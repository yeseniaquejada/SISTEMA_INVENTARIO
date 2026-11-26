/* =============================================================
   016 - "¿LE QUITAMOS ALGO?": TODOS LOS INGREDIENTES DE LA RECETA
   Yesenia Quejada Rojas - Claude — 24/11/2026

   Al vender (Vender y la carta digital) el cliente puede pedir "Sin ...".
   Antes la lista se filtraba por categoría de insumo y se perdían
   ingredientes que sí se quitan (ensalada, ripio, queso...).

   Este script crea SP_RECETA_QUITABLES: los ingredientes de la receta de
   cada producto activo, con la categoría del insumo. Solo se dejan por
   fuera las bebidas (productos de la categoría de menú "Bebidas") y los
   insumos de categorías de empaque, desechables o bebidas. La pantalla
   además oculta por nombre cajas, bolsas, servilletas, cubiertos y vasos.

   Lo que el cliente quita no se descuenta del inventario: eso ya lo hace
   SP_VENTA_REGISTRAR (script 013), que solo acepta insumos de la receta.

   No cambia datos; se puede ejecutar de nuevo.
   Si el script no se ha corrido, el sistema sigue funcionando con la
   lista de antes.
   ============================================================= */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.SP_RECETA_QUITABLES
AS
BEGIN
    SET NOCOUNT ON;
    SELECT r.IdProducto, r.IdInsumo, i.Nombre, ISNULL(c.Descripcion, '') AS Categoria
    FROM dbo.RECETA r
    INNER JOIN dbo.PRODUCTO_MENU p ON p.IdProducto = r.IdProducto AND p.Activo = 1
    LEFT JOIN dbo.CATEGORIA_MENU cm ON cm.IdCategoriaMenu = p.IdCategoriaMenu
    INNER JOIN dbo.INSUMO i ON i.IdInsumo = r.IdInsumo
    LEFT JOIN dbo.CATEGORIA c ON c.IdCategoria = i.IdCategoria
    WHERE ISNULL(cm.Nombre, '') NOT LIKE '%bebida%'
      AND ISNULL(c.Descripcion, '') NOT LIKE '%bebida%'
      AND ISNULL(c.Descripcion, '') NOT LIKE '%gaseosa%'
      AND ISNULL(c.Descripcion, '') NOT LIKE '%empaque%'
      AND ISNULL(c.Descripcion, '') NOT LIKE '%desechable%'
    ORDER BY r.IdProducto, i.Nombre;
END
GO

/* Para revisar: categorías de insumo que hay en la base (sale en el registro de la ejecución). */
SELECT c.IdCategoria, c.Descripcion, COUNT(i.IdInsumo) AS Insumos
FROM dbo.CATEGORIA c LEFT JOIN dbo.INSUMO i ON i.IdCategoria = c.IdCategoria
GROUP BY c.IdCategoria, c.Descripcion
ORDER BY c.IdCategoria;
GO
