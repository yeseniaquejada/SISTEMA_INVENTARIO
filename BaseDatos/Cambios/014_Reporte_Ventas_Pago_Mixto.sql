/* =============================================================
   014 - REPORTE DE VENTAS: LAS VENTAS MIXTAS SE REPARTEN POR MEDIO DE PAGO
   Yesenia Quejada Rojas - Claude â€” 14/11/2026

   En el resumen de ventas, una venta pagada en efectivo y transferencia
   suma cada parte a su medio (antes todo iba a efectivo). Los pedidos se
   cuentan una vez por medio. No cambia datos; se puede ejecutar de nuevo.
   ============================================================= */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE SP_REPORTE_RESUMEN (@IdSede INT, @FechaInicio DATE, @FechaFin DATE)
AS
BEGIN
    DECLARE @Ventas DECIMAL(14,2), @Domicilios DECIMAL(14,2), @Pedidos INT, @Costo DECIMAL(14,2), @Mermas DECIMAL(14,2);
    -- Yesenia Quejada Rojas - Claude — 31/10/2026: cajas de empaque. cajas de empaque de los pedidos del periodo (no anulados) y su valor unitario.
    DECLARE @Cajas INT, @CostoCaja DECIMAL(12,2) = dbo.FN_COSTO_CAJA();
    SELECT @Cajas = ISNULL(SUM(Cajas), 0) FROM VENTA WHERE IdSede = @IdSede AND Anulada = 0 AND /* Yesenia Quejada Rojas - Claude — 02/11/2026: el dia de una venta es el de la apertura de su caja (lo de despues de medianoche es del dia anterior). */ IdCaja IN (SELECT IdCaja FROM CAJA WHERE CAST(FechaApertura AS DATE) BETWEEN @FechaInicio AND @FechaFin);
    SELECT @Ventas = ISNULL(SUM(Total), 0), @Domicilios = ISNULL(SUM(CostoDomicilio), 0), @Pedidos = COUNT(*)
    FROM VENTA WHERE IdSede = @IdSede AND Anulada = 0 AND /* Yesenia Quejada Rojas - Claude — 02/11/2026: el dia de una venta es el de la apertura de su caja (lo de despues de medianoche es del dia anterior). */ IdCaja IN (SELECT IdCaja FROM CAJA WHERE CAST(FechaApertura AS DATE) BETWEEN @FechaInicio AND @FechaFin);

    -- Costo neto: lo que salió por ventas menos lo que volvió por ediciones o anulaciones
    SELECT @Costo = ISNULL(SUM(CASE WHEN m.Tipo = 'VENTA' THEN 1 ELSE -1 END * m.Cantidad * m.CostoUnitario), 0)
    FROM MOVIMIENTO m
    WHERE m.IdSede = @IdSede AND (m.Tipo = 'VENTA' OR m.Tipo = 'DEVOLUCION' AND m.IdVenta IS NOT NULL)
      AND ISNULL((SELECT CAST(c.FechaApertura AS DATE) FROM VENTA vm INNER JOIN CAJA c ON c.IdCaja = vm.IdCaja WHERE vm.IdVenta = m.IdVenta), CAST(m.Fecha AS DATE)) BETWEEN @FechaInicio AND @FechaFin;

    SELECT @Mermas = ISNULL(SUM(m.Cantidad * m.CostoUnitario), 0)
    FROM MOVIMIENTO m WHERE m.IdSede = @IdSede AND m.Tipo = 'MERMA' AND CAST(m.Fecha AS DATE) BETWEEN @FechaInicio AND @FechaFin;

    SELECT @Ventas AS Ventas, @Pedidos AS Pedidos,
           CASE WHEN @Pedidos > 0 THEN @Ventas / @Pedidos ELSE 0 END AS TicketPromedio,
           @Ventas - @Domicilios AS VentasProductos, @Costo AS CostoInsumos,
           @Ventas - @Domicilios - @Costo AS Ganancia, @Mermas AS Mermas, @Cajas AS Cajas, @CostoCaja AS CostoCaja;

    -- Yesenia Quejada Rojas - Claude â€” 14/11/2026: una venta mixta (efectivo + transferencia) se reparte entre los dos medios.
    SELECT p.MetodoPago, COUNT(*) AS Pedidos, SUM(p.Total) AS Total
    FROM VENTA
    CROSS APPLY (VALUES (MetodoPago, Total - MontoTransferencia), ('TRANSFERENCIA', MontoTransferencia)) AS p(MetodoPago, Total)
    WHERE IdSede = @IdSede AND Anulada = 0 AND IdSede = @IdSede AND Anulada = 0 AND /* Yesenia Quejada Rojas - Claude — 02/11/2026: el dia de una venta es el de la apertura de su caja (lo de despues de medianoche es del dia anterior). */ IdCaja IN (SELECT IdCaja FROM CAJA WHERE CAST(FechaApertura AS DATE) BETWEEN @FechaInicio AND @FechaFin)
      AND p.Total > 0
    GROUP BY p.MetodoPago;
END
GO
