-- Yesenia Quejada Rojas - Claude — 09/11/2026
-- Arreglo: crea SP_CAJA_EDITAR_BASE en el hosting. Funciona aunque el SP no exista
-- y en cualquier versión de SQL Server. No toca tablas ni datos. Se puede correr varias veces.
IF OBJECT_ID('dbo.SP_CAJA_EDITAR_BASE', 'P') IS NULL
    EXEC('CREATE PROCEDURE dbo.SP_CAJA_EDITAR_BASE AS RETURN 0');
GO
ALTER PROCEDURE dbo.SP_CAJA_EDITAR_BASE (
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
-- Comprobación: debe mostrar una fila con el nombre del SP.
SELECT name, create_date, modify_date FROM sys.procedures WHERE name = 'SP_CAJA_EDITAR_BASE';
GO
