<#
  Guarda (cifrados con DPAPI, solo para este usuario de Windows) los datos de conexión.
  Se ejecuta UNA vez por PC y entorno. La clave se escribe en la ventana, nunca en el chat.

  Ejemplos:
    .\configurar.ps1 -Que BaseDatos  -Entorno hosting
    .\configurar.ps1 -Que BaseDatos  -Entorno local
    .\configurar.ps1 -Que Publicacion -Entorno hosting     (usuario y clave de Web Deploy / FTP)
    .\configurar.ps1 -Que Probar     -Entorno hosting     (solo prueba la conexión a la base)
#>
param(
    [Parameter(Mandatory)][ValidateSet('BaseDatos', 'Publicacion', 'Probar')][string]$Que,
    [Parameter(Mandatory)][string]$Entorno
)
. (Join-Path $PSScriptRoot 'comun.ps1')

if ($Que -eq 'BaseDatos') {
    $servidor = Read-Host 'Servidor SQL (ej. sql1234.site4now.net o (localdb)\MSSQLLocalDB)'
    $base = Read-Host 'Nombre de la base (ej. DB_INVENTARIO_COMIDAS)'
    $modo = Read-Host '¿Usuario SQL (S) o autenticación de Windows (W)? [S/W]'
    $cred = $null
    if ($modo -match '^[sS]') { $cred = Get-Credential -Message "Usuario y clave SQL de $Entorno" }
    $cifrar = (Read-Host '¿El hosting exige conexión cifrada (Encrypt)? [s/N]') -match '^[sS]'
    $cfg = [pscustomobject]@{ Servidor = $servidor; Base = $base; Credencial = $cred; Cifrar = $cifrar }
    $cfg | Export-Clixml (Get-RutaSecreto "bd-$Entorno")
    Write-Host "Guardado. Probando conexión..." -ForegroundColor Green
    $Que = 'Probar'
}

if ($Que -eq 'Publicacion') {
    $cred = Get-Credential -Message "Usuario y clave para publicar en $Entorno (Web Deploy o FTP)"
    $cred | Export-Clixml (Get-RutaSecreto "pub-$Entorno")
    Write-Host "Guardado en $(Get-RutaSecreto "pub-$Entorno") (cifrado)." -ForegroundColor Green
    return
}

if ($Que -eq 'Probar') {
    $cfg = Get-ConfigBase $Entorno
    $cn = New-Object System.Data.SqlClient.SqlConnection (New-CadenaConexion $cfg)
    $cn.Open()
    $cmd = $cn.CreateCommand()
    $cmd.CommandText = "SELECT DB_NAME() AS Base, @@VERSION AS Version, (SELECT COUNT(*) FROM sys.procedures) AS Procedimientos"
    $dr = $cmd.ExecuteReader(); $null = $dr.Read()
    Write-Host ("Conectado a {0}. Procedimientos: {1}" -f $dr['Base'], $dr['Procedimientos']) -ForegroundColor Green
    Write-Host (($dr['Version'] -split "`n")[0])
    $cn.Close()
}
