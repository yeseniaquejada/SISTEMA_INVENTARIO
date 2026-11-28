/* =============================================================
   VENTAS GUARDADAS CON 0 CAJAS GASTADAS  (SOLO LEE, NO CAMBIA NADA)
   Yesenia Quejada Rojas - Claude — 28/11/2026

   Desde el 24/11/2026 (script 016) la pantalla de Vender dejó de
   sugerir las cajas del pedido y las ventas se guardaron con
   VENTA.Cajas = 0, aunque la receta sí descontó las cajas del
   inventario. Este script muestra, por venta, cuántas cajas descontó
   la receta según MOVIMIENTO (VENTA menos DEVOLUCION por ediciones),
   para decidir después si se reponen en VENTA.Cajas.

   CajasSugeridas = cajas "Caja de empaque" de la receta: es lo que la
   pantalla habría sugerido (lo mismo que se guardaba antes del 24/11).
   OtrasCajas     = otras cajas de empaque (p. ej. "Caja C1 hamburguesa"),
   que nunca se contaron como cajas gastadas; salen solo como referencia.

   Ojo: antes del script 017 (26/11/2026) una venta no descontaba un
   insumo en 0, así que las ventas del 24 y 25/11 pueden salir con 0
   cajas en MOVIMIENTO aunque sí llevaran caja.
   ============================================================= */
SET NOCOUNT ON;
DECLARE @Sede INT = 1, @Desde DATETIME = '20261124';

;WITH cajas AS (
    -- Insumos de caja de empaque: el mismo criterio de nombre que usa el cierre de caja (empieza por "Caja").
    SELECT IdInsumo, CASE WHEN LTRIM(RTRIM(Nombre)) = 'Caja de empaque' THEN 1 ELSE 0 END AS EsSugerida
    FROM dbo.INSUMO
    WHERE LTRIM(Nombre) LIKE 'caja%'),
porVenta AS (
    SELECT m.IdVenta,
           SUM(CASE WHEN k.EsSugerida = 1 THEN CASE m.Tipo WHEN 'VENTA' THEN m.Cantidad ELSE -m.Cantidad END ELSE 0 END) AS CajasSugeridas,
           SUM(CASE WHEN k.EsSugerida = 0 THEN CASE m.Tipo WHEN 'VENTA' THEN m.Cantidad ELSE -m.Cantidad END ELSE 0 END) AS OtrasCajas
    FROM dbo.MOVIMIENTO m
    INNER JOIN cajas k ON k.IdInsumo = m.IdInsumo
    WHERE m.IdVenta IS NOT NULL AND m.Tipo IN ('VENTA', 'DEVOLUCION')
    GROUP BY m.IdVenta)
SELECT v.IdCaja, v.IdVenta, CONVERT(VARCHAR(16), v.Fecha, 120) AS Fecha, v.TipoPedido, v.Total,
       v.Cajas AS CajasGuardadas,
       CAST(ISNULL(p.CajasSugeridas, 0) AS INT) AS CajasSugeridas,
       CAST(ISNULL(p.OtrasCajas, 0) AS INT) AS OtrasCajas
FROM dbo.VENTA v
LEFT JOIN porVenta p ON p.IdVenta = v.IdVenta
WHERE v.IdSede = @Sede AND v.Anulada = 0 AND v.Fecha >= @Desde AND v.Cajas = 0
ORDER BY v.IdCaja, v.IdVenta;

/* Resumen por caja: lo que mostraría "Cajas gastadas" si se repusieran las sugeridas. */
;WITH cajas AS (
    SELECT IdInsumo FROM dbo.INSUMO WHERE LTRIM(RTRIM(Nombre)) = 'Caja de empaque'),
porVenta AS (
    SELECT m.IdVenta, SUM(CASE m.Tipo WHEN 'VENTA' THEN m.Cantidad ELSE -m.Cantidad END) AS Cajas
    FROM dbo.MOVIMIENTO m INNER JOIN cajas k ON k.IdInsumo = m.IdInsumo
    WHERE m.IdVenta IS NOT NULL AND m.Tipo IN ('VENTA', 'DEVOLUCION')
    GROUP BY m.IdVenta)
SELECT v.IdCaja, COUNT(*) AS Ventas, SUM(v.Cajas) AS CajasGuardadas,
       CAST(SUM(ISNULL(p.Cajas, 0)) AS INT) AS CajasSugeridas
FROM dbo.VENTA v
LEFT JOIN porVenta p ON p.IdVenta = v.IdVenta
WHERE v.IdSede = @Sede AND v.Anulada = 0 AND v.Fecha >= @Desde
GROUP BY v.IdCaja
ORDER BY v.IdCaja;
