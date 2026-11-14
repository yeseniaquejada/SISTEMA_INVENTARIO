/* =============================================================
   011 - INSUMO "QUESO LONCHITA" POR UNIDAD (LONCHA)
   Yesenia Quejada Rojas - Claude — 12/11/2026

   Se crea el insumo "Queso lonchita" (código QLONU), contado por
   loncha (UND), además del que ya existe "Queso lonchita (bloque)"
   (QLON). Así en Movimiento se pueden restar lonchas sueltas, por
   ejemplo el consumo del personal.

   - Misma categoría que el bloque.
   - Stock 0 en todas las sedes (se carga con una entrada o el conteo).
   - Mínimo 0, para que no salga en "Qué debo comprar".
   - Costo: el del bloque dividido entre 10 lonchas (el supuesto que ya
     usan las recetas: 0,1 bloque por loncha). Se puede cambiar en Insumos.
   - No toca recetas: las ventas siguen descontando del bloque.

   Se puede ejecutar más de una vez (no duplica).
   ============================================================= */
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF NOT EXISTS (SELECT 1 FROM INSUMO WHERE Codigo = 'QLON')
    PRINT 'Aviso: no se encontró el insumo QLON (bloque). Se usa la categoría de cualquier insumo con "queso" en el nombre.';

BEGIN TRANSACTION;

INSERT INTO INSUMO (Codigo, Nombre, IdCategoria, UnidadMedida, StockMinimo, CostoUnitario, Activo)
SELECT TOP 1 'QLONU', 'Queso lonchita', b.IdCategoria, 'UND', 0,
       CASE WHEN b.Codigo = 'QLON' THEN ROUND(b.CostoUnitario / 10, 2) ELSE 0 END, 1
FROM INSUMO b
WHERE (b.Codigo = 'QLON' OR b.Nombre LIKE '%queso%')
  AND NOT EXISTS (SELECT 1 FROM INSUMO x WHERE x.Codigo = 'QLONU' OR x.Nombre = 'Queso lonchita')
ORDER BY CASE WHEN b.Codigo = 'QLON' THEN 0 ELSE 1 END, b.IdInsumo;
PRINT 'Insumo Queso lonchita creado: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

/* Stock 0 en cada sede */
INSERT INTO INSUMO_SEDE (IdSede, IdInsumo, Stock)
SELECT s.IdSede, i.IdInsumo, 0
FROM SEDE s CROSS JOIN INSUMO i
WHERE i.Codigo = 'QLONU'
  AND NOT EXISTS (SELECT 1 FROM INSUMO_SEDE x WHERE x.IdSede = s.IdSede AND x.IdInsumo = i.IdInsumo);

COMMIT TRANSACTION;

SELECT Codigo, Nombre, UnidadMedida, StockMinimo, CostoUnitario, Activo
FROM INSUMO WHERE Codigo IN ('QLON', 'QLONU') OR Nombre LIKE 'Queso lonchita%';
