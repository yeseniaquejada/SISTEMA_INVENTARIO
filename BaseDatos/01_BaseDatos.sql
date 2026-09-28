/* =============================================================
   SISTEMA DE INVENTARIO - LOCAL DE COMIDAS RÁPIDAS
   Script de base de datos para SQL Server (2017 o superior, usa STRING_AGG)
   Ejecutar completo en SQL Server Management Studio.
   ============================================================= */

IF DB_ID('DB_INVENTARIO_COMIDAS') IS NULL
    CREATE DATABASE DB_INVENTARIO_COMIDAS;
GO
USE DB_INVENTARIO_COMIDAS;
GO

/* ------------------------- TABLAS ------------------------- */

CREATE TABLE ROL (
    IdRol        INT IDENTITY(1,1) PRIMARY KEY,
    Descripcion  VARCHAR(50) NOT NULL
);

CREATE TABLE USUARIO (
    IdUsuario     INT IDENTITY(1,1) PRIMARY KEY,
    NombreCompleto VARCHAR(100) NOT NULL,
    Usuario       VARCHAR(50)  NOT NULL UNIQUE,
    Clave         VARCHAR(200) NOT NULL,       -- hash PBKDF2 (sal.hash en Base64)
    IdRol         INT NOT NULL REFERENCES ROL(IdRol),
    Activo        BIT NOT NULL DEFAULT 1,
    FechaRegistro DATETIME NOT NULL DEFAULT GETDATE()
);

CREATE TABLE CATEGORIA (
    IdCategoria   INT IDENTITY(1,1) PRIMARY KEY,
    Descripcion   VARCHAR(100) NOT NULL UNIQUE,
    Activo        BIT NOT NULL DEFAULT 1,
    FechaRegistro DATETIME NOT NULL DEFAULT GETDATE()
);

CREATE TABLE PROVEEDOR (
    IdProveedor   INT IDENTITY(1,1) PRIMARY KEY,
    Documento     VARCHAR(20)  NOT NULL UNIQUE,  -- NIT / RUC / RUT
    RazonSocial   VARCHAR(150) NOT NULL,
    Telefono      VARCHAR(30)  NULL,
    Correo        VARCHAR(100) NULL,
    Activo        BIT NOT NULL DEFAULT 1,
    FechaRegistro DATETIME NOT NULL DEFAULT GETDATE()
);

/* Insumos: lo que se guarda en bodega (pan, carne, papas, gaseosas, salsas...) */
CREATE TABLE INSUMO (
    IdInsumo      INT IDENTITY(1,1) PRIMARY KEY,
    Codigo        VARCHAR(30)  NOT NULL UNIQUE,
    Nombre        VARCHAR(100) NOT NULL,
    IdCategoria   INT NOT NULL REFERENCES CATEGORIA(IdCategoria),
    UnidadMedida  VARCHAR(20)  NOT NULL,          -- UND, KG, GR, LT, ML
    Stock         DECIMAL(12,3) NOT NULL DEFAULT 0,
    StockMinimo   DECIMAL(12,3) NOT NULL DEFAULT 0,
    CostoUnitario DECIMAL(12,2) NOT NULL DEFAULT 0,
    Activo        BIT NOT NULL DEFAULT 1,
    FechaRegistro DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT CK_INSUMO_STOCK CHECK (Stock >= 0)
);

/* Kardex: cada entrada/salida queda registrada */
CREATE TABLE MOVIMIENTO (
    IdMovimiento  INT IDENTITY(1,1) PRIMARY KEY,
    IdInsumo      INT NOT NULL REFERENCES INSUMO(IdInsumo),
    Tipo          VARCHAR(10) NOT NULL,  -- ENTRADA | SALIDA | MERMA | VENTA
    Cantidad      DECIMAL(12,3) NOT NULL,
    CostoUnitario DECIMAL(12,2) NOT NULL DEFAULT 0,
    StockAnterior DECIMAL(12,3) NOT NULL,
    StockNuevo    DECIMAL(12,3) NOT NULL,
    IdProveedor   INT NULL REFERENCES PROVEEDOR(IdProveedor),
    IdVenta       INT NULL,
    Observacion   VARCHAR(250) NULL,
    IdUsuario     INT NOT NULL REFERENCES USUARIO(IdUsuario),
    Fecha         DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT CK_MOV_TIPO CHECK (Tipo IN ('ENTRADA','SALIDA','MERMA','VENTA')),
    CONSTRAINT CK_MOV_CANT CHECK (Cantidad > 0)
);

/* Productos del menú (hamburguesa, perro caliente, combo...) */
CREATE TABLE PRODUCTO_MENU (
    IdProducto    INT IDENTITY(1,1) PRIMARY KEY,
    Nombre        VARCHAR(100) NOT NULL UNIQUE,
    Precio        DECIMAL(12,2) NOT NULL,
    Activo        BIT NOT NULL DEFAULT 1,
    FechaRegistro DATETIME NOT NULL DEFAULT GETDATE()
);

/* Receta: cuánto insumo consume cada producto del menú */
CREATE TABLE RECETA (
    IdReceta      INT IDENTITY(1,1) PRIMARY KEY,
    IdProducto    INT NOT NULL REFERENCES PRODUCTO_MENU(IdProducto) ON DELETE CASCADE,
    IdInsumo      INT NOT NULL REFERENCES INSUMO(IdInsumo),
    Cantidad      DECIMAL(12,3) NOT NULL CHECK (Cantidad > 0),
    CONSTRAINT UQ_RECETA UNIQUE (IdProducto, IdInsumo)
);

CREATE TABLE VENTA (
    IdVenta       INT IDENTITY(1,1) PRIMARY KEY,
    IdUsuario     INT NOT NULL REFERENCES USUARIO(IdUsuario),
    Total         DECIMAL(12,2) NOT NULL,
    Fecha         DATETIME NOT NULL DEFAULT GETDATE()
);

CREATE TABLE DETALLE_VENTA (
    IdDetalle     INT IDENTITY(1,1) PRIMARY KEY,
    IdVenta       INT NOT NULL REFERENCES VENTA(IdVenta),
    IdProducto    INT NOT NULL REFERENCES PRODUCTO_MENU(IdProducto),
    Cantidad      INT NOT NULL CHECK (Cantidad > 0),
    PrecioUnitario DECIMAL(12,2) NOT NULL,
    Subtotal      DECIMAL(12,2) NOT NULL
);

ALTER TABLE MOVIMIENTO ADD CONSTRAINT FK_MOV_VENTA FOREIGN KEY (IdVenta) REFERENCES VENTA(IdVenta);
GO

/* Tipo tabla para enviar el detalle de venta desde C# */
CREATE TYPE EDetalleVenta AS TABLE (
    IdProducto INT,
    Cantidad   INT
);
GO

/* Tipo tabla para enviar la receta desde C# */
CREATE TYPE EReceta AS TABLE (
    IdInsumo INT,
    Cantidad DECIMAL(12,3)
);
GO

/* ------------------- PROCEDIMIENTOS: USUARIO ------------------- */

CREATE PROCEDURE SP_USUARIO_OBTENER (@Usuario VARCHAR(50))
AS
BEGIN
    SELECT u.IdUsuario, u.NombreCompleto, u.Usuario, u.Clave, u.IdRol, r.Descripcion AS Rol, u.Activo
    FROM USUARIO u INNER JOIN ROL r ON r.IdRol = u.IdRol
    WHERE u.Usuario = @Usuario;
END
GO

/* ------------------- PROCEDIMIENTOS: CATEGORÍA ------------------- */

CREATE PROCEDURE SP_CATEGORIA_LISTAR
AS
    SELECT IdCategoria, Descripcion, Activo FROM CATEGORIA ORDER BY Descripcion;
GO

CREATE PROCEDURE SP_CATEGORIA_GUARDAR (
    @IdCategoria INT, @Descripcion VARCHAR(100), @Activo BIT,
    @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET @Resultado = 0; SET @Mensaje = '';
    IF EXISTS (SELECT 1 FROM CATEGORIA WHERE Descripcion = @Descripcion AND IdCategoria <> @IdCategoria)
    BEGIN SET @Mensaje = 'Ya existe una categoría con esa descripción'; RETURN; END

    IF @IdCategoria = 0
    BEGIN
        INSERT INTO CATEGORIA (Descripcion, Activo) VALUES (@Descripcion, @Activo);
        SET @Resultado = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE CATEGORIA SET Descripcion = @Descripcion, Activo = @Activo WHERE IdCategoria = @IdCategoria;
        SET @Resultado = @IdCategoria;
    END
END
GO

CREATE PROCEDURE SP_CATEGORIA_ELIMINAR (@IdCategoria INT, @Resultado BIT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET @Resultado = 0; SET @Mensaje = '';
    IF EXISTS (SELECT 1 FROM INSUMO WHERE IdCategoria = @IdCategoria)
    BEGIN SET @Mensaje = 'La categoría tiene insumos asociados. Puede desactivarla.'; RETURN; END
    DELETE FROM CATEGORIA WHERE IdCategoria = @IdCategoria;
    SET @Resultado = 1;
END
GO

/* ------------------- PROCEDIMIENTOS: PROVEEDOR ------------------- */

CREATE PROCEDURE SP_PROVEEDOR_LISTAR
AS
    SELECT IdProveedor, Documento, RazonSocial, Telefono, Correo, Activo FROM PROVEEDOR ORDER BY RazonSocial;
GO

CREATE PROCEDURE SP_PROVEEDOR_GUARDAR (
    @IdProveedor INT, @Documento VARCHAR(20), @RazonSocial VARCHAR(150),
    @Telefono VARCHAR(30), @Correo VARCHAR(100), @Activo BIT,
    @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET @Resultado = 0; SET @Mensaje = '';
    IF EXISTS (SELECT 1 FROM PROVEEDOR WHERE Documento = @Documento AND IdProveedor <> @IdProveedor)
    BEGIN SET @Mensaje = 'Ya existe un proveedor con ese documento'; RETURN; END

    IF @IdProveedor = 0
    BEGIN
        INSERT INTO PROVEEDOR (Documento, RazonSocial, Telefono, Correo, Activo)
        VALUES (@Documento, @RazonSocial, @Telefono, @Correo, @Activo);
        SET @Resultado = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE PROVEEDOR SET Documento = @Documento, RazonSocial = @RazonSocial, Telefono = @Telefono,
               Correo = @Correo, Activo = @Activo
        WHERE IdProveedor = @IdProveedor;
        SET @Resultado = @IdProveedor;
    END
END
GO

CREATE PROCEDURE SP_PROVEEDOR_ELIMINAR (@IdProveedor INT, @Resultado BIT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET @Resultado = 0; SET @Mensaje = '';
    IF EXISTS (SELECT 1 FROM MOVIMIENTO WHERE IdProveedor = @IdProveedor)
    BEGIN SET @Mensaje = 'El proveedor tiene movimientos registrados. Puede desactivarlo.'; RETURN; END
    DELETE FROM PROVEEDOR WHERE IdProveedor = @IdProveedor;
    SET @Resultado = 1;
END
GO

/* ------------------- PROCEDIMIENTOS: INSUMO ------------------- */

CREATE PROCEDURE SP_INSUMO_LISTAR
AS
    SELECT i.IdInsumo, i.Codigo, i.Nombre, i.IdCategoria, c.Descripcion AS Categoria, i.UnidadMedida,
           i.Stock, i.StockMinimo, i.CostoUnitario, i.Activo
    FROM INSUMO i INNER JOIN CATEGORIA c ON c.IdCategoria = i.IdCategoria
    ORDER BY i.Nombre;
GO

CREATE PROCEDURE SP_INSUMO_GUARDAR (
    @IdInsumo INT, @Codigo VARCHAR(30), @Nombre VARCHAR(100), @IdCategoria INT,
    @UnidadMedida VARCHAR(20), @StockMinimo DECIMAL(12,3), @CostoUnitario DECIMAL(12,2), @Activo BIT,
    @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET @Resultado = 0; SET @Mensaje = '';
    IF EXISTS (SELECT 1 FROM INSUMO WHERE Codigo = @Codigo AND IdInsumo <> @IdInsumo)
    BEGIN SET @Mensaje = 'Ya existe un insumo con ese código'; RETURN; END

    -- El stock no se edita aquí: solo cambia con movimientos (entradas, salidas, ventas)
    IF @IdInsumo = 0
    BEGIN
        INSERT INTO INSUMO (Codigo, Nombre, IdCategoria, UnidadMedida, StockMinimo, CostoUnitario, Activo)
        VALUES (@Codigo, @Nombre, @IdCategoria, @UnidadMedida, @StockMinimo, @CostoUnitario, @Activo);
        SET @Resultado = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE INSUMO SET Codigo = @Codigo, Nombre = @Nombre, IdCategoria = @IdCategoria,
               UnidadMedida = @UnidadMedida, StockMinimo = @StockMinimo, CostoUnitario = @CostoUnitario,
               Activo = @Activo
        WHERE IdInsumo = @IdInsumo;
        SET @Resultado = @IdInsumo;
    END
END
GO

CREATE PROCEDURE SP_INSUMO_ELIMINAR (@IdInsumo INT, @Resultado BIT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET @Resultado = 0; SET @Mensaje = '';
    IF EXISTS (SELECT 1 FROM MOVIMIENTO WHERE IdInsumo = @IdInsumo)
       OR EXISTS (SELECT 1 FROM RECETA WHERE IdInsumo = @IdInsumo)
    BEGIN SET @Mensaje = 'El insumo tiene movimientos o está en una receta. Puede desactivarlo.'; RETURN; END
    DELETE FROM INSUMO WHERE IdInsumo = @IdInsumo;
    SET @Resultado = 1;
END
GO

/* ------------------- PROCEDIMIENTOS: MOVIMIENTOS ------------------- */

/* Entrada (compra), Salida (consumo interno) o Merma (daño/vencimiento) */
CREATE PROCEDURE SP_MOVIMIENTO_REGISTRAR (
    @IdInsumo INT, @Tipo VARCHAR(10), @Cantidad DECIMAL(12,3), @CostoUnitario DECIMAL(12,2),
    @IdProveedor INT, @Observacion VARCHAR(250), @IdUsuario INT,
    @Resultado BIT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET NOCOUNT ON;
    SET @Resultado = 0; SET @Mensaje = '';
    DECLARE @StockActual DECIMAL(12,3), @StockNuevo DECIMAL(12,3);

    IF @Tipo NOT IN ('ENTRADA','SALIDA','MERMA')
    BEGIN SET @Mensaje = 'Tipo de movimiento no válido'; RETURN; END

    BEGIN TRY
        BEGIN TRANSACTION;
        SELECT @StockActual = Stock FROM INSUMO WITH (UPDLOCK, ROWLOCK) WHERE IdInsumo = @IdInsumo;

        IF @StockActual IS NULL
        BEGIN SET @Mensaje = 'El insumo no existe'; ROLLBACK; RETURN; END

        IF @Tipo = 'ENTRADA'
            SET @StockNuevo = @StockActual + @Cantidad;
        ELSE
        BEGIN
            IF @Cantidad > @StockActual
            BEGIN SET @Mensaje = 'Stock insuficiente. Disponible: ' + CAST(@StockActual AS VARCHAR(20)); ROLLBACK; RETURN; END
            SET @StockNuevo = @StockActual - @Cantidad;
        END

        UPDATE INSUMO SET Stock = @StockNuevo,
               CostoUnitario = CASE WHEN @Tipo = 'ENTRADA' AND @CostoUnitario > 0 THEN @CostoUnitario ELSE CostoUnitario END
        WHERE IdInsumo = @IdInsumo;

        INSERT INTO MOVIMIENTO (IdInsumo, Tipo, Cantidad, CostoUnitario, StockAnterior, StockNuevo, IdProveedor, Observacion, IdUsuario)
        VALUES (@IdInsumo, @Tipo, @Cantidad, @CostoUnitario, @StockActual, @StockNuevo,
                NULLIF(@IdProveedor, 0), @Observacion, @IdUsuario);

        COMMIT;
        SET @Resultado = 1;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Mensaje = ERROR_MESSAGE();
    END CATCH
END
GO

CREATE PROCEDURE SP_MOVIMIENTO_LISTAR (@FechaInicio DATE, @FechaFin DATE, @IdInsumo INT = 0)
AS
    SELECT m.IdMovimiento, CONVERT(VARCHAR(16), m.Fecha, 120) AS Fecha, i.Nombre AS Insumo, i.UnidadMedida,
           m.Tipo, m.Cantidad, m.CostoUnitario, m.StockAnterior, m.StockNuevo,
           ISNULL(p.RazonSocial, '') AS Proveedor, ISNULL(m.Observacion, '') AS Observacion,
           u.NombreCompleto AS Usuario
    FROM MOVIMIENTO m
    INNER JOIN INSUMO i ON i.IdInsumo = m.IdInsumo
    INNER JOIN USUARIO u ON u.IdUsuario = m.IdUsuario
    LEFT JOIN PROVEEDOR p ON p.IdProveedor = m.IdProveedor
    WHERE CAST(m.Fecha AS DATE) BETWEEN @FechaInicio AND @FechaFin
      AND (@IdInsumo = 0 OR m.IdInsumo = @IdInsumo)
    ORDER BY m.Fecha DESC;
GO

/* ------------------- PROCEDIMIENTOS: PRODUCTO DEL MENÚ ------------------- */

CREATE PROCEDURE SP_PRODUCTO_LISTAR
AS
    SELECT p.IdProducto, p.Nombre, p.Precio, p.Activo,
           (SELECT COUNT(*) FROM RECETA r WHERE r.IdProducto = p.IdProducto) AS TotalInsumos
    FROM PRODUCTO_MENU p ORDER BY p.Nombre;
GO

CREATE PROCEDURE SP_RECETA_LISTAR (@IdProducto INT)
AS
    SELECT r.IdInsumo, i.Nombre AS Insumo, i.UnidadMedida, r.Cantidad
    FROM RECETA r INNER JOIN INSUMO i ON i.IdInsumo = r.IdInsumo
    WHERE r.IdProducto = @IdProducto;
GO

CREATE PROCEDURE SP_PRODUCTO_GUARDAR (
    @IdProducto INT, @Nombre VARCHAR(100), @Precio DECIMAL(12,2), @Activo BIT,
    @Receta EReceta READONLY,
    @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET NOCOUNT ON;
    SET @Resultado = 0; SET @Mensaje = '';
    IF EXISTS (SELECT 1 FROM PRODUCTO_MENU WHERE Nombre = @Nombre AND IdProducto <> @IdProducto)
    BEGIN SET @Mensaje = 'Ya existe un producto con ese nombre'; RETURN; END

    BEGIN TRY
        BEGIN TRANSACTION;
        IF @IdProducto = 0
        BEGIN
            INSERT INTO PRODUCTO_MENU (Nombre, Precio, Activo) VALUES (@Nombre, @Precio, @Activo);
            SET @IdProducto = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE PRODUCTO_MENU SET Nombre = @Nombre, Precio = @Precio, Activo = @Activo WHERE IdProducto = @IdProducto;

        DELETE FROM RECETA WHERE IdProducto = @IdProducto;
        INSERT INTO RECETA (IdProducto, IdInsumo, Cantidad)
        SELECT @IdProducto, IdInsumo, SUM(Cantidad) FROM @Receta GROUP BY IdInsumo;

        COMMIT;
        SET @Resultado = @IdProducto;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0; SET @Mensaje = ERROR_MESSAGE();
    END CATCH
END
GO

CREATE PROCEDURE SP_PRODUCTO_ELIMINAR (@IdProducto INT, @Resultado BIT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET @Resultado = 0; SET @Mensaje = '';
    IF EXISTS (SELECT 1 FROM DETALLE_VENTA WHERE IdProducto = @IdProducto)
    BEGIN SET @Mensaje = 'El producto tiene ventas registradas. Puede desactivarlo.'; RETURN; END
    DELETE FROM PRODUCTO_MENU WHERE IdProducto = @IdProducto;  -- la receta se borra en cascada
    SET @Resultado = 1;
END
GO

/* ------------------- PROCEDIMIENTOS: VENTA ------------------- */

/* Registra la venta y descuenta los insumos según la receta de cada producto */
CREATE PROCEDURE SP_VENTA_REGISTRAR (
    @IdUsuario INT, @Detalle EDetalleVenta READONLY,
    @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET NOCOUNT ON;
    SET @Resultado = 0; SET @Mensaje = '';
    DECLARE @IdVenta INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Insumos necesarios para toda la venta
        DECLARE @Consumo TABLE (IdInsumo INT PRIMARY KEY, Cantidad DECIMAL(12,3));
        INSERT INTO @Consumo (IdInsumo, Cantidad)
        SELECT r.IdInsumo, SUM(r.Cantidad * d.Cantidad)
        FROM @Detalle d INNER JOIN RECETA r ON r.IdProducto = d.IdProducto
        GROUP BY r.IdInsumo;

        IF NOT EXISTS (SELECT 1 FROM @Detalle)
        BEGIN SET @Mensaje = 'La venta no tiene productos'; ROLLBACK; RETURN; END

        -- Bloquear los insumos involucrados para evitar ventas simultáneas sobre el mismo stock
        DECLARE @Bloqueo INT;
        SELECT @Bloqueo = COUNT(*) FROM INSUMO WITH (UPDLOCK, HOLDLOCK)
        WHERE IdInsumo IN (SELECT IdInsumo FROM @Consumo);

        -- Validar stock
        DECLARE @Faltante VARCHAR(4000);
        SELECT @Faltante = STRING_AGG(i.Nombre + ' (disp. ' + CAST(i.Stock AS VARCHAR(20)) + ', req. ' + CAST(c.Cantidad AS VARCHAR(20)) + ')', ', ')
        FROM @Consumo c INNER JOIN INSUMO i ON i.IdInsumo = c.IdInsumo
        WHERE i.Stock < c.Cantidad;

        IF @Faltante IS NOT NULL
        BEGIN SET @Mensaje = LEFT('Stock insuficiente: ' + @Faltante, 500); ROLLBACK; RETURN; END

        INSERT INTO VENTA (IdUsuario, Total)
        SELECT @IdUsuario, SUM(p.Precio * d.Cantidad)
        FROM @Detalle d INNER JOIN PRODUCTO_MENU p ON p.IdProducto = d.IdProducto AND p.Activo = 1;
        SET @IdVenta = SCOPE_IDENTITY();

        INSERT INTO DETALLE_VENTA (IdVenta, IdProducto, Cantidad, PrecioUnitario, Subtotal)
        SELECT @IdVenta, p.IdProducto, d.Cantidad, p.Precio, p.Precio * d.Cantidad
        FROM @Detalle d INNER JOIN PRODUCTO_MENU p ON p.IdProducto = d.IdProducto AND p.Activo = 1;

        IF @@ROWCOUNT <> (SELECT COUNT(*) FROM @Detalle)
        BEGIN SET @Mensaje = 'Hay productos inactivos o inexistentes en la venta'; ROLLBACK; RETURN; END

        -- Kardex
        INSERT INTO MOVIMIENTO (IdInsumo, Tipo, Cantidad, CostoUnitario, StockAnterior, StockNuevo, IdVenta, Observacion, IdUsuario)
        SELECT i.IdInsumo, 'VENTA', c.Cantidad, i.CostoUnitario, i.Stock, i.Stock - c.Cantidad, @IdVenta,
               'Venta #' + CAST(@IdVenta AS VARCHAR(10)), @IdUsuario
        FROM @Consumo c INNER JOIN INSUMO i ON i.IdInsumo = c.IdInsumo;

        UPDATE i SET i.Stock = i.Stock - c.Cantidad
        FROM INSUMO i INNER JOIN @Consumo c ON c.IdInsumo = i.IdInsumo;

        COMMIT;
        SET @Resultado = @IdVenta;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0; SET @Mensaje = ERROR_MESSAGE();
    END CATCH
END
GO

CREATE PROCEDURE SP_VENTA_LISTAR (@FechaInicio DATE, @FechaFin DATE)
AS
    SELECT v.IdVenta, CONVERT(VARCHAR(16), v.Fecha, 120) AS Fecha, v.Total, u.NombreCompleto AS Usuario,
           (SELECT STRING_AGG(CAST(d.Cantidad AS VARCHAR(10)) + ' x ' + p.Nombre, ', ')
              FROM DETALLE_VENTA d INNER JOIN PRODUCTO_MENU p ON p.IdProducto = d.IdProducto
             WHERE d.IdVenta = v.IdVenta) AS Detalle
    FROM VENTA v INNER JOIN USUARIO u ON u.IdUsuario = v.IdUsuario
    WHERE CAST(v.Fecha AS DATE) BETWEEN @FechaInicio AND @FechaFin
    ORDER BY v.Fecha DESC;
GO

/* ------------------- PROCEDIMIENTOS: DASHBOARD ------------------- */

CREATE PROCEDURE SP_DASHBOARD
AS
BEGIN
    SELECT
        (SELECT COUNT(*) FROM INSUMO WHERE Activo = 1) AS TotalInsumos,
        (SELECT COUNT(*) FROM INSUMO WHERE Activo = 1 AND Stock <= StockMinimo) AS InsumosBajoStock,
        (SELECT ISNULL(SUM(Stock * CostoUnitario), 0) FROM INSUMO WHERE Activo = 1) AS ValorInventario,
        (SELECT ISNULL(SUM(Total), 0) FROM VENTA WHERE CAST(Fecha AS DATE) = CAST(GETDATE() AS DATE)) AS VentasHoy,
        (SELECT COUNT(*) FROM VENTA WHERE CAST(Fecha AS DATE) = CAST(GETDATE() AS DATE)) AS PedidosHoy;

    SELECT IdInsumo, Codigo, Nombre, UnidadMedida, Stock, StockMinimo
    FROM INSUMO WHERE Activo = 1 AND Stock <= StockMinimo
    ORDER BY (Stock - StockMinimo);
END
GO

/* ------------------------- DATOS INICIALES ------------------------- */

INSERT INTO ROL (Descripcion) VALUES ('ADMINISTRADOR'), ('CAJERO');

-- Usuario: admin  /  Clave: Admin123   (cámbiela después del primer ingreso)
INSERT INTO USUARIO (NombreCompleto, Usuario, Clave, IdRol)
VALUES ('Administrador', 'admin', 'obLD1OX2BxgpOktcbX6PkA==.hu16QIR4DKgpgZnV4Z/2/kZH0zVnimm+EKQf2ZkDYQA=', 1);

INSERT INTO CATEGORIA (Descripcion) VALUES
('Panadería'), ('Carnes'), ('Lácteos'), ('Verduras'), ('Congelados'), ('Bebidas'), ('Salsas'), ('Desechables');

INSERT INTO PROVEEDOR (Documento, RazonSocial, Telefono, Correo) VALUES
('900111222', 'Panadería El Trigal', '3001112233', 'ventas@eltrigal.com'),
('900333444', 'Carnes Premium S.A.S.', '3004445566', 'pedidos@carnespremium.com'),
('900555666', 'Distribuidora de Bebidas', '3007778899', 'contacto@bebidas.com');

INSERT INTO INSUMO (Codigo, Nombre, IdCategoria, UnidadMedida, StockMinimo, CostoUnitario) VALUES
('PAN-HAM', 'Pan de hamburguesa',     1, 'UND', 30, 800),
('PAN-PER', 'Pan de perro',           1, 'UND', 30, 700),
('CAR-HAM', 'Carne de hamburguesa',   2, 'UND', 30, 2500),
('SAL-PER', 'Salchicha',              2, 'UND', 30, 1200),
('QUE-TAJ', 'Queso tajado',           3, 'UND', 40, 400),
('LEC-HOJ', 'Lechuga',                4, 'GR',  1000, 8),
('TOM',     'Tomate',                 4, 'GR',  1000, 6),
('PAP-FRA', 'Papa a la francesa',     5, 'GR',  5000, 12),
('GAS-400', 'Gaseosa 400 ml',         6, 'UND', 24, 1800),
('SAL-TOM', 'Salsa de tomate',        7, 'ML',  2000, 5),
('CAJ-HAM', 'Caja para hamburguesa',  8, 'UND', 50, 350);

INSERT INTO PRODUCTO_MENU (Nombre, Precio) VALUES
('Hamburguesa sencilla', 12000),
('Perro caliente', 9000),
('Porción de papas', 6000),
('Combo hamburguesa + papas + gaseosa', 22000);

INSERT INTO RECETA (IdProducto, IdInsumo, Cantidad) VALUES
(1, 1, 1), (1, 3, 1), (1, 5, 1), (1, 6, 20), (1, 7, 30), (1, 10, 15), (1, 11, 1),
(2, 2, 1), (2, 4, 1), (2, 10, 15),
(3, 8, 150),
(4, 1, 1), (4, 3, 1), (4, 5, 1), (4, 6, 20), (4, 7, 30), (4, 10, 25), (4, 11, 1), (4, 8, 150), (4, 9, 1);
GO

/* Inventario inicial: se carga como ENTRADA para que quede en el kardex */
DECLARE @r BIT, @m VARCHAR(500);
EXEC SP_MOVIMIENTO_REGISTRAR 1, 'ENTRADA', 100, 800, 1, 'Inventario inicial', 1, @r OUTPUT, @m OUTPUT;
EXEC SP_MOVIMIENTO_REGISTRAR 2, 'ENTRADA', 80, 700, 1, 'Inventario inicial', 1, @r OUTPUT, @m OUTPUT;
EXEC SP_MOVIMIENTO_REGISTRAR 3, 'ENTRADA', 100, 2500, 2, 'Inventario inicial', 1, @r OUTPUT, @m OUTPUT;
EXEC SP_MOVIMIENTO_REGISTRAR 4, 'ENTRADA', 80, 1200, 2, 'Inventario inicial', 1, @r OUTPUT, @m OUTPUT;
EXEC SP_MOVIMIENTO_REGISTRAR 5, 'ENTRADA', 150, 400, 0, 'Inventario inicial', 1, @r OUTPUT, @m OUTPUT;
EXEC SP_MOVIMIENTO_REGISTRAR 6, 'ENTRADA', 3000, 8, 0, 'Inventario inicial', 1, @r OUTPUT, @m OUTPUT;
EXEC SP_MOVIMIENTO_REGISTRAR 7, 'ENTRADA', 3000, 6, 0, 'Inventario inicial', 1, @r OUTPUT, @m OUTPUT;
EXEC SP_MOVIMIENTO_REGISTRAR 8, 'ENTRADA', 20000, 12, 0, 'Inventario inicial', 1, @r OUTPUT, @m OUTPUT;
EXEC SP_MOVIMIENTO_REGISTRAR 9, 'ENTRADA', 20, 1800, 3, 'Inventario inicial', 1, @r OUTPUT, @m OUTPUT;
EXEC SP_MOVIMIENTO_REGISTRAR 10, 'ENTRADA', 5000, 5, 0, 'Inventario inicial', 1, @r OUTPUT, @m OUTPUT;
EXEC SP_MOVIMIENTO_REGISTRAR 11, 'ENTRADA', 200, 350, 0, 'Inventario inicial', 1, @r OUTPUT, @m OUTPUT;
GO
