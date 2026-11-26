/* Nuevas adiciones pedidas por Yesenia (05-nov-2026).
   Ejecutar sobre DB_INVENTARIO_COMIDAS DESPUES de la carga de cero. Idempotente: se puede correr varias veces.
   - Adición de carne desmechada ....... $7.000  (descuenta 1 porción de CARNED)
   - Adición de pollo .................. $6.000  (descuenta 1 porción de POLLO)
   - Carne de hamburguesa artesanal .... $7.000  (descuenta 1 unidad de CARNEH)
   Igual que las demás adiciones, quedan disponibles en todos los productos que no son Bebidas.
   NO SE HA EJECUTADO EN PRODUCCION. */
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @Nuevas TABLE (Nombre VARCHAR(80), Precio DECIMAL(12,2), Codigo VARCHAR(20), Cantidad DECIMAL(12,3));
INSERT INTO @Nuevas VALUES
  ('Adición de carne desmechada',    7000, 'CARNED', 1),
  ('Adición de pollo',               6000, 'POLLO',  1),
  ('Carne de hamburguesa artesanal', 7000, 'CARNEH', 1);

IF EXISTS (SELECT 1 FROM @Nuevas n LEFT JOIN INSUMO i ON i.Codigo = n.Codigo WHERE i.IdInsumo IS NULL)
    THROW 50001, 'Falta alguno de los insumos CARNED, POLLO o CARNEH; revisa la carga de insumos', 1;

/* 1. Crear la adición o, si ya existe con ese nombre, actualizar su precio e insumo */
UPDATE m SET m.Precio = n.Precio, m.IdInsumo = i.IdInsumo, m.Cantidad = n.Cantidad, m.Activo = 1
FROM MODIFICADOR m
INNER JOIN @Nuevas n ON n.Nombre = m.Nombre
INNER JOIN INSUMO i ON i.Codigo = n.Codigo;

INSERT INTO MODIFICADOR (Nombre, Precio, IdInsumo, Cantidad, Activo)
SELECT n.Nombre, n.Precio, i.IdInsumo, n.Cantidad, 1
FROM @Nuevas n INNER JOIN INSUMO i ON i.Codigo = n.Codigo
WHERE NOT EXISTS (SELECT 1 FROM MODIFICADOR m WHERE m.Nombre = n.Nombre);

/* 2. Habilitarlas en todos los productos que no son Bebidas */
INSERT INTO PRODUCTO_MODIFICADOR (IdProducto, IdModificador)
SELECT p.IdProducto, m.IdModificador
FROM PRODUCTO_MENU p
INNER JOIN CATEGORIA_MENU c ON c.IdCategoriaMenu = p.IdCategoriaMenu
CROSS JOIN MODIFICADOR m
WHERE m.Nombre IN (SELECT Nombre FROM @Nuevas)
  AND c.Nombre <> 'Bebidas'
  AND NOT EXISTS (SELECT 1 FROM PRODUCTO_MODIFICADOR pm
                  WHERE pm.IdProducto = p.IdProducto AND pm.IdModificador = m.IdModificador);

COMMIT;

/* Verificación */
SELECT m.IdModificador, m.Nombre, m.Precio, i.Codigo AS Insumo, m.Cantidad, m.Activo,
       (SELECT COUNT(*) FROM PRODUCTO_MODIFICADOR pm WHERE pm.IdModificador = m.IdModificador) AS Productos
FROM MODIFICADOR m LEFT JOIN INSUMO i ON i.IdInsumo = m.IdInsumo
WHERE m.Nombre IN ('Adición de carne desmechada', 'Adición de pollo', 'Carne de hamburguesa artesanal');
