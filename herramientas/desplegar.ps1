<#
  Todo en un paso, en el orden correcto:
    1. Ejecuta los scripts SQL pendientes (primero la base, para que existan los procedimientos nuevos).
    2. Compila y publica la página.
  Si el paso 1 falla, no publica.

    .\desplegar.ps1 -Entorno hosting
    .\desplegar.ps1 -Entorno hosting -SinPreguntar
#>
param(
    [Parameter(Mandatory)][string]$Entorno,
    [switch]$SinPreguntar
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'aplicar-sql.ps1') -Entorno $Entorno -SinPreguntar:$SinPreguntar
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw 'Falló un script SQL. No se publicó.' }
& (Join-Path $PSScriptRoot 'publicar.ps1') -Entorno $Entorno
