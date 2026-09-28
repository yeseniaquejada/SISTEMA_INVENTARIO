/* =============================================================
   SISTEMA DE INVENTARIO - LOCAL DE COMIDAS RÁPIDAS  (versión 2)
   Script de base de datos para SQL Server 2017 o superior.

   ATENCIÓN: este script BORRA y vuelve a crear la base
   DB_INVENTARIO_COMIDAS. Después ejecute 02_DatosIniciales.sql.
   ============================================================= */

USE master;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF DB_ID('DB_INVENTARIO_COMIDAS') IS NOT NULL
BEGIN
    ALTER DATABASE DB_INVENTARIO_COMIDAS SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DB_INVENTARIO_COMIDAS;
END
GO
CREATE DATABASE DB_INVENTARIO_COMIDAS;
GO
USE DB_INVENTARIO_COMIDAS;
GO

/* ============================ TABLAS ============================ */

/* Datos del negocio y apariencia del sistema (una sola fila) */
CREATE TABLE CONFIGURACION (
    IdConfiguracion  INT PRIMARY KEY DEFAULT 1 CHECK (IdConfiguracion = 1),
    NombreNegocio    VARCHAR(100) NOT NULL,
    Nit              VARCHAR(30)  NULL,
    Direccion        VARCHAR(150) NULL,
    Telefono         VARCHAR(30)  NULL,
    ColorPrimario    CHAR(7) NOT NULL DEFAULT '#C8322B',
    ColorSecundario  CHAR(7) NOT NULL DEFAULT '#1F1A17',
    LogoUrl          VARCHAR(250) NULL,
    SimboloMoneda    VARCHAR(5) NOT NULL DEFAULT '$',
    MensajeTicket    VARCHAR(250) NULL,
    DiasAlertaVencimiento INT NOT NULL DEFAULT 3
);

CREATE TABLE SEDE (
    IdSede        INT IDENTITY(1,1) PRIMARY KEY,
    Nombre        VARCHAR(100) NOT NULL UNIQUE,
    Direccion     VARCHAR(150) NULL,
    Telefono      VARCHAR(30)  NULL,
    Activo        BIT NOT NULL DEFAULT 1
);

CREATE TABLE ROL (
    IdRol        INT IDENTITY(1,1) PRIMARY KEY,
    Descripcion  VARCHAR(50) NOT NULL
);

CREATE TABLE USUARIO (
    IdUsuario      INT IDENTITY(1,1) PRIMARY KEY,
    NombreCompleto VARCHAR(100) NOT NULL,
    Usuario        VARCHAR(50)  NOT NULL UNIQUE,
    Clave          VARCHAR(200) NOT NULL,   -- hash PBKDF2 (sal.hash en Base64)
    IdRol          INT NOT NULL REFERENCES ROL(IdRol),
    IdSede         INT NOT NULL REFERENCES SEDE(IdSede),
    Activo         BIT NOT NULL DEFAULT 1,
    FechaRegistro  DATETIME NOT NULL DEFAULT GETDATE()
);

CREATE TABLE CATEGORIA (
    IdCategoria   INT IDENTITY(1,1) PRIMARY KEY,
    Descripcion   VARCHAR(100) NOT NULL UNIQUE,
    Activo        BIT NOT NULL DEFAULT 1
);

CREATE TABLE PROVEEDOR (
    IdProveedor   INT IDENTITY(1,1) PRIMARY KEY,
    Documento     VARCHAR(20)  NOT NULL UNIQUE,
    RazonSocial   VARCHAR(150) NOT NULL,
    Telefono      VARCHAR(30)  NULL,
    Correo        VARCHAR(100) NULL,
    Activo        BIT NOT NULL DEFAULT 1
);

/* Catálogo de insumos (el stock se guarda por sede en INSUMO_SEDE) */
CREATE TABLE INSUMO (
    IdInsumo      INT IDENTITY(1,1) PRIMARY KEY,
    Codigo        VARCHAR(30)  NOT NULL UNIQUE,
    Nombre        VARCHAR(100) NOT NULL,
    IdCategoria   INT NOT NULL REFERENCES CATEGORIA(IdCategoria),
    UnidadMedida  VARCHAR(20)  NOT NULL,          -- UND, PORC, KG, GR, LT, ML
    StockMinimo   DECIMAL(12,3) NOT NULL DEFAULT 0,
    CostoUnitario DECIMAL(12,2) NOT NULL DEFAULT 0,
    Activo        BIT NOT NULL DEFAULT 1
);

CREATE TABLE INSUMO_SEDE (
    IdSede    INT NOT NULL REFERENCES SEDE(IdSede),
    IdInsumo  INT NOT NULL REFERENCES INSUMO(IdInsumo),
    Stock     DECIMAL(12,3) NOT NULL DEFAULT 0 CHECK (Stock >= 0),
    PRIMARY KEY (IdSede, IdInsumo)
);

/* Kardex */
CREATE TABLE MOVIMIENTO (
    IdMovimiento  INT IDENTITY(1,1) PRIMARY KEY,
    IdSede        INT NOT NULL REFERENCES SEDE(IdSede),
    IdInsumo      INT NOT NULL REFERENCES INSUMO(IdInsumo),
    Tipo          VARCHAR(10) NOT NULL,
    Cantidad      DECIMAL(12,3) NOT NULL CHECK (Cantidad > 0),
    CostoUnitario DECIMAL(12,2) NOT NULL DEFAULT 0,
    StockAnterior DECIMAL(12,3) NOT NULL,
    StockNuevo    DECIMAL(12,3) NOT NULL,
    IdProveedor   INT NULL REFERENCES PROVEEDOR(IdProveedor),
    IdVenta       INT NULL,
    Observacion   VARCHAR(250) NULL,
    IdUsuario     INT NOT NULL REFERENCES USUARIO(IdUsuario),
    Fecha         DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT CK_MOV_TIPO CHECK (Tipo IN ('ENTRADA','SALIDA','MERMA','VENTA','AJUSTE+','AJUSTE-'))
);

/* Lotes: cada entrada crea un lote; las salidas consumen primero el lote más antiguo (FIFO) */
CREATE TABLE LOTE (
    IdLote             INT IDENTITY(1,1) PRIMARY KEY,
    IdSede             INT NOT NULL REFERENCES SEDE(IdSede),
    IdInsumo           INT NOT NULL REFERENCES INSUMO(IdInsumo),
    CantidadInicial    DECIMAL(12,3) NOT NULL,
    CantidadDisponible DECIMAL(12,3) NOT NULL CHECK (CantidadDisponible >= 0),
    FechaVencimiento   DATE NULL,
    FechaIngreso       DATETIME NOT NULL DEFAULT GETDATE(),
    IdMovimiento       INT NULL REFERENCES MOVIMIENTO(IdMovimiento)
);
CREATE INDEX IX_LOTE_DISPONIBLE ON LOTE (IdSede, IdInsumo, CantidadDisponible);

/* Menú */
CREATE TABLE CATEGORIA_MENU (
    IdCategoriaMenu INT IDENTITY(1,1) PRIMARY KEY,
    Nombre          VARCHAR(60) NOT NULL UNIQUE,
    Icono           NVARCHAR(10) NOT NULL DEFAULT N'🍽️',
    Orden           INT NOT NULL DEFAULT 0,
    Activo          BIT NOT NULL DEFAULT 1
);

CREATE TABLE PRODUCTO_MENU (
    IdProducto      INT IDENTITY(1,1) PRIMARY KEY,
    Nombre          VARCHAR(100) NOT NULL UNIQUE,
    Descripcion     VARCHAR(250) NULL,
    IdCategoriaMenu INT NOT NULL REFERENCES CATEGORIA_MENU(IdCategoriaMenu),
    Precio          DECIMAL(12,2) NOT NULL,
    ImagenUrl       VARCHAR(250) NULL,
    Activo          BIT NOT NULL DEFAULT 1
);

CREATE TABLE RECETA (
    IdProducto  INT NOT NULL REFERENCES PRODUCTO_MENU(IdProducto) ON DELETE CASCADE,
    IdInsumo    INT NOT NULL REFERENCES INSUMO(IdInsumo),
    Cantidad    DECIMAL(12,3) NOT NULL CHECK (Cantidad > 0),
    PRIMARY KEY (IdProducto, IdInsumo)
);

/* Adiciones y modificadores ("Extra queso", "Sin ensalada").
   Cantidad positiva = consume más insumo; negativa = deja de consumirlo. */
CREATE TABLE MODIFICADOR (
    IdModificador INT IDENTITY(1,1) PRIMARY KEY,
    Nombre        VARCHAR(80) NOT NULL UNIQUE,
    Precio        DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (Precio >= 0),
    IdInsumo      INT NULL REFERENCES INSUMO(IdInsumo),
    Cantidad      DECIMAL(12,3) NOT NULL DEFAULT 0,
    Activo        BIT NOT NULL DEFAULT 1
);

CREATE TABLE PRODUCTO_MODIFICADOR (
    IdProducto    INT NOT NULL REFERENCES PRODUCTO_MENU(IdProducto) ON DELETE CASCADE,
    IdModificador INT NOT NULL REFERENCES MODIFICADOR(IdModificador) ON DELETE CASCADE,
    PRIMARY KEY (IdProducto, IdModificador)
);

/* Caja: apertura y cierre por sede */
CREATE TABLE CAJA (
    IdCaja              INT IDENTITY(1,1) PRIMARY KEY,
    IdSede              INT NOT NULL REFERENCES SEDE(IdSede),
    IdUsuarioApertura   INT NOT NULL REFERENCES USUARIO(IdUsuario),
    FechaApertura       DATETIME NOT NULL DEFAULT GETDATE(),
    BaseInicial         DECIMAL(12,2) NOT NULL DEFAULT 0,
    Estado              VARCHAR(10) NOT NULL DEFAULT 'ABIERTA' CHECK (Estado IN ('ABIERTA','CERRADA')),
    IdUsuarioCierre     INT NULL REFERENCES USUARIO(IdUsuario),
    FechaCierre         DATETIME NULL,
    VentasEfectivo      DECIMAL(12,2) NULL,
    VentasTarjeta       DECIMAL(12,2) NULL,
    VentasTransferencia DECIMAL(12,2) NULL,
    EfectivoEsperado    DECIMAL(12,2) NULL,
    EfectivoContado     DECIMAL(12,2) NULL,
    Diferencia          DECIMAL(12,2) NULL,
    Observacion         VARCHAR(250) NULL
);
CREATE UNIQUE INDEX UX_CAJA_ABIERTA ON CAJA (IdSede) WHERE Estado = 'ABIERTA';

CREATE TABLE VENTA (
    IdVenta         INT IDENTITY(1,1) PRIMARY KEY,
    IdSede          INT NOT NULL REFERENCES SEDE(IdSede),
    IdCaja          INT NOT NULL REFERENCES CAJA(IdCaja),
    IdUsuario       INT NOT NULL REFERENCES USUARIO(IdUsuario),
    TipoPedido      VARCHAR(10) NOT NULL CHECK (TipoPedido IN ('MESA','LLEVAR','DOMICILIO')),
    ClienteNombre   VARCHAR(100) NULL,
    ClienteTelefono VARCHAR(30)  NULL,
    Direccion       VARCHAR(200) NULL,
    Subtotal        DECIMAL(12,2) NOT NULL,
    CostoDomicilio  DECIMAL(12,2) NOT NULL DEFAULT 0,
    Total           DECIMAL(12,2) NOT NULL,
    MetodoPago      VARCHAR(15) NOT NULL CHECK (MetodoPago IN ('EFECTIVO','TARJETA','TRANSFERENCIA')),
    MontoRecibido   DECIMAL(12,2) NOT NULL DEFAULT 0,
    Cambio          DECIMAL(12,2) NOT NULL DEFAULT 0,
    EstadoPedido    VARCHAR(10) NOT NULL DEFAULT 'ENTREGADO' CHECK (EstadoPedido IN ('PENDIENTE','EN_CAMINO','ENTREGADO')),
    Fecha           DATETIME NOT NULL DEFAULT GETDATE()
);

CREATE TABLE DETALLE_VENTA (
    IdDetalle      INT IDENTITY(1,1) PRIMARY KEY,
    IdVenta        INT NOT NULL REFERENCES VENTA(IdVenta),
    IdProducto     INT NOT NULL REFERENCES PRODUCTO_MENU(IdProducto),
    Cantidad       INT NOT NULL CHECK (Cantidad > 0),
    PrecioUnitario DECIMAL(12,2) NOT NULL,   -- incluye las adiciones
    Subtotal       DECIMAL(12,2) NOT NULL,
    Notas          VARCHAR(150) NULL
);

CREATE TABLE DETALLE_MODIFICADOR (
    IdDetalle     INT NOT NULL REFERENCES DETALLE_VENTA(IdDetalle),
    IdModificador INT NOT NULL REFERENCES MODIFICADOR(IdModificador),
    Precio        DECIMAL(12,2) NOT NULL,
    PRIMARY KEY (IdDetalle, IdModificador)
);

ALTER TABLE MOVIMIENTO ADD CONSTRAINT FK_MOV_VENTA FOREIGN KEY (IdVenta) REFERENCES VENTA(IdVenta);

/* Conteo físico de inventario */
CREATE TABLE CONTEO (
    IdConteo    INT IDENTITY(1,1) PRIMARY KEY,
    IdSede      INT NOT NULL REFERENCES SEDE(IdSede),
    IdUsuario   INT NOT NULL REFERENCES USUARIO(IdUsuario),
    Observacion VARCHAR(250) NULL,
    Fecha       DATETIME NOT NULL DEFAULT GETDATE()
);

CREATE TABLE CONTEO_DETALLE (
    IdConteo      INT NOT NULL REFERENCES CONTEO(IdConteo),
    IdInsumo      INT NOT NULL REFERENCES INSUMO(IdInsumo),
    StockSistema  DECIMAL(12,3) NOT NULL,
    StockContado  DECIMAL(12,3) NOT NULL,
    Diferencia    DECIMAL(12,3) NOT NULL,
    PRIMARY KEY (IdConteo, IdInsumo)
);
GO

/* Tipos tabla para enviar listas desde C# */
CREATE TYPE ELineaVenta AS TABLE (Linea INT, IdProducto INT, Cantidad INT, Notas VARCHAR(150));
CREATE TYPE ELineaModificador AS TABLE (Linea INT, IdModificador INT);
CREATE TYPE EReceta AS TABLE (IdInsumo INT, Cantidad DECIMAL(12,3));
CREATE TYPE EIds AS TABLE (Id INT);
CREATE TYPE EConteo AS TABLE (IdInsumo INT, StockContado DECIMAL(12,3));
GO

/* ===================== FUNCIONES Y AUXILIARES ===================== */

/* Mueve el stock de un insumo en una sede, registra el kardex y actualiza lotes.
   Debe llamarse dentro de una transacción. @Delta positivo = entra, negativo = sale. */
CREATE PROCEDURE SP_STOCK_APLICAR (
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

    IF @StockActual + @Delta < 0
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
        INSERT INTO LOTE (IdSede, IdInsumo, CantidadInicial, CantidadDisponible, FechaVencimiento, IdMovimiento)
        VALUES (@IdSede, @IdInsumo, @Delta, @Delta, @FechaVencimiento, @IdMovimiento);
    ELSE
    BEGIN
        -- Consumir lotes: primero los que vencen antes, luego los más antiguos
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

/* ======================= CONFIGURACIÓN ======================= */

CREATE PROCEDURE SP_CONFIGURACION_OBTENER
AS
    SELECT NombreNegocio, Nit, Direccion, Telefono, ColorPrimario, ColorSecundario, LogoUrl,
           SimboloMoneda, MensajeTicket, DiasAlertaVencimiento
    FROM CONFIGURACION WHERE IdConfiguracion = 1;
GO

CREATE PROCEDURE SP_CONFIGURACION_GUARDAR (
    @NombreNegocio VARCHAR(100), @Nit VARCHAR(30), @Direccion VARCHAR(150), @Telefono VARCHAR(30),
    @ColorPrimario CHAR(7), @ColorSecundario CHAR(7), @LogoUrl VARCHAR(250), @SimboloMoneda VARCHAR(5),
    @MensajeTicket VARCHAR(250), @DiasAlertaVencimiento INT,
    @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    UPDATE CONFIGURACION SET NombreNegocio = @NombreNegocio, Nit = @Nit, Direccion = @Direccion,
           Telefono = @Telefono, ColorPrimario = @ColorPrimario, ColorSecundario = @ColorSecundario,
           LogoUrl = @LogoUrl, SimboloMoneda = @SimboloMoneda, MensajeTicket = @MensajeTicket,
           DiasAlertaVencimiento = @DiasAlertaVencimiento
    WHERE IdConfiguracion = 1;
    SET @Resultado = 1; SET @Mensaje = '';
END
GO

/* ========================= SEDES ========================= */

CREATE PROCEDURE SP_SEDE_LISTAR
AS
    SELECT IdSede, Nombre, Direccion, Telefono, Activo FROM SEDE ORDER BY Nombre;
GO

CREATE PROCEDURE SP_SEDE_GUARDAR (
    @IdSede INT, @Nombre VARCHAR(100), @Direccion VARCHAR(150), @Telefono VARCHAR(30), @Activo BIT,
    @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET @Resultado = 0; SET @Mensaje = '';
    IF EXISTS (SELECT 1 FROM SEDE WHERE Nombre = @Nombre AND IdSede <> @IdSede)
    BEGIN SET @Mensaje = 'Ya existe una sede con ese nombre'; RETURN; END
    IF @IdSede = 0
    BEGIN
        INSERT INTO SEDE (Nombre, Direccion, Telefono, Activo) VALUES (@Nombre, @Direccion, @Telefono, @Activo);
        SET @Resultado = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE SEDE SET Nombre = @Nombre, Direccion = @Direccion, Telefono = @Telefono, Activo = @Activo WHERE IdSede = @IdSede;
        SET @Resultado = @IdSede;
    END
END
GO

CREATE PROCEDURE SP_SEDE_ELIMINAR (@IdSede INT, @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET @Resultado = 0; SET @Mensaje = '';
    IF EXISTS (SELECT 1 FROM USUARIO WHERE IdSede = @IdSede) OR EXISTS (SELECT 1 FROM MOVIMIENTO WHERE IdSede = @IdSede)
    BEGIN SET @Mensaje = 'La sede tiene usuarios o movimientos. Puede desactivarla.'; RETURN; END
    DELETE FROM INSUMO_SEDE WHERE IdSede = @IdSede;
    DELETE FROM SEDE WHERE IdSede = @IdSede;
    SET @Resultado = 1;
END
GO

/* ========================= USUARIOS ========================= */

CREATE PROCEDURE SP_USUARIO_OBTENER (@Usuario VARCHAR(50))
AS
    SELECT u.IdUsuario, u.NombreCompleto, u.Usuario, u.Clave, u.IdRol, r.Descripcion AS Rol,
           u.IdSede, s.Nombre AS Sede, u.Activo
    FROM USUARIO u
    INNER JOIN ROL r ON r.IdRol = u.IdRol
    INNER JOIN SEDE s ON s.IdSede = u.IdSede
    WHERE u.Usuario = @Usuario;
GO

CREATE PROCEDURE SP_USUARIO_OBTENER_ID (@IdUsuario INT)
AS
    SELECT u.IdUsuario, u.NombreCompleto, u.Usuario, u.Clave, u.IdRol, r.Descripcion AS Rol,
           u.IdSede, s.Nombre AS Sede, u.Activo
    FROM USUARIO u
    INNER JOIN ROL r ON r.IdRol = u.IdRol
    INNER JOIN SEDE s ON s.IdSede = u.IdSede
    WHERE u.IdUsuario = @IdUsuario;
GO

CREATE PROCEDURE SP_USUARIO_LISTAR
AS
    SELECT u.IdUsuario, u.NombreCompleto, u.Usuario, '' AS Clave, u.IdRol, r.Descripcion AS Rol,
           u.IdSede, s.Nombre AS Sede, u.Activo
    FROM USUARIO u
    INNER JOIN ROL r ON r.IdRol = u.IdRol
    INNER JOIN SEDE s ON s.IdSede = u.IdSede
    ORDER BY u.NombreCompleto;
GO

CREATE PROCEDURE SP_ROL_LISTAR
AS
    SELECT IdRol, Descripcion FROM ROL ORDER BY IdRol;
GO

/* @Clave llega ya cifrada desde C#. Vacía = no cambiar la contraseña */
CREATE PROCEDURE SP_USUARIO_GUARDAR (
    @IdUsuario INT, @NombreCompleto VARCHAR(100), @Usuario VARCHAR(50), @Clave VARCHAR(200),
    @IdRol INT, @IdSede INT, @Activo BIT,
    @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET @Resultado = 0; SET @Mensaje = '';
    IF EXISTS (SELECT 1 FROM USUARIO WHERE Usuario = @Usuario AND IdUsuario <> @IdUsuario)
    BEGIN SET @Mensaje = 'Ese nombre de usuario ya está en uso'; RETURN; END
    IF @IdUsuario = 0
    BEGIN
        IF ISNULL(@Clave, '') = '' BEGIN SET @Mensaje = 'La contraseña es obligatoria'; RETURN; END
        INSERT INTO USUARIO (NombreCompleto, Usuario, Clave, IdRol, IdSede, Activo)
        VALUES (@NombreCompleto, @Usuario, @Clave, @IdRol, @IdSede, @Activo);
        SET @Resultado = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE USUARIO SET NombreCompleto = @NombreCompleto, Usuario = @Usuario, IdRol = @IdRol,
               IdSede = @IdSede, Activo = @Activo,
               Clave = CASE WHEN ISNULL(@Clave, '') = '' THEN Clave ELSE @Clave END
        WHERE IdUsuario = @IdUsuario;
        SET @Resultado = @IdUsuario;
    END
END
GO

CREATE PROCEDURE SP_USUARIO_CAMBIAR_CLAVE (@IdUsuario INT, @Clave VARCHAR(200), @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    UPDATE USUARIO SET Clave = @Clave WHERE IdUsuario = @IdUsuario;
    SET @Resultado = @@ROWCOUNT; SET @Mensaje = '';
END
GO

/* ===================== CATEGORÍAS Y PROVEEDORES ===================== */

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

CREATE PROCEDURE SP_CATEGORIA_ELIMINAR (@IdCategoria INT, @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET @Resultado = 0; SET @Mensaje = '';
    IF EXISTS (SELECT 1 FROM INSUMO WHERE IdCategoria = @IdCategoria)
    BEGIN SET @Mensaje = 'La categoría tiene insumos asociados. Puede desactivarla.'; RETURN; END
    DELETE FROM CATEGORIA WHERE IdCategoria = @IdCategoria;
    SET @Resultado = 1;
END
GO

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

CREATE PROCEDURE SP_PROVEEDOR_ELIMINAR (@IdProveedor INT, @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET @Resultado = 0; SET @Mensaje = '';
    IF EXISTS (SELECT 1 FROM MOVIMIENTO WHERE IdProveedor = @IdProveedor)
    BEGIN SET @Mensaje = 'El proveedor tiene movimientos registrados. Puede desactivarlo.'; RETURN; END
    DELETE FROM PROVEEDOR WHERE IdProveedor = @IdProveedor;
    SET @Resultado = 1;
END
GO

/* ========================= INSUMOS ========================= */

CREATE PROCEDURE SP_INSUMO_LISTAR (@IdSede INT)
AS
    SELECT i.IdInsumo, i.Codigo, i.Nombre, i.IdCategoria, c.Descripcion AS Categoria, i.UnidadMedida,
           ISNULL(s.Stock, 0) AS Stock, i.StockMinimo, i.CostoUnitario, i.Activo,
           (SELECT MIN(l.FechaVencimiento) FROM LOTE l
             WHERE l.IdSede = @IdSede AND l.IdInsumo = i.IdInsumo AND l.CantidadDisponible > 0) AS ProximoVencimiento
    FROM INSUMO i
    INNER JOIN CATEGORIA c ON c.IdCategoria = i.IdCategoria
    LEFT JOIN INSUMO_SEDE s ON s.IdInsumo = i.IdInsumo AND s.IdSede = @IdSede
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

CREATE PROCEDURE SP_INSUMO_ELIMINAR (@IdInsumo INT, @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET @Resultado = 0; SET @Mensaje = '';
    IF EXISTS (SELECT 1 FROM MOVIMIENTO WHERE IdInsumo = @IdInsumo)
       OR EXISTS (SELECT 1 FROM RECETA WHERE IdInsumo = @IdInsumo)
       OR EXISTS (SELECT 1 FROM MODIFICADOR WHERE IdInsumo = @IdInsumo)
    BEGIN SET @Mensaje = 'El insumo tiene movimientos o está en una receta. Puede desactivarlo.'; RETURN; END
    DELETE FROM INSUMO_SEDE WHERE IdInsumo = @IdInsumo;
    DELETE FROM INSUMO WHERE IdInsumo = @IdInsumo;
    SET @Resultado = 1;
END
GO

/* ========================= MOVIMIENTOS ========================= */

CREATE PROCEDURE SP_MOVIMIENTO_REGISTRAR (
    @IdSede INT, @IdInsumo INT, @Tipo VARCHAR(10), @Cantidad DECIMAL(12,3), @CostoUnitario DECIMAL(12,2),
    @IdProveedor INT, @FechaVencimiento DATE, @Observacion VARCHAR(250), @IdUsuario INT,
    @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET NOCOUNT ON;
    SET @Resultado = 0; SET @Mensaje = '';
    IF @Tipo NOT IN ('ENTRADA','SALIDA','MERMA') BEGIN SET @Mensaje = 'Tipo de movimiento no válido'; RETURN; END
    IF NOT EXISTS (SELECT 1 FROM INSUMO WHERE IdInsumo = @IdInsumo) BEGIN SET @Mensaje = 'El insumo no existe'; RETURN; END

    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @Delta DECIMAL(12,3) = CASE WHEN @Tipo = 'ENTRADA' THEN @Cantidad ELSE -@Cantidad END;
        DECLARE @Costo DECIMAL(12,2) = CASE WHEN @Tipo = 'ENTRADA' THEN @CostoUnitario
                                            ELSE (SELECT CostoUnitario FROM INSUMO WHERE IdInsumo = @IdInsumo) END;
        EXEC SP_STOCK_APLICAR @IdSede, @IdInsumo, @Tipo, @Delta, @Costo, @IdProveedor, NULL, @Observacion, @IdUsuario, @FechaVencimiento;

        IF @Tipo = 'ENTRADA' AND @CostoUnitario > 0
            UPDATE INSUMO SET CostoUnitario = @CostoUnitario WHERE IdInsumo = @IdInsumo;
        COMMIT;
        SET @Resultado = 1;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Mensaje = ERROR_MESSAGE();
    END CATCH
END
GO

CREATE PROCEDURE SP_MOVIMIENTO_LISTAR (@IdSede INT, @FechaInicio DATE, @FechaFin DATE, @IdInsumo INT = 0)
AS
    SELECT m.IdMovimiento, CONVERT(VARCHAR(16), m.Fecha, 120) AS Fecha, i.Nombre AS Insumo, i.UnidadMedida,
           m.Tipo, m.Cantidad, m.CostoUnitario, m.StockAnterior, m.StockNuevo,
           ISNULL(p.RazonSocial, '') AS Proveedor, ISNULL(m.Observacion, '') AS Observacion,
           u.NombreCompleto AS Usuario
    FROM MOVIMIENTO m
    INNER JOIN INSUMO i ON i.IdInsumo = m.IdInsumo
    INNER JOIN USUARIO u ON u.IdUsuario = m.IdUsuario
    LEFT JOIN PROVEEDOR p ON p.IdProveedor = m.IdProveedor
    WHERE m.IdSede = @IdSede
      AND CAST(m.Fecha AS DATE) BETWEEN @FechaInicio AND @FechaFin
      AND (@IdInsumo = 0 OR m.IdInsumo = @IdInsumo)
    ORDER BY m.Fecha DESC, m.IdMovimiento DESC;
GO

/* ========================= CONTEO FÍSICO ========================= */

CREATE PROCEDURE SP_CONTEO_REGISTRAR (
    @IdSede INT, @IdUsuario INT, @Observacion VARCHAR(250), @Detalle EConteo READONLY,
    @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET NOCOUNT ON;
    SET @Resultado = 0; SET @Mensaje = '';
    IF NOT EXISTS (SELECT 1 FROM @Detalle) BEGIN SET @Mensaje = 'No hay insumos contados'; RETURN; END
    IF EXISTS (SELECT 1 FROM @Detalle WHERE StockContado < 0) BEGIN SET @Mensaje = 'El conteo no puede ser negativo'; RETURN; END

    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @IdConteo INT;
        INSERT INTO CONTEO (IdSede, IdUsuario, Observacion) VALUES (@IdSede, @IdUsuario, @Observacion);
        SET @IdConteo = SCOPE_IDENTITY();

        INSERT INTO CONTEO_DETALLE (IdConteo, IdInsumo, StockSistema, StockContado, Diferencia)
        SELECT @IdConteo, d.IdInsumo, ISNULL(s.Stock, 0), d.StockContado, d.StockContado - ISNULL(s.Stock, 0)
        FROM @Detalle d LEFT JOIN INSUMO_SEDE s ON s.IdSede = @IdSede AND s.IdInsumo = d.IdInsumo;

        DECLARE @IdInsumo INT, @Dif DECIMAL(12,3), @Costo DECIMAL(12,2), @Obs VARCHAR(250) = 'Conteo físico #' + CAST(@IdConteo AS VARCHAR(10));
        DECLARE c CURSOR LOCAL FAST_FORWARD FOR
            SELECT cd.IdInsumo, cd.Diferencia, i.CostoUnitario
            FROM CONTEO_DETALLE cd INNER JOIN INSUMO i ON i.IdInsumo = cd.IdInsumo
            WHERE cd.IdConteo = @IdConteo AND cd.Diferencia <> 0;
        OPEN c;
        FETCH NEXT FROM c INTO @IdInsumo, @Dif, @Costo;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            DECLARE @TipoAj VARCHAR(10) = CASE WHEN @Dif > 0 THEN 'AJUSTE+' ELSE 'AJUSTE-' END;
            EXEC SP_STOCK_APLICAR @IdSede, @IdInsumo, @TipoAj, @Dif, @Costo, 0, NULL, @Obs, @IdUsuario, NULL;
            FETCH NEXT FROM c INTO @IdInsumo, @Dif, @Costo;
        END
        CLOSE c; DEALLOCATE c;

        COMMIT;
        SET @Resultado = @IdConteo;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Mensaje = ERROR_MESSAGE();
    END CATCH
END
GO

CREATE PROCEDURE SP_CONTEO_LISTAR (@IdSede INT)
AS
    SELECT TOP 50 c.IdConteo, CONVERT(VARCHAR(16), c.Fecha, 120) AS Fecha, u.NombreCompleto AS Usuario,
           ISNULL(c.Observacion, '') AS Observacion,
           (SELECT COUNT(*) FROM CONTEO_DETALLE d WHERE d.IdConteo = c.IdConteo) AS Insumos,
           (SELECT COUNT(*) FROM CONTEO_DETALLE d WHERE d.IdConteo = c.IdConteo AND d.Diferencia <> 0) AS ConDiferencia,
           (SELECT ISNULL(SUM(d.Diferencia * i.CostoUnitario), 0) FROM CONTEO_DETALLE d
              INNER JOIN INSUMO i ON i.IdInsumo = d.IdInsumo WHERE d.IdConteo = c.IdConteo) AS ValorDiferencia
    FROM CONTEO c INNER JOIN USUARIO u ON u.IdUsuario = c.IdUsuario
    WHERE c.IdSede = @IdSede
    ORDER BY c.Fecha DESC;
GO

/* ========================= MENÚ ========================= */

CREATE PROCEDURE SP_CATEGORIA_MENU_LISTAR
AS
    SELECT IdCategoriaMenu, Nombre, Icono, Orden, Activo FROM CATEGORIA_MENU ORDER BY Orden, Nombre;
GO

CREATE PROCEDURE SP_CATEGORIA_MENU_GUARDAR (
    @IdCategoriaMenu INT, @Nombre VARCHAR(60), @Icono NVARCHAR(10), @Orden INT, @Activo BIT,
    @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET @Resultado = 0; SET @Mensaje = '';
    IF EXISTS (SELECT 1 FROM CATEGORIA_MENU WHERE Nombre = @Nombre AND IdCategoriaMenu <> @IdCategoriaMenu)
    BEGIN SET @Mensaje = 'Ya existe una categoría con ese nombre'; RETURN; END
    IF @IdCategoriaMenu = 0
    BEGIN
        INSERT INTO CATEGORIA_MENU (Nombre, Icono, Orden, Activo) VALUES (@Nombre, @Icono, @Orden, @Activo);
        SET @Resultado = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE CATEGORIA_MENU SET Nombre = @Nombre, Icono = @Icono, Orden = @Orden, Activo = @Activo
        WHERE IdCategoriaMenu = @IdCategoriaMenu;
        SET @Resultado = @IdCategoriaMenu;
    END
END
GO

CREATE PROCEDURE SP_CATEGORIA_MENU_ELIMINAR (@IdCategoriaMenu INT, @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET @Resultado = 0; SET @Mensaje = '';
    IF EXISTS (SELECT 1 FROM PRODUCTO_MENU WHERE IdCategoriaMenu = @IdCategoriaMenu)
    BEGIN SET @Mensaje = 'La categoría tiene productos. Puede desactivarla.'; RETURN; END
    DELETE FROM CATEGORIA_MENU WHERE IdCategoriaMenu = @IdCategoriaMenu;
    SET @Resultado = 1;
END
GO

CREATE PROCEDURE SP_PRODUCTO_LISTAR
AS
    SELECT p.IdProducto, p.Nombre, ISNULL(p.Descripcion, '') AS Descripcion, p.IdCategoriaMenu,
           c.Nombre AS CategoriaMenu, c.Icono, p.Precio, ISNULL(p.ImagenUrl, '') AS ImagenUrl, p.Activo,
           (SELECT COUNT(*) FROM RECETA r WHERE r.IdProducto = p.IdProducto) AS TotalInsumos,
           (SELECT ISNULL(SUM(r.Cantidad * i.CostoUnitario), 0) FROM RECETA r
              INNER JOIN INSUMO i ON i.IdInsumo = r.IdInsumo WHERE r.IdProducto = p.IdProducto) AS Costo
    FROM PRODUCTO_MENU p INNER JOIN CATEGORIA_MENU c ON c.IdCategoriaMenu = p.IdCategoriaMenu
    ORDER BY c.Orden, p.Nombre;
GO

CREATE PROCEDURE SP_RECETA_LISTAR (@IdProducto INT)
AS
    SELECT r.IdInsumo, i.Nombre AS Insumo, i.UnidadMedida, r.Cantidad, i.CostoUnitario
    FROM RECETA r INNER JOIN INSUMO i ON i.IdInsumo = r.IdInsumo
    WHERE r.IdProducto = @IdProducto
    ORDER BY i.Nombre;
GO

CREATE PROCEDURE SP_PRODUCTO_MODIFICADORES (@IdProducto INT)
AS
    SELECT IdModificador FROM PRODUCTO_MODIFICADOR WHERE IdProducto = @IdProducto;
GO

CREATE PROCEDURE SP_PRODUCTO_GUARDAR (
    @IdProducto INT, @Nombre VARCHAR(100), @Descripcion VARCHAR(250), @IdCategoriaMenu INT,
    @Precio DECIMAL(12,2), @Activo BIT, @Receta EReceta READONLY, @Modificadores EIds READONLY,
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
            INSERT INTO PRODUCTO_MENU (Nombre, Descripcion, IdCategoriaMenu, Precio, Activo)
            VALUES (@Nombre, @Descripcion, @IdCategoriaMenu, @Precio, @Activo);
            SET @IdProducto = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE PRODUCTO_MENU SET Nombre = @Nombre, Descripcion = @Descripcion, IdCategoriaMenu = @IdCategoriaMenu,
                   Precio = @Precio, Activo = @Activo
            WHERE IdProducto = @IdProducto;

        DELETE FROM RECETA WHERE IdProducto = @IdProducto;
        INSERT INTO RECETA (IdProducto, IdInsumo, Cantidad)
        SELECT @IdProducto, IdInsumo, SUM(Cantidad) FROM @Receta GROUP BY IdInsumo;

        DELETE FROM PRODUCTO_MODIFICADOR WHERE IdProducto = @IdProducto;
        INSERT INTO PRODUCTO_MODIFICADOR (IdProducto, IdModificador)
        SELECT DISTINCT @IdProducto, Id FROM @Modificadores;

        COMMIT;
        SET @Resultado = @IdProducto;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0; SET @Mensaje = ERROR_MESSAGE();
    END CATCH
END
GO

CREATE PROCEDURE SP_PRODUCTO_IMAGEN (@IdProducto INT, @ImagenUrl VARCHAR(250), @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    UPDATE PRODUCTO_MENU SET ImagenUrl = @ImagenUrl WHERE IdProducto = @IdProducto;
    SET @Resultado = @@ROWCOUNT; SET @Mensaje = '';
END
GO

CREATE PROCEDURE SP_PRODUCTO_ELIMINAR (@IdProducto INT, @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET @Resultado = 0; SET @Mensaje = '';
    IF EXISTS (SELECT 1 FROM DETALLE_VENTA WHERE IdProducto = @IdProducto)
    BEGIN SET @Mensaje = 'El producto tiene ventas registradas. Puede desactivarlo.'; RETURN; END
    DELETE FROM PRODUCTO_MENU WHERE IdProducto = @IdProducto;
    SET @Resultado = 1;
END
GO

CREATE PROCEDURE SP_MODIFICADOR_LISTAR
AS
    SELECT m.IdModificador, m.Nombre, m.Precio, ISNULL(m.IdInsumo, 0) AS IdInsumo,
           ISNULL(i.Nombre, '') AS Insumo, ISNULL(i.UnidadMedida, '') AS UnidadMedida, m.Cantidad, m.Activo
    FROM MODIFICADOR m LEFT JOIN INSUMO i ON i.IdInsumo = m.IdInsumo
    ORDER BY m.Nombre;
GO

CREATE PROCEDURE SP_MODIFICADOR_GUARDAR (
    @IdModificador INT, @Nombre VARCHAR(80), @Precio DECIMAL(12,2), @IdInsumo INT, @Cantidad DECIMAL(12,3), @Activo BIT,
    @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET @Resultado = 0; SET @Mensaje = '';
    IF EXISTS (SELECT 1 FROM MODIFICADOR WHERE Nombre = @Nombre AND IdModificador <> @IdModificador)
    BEGIN SET @Mensaje = 'Ya existe un modificador con ese nombre'; RETURN; END
    IF @IdModificador = 0
    BEGIN
        INSERT INTO MODIFICADOR (Nombre, Precio, IdInsumo, Cantidad, Activo)
        VALUES (@Nombre, @Precio, NULLIF(@IdInsumo, 0), CASE WHEN @IdInsumo = 0 THEN 0 ELSE @Cantidad END, @Activo);
        SET @Resultado = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE MODIFICADOR SET Nombre = @Nombre, Precio = @Precio, IdInsumo = NULLIF(@IdInsumo, 0),
               Cantidad = CASE WHEN @IdInsumo = 0 THEN 0 ELSE @Cantidad END, Activo = @Activo
        WHERE IdModificador = @IdModificador;
        SET @Resultado = @IdModificador;
    END
END
GO

CREATE PROCEDURE SP_MODIFICADOR_ELIMINAR (@IdModificador INT, @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET @Resultado = 0; SET @Mensaje = '';
    IF EXISTS (SELECT 1 FROM DETALLE_MODIFICADOR WHERE IdModificador = @IdModificador)
    BEGIN SET @Mensaje = 'El modificador ya se usó en ventas. Puede desactivarlo.'; RETURN; END
    DELETE FROM MODIFICADOR WHERE IdModificador = @IdModificador;
    SET @Resultado = 1;
END
GO

/* Productos para la pantalla de venta con sus modificadores permitidos (2 resultados) */
CREATE PROCEDURE SP_POS_CATALOGO
AS
BEGIN
    SELECT p.IdProducto, p.Nombre, ISNULL(p.Descripcion, '') AS Descripcion, p.IdCategoriaMenu,
           c.Nombre AS CategoriaMenu, c.Icono, p.Precio, ISNULL(p.ImagenUrl, '') AS ImagenUrl
    FROM PRODUCTO_MENU p INNER JOIN CATEGORIA_MENU c ON c.IdCategoriaMenu = p.IdCategoriaMenu
    WHERE p.Activo = 1 AND c.Activo = 1
    ORDER BY c.Orden, p.Nombre;

    SELECT pm.IdProducto, m.IdModificador, m.Nombre, m.Precio
    FROM PRODUCTO_MODIFICADOR pm INNER JOIN MODIFICADOR m ON m.IdModificador = pm.IdModificador
    WHERE m.Activo = 1
    ORDER BY m.Precio DESC, m.Nombre;
END
GO

/* ========================= CAJA ========================= */

CREATE PROCEDURE SP_CAJA_ACTUAL (@IdSede INT)
AS
BEGIN
    SELECT c.IdCaja, CONVERT(VARCHAR(16), c.FechaApertura, 120) AS FechaApertura, c.BaseInicial,
           u.NombreCompleto AS UsuarioApertura,
           ISNULL(SUM(CASE WHEN v.MetodoPago = 'EFECTIVO' THEN v.Total ELSE 0 END), 0) AS VentasEfectivo,
           ISNULL(SUM(CASE WHEN v.MetodoPago = 'TARJETA' THEN v.Total ELSE 0 END), 0) AS VentasTarjeta,
           ISNULL(SUM(CASE WHEN v.MetodoPago = 'TRANSFERENCIA' THEN v.Total ELSE 0 END), 0) AS VentasTransferencia,
           COUNT(v.IdVenta) AS NumeroVentas
    FROM CAJA c
    INNER JOIN USUARIO u ON u.IdUsuario = c.IdUsuarioApertura
    LEFT JOIN VENTA v ON v.IdCaja = c.IdCaja
    WHERE c.IdSede = @IdSede AND c.Estado = 'ABIERTA'
    GROUP BY c.IdCaja, c.FechaApertura, c.BaseInicial, u.NombreCompleto;
END
GO

CREATE PROCEDURE SP_CAJA_ABRIR (@IdSede INT, @IdUsuario INT, @BaseInicial DECIMAL(12,2), @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET @Resultado = 0; SET @Mensaje = '';
    IF EXISTS (SELECT 1 FROM CAJA WHERE IdSede = @IdSede AND Estado = 'ABIERTA')
    BEGIN SET @Mensaje = 'Ya hay una caja abierta en esta sede'; RETURN; END
    INSERT INTO CAJA (IdSede, IdUsuarioApertura, BaseInicial) VALUES (@IdSede, @IdUsuario, @BaseInicial);
    SET @Resultado = SCOPE_IDENTITY();
END
GO

CREATE PROCEDURE SP_CAJA_CERRAR (
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
    FROM VENTA WHERE IdCaja = @IdCaja;
    SELECT @Base = BaseInicial FROM CAJA WHERE IdCaja = @IdCaja;

    UPDATE CAJA SET Estado = 'CERRADA', IdUsuarioCierre = @IdUsuario, FechaCierre = GETDATE(),
           VentasEfectivo = @Ef, VentasTarjeta = @Ta, VentasTransferencia = @Tr,
           EfectivoEsperado = @Base + @Ef, EfectivoContado = @EfectivoContado,
           Diferencia = @EfectivoContado - (@Base + @Ef), Observacion = @Observacion
    WHERE IdCaja = @IdCaja;
    SET @Resultado = @IdCaja;
END
GO

CREATE PROCEDURE SP_CAJA_HISTORIAL (@IdSede INT)
AS
    SELECT TOP 60 c.IdCaja, CONVERT(VARCHAR(16), c.FechaApertura, 120) AS FechaApertura,
           CONVERT(VARCHAR(16), c.FechaCierre, 120) AS FechaCierre, c.BaseInicial,
           c.VentasEfectivo, c.VentasTarjeta, c.VentasTransferencia, c.EfectivoEsperado, c.EfectivoContado,
           c.Diferencia, ISNULL(u.NombreCompleto, '') AS UsuarioCierre, ISNULL(c.Observacion, '') AS Observacion
    FROM CAJA c LEFT JOIN USUARIO u ON u.IdUsuario = c.IdUsuarioCierre
    WHERE c.IdSede = @IdSede AND c.Estado = 'CERRADA'
    ORDER BY c.FechaCierre DESC;
GO

/* ========================= VENTAS ========================= */

CREATE PROCEDURE SP_VENTA_REGISTRAR (
    @IdSede INT, @IdUsuario INT, @TipoPedido VARCHAR(10), @ClienteNombre VARCHAR(100), @ClienteTelefono VARCHAR(30),
    @Direccion VARCHAR(200), @CostoDomicilio DECIMAL(12,2), @MetodoPago VARCHAR(15), @MontoRecibido DECIMAL(12,2),
    @Lineas ELineaVenta READONLY, @Modificadores ELineaModificador READONLY,
    @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET NOCOUNT ON;
    SET @Resultado = 0; SET @Mensaje = '';

    DECLARE @IdCaja INT = (SELECT IdCaja FROM CAJA WHERE IdSede = @IdSede AND Estado = 'ABIERTA');
    IF @IdCaja IS NULL BEGIN SET @Mensaje = 'Abra la caja antes de registrar ventas'; RETURN; END
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
        DECLARE @IdVenta INT;
        INSERT INTO VENTA (IdSede, IdCaja, IdUsuario, TipoPedido, ClienteNombre, ClienteTelefono, Direccion,
                           Subtotal, CostoDomicilio, Total, MetodoPago, MontoRecibido, Cambio, EstadoPedido)
        VALUES (@IdSede, @IdCaja, @IdUsuario, @TipoPedido, NULLIF(@ClienteNombre, ''), NULLIF(@ClienteTelefono, ''),
                NULLIF(@Direccion, ''), @Subtotal, @CostoDomicilio, @Total, @MetodoPago, @MontoRecibido,
                @MontoRecibido - @Total, CASE WHEN @TipoPedido = 'DOMICILIO' THEN 'PENDIENTE' ELSE 'ENTREGADO' END);
        SET @IdVenta = SCOPE_IDENTITY();

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

CREATE PROCEDURE SP_VENTA_LISTAR (@IdSede INT, @FechaInicio DATE, @FechaFin DATE)
AS
    SELECT v.IdVenta, CONVERT(VARCHAR(16), v.Fecha, 120) AS Fecha, v.TipoPedido, v.MetodoPago, v.Total,
           v.EstadoPedido, ISNULL(v.ClienteNombre, '') AS ClienteNombre, u.NombreCompleto AS Usuario,
           (SELECT STRING_AGG(CAST(d.Cantidad AS VARCHAR(10)) + ' x ' + p.Nombre, ', ')
              FROM DETALLE_VENTA d INNER JOIN PRODUCTO_MENU p ON p.IdProducto = d.IdProducto
             WHERE d.IdVenta = v.IdVenta) AS Detalle
    FROM VENTA v INNER JOIN USUARIO u ON u.IdUsuario = v.IdUsuario
    WHERE v.IdSede = @IdSede AND CAST(v.Fecha AS DATE) BETWEEN @FechaInicio AND @FechaFin
    ORDER BY v.Fecha DESC;
GO

/* Ticket: encabezado, líneas y adiciones (3 resultados) */
CREATE PROCEDURE SP_VENTA_TICKET (@IdVenta INT)
AS
BEGIN
    SELECT v.IdVenta, CONVERT(VARCHAR(16), v.Fecha, 120) AS Fecha, v.TipoPedido, v.MetodoPago, v.Subtotal,
           v.CostoDomicilio, v.Total, v.MontoRecibido, v.Cambio, v.EstadoPedido,
           ISNULL(v.ClienteNombre, '') AS ClienteNombre, ISNULL(v.ClienteTelefono, '') AS ClienteTelefono,
           ISNULL(v.Direccion, '') AS Direccion, u.NombreCompleto AS Usuario, s.Nombre AS Sede,
           ISNULL(s.Direccion, '') AS SedeDireccion, v.IdSede
    FROM VENTA v
    INNER JOIN USUARIO u ON u.IdUsuario = v.IdUsuario
    INNER JOIN SEDE s ON s.IdSede = v.IdSede
    WHERE v.IdVenta = @IdVenta;

    SELECT d.IdDetalle, p.Nombre, d.Cantidad, d.PrecioUnitario, d.Subtotal, ISNULL(d.Notas, '') AS Notas
    FROM DETALLE_VENTA d INNER JOIN PRODUCTO_MENU p ON p.IdProducto = d.IdProducto
    WHERE d.IdVenta = @IdVenta
    ORDER BY d.IdDetalle;

    SELECT dm.IdDetalle, m.Nombre, dm.Precio
    FROM DETALLE_MODIFICADOR dm
    INNER JOIN DETALLE_VENTA d ON d.IdDetalle = dm.IdDetalle
    INNER JOIN MODIFICADOR m ON m.IdModificador = dm.IdModificador
    WHERE d.IdVenta = @IdVenta;
END
GO

/* ========================= DOMICILIOS ========================= */

CREATE PROCEDURE SP_DOMICILIO_LISTAR (@IdSede INT, @SoloPendientes BIT)
AS
    SELECT v.IdVenta, CONVERT(VARCHAR(16), v.Fecha, 120) AS Fecha, v.ClienteNombre, v.ClienteTelefono, v.Direccion,
           v.Total, v.MetodoPago, v.EstadoPedido,
           DATEDIFF(MINUTE, v.Fecha, GETDATE()) AS Minutos,
           (SELECT STRING_AGG(CAST(d.Cantidad AS VARCHAR(10)) + ' x ' + p.Nombre, ', ')
              FROM DETALLE_VENTA d INNER JOIN PRODUCTO_MENU p ON p.IdProducto = d.IdProducto
             WHERE d.IdVenta = v.IdVenta) AS Detalle
    FROM VENTA v
    WHERE v.IdSede = @IdSede AND v.TipoPedido = 'DOMICILIO'
      AND (@SoloPendientes = 0 AND CAST(v.Fecha AS DATE) = CAST(GETDATE() AS DATE) OR @SoloPendientes = 1 AND v.EstadoPedido <> 'ENTREGADO')
    ORDER BY CASE v.EstadoPedido WHEN 'PENDIENTE' THEN 0 WHEN 'EN_CAMINO' THEN 1 ELSE 2 END, v.Fecha;
GO

CREATE PROCEDURE SP_DOMICILIO_ESTADO (@IdSede INT, @IdVenta INT, @Estado VARCHAR(10), @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET @Resultado = 0; SET @Mensaje = '';
    IF @Estado NOT IN ('PENDIENTE','EN_CAMINO','ENTREGADO') BEGIN SET @Mensaje = 'Estado no válido'; RETURN; END
    UPDATE VENTA SET EstadoPedido = @Estado WHERE IdVenta = @IdVenta AND IdSede = @IdSede AND TipoPedido = 'DOMICILIO';
    IF @@ROWCOUNT = 0 SET @Mensaje = 'No se encontró el domicilio'; ELSE SET @Resultado = 1;
END
GO

/* ========================= COMPRAS ========================= */

/* Orden de compra sugerida: insumos en o bajo el mínimo, con el último proveedor usado */
CREATE PROCEDURE SP_ORDEN_COMPRA_SUGERIDA (@IdSede INT)
AS
    SELECT i.IdInsumo, i.Codigo, i.Nombre, i.UnidadMedida, ISNULL(s.Stock, 0) AS Stock, i.StockMinimo,
           CAST(i.StockMinimo * 2 - ISNULL(s.Stock, 0) AS DECIMAL(12,3)) AS CantidadSugerida,
           i.CostoUnitario,
           CAST((i.StockMinimo * 2 - ISNULL(s.Stock, 0)) * i.CostoUnitario AS DECIMAL(12,2)) AS CostoEstimado,
           ISNULL(ult.IdProveedor, 0) AS IdProveedor, ISNULL(p.RazonSocial, 'Sin proveedor') AS Proveedor,
           ISNULL(p.Telefono, '') AS TelefonoProveedor
    FROM INSUMO i
    LEFT JOIN INSUMO_SEDE s ON s.IdInsumo = i.IdInsumo AND s.IdSede = @IdSede
    OUTER APPLY (SELECT TOP 1 m.IdProveedor FROM MOVIMIENTO m
                 WHERE m.IdInsumo = i.IdInsumo AND m.Tipo = 'ENTRADA' AND m.IdProveedor IS NOT NULL
                 ORDER BY m.Fecha DESC) ult
    LEFT JOIN PROVEEDOR p ON p.IdProveedor = ult.IdProveedor
    WHERE i.Activo = 1 AND i.StockMinimo > 0 AND ISNULL(s.Stock, 0) <= i.StockMinimo
    ORDER BY ISNULL(p.RazonSocial, 'zzz'), i.Nombre;
GO

/* ========================= REPORTES ========================= */

CREATE PROCEDURE SP_REPORTE_VENTAS_DIA (@IdSede INT, @FechaInicio DATE, @FechaFin DATE)
AS
    SELECT CONVERT(VARCHAR(10), CAST(v.Fecha AS DATE), 120) AS Dia, COUNT(*) AS Pedidos, SUM(v.Total) AS Total
    FROM VENTA v
    WHERE v.IdSede = @IdSede AND CAST(v.Fecha AS DATE) BETWEEN @FechaInicio AND @FechaFin
    GROUP BY CAST(v.Fecha AS DATE)
    ORDER BY Dia;
GO

CREATE PROCEDURE SP_REPORTE_TOP_PRODUCTOS (@IdSede INT, @FechaInicio DATE, @FechaFin DATE)
AS
    SELECT TOP 10 p.Nombre, SUM(d.Cantidad) AS Cantidad, SUM(d.Subtotal) AS Total
    FROM DETALLE_VENTA d
    INNER JOIN VENTA v ON v.IdVenta = d.IdVenta
    INNER JOIN PRODUCTO_MENU p ON p.IdProducto = d.IdProducto
    WHERE v.IdSede = @IdSede AND CAST(v.Fecha AS DATE) BETWEEN @FechaInicio AND @FechaFin
    GROUP BY p.Nombre
    ORDER BY Cantidad DESC, Total DESC;
GO

CREATE PROCEDURE SP_REPORTE_RESUMEN (@IdSede INT, @FechaInicio DATE, @FechaFin DATE)
AS
BEGIN
    DECLARE @Ventas DECIMAL(14,2), @Domicilios DECIMAL(14,2), @Pedidos INT, @Costo DECIMAL(14,2), @Mermas DECIMAL(14,2);
    SELECT @Ventas = ISNULL(SUM(Total), 0), @Domicilios = ISNULL(SUM(CostoDomicilio), 0), @Pedidos = COUNT(*)
    FROM VENTA WHERE IdSede = @IdSede AND CAST(Fecha AS DATE) BETWEEN @FechaInicio AND @FechaFin;

    SELECT @Costo = ISNULL(SUM(m.Cantidad * m.CostoUnitario), 0)
    FROM MOVIMIENTO m WHERE m.IdSede = @IdSede AND m.Tipo = 'VENTA' AND CAST(m.Fecha AS DATE) BETWEEN @FechaInicio AND @FechaFin;

    SELECT @Mermas = ISNULL(SUM(m.Cantidad * m.CostoUnitario), 0)
    FROM MOVIMIENTO m WHERE m.IdSede = @IdSede AND m.Tipo = 'MERMA' AND CAST(m.Fecha AS DATE) BETWEEN @FechaInicio AND @FechaFin;

    SELECT @Ventas AS Ventas, @Pedidos AS Pedidos,
           CASE WHEN @Pedidos > 0 THEN @Ventas / @Pedidos ELSE 0 END AS TicketPromedio,
           @Ventas - @Domicilios AS VentasProductos, @Costo AS CostoInsumos,
           @Ventas - @Domicilios - @Costo AS Ganancia, @Mermas AS Mermas;

    SELECT MetodoPago, COUNT(*) AS Pedidos, SUM(Total) AS Total
    FROM VENTA WHERE IdSede = @IdSede AND CAST(Fecha AS DATE) BETWEEN @FechaInicio AND @FechaFin
    GROUP BY MetodoPago;
END
GO

/* ========================= PANEL ========================= */

CREATE PROCEDURE SP_DASHBOARD (@IdSede INT)
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
        (SELECT ISNULL(SUM(Total), 0) FROM VENTA WHERE IdSede = @IdSede AND CAST(Fecha AS DATE) = @Hoy) AS VentasHoy,
        (SELECT COUNT(*) FROM VENTA WHERE IdSede = @IdSede AND CAST(Fecha AS DATE) = @Hoy) AS PedidosHoy,
        (SELECT COUNT(*) FROM VENTA WHERE IdSede = @IdSede AND TipoPedido = 'DOMICILIO' AND EstadoPedido <> 'ENTREGADO') AS DomiciliosPendientes,
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

/* ===================== DATOS BÁSICOS DEL SISTEMA ===================== */

INSERT INTO CONFIGURACION (IdConfiguracion, NombreNegocio, Nit, Direccion, Telefono, ColorPrimario, ColorSecundario, SimboloMoneda, MensajeTicket)
VALUES (1, 'Mi Negocio', '', '', '', '#C8322B', '#1F1A17', '$', '¡Gracias por su compra!');

INSERT INTO SEDE (Nombre, Direccion) VALUES ('Principal', '');

INSERT INTO ROL (Descripcion) VALUES ('ADMINISTRADOR'), ('CAJERO');

-- Usuario: admin  /  Clave: Admin123   (cámbiela en "Mi contraseña" después del primer ingreso)
INSERT INTO USUARIO (NombreCompleto, Usuario, Clave, IdRol, IdSede)
VALUES ('Administrador', 'admin', 'obLD1OX2BxgpOktcbX6PkA==.hu16QIR4DKgpgZnV4Z/2/kZH0zVnimm+EKQf2ZkDYQA=', 1, 1);
GO
