/* =============================================================
   018 - SP_STOCK_APLICAR: VUELVEN LOS CONTROLES DE SEGURIDAD
   Yesenia Quejada Rojas - Claude — 26/11/2026

   El 017 reemplazó SP_STOCK_APLICAR partiendo de una versión vieja y
   se perdieron tres controles que tenía la del hosting. Este script
   deja el comportamiento del 017 (las ventas pueden dejar el stock en
   negativo) y los devuelve:
   1. Si se llama fuera de una transacción, da error.
   2. Bloqueo (UPDLOCK, HOLDLOCK) al revisar si existe la fila del insumo
      en la sede, para que dos ventas a la vez no choquen.
   3. En salidas y mermas, si los lotes no alcanzan da "Los lotes no
      coinciden con el stock". Las ventas y los ajustes del conteo
      (AJUSTE-) no se bloquean, para que el conteo siempre pueda corregir.

   Solo reemplaza el procedimiento; no cambia datos.
   Se puede ejecutar más de una vez.
   ============================================================= */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

/* ---------- 0. Verificación de SP_STOCK_APLICAR ---------- */
IF (SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.SP_STOCK_APLICAR')) <> 10
   OR (SELECT STRING_AGG(name, ',') WITHIN GROUP (ORDER BY parameter_id) FROM sys.parameters WHERE object_id = OBJECT_ID('dbo.SP_STOCK_APLICAR'))
      <> '@IdSede,@IdInsumo,@Tipo,@Delta,@CostoUnitario,@IdProveedor,@IdVenta,@Observacion,@IdUsuario,@FechaVencimiento'
BEGIN
    RAISERROR('018: SP_STOCK_APLICAR no tiene los parámetros esperados. No se cambió nada; revisar a mano.', 16, 1);
    SET NOEXEC ON;
END
GO

CREATE OR ALTER PROCEDURE dbo.SP_STOCK_APLICAR (
    @IdSede INT, @IdInsumo INT, @Tipo VARCHAR(10), @Delta DECIMAL(12,3),
    @CostoUnitario DECIMAL(12,2), @IdProveedor INT, @IdVenta INT,
    @Observacion VARCHAR(250), @IdUsuario INT, @FechaVencimiento DATE = NULL)
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT = 0 THROW 50001, 'El movimiento de stock debe ejecutarse dentro de una transacción', 1;
    DECLARE @StockActual DECIMAL(12,3), @IdMovimiento INT;

    IF NOT EXISTS (SELECT 1 FROM INSUMO_SEDE WITH (UPDLOCK, HOLDLOCK) WHERE IdSede = @IdSede AND IdInsumo = @IdInsumo)
        INSERT INTO INSUMO_SEDE (IdSede, IdInsumo, Stock) VALUES (@IdSede, @IdInsumo, 0);

    SELECT @StockActual = Stock FROM INSUMO_SEDE WITH (UPDLOCK, HOLDLOCK)
    WHERE IdSede = @IdSede AND IdInsumo = @IdInsumo;

    -- Solo una salida que no sea venta (salida, merma, ajuste) se bloquea si no alcanza.
    IF @Delta < 0 AND @Tipo <> 'VENTA' AND @StockActual + @Delta < 0
    BEGIN
        DECLARE @Nombre VARCHAR(100) = (SELECT Nombre FROM INSUMO WHERE IdInsumo = @IdInsumo);
        DECLARE @Err VARCHAR(400) = 'Stock insuficiente de ' + @Nombre + '. Disponible: ' + CAST(@StockActual AS VARCHAR(20));
        THROW 50001, @Err, 1;
    END

    UPDATE INSUMO_SEDE SET Stock = Stock + @Delta WHERE IdSede = @IdSede AND IdInsumo = @IdInsumo;

    INSERT INTO MOVIMIENTO (IdSede, IdInsumo, Tipo, Cantidad, CostoUnitario, StockAnterior, StockNuevo,
                            IdProveedor, IdVenta, Observacion, IdUsuario)
    VALUES (@IdSede, @IdInsumo, @Tipo, ABS(@Delta), ISNULL(@CostoUnitario, 0), @StockActual, @StockActual + @Delta,
            NULLIF(@IdProveedor, 0), @IdVenta, @Observacion, @IdUsuario);
    SET @IdMovimiento = SCOPE_IDENTITY();

    IF @Delta > 0
    BEGIN
        -- Si el stock venía en negativo, la entrada primero cubre el faltante; solo lo que sobra queda como lote.
        DECLARE @ParaLote DECIMAL(12,3) = CASE WHEN @StockActual >= 0 THEN @Delta
                                               WHEN @StockActual + @Delta > 0 THEN @StockActual + @Delta
                                               ELSE 0 END;
        IF @ParaLote > 0
            INSERT INTO LOTE (IdSede, IdInsumo, CantidadInicial, CantidadDisponible, FechaVencimiento, IdMovimiento)
            VALUES (@IdSede, @IdInsumo, @ParaLote, @ParaLote, @FechaVencimiento, @IdMovimiento);
    END
    ELSE
    BEGIN
        -- Consumir lotes: primero los que vencen antes, luego los más antiguos. Si no alcanzan, el resto queda en negativo.
        DECLARE @Pendiente DECIMAL(12,3) = -@Delta, @IdLote INT, @Disp DECIMAL(12,3), @HayLote INT;
        WHILE @Pendiente > 0
        BEGIN
            SELECT TOP 1 @IdLote = IdLote, @Disp = CantidadDisponible
            FROM LOTE WITH (UPDLOCK)
            WHERE IdSede = @IdSede AND IdInsumo = @IdInsumo AND CantidadDisponible > 0
            ORDER BY CASE WHEN FechaVencimiento IS NULL THEN 1 ELSE 0 END, FechaVencimiento, FechaIngreso, IdLote;
            SET @HayLote = @@ROWCOUNT;
            -- Ventas (pueden quedar en negativo) y ajustes del conteo (siempre deben poder corregir) no se bloquean.
            IF @HayLote = 0 AND @Tipo IN ('VENTA', 'AJUSTE-') BREAK;
            IF @HayLote = 0 THROW 50001, 'Los lotes no coinciden con el stock; revise el inventario', 1;
            IF @Disp >= @Pendiente
            BEGIN
                UPDATE LOTE SET CantidadDisponible = CantidadDisponible - @Pendiente WHERE IdLote = @IdLote;
                SET @Pendiente = 0;
            END
            ELSE
            BEGIN
                UPDATE LOTE SET CantidadDisponible = 0 WHERE IdLote = @IdLote;
                SET @Pendiente = @Pendiente - @Disp;
            END
        END
    END
END
GO

SET NOEXEC OFF;
GO
