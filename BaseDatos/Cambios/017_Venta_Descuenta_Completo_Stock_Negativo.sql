/* =============================================================
   017 - LA VENTA DESCUENTA COMPLETO AUNQUE EL STOCK QUEDE EN NEGATIVO
   Yesenia Quejada Rojas - Claude — 26/11/2026

   Qué pasaba: si un insumo estaba en 0 (o no alcanzaba), la venta
   descontaba solo lo que había y el resto se perdía ("faltaron X").
   Al registrar la compra, el sistema quedaba con más de lo real.

   Qué cambia:
   1. INSUMO_SEDE.Stock ya puede ser negativo (se quita el CHECK >= 0).
   2. SP_STOCK_APLICAR: las ventas pueden dejar el stock en negativo.
      Salidas y mermas siguen sin poder pasar de lo que hay. Una
      entrada, devolución o ajuste sobre un stock negativo primero
      cubre lo que faltaba y solo lo que sobra crea lote (así los
      lotes siguen cuadrando con el stock).
   3. SP_VENTA_REGISTRAR: descuenta la cantidad completa. Si quedó en
      negativo, el movimiento dice "faltaron X; quedó en -Y".
      La venta nunca se bloquea (igual que antes).

   No cambia ventas ni stock existentes. Lo que se perdió antes se
   corrige con el conteo (Contar inventario, modo "Total contado").

   Antes de cambiar SP_STOCK_APLICAR revisa que tenga los 10 parámetros
   de siempre; si no, se detiene sin cambiar nada. La versión anterior
   queda en el registro de la ejecución (BaseDatos\Resultados).
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
    RAISERROR('017: SP_STOCK_APLICAR no tiene los parámetros esperados. No se cambió nada; revisar a mano.', 16, 1);
    SET NOEXEC ON;
END
GO

PRINT '== Versión anterior de SP_STOCK_APLICAR (respaldo) ==';
SELECT OBJECT_DEFINITION(OBJECT_ID('dbo.SP_STOCK_APLICAR')) AS SP_STOCK_APLICAR_Anterior;
GO

/* ---------- 1. El stock puede quedar en negativo ---------- */
DECLARE @ck SYSNAME, @sql NVARCHAR(400);
DECLARE ck CURSOR LOCAL FAST_FORWARD FOR
    SELECT cc.name FROM sys.check_constraints cc
    WHERE cc.parent_object_id = OBJECT_ID('dbo.INSUMO_SEDE') AND cc.definition LIKE '%Stock%>=%0%';
OPEN ck; FETCH NEXT FROM ck INTO @ck;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'ALTER TABLE dbo.INSUMO_SEDE DROP CONSTRAINT ' + QUOTENAME(@ck);
    EXEC sp_executesql @sql;
    PRINT 'Quitada la restricción ' + @ck + ' (Stock >= 0).';
    FETCH NEXT FROM ck INTO @ck;
END
CLOSE ck; DEALLOCATE ck;
GO

/* ---------- 2. SP_STOCK_APLICAR ---------- */
/* Mueve el stock de un insumo en una sede, registra el kardex y actualiza lotes.
   Debe llamarse dentro de una transacción. @Delta positivo = entra, negativo = sale.
   Yesenia Quejada Rojas - Claude — 26/11/2026: las ventas pueden dejar el stock en negativo. */
CREATE OR ALTER PROCEDURE dbo.SP_STOCK_APLICAR (
    @IdSede INT, @IdInsumo INT, @Tipo VARCHAR(10), @Delta DECIMAL(12,3),
    @CostoUnitario DECIMAL(12,2), @IdProveedor INT, @IdVenta INT,
    @Observacion VARCHAR(250), @IdUsuario INT, @FechaVencimiento DATE = NULL)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @StockActual DECIMAL(12,3), @IdMovimiento INT;

    IF NOT EXISTS (SELECT 1 FROM INSUMO_SEDE WHERE IdSede = @IdSede AND IdInsumo = @IdInsumo)
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
        DECLARE @Pendiente DECIMAL(12,3) = -@Delta, @IdLote INT, @Disp DECIMAL(12,3);
        WHILE @Pendiente > 0
        BEGIN
            SELECT TOP 1 @IdLote = IdLote, @Disp = CantidadDisponible
            FROM LOTE WITH (UPDLOCK)
            WHERE IdSede = @IdSede AND IdInsumo = @IdInsumo AND CantidadDisponible > 0
            ORDER BY CASE WHEN FechaVencimiento IS NULL THEN 1 ELSE 0 END, FechaVencimiento, FechaIngreso, IdLote;
            IF @@ROWCOUNT = 0 BREAK;
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

/* ---------- 3. SP_VENTA_REGISTRAR (igual al del 013, cambia solo el descuento) ---------- */
CREATE OR ALTER PROCEDURE SP_VENTA_REGISTRAR (
    @IdSede INT, @IdUsuario INT, @TipoPedido VARCHAR(10), @ClienteNombre VARCHAR(100), @ClienteTelefono VARCHAR(30),
    @Direccion VARCHAR(200), @CostoDomicilio DECIMAL(12,2), @MetodoPago VARCHAR(15), @MontoRecibido DECIMAL(12,2),
    @Lineas ELineaVenta READONLY, @Modificadores ELineaModificador READONLY,
    @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT, @IdVenta INT = 0,
    -- Yesenia Quejada Rojas - Claude - 19/10/2026: ingredientes de la receta que el cliente pidió quitar ("sin lechuga"); no se descuentan del inventario.
    @Quitados ELineaQuitado READONLY,
    -- Yesenia Quejada Rojas - Claude — 31/10/2026: cajas de empaque. Cajas de empaque que lleva el pedido (0 a 99); se cuentan como "cajas gastadas" al cerrar la caja y en los reportes.
    @Cajas INT = 0,
    -- Yesenia Quejada Rojas - Claude — 13/11/2026: pago mixto. Parte del total que se pagó por transferencia cuando el resto es en efectivo.
    @MontoTransferencia DECIMAL(12,2) = 0)
AS
BEGIN
    SET NOCOUNT ON;
    SET @Resultado = 0; SET @Mensaje = '';
    SET @IdVenta = ISNULL(@IdVenta, 0);
    SET @Cajas = ISNULL(@Cajas, 0);
    IF @Cajas < 0 OR @Cajas > 99 BEGIN SET @Mensaje = 'Las cajas deben estar entre 0 y 99'; RETURN; END

    DECLARE @IdCaja INT = (SELECT IdCaja FROM CAJA WHERE IdSede = @IdSede AND Estado = 'ABIERTA');
    IF @IdCaja IS NULL BEGIN SET @Mensaje = 'Abra la caja antes de registrar ventas'; RETURN; END
    IF @IdVenta > 0
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM VENTA WHERE IdVenta = @IdVenta AND IdSede = @IdSede)
        BEGIN SET @Mensaje = 'No se encontró el pedido'; RETURN; END
        IF dbo.FN_VENTA_SEGUNDOS_EDICION(@IdVenta) <= 0
        BEGIN SET @Mensaje = 'Este pedido ya no se puede editar: pasó el tiempo permitido o cocina ya lo empezó'; RETURN; END
    END
    IF EXISTS(SELECT 1 FROM @Lineas WHERE Cantidad<=0) BEGIN SET @Mensaje='Las cantidades deben ser positivas'; RETURN; END;
    IF NOT EXISTS (SELECT 1 FROM @Lineas) BEGIN SET @Mensaje = 'La venta no tiene productos'; RETURN; END
    IF EXISTS (SELECT 1 FROM @Lineas l LEFT JOIN PRODUCTO_MENU p ON p.IdProducto = l.IdProducto AND p.Activo = 1 WHERE p.IdProducto IS NULL)
    BEGIN SET @Mensaje = 'Hay productos inactivos o inexistentes en la venta'; RETURN; END
    IF EXISTS (SELECT 1 FROM @Modificadores lm INNER JOIN @Lineas l ON l.Linea = lm.Linea
               LEFT JOIN PRODUCTO_MODIFICADOR pm ON pm.IdProducto = l.IdProducto AND pm.IdModificador = lm.IdModificador
               LEFT JOIN MODIFICADOR m ON m.IdModificador = lm.IdModificador AND m.Activo = 1
               WHERE pm.IdModificador IS NULL OR m.IdModificador IS NULL)
    BEGIN SET @Mensaje = 'Hay adiciones que no aplican a su producto'; RETURN; END
    IF EXISTS (SELECT 1 FROM @Quitados q INNER JOIN @Lineas l ON l.Linea = q.Linea
               LEFT JOIN RECETA r ON r.IdProducto = l.IdProducto AND r.IdInsumo = q.IdInsumo
               WHERE r.IdInsumo IS NULL)
    BEGIN SET @Mensaje = 'Hay ingredientes para quitar que no son de la receta del producto'; RETURN; END

    -- Precio por línea = precio del producto + adiciones
    DECLARE @Precios TABLE (Linea INT PRIMARY KEY, Precio DECIMAL(12,2));
    INSERT INTO @Precios
    SELECT l.Linea, p.Precio + ISNULL((SELECT SUM(m.Precio) FROM @Modificadores lm
                                       INNER JOIN MODIFICADOR m ON m.IdModificador = lm.IdModificador
                                       WHERE lm.Linea = l.Linea), 0)
    FROM @Lineas l INNER JOIN PRODUCTO_MENU p ON p.IdProducto = l.IdProducto;

    DECLARE @Subtotal DECIMAL(12,2) = (SELECT SUM(pr.Precio * l.Cantidad) FROM @Lineas l INNER JOIN @Precios pr ON pr.Linea = l.Linea);
    SET @CostoDomicilio = CASE WHEN @TipoPedido = 'DOMICILIO' THEN ISNULL(@CostoDomicilio, 0) ELSE 0 END;
    DECLARE @Total DECIMAL(12,2) = @Subtotal + @CostoDomicilio;

    -- Yesenia Quejada Rojas - Claude — 13/11/2026: pago mixto (efectivo + transferencia): el efectivo solo cubre lo que falta.
    SET @MontoTransferencia = CASE WHEN @MetodoPago = 'EFECTIVO' THEN ISNULL(@MontoTransferencia, 0) ELSE 0 END;
    IF @MontoTransferencia < 0 OR (@MontoTransferencia > 0 AND @MontoTransferencia >= @Total)
    BEGIN SET @Mensaje = 'La parte en transferencia debe ser menor que el total'; RETURN; END
    IF @MetodoPago = 'EFECTIVO' AND @MontoRecibido < @Total - @MontoTransferencia
    BEGIN SET @Mensaje = 'El dinero recibido es menor que el total'; RETURN; END
    IF @MetodoPago <> 'EFECTIVO' SET @MontoRecibido = @Total;
    IF @TipoPedido = 'DOMICILIO' AND (ISNULL(@ClienteNombre, '') = '' OR ISNULL(@Direccion, '') = '' OR ISNULL(@ClienteTelefono, '') = '')
    BEGIN SET @Mensaje = 'Para domicilio indique nombre, teléfono y dirección del cliente'; RETURN; END

    -- Consumo de insumos: receta + modificadores por línea (sin bajar de cero en cada línea)
    DECLARE @Consumo TABLE (IdInsumo INT PRIMARY KEY, Cantidad DECIMAL(12,3));
    INSERT INTO @Consumo (IdInsumo, Cantidad)
    SELECT x.IdInsumo, SUM(x.Cantidad)
    FROM (
        SELECT porLinea.Linea, porLinea.IdInsumo,
               CASE WHEN SUM(porLinea.Cantidad) > 0 THEN SUM(porLinea.Cantidad) ELSE 0 END * MAX(l.Cantidad) AS Cantidad
        FROM (
            SELECT l.Linea, r.IdInsumo, r.Cantidad
            FROM @Lineas l INNER JOIN RECETA r ON r.IdProducto = l.IdProducto
            WHERE NOT EXISTS (SELECT 1 FROM @Quitados q WHERE q.Linea = l.Linea AND q.IdInsumo = r.IdInsumo)
            UNION ALL
            SELECT lm.Linea, m.IdInsumo, m.Cantidad
            FROM @Modificadores lm INNER JOIN MODIFICADOR m ON m.IdModificador = lm.IdModificador
            WHERE m.IdInsumo IS NOT NULL
        ) porLinea
        INNER JOIN @Lineas l ON l.Linea = porLinea.Linea
        GROUP BY porLinea.Linea, porLinea.IdInsumo
    ) x
    GROUP BY x.IdInsumo
    HAVING SUM(x.Cantidad) > 0;

    BEGIN TRY
        BEGIN TRANSACTION;
        SET @IdCaja=NULL;
        SELECT @IdCaja=IdCaja FROM CAJA WITH(UPDLOCK,HOLDLOCK) WHERE IdSede=@IdSede AND Estado='ABIERTA';
        IF @IdCaja IS NULL THROW 50001,'La caja ya se cerró; abra una caja para vender',1;
        IF @IdVenta>0 AND NOT EXISTS(SELECT 1 FROM VENTA WITH(UPDLOCK,HOLDLOCK) WHERE IdVenta=@IdVenta AND IdSede=@IdSede AND IdCaja=@IdCaja AND Anulada=0) THROW 50001,'El pedido no pertenece a la caja abierta o está anulado',1;
        IF @IdVenta = 0
        BEGIN
            INSERT INTO VENTA (IdSede, IdCaja, IdUsuario, TipoPedido, ClienteNombre, ClienteTelefono, Direccion,
                               Subtotal, CostoDomicilio, Total, MetodoPago, MontoRecibido, Cambio, EstadoPedido, EstadoCocina, Cajas, MontoTransferencia)
            VALUES (@IdSede, @IdCaja, @IdUsuario, @TipoPedido, NULLIF(@ClienteNombre, ''), NULLIF(@ClienteTelefono, ''),
                    NULLIF(@Direccion, ''), @Subtotal, @CostoDomicilio, @Total, @MetodoPago, @MontoRecibido,
                    @MontoRecibido - (@Total - @MontoTransferencia), CASE WHEN @TipoPedido = 'DOMICILIO' THEN 'PENDIENTE' ELSE 'ENTREGADO' END, 'PENDIENTE', @Cajas, @MontoTransferencia);
            SET @IdVenta = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            -- Bloquea el pedido y vuelve a validar dentro de la transacción
            IF dbo.FN_VENTA_SEGUNDOS_EDICION(@IdVenta) <= 0
                THROW 50002, 'Este pedido ya no se puede editar: pasó el tiempo permitido o cocina ya lo empezó', 1;
            DECLARE @ObsDev VARCHAR(250) = 'Edición venta #' + CAST(@IdVenta AS VARCHAR(10));
            EXEC SP_VENTA_DEVOLVER_INSUMOS @IdSede, @IdVenta, @IdUsuario, @ObsDev;
            DELETE dm FROM DETALLE_MODIFICADOR dm INNER JOIN DETALLE_VENTA d ON d.IdDetalle = dm.IdDetalle WHERE d.IdVenta = @IdVenta;
            DELETE FROM DETALLE_VENTA WHERE IdVenta = @IdVenta;
            UPDATE VENTA SET TipoPedido = @TipoPedido, ClienteNombre = NULLIF(@ClienteNombre, ''),
                   ClienteTelefono = NULLIF(@ClienteTelefono, ''), Direccion = NULLIF(@Direccion, ''),
                   Subtotal = @Subtotal, CostoDomicilio = @CostoDomicilio, Total = @Total, MetodoPago = @MetodoPago,
                   MontoRecibido = @MontoRecibido, Cambio = @MontoRecibido - (@Total - @MontoTransferencia), MontoTransferencia = @MontoTransferencia,
                   EstadoPedido = CASE WHEN @TipoPedido = 'DOMICILIO' THEN 'PENDIENTE' ELSE 'ENTREGADO' END,
                   FechaEdicion = GETDATE(), Cajas = @Cajas
            WHERE IdVenta = @IdVenta;
        END

        DECLARE @Mapa TABLE (Linea INT, IdDetalle INT);
        MERGE DETALLE_VENTA AS d
        USING (SELECT l.Linea, l.IdProducto, l.Cantidad, pr.Precio, l.Notas
               FROM @Lineas l INNER JOIN @Precios pr ON pr.Linea = l.Linea) AS s
        ON 1 = 0
        WHEN NOT MATCHED THEN
            INSERT (IdVenta, IdProducto, Cantidad, PrecioUnitario, Subtotal, Notas)
            VALUES (@IdVenta, s.IdProducto, s.Cantidad, s.Precio, s.Precio * s.Cantidad, NULLIF(s.Notas, ''))
        OUTPUT s.Linea, inserted.IdDetalle INTO @Mapa;

        INSERT INTO DETALLE_MODIFICADOR (IdDetalle, IdModificador, Precio)
        SELECT DISTINCT mp.IdDetalle, m.IdModificador, m.Precio
        FROM @Modificadores lm
        INNER JOIN @Mapa mp ON mp.Linea = lm.Linea
        INNER JOIN MODIFICADOR m ON m.IdModificador = lm.IdModificador;

        INSERT INTO DETALLE_QUITADO (IdDetalle, IdInsumo)
        SELECT DISTINCT mp.IdDetalle, q.IdInsumo
        FROM @Quitados q INNER JOIN @Mapa mp ON mp.Linea = q.Linea;

        DECLARE @IdInsumo INT, @Cant DECIMAL(12,3), @Costo DECIMAL(12,2), @Delta DECIMAL(12,3), @Disp DECIMAL(12,3), @ObsLinea VARCHAR(250),
                @Obs VARCHAR(250) = 'Venta #' + CAST(@IdVenta AS VARCHAR(10));
        DECLARE c CURSOR LOCAL FAST_FORWARD FOR
            SELECT c.IdInsumo, c.Cantidad, i.CostoUnitario FROM @Consumo c INNER JOIN INSUMO i ON i.IdInsumo = c.IdInsumo
            -- Yesenia Quejada Rojas - Claude - 28/10/2026: los insumos que no controlan stock (porciones preparadas) no se descuentan ni bloquean la venta.
            WHERE i.ControlaStock = 1;
        OPEN c;
        FETCH NEXT FROM c INTO @IdInsumo, @Cant, @Costo;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Yesenia Quejada Rojas - Claude — 26/11/2026: se descuenta SIEMPRE la cantidad completa, aunque el stock quede en negativo.
            -- Antes se descontaba solo lo que había y el faltante se perdía (al entrar la compra el sistema quedaba con más de lo real).
            -- El negativo indica lo que falta por contar o por registrar como compra; la venta nunca se bloquea.
            SET @Disp = ISNULL((SELECT Stock FROM INSUMO_SEDE WITH (UPDLOCK, HOLDLOCK) WHERE IdSede = @IdSede AND IdInsumo = @IdInsumo), 0);
            SET @Delta = -@Cant;
            SET @ObsLinea = @Obs + CASE WHEN @Cant > @Disp
                THEN ' (faltaron ' + CAST(CAST(@Cant - CASE WHEN @Disp > 0 THEN @Disp ELSE 0 END AS DECIMAL(12,3)) AS VARCHAR(20))
                     + '; quedó en ' + CAST(CAST(@Disp - @Cant AS DECIMAL(12,3)) AS VARCHAR(20)) + ', revise el inventario)'
                ELSE '' END;
            EXEC SP_STOCK_APLICAR @IdSede, @IdInsumo, 'VENTA', @Delta, @Costo, 0, @IdVenta, @ObsLinea, @IdUsuario, NULL;
            FETCH NEXT FROM c INTO @IdInsumo, @Cant, @Costo;
        END
        CLOSE c; DEALLOCATE c;

        COMMIT;
        SET @Resultado = @IdVenta;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0; SET @Mensaje = ERROR_MESSAGE();
    END CATCH
END

GO


SET NOEXEC OFF;
GO
