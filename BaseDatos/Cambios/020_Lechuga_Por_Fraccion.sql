/* =============================================================
   020 - LECHUGA CRESPA: LAS RECETAS DESCUENTAN UNA FRACCIÓN
   Yesenia Quejada Rojas - Claude — 26/11/2026

   La lechuga crespa (LECH) se cuenta entera (UND), pero cada
   hamburguesa y burrito descontaba 1 lechuga completa: venía de cuando
   era "Lechuga (porción)". Se deja en 0,1 lechuga por plato (unas 10
   hojas por lechuga). Solo cambia las recetas que tienen exactamente 1;
   si alguna ya se corrigió a mano, no se toca. Se puede ajustar en
   Productos.

   No cambia ventas ni stock. Se puede ejecutar más de una vez.
   ============================================================= */
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Lech INT = (SELECT IdInsumo FROM INSUMO WHERE Codigo = 'LECH' AND UnidadMedida = 'UND');
IF @Lech IS NULL
    PRINT 'No se encontró la lechuga LECH por unidad; no se cambia nada.';
ELSE
BEGIN
    BEGIN TRANSACTION;
    UPDATE RECETA SET Cantidad = 0.1 WHERE IdInsumo = @Lech AND Cantidad = 1;
    PRINT 'Recetas de lechuga en 0,1: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
    UPDATE MODIFICADOR SET Cantidad = 0.1 WHERE IdInsumo = @Lech AND Cantidad = 1;
    COMMIT TRANSACTION;
END

SELECT p.Nombre AS Producto, r.Cantidad
FROM RECETA r INNER JOIN PRODUCTO_MENU p ON p.IdProducto = r.IdProducto
INNER JOIN INSUMO i ON i.IdInsumo = r.IdInsumo
WHERE i.Codigo = 'LECH' ORDER BY p.Nombre;
