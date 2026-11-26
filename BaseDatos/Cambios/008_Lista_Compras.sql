/* =============================================================
   LISTA DE COMPRAS: QUITAR INSUMOS (P. EJ. LA BOLSA ZIPLOC)
   Yesenia Quejada Rojas - Claude — 11/11/2026

   Crea la tabla INSUMO_FUERA_COMPRA y sus dos procedimientos. Un insumo
   que esté en esa tabla no sale en "Qué debo comprar" (pantalla, Excel ni
   tirilla), aunque se acabe. Sigue en el inventario y en las ventas.
   Desde la pantalla se quita con la X y se vuelve a incluir abajo.

   Al final deja fuera de la lista las bolsas ziploc.

   Ejecutar una vez en la base del hosting. Se puede volver a ejecutar
   sin problema. No borra ni cambia insumos, ventas ni inventario.
   ============================================================= */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('INSUMO_FUERA_COMPRA', 'U') IS NULL
CREATE TABLE INSUMO_FUERA_COMPRA (
    IdInsumo  INT NOT NULL PRIMARY KEY REFERENCES INSUMO(IdInsumo) ON DELETE CASCADE,
    Fecha     DATETIME NOT NULL DEFAULT GETDATE()
);
GO

CREATE OR ALTER PROCEDURE SP_COMPRA_FUERA_LISTAR
AS
    SELECT f.IdInsumo, i.Codigo, i.Nombre
    FROM INSUMO_FUERA_COMPRA f
    INNER JOIN INSUMO i ON i.IdInsumo = f.IdInsumo
    ORDER BY i.Nombre;
GO

/* @Fuera = 1 quita el insumo de la lista de compras; @Fuera = 0 lo vuelve a incluir */
CREATE OR ALTER PROCEDURE SP_COMPRA_FUERA_GUARDAR (
    @IdInsumo INT, @Fuera BIT, @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET NOCOUNT ON;
    SET @Resultado = 0; SET @Mensaje = '';
    IF NOT EXISTS (SELECT 1 FROM INSUMO WHERE IdInsumo = @IdInsumo)
    BEGIN SET @Mensaje = 'El insumo no existe'; RETURN; END

    IF @Fuera = 1
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM INSUMO_FUERA_COMPRA WHERE IdInsumo = @IdInsumo)
            INSERT INTO INSUMO_FUERA_COMPRA (IdInsumo) VALUES (@IdInsumo);
    END
    ELSE
        DELETE FROM INSUMO_FUERA_COMPRA WHERE IdInsumo = @IdInsumo;

    SET @Resultado = @IdInsumo;
END
GO

/* Bolsas ziploc fuera de la lista de compras (pedido del 09/11/2026).
   Primero se ven los insumos que se van a quitar. */
SELECT IdInsumo, Codigo, Nombre FROM INSUMO
WHERE REPLACE(REPLACE(Nombre, ' ', ''), '-', '') LIKE '%ziplo%'
   OR REPLACE(REPLACE(Nombre, ' ', ''), '-', '') LIKE '%ziplock%';

INSERT INTO INSUMO_FUERA_COMPRA (IdInsumo)
SELECT i.IdInsumo FROM INSUMO i
WHERE (REPLACE(REPLACE(i.Nombre, ' ', ''), '-', '') LIKE '%ziplo%'
    OR REPLACE(REPLACE(i.Nombre, ' ', ''), '-', '') LIKE '%ziplock%')
  AND NOT EXISTS (SELECT 1 FROM INSUMO_FUERA_COMPRA f WHERE f.IdInsumo = i.IdInsumo);
GO
