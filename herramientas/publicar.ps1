<#
  Compila y publica CapaPresentacion según herramientas\publicacion.config.json.

  Ejemplos:
    .\publicar.ps1 -Entorno hosting
    .\publicar.ps1 -Entorno iis-local
    .\publicar.ps1 -Entorno hosting -SoloCompilar      (compila y deja la salida en .\publicado, no sube nada)

  Métodos (campo "Metodo" del entorno en el config):
    WebDeploy : usa el perfil .pubxml que ya tiene en Visual Studio (Properties\PublishProfiles).
                La clave sale de lo guardado con: .\configurar.ps1 -Que Publicacion -Entorno hosting
    Zip       : deja un .zip en .\publicado-zip para subirlo en el panel del hosting (sin appsettings.json ni fotos).
    Carpeta   : copia a la carpeta física de un sitio IIS (local o en red). Pone app_offline.htm mientras copia.

  En ningún método se borran archivos del servidor que no estén en la publicación (fotos de wwwroot\uploads,
  logs) y no se reemplazan los archivos de "NoReemplazar" (por defecto appsettings.json del servidor).
#>
param(
    [Parameter(Mandatory)][string]$Entorno,
    [switch]$SoloCompilar
)
. (Join-Path $PSScriptRoot 'comun.ps1')

$config = Get-ConfigPublicacion
$ent = $config.Entornos.$Entorno
if (-not $ent) { throw "El entorno '$Entorno' no está en publicacion.config.json." }
$proyecto = Resolve-RutaRepo $config.Proyecto
$salida = Resolve-RutaRepo 'publicado'
$noReemplazar = @($ent.NoReemplazar)
if ($noReemplazar.Count -eq 0 -or -not $noReemplazar[0]) { $noReemplazar = @('appsettings.json', 'appsettings.Production.json') }

Write-Paso "Compilando $proyecto"
if (Test-Path $salida) { Remove-Item $salida -Recurse -Force }
& dotnet publish $proyecto -c Release -o $salida --nologo
if ($LASTEXITCODE -ne 0) { throw 'La compilación falló. No se publicó nada.' }
# Las fotos subidas viven en el servidor; nunca se suben desde aquí
$uploads = Join-Path $salida 'wwwroot\uploads'
if (Test-Path $uploads) { Remove-Item $uploads -Recurse -Force }
if ($SoloCompilar) { Write-Host "Compilado en $salida" -ForegroundColor Green; return }

switch ($ent.Metodo) {
    'Carpeta' {
        $destino = $ent.RutaSitio
        if (-not (Test-Path $destino)) { throw "No existe la carpeta del sitio: $destino" }
        Write-Paso "Copiando a $destino"
        $offline = Join-Path $destino 'app_offline.htm'
        Set-Content -Path $offline -Value '<html><body style="font-family:sans-serif"><h2>Actualizando el sistema, vuelva en un minuto...</h2></body></html>' -Encoding UTF8
        Start-Sleep -Seconds 3
        try {
            # /E sin /PURGE: agrega y reemplaza, no borra lo que solo existe en el servidor
            $excluir = @('app_offline.htm') + $noReemplazar
            & robocopy $salida $destino /E /R:3 /W:2 /NFL /NDL /NP /XF $excluir /XD (Join-Path $salida 'wwwroot\uploads')
            if ($LASTEXITCODE -ge 8) { throw "robocopy falló (código $LASTEXITCODE)" }
        } finally { Remove-Item $offline -Force -ErrorAction SilentlyContinue }
    }
    'WebDeploy' {
        $cred = Import-Clixml (Get-RutaSecreto "pub-$Entorno")
        Write-Paso "Publicando con Web Deploy en $($ent.Sitio)$($ent.Perfil)"
        $skip = ($noReemplazar | ForEach-Object { "<MsDeploySkipRules Include=`"No_$($_)`"><ObjectName>filePath</ObjectName><AbsolutePath>$([regex]::Escape($_))$</AbsolutePath></MsDeploySkipRules>" }) -join ''
        $props = Join-Path $env:TEMP 'inventario-skip.targets'
        Set-Content -Path $props -Encoding UTF8 -Value "<Project><ItemGroup>$skip<MsDeploySkipRules Include=`"No_uploads`"><ObjectName>dirPath</ObjectName><AbsolutePath>wwwroot\\uploads</AbsolutePath></MsDeploySkipRules></ItemGroup></Project>"
        # Con "Perfil" usa un .pubxml; si no, toma ServidorWebDeploy y Sitio del config
        # (en SmarterASP: Websites > Show Deployment Information).
        $destinoArgs = @()
        if ($ent.Perfil) { $destinoArgs += "/p:PublishProfile=$($ent.Perfil)" }
        else {
            $destinoArgs += '/p:WebPublishMethod=MSDeploy', '/p:MSDeployPublishMethod=WMSVC', '/p:EnableMSDeployAppOffline=true',
                "/p:MSDeployServiceURL=$($ent.ServidorWebDeploy)", "/p:DeployIisAppPath=$($ent.Sitio)"
        }
        & dotnet publish $proyecto -c Release --nologo @destinoArgs `
            "/p:UserName=$($cred.UserName)" `
            "/p:Password=$($cred.GetNetworkCredential().Password)" `
            '/p:SkipExtraFilesOnServer=true' `
            '/p:AllowUntrustedCertificate=true' `
            "/p:CustomAfterMicrosoftCommonTargets=$props"
        Remove-Item $props -Force -ErrorAction SilentlyContinue
        if ($LASTEXITCODE -ne 0) { throw 'La publicación con Web Deploy falló.' }
    }
    'Zip' {
        # Para hostings donde se sube un .zip por el panel. El zip no lleva appsettings.json
        # (el del servidor tiene la conexión del hosting) ni las fotos.
        foreach ($n in $noReemplazar) { Get-ChildItem $salida -Filter $n -File | Remove-Item -Force }
        $carpetaZip = Resolve-RutaRepo 'publicado-zip'
        if (-not (Test-Path $carpetaZip)) { New-Item -ItemType Directory -Path $carpetaZip | Out-Null }
        $zip = Join-Path $carpetaZip ("inventario_{0:yyyyMMdd_HHmm}.zip" -f (Get-Date))
        Compress-Archive -Path (Join-Path $salida '*') -DestinationPath $zip -CompressionLevel Optimal
        Write-Host "`nZip listo para subir en el panel del hosting:`n  $zip" -ForegroundColor Green
        Write-Host 'Al descomprimir en el servidor elija reemplazar archivos; no borre la carpeta wwwroot\uploads.' -ForegroundColor Yellow
    }
    default { throw "Método '$($ent.Metodo)' no soportado todavía (use Zip, Carpeta o WebDeploy)." }
}

if ($ent.Url) {
    Write-Paso "Comprobando $($ent.Url)"
    try {
        $r = Invoke-WebRequest -Uri $ent.Url -UseBasicParsing -TimeoutSec 60 -MaximumRedirection 5
        Write-Host "Responde: HTTP $($r.StatusCode)" -ForegroundColor Green
    } catch { Write-Host "AVISO: la página no respondió bien: $($_.Exception.Message)" -ForegroundColor Yellow }
}
Write-Host "`nPublicado en '$Entorno'." -ForegroundColor Green
