/* =============================================================
   ACTUALIZACIÓN A LA VERSIÓN 3  (no borra datos)
   - Más vendidos primero y disponibilidad en el punto de venta
   - Grupos de modificadores (Salsas, Adiciones, Preferencias)
   - Pantalla de cocina (comandas) y edición/anulación con límite de tiempo
   - Domicilios con repartidor, tiempos y cliente frecuente
   - Reporte de cierre de caja

   Se puede ejecutar varias veces. En una instalación nueva ejecute
   01_BaseDatos.sql, 02_DatosIniciales.sql y luego este archivo.
   ============================================================= */
USE DB_INVENTARIO_COMIDAS;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ============================ COLUMNAS ============================ */

IF COL_LENGTH('CONFIGURACION', 'MinutosEdicion') IS NULL
    ALTER TABLE CONFIGURACION ADD MinutosEdicion INT NOT NULL CONSTRAINT DF_CONF_MIN_EDICION DEFAULT 5;
IF COL_LENGTH('CONFIGURACION', 'MinutosAlertaCocina') IS NULL
    ALTER TABLE CONFIGURACION ADD MinutosAlertaCocina INT NOT NULL CONSTRAINT DF_CONF_MIN_COCINA DEFAULT 15;
IF COL_LENGTH('CONFIGURACION', 'MinutosAlertaDomicilio') IS NULL
    ALTER TABLE CONFIGURACION ADD MinutosAlertaDomicilio INT NOT NULL CONSTRAINT DF_CONF_MIN_DOMICILIO DEFAULT 40;
IF COL_LENGTH('CONFIGURACION', 'CostoDomicilio') IS NULL
    ALTER TABLE CONFIGURACION ADD CostoDomicilio DECIMAL(12,2) NOT NULL CONSTRAINT DF_CONF_COSTO_DOMICILIO DEFAULT 0;

IF COL_LENGTH('MODIFICADOR', 'Grupo') IS NULL
    ALTER TABLE MODIFICADOR ADD Grupo VARCHAR(40) NOT NULL CONSTRAINT DF_MOD_GRUPO DEFAULT 'Adiciones';

/* Estado en cocina. Las ventas que ya existían quedan como entregadas. */
IF COL_LENGTH('VENTA', 'EstadoCocina') IS NULL
    ALTER TABLE VENTA ADD EstadoCocina VARCHAR(10) NOT NULL CONSTRAINT DF_VENTA_COCINA DEFAULT 'ENTREGADO'
        CONSTRAINT CK_VENTA_COCINA CHECK (EstadoCocina IN ('PENDIENTE','PREPARANDO','LISTO','ENTREGADO'));
IF COL_LENGTH('VENTA', 'FechaListo') IS NULL       ALTER TABLE VENTA ADD FechaListo DATETIME NULL;
IF COL_LENGTH('VENTA', 'FechaEdicion') IS NULL     ALTER TABLE VENTA ADD FechaEdicion DATETIME NULL;
IF COL_LENGTH('VENTA', 'Anulada') IS NULL          ALTER TABLE VENTA ADD Anulada BIT NOT NULL CONSTRAINT DF_VENTA_ANULADA DEFAULT 0;
IF COL_LENGTH('VENTA', 'FechaAnulacion') IS NULL   ALTER TABLE VENTA ADD FechaAnulacion DATETIME NULL;
IF COL_LENGTH('VENTA', 'IdUsuarioAnula') IS NULL   ALTER TABLE VENTA ADD IdUsuarioAnula INT NULL REFERENCES USUARIO(IdUsuario);
IF COL_LENGTH('VENTA', 'MotivoAnulacion') IS NULL  ALTER TABLE VENTA ADD MotivoAnulacion VARCHAR(150) NULL;
IF COL_LENGTH('VENTA', 'Repartidor') IS NULL       ALTER TABLE VENTA ADD Repartidor VARCHAR(60) NULL;
IF COL_LENGTH('VENTA', 'FechaDespacho') IS NULL    ALTER TABLE VENTA ADD FechaDespacho DATETIME NULL;
IF COL_LENGTH('VENTA', 'FechaEntrega') IS NULL     ALTER TABLE VENTA ADD FechaEntrega DATETIME NULL;
GO

/* Nuevo tipo de movimiento: DEVOLUCION (insumos que vuelven al editar o anular una venta) */
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_MOV_TIPO' AND definition LIKE '%DEVOLUCION%')
BEGIN
    ALTER TABLE MOVIMIENTO DROP CONSTRAINT CK_MOV_TIPO;
    ALTER TABLE MOVIMIENTO ADD CONSTRAINT CK_MOV_TIPO
        CHECK (Tipo IN ('ENTRADA','SALIDA','MERMA','VENTA','AJUSTE+','AJUSTE-','DEVOLUCION'));
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_VENTA_TELEFONO')
    CREATE INDEX IX_VENTA_TELEFONO ON VENTA (ClienteTelefono, Fecha) WHERE ClienteTelefono IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_VENTA_SEDE_FECHA')
    CREATE INDEX IX_VENTA_SEDE_FECHA ON VENTA (IdSede, Fecha);
GO

/* ============================ DATOS ============================ */

/* Salsas para elegir (no cobran ni descuentan: el consumo de salsas ya está en la receta) */
INSERT INTO MODIFICADOR (Nombre, Precio, IdInsumo, Cantidad, Grupo)
SELECT v.Nombre, 0, NULL, 0, 'Salsas'
FROM (VALUES ('Salsa de la casa'), ('Salsa rosada'), ('Salsa BBQ'), ('Salsa de piña'), ('Salsa tártara'),
             ('Salsa de ajo'), ('Mostaza miel'), ('Salsa de tomate'), ('Mayonesa'), ('Salsa picante')) v (Nombre)
WHERE NOT EXISTS (SELECT 1 FROM MODIFICADOR m WHERE m.Nombre = v.Nombre);

UPDATE MODIFICADOR SET Grupo = 'Preferencias' WHERE Nombre LIKE 'Sin %' AND Grupo = 'Adiciones';

/* Las salsas aplican a todos los productos que llevan salsas en la receta */
INSERT INTO PRODUCTO_MODIFICADOR (IdProducto, IdModificador)
SELECT p.IdProducto, m.IdModificador
FROM PRODUCTO_MENU p CROSS JOIN MODIFICADOR m
WHERE m.Grupo = 'Salsas'
  AND EXISTS (SELECT 1 FROM RECETA r INNER JOIN INSUMO i ON i.IdInsumo = r.IdInsumo
              WHERE r.IdProducto = p.IdProducto AND i.Codigo = 'SALSAS')
  AND NOT EXISTS (SELECT 1 FROM PRODUCTO_MODIFICADOR x WHERE x.IdProducto = p.IdProducto AND x.IdModificador = m.IdModificador);
GO

/* ======================= CONFIGURACIÓN ======================= */

CREATE OR ALTER PROCEDURE SP_CONFIGURACION_OBTENER
AS
    SELECT NombreNegocio, Nit, Direccion, Telefono, ColorPrimario, ColorSecundario, LogoUrl,
           SimboloMoneda, MensajeTicket, DiasAlertaVencimiento,
           MinutosEdicion, MinutosAlertaCocina, MinutosAlertaDomicilio, CostoDomicilio
    FROM CONFIGURACION WHERE IdConfiguracion = 1;
GO

CREATE OR ALTER PROCEDURE SP_CONFIGURACION_GUARDAR (
    @NombreNegocio VARCHAR(100), @Nit VARCHAR(30), @Direccion VARCHAR(150), @Telefono VARCHAR(30),
    @ColorPrimario CHAR(7), @ColorSecundario CHAR(7), @LogoUrl VARCHAR(250), @SimboloMoneda VARCHAR(5),
    @MensajeTicket VARCHAR(250), @DiasAlertaVencimiento INT,
    @MinutosEdicion INT, @MinutosAlertaCocina INT, @MinutosAlertaDomicilio INT, @CostoDomicilio DECIMAL(12,2),
    @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    UPDATE CONFIGURACION SET NombreNegocio = @NombreNegocio, Nit = @Nit, Direccion = @Direccion,
           Telefono = @Telefono, ColorPrimario = @ColorPrimario, ColorSecundario = @ColorSecundario,
           LogoUrl = @LogoUrl, SimboloMoneda = @SimboloMoneda, MensajeTicket = @MensajeTicket,
           DiasAlertaVencimiento = @DiasAlertaVencimiento, MinutosEdicion = @MinutosEdicion,
           MinutosAlertaCocina = @MinutosAlertaCocina, MinutosAlertaDomicilio = @MinutosAlertaDomicilio,
           CostoDomicilio = @CostoDomicilio
    WHERE IdConfiguracion = 1;
    SET @Resultado = 1; SET @Mensaje = '';
END
GO

/* ======================= MODIFICADORES ======================= */

CREATE OR ALTER PROCEDURE SP_MODIFICADOR_LISTAR
AS
    SELECT m.IdModificador, m.Nombre, m.Precio, ISNULL(m.IdInsumo, 0) AS IdInsumo,
           ISNULL(i.Nombre, '') AS Insumo, ISNULL(i.UnidadMedida, '') AS UnidadMedida, m.Cantidad, m.Activo, m.Grupo
    FROM MODIFICADOR m LEFT JOIN INSUMO i ON i.IdInsumo = m.IdInsumo
    ORDER BY m.Grupo, m.Nombre;
GO

CREATE OR ALTER PROCEDURE SP_MODIFICADOR_GUARDAR (
    @IdModificador INT, @Nombre VARCHAR(80), @Precio DECIMAL(12,2), @IdInsumo INT, @Cantidad DECIMAL(12,3), @Activo BIT,
    @Grupo VARCHAR(40),
    @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET @Resultado = 0; SET @Mensaje = '';
    SET @Grupo = ISNULL(NULLIF(LTRIM(RTRIM(@Grupo)), ''), 'Adiciones');
    IF EXISTS (SELECT 1 FROM MODIFICADOR WHERE Nombre = @Nombre AND IdModificador <> @IdModificador)
    BEGIN SET @Mensaje = 'Ya existe un modificador con ese nombre'; RETURN; END
    IF @IdModificador = 0
    BEGIN
        INSERT INTO MODIFICADOR (Nombre, Precio, IdInsumo, Cantidad, Activo, Grupo)
        VALUES (@Nombre, @Precio, NULLIF(@IdInsumo, 0), CASE WHEN @IdInsumo = 0 THEN 0 ELSE @Cantidad END, @Activo, @Grupo);
        SET @Resultado = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE MODIFICADOR SET Nombre = @Nombre, Precio = @Precio, IdInsumo = NULLIF(@IdInsumo, 0),
               Cantidad = CASE WHEN @IdInsumo = 0 THEN 0 ELSE @Cantidad END, Activo = @Activo, Grupo = @Grupo
        WHERE IdModificador = @IdModificador;
        SET @Resultado = @IdModificador;
    END
END
GO

/* ======================= PUNTO DE VENTA ======================= */

/* Catálogo: los más vendidos (últimos 30 días en la sede) primero, con las unidades
   que alcanzan a salir con el stock actual. Segundo resultado: modificadores. */
CREATE OR ALTER PROCEDURE SP_POS_CATALOGO (@IdSede INT = 1)
AS
BEGIN
    SELECT p.IdProducto, p.Nombre, ISNULL(p.Descripcion, '') AS Descripcion, p.IdCategoriaMenu,
           c.Nombre AS CategoriaMenu, c.Icono, p.Precio, ISNULL(p.ImagenUrl, '') AS ImagenUrl,
           ISNULL(vend.Vendidos, 0) AS Vendidos,
           disp.Disponibles
    FROM PRODUCTO_MENU p
    INNER JOIN CATEGORIA_MENU c ON c.IdCategoriaMenu = p.IdCategoriaMenu
    OUTER APPLY (SELECT SUM(d.Cantidad) AS Vendidos
                 FROM DETALLE_VENTA d INNER JOIN VENTA v ON v.IdVenta = d.IdVenta
                 WHERE d.IdProducto = p.IdProducto AND v.IdSede = @IdSede AND v.Anulada = 0
                   AND v.Fecha >= DATEADD(DAY, -30, GETDATE())) vend
    OUTER APPLY (SELECT CAST(MIN(FLOOR(ISNULL(s.Stock, 0) / r.Cantidad)) AS INT) AS Disponibles
                 FROM RECETA r LEFT JOIN INSUMO_SEDE s ON s.IdInsumo = r.IdInsumo AND s.IdSede = @IdSede
                 WHERE r.IdProducto = p.IdProducto) disp
    WHERE p.Activo = 1 AND c.Activo = 1
    ORDER BY ISNULL(vend.Vendidos, 0) DESC, c.Orden, p.Nombre;

    SELECT pm.IdProducto, m.IdModificador, m.Nombre, m.Precio, m.Grupo
    FROM PRODUCTO_MODIFICADOR pm INNER JOIN MODIFICADOR m ON m.IdModificador = pm.IdModificador
    WHERE m.Activo = 1
    ORDER BY m.Grupo, m.Precio DESC, m.Nombre;
END
GO

/* Devuelve al inventario lo que consumió una venta (neto de ediciones anteriores).
   Debe llamarse dentro de una transacción. */
CREATE OR ALTER PROCEDURE SP_VENTA_DEVOLVER_INSUMOS (@IdSede INT, @IdVenta INT, @IdUsuario INT, @Observacion VARCHAR(250))
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Neto TABLE (IdInsumo INT PRIMARY KEY, Cantidad DECIMAL(12,3), Costo DECIMAL(12,2));
    INSERT INTO @Neto
    SELECT m.IdInsumo,
           SUM(CASE WHEN m.Tipo = 'VENTA' THEN m.Cantidad ELSE -m.Cantidad END),
           MAX(m.CostoUnitario)
    FROM MOVIMIENTO m
    WHERE m.IdVenta = @IdVenta AND m.Tipo IN ('VENTA', 'DEVOLUCION')
    GROUP BY m.IdInsumo
    HAVING SUM(CASE WHEN m.Tipo = 'VENTA' THEN m.Cantidad ELSE -m.Cantidad END) > 0;

    DECLARE @IdInsumo INT, @Cant DECIMAL(12,3), @Costo DECIMAL(12,2);
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT IdInsumo, Cantidad, Costo FROM @Neto;
    OPEN c;
    FETCH NEXT FROM c INTO @IdInsumo, @Cant, @Costo;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SP_STOCK_APLICAR @IdSede, @IdInsumo, 'DEVOLUCION', @Cant, @Costo, 0, @IdVenta, @Observacion, @IdUsuario, NULL;
        FETCH NEXT FROM c INTO @IdInsumo, @Cant, @Costo;
    END
    CLOSE c; DEALLOCATE c;
END
GO

/* ¿Se puede editar o anular? Solo mientras cocina no la haya empezado, el domicilio no haya salido,
   la caja siga abierta y no haya pasado el tiempo configurado. */
CREATE OR ALTER FUNCTION FN_VENTA_SEGUNDOS_EDICION (@IdVenta INT)
RETURNS INT
AS
BEGIN
    DECLARE @Seg INT;
    SELECT @Seg = CASE WHEN v.Anulada = 0 AND v.EstadoCocina = 'PENDIENTE'
                        AND (v.TipoPedido <> 'DOMICILIO' OR v.EstadoPedido = 'PENDIENTE')
                        AND c.Estado = 'ABIERTA'
                       THEN cf.MinutosEdicion * 60 - DATEDIFF(SECOND, v.Fecha, GETDATE()) ELSE 0 END
    FROM VENTA v
    INNER JOIN CAJA c ON c.IdCaja = v.IdCaja
    CROSS JOIN CONFIGURACION cf
    WHERE v.IdVenta = @IdVenta AND cf.IdConfiguracion = 1;
    RETURN CASE WHEN ISNULL(@Seg, 0) > 0 THEN @Seg ELSE 0 END;
END
GO

/* Registra una venta nueva (@IdVenta = 0) o reemplaza el contenido de una venta que aún se puede editar. */
CREATE OR ALTER PROCEDURE SP_VENTA_REGISTRAR (
    @IdSede INT, @IdUsuario INT, @TipoPedido VARCHAR(10), @ClienteNombre VARCHAR(100), @ClienteTelefono VARCHAR(30),
    @Direccion VARCHAR(200), @CostoDomicilio DECIMAL(12,2), @MetodoPago VARCHAR(15), @MontoRecibido DECIMAL(12,2),
    @Lineas ELineaVenta READONLY, @Modificadores ELineaModificador READONLY,
    @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT, @IdVenta INT = 0)
AS
BEGIN
    SET NOCOUNT ON;
    SET @Resultado = 0; SET @Mensaje = '';
    SET @IdVenta = ISNULL(@IdVenta, 0);

    DECLARE @IdCaja INT = (SELECT IdCaja FROM CAJA WHERE IdSede = @IdSede AND Estado = 'ABIERTA');
    IF @IdCaja IS NULL BEGIN SET @Mensaje = 'Abra la caja antes de registrar ventas'; RETURN; END
    IF @IdVenta > 0
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM VENTA WHERE IdVenta = @IdVenta AND IdSede = @IdSede)
        BEGIN SET @Mensaje = 'No se encontró el pedido'; RETURN; END
        IF dbo.FN_VENTA_SEGUNDOS_EDICION(@IdVenta) <= 0
        BEGIN SET @Mensaje = 'Este pedido ya no se puede editar: pasó el tiempo permitido o cocina ya lo empezó'; RETURN; END
    END
    IF NOT EXISTS (SELECT 1 FROM @Lineas) BEGIN SET @Mensaje = 'La venta no tiene productos'; RETURN; END
    IF EXISTS (SELECT 1 FROM @Lineas l LEFT JOIN PRODUCTO_MENU p ON p.IdProducto = l.IdProducto AND p.Activo = 1 WHERE p.IdProducto IS NULL)
    BEGIN SET @Mensaje = 'Hay productos inactivos o inexistentes en la venta'; RETURN; END
    IF EXISTS (SELECT 1 FROM @Modificadores lm INNER JOIN @Lineas l ON l.Linea = lm.Linea
               LEFT JOIN PRODUCTO_MODIFICADOR pm ON pm.IdProducto = l.IdProducto AND pm.IdModificador = lm.IdModificador
               LEFT JOIN MODIFICADOR m ON m.IdModificador = lm.IdModificador AND m.Activo = 1
               WHERE pm.IdModificador IS NULL OR m.IdModificador IS NULL)
    BEGIN SET @Mensaje = 'Hay adiciones que no aplican a su producto'; RETURN; END

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

    IF @MetodoPago = 'EFECTIVO' AND @MontoRecibido < @Total
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
        IF @IdVenta = 0
        BEGIN
            INSERT INTO VENTA (IdSede, IdCaja, IdUsuario, TipoPedido, ClienteNombre, ClienteTelefono, Direccion,
                               Subtotal, CostoDomicilio, Total, MetodoPago, MontoRecibido, Cambio, EstadoPedido, EstadoCocina)
            VALUES (@IdSede, @IdCaja, @IdUsuario, @TipoPedido, NULLIF(@ClienteNombre, ''), NULLIF(@ClienteTelefono, ''),
                    NULLIF(@Direccion, ''), @Subtotal, @CostoDomicilio, @Total, @MetodoPago, @MontoRecibido,
                    @MontoRecibido - @Total, CASE WHEN @TipoPedido = 'DOMICILIO' THEN 'PENDIENTE' ELSE 'ENTREGADO' END, 'PENDIENTE');
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
                   MontoRecibido = @MontoRecibido, Cambio = @MontoRecibido - @Total,
                   EstadoPedido = CASE WHEN @TipoPedido = 'DOMICILIO' THEN 'PENDIENTE' ELSE 'ENTREGADO' END,
                   FechaEdicion = GETDATE()
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

        DECLARE @IdInsumo INT, @Cant DECIMAL(12,3), @Costo DECIMAL(12,2), @Delta DECIMAL(12,3),
                @Obs VARCHAR(250) = 'Venta #' + CAST(@IdVenta AS VARCHAR(10));
        DECLARE c CURSOR LOCAL FAST_FORWARD FOR
            SELECT c.IdInsumo, c.Cantidad, i.CostoUnitario FROM @Consumo c INNER JOIN INSUMO i ON i.IdInsumo = c.IdInsumo;
        OPEN c;
        FETCH NEXT FROM c INTO @IdInsumo, @Cant, @Costo;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @Delta = -@Cant;
            EXEC SP_STOCK_APLICAR @IdSede, @IdInsumo, 'VENTA', @Delta, @Costo, 0, @IdVenta, @Obs, @IdUsuario, NULL;
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

/* Anula una venta y devuelve los insumos. El cajero solo puede dentro del tiempo de edición;
   el administrador puede mientras la caja de esa venta siga abierta. */
CREATE OR ALTER PROCEDURE SP_VENTA_ANULAR (
    @IdSede INT, @IdVenta INT, @IdUsuario INT, @EsAdmin BIT, @Motivo VARCHAR(150),
    @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET NOCOUNT ON;
    SET @Resultado = 0; SET @Mensaje = '';
    IF ISNULL(LTRIM(@Motivo), '') = '' BEGIN SET @Mensaje = 'Indique el motivo de la anulación'; RETURN; END
    IF NOT EXISTS (SELECT 1 FROM VENTA WHERE IdVenta = @IdVenta AND IdSede = @IdSede)
    BEGIN SET @Mensaje = 'No se encontró el pedido'; RETURN; END
    IF EXISTS (SELECT 1 FROM VENTA WHERE IdVenta = @IdVenta AND Anulada = 1)
    BEGIN SET @Mensaje = 'El pedido ya está anulado'; RETURN; END
    IF NOT EXISTS (SELECT 1 FROM VENTA v INNER JOIN CAJA c ON c.IdCaja = v.IdCaja WHERE v.IdVenta = @IdVenta AND c.Estado = 'ABIERTA')
    BEGIN SET @Mensaje = 'La caja de este pedido ya se cerró; no se puede anular'; RETURN; END
    IF @EsAdmin = 0 AND dbo.FN_VENTA_SEGUNDOS_EDICION(@IdVenta) <= 0
    BEGIN SET @Mensaje = 'Pasó el tiempo permitido o cocina ya empezó el pedido. Pida al administrador que lo anule.'; RETURN; END

    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Obs VARCHAR(250) = 'Anulación venta #' + CAST(@IdVenta AS VARCHAR(10));
        EXEC SP_VENTA_DEVOLVER_INSUMOS @IdSede, @IdVenta, @IdUsuario, @Obs;
        UPDATE VENTA SET Anulada = 1, FechaAnulacion = GETDATE(), IdUsuarioAnula = @IdUsuario,
               MotivoAnulacion = @Motivo, EstadoCocina = 'ENTREGADO'
        WHERE IdVenta = @IdVenta;
        COMMIT;
        SET @Resultado = @IdVenta;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Mensaje = ERROR_MESSAGE();
    END CATCH
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
           CAST(CASE WHEN c.Estado = 'ABIERTA' THEN 1 ELSE 0 END AS BIT) AS CajaAbierta
    FROM VENTA v
    INNER JOIN USUARIO u ON u.IdUsuario = v.IdUsuario
    INNER JOIN CAJA c ON c.IdCaja = v.IdCaja
    WHERE v.IdSede = @IdSede AND CAST(v.Fecha AS DATE) BETWEEN @FechaInicio AND @FechaFin
    ORDER BY v.Fecha DESC;
GO

/* Ticket / detalle de una venta: encabezado, líneas y adiciones (3 resultados) */
CREATE OR ALTER PROCEDURE SP_VENTA_TICKET (@IdVenta INT)
AS
BEGIN
    SELECT v.IdVenta, CONVERT(VARCHAR(16), v.Fecha, 120) AS Fecha, v.TipoPedido, v.MetodoPago, v.Subtotal,
           v.CostoDomicilio, v.Total, v.MontoRecibido, v.Cambio, v.EstadoPedido,
           ISNULL(v.ClienteNombre, '') AS ClienteNombre, ISNULL(v.ClienteTelefono, '') AS ClienteTelefono,
           ISNULL(v.Direccion, '') AS Direccion, u.NombreCompleto AS Usuario, s.Nombre AS Sede,
           ISNULL(s.Direccion, '') AS SedeDireccion, v.IdSede,
           v.Anulada, ISNULL(v.MotivoAnulacion, '') AS MotivoAnulacion, v.EstadoCocina,
           dbo.FN_VENTA_SEGUNDOS_EDICION(v.IdVenta) AS SegundosEdicion
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
END
GO

/* Cliente frecuente: último nombre y dirección usados con ese teléfono */
CREATE OR ALTER PROCEDURE SP_CLIENTE_BUSCAR (@Telefono VARCHAR(30))
AS
    SELECT TOP 1 ISNULL(v.ClienteNombre, '') AS ClienteNombre, ISNULL(v.Direccion, '') AS Direccion,
           (SELECT COUNT(*) FROM VENTA x WHERE x.ClienteTelefono = @Telefono AND x.Anulada = 0) AS Pedidos,
           CONVERT(VARCHAR(10), v.Fecha, 120) AS UltimoPedido
    FROM VENTA v
    WHERE v.ClienteTelefono = @Telefono AND v.Anulada = 0
    ORDER BY v.Fecha DESC;
GO

/* ========================= COCINA ========================= */

/* Comandas activas (3 resultados: pedidos, líneas y adiciones) */
CREATE OR ALTER PROCEDURE SP_COCINA_LISTAR (@IdSede INT)
AS
BEGIN
    DECLARE @Pedidos TABLE (IdVenta INT PRIMARY KEY);
    INSERT INTO @Pedidos
    SELECT IdVenta FROM VENTA
    WHERE IdSede = @IdSede AND Anulada = 0 AND EstadoCocina <> 'ENTREGADO'
      AND Fecha >= DATEADD(HOUR, -18, GETDATE());

    SELECT v.IdVenta, CONVERT(VARCHAR(16), v.Fecha, 120) AS Fecha, v.TipoPedido, ISNULL(v.ClienteNombre, '') AS ClienteNombre,
           v.EstadoCocina, v.EstadoPedido, DATEDIFF(SECOND, v.Fecha, GETDATE()) AS Segundos,
           dbo.FN_VENTA_SEGUNDOS_EDICION(v.IdVenta) AS SegundosEdicion, v.Total,
           CAST(CASE WHEN v.FechaEdicion IS NULL THEN 0 ELSE 1 END AS BIT) AS Editada
    FROM VENTA v INNER JOIN @Pedidos x ON x.IdVenta = v.IdVenta
    ORDER BY v.Fecha;

    SELECT d.IdVenta, d.IdDetalle, p.Nombre, d.Cantidad, ISNULL(d.Notas, '') AS Notas
    FROM DETALLE_VENTA d
    INNER JOIN @Pedidos x ON x.IdVenta = d.IdVenta
    INNER JOIN PRODUCTO_MENU p ON p.IdProducto = d.IdProducto
    ORDER BY d.IdDetalle;

    SELECT dm.IdDetalle, m.Nombre, m.Grupo
    FROM DETALLE_MODIFICADOR dm
    INNER JOIN DETALLE_VENTA d ON d.IdDetalle = dm.IdDetalle
    INNER JOIN @Pedidos x ON x.IdVenta = d.IdVenta
    INNER JOIN MODIFICADOR m ON m.IdModificador = dm.IdModificador
    ORDER BY m.Grupo, m.Nombre;
END
GO

CREATE OR ALTER PROCEDURE SP_COCINA_ESTADO (@IdSede INT, @IdVenta INT, @Estado VARCHAR(10), @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET @Resultado = 0; SET @Mensaje = '';
    IF @Estado NOT IN ('PENDIENTE','PREPARANDO','LISTO','ENTREGADO') BEGIN SET @Mensaje = 'Estado no válido'; RETURN; END
    UPDATE VENTA SET EstadoCocina = @Estado,
           FechaListo = CASE WHEN @Estado = 'LISTO' THEN GETDATE() WHEN @Estado IN ('PENDIENTE','PREPARANDO') THEN NULL ELSE FechaListo END
    WHERE IdVenta = @IdVenta AND IdSede = @IdSede AND Anulada = 0;
    IF @@ROWCOUNT = 0 SET @Mensaje = 'No se encontró el pedido'; ELSE SET @Resultado = 1;
END
GO

/* ========================= DOMICILIOS ========================= */

CREATE OR ALTER PROCEDURE SP_DOMICILIO_LISTAR (@IdSede INT, @SoloPendientes BIT)
AS
    SELECT v.IdVenta, CONVERT(VARCHAR(16), v.Fecha, 120) AS Fecha, v.ClienteNombre, v.ClienteTelefono, v.Direccion,
           v.Total, v.MetodoPago, v.MontoRecibido, v.Cambio, v.EstadoPedido, v.EstadoCocina, ISNULL(v.Repartidor, '') AS Repartidor,
           DATEDIFF(MINUTE, v.Fecha, ISNULL(v.FechaEntrega, GETDATE())) AS Minutos,
           ISNULL(DATEDIFF(MINUTE, v.FechaDespacho, ISNULL(v.FechaEntrega, GETDATE())), 0) AS MinutosEnCamino,
           ISNULL(CONVERT(VARCHAR(5), v.FechaDespacho, 108), '') AS HoraDespacho,
           ISNULL(CONVERT(VARCHAR(5), v.FechaEntrega, 108), '') AS HoraEntrega,
           (SELECT STRING_AGG(CAST(d.Cantidad AS VARCHAR(10)) + ' x ' + p.Nombre, ', ')
              FROM DETALLE_VENTA d INNER JOIN PRODUCTO_MENU p ON p.IdProducto = d.IdProducto
             WHERE d.IdVenta = v.IdVenta) AS Detalle
    FROM VENTA v
    WHERE v.IdSede = @IdSede AND v.TipoPedido = 'DOMICILIO' AND v.Anulada = 0
      AND (@SoloPendientes = 0 AND CAST(v.Fecha AS DATE) = CAST(GETDATE() AS DATE) OR @SoloPendientes = 1 AND v.EstadoPedido <> 'ENTREGADO')
    ORDER BY CASE v.EstadoPedido WHEN 'PENDIENTE' THEN 0 WHEN 'EN_CAMINO' THEN 1 ELSE 2 END, v.Fecha;
GO

CREATE OR ALTER PROCEDURE SP_DOMICILIO_ESTADO (
    @IdSede INT, @IdVenta INT, @Estado VARCHAR(10), @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT,
    @Repartidor VARCHAR(60) = NULL)
AS
BEGIN
    SET @Resultado = 0; SET @Mensaje = '';
    IF @Estado NOT IN ('PENDIENTE','EN_CAMINO','ENTREGADO') BEGIN SET @Mensaje = 'Estado no válido'; RETURN; END
    IF @Estado = 'EN_CAMINO' AND ISNULL(LTRIM(@Repartidor), '') = '' BEGIN SET @Mensaje = 'Indique quién lleva el domicilio'; RETURN; END
    UPDATE VENTA SET EstadoPedido = @Estado,
           Repartidor    = CASE WHEN @Estado = 'EN_CAMINO' THEN LTRIM(RTRIM(@Repartidor)) WHEN @Estado = 'PENDIENTE' THEN NULL ELSE Repartidor END,
           FechaDespacho = CASE WHEN @Estado = 'EN_CAMINO' THEN GETDATE() WHEN @Estado = 'PENDIENTE' THEN NULL ELSE FechaDespacho END,
           FechaEntrega  = CASE WHEN @Estado = 'ENTREGADO' THEN GETDATE() ELSE NULL END,
           EstadoCocina  = CASE WHEN @Estado = 'PENDIENTE' THEN EstadoCocina ELSE 'ENTREGADO' END
    WHERE IdVenta = @IdVenta AND IdSede = @IdSede AND TipoPedido = 'DOMICILIO' AND Anulada = 0;
    IF @@ROWCOUNT = 0 SET @Mensaje = 'No se encontró el domicilio'; ELSE SET @Resultado = 1;
END
GO

CREATE OR ALTER PROCEDURE SP_REPARTIDOR_LISTAR (@IdSede INT)
AS
    SELECT DISTINCT TOP 20 Repartidor FROM VENTA
    WHERE IdSede = @IdSede AND Repartidor IS NOT NULL AND Fecha >= DATEADD(DAY, -30, GETDATE())
    ORDER BY Repartidor;
GO

/* ========================= CAJA ========================= */

CREATE OR ALTER PROCEDURE SP_CAJA_ACTUAL (@IdSede INT)
AS
BEGIN
    SELECT c.IdCaja, CONVERT(VARCHAR(16), c.FechaApertura, 120) AS FechaApertura, c.BaseInicial,
           u.NombreCompleto AS UsuarioApertura,
           ISNULL(SUM(CASE WHEN v.Anulada = 0 AND v.MetodoPago = 'EFECTIVO' THEN v.Total ELSE 0 END), 0) AS VentasEfectivo,
           ISNULL(SUM(CASE WHEN v.Anulada = 0 AND v.MetodoPago = 'TARJETA' THEN v.Total ELSE 0 END), 0) AS VentasTarjeta,
           ISNULL(SUM(CASE WHEN v.Anulada = 0 AND v.MetodoPago = 'TRANSFERENCIA' THEN v.Total ELSE 0 END), 0) AS VentasTransferencia,
           ISNULL(SUM(CASE WHEN v.Anulada = 0 THEN 1 ELSE 0 END), 0) AS NumeroVentas,
           ISNULL(SUM(CASE WHEN v.Anulada = 1 THEN 1 ELSE 0 END), 0) AS NumeroAnuladas,
           ISNULL(SUM(CASE WHEN v.Anulada = 1 THEN v.Total ELSE 0 END), 0) AS TotalAnulado,
           ISNULL(SUM(CASE WHEN v.Anulada = 0 AND v.MetodoPago = 'EFECTIVO' AND v.TipoPedido = 'DOMICILIO'
                            AND v.EstadoPedido <> 'ENTREGADO' THEN v.Total ELSE 0 END), 0) AS EfectivoEnDomicilios
    FROM CAJA c
    INNER JOIN USUARIO u ON u.IdUsuario = c.IdUsuarioApertura
    LEFT JOIN VENTA v ON v.IdCaja = c.IdCaja
    WHERE c.IdSede = @IdSede AND c.Estado = 'ABIERTA'
    GROUP BY c.IdCaja, c.FechaApertura, c.BaseInicial, u.NombreCompleto;
END
GO

CREATE OR ALTER PROCEDURE SP_CAJA_CERRAR (
    @IdSede INT, @IdUsuario INT, @EfectivoContado DECIMAL(12,2), @Observacion VARCHAR(250),
    @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET @Resultado = 0; SET @Mensaje = '';
    DECLARE @IdCaja INT = (SELECT IdCaja FROM CAJA WHERE IdSede = @IdSede AND Estado = 'ABIERTA');
    IF @IdCaja IS NULL BEGIN SET @Mensaje = 'No hay una caja abierta en esta sede'; RETURN; END

    DECLARE @Ef DECIMAL(12,2), @Ta DECIMAL(12,2), @Tr DECIMAL(12,2), @Base DECIMAL(12,2);
    SELECT @Ef = ISNULL(SUM(CASE WHEN MetodoPago = 'EFECTIVO' THEN Total ELSE 0 END), 0),
           @Ta = ISNULL(SUM(CASE WHEN MetodoPago = 'TARJETA' THEN Total ELSE 0 END), 0),
           @Tr = ISNULL(SUM(CASE WHEN MetodoPago = 'TRANSFERENCIA' THEN Total ELSE 0 END), 0)
    FROM VENTA WHERE IdCaja = @IdCaja AND Anulada = 0;
    SELECT @Base = BaseInicial FROM CAJA WHERE IdCaja = @IdCaja;

    UPDATE CAJA SET Estado = 'CERRADA', IdUsuarioCierre = @IdUsuario, FechaCierre = GETDATE(),
           VentasEfectivo = @Ef, VentasTarjeta = @Ta, VentasTransferencia = @Tr,
           EfectivoEsperado = @Base + @Ef, EfectivoContado = @EfectivoContado,
           Diferencia = @EfectivoContado - (@Base + @Ef), Observacion = @Observacion
    WHERE IdCaja = @IdCaja;
    -- Lo que cocina no marcó como entregado sale del tablero al cerrar
    UPDATE VENTA SET EstadoCocina = 'ENTREGADO' WHERE IdCaja = @IdCaja AND EstadoCocina <> 'ENTREGADO' AND TipoPedido <> 'DOMICILIO';
    SET @Resultado = @IdCaja;
END
GO

/* Reporte de cierre (3 resultados: resumen, productos vendidos, anulaciones) */
CREATE OR ALTER PROCEDURE SP_CAJA_REPORTE (@IdSede INT, @IdCaja INT)
AS
BEGIN
    SELECT c.IdCaja, CONVERT(VARCHAR(16), c.FechaApertura, 120) AS FechaApertura,
           ISNULL(CONVERT(VARCHAR(16), c.FechaCierre, 120), '') AS FechaCierre, c.Estado, c.BaseInicial,
           ua.NombreCompleto AS UsuarioApertura, ISNULL(uc.NombreCompleto, '') AS UsuarioCierre,
           ISNULL(c.EfectivoContado, 0) AS EfectivoContado, ISNULL(c.Diferencia, 0) AS Diferencia,
           ISNULL(c.Observacion, '') AS Observacion, s.Nombre AS Sede,
           ISNULL(SUM(CASE WHEN v.Anulada = 0 AND v.MetodoPago = 'EFECTIVO' THEN v.Total END), 0) AS VentasEfectivo,
           ISNULL(SUM(CASE WHEN v.Anulada = 0 AND v.MetodoPago = 'TARJETA' THEN v.Total END), 0) AS VentasTarjeta,
           ISNULL(SUM(CASE WHEN v.Anulada = 0 AND v.MetodoPago = 'TRANSFERENCIA' THEN v.Total END), 0) AS VentasTransferencia,
           ISNULL(SUM(CASE WHEN v.Anulada = 0 THEN v.CostoDomicilio END), 0) AS Domicilios,
           ISNULL(SUM(CASE WHEN v.Anulada = 0 THEN 1 ELSE 0 END), 0) AS NumeroVentas,
           ISNULL(SUM(CASE WHEN v.Anulada = 1 THEN 1 ELSE 0 END), 0) AS NumeroAnuladas,
           ISNULL(SUM(CASE WHEN v.Anulada = 1 THEN v.Total END), 0) AS TotalAnulado
    FROM CAJA c
    INNER JOIN SEDE s ON s.IdSede = c.IdSede
    INNER JOIN USUARIO ua ON ua.IdUsuario = c.IdUsuarioApertura
    LEFT JOIN USUARIO uc ON uc.IdUsuario = c.IdUsuarioCierre
    LEFT JOIN VENTA v ON v.IdCaja = c.IdCaja
    WHERE c.IdCaja = @IdCaja AND c.IdSede = @IdSede
    GROUP BY c.IdCaja, c.FechaApertura, c.FechaCierre, c.Estado, c.BaseInicial, ua.NombreCompleto, uc.NombreCompleto,
             c.EfectivoContado, c.Diferencia, c.Observacion, s.Nombre;

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

/* ========================= REPORTES Y PANEL ========================= */

CREATE OR ALTER PROCEDURE SP_REPORTE_VENTAS_DIA (@IdSede INT, @FechaInicio DATE, @FechaFin DATE)
AS
    SELECT CONVERT(VARCHAR(10), CAST(v.Fecha AS DATE), 120) AS Dia, COUNT(*) AS Pedidos, SUM(v.Total) AS Total
    FROM VENTA v
    WHERE v.IdSede = @IdSede AND v.Anulada = 0 AND CAST(v.Fecha AS DATE) BETWEEN @FechaInicio AND @FechaFin
    GROUP BY CAST(v.Fecha AS DATE)
    ORDER BY Dia;
GO

CREATE OR ALTER PROCEDURE SP_REPORTE_TOP_PRODUCTOS (@IdSede INT, @FechaInicio DATE, @FechaFin DATE)
AS
    SELECT TOP 10 p.Nombre, SUM(d.Cantidad) AS Cantidad, SUM(d.Subtotal) AS Total
    FROM DETALLE_VENTA d
    INNER JOIN VENTA v ON v.IdVenta = d.IdVenta
    INNER JOIN PRODUCTO_MENU p ON p.IdProducto = d.IdProducto
    WHERE v.IdSede = @IdSede AND v.Anulada = 0 AND CAST(v.Fecha AS DATE) BETWEEN @FechaInicio AND @FechaFin
    GROUP BY p.Nombre
    ORDER BY Cantidad DESC, Total DESC;
GO

CREATE OR ALTER PROCEDURE SP_REPORTE_RESUMEN (@IdSede INT, @FechaInicio DATE, @FechaFin DATE)
AS
BEGIN
    DECLARE @Ventas DECIMAL(14,2), @Domicilios DECIMAL(14,2), @Pedidos INT, @Costo DECIMAL(14,2), @Mermas DECIMAL(14,2);
    SELECT @Ventas = ISNULL(SUM(Total), 0), @Domicilios = ISNULL(SUM(CostoDomicilio), 0), @Pedidos = COUNT(*)
    FROM VENTA WHERE IdSede = @IdSede AND Anulada = 0 AND CAST(Fecha AS DATE) BETWEEN @FechaInicio AND @FechaFin;

    -- Costo neto: lo que salió por ventas menos lo que volvió por ediciones o anulaciones
    SELECT @Costo = ISNULL(SUM(CASE WHEN m.Tipo = 'VENTA' THEN 1 ELSE -1 END * m.Cantidad * m.CostoUnitario), 0)
    FROM MOVIMIENTO m
    WHERE m.IdSede = @IdSede AND (m.Tipo = 'VENTA' OR m.Tipo = 'DEVOLUCION' AND m.IdVenta IS NOT NULL)
      AND CAST(m.Fecha AS DATE) BETWEEN @FechaInicio AND @FechaFin;

    SELECT @Mermas = ISNULL(SUM(m.Cantidad * m.CostoUnitario), 0)
    FROM MOVIMIENTO m WHERE m.IdSede = @IdSede AND m.Tipo = 'MERMA' AND CAST(m.Fecha AS DATE) BETWEEN @FechaInicio AND @FechaFin;

    SELECT @Ventas AS Ventas, @Pedidos AS Pedidos,
           CASE WHEN @Pedidos > 0 THEN @Ventas / @Pedidos ELSE 0 END AS TicketPromedio,
           @Ventas - @Domicilios AS VentasProductos, @Costo AS CostoInsumos,
           @Ventas - @Domicilios - @Costo AS Ganancia, @Mermas AS Mermas;

    SELECT MetodoPago, COUNT(*) AS Pedidos, SUM(Total) AS Total
    FROM VENTA WHERE IdSede = @IdSede AND Anulada = 0 AND CAST(Fecha AS DATE) BETWEEN @FechaInicio AND @FechaFin
    GROUP BY MetodoPago;
END
GO

CREATE OR ALTER PROCEDURE SP_DASHBOARD (@IdSede INT)
AS
BEGIN
    DECLARE @Dias INT = (SELECT DiasAlertaVencimiento FROM CONFIGURACION WHERE IdConfiguracion = 1);
    DECLARE @Hoy DATE = CAST(GETDATE() AS DATE);

    SELECT
        (SELECT COUNT(*) FROM INSUMO WHERE Activo = 1) AS TotalInsumos,
        (SELECT COUNT(*) FROM INSUMO i LEFT JOIN INSUMO_SEDE s ON s.IdInsumo = i.IdInsumo AND s.IdSede = @IdSede
          WHERE i.Activo = 1 AND ISNULL(s.Stock, 0) <= i.StockMinimo) AS InsumosBajoStock,
        (SELECT ISNULL(SUM(s.Stock * i.CostoUnitario), 0) FROM INSUMO_SEDE s INNER JOIN INSUMO i ON i.IdInsumo = s.IdInsumo
          WHERE s.IdSede = @IdSede AND i.Activo = 1) AS ValorInventario,
        (SELECT ISNULL(SUM(Total), 0) FROM VENTA WHERE IdSede = @IdSede AND Anulada = 0 AND CAST(Fecha AS DATE) = @Hoy) AS VentasHoy,
        (SELECT COUNT(*) FROM VENTA WHERE IdSede = @IdSede AND Anulada = 0 AND CAST(Fecha AS DATE) = @Hoy) AS PedidosHoy,
        (SELECT COUNT(*) FROM VENTA WHERE IdSede = @IdSede AND Anulada = 0 AND TipoPedido = 'DOMICILIO' AND EstadoPedido <> 'ENTREGADO') AS DomiciliosPendientes,
        CAST(CASE WHEN EXISTS (SELECT 1 FROM CAJA WHERE IdSede = @IdSede AND Estado = 'ABIERTA') THEN 1 ELSE 0 END AS BIT) AS CajaAbierta;

    SELECT i.IdInsumo, i.Codigo, i.Nombre, i.UnidadMedida, ISNULL(s.Stock, 0) AS Stock, i.StockMinimo
    FROM INSUMO i LEFT JOIN INSUMO_SEDE s ON s.IdInsumo = i.IdInsumo AND s.IdSede = @IdSede
    WHERE i.Activo = 1 AND ISNULL(s.Stock, 0) <= i.StockMinimo
    ORDER BY ISNULL(s.Stock, 0) - i.StockMinimo;

    SELECT l.IdLote, i.Nombre, i.UnidadMedida, l.CantidadDisponible, CONVERT(VARCHAR(10), l.FechaVencimiento, 120) AS FechaVencimiento,
           DATEDIFF(DAY, @Hoy, l.FechaVencimiento) AS DiasRestantes
    FROM LOTE l INNER JOIN INSUMO i ON i.IdInsumo = l.IdInsumo
    WHERE l.IdSede = @IdSede AND l.CantidadDisponible > 0 AND l.FechaVencimiento IS NOT NULL
      AND l.FechaVencimiento <= DATEADD(DAY, @Dias, @Hoy)
    ORDER BY l.FechaVencimiento;
END
GO
