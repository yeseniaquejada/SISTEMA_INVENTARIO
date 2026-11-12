/* 09 - Vuelve a activar las gaseosas de 400 ml (se desactivaron por error)
   y busca las "lata" (precio cerca de 800, creadas hace pocos días). */
SET NOCOUNT ON;
UPDATE INSUMO SET Activo = 1 WHERE (Nombre LIKE '%400 ml%' OR Nombre LIKE '%400ml%') AND Activo = 0;
PRINT 'Insumos 400 ml activados de nuevo: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
UPDATE PRODUCTO_MENU SET Activo = 1 WHERE (Nombre LIKE '%400 ml%' OR Nombre LIKE '%400ml%') AND Activo = 0;
PRINT 'Productos 400 ml activados de nuevo: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

/* Búsqueda: "lata" en cualquier parte, o precio/costo entre 500 y 1.200 */
SELECT 'PRODUCTO' AS Tabla, IdProducto AS Id, Nombre, Descripcion, Precio AS Valor, Activo
FROM PRODUCTO_MENU WHERE Nombre LIKE '%lata%' OR Descripcion LIKE '%lata%' OR Precio BETWEEN 500 AND 1200
UNION ALL
SELECT 'INSUMO', IdInsumo, Nombre, Codigo, CostoUnitario, Activo
FROM INSUMO WHERE Nombre LIKE '%lata%' OR Codigo LIKE '%LATA%' OR CostoUnitario BETWEEN 500 AND 1200
ORDER BY Tabla, Id;

/* Los últimos creados (Id más alto) */
SELECT TOP 15 IdProducto, Nombre, Precio, Activo FROM PRODUCTO_MENU ORDER BY IdProducto DESC;
SELECT TOP 15 IdInsumo, Codigo, Nombre, CostoUnitario, Activo FROM INSUMO ORDER BY IdInsumo DESC;
GO
