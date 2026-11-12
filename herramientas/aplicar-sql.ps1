<#
  Ejecuta en orden los scripts de BaseDatos\Cambios que aún no se han corrido en la base elegida.
  Lleva el registro en la tabla dbo.HISTORIAL_SCRIPTS (se crea sola): nombre, huella (hash),
  fecha, usuario de Windows y resultado. Un script que ya está registrado no se vuelve a ejecutar.

  Ejemplos:
    .\aplicar-sql.ps1 -Entorno hosting -Ver                 (solo lista los pendientes, no ejecuta nada)
    .\aplicar-sql.ps1 -Entorno hosting                      (ejecuta los pendientes; pide confirmar)
    .\aplicar-sql.ps1 -Entorno hosting -SinPreguntar        (para que Claude lo corra sin la pregunta)
    .\aplicar-sql.ps1 -Entorno hosting -MarcarHasta 010     (registra 001..010 como YA ejecutados, sin correrlos)

  Reglas para los scripts nuevos:
    - Nombre: NNN_Descripcion.sql (3 dígitos, el siguiente número libre). Nunca se renumera uno ya ejecutado.
    - Deben poder correrse más de una vez (IF EXISTS / CREATE OR ALTER) y manejar su propia transacción.
    - Si un script registrado se modifica, el programa avisa (la huella cambia) y no lo vuelve a correr:
      para corregirlo se crea un script nuevo con el siguiente número.
    - Separadores GO en su propia línea, como en SSMS.
#>
param(
    [Parameter(Mandatory)][string]$Entorno,
    [string]$Carpeta = '',
    [switch]$Ver,
    [switch]$SinPreguntar,
    [string]$MarcarHasta = ''
)
. (Join-Path $PSScriptRoot 'comun.ps1')

if (-not $Carpeta) { $Carpeta = Resolve-RutaRepo 'BaseDatos\Cambios' }
$cfg = Get-ConfigBase $Entorno
$carpetaLog = Resolve-RutaRepo 'BaseDatos\Resultados'
if (-not (Test-Path $carpetaLog)) { New-Item -ItemType Directory -Path $carpetaLog | Out-Null }
$log = Join-Path $carpetaLog ("{0:yyyyMMdd_HHmmss}_{1}.txt" -f (Get-Date), $Entorno)

function Log([string]$t, [string]$color = 'Gray') { Write-Host $t -ForegroundColor $color; Add-Content -Path $log -Value $t -Encoding UTF8 }

$cn = New-Object System.Data.SqlClient.SqlConnection (New-CadenaConexion $cfg)
$cn.FireInfoMessageEventOnUserErrors = $false
$cn.add_InfoMessage({ param($s, $e) Log ("   " + $e.Message) })
try {
    $cn.Open()

    function Exec([string]$sql, [switch]$Mostrar) {
        $cmd = $cn.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 600
        if (-not $Mostrar) { return $cmd.ExecuteNonQuery() }
        $dr = $cmd.ExecuteReader()
        while (-not $dr.IsClosed) {
            if ($dr.FieldCount -gt 0) {
                # Load lee el resultado y pasa solo al siguiente (cierra el lector al final)
                $tabla = New-Object System.Data.DataTable; $tabla.Load($dr)
                if ($tabla.Rows.Count -gt 0) { Log (($tabla | Format-Table -AutoSize | Out-String -Width 220).TrimEnd()) }
            } elseif (-not $dr.NextResult()) { break }
        }
        if (-not $dr.IsClosed) { $dr.Close() }
    }

    Exec @"
IF OBJECT_ID('dbo.HISTORIAL_SCRIPTS','U') IS NULL
CREATE TABLE dbo.HISTORIAL_SCRIPTS (
    Nombre       VARCHAR(200)  NOT NULL PRIMARY KEY,
    Huella       CHAR(64)      NULL,
    FechaEjecucion DATETIME    NOT NULL DEFAULT GETDATE(),
    EjecutadoPor VARCHAR(100)  NULL,
    Modo         VARCHAR(20)   NOT NULL   -- EJECUTADO o MARCADO
);
"@ | Out-Null

    $hechos = @{}
    $cmd = $cn.CreateCommand(); $cmd.CommandText = 'SELECT Nombre, Huella FROM dbo.HISTORIAL_SCRIPTS'
    $dr = $cmd.ExecuteReader(); while ($dr.Read()) { $hechos[$dr.GetString(0)] = if ($dr.IsDBNull(1)) { '' } else { $dr.GetString(1) } }; $dr.Close()

    $archivos = Get-ChildItem -Path $Carpeta -Filter '*.sql' | Where-Object { $_.Name -match '^\d{3}_' } | Sort-Object Name
    $pendientes = @()
    foreach ($a in $archivos) {
        $huella = (Get-FileHash $a.FullName -Algorithm SHA256).Hash
        if ($hechos.ContainsKey($a.Name)) {
            if ($hechos[$a.Name] -and $hechos[$a.Name] -ne $huella) { Log "AVISO: $($a.Name) cambió después de ejecutarse. No se vuelve a correr; cree un script nuevo." 'Yellow' }
        } else { $pendientes += [pscustomobject]@{ Archivo = $a; Huella = $huella } }
    }

    Log ("Base: {0} en {1} ({2})" -f $cfg.Base, $cfg.Servidor, $Entorno) 'Cyan'

    if ($MarcarHasta) {
        foreach ($p in $pendientes | Where-Object { $_.Archivo.Name.Substring(0, 3) -le $MarcarHasta }) {
            $c = $cn.CreateCommand()
            $c.CommandText = "INSERT INTO dbo.HISTORIAL_SCRIPTS (Nombre, Huella, EjecutadoPor, Modo) VALUES (@n, @h, @u, 'MARCADO')"
            $null = $c.Parameters.AddWithValue('@n', $p.Archivo.Name); $null = $c.Parameters.AddWithValue('@h', $p.Huella); $null = $c.Parameters.AddWithValue('@u', $env:USERNAME)
            $null = $c.ExecuteNonQuery(); Log "Marcado como ya ejecutado: $($p.Archivo.Name)" 'Green'
        }
        return
    }

    if ($pendientes.Count -eq 0) { Log 'No hay scripts pendientes.' 'Green'; return }
    Log 'Pendientes, en este orden:' 'Cyan'
    $pendientes | ForEach-Object { Log ("  - " + $_.Archivo.Name) }
    if ($Ver) { return }
    if (-not $SinPreguntar) {
        if ((Read-Host "¿Ejecutar $($pendientes.Count) script(s) en '$Entorno'? [s/N]") -notmatch '^[sS]') { Log 'Cancelado.'; return }
    }

    foreach ($p in $pendientes) {
        Log "`n>> $($p.Archivo.Name)" 'Cyan'
        $texto = Get-Content $p.Archivo.FullName -Raw -Encoding UTF8
        $lotes = [regex]::Split($texto, '(?im)^\s*GO\s*(?:--.*)?$') | Where-Object { $_.Trim() }
        try {
            foreach ($lote in $lotes) { Exec $lote -Mostrar }
        } catch {
            Log ("ERROR en $($p.Archivo.Name): " + $_.Exception.GetBaseException().Message) 'Red'
            Log 'Se detuvo aquí. Los scripts siguientes no se ejecutaron. Resultado completo en:' 'Red'
            Log $log
            exit 1
        }
        $c = $cn.CreateCommand()
        $c.CommandText = "INSERT INTO dbo.HISTORIAL_SCRIPTS (Nombre, Huella, EjecutadoPor, Modo) VALUES (@n, @h, @u, 'EJECUTADO')"
        $null = $c.Parameters.AddWithValue('@n', $p.Archivo.Name); $null = $c.Parameters.AddWithValue('@h', $p.Huella); $null = $c.Parameters.AddWithValue('@u', $env:USERNAME)
        $null = $c.ExecuteNonQuery()
        Log "OK: $($p.Archivo.Name)" 'Green'
    }
    Log "`nListo. Resultado en $log" 'Green'
}
finally {
    if ($cn.State -eq 'Open') { $cn.Close() }
}
