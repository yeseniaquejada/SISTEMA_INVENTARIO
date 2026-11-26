/* =============================================================
   015 - LOS PRODUCTOS JOHN WICK DESCUENTAN EL CHICHARRÓN DE LA NEVERA
   Yesenia Quejada Rojas - Claude — 19/11/2026

   Qué pasaba: "Hamburguesa John Wick", "Hamburguesa John Wick con papas"
   y "Papas John Wick" tenían en la receta el insumo "Chicharrón
   caramelizado (porción)" (CHICHC). Ese insumo está inactivo y marcado
   "no descontar al vender", así que esas ventas nunca bajaban el
   chicharrón. Solo "Papa paisa" descontaba "Chicharrón 100 g" (CHICH).

   Qué hace: en esas recetas cambia CHICHC por CHICH (1 porción por
   producto, igual que antes). No toca ventas pasadas ni el stock.
   Después de ejecutarlo, cuente el chicharrón y corríjalo en Contar
   inventario (modo "Total contado").

   Se puede ejecutar más de una vez.
   ============================================================= */
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Chich INT = (SELECT IdInsumo FROM INSUMO WHERE Codigo = 'CHICH');
DECLARE @Carame INT = (SELECT IdInsumo FROM INSUMO WHERE Codigo = 'CHICHC');
IF @Chich IS NULL THROW 50001, 'No existe el insumo CHICH (Chicharrón 100 g)', 1;

BEGIN TRANSACTION;

/* Si alguna receta ya tuviera los dos, se suma la cantidad a CHICH */
UPDATE r SET r.Cantidad = r.Cantidad + c.Cantidad
FROM RECETA r
INNER JOIN RECETA c ON c.IdProducto = r.IdProducto AND c.IdInsumo = @Carame
WHERE r.IdInsumo = @Chich;
DELETE c FROM RECETA c
WHERE c.IdInsumo = @Carame AND EXISTS (SELECT 1 FROM RECETA r WHERE r.IdProducto = c.IdProducto AND r.IdInsumo = @Chich);

/* Cambio normal: CHICHC -> CHICH */
UPDATE RECETA SET IdInsumo = @Chich WHERE IdInsumo = @Carame;
PRINT 'Recetas cambiadas a Chicharrón 100 g: ' + CAST(@@ROWCOUNT AS VARCHAR(10));

/* Adiciones que usaran el caramelizado (hoy ninguna) */
UPDATE MODIFICADOR SET IdInsumo = @Chich WHERE IdInsumo = @Carame;

COMMIT TRANSACTION;

/* Verificación: qué productos descuentan chicharrón ahora */
SELECT p.Nombre AS Producto, i.Codigo, i.Nombre AS Insumo, r.Cantidad
FROM RECETA r
INNER JOIN PRODUCTO_MENU p ON p.IdProducto = r.IdProducto
INNER JOIN INSUMO i ON i.IdInsumo = r.IdInsumo
WHERE i.Codigo IN ('CHICH', 'CHICHC')
ORDER BY p.Nombre;
