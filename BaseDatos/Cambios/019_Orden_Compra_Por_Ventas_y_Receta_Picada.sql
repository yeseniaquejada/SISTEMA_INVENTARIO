/* =============================================================
   019 - ORDEN DE COMPRA CON EL CONSUMO REAL Y EMPAQUE DE LA PICADA
   Yesenia Quejada Rojas - Claude — 26/11/2026

   1. SP_ORDEN_COMPRA_SUGERIDA: el consumo diario se calcula con las
      ventas de los últimos 14 días × la receta y las adiciones actuales
      (sin lo que el cliente pidió quitar, sin anuladas), en vez de con
      los movimientos. Antes del 017, si un insumo estaba en 0 la venta
      no dejaba movimiento y el consumo salía en 0 (cajas, huevo de
      codorniz, papel aluminio...), así que se pedía muy poco.
      Además ya no salen los insumos marcados "no descontar al vender"
      (salsas preparadas, papa bulto). Lo demás queda igual: se pide
      para 7 días sin bajar del doble del mínimo, en números enteros,
      y la pantalla sigue quitando los insumos "fuera de la lista".
   2. Picada (para 2 personas) no tenía receta. Se le pone solo el
      empaque, igual que las papas: 1 caja, 2 tenedores, 3 servilletas
      y 1 bolsa T30. Lo que lleva de comida se agrega en Productos.
      Si la Picada ya tiene alguna receta, no se toca.

   No cambia ventas ni stock. Se puede ejecutar más de una vez.
   ============================================================= */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE SP_ORDEN_COMPRA_SUGERIDA (@IdSede INT)
AS
BEGIN
    SET NOCOUNT ON;
    -- Yesenia Quejada Rojas - Claude - 31/10/2026: "a pedir" estimado por consumo real: promedio diario de los ultimos 14 dias
    -- (sobre los dias con ventas). Se pide para cubrir 7 dias, sin bajar del doble del minimo, en numeros enteros.
    -- Tambien entra lo que no alcanza para 3 dias aunque este sobre el minimo. Sin historial queda la regla anterior (doble del minimo).
    -- Yesenia Quejada Rojas - Claude — 26/11/2026: el consumo sale de las ventas × receta y adiciones (no de los movimientos,
    -- que antes del 017 quedaban en 0 cuando no había stock). Solo insumos que se descuentan al vender.
    DECLARE @Desde DATETIME = DATEADD(DAY, -14, GETDATE());
    DECLARE @Dias INT = (SELECT COUNT(DISTINCT CONVERT(DATE, Fecha)) FROM VENTA WHERE IdSede = @IdSede AND Anulada = 0 AND Fecha >= @Desde);
    IF @Dias = 0 SET @Dias = 1;

    ;WITH Lineas AS (
        SELECT d.IdDetalle, d.IdProducto, d.Cantidad
        FROM DETALLE_VENTA d INNER JOIN VENTA v ON v.IdVenta = d.IdVenta
        WHERE v.IdSede = @IdSede AND v.Anulada = 0 AND v.Fecha >= @Desde
    ), PorLinea AS (
        SELECT l.IdDetalle, r.IdInsumo, r.Cantidad AS Cant, l.Cantidad AS Veces
        FROM Lineas l INNER JOIN RECETA r ON r.IdProducto = l.IdProducto
        WHERE NOT EXISTS (SELECT 1 FROM DETALLE_QUITADO q WHERE q.IdDetalle = l.IdDetalle AND q.IdInsumo = r.IdInsumo)
        UNION ALL
        SELECT l.IdDetalle, m.IdInsumo, m.Cantidad, l.Cantidad
        FROM Lineas l INNER JOIN DETALLE_MODIFICADOR dm ON dm.IdDetalle = l.IdDetalle
        INNER JOIN MODIFICADOR m ON m.IdModificador = dm.IdModificador
        WHERE m.IdInsumo IS NOT NULL
    ), Consumo AS (
        SELECT t.IdInsumo, SUM(CASE WHEN t.c > 0 THEN t.c ELSE 0 END * t.Veces) / @Dias AS ConsumoDia
        FROM (SELECT IdDetalle, IdInsumo, SUM(Cant) AS c, MAX(Veces) AS Veces FROM PorLinea GROUP BY IdDetalle, IdInsumo) t
        GROUP BY t.IdInsumo
    ), Base AS (
        SELECT i.IdInsumo, i.Codigo, i.Nombre, i.UnidadMedida, ISNULL(s.Stock, 0) AS Stock, i.StockMinimo, i.CostoUnitario,
               CASE WHEN ISNULL(c.ConsumoDia, 0) > 0 THEN c.ConsumoDia ELSE 0 END AS ConsumoDia,
               ISNULL(ult.IdProveedor, 0) AS IdProveedor, ISNULL(p.RazonSocial, 'Sin proveedor') AS Proveedor, ISNULL(p.Telefono, '') AS TelefonoProveedor
        FROM INSUMO i
        LEFT JOIN INSUMO_SEDE s ON s.IdInsumo = i.IdInsumo AND s.IdSede = @IdSede
        LEFT JOIN Consumo c ON c.IdInsumo = i.IdInsumo
        OUTER APPLY (SELECT TOP 1 m.IdProveedor FROM MOVIMIENTO m
                     WHERE m.IdInsumo = i.IdInsumo AND m.Tipo = 'ENTRADA' AND m.IdProveedor IS NOT NULL
                     ORDER BY m.Fecha DESC) ult
        LEFT JOIN PROVEEDOR p ON p.IdProveedor = ult.IdProveedor
        WHERE i.Activo = 1 AND i.ControlaStock = 1 AND i.StockMinimo > 0
    ), Calculo AS (
        SELECT b.*, CAST(CEILING(CASE WHEN b.ConsumoDia * 7 > b.StockMinimo * 2 THEN b.ConsumoDia * 7 ELSE b.StockMinimo * 2 END - b.Stock) AS DECIMAL(12,3)) AS Cantidad
        FROM Base b
        WHERE b.Stock <= b.StockMinimo OR b.Stock < b.ConsumoDia * 3
    )
    SELECT IdInsumo, Codigo, Nombre, UnidadMedida, Stock, StockMinimo,
           CAST(ConsumoDia AS DECIMAL(12,3)) AS ConsumoDia,
           CASE WHEN Cantidad < 1 THEN CAST(1 AS DECIMAL(12,3)) ELSE Cantidad END AS CantidadSugerida,
           CostoUnitario,
           CAST(CASE WHEN Cantidad < 1 THEN 1 ELSE Cantidad END * CostoUnitario AS DECIMAL(12,2)) AS CostoEstimado,
           IdProveedor, Proveedor, TelefonoProveedor
    FROM Calculo
    ORDER BY CASE WHEN IdProveedor = 0 THEN 'zzz' ELSE Proveedor END, Nombre;
END;
GO

/* ---------- 2. Empaque de la Picada ---------- */
SET XACT_ABORT ON;
DECLARE @Picada INT = (SELECT IdProducto FROM PRODUCTO_MENU WHERE Nombre = 'Picada');
IF @Picada IS NULL
    PRINT 'No existe el producto Picada; no se cambia nada.';
ELSE IF EXISTS (SELECT 1 FROM RECETA WHERE IdProducto = @Picada)
    PRINT 'La Picada ya tiene receta; no se toca.';
ELSE
BEGIN
    BEGIN TRANSACTION;
    INSERT INTO RECETA (IdProducto, IdInsumo, Cantidad)
    SELECT @Picada, i.IdInsumo, x.Cantidad
    FROM (VALUES ('CAJA', 1.0), ('TENE', 2.0), ('SERV', 0.03), ('BOLT30', 0.01)) x (Codigo, Cantidad)
    INNER JOIN INSUMO i ON i.Codigo = x.Codigo AND i.Activo = 1;
    PRINT 'Picada: empaque agregado a la receta (' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' insumos).';
    COMMIT TRANSACTION;
END
GO

/* Verificación */
SELECT p.Nombre AS Producto, i.Codigo, i.Nombre AS Insumo, r.Cantidad
FROM RECETA r INNER JOIN PRODUCTO_MENU p ON p.IdProducto = r.IdProducto INNER JOIN INSUMO i ON i.IdInsumo = r.IdInsumo
WHERE p.Nombre = 'Picada';
EXEC SP_ORDEN_COMPRA_SUGERIDA @IdSede = 1;
GO
