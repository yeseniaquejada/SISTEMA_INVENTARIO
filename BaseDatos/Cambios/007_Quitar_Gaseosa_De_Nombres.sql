/* =============================================================
   QUITAR "GASEOSA DE" / "GASEOSA" DEL NOMBRE DE LAS BEBIDAS
   Deja solo el sabor y el tamaño:
       "Gaseosa de Cola 400ml"   ->  "Cola 400ml"
       "Gaseosa Manzana 400 ml"  ->  "Manzana 400 ml"
   Cambia el nombre en INSUMO (inventario) y en PRODUCTO_MENU (carta).
   Solo toca nombres que empiezan por "Gaseosa de " o "Gaseosa ".
   No borra nada: recetas, ventas, stock y precios siguen igual porque
   todo va por Id, no por nombre. La descripción del producto no cambia.

   Si el nombre nuevo ya existe (o dos gaseosas quedarían con el mismo
   nombre) esa fila NO se cambia y aparece en el listado de "conflictos"
   para revisarla a mano.

   Se puede ejecutar varias veces: la segunda vez ya no encuentra nada.
   Para mirar antes de cambiar: seleccione desde el inicio hasta el final
   de la PARTE 1 (vista previa) y ejecute solo eso. Si se ve bien, ejecute todo.
   ============================================================= */
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID('tempdb..#Cambios') IS NOT NULL DROP TABLE #Cambios;
CREATE TABLE #Cambios (
    Tabla        VARCHAR(20)  NOT NULL,
    Id           INT          NOT NULL,
    NombreActual VARCHAR(100) NOT NULL,
    NombreNuevo  VARCHAR(100) NOT NULL,
    Conflicto    VARCHAR(200) NULL
);

/* Nombre nuevo: quita el prefijo y pone en mayúscula la primera letra */
;WITH base AS (
    SELECT 'INSUMO' AS Tabla, IdInsumo AS Id, Nombre,
           LTRIM(CASE WHEN Nombre LIKE 'Gaseosa de %' THEN SUBSTRING(Nombre, 12, 100)
                      ELSE SUBSTRING(Nombre, 9, 100) END) AS Resto
    FROM INSUMO WHERE Nombre LIKE 'Gaseosa %'
    UNION ALL
    SELECT 'PRODUCTO_MENU', IdProducto, Nombre,
           LTRIM(CASE WHEN Nombre LIKE 'Gaseosa de %' THEN SUBSTRING(Nombre, 12, 100)
                      ELSE SUBSTRING(Nombre, 9, 100) END)
    FROM PRODUCTO_MENU WHERE Nombre LIKE 'Gaseosa %'
)
INSERT INTO #Cambios (Tabla, Id, NombreActual, NombreNuevo)
SELECT Tabla, Id, Nombre, UPPER(LEFT(Resto, 1)) + SUBSTRING(Resto, 2, 100)
FROM base
WHERE Resto <> '';

/* Conflicto 1: ya existe otro registro con ese nombre */
UPDATE c SET Conflicto = 'Ya existe un insumo con ese nombre'
FROM #Cambios c
WHERE c.Tabla = 'INSUMO'
  AND EXISTS (SELECT 1 FROM INSUMO i WHERE i.Nombre = c.NombreNuevo AND i.IdInsumo <> c.Id);

UPDATE c SET Conflicto = 'Ya existe un producto con ese nombre'
FROM #Cambios c
WHERE c.Tabla = 'PRODUCTO_MENU'
  AND EXISTS (SELECT 1 FROM PRODUCTO_MENU p WHERE p.Nombre = c.NombreNuevo AND p.IdProducto <> c.Id);

/* Conflicto 2: dos gaseosas quedarían con el mismo nombre */
UPDATE c SET Conflicto = 'Otra gaseosa quedaría con el mismo nombre'
FROM #Cambios c
WHERE c.Conflicto IS NULL
  AND (SELECT COUNT(*) FROM #Cambios x WHERE x.Tabla = c.Tabla AND x.NombreNuevo = c.NombreNuevo) > 1;

/* ---------------- PARTE 1: VISTA PREVIA ---------------- */
SELECT Tabla, Id, NombreActual, NombreNuevo,
       ISNULL(Conflicto, 'OK, se cambia') AS Estado
FROM #Cambios
ORDER BY Tabla, NombreNuevo;

/* ---------------- PARTE 2: APLICAR ---------------- */
BEGIN TRANSACTION;

    UPDATE i SET i.Nombre = c.NombreNuevo
    FROM INSUMO i
    JOIN #Cambios c ON c.Tabla = 'INSUMO' AND c.Id = i.IdInsumo
    WHERE c.Conflicto IS NULL;
    PRINT 'Insumos renombrados: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

    UPDATE p SET p.Nombre = c.NombreNuevo
    FROM PRODUCTO_MENU p
    JOIN #Cambios c ON c.Tabla = 'PRODUCTO_MENU' AND c.Id = p.IdProducto
    WHERE c.Conflicto IS NULL;
    PRINT 'Productos renombrados: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

COMMIT TRANSACTION;

/* Lo que quedó sin cambiar por conflicto (vacío = todo bien) */
SELECT Tabla, Id, NombreActual, NombreNuevo, Conflicto
FROM #Cambios WHERE Conflicto IS NOT NULL;

DROP TABLE #Cambios;
GO
