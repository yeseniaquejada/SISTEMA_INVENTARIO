/* =============================================================
   ARREGLO: ELIMINAR INSUMO QUEDABA A MEDIAS
   Yesenia Quejada Rojas - Claude — 10/11/2026

   Antes: si el insumo ya estaba en un conteo (u otro registro que la
   validación no revisaba), el SP borraba primero su cantidad por sede
   (INSUMO_SEDE) y luego fallaba al borrar el insumo. El insumo quedaba
   en la lista con cantidad 0 y salía un error de base de datos.

   Ahora: todo se hace en una transacción. Si algo impide borrarlo, no se
   toca nada y se devuelve el mensaje "Puede desactivarlo", con el que la
   pantalla de Insumos ofrece desactivarlo en el mismo paso.

   Ejecutar una vez en la base. Se puede volver a ejecutar sin problema.
   No borra ni cambia datos: solo reemplaza el procedimiento.
   ============================================================= */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE SP_INSUMO_ELIMINAR (@IdInsumo INT, @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET NOCOUNT ON;
    SET @Resultado = 0; SET @Mensaje = '';
    DECLARE @Historial VARCHAR(500) =
        'Este insumo ya tiene historial (conteos, compras o ventas) y no se puede borrar. Puede desactivarlo para que no se use más.';

    IF NOT EXISTS (SELECT 1 FROM INSUMO WHERE IdInsumo = @IdInsumo)
    BEGIN SET @Mensaje = 'El insumo no existe'; RETURN; END

    IF EXISTS (SELECT 1 FROM MOVIMIENTO WHERE IdInsumo = @IdInsumo)
       OR EXISTS (SELECT 1 FROM RECETA WHERE IdInsumo = @IdInsumo)
       OR EXISTS (SELECT 1 FROM MODIFICADOR WHERE IdInsumo = @IdInsumo)
       OR EXISTS (SELECT 1 FROM LOTE WHERE IdInsumo = @IdInsumo)
       OR EXISTS (SELECT 1 FROM CONTEO_DETALLE WHERE IdInsumo = @IdInsumo)
    BEGIN SET @Mensaje = @Historial; RETURN; END

    BEGIN TRY
        BEGIN TRAN;
        -- La nota "por confirmar" (INSUMO_PENDIENTE) se borra sola con el insumo (ON DELETE CASCADE).
        DELETE FROM INSUMO_SEDE WHERE IdInsumo = @IdInsumo;
        DELETE FROM INSUMO WHERE IdInsumo = @IdInsumo;
        COMMIT;
        SET @Resultado = 1;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        -- 547 = otra tabla usa este insumo: no se borra nada y se ofrece desactivarlo
        SET @Mensaje = CASE WHEN ERROR_NUMBER() = 547 THEN @Historial ELSE LEFT(ERROR_MESSAGE(), 500) END;
    END CATCH
END
GO
