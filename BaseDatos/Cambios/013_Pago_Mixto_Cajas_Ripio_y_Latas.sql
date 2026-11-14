/* =============================================================
   013 - PAGO MIXTO, CAJAS DEL CIERRE, RIPIO POR PORCIÓN Y CERVEZA REPETIDA
   Yesenia Quejada Rojas - Claude — 13/11/2026

   1. Pago mixto (efectivo + transferencia): VENTA.MontoTransferencia.
      Con MetodoPago = EFECTIVO, MontoTransferencia es la parte del
      total pagada por transferencia; el efectivo y el cambio se
      calculan sobre el resto. Se actualizan los procedimientos de
      venta, caja (actual, cierre, reporte), ticket, lista de ventas
      y domicilios. Las ventas anteriores quedan en 0 (sin cambio).
   2. SP_CAJA_INSUMOS_VENDIDOS: al cerrar la caja solo se cuentan las
      cajas que salieron con las ventas de esa caja.
   3. Papa ripio: pasa de "bolsa" (decimales) a "porción" (20 por
      bolsa). Convierte stock, lotes, receta, costo y mínimo, y crea la
      adición "Ripio" (3.000, por confirmar el precio) en las hamburguesas.
   4. Cerveza Águila en latón (repetida): se desactivan el producto y
      el insumo; queda "Cerveza Águila".

   Se puede ejecutar más de una vez. No borra ventas ni movimientos.
   ============================================================= */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

/* ---------- 1. Columna del pago mixto ---------- */
IF COL_LENGTH('dbo.VENTA', 'MontoTransferencia') IS NULL
    ALTER TABLE dbo.VENTA ADD MontoTransferencia DECIMAL(12,2) NOT NULL
        CONSTRAINT DF_VENTA_MontoTransferencia DEFAULT (0);
GO

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
            -- Yesenia Quejada Rojas - Claude - 30/10/2026: la venta ya no depende del inventario. Se descuenta lo que haya (sin bajar de 0)
            -- y, si faltó, queda anotado en el movimiento para revisar el inventario; el producto se vende igual.
            SET @Disp = ISNULL((SELECT Stock FROM INSUMO_SEDE WITH (UPDLOCK, HOLDLOCK) WHERE IdSede = @IdSede AND IdInsumo = @IdInsumo), 0);
            SET @Delta = -(CASE WHEN @Cant <= @Disp THEN @Cant ELSE @Disp END);
            SET @ObsLinea = @Obs + CASE WHEN @Cant > @Disp THEN ' (faltaron ' + CAST(CAST(@Cant - @Disp AS DECIMAL(12,3)) AS VARCHAR(20)) + '; revise el inventario)' ELSE '' END;
            IF @Delta < 0
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

CREATE OR ALTER PROCEDURE SP_VENTA_TICKET (@IdVenta INT)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT v.IdVenta, CONVERT(VARCHAR(16), v.Fecha, 120) AS Fecha, v.TipoPedido, v.MetodoPago, v.Subtotal,
           v.CostoDomicilio, v.Total, v.MontoRecibido, v.Cambio, v.EstadoPedido, v.MontoTransferencia,
           ISNULL(v.ClienteNombre, '') AS ClienteNombre, ISNULL(v.ClienteTelefono, '') AS ClienteTelefono,
           ISNULL(v.Direccion, '') AS Direccion, u.NombreCompleto AS Usuario, s.Nombre AS Sede,
           ISNULL(s.Direccion, '') AS SedeDireccion, v.IdSede,
           v.Anulada, ISNULL(v.MotivoAnulacion, '') AS MotivoAnulacion, v.EstadoCocina,
           dbo.FN_VENTA_SEGUNDOS_EDICION(v.IdVenta) AS SegundosEdicion, v.Cajas
    FROM VENTA v
    INNER JOIN USUARIO u ON u.IdUsuario = v.IdUsuario
    INNER JOIN SEDE s ON s.IdSede = v.IdSede
    WHERE v.IdVenta = @IdVenta;

    SELECT d.IdDetalle, d.IdProducto, p.Nombre, d.Cantidad, d.PrecioUnitario, d.Subtotal, ISNULL(d.Notas, '') AS Notas
    FROM DETALLE_VENTA d INNER JOIN PRODUCTO_MENU p ON p.IdProducto = d.IdProducto
    WHERE d.IdVenta = @IdVenta
    ORDER BY d.IdDetalle;

    SELECT dm.IdDetalle, dm.IdModificador, m.Nombre, dm.Precio, m.Grupo
    FROM DETALLE_MODIFICADOR dm
    INNER JOIN DETALLE_VENTA d ON d.IdDetalle = dm.IdDetalle
    INNER JOIN MODIFICADOR m ON m.IdModificador = dm.IdModificador
    WHERE d.IdVenta = @IdVenta
    ORDER BY m.Grupo, m.Nombre;

    -- Yesenia Quejada Rojas - Claude — 19/10/2026: ingredientes que el cliente pidió quitar, para el ticket y para editar el pedido.
    SELECT dq.IdDetalle, dq.IdInsumo, i.Nombre
    FROM DETALLE_QUITADO dq
    INNER JOIN DETALLE_VENTA d ON d.IdDetalle = dq.IdDetalle
    INNER JOIN INSUMO i ON i.IdInsumo = dq.IdInsumo
    WHERE d.IdVenta = @IdVenta
    ORDER BY i.Nombre;
END

GO

CREATE OR ALTER PROCEDURE SP_VENTA_LISTAR (@IdSede INT, @FechaInicio DATE, @FechaFin DATE)
AS
    SELECT v.IdVenta, CONVERT(VARCHAR(16), v.Fecha, 120) AS Fecha, v.TipoPedido, v.MetodoPago, v.Total,
           v.EstadoPedido, ISNULL(v.ClienteNombre, '') AS ClienteNombre, u.NombreCompleto AS Usuario,
           (SELECT STRING_AGG(CAST(d.Cantidad AS VARCHAR(10)) + ' x ' + p.Nombre, ', ')
              FROM DETALLE_VENTA d INNER JOIN PRODUCTO_MENU p ON p.IdProducto = d.IdProducto
             WHERE d.IdVenta = v.IdVenta) AS Detalle,
           v.Anulada, ISNULL(v.MotivoAnulacion, '') AS MotivoAnulacion, v.EstadoCocina,
           dbo.FN_VENTA_SEGUNDOS_EDICION(v.IdVenta) AS SegundosEdicion,
           CAST(CASE WHEN c.Estado = 'ABIERTA' THEN 1 ELSE 0 END AS BIT) AS CajaAbierta,
           -- Yesenia Quejada Rojas - Claude — 30/10/2026: si ya entró el pago de Rappi o de la transferencia.
           v.PagoConfirmado, ISNULL(CONVERT(VARCHAR(16), v.FechaPagoConfirmado, 120), '') AS FechaPagoConfirmado,
           -- Yesenia Quejada Rojas - Claude — 31/10/2026: cajas de empaque.
           v.Cajas, v.MontoTransferencia
    FROM VENTA v
    INNER JOIN USUARIO u ON u.IdUsuario = v.IdUsuario
    INNER JOIN CAJA c ON c.IdCaja = v.IdCaja
    WHERE v.IdSede = @IdSede AND /* Yesenia Quejada Rojas - Claude — 02/11/2026: el dia de una venta es el de la apertura de su caja (lo de despues de medianoche es del dia anterior). */ CAST(c.FechaApertura AS DATE) BETWEEN @FechaInicio AND @FechaFin
    ORDER BY v.Fecha DESC;

GO

CREATE OR ALTER PROCEDURE SP_DOMICILIO_LISTAR (@IdSede INT, @SoloPendientes BIT)
AS
BEGIN
    SET NOCOUNT ON;
    -- Yesenia Quejada Rojas - Claude — 30/10/2026: antes de listar, los domicilios vencidos avanzan solos.
    EXEC dbo.SP_DOMICILIO_AUTO @IdSede;
    SELECT v.IdVenta, CONVERT(VARCHAR(16), v.Fecha, 120) AS Fecha, v.ClienteNombre, v.ClienteTelefono, v.Direccion,
           v.Total, v.MetodoPago, v.MontoRecibido, v.Cambio, v.MontoTransferencia, v.EstadoPedido, v.EstadoCocina, ISNULL(v.Repartidor, '') AS Repartidor,
           DATEDIFF(MINUTE, v.Fecha, ISNULL(v.FechaEntrega, GETDATE())) AS Minutos,
           ISNULL(DATEDIFF(MINUTE, v.FechaDespacho, ISNULL(v.FechaEntrega, GETDATE())), 0) AS MinutosEnCamino,
           ISNULL(CONVERT(VARCHAR(5), v.FechaDespacho, 108), '') AS HoraDespacho,
           ISNULL(CONVERT(VARCHAR(5), v.FechaEntrega, 108), '') AS HoraEntrega,
           (SELECT STRING_AGG(CAST(d.Cantidad AS VARCHAR(10)) + ' x ' + p.Nombre, ', ')
              FROM DETALLE_VENTA d INNER JOIN PRODUCTO_MENU p ON p.IdProducto = d.IdProducto
             WHERE d.IdVenta = v.IdVenta) AS Detalle
    FROM VENTA v
    WHERE v.IdSede = @IdSede AND v.TipoPedido = 'DOMICILIO' AND v.Anulada = 0
      AND (@SoloPendientes = 0 AND /* Yesenia Quejada Rojas - Claude — 02/11/2026: el dia de una venta es el de la apertura de su caja (lo de despues de medianoche es del dia anterior). */ v.IdCaja IN (SELECT IdCaja FROM CAJA WHERE CAST(FechaApertura AS DATE) = ISNULL((SELECT TOP 1 CAST(FechaApertura AS DATE) FROM CAJA WHERE IdSede = @IdSede AND Estado = 'ABIERTA' ORDER BY IdCaja DESC), CAST(GETDATE() AS DATE))) OR @SoloPendientes = 1 AND v.EstadoPedido <> 'ENTREGADO')
    ORDER BY CASE v.EstadoPedido WHEN 'PENDIENTE' THEN 0 WHEN 'EN_CAMINO' THEN 1 ELSE 2 END, v.Fecha;
END

GO

CREATE OR ALTER PROCEDURE SP_CAJA_ACTUAL (@IdSede INT)
AS
BEGIN
    -- Yesenia Quejada Rojas - Claude - 30/10/2026: los domicilios vencidos avanzan solos antes de contarlos.
    EXEC dbo.SP_DOMICILIO_AUTO @IdSede;
    SELECT dbo.FN_CAJA_FLUJO(c.IdCaja,'INGRESO') AS IngresosEfectivo, dbo.FN_CAJA_FLUJO(c.IdCaja,'EGRESO') AS EgresosEfectivo, c.IdCaja, CONVERT(VARCHAR(16), c.FechaApertura, 120) AS FechaApertura, c.BaseInicial,
           c.FondoNegocio, dbo.FN_FONDO_FLUJO(c.IdCaja,'INGRESO') AS IngresosFondo, dbo.FN_FONDO_FLUJO(c.IdCaja,'EGRESO') AS EgresosFondo,
           u.NombreCompleto AS UsuarioApertura,
           ISNULL(SUM(CASE WHEN v.Anulada = 0 AND v.MetodoPago = 'EFECTIVO' THEN v.Total - v.MontoTransferencia ELSE 0 END), 0) AS VentasEfectivo,
           ISNULL(SUM(CASE WHEN v.Anulada = 0 AND v.MetodoPago = 'TARJETA' THEN v.Total ELSE 0 END), 0) AS VentasTarjeta,
           ISNULL(SUM(CASE WHEN v.Anulada = 0 AND v.MetodoPago = 'TRANSFERENCIA' THEN v.Total WHEN v.Anulada = 0 AND v.MetodoPago = 'EFECTIVO' THEN v.MontoTransferencia ELSE 0 END), 0) AS VentasTransferencia,
    -- Yesenia Quejada Rojas - Claude - 30/10/2026: ventas pagadas en la app de Rappi (no entran al efectivo de la caja).
           ISNULL(SUM(CASE WHEN v.Anulada = 0 AND v.MetodoPago = 'RAPPI' THEN v.Total ELSE 0 END), 0) AS VentasRappi,
           ISNULL(SUM(CASE WHEN v.Anulada = 0 THEN 1 ELSE 0 END), 0) AS NumeroVentas,
           ISNULL(SUM(CASE WHEN v.Anulada = 1 THEN 1 ELSE 0 END), 0) AS NumeroAnuladas,
           ISNULL(SUM(CASE WHEN v.Anulada = 1 THEN v.Total ELSE 0 END), 0) AS TotalAnulado,
    -- Yesenia Quejada Rojas - Claude - 31/10/2026: cajas de empaque. cajas usadas en los pedidos y lo que valen (cantidad x costo del insumo "Caja de empaque").
           ISNULL(SUM(CASE WHEN v.Anulada = 0 THEN v.Cajas ELSE 0 END), 0) AS Cajas, dbo.FN_COSTO_CAJA() AS CostoCaja,
    -- Yesenia Quejada Rojas - Claude - 31/10/2026: saldo del negocio = base + todas las ventas (efectivo, tarjeta, transferencia y Rappi)
    -- + aportes - gastos (cualquier medio) + diferencia del conteo; la base de cada caja es el saldo de la anterior.
           -- Yesenia Quejada Rojas - Claude - 31/10/2026: gastos y retiros de cualquier medio; el esperado del cajon sigue usando solo EgresosEfectivo.
           ISNULL((SELECT SUM(m.Monto) FROM dbo.CAJA_MOVIMIENTO m WHERE m.IdCaja = c.IdCaja AND m.Anulado = 0 AND m.Tipo <> 'INGRESO'), 0) AS GastosTotal,
           dbo.FN_CAJA_BASE_NEGOCIO(c.IdCaja) AS BaseNegocio, dbo.FN_CAJA_BASE_NEGOCIO(c.IdCaja) + dbo.FN_CAJA_FLUJO_NEGOCIO(c.IdCaja) AS SaldoNegocio,
           ISNULL(SUM(CASE WHEN v.Anulada = 0 AND v.MetodoPago = 'EFECTIVO' AND v.TipoPedido = 'DOMICILIO'
                            AND v.EstadoPedido <> 'ENTREGADO' THEN v.Total - v.MontoTransferencia ELSE 0 END), 0) AS EfectivoEnDomicilios
    FROM CAJA c
    INNER JOIN USUARIO u ON u.IdUsuario = c.IdUsuarioApertura
    LEFT JOIN VENTA v ON v.IdCaja = c.IdCaja
    WHERE c.IdSede = @IdSede AND c.Estado = 'ABIERTA'
    GROUP BY c.IdCaja, c.FechaApertura, c.BaseInicial, c.FondoNegocio, u.NombreCompleto;
END

GO

CREATE OR ALTER PROCEDURE SP_CAJA_CERRAR (
    @IdSede INT, @IdUsuario INT, @EfectivoContado DECIMAL(12,2), @Observacion VARCHAR(250),
    @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    -- Yesenia Quejada Rojas - Claude — 30/10/2026: los domicilios vencidos avanzan solos antes de contarlos.
    EXEC dbo.SP_DOMICILIO_AUTO @IdSede;
    SET @Resultado = 0; SET @Mensaje = '';
    SET XACT_ABORT ON;
    IF @EfectivoContado < 0 BEGIN SET @Mensaje='El contado no puede ser negativo'; RETURN; END;
    BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @IdCaja INT = (SELECT IdCaja FROM CAJA WITH(UPDLOCK,HOLDLOCK) WHERE IdSede = @IdSede AND Estado = 'ABIERTA');
    IF @IdCaja IS NULL THROW 50001,'No hay una caja abierta en esta sede',1;
    -- Yesenia Quejada Rojas - Claude — 02/11/2026: ya no se bloquea el cierre por domicilios en efectivo sin entregar. Ese efectivo sigue dentro del esperado
    -- (si no esta en el cajon sale como faltante) y se anota en la observacion del cierre para explicar la diferencia.
    DECLARE @DomPend DECIMAL(12,2) = (SELECT ISNULL(SUM(Total - MontoTransferencia), 0) FROM VENTA WHERE IdCaja=@IdCaja AND Anulada=0 AND TipoPedido='DOMICILIO' AND MetodoPago='EFECTIVO' AND EstadoPedido<>'ENTREGADO');
    IF @DomPend > 0 SET @Observacion = LEFT(CONCAT(NULLIF(LTRIM(RTRIM(@Observacion)), '') + ' · ', 'Domicilios en efectivo sin entregar al cerrar: $', FORMAT(@DomPend, 'N0', 'es-CO')), 250);
    DECLARE @Ef DECIMAL(12,2), @Ta DECIMAL(12,2), @Tr DECIMAL(12,2), @Ra DECIMAL(12,2), @Base DECIMAL(12,2), @Fondo DECIMAL(12,2);
    SELECT @Ef = ISNULL(SUM(CASE WHEN MetodoPago = 'EFECTIVO' THEN Total - MontoTransferencia ELSE 0 END), 0),
           @Ta = ISNULL(SUM(CASE WHEN MetodoPago = 'TARJETA' THEN Total ELSE 0 END), 0),
           @Tr = ISNULL(SUM(CASE WHEN MetodoPago = 'TRANSFERENCIA' THEN Total WHEN MetodoPago = 'EFECTIVO' THEN MontoTransferencia ELSE 0 END), 0),
    -- Yesenia Quejada Rojas - Claude — 30/10/2026: ventas pagadas en la app de Rappi (no entran al efectivo de la caja).
           @Ra = ISNULL(SUM(CASE WHEN MetodoPago = 'RAPPI' THEN Total ELSE 0 END), 0)
    FROM VENTA WHERE IdCaja = @IdCaja AND Anulada = 0;
    SELECT @Base = BaseInicial, @Fondo = FondoNegocio FROM CAJA WHERE IdCaja = @IdCaja;
    DECLARE @Esperado decimal(12,2)=@Base+@Ef+dbo.FN_CAJA_FLUJO(@IdCaja,'INGRESO')-dbo.FN_CAJA_FLUJO(@IdCaja,'EGRESO');
    UPDATE CAJA SET Estado = 'CERRADA', IdUsuarioCierre = @IdUsuario, FechaCierre = GETDATE(),
           VentasEfectivo = @Ef, VentasTarjeta = @Ta, VentasTransferencia = @Tr, VentasRappi = @Ra,
           EfectivoEsperado = @Esperado, EfectivoContado = @EfectivoContado,
           Diferencia = @EfectivoContado - (@Esperado), Observacion = @Observacion,
           -- Yesenia Quejada Rojas - Claude — 28/10/2026: lo que queda del fondo del negocio pasa a la siguiente apertura.
           FondoFinal = @Fondo + dbo.FN_FONDO_FLUJO(@IdCaja,'INGRESO') - dbo.FN_FONDO_FLUJO(@IdCaja,'EGRESO')
    WHERE IdCaja = @IdCaja;
    -- Lo que cocina no marcó como entregado sale del tablero al cerrar
    UPDATE VENTA SET EstadoCocina = 'ENTREGADO' WHERE IdCaja = @IdCaja AND EstadoCocina <> 'ENTREGADO' AND TipoPedido <> 'DOMICILIO';
    COMMIT; SET @Resultado = @IdCaja;
    END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; SET @Resultado=0; SET @Mensaje=ERROR_MESSAGE(); END CATCH;
END

GO

CREATE OR ALTER PROCEDURE SP_CAJA_REPORTE (@IdSede INT, @IdCaja INT)
AS
BEGIN
    SELECT ISNULL(c.EfectivoEsperado,0) AS EfectivoEsperadoGuardado, dbo.FN_CAJA_FLUJO(c.IdCaja,'INGRESO') AS IngresosEfectivo, dbo.FN_CAJA_FLUJO(c.IdCaja,'EGRESO') AS EgresosEfectivo, c.IdCaja, CONVERT(VARCHAR(16), c.FechaApertura, 120) AS FechaApertura,
           c.FondoNegocio, dbo.FN_FONDO_FLUJO(c.IdCaja,'INGRESO') AS IngresosFondo, dbo.FN_FONDO_FLUJO(c.IdCaja,'EGRESO') AS EgresosFondo,
           ISNULL(CONVERT(VARCHAR(16), c.FechaCierre, 120), '') AS FechaCierre, c.Estado, c.BaseInicial,
           ua.NombreCompleto AS UsuarioApertura, ISNULL(uc.NombreCompleto, '') AS UsuarioCierre,
           ISNULL(c.EfectivoContado, 0) AS EfectivoContado, ISNULL(c.Diferencia, 0) AS Diferencia,
           ISNULL(c.Observacion, '') AS Observacion, s.Nombre AS Sede,
           ISNULL(SUM(CASE WHEN v.Anulada = 0 AND v.MetodoPago = 'EFECTIVO' THEN v.Total - v.MontoTransferencia END), 0) AS VentasEfectivo,
           ISNULL(SUM(CASE WHEN v.Anulada = 0 AND v.MetodoPago = 'TARJETA' THEN v.Total END), 0) AS VentasTarjeta,
           ISNULL(SUM(CASE WHEN v.Anulada = 0 AND v.MetodoPago = 'TRANSFERENCIA' THEN v.Total WHEN v.Anulada = 0 AND v.MetodoPago = 'EFECTIVO' THEN v.MontoTransferencia END), 0) AS VentasTransferencia,
    -- Yesenia Quejada Rojas - Claude — 30/10/2026: ventas pagadas en la app de Rappi (no entran al efectivo de la caja).
           ISNULL(SUM(CASE WHEN v.Anulada = 0 AND v.MetodoPago = 'RAPPI' THEN v.Total END), 0) AS VentasRappi,
           ISNULL(SUM(CASE WHEN v.Anulada = 0 THEN v.CostoDomicilio END), 0) AS Domicilios,
           ISNULL(SUM(CASE WHEN v.Anulada = 0 THEN 1 ELSE 0 END), 0) AS NumeroVentas,
           ISNULL(SUM(CASE WHEN v.Anulada = 1 THEN 1 ELSE 0 END), 0) AS NumeroAnuladas,
           ISNULL(SUM(CASE WHEN v.Anulada = 1 THEN v.Total END), 0) AS TotalAnulado,
    -- Yesenia Quejada Rojas - Claude — 31/10/2026: cajas de empaque. cajas gastadas en esa caja y lo que valen.
           ISNULL(SUM(CASE WHEN v.Anulada = 0 THEN v.Cajas END), 0) AS Cajas, dbo.FN_COSTO_CAJA() AS CostoCaja,
    -- Yesenia Quejada Rojas - Claude — 31/10/2026: saldo del negocio = base + todas las ventas (efectivo, tarjeta, transferencia y Rappi)
    -- + aportes − gastos (cualquier medio) + diferencia del conteo; la base de cada caja es el saldo de la anterior.
           dbo.FN_CAJA_BASE_NEGOCIO(c.IdCaja) AS BaseNegocio,
           dbo.FN_CAJA_BASE_NEGOCIO(c.IdCaja) + dbo.FN_CAJA_FLUJO_NEGOCIO(c.IdCaja) + ISNULL(c.Diferencia, 0) AS SaldoNegocio
    FROM CAJA c
    INNER JOIN SEDE s ON s.IdSede = c.IdSede
    INNER JOIN USUARIO ua ON ua.IdUsuario = c.IdUsuarioApertura
    LEFT JOIN USUARIO uc ON uc.IdUsuario = c.IdUsuarioCierre
    LEFT JOIN VENTA v ON v.IdCaja = c.IdCaja
    WHERE c.IdCaja = @IdCaja AND c.IdSede = @IdSede
    GROUP BY c.IdCaja, c.FechaApertura, c.FechaCierre, c.Estado, c.BaseInicial, c.FondoNegocio, ua.NombreCompleto, uc.NombreCompleto,
             c.EfectivoContado, c.Diferencia, c.Observacion, c.EfectivoEsperado, s.Nombre;
    SELECT p.Nombre, SUM(d.Cantidad) AS Cantidad, SUM(d.Subtotal) AS Total
    FROM DETALLE_VENTA d
    INNER JOIN VENTA v ON v.IdVenta = d.IdVenta
    INNER JOIN PRODUCTO_MENU p ON p.IdProducto = d.IdProducto
    WHERE v.IdCaja = @IdCaja AND v.IdSede = @IdSede AND v.Anulada = 0
    GROUP BY p.Nombre
    ORDER BY Cantidad DESC, p.Nombre;
    SELECT v.IdVenta, v.Total, ISNULL(v.MotivoAnulacion, '') AS MotivoAnulacion, ISNULL(u.NombreCompleto, '') AS Usuario
    FROM VENTA v LEFT JOIN USUARIO u ON u.IdUsuario = v.IdUsuarioAnula
    WHERE v.IdCaja = @IdCaja AND v.IdSede = @IdSede AND v.Anulada = 1
    ORDER BY v.IdVenta;
END

GO

/* ---------- 2. Insumos vendidos en la caja abierta (para contar solo esas cajas) ---------- */
CREATE OR ALTER PROCEDURE SP_CAJA_INSUMOS_VENDIDOS (@IdSede INT)
AS
BEGIN
    SET NOCOUNT ON;
    -- Insumos que se descontaron por ventas (no anuladas) de la caja abierta. Usa IX por IdVenta de MOVIMIENTO.
    SELECT DISTINCT m.IdInsumo
    FROM dbo.CAJA c
    INNER JOIN dbo.VENTA v ON v.IdCaja = c.IdCaja AND v.Anulada = 0
    INNER JOIN dbo.MOVIMIENTO m ON m.IdVenta = v.IdVenta AND m.Tipo = 'VENTA'
    WHERE c.IdSede = @IdSede AND c.Estado = 'ABIERTA';
END
GO
GRANT EXECUTE ON dbo.SP_CAJA_INSUMOS_VENDIDOS TO PUBLIC;
GO

/* ---------- 3. Papa ripio por porción ---------- */
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @IdRipio INT = (SELECT IdInsumo FROM dbo.INSUMO WHERE Codigo = 'RIPIO' AND UnidadMedida <> 'PORC');
    IF @IdRipio IS NOT NULL
    BEGIN
        -- 1 bolsa = 20 porciones (el supuesto que ya usaban las recetas: 0,05 bolsa por porción)
        UPDATE dbo.INSUMO_SEDE SET Stock = ROUND(Stock * 20, 0) WHERE IdInsumo = @IdRipio;
        UPDATE dbo.LOTE SET CantidadInicial = ROUND(CantidadInicial * 20, 0), CantidadDisponible = ROUND(CantidadDisponible * 20, 0) WHERE IdInsumo = @IdRipio;
        UPDATE dbo.RECETA SET Cantidad = ROUND(Cantidad * 20, 3) WHERE IdInsumo = @IdRipio;
        UPDATE dbo.MODIFICADOR SET Cantidad = ROUND(Cantidad * 20, 3) WHERE IdInsumo = @IdRipio;
        UPDATE dbo.INSUMO SET Nombre = 'Papa ripio (porción)', UnidadMedida = 'PORC', CostoUnitario = ROUND(CostoUnitario / 20, 2),
               StockMinimo = StockMinimo * 20 WHERE IdInsumo = @IdRipio;
        PRINT 'Papa ripio: convertida a porciones (x20).';
    END
    COMMIT;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
END CATCH
GO

-- Adición "Ripio" en las hamburguesas (precio 3.000: confirmar con el negocio).
IF EXISTS (SELECT 1 FROM dbo.INSUMO WHERE Codigo = 'RIPIO') AND NOT EXISTS (SELECT 1 FROM dbo.MODIFICADOR WHERE Nombre = 'Ripio' AND Grupo = 'Adiciones')
BEGIN
    BEGIN TRANSACTION;
    INSERT INTO dbo.MODIFICADOR (Nombre, Precio, IdInsumo, Cantidad, Activo, Grupo)
    SELECT 'Ripio', 3000, IdInsumo, 1, 1, 'Adiciones' FROM dbo.INSUMO WHERE Codigo = 'RIPIO';
    DECLARE @IdMod INT = SCOPE_IDENTITY();
    INSERT INTO dbo.PRODUCTO_MODIFICADOR (IdProducto, IdModificador)
    SELECT p.IdProducto, @IdMod FROM dbo.PRODUCTO_MENU p
    INNER JOIN dbo.CATEGORIA_MENU c ON c.IdCategoriaMenu = p.IdCategoriaMenu AND c.Nombre = 'Hamburguesas';
    COMMIT;
    PRINT 'Adición Ripio creada y agregada a las hamburguesas.';
END
GO

/* ---------- 4. Cerveza Águila en latón (repetida) ---------- */
UPDATE p SET Activo = 0 FROM dbo.PRODUCTO_MENU p WHERE p.Nombre LIKE 'Cerveza %guila en lat%n';
UPDATE i SET Activo = 0 FROM dbo.INSUMO i WHERE i.Codigo = 'CERAGULAT';
-- Sin notas por confirmar en lo que se desactiva.
IF OBJECT_ID('dbo.INSUMO_PENDIENTE', 'U') IS NOT NULL
    DELETE ip FROM dbo.INSUMO_PENDIENTE ip INNER JOIN dbo.INSUMO i ON i.IdInsumo = ip.IdInsumo WHERE i.Codigo = 'CERAGULAT';
GO
