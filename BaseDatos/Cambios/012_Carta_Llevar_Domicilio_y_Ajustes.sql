/* =============================================================
   012 - CARTA DIGITAL: PEDIDOS PARA LLEVAR Y A DOMICILIO + AJUSTES
   Yesenia Quejada Rojas - Claude — 13/11/2026

   1. PEDIDO_CARTA acepta pedidos sin mesa:
      - Nuevas columnas TipoPedido (MESA / LLEVAR / DOMICILIO),
        Telefono y Direccion (para domicilio).
      - IdMesa pasa a aceptar NULL (solo MESA la exige).
      - SP_PEDIDO_CARTA_REGISTRAR recibe sede, tipo, teléfono y
        dirección. Las llamadas viejas (solo mesa) siguen sirviendo.
      - SP_PEDIDO_CARTA_LISTAR devuelve el tipo y los datos del cliente.
      - SP_CARTA_PUBLICA devuelve también el IdSede (el QR de mesa no
        lo trae y el pedido sin mesa lo necesita).
   2. "Chorizo coctelero (suelto)" pasa a llamarse "Chorizo coctelero".
   3. Cajas, papel aluminio y kits de comida salen de "Qué debo
      comprar" (tabla INSUMO_FUERA_COMPRA del script 008).

   Se puede ejecutar más de una vez. No borra pedidos, ventas ni
   inventario.
   ============================================================= */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ---------- 1. Columnas nuevas de PEDIDO_CARTA ---------- */
IF COL_LENGTH('dbo.PEDIDO_CARTA', 'TipoPedido') IS NULL
    ALTER TABLE dbo.PEDIDO_CARTA ADD TipoPedido VARCHAR(10) NOT NULL
        CONSTRAINT DF_PEDIDO_CARTA_Tipo DEFAULT ('MESA');
IF COL_LENGTH('dbo.PEDIDO_CARTA', 'Telefono') IS NULL
    ALTER TABLE dbo.PEDIDO_CARTA ADD Telefono VARCHAR(20) NOT NULL
        CONSTRAINT DF_PEDIDO_CARTA_Telefono DEFAULT ('');
IF COL_LENGTH('dbo.PEDIDO_CARTA', 'Direccion') IS NULL
    ALTER TABLE dbo.PEDIDO_CARTA ADD Direccion VARCHAR(200) NOT NULL
        CONSTRAINT DF_PEDIDO_CARTA_Direccion DEFAULT ('');
GO

/* IdMesa admite NULL. El índice y la llave foránea que usan la columna se quitan y se vuelven a crear igual. */
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.PEDIDO_CARTA') AND name = 'IdMesa' AND is_nullable = 0)
BEGIN
    BEGIN TRANSACTION;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.PEDIDO_CARTA') AND name = 'IX_PEDIDO_CARTA_Abiertos')
        DROP INDEX IX_PEDIDO_CARTA_Abiertos ON dbo.PEDIDO_CARTA;
    IF OBJECT_ID('dbo.FK_PEDIDO_CARTA_MESA', 'F') IS NOT NULL
        ALTER TABLE dbo.PEDIDO_CARTA DROP CONSTRAINT FK_PEDIDO_CARTA_MESA;
    ALTER TABLE dbo.PEDIDO_CARTA ALTER COLUMN IdMesa INT NULL;
    ALTER TABLE dbo.PEDIDO_CARTA ADD CONSTRAINT FK_PEDIDO_CARTA_MESA FOREIGN KEY (IdMesa) REFERENCES dbo.MESA (IdMesa);
    COMMIT;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.PEDIDO_CARTA') AND name = 'IX_PEDIDO_CARTA_Abiertos')
    -- Pedidos abiertos de la sede (Vender y la campana los consultan cada 15 s).
    CREATE INDEX IX_PEDIDO_CARTA_Abiertos ON dbo.PEDIDO_CARTA (IdSede, FechaRegistro)
        INCLUDE (IdMesa, Estado) WHERE Estado IN ('PENDIENTE', 'CONFIRMADO');
GO

IF OBJECT_ID('dbo.CK_PEDIDO_CARTA_Tipo', 'C') IS NULL
    ALTER TABLE dbo.PEDIDO_CARTA ADD CONSTRAINT CK_PEDIDO_CARTA_Tipo
        CHECK (TipoPedido IN ('MESA', 'LLEVAR', 'DOMICILIO') AND (TipoPedido <> 'MESA' OR IdMesa IS NOT NULL));
GO

/* ---------- SP: registrar el pedido del carrito ---------- */
CREATE OR ALTER PROCEDURE dbo.SP_PEDIDO_CARTA_REGISTRAR (@IdMesa INT, @ClienteNombre VARCHAR(60), @Nota VARCHAR(150),
    @Lineas dbo.ELineaVenta READONLY, @Modificadores dbo.ELineaModificador READONLY, @Quitados dbo.ELineaQuitado READONLY,
    @Codigo UNIQUEIDENTIFIER OUTPUT, @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT,
    -- Yesenia Quejada Rojas - Claude — 13/11/2026: pedidos para llevar y a domicilio desde la carta (sin mesa).
    @IdSede INT = NULL, @TipoPedido VARCHAR(10) = 'MESA', @Telefono VARCHAR(20) = '', @Direccion VARCHAR(200) = '')
AS
BEGIN
    SET NOCOUNT ON;
    SET @Resultado = 0; SET @Mensaje = ''; SET @Codigo = NULL;
    DECLARE @Total DECIMAL(12,2);
    SET @TipoPedido = UPPER(LTRIM(RTRIM(ISNULL(@TipoPedido, 'MESA'))));
    SET @ClienteNombre = LTRIM(RTRIM(ISNULL(@ClienteNombre, '')));
    SET @Telefono = LTRIM(RTRIM(ISNULL(@Telefono, '')));
    SET @Direccion = LTRIM(RTRIM(ISNULL(@Direccion, '')));
    IF @TipoPedido NOT IN ('MESA', 'LLEVAR', 'DOMICILIO') BEGIN SET @Mensaje = 'Tipo de pedido no válido'; RETURN; END

    IF @TipoPedido = 'MESA'
    BEGIN
        -- La sede sale de la mesa (como antes).
        SET @IdSede = NULL;
        SELECT @IdSede = m.IdSede FROM dbo.MESA m INNER JOIN dbo.SEDE s ON s.IdSede = m.IdSede AND s.Activo = 1
        WHERE m.IdMesa = @IdMesa AND m.Activo = 1;
        IF @IdSede IS NULL BEGIN SET @Mensaje = 'Esta mesa no está disponible. Pida su pedido al personal.'; RETURN; END
        SET @Telefono = ''; SET @Direccion = '';
    END
    ELSE
    BEGIN
        SET @IdMesa = NULL;
        IF NOT EXISTS (SELECT 1 FROM dbo.SEDE WHERE IdSede = @IdSede AND Activo = 1)
        BEGIN SET @Mensaje = 'El local no está recibiendo pedidos. Llame al negocio.'; RETURN; END
        IF @TipoPedido = 'DOMICILIO'
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.CONFIGURACION WHERE MostrarDomicilios = 1)
            BEGIN SET @Mensaje = 'Por ahora no hay domicilios. Elija mesa o para llevar.'; RETURN; END
            IF @ClienteNombre = '' OR LEN(@Telefono) < 7 OR LEN(@Direccion) < 5
            BEGIN SET @Mensaje = 'Para el domicilio escriba su nombre, teléfono y dirección.'; RETURN; END
        END
        ELSE SET @Direccion = '';
        IF @Telefono LIKE '%[^0-9 +()-]%' BEGIN SET @Mensaje = 'Escriba el teléfono solo con números.'; RETURN; END
    END

    IF NOT EXISTS (SELECT 1 FROM @Lineas) BEGIN SET @Mensaje = 'El carrito está vacío'; RETURN; END
    IF (SELECT COUNT(*) FROM @Lineas) > 30 BEGIN SET @Mensaje = 'El pedido tiene demasiados productos'; RETURN; END
    IF (SELECT COUNT(DISTINCT Linea) FROM @Lineas) <> (SELECT COUNT(*) FROM @Lineas) BEGIN SET @Mensaje = 'El pedido llegó incompleto. Intente de nuevo.'; RETURN; END
    IF EXISTS (SELECT 1 FROM @Lineas WHERE Cantidad NOT BETWEEN 1 AND 20) BEGIN SET @Mensaje = 'Cada producto admite de 1 a 20 unidades'; RETURN; END
    IF EXISTS (SELECT 1 FROM @Lineas l LEFT JOIN dbo.PRODUCTO_MENU p ON p.IdProducto = l.IdProducto AND p.Activo = 1 AND p.EnCarta = 1
               LEFT JOIN dbo.CATEGORIA_MENU c ON c.IdCategoriaMenu = p.IdCategoriaMenu AND c.Activo = 1
               WHERE c.IdCategoriaMenu IS NULL)
    BEGIN SET @Mensaje = 'Un producto del carrito ya no está en la carta. Recargue la página.'; RETURN; END
    -- Cada salsa o adición debe ser de ese producto y estar activa; cada "Sin ..." debe ser de su receta.
    IF EXISTS (SELECT 1 FROM @Modificadores x LEFT JOIN @Lineas l ON l.Linea = x.Linea
               LEFT JOIN dbo.PRODUCTO_MODIFICADOR pm ON pm.IdProducto = l.IdProducto AND pm.IdModificador = x.IdModificador
               LEFT JOIN dbo.MODIFICADOR m ON m.IdModificador = pm.IdModificador AND m.Activo = 1
               WHERE m.IdModificador IS NULL)
       OR EXISTS (SELECT 1 FROM @Quitados x LEFT JOIN @Lineas l ON l.Linea = x.Linea
                  LEFT JOIN dbo.RECETA r ON r.IdProducto = l.IdProducto AND r.IdInsumo = x.IdInsumo
                  WHERE r.IdInsumo IS NULL)
    BEGIN SET @Mensaje = 'Una opción del pedido ya no está disponible. Recargue la página.'; RETURN; END
    -- Evita pedidos repetidos por error o por abuso del QR: máximo 3 en espera por mesa (o por teléfono)
    -- y máximo 15 sin mesa esperando en la sede.
    IF @TipoPedido = 'MESA' AND (SELECT COUNT(*) FROM dbo.PEDIDO_CARTA WHERE IdSede = @IdSede AND IdMesa = @IdMesa AND Estado = 'PENDIENTE') >= 3
    BEGIN SET @Mensaje = 'Esta mesa ya tiene pedidos esperando confirmación. Espere a que el personal los revise.'; RETURN; END
    IF @TipoPedido <> 'MESA' AND (
           (@Telefono <> '' AND (SELECT COUNT(*) FROM dbo.PEDIDO_CARTA WHERE IdSede = @IdSede AND Telefono = @Telefono AND Estado = 'PENDIENTE') >= 3)
        OR (SELECT COUNT(*) FROM dbo.PEDIDO_CARTA WHERE IdSede = @IdSede AND IdMesa IS NULL AND Estado = 'PENDIENTE') >= 15)
    BEGIN SET @Mensaje = 'Hay muchos pedidos esperando confirmación. Espere un momento o llame al negocio.'; RETURN; END

    SELECT @Total = SUM((p.Precio + ISNULL(ad.Precio, 0)) * l.Cantidad)
    FROM @Lineas l INNER JOIN dbo.PRODUCTO_MENU p ON p.IdProducto = l.IdProducto
    OUTER APPLY (SELECT SUM(m.Precio) AS Precio FROM (SELECT DISTINCT IdModificador FROM @Modificadores WHERE Linea = l.Linea) x
                 INNER JOIN dbo.MODIFICADOR m ON m.IdModificador = x.IdModificador) ad;
    BEGIN TRY
        BEGIN TRAN;
        INSERT INTO dbo.PEDIDO_CARTA (IdSede, IdMesa, ClienteNombre, Nota, Total, TipoPedido, Telefono, Direccion)
        VALUES (@IdSede, @IdMesa, @ClienteNombre, LTRIM(RTRIM(ISNULL(@Nota, ''))), @Total, @TipoPedido, @Telefono, @Direccion);
        SET @Resultado = SCOPE_IDENTITY();
        INSERT INTO dbo.PEDIDO_CARTA_DETALLE (IdPedidoCarta, Linea, IdProducto, Cantidad, PrecioUnitario, Notas)
        SELECT @Resultado, l.Linea, l.IdProducto, l.Cantidad, p.Precio, LTRIM(RTRIM(ISNULL(l.Notas, '')))
        FROM @Lineas l INNER JOIN dbo.PRODUCTO_MENU p ON p.IdProducto = l.IdProducto;
        INSERT INTO dbo.PEDIDO_CARTA_MODIFICADOR (IdPedidoCarta, Linea, IdModificador, Precio)
        SELECT DISTINCT @Resultado, x.Linea, x.IdModificador, m.Precio FROM @Modificadores x INNER JOIN dbo.MODIFICADOR m ON m.IdModificador = x.IdModificador;
        INSERT INTO dbo.PEDIDO_CARTA_QUITADO (IdPedidoCarta, Linea, IdInsumo)
        SELECT DISTINCT @Resultado, x.Linea, x.IdInsumo FROM @Quitados x;
        SELECT @Codigo = Codigo FROM dbo.PEDIDO_CARTA WHERE IdPedidoCarta = @Resultado;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @Resultado = 0; SET @Codigo = NULL; SET @Mensaje = 'No se pudo enviar el pedido. Intente de nuevo.';
    END CATCH
END
GO

/* ---------- SP: pedidos abiertos para Vender y la campana ---------- */
-- Pedidos abiertos de la sede para Vender: encabezado, detalle y las opciones de cada línea.
CREATE OR ALTER PROCEDURE dbo.SP_PEDIDO_CARTA_LISTAR (@IdSede INT)
AS
BEGIN
    SET NOCOUNT ON;
    -- Yesenia Quejada Rojas - Claude — 13/11/2026: LEFT JOIN porque llevar y domicilio no tienen mesa; se agregan tipo, teléfono y dirección.
    SELECT pc.IdPedidoCarta, ISNULL(m.Nombre, '') AS Mesa, pc.ClienteNombre, pc.Nota, pc.Total, pc.Estado,
           DATEDIFF(SECOND, pc.FechaRegistro, GETDATE()) AS Segundos, pc.TipoPedido, pc.Telefono, pc.Direccion
    FROM dbo.PEDIDO_CARTA pc LEFT JOIN dbo.MESA m ON m.IdMesa = pc.IdMesa
    WHERE pc.IdSede = @IdSede AND pc.Estado IN ('PENDIENTE', 'CONFIRMADO')
    ORDER BY pc.FechaRegistro;
    SELECT d.IdPedidoCarta, d.Linea, d.IdProducto, p.Nombre, d.Cantidad, d.PrecioUnitario, d.Notas
    FROM dbo.PEDIDO_CARTA_DETALLE d
    INNER JOIN dbo.PEDIDO_CARTA pc ON pc.IdPedidoCarta = d.IdPedidoCarta
    INNER JOIN dbo.PRODUCTO_MENU p ON p.IdProducto = d.IdProducto
    WHERE pc.IdSede = @IdSede AND pc.Estado IN ('PENDIENTE', 'CONFIRMADO')
    ORDER BY d.IdPedidoCarta, d.Linea;
    SELECT x.IdPedidoCarta, x.Linea, x.IdModificador, m.Nombre
    FROM dbo.PEDIDO_CARTA_MODIFICADOR x
    INNER JOIN dbo.PEDIDO_CARTA pc ON pc.IdPedidoCarta = x.IdPedidoCarta
    INNER JOIN dbo.MODIFICADOR m ON m.IdModificador = x.IdModificador
    WHERE pc.IdSede = @IdSede AND pc.Estado IN ('PENDIENTE', 'CONFIRMADO');
    SELECT x.IdPedidoCarta, x.Linea, x.IdInsumo, i.Nombre
    FROM dbo.PEDIDO_CARTA_QUITADO x
    INNER JOIN dbo.PEDIDO_CARTA pc ON pc.IdPedidoCarta = x.IdPedidoCarta
    INNER JOIN dbo.INSUMO i ON i.IdInsumo = x.IdInsumo
    WHERE pc.IdSede = @IdSede AND pc.Estado IN ('PENDIENTE', 'CONFIRMADO');
END
GO

/* ---------- SP: carta pública (igual que antes + IdSede) ---------- */
CREATE OR ALTER PROCEDURE dbo.SP_CARTA_PUBLICA (@IdSede INT, @IdMesa INT = NULL)
AS
BEGIN
    SET NOCOUNT ON;
    -- Yesenia Quejada Rojas - Claude — 29/10/2026: el QR impreso solo trae la mesa; la sede se toma de la mesa para que el QR no dependa de nada más.
    IF @IdMesa IS NOT NULL
        SELECT @IdSede = IdSede FROM MESA WHERE IdMesa = @IdMesa;
    -- Yesenia Quejada Rojas - Claude — 13/11/2026: se devuelve IdSede para los pedidos para llevar y a domicilio.
    SELECT s.IdSede, s.Nombre AS Sede, ISNULL(s.Direccion, '') AS Direccion, ISNULL(s.Telefono, '') AS Telefono,
           ISNULL((SELECT Nombre FROM MESA WHERE IdMesa = @IdMesa AND IdSede = @IdSede AND Activo = 1), '') AS Mesa
    FROM SEDE s WHERE s.IdSede = @IdSede AND s.Activo = 1;
    SELECT p.IdProducto, p.Nombre, ISNULL(p.Descripcion, '') AS Descripcion, c.IdCategoriaMenu, c.Nombre AS CategoriaMenu, c.Icono,
           p.Precio, ISNULL(p.ImagenUrl, '') AS ImagenUrl,
           -- Yesenia Quejada Rojas - Claude — 30/10/2026: la venta no depende del inventario, así que la carta no marca agotados.
           CAST(0 AS BIT) AS Agotado
    FROM PRODUCTO_MENU p
    INNER JOIN CATEGORIA_MENU c ON c.IdCategoriaMenu = p.IdCategoriaMenu
    WHERE p.Activo = 1 AND p.EnCarta = 1 AND c.Activo = 1
    ORDER BY c.Orden, c.Nombre, p.Nombre;
    SELECT DISTINCT m.Grupo, m.Nombre, m.Precio
    FROM MODIFICADOR m
    WHERE m.Activo = 1 AND EXISTS (SELECT 1 FROM PRODUCTO_MODIFICADOR pm INNER JOIN PRODUCTO_MENU p ON p.IdProducto = pm.IdProducto AND p.Activo = 1 AND p.EnCarta = 1
                                   WHERE pm.IdModificador = m.IdModificador)
    ORDER BY m.Grupo, m.Precio DESC, m.Nombre;
    -- Salsas y adiciones de cada producto (las mismas que ofrece Vender).
    SELECT pm.IdProducto, m.IdModificador, m.Nombre, m.Precio, m.Grupo
    FROM PRODUCTO_MODIFICADOR pm INNER JOIN MODIFICADOR m ON m.IdModificador = pm.IdModificador AND m.Activo = 1
    INNER JOIN PRODUCTO_MENU p ON p.IdProducto = pm.IdProducto AND p.Activo = 1 AND p.EnCarta = 1
    ORDER BY m.Grupo, m.Precio DESC, m.Nombre;
    -- Ingredientes que el cliente puede pedir quitar: sin empaques (2) ni bebidas (3), que no tiene sentido ofrecer.
    SELECT r.IdProducto, r.IdInsumo, i.Nombre
    FROM RECETA r
    INNER JOIN PRODUCTO_MENU p ON p.IdProducto = r.IdProducto AND p.Activo = 1 AND p.EnCarta = 1
    INNER JOIN INSUMO i ON i.IdInsumo = r.IdInsumo AND ISNULL(i.IdCategoria, 0) NOT IN (2, 3)
    ORDER BY r.IdProducto, i.Nombre;
END
GO

/* ---------- 2. Nombre del chorizo coctelero ---------- */
IF NOT EXISTS (SELECT 1 FROM dbo.INSUMO WHERE Nombre = 'Chorizo coctelero')
    UPDATE dbo.INSUMO SET Nombre = 'Chorizo coctelero'
    WHERE Nombre = 'Chorizo coctelero (suelto)';
PRINT 'Chorizo coctelero: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' insumo renombrado.';
GO

/* ---------- 3. Fuera de "Qué debo comprar": cajas, aluminio y kits ---------- */
IF OBJECT_ID('dbo.INSUMO_FUERA_COMPRA', 'U') IS NULL
    PRINT 'Aviso: falta la tabla INSUMO_FUERA_COMPRA (script 008). No se quitó nada de la lista de compras.';
ELSE
BEGIN
    INSERT INTO dbo.INSUMO_FUERA_COMPRA (IdInsumo)
    SELECT i.IdInsumo FROM dbo.INSUMO i
    WHERE (i.Nombre LIKE 'Caja%' OR i.Nombre LIKE '%aluminio%' OR i.Nombre LIKE 'Kit %')
      AND NOT EXISTS (SELECT 1 FROM dbo.INSUMO_FUERA_COMPRA f WHERE f.IdInsumo = i.IdInsumo);
    PRINT 'Lista de compras: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' insumos quitados (cajas, aluminio y kits).';
    SELECT i.Codigo, i.Nombre AS [Fuera de la lista de compras]
    FROM dbo.INSUMO_FUERA_COMPRA f INNER JOIN dbo.INSUMO i ON i.IdInsumo = f.IdInsumo
    ORDER BY i.Nombre;
END
GO
