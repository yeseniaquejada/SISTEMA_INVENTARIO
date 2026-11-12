# Funciones compartidas por configurar.ps1, aplicar-sql.ps1 y publicar.ps1.
# Las claves se guardan cifradas con DPAPI de Windows en %LOCALAPPDATA%\SistemaInventario:
# solo el mismo usuario de Windows, en este mismo PC, puede leerlas. Nunca quedan en el repositorio.

$ErrorActionPreference = 'Stop'
$script:CarpetaSecretos = Join-Path $env:LOCALAPPDATA 'SistemaInventario'

function Get-RutaSecreto([string]$Nombre) {
    if (-not (Test-Path $script:CarpetaSecretos)) { New-Item -ItemType Directory -Path $script:CarpetaSecretos | Out-Null }
    return (Join-Path $script:CarpetaSecretos "$Nombre.xml")
}

function Get-ConfigBase([string]$Entorno) {
    $ruta = Get-RutaSecreto "bd-$Entorno"
    if (-not (Test-Path $ruta)) {
        throw "No hay conexión guardada para '$Entorno'. Ejecute primero: .\configurar.ps1 -Que BaseDatos -Entorno $Entorno"
    }
    return (Import-Clixml $ruta)
}

function New-CadenaConexion($cfg) {
    $b = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $b['Data Source'] = $cfg.Servidor
    $b['Initial Catalog'] = $cfg.Base
    if ($cfg.Credencial) {
        $b['User ID'] = $cfg.Credencial.UserName
        $b['Password'] = $cfg.Credencial.GetNetworkCredential().Password
    } else {
        $b['Integrated Security'] = $true
    }
    $b['TrustServerCertificate'] = $true
    $b['Encrypt'] = [bool]$cfg.Cifrar
    # Yesenia Quejada Rojas - Claude — 11/11/2026: LocalDB takes ~30 s to start when stopped; 30 s was not enough.
    $b['Connect Timeout'] = 60
    return $b.ConnectionString
}

function Get-ConfigPublicacion {
    $ruta = Join-Path $PSScriptRoot 'publicacion.config.json'
    if (-not (Test-Path $ruta)) { throw "Falta $ruta (copie publicacion.config.ejemplo.json y complételo)." }
    return (Get-Content $ruta -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Resolve-RutaRepo([string]$Relativa) {
    # Las rutas del config son relativas a la carpeta raíz del repositorio (la que contiene "herramientas").
    $raiz = Split-Path $PSScriptRoot -Parent
    if ([System.IO.Path]::IsPathRooted($Relativa)) { return $Relativa }
    return (Join-Path $raiz $Relativa)
}

function Write-Paso([string]$Texto) { Write-Host "`n== $Texto" -ForegroundColor Cyan }
