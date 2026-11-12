/* =============================================================
   DATOS POR CONFIRMAR DE LOS INSUMOS
   Guarda una nota por insumo con lo que falta averiguar con el cliente
   (cantidad que no se leía, unidad dudosa, etc.). La pantalla de Insumos
   la muestra resaltada hasta que alguien corrija el dato y borre la nota.
   Ejecutar una vez en la base del cliente. Se puede volver a ejecutar sin problema.
   ============================================================= */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('INSUMO_PENDIENTE', 'U') IS NULL
CREATE TABLE INSUMO_PENDIENTE (
    IdInsumo  INT NOT NULL PRIMARY KEY REFERENCES INSUMO(IdInsumo) ON DELETE CASCADE,
    Nota      VARCHAR(300) NOT NULL,
    Fecha     DATETIME NOT NULL DEFAULT GETDATE()
);
GO

CREATE OR ALTER PROCEDURE SP_INSUMO_PENDIENTE_LISTAR
AS
    SELECT IdInsumo, Nota FROM INSUMO_PENDIENTE;
GO

/* Nota vacía = el dato ya se confirmó y se borra la nota */
CREATE OR ALTER PROCEDURE SP_INSUMO_PENDIENTE_GUARDAR (
    @IdInsumo INT, @Nota VARCHAR(300), @Resultado INT OUTPUT, @Mensaje VARCHAR(500) OUTPUT)
AS
BEGIN
    SET @Resultado = 0; SET @Mensaje = '';
    SET @Nota = LTRIM(RTRIM(ISNULL(@Nota, '')));
    IF NOT EXISTS (SELECT 1 FROM INSUMO WHERE IdInsumo = @IdInsumo)
    BEGIN SET @Mensaje = 'El insumo no existe'; RETURN; END
    IF @Nota = ''
        DELETE FROM INSUMO_PENDIENTE WHERE IdInsumo = @IdInsumo;
    ELSE IF EXISTS (SELECT 1 FROM INSUMO_PENDIENTE WHERE IdInsumo = @IdInsumo)
        UPDATE INSUMO_PENDIENTE SET Nota = @Nota, Fecha = GETDATE() WHERE IdInsumo = @IdInsumo;
    ELSE
        INSERT INTO INSUMO_PENDIENTE (IdInsumo, Nota) VALUES (@IdInsumo, @Nota);
    SET @Resultado = @IdInsumo;
END
GO
