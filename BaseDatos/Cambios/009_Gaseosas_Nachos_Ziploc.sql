/* =============================================================
   08 - GASEOSAS 1,75 L / 1,5 L, NACHOS PAQUETE Y BOLSA ZIPLOC
   Yesenia Quejada Rojas - Claude — 11/11/2026

   1. Gaseosas Postobón (Manzana, Colombiana, Uva, Naranja):
      - Los insumos de 1,75 L quedan con solo el sabor: "Manzana 1,75 L".
      - El producto de la carta de 1,75 L pasa a valer 9.000.
      - Se crean insumos NUEVOS de 1,5 L ("Manzana 1,5 L"), separados de los
        de 1,75 L, con stock 0, y su producto en la carta a 8.000 con receta
        de 1 unidad. Así cada tamaño descuenta su propio stock.
   2. NACHO pasa a "Nachos paquete", se cuenta por paquete y se quita de
      las recetas de los burritos (ya no descuenta 0,1 por venta).
      Los productos e insumos con "lata" en el nombre quedan desactivados.
   3. Bolsa ziploc 2x3 y 3x3: mínimo en 0 para que no salgan en
      "Qué debo comprar". Siguen en el inventario y en el conteo.

   Solo borra las líneas de nachos en recetas. Se puede ejecutar más de una vez.
   Ejecutar en la base del cliente (SSMS).
   ============================================================= */
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Sabores TABLE (Sabor VARCHAR(30), Cod175 VARCHAR(30), Cod15 VARCHAR(30));
INSERT INTO @Sabores VALUES
    ('Manzana',    'GASMAN175L', 'GASMAN15L'),
    ('Colombiana', 'GASCOL175L', 'GASCOL15L'),
    ('Uva',        'GASUVA175L', 'GASUVA15L'),
    ('Naranja',    'GASNAR175L', 'GASNAR15L');

DECLARE @Precio175 DECIMAL(12,2) = 9000;
DECLARE @Precio15  DECIMAL(12,2) = 8000;

/* Aviso si falta algún insumo de 1,75 L (se salta ese sabor) */
SELECT s.Cod175 AS CodigoNoEncontrado, s.Sabor
FROM @Sabores s WHERE NOT EXISTS (SELECT 1 FROM INSUMO i WHERE i.Codigo = s.Cod175);

BEGIN TRANSACTION;

/* ---------- 1a. Insumos 1,75 L: solo el sabor ---------- */
UPDATE i SET i.Nombre = s.Sabor + ' 1,75 L'
FROM INSUMO i JOIN @Sabores s ON s.Cod175 = i.Codigo
WHERE i.Nombre <> s.Sabor + ' 1,75 L';
PRINT 'Insumos 1,75 L renombrados: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

/* ---------- 1b. Producto 1,75 L: precio 9.000 y nombre con solo el sabor ----------
   Se ubica por la receta (el producto que descuenta el insumo de 1,75 L). */
UPDATE p SET p.Precio = @Precio175,
             p.Descripcion = 'Gaseosa Postobón 1,75 L',
             p.Nombre = CASE WHEN EXISTS (SELECT 1 FROM PRODUCTO_MENU x
                                          WHERE x.Nombre = s.Sabor + ' 1,75 L' AND x.IdProducto <> p.IdProducto)
                             THEN p.Nombre ELSE s.Sabor + ' 1,75 L' END
FROM PRODUCTO_MENU p
JOIN RECETA r ON r.IdProducto = p.IdProducto
JOIN INSUMO i ON i.IdInsumo = r.IdInsumo
JOIN @Sabores s ON s.Cod175 = i.Codigo
WHERE (SELECT COUNT(*) FROM RECETA x WHERE x.IdProducto = p.IdProducto) = 1;  -- solo la gaseosa sola, no combos
PRINT 'Productos 1,75 L a 9.000: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

/* ---------- 1c. Insumos nuevos de 1,5 L ---------- */
INSERT INTO INSUMO (Codigo, Nombre, IdCategoria, UnidadMedida, StockMinimo, CostoUnitario, Activo)
SELECT s.Cod15, s.Sabor + ' 1,5 L', i.IdCategoria, 'UND', 0, 0, 1
FROM @Sabores s
JOIN INSUMO i ON i.Codigo = s.Cod175
WHERE NOT EXISTS (SELECT 1 FROM INSUMO x WHERE x.Codigo = s.Cod15);
PRINT 'Insumos 1,5 L creados: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

/* ---------- 1d. Productos nuevos de 1,5 L (misma categoría que el de 1,75 L) ---------- */
INSERT INTO PRODUCTO_MENU (Nombre, Descripcion, IdCategoriaMenu, Precio, ImagenUrl, Activo)
SELECT s.Sabor + ' 1,5 L', 'Gaseosa Postobón 1,5 L', p.IdCategoriaMenu, @Precio15, p.ImagenUrl, 1
FROM @Sabores s
JOIN INSUMO i ON i.Codigo = s.Cod175
CROSS APPLY (SELECT TOP 1 pm.IdCategoriaMenu, pm.ImagenUrl FROM PRODUCTO_MENU pm
             JOIN RECETA r ON r.IdProducto = pm.IdProducto
             WHERE r.IdInsumo = i.IdInsumo
               AND (SELECT COUNT(*) FROM RECETA x WHERE x.IdProducto = pm.IdProducto) = 1
             ORDER BY pm.IdProducto) p
WHERE NOT EXISTS (SELECT 1 FROM PRODUCTO_MENU x WHERE x.Nombre = s.Sabor + ' 1,5 L');
PRINT 'Productos 1,5 L creados: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

/* Receta: cada producto de 1,5 L descuenta 1 unidad de su insumo de 1,5 L */
INSERT INTO RECETA (IdProducto, IdInsumo, Cantidad)
SELECT p.IdProducto, i.IdInsumo, 1
FROM @Sabores s
JOIN PRODUCTO_MENU p ON p.Nombre = s.Sabor + ' 1,5 L'
JOIN INSUMO i ON i.Codigo = s.Cod15
WHERE NOT EXISTS (SELECT 1 FROM RECETA r WHERE r.IdProducto = p.IdProducto AND r.IdInsumo = i.IdInsumo);
PRINT 'Recetas 1,5 L creadas: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

/* ---------- 2. Nachos por paquete ----------
   El insumo se cuenta en paquetes enteros. Se quita de las recetas de los
   burritos (antes gastaban 0,1 paquete, dato no confirmado), así una venta ya
   no descuenta nachos. El paquete se descuenta cuando se registra la salida o
   el conteo. Ventas anteriores no cambian. */
UPDATE INSUMO SET Nombre = 'Nachos paquete', UnidadMedida = 'UND'
WHERE Codigo = 'NACHO' AND (Nombre <> 'Nachos paquete' OR UnidadMedida <> 'UND');
PRINT 'Nachos ajustado: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

DELETE r FROM RECETA r JOIN INSUMO i ON i.IdInsumo = r.IdInsumo WHERE i.Codigo = 'NACHO';
PRINT 'Recetas que ya no descuentan nachos: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

/* ---------- 2b. Gaseosas en lata: desactivadas ----------
   Productos e insumos con "lata" en el nombre. Las de 400 ml NO se tocan.
   Dejan de salir en el punto de venta, compras e insumos. No se borran. */
UPDATE INSUMO SET Activo = 0 WHERE Nombre LIKE '%lata%' AND Nombre NOT LIKE '%latón%' AND Nombre NOT LIKE '%platan%' AND Activo = 1;
PRINT 'Insumos en lata desactivados: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
UPDATE PRODUCTO_MENU SET Activo = 0 WHERE Nombre LIKE '%lata%' AND Nombre NOT LIKE '%latón%' AND Nombre NOT LIKE '%platan%' AND Activo = 1;
PRINT 'Productos en lata desactivados: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

/* ---------- 3. Bolsa ziploc fuera de la compra ---------- */
UPDATE INSUMO SET StockMinimo = 0
WHERE (Codigo LIKE 'BOLZIP%' OR Nombre LIKE '%ziploc%') AND StockMinimo <> 0;
PRINT 'Ziploc con mínimo en 0: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

COMMIT TRANSACTION;

/* ---------------- RESULTADO ---------------- */
SELECT i.Codigo, i.Nombre, i.UnidadMedida, i.StockMinimo, i.Activo
FROM INSUMO i
WHERE i.Codigo IN (SELECT Cod175 FROM @Sabores UNION SELECT Cod15 FROM @Sabores)
   OR i.Codigo = 'NACHO' OR i.Codigo LIKE 'BOLZIP%' OR i.Nombre LIKE '%ziploc%'
   OR (i.Nombre LIKE '%lata%' AND i.Nombre NOT LIKE '%latón%' AND i.Nombre NOT LIKE '%platan%')
ORDER BY i.Nombre;

SELECT p.Nombre AS Producto, p.Precio, p.Descripcion, i.Codigo AS InsumoQueDescuenta, r.Cantidad
FROM PRODUCTO_MENU p
JOIN RECETA r ON r.IdProducto = p.IdProducto
JOIN INSUMO i ON i.IdInsumo = r.IdInsumo
WHERE i.Codigo IN (SELECT Cod175 FROM @Sabores UNION SELECT Cod15 FROM @Sabores)
ORDER BY p.Nombre;

/* Comprobación: la lista de compra de la sede 1 ya no debe mostrar ziploc.
   Si aún sale, quite el comentario de la línea de abajo y ejecútela sola
   (desactiva la ziploc: deja de salir en compra, conteo e insumos).
   UPDATE INSUMO SET Activo = 0 WHERE Codigo LIKE 'BOLZIP%' OR Nombre LIKE '%ziploc%';  */
SELECT IdProducto, Nombre, Activo FROM PRODUCTO_MENU WHERE Nombre LIKE '%lata%' AND Nombre NOT LIKE '%latón%' AND Nombre NOT LIKE '%platan%';
EXEC SP_ORDEN_COMPRA_SUGERIDA @IdSede = 1;
GO
