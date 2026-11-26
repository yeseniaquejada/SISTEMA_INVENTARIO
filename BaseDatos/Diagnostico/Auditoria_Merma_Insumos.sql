/* =============================================================
   AUDITORÍA: ¿TODOS LOS INSUMOS SE DESCUENTAN BIEN AL VENDER?
   Yesenia Quejada Rojas - Claude — 26/11/2026

   SOLO LEE DATOS. No cambia nada. Se puede ejecutar cuando quiera
   (SSMS o el registro de aplicar-sql). No está en BaseDatos\Cambios
   para que no se ejecute solo al desplegar.

   Cada bloque dice qué revisa. Si un bloque sale vacío, está bien.
   @Sede y @Dias se pueden cambiar.
   ============================================================= */
SET NOCOUNT ON;
DECLARE @Sede INT = 1;
DECLARE @Dias INT = 30;
DECLARE @Desde DATETIME = DATEADD(DAY, -@Dias, CAST(GETDATE() AS DATE));

PRINT '== 1. Productos activos SIN receta: al venderlos no baja nada ==';
SELECT p.IdProducto, p.Nombre, cm.Nombre AS Categoria,
       (SELECT ISNULL(SUM(d.Cantidad), 0) FROM DETALLE_VENTA d INNER JOIN VENTA v ON v.IdVenta = d.IdVenta
         WHERE d.IdProducto = p.IdProducto AND v.Anulada = 0 AND v.Fecha >= @Desde) AS VendidosPeriodo
FROM PRODUCTO_MENU p LEFT JOIN CATEGORIA_MENU cm ON cm.IdCategoriaMenu = p.IdCategoriaMenu
WHERE p.Activo = 1 AND NOT EXISTS (SELECT 1 FROM RECETA r WHERE r.IdProducto = p.IdProducto)
ORDER BY VendidosPeriodo DESC, p.Nombre;

PRINT '== 2. Productos activos cuya receta NO descuenta nada (todos sus insumos inactivos o "no descontar al vender") ==';
SELECT p.IdProducto, p.Nombre,
       STRING_AGG(i.Codigo + ' ' + i.Nombre, ', ') AS Insumos
FROM PRODUCTO_MENU p
INNER JOIN RECETA r ON r.IdProducto = p.IdProducto
INNER JOIN INSUMO i ON i.IdInsumo = r.IdInsumo
WHERE p.Activo = 1
GROUP BY p.IdProducto, p.Nombre
HAVING SUM(CASE WHEN i.ControlaStock = 1 AND i.Activo = 1 THEN 1 ELSE 0 END) = 0
ORDER BY p.Nombre;

PRINT '== 3. Recetas de productos activos con un insumo que nunca baja (inactivo o "no descontar al vender") ==';
PRINT '   Ej.: lo que pasaba con el Chicharrón caramelizado en los John Wick. Revise si debe usar otro insumo.';
SELECT i.Codigo, i.Nombre AS Insumo, i.Activo AS InsumoActivo, i.ControlaStock AS DescontarAlVender,
       COUNT(*) AS Productos, STRING_AGG(p.Nombre, ', ') AS EnProductos
FROM RECETA r
INNER JOIN PRODUCTO_MENU p ON p.IdProducto = r.IdProducto AND p.Activo = 1
INNER JOIN INSUMO i ON i.IdInsumo = r.IdInsumo
WHERE i.Activo = 0 OR i.ControlaStock = 0
GROUP BY i.Codigo, i.Nombre, i.Activo, i.ControlaStock
ORDER BY i.Activo, i.Nombre;

PRINT '== 4. Adiciones activas que no descuentan nada (sin insumo, o con insumo inactivo / "no descontar") ==';
PRINT '   Las salsas sin insumo pueden estar bien; una adición con precio (tocineta, queso...) debería descontar.';
SELECT m.IdModificador, m.Nombre, m.Grupo, m.Precio, ISNULL(i.Codigo, '(sin insumo)') AS Codigo, ISNULL(i.Nombre, '') AS Insumo,
       m.Cantidad, ISNULL(i.Activo, 0) AS InsumoActivo, ISNULL(i.ControlaStock, 0) AS DescontarAlVender,
       (SELECT COUNT(*) FROM DETALLE_MODIFICADOR dm INNER JOIN DETALLE_VENTA d ON d.IdDetalle = dm.IdDetalle
          INNER JOIN VENTA v ON v.IdVenta = d.IdVenta
         WHERE dm.IdModificador = m.IdModificador AND v.Anulada = 0 AND v.Fecha >= @Desde) AS VecesVendidaPeriodo
FROM MODIFICADOR m LEFT JOIN INSUMO i ON i.IdInsumo = m.IdInsumo
WHERE m.Activo = 1 AND (m.IdInsumo IS NULL OR m.Cantidad = 0 OR i.Activo = 0 OR i.ControlaStock = 0)
ORDER BY CASE WHEN m.Precio > 0 THEN 0 ELSE 1 END, m.Grupo, m.Nombre;

PRINT '== 5. Adiciones con cantidad NEGATIVA (restan) cuyo insumo no está en la receta de algún producto donde aplican ==';
SELECT m.Nombre AS Adicion, i.Nombre AS Insumo, m.Cantidad, p.Nombre AS Producto
FROM MODIFICADOR m
INNER JOIN INSUMO i ON i.IdInsumo = m.IdInsumo
INNER JOIN PRODUCTO_MODIFICADOR pm ON pm.IdModificador = m.IdModificador
INNER JOIN PRODUCTO_MENU p ON p.IdProducto = pm.IdProducto AND p.Activo = 1
WHERE m.Activo = 1 AND m.Cantidad < 0
  AND NOT EXISTS (SELECT 1 FROM RECETA r WHERE r.IdProducto = p.IdProducto AND r.IdInsumo = m.IdInsumo)
ORDER BY m.Nombre, p.Nombre;

PRINT '== 6. Insumos activos que se descuentan al vender pero NO están en ninguna receta ni adición activa ==';
PRINT '   Nunca bajan con las ventas: solo con salidas, mermas o el conteo. Puede estar bien (nachos paquete, ajo...).';
SELECT i.Codigo, i.Nombre, i.UnidadMedida, ISNULL(s.Stock, 0) AS Stock,
       (SELECT MAX(m.Fecha) FROM MOVIMIENTO m WHERE m.IdInsumo = i.IdInsumo AND m.Tipo = 'VENTA') AS UltimaVentaQueLoDescontó
FROM INSUMO i LEFT JOIN INSUMO_SEDE s ON s.IdInsumo = i.IdInsumo AND s.IdSede = @Sede
WHERE i.Activo = 1 AND i.ControlaStock = 1
  AND NOT EXISTS (SELECT 1 FROM RECETA r INNER JOIN PRODUCTO_MENU p ON p.IdProducto = r.IdProducto AND p.Activo = 1 WHERE r.IdInsumo = i.IdInsumo)
  AND NOT EXISTS (SELECT 1 FROM MODIFICADOR m WHERE m.IdInsumo = i.IdInsumo AND m.Activo = 1 AND m.Cantidad > 0)
ORDER BY i.Nombre;

PRINT '== 7. Unidades raras en recetas y adiciones ==';
PRINT '   KG/LT con cantidad >= 1 (¿escribió gramos en kilos?), GR/ML con cantidad < 1, UND/PAQ con muchos decimales,';
PRINT '   y paquetes (PAQ) donde la cantidad no da unidades enteras por el redondeo a 3 decimales.';
SELECT 'Receta' AS Donde, p.Nombre AS Producto, i.Codigo, i.Nombre AS Insumo, i.UnidadMedida, x.Cantidad,
       i.UnidadesPorPaquete,
       CASE WHEN i.UnidadMedida = 'PAQ' AND i.UnidadesPorPaquete > 1 THEN CAST(x.Cantidad * i.UnidadesPorPaquete AS DECIMAL(12,3)) END AS UnidadesReales,
       CASE WHEN i.UnidadMedida IN ('KG','LT') AND x.Cantidad >= 1 THEN 'Cantidad alta para KG/LT'
            WHEN i.UnidadMedida IN ('GR','ML') AND x.Cantidad < 1 THEN 'Cantidad muy baja para GR/ML'
            WHEN i.UnidadMedida = 'PAQ' AND i.UnidadesPorPaquete > 1
                 AND ABS(x.Cantidad * i.UnidadesPorPaquete - ROUND(x.Cantidad * i.UnidadesPorPaquete, 0)) > 0.02 THEN 'Paquete: no da unidades enteras (redondeo)'
            WHEN i.UnidadMedida = 'PAQ' AND ISNULL(i.UnidadesPorPaquete, 0) <= 1 THEN 'Paquete sin unidades por paquete'
            ELSE 'Revisar' END AS Motivo
FROM RECETA x INNER JOIN PRODUCTO_MENU p ON p.IdProducto = x.IdProducto AND p.Activo = 1
INNER JOIN INSUMO i ON i.IdInsumo = x.IdInsumo
WHERE (i.UnidadMedida IN ('KG','LT') AND x.Cantidad >= 1)
   OR (i.UnidadMedida IN ('GR','ML') AND x.Cantidad < 1)
   OR (i.UnidadMedida = 'PAQ' AND (ISNULL(i.UnidadesPorPaquete, 0) <= 1
        OR ABS(x.Cantidad * i.UnidadesPorPaquete - ROUND(x.Cantidad * i.UnidadesPorPaquete, 0)) > 0.02))
UNION ALL
SELECT 'Adición', m.Nombre, i.Codigo, i.Nombre, i.UnidadMedida, m.Cantidad, i.UnidadesPorPaquete,
       CASE WHEN i.UnidadMedida = 'PAQ' AND i.UnidadesPorPaquete > 1 THEN CAST(m.Cantidad * i.UnidadesPorPaquete AS DECIMAL(12,3)) END,
       CASE WHEN i.UnidadMedida = 'PAQ' THEN 'Adición de un paquete: la cantidad está en paquetes, no en unidades'
            WHEN i.UnidadMedida IN ('KG','LT') AND m.Cantidad >= 1 THEN 'Cantidad alta para KG/LT'
            ELSE 'Cantidad muy baja para GR/ML' END
FROM MODIFICADOR m INNER JOIN INSUMO i ON i.IdInsumo = m.IdInsumo
WHERE m.Activo = 1 AND m.Cantidad <> 0
  AND (i.UnidadMedida = 'PAQ' OR (i.UnidadMedida IN ('KG','LT') AND m.Cantidad >= 1) OR (i.UnidadMedida IN ('GR','ML') AND ABS(m.Cantidad) < 1))
ORDER BY 1, 2;

PRINT '== 8. Insumos repetidos o parecidos (mismo nombre sin el tamaño/paréntesis) ==';
PRINT '   Si las recetas usan uno y en la nevera se cuenta el otro, el contado nunca baja.';
;WITH n AS (
    SELECT i.IdInsumo, i.Codigo, i.Nombre, i.Activo, i.ControlaStock,
           LTRIM(RTRIM(CASE WHEN CHARINDEX('(', i.Nombre) > 0 THEN LEFT(i.Nombre, CHARINDEX('(', i.Nombre) - 1) ELSE i.Nombre END)) AS Base
    FROM INSUMO i)
SELECT a.Base, a.Codigo, a.Nombre, a.Activo, a.ControlaStock AS DescontarAlVender,
       (SELECT COUNT(*) FROM RECETA r WHERE r.IdInsumo = a.IdInsumo) AS EnRecetas,
       ISNULL((SELECT s.Stock FROM INSUMO_SEDE s WHERE s.IdInsumo = a.IdInsumo AND s.IdSede = @Sede), 0) AS Stock
FROM n a
WHERE EXISTS (SELECT 1 FROM n b WHERE b.IdInsumo <> a.IdInsumo
              AND (b.Base = a.Base OR LEFT(b.Base, 10) = LEFT(a.Base, 10)) AND LEN(a.Base) >= 5)
ORDER BY a.Base, a.Codigo;

PRINT '== 9. Ventas que no pudieron descontar todo porque el stock ya estaba en 0 ("faltaron") ==';
PRINT '   Ese faltante NO se descuenta después: cuando entra la compra, el sistema queda con más de lo real.';
SELECT i.Codigo, i.Nombre, i.UnidadMedida, COUNT(*) AS Ventas,
       SUM(TRY_CAST(SUBSTRING(m.Observacion, CHARINDEX('faltaron ', m.Observacion) + 9,
               CHARINDEX(';', m.Observacion + ';', CHARINDEX('faltaron ', m.Observacion)) - CHARINDEX('faltaron ', m.Observacion) - 9) AS DECIMAL(12,3))) AS CantidadNoDescontada,
       MAX(m.Fecha) AS Ultima
FROM MOVIMIENTO m INNER JOIN INSUMO i ON i.IdInsumo = m.IdInsumo
WHERE m.IdSede = @Sede AND m.Tipo = 'VENTA' AND m.Fecha >= @Desde AND m.Observacion LIKE '%faltaron%'
GROUP BY i.Codigo, i.Nombre, i.UnidadMedida
ORDER BY Ventas DESC;
PRINT '   (Si el insumo estaba en 0 y no se descontó NADA, no queda movimiento; eso lo muestra el bloque 10.)';

PRINT '== 10. Lo que debió bajar por ventas vs. lo que bajó, por insumo (periodo, receta ACTUAL) ==';
PRINT '   Diferencia > 0 = se vendió más de lo que se descontó (stock en 0, receta cambiada después, o insumo';
PRINT '   que en su momento estaba en "no descontar"). Las ventas anuladas no cuentan.';
;WITH lineas AS (
    SELECT d.IdDetalle, d.IdProducto, d.Cantidad
    FROM DETALLE_VENTA d INNER JOIN VENTA v ON v.IdVenta = d.IdVenta
    WHERE v.IdSede = @Sede AND v.Anulada = 0 AND v.Fecha >= @Desde),
porLinea AS (
    SELECT l.IdDetalle, r.IdInsumo, r.Cantidad AS Cant, l.Cantidad AS Veces
    FROM lineas l INNER JOIN RECETA r ON r.IdProducto = l.IdProducto
    WHERE NOT EXISTS (SELECT 1 FROM DETALLE_QUITADO q WHERE q.IdDetalle = l.IdDetalle AND q.IdInsumo = r.IdInsumo)
    UNION ALL
    SELECT l.IdDetalle, m.IdInsumo, m.Cantidad, l.Cantidad
    FROM lineas l INNER JOIN DETALLE_MODIFICADOR dm ON dm.IdDetalle = l.IdDetalle
    INNER JOIN MODIFICADOR m ON m.IdModificador = dm.IdModificador
    WHERE m.IdInsumo IS NOT NULL),
esperado AS (
    SELECT IdInsumo, SUM(CASE WHEN c > 0 THEN c ELSE 0 END * Veces) AS Esperado
    FROM (SELECT IdDetalle, IdInsumo, SUM(Cant) AS c, MAX(Veces) AS Veces FROM porLinea GROUP BY IdDetalle, IdInsumo) t
    GROUP BY IdInsumo),
bajado AS (
    SELECT m.IdInsumo, SUM(CASE WHEN m.Tipo = 'VENTA' THEN m.Cantidad ELSE -m.Cantidad END) AS Descontado
    FROM MOVIMIENTO m INNER JOIN VENTA v ON v.IdVenta = m.IdVenta
    WHERE m.IdSede = @Sede AND m.Tipo IN ('VENTA','DEVOLUCION') AND v.Anulada = 0 AND v.Fecha >= @Desde
    GROUP BY m.IdInsumo)
SELECT i.Codigo, i.Nombre, i.UnidadMedida, i.Activo, i.ControlaStock AS DescontarAlVender,
       CAST(ISNULL(e.Esperado, 0) AS DECIMAL(12,3)) AS DebioBajar,
       CAST(ISNULL(r.Descontado, 0) AS DECIMAL(12,3)) AS Bajo,
       CAST(ISNULL(e.Esperado, 0) - ISNULL(r.Descontado, 0) AS DECIMAL(12,3)) AS Diferencia,
       ISNULL((SELECT s.Stock FROM INSUMO_SEDE s WHERE s.IdInsumo = i.IdInsumo AND s.IdSede = @Sede), 0) AS StockHoy
FROM INSUMO i
LEFT JOIN esperado e ON e.IdInsumo = i.IdInsumo
LEFT JOIN bajado r ON r.IdInsumo = i.IdInsumo
WHERE ABS(ISNULL(e.Esperado, 0) - ISNULL(r.Descontado, 0)) > 0.001
ORDER BY ABS(ISNULL(e.Esperado, 0) - ISNULL(r.Descontado, 0)) * CASE WHEN i.ControlaStock = 1 THEN 1 ELSE 0.001 END DESC;

PRINT '== 11. Ventas (no anuladas) del periodo con productos que tienen receta pero sin NINGÚN movimiento de inventario ==';
SELECT v.IdVenta, CONVERT(VARCHAR(16), v.Fecha, 120) AS Fecha, v.Total,
       (SELECT STRING_AGG(CAST(d.Cantidad AS VARCHAR(5)) + ' x ' + p.Nombre, ', ')
          FROM DETALLE_VENTA d INNER JOIN PRODUCTO_MENU p ON p.IdProducto = d.IdProducto WHERE d.IdVenta = v.IdVenta) AS Detalle
FROM VENTA v
WHERE v.IdSede = @Sede AND v.Anulada = 0 AND v.Fecha >= @Desde
  AND EXISTS (SELECT 1 FROM DETALLE_VENTA d INNER JOIN RECETA r ON r.IdProducto = d.IdProducto
              INNER JOIN INSUMO i ON i.IdInsumo = r.IdInsumo AND i.ControlaStock = 1 WHERE d.IdVenta = v.IdVenta)
  AND NOT EXISTS (SELECT 1 FROM MOVIMIENTO m WHERE m.IdVenta = v.IdVenta)
ORDER BY v.Fecha DESC;

PRINT '== 12. Stock vs. lotes (si no cuadran, el aviso de vencimiento y el FIFO se desordenan; no afecta el stock) ==';
SELECT i.Codigo, i.Nombre, s.Stock, ISNULL(l.Lotes, 0) AS EnLotes
FROM INSUMO_SEDE s INNER JOIN INSUMO i ON i.IdInsumo = s.IdInsumo
OUTER APPLY (SELECT SUM(CantidadDisponible) AS Lotes FROM LOTE x WHERE x.IdSede = s.IdSede AND x.IdInsumo = s.IdInsumo) l
WHERE s.IdSede = @Sede AND ABS(s.Stock - ISNULL(l.Lotes, 0)) > 0.001
ORDER BY ABS(s.Stock - ISNULL(l.Lotes, 0)) DESC;

PRINT '== 13. ¿Se ejecutaron los scripts de recetas? (015 chicharrón, 016) ==';
IF OBJECT_ID('dbo.HISTORIAL_SCRIPTS', 'U') IS NOT NULL
    SELECT Nombre, FechaEjecucion, Modo FROM dbo.HISTORIAL_SCRIPTS WHERE Nombre >= '012' ORDER BY Nombre;
ELSE PRINT '   La base no tiene HISTORIAL_SCRIPTS.';
