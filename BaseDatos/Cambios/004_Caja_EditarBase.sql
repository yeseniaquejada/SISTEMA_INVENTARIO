-- Yesenia Quejada Rojas - Claude — 04/11/2026
-- Permite corregir la base de caja (efectivo con que se abrió el cajón) mientras la caja siga ABIERTA.
-- El efectivo esperado se calcula con CAJA.BaseInicial, así que al corregirla el esperado y el cierre quedan bien.
-- Ejecutar una sola vez en la base de datos del hosting (se puede volver a correr sin problema).
CREATE OR ALTER PROCEDURE SP_CAJA_EDITAR_BASE (
    @IdSede INT, @IdUsuario INT, @BaseInicial DECIMAL(12,2),
    @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET NOCOUNT ON;
    SET @Resultado = 0; SET @Mensaje = '';
    IF @BaseInicial IS NULL OR @BaseInicial < 0
    BEGIN SET @Mensaje = 'La base de caja no puede ser negativa'; RETURN; END

    DECLARE @IdCaja INT = (SELECT IdCaja FROM CAJA WHERE IdSede = @IdSede AND Estado = 'ABIERTA');
    IF @IdCaja IS NULL BEGIN SET @Mensaje = 'No hay una caja abierta en esta sede'; RETURN; END

    UPDATE CAJA SET BaseInicial = @BaseInicial WHERE IdCaja = @IdCaja AND Estado = 'ABIERTA';
    IF @@ROWCOUNT = 0 BEGIN SET @Mensaje = 'La caja ya se cerró; recargue la página'; RETURN; END

    SET @Resultado = @IdCaja;
    SET @Mensaje = 'Base de caja actualizada';
END
GO
