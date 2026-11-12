/* Ejecutar DESPUES de la carga de cero, sobre DB_INVENTARIO_COMIDAS. Idempotente. */
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @Orig INT = (SELECT IdProducto FROM PRODUCTO_MENU WHERE Nombre = 'Papa pollo');
IF @Orig IS NULL THROW 50001, 'No existe "Papa pollo"; corre primero la carga de cero', 1;

/* 1. Papa pollo #2: copia exacta de Papa pollo (precio, receta, adiciones/salsas) para que la editen */
IF NOT EXISTS (SELECT 1 FROM PRODUCTO_MENU WHERE Nombre = 'Papa pollo #2')
BEGIN
    INSERT INTO PRODUCTO_MENU (Nombre, Descripcion, IdCategoriaMenu, Precio, ImagenUrl, Activo)
    SELECT 'Papa pollo #2', 'POR CONFIRMAR: copia de Papa pollo, ajustar receta y precio', IdCategoriaMenu, Precio, ImagenUrl, 1
    FROM PRODUCTO_MENU WHERE IdProducto = @Orig;
    DECLARE @Nuevo INT = SCOPE_IDENTITY();
    INSERT INTO RECETA (IdProducto, IdInsumo, Cantidad) SELECT @Nuevo, IdInsumo, Cantidad FROM RECETA WHERE IdProducto = @Orig;
    INSERT INTO PRODUCTO_MODIFICADOR (IdProducto, IdModificador) SELECT @Nuevo, IdModificador FROM PRODUCTO_MODIFICADOR WHERE IdProducto = @Orig;
END

/* 2. Picada: sin receta ni precio conocidos. Queda INACTIVA (no sale en el POS) hasta que la completen */
IF NOT EXISTS (SELECT 1 FROM PRODUCTO_MENU WHERE Nombre = 'Picada')
    INSERT INTO PRODUCTO_MENU (Nombre, Descripcion, IdCategoriaMenu, Precio, Activo)
    SELECT 'Picada', 'POR COMPLETAR: agregar receta y precio, luego activar', IdCategoriaMenu, 0, 0
    FROM CATEGORIA_MENU WHERE Nombre = 'Platos';

COMMIT;
SELECT p.IdProducto, p.Nombre, p.Precio, p.Activo, (SELECT COUNT(*) FROM RECETA r WHERE r.IdProducto = p.IdProducto) AS LineasReceta
FROM PRODUCTO_MENU p WHERE p.Nombre IN ('Papa pollo', 'Papa pollo #2', 'Picada');
