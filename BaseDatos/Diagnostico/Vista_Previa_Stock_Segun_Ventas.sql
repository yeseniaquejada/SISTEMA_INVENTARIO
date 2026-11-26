/* =============================================================
   VISTA PREVIA: ¿CÓMO QUEDARÍA EL STOCK SI TODAS LAS VENTAS
   HUBIERAN DESCONTADO COMPLETO?  (SOLO LEE, NO CAMBIA NADA)
   Yesenia Quejada Rojas - Claude — 26/11/2026

   Antes del 017, si un insumo estaba en 0 la venta no lo descontaba.
   Para cada insumo que se descuenta al vender, desde su último conteo
   físico (o desde el principio si nunca se contó) compara lo que las
   ventas debieron descontar (receta y adiciones ACTUALES, sin lo que el
   cliente pidió quitar, sin anuladas) con lo que de verdad bajó.
   Faltante = lo que quedó sin descontar. StockAjustado = StockHoy - Faltante.
   ============================================================= */
SET NOCOUNT ON;
DECLARE @Sede INT = 1;

;WITH ultimo AS (
    SELECT cd.IdInsumo, MAX(c.Fecha) AS Desde
    FROM CONTEO c INNER JOIN CONTEO_DETALLE cd ON cd.IdConteo = c.IdConteo
    WHERE c.IdSede = @Sede GROUP BY cd.IdInsumo),
lineas AS (
    SELECT d.IdDetalle, d.IdProducto, d.Cantidad, v.IdVenta, v.Fecha
    FROM DETALLE_VENTA d INNER JOIN VENTA v ON v.IdVenta = d.IdVenta
    WHERE v.IdSede = @Sede AND v.Anulada = 0),
porLinea AS (
    SELECT l.IdDetalle, l.Fecha, r.IdInsumo, r.Cantidad AS Cant, l.Cantidad AS Veces
    FROM lineas l INNER JOIN RECETA r ON r.IdProducto = l.IdProducto
    WHERE NOT EXISTS (SELECT 1 FROM DETALLE_QUITADO q WHERE q.IdDetalle = l.IdDetalle AND q.IdInsumo = r.IdInsumo)
    UNION ALL
    SELECT l.IdDetalle, l.Fecha, m.IdInsumo, m.Cantidad, l.Cantidad
    FROM lineas l INNER JOIN DETALLE_MODIFICADOR dm ON dm.IdDetalle = l.IdDetalle
    INNER JOIN MODIFICADOR m ON m.IdModificador = dm.IdModificador
    WHERE m.IdInsumo IS NOT NULL),
esperado AS (
    SELECT t.IdInsumo, SUM(CASE WHEN t.c > 0 THEN t.c ELSE 0 END * t.Veces) AS Esperado, COUNT(*) AS Lineas
    FROM (SELECT IdDetalle, IdInsumo, MAX(Fecha) AS Fecha, SUM(Cant) AS c, MAX(Veces) AS Veces FROM porLinea GROUP BY IdDetalle, IdInsumo) t
    LEFT JOIN ultimo u ON u.IdInsumo = t.IdInsumo
    WHERE u.Desde IS NULL OR t.Fecha > u.Desde
    GROUP BY t.IdInsumo),
bajado AS (
    SELECT m.IdInsumo, SUM(CASE WHEN m.Tipo = 'VENTA' THEN m.Cantidad ELSE -m.Cantidad END) AS Bajo
    FROM MOVIMIENTO m INNER JOIN VENTA v ON v.IdVenta = m.IdVenta
    LEFT JOIN ultimo u ON u.IdInsumo = m.IdInsumo
    WHERE m.IdSede = @Sede AND v.Anulada = 0 AND m.Tipo IN ('VENTA', 'DEVOLUCION')
      AND (u.Desde IS NULL OR v.Fecha > u.Desde)
    GROUP BY m.IdInsumo)
SELECT i.Codigo, i.Nombre, i.UnidadMedida,
       CONVERT(VARCHAR(16), u.Desde, 120) AS UltimoConteo,
       e.Lineas AS LineasVendidas,
       CAST(e.Esperado AS DECIMAL(12,3)) AS DebioBajar,
       CAST(ISNULL(b.Bajo, 0) AS DECIMAL(12,3)) AS Bajo,
       CAST(e.Esperado - ISNULL(b.Bajo, 0) AS DECIMAL(12,3)) AS Faltante,
       ISNULL(s.Stock, 0) AS StockHoy,
       CAST(ISNULL(s.Stock, 0) - (e.Esperado - ISNULL(b.Bajo, 0)) AS DECIMAL(12,3)) AS StockAjustado
FROM esperado e
INNER JOIN INSUMO i ON i.IdInsumo = e.IdInsumo AND i.Activo = 1 AND i.ControlaStock = 1
LEFT JOIN bajado b ON b.IdInsumo = e.IdInsumo
LEFT JOIN ultimo u ON u.IdInsumo = e.IdInsumo
LEFT JOIN INSUMO_SEDE s ON s.IdInsumo = e.IdInsumo AND s.IdSede = @Sede
WHERE e.Esperado - ISNULL(b.Bajo, 0) > 0.001
ORDER BY i.Nombre;
