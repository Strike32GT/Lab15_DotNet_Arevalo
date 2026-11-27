param(
    [string]$Configuracion = "Debug",
    [switch]$SinCompilar
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$raiz = Split-Path -Parent $PSScriptRoot
$logs = Join-Path $raiz "logs"
New-Item -ItemType Directory -Force $logs | Out-Null

if (-not $SinCompilar) {
    Write-Host "Compilando la solución..." -ForegroundColor Cyan
    dotnet build (Join-Path $raiz "Lab15.slnx") -v q --nologo | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "La compilación falló." }
}

$servicios = @(
    [pscustomobject]@{
        Nombre   = "Restaurante.Api"
        Puerto   = 5001
        Proyecto = Join-Path $raiz "Restaurante.Api"
        Dll      = Join-Path $raiz "Restaurante.Api\bin\$Configuracion\net10.0\Restaurante.Api.dll"
        Listo    = "http://localhost:5001/api/platos"
    },
    [pscustomobject]@{
        Nombre   = "Reservas.Api"
        Puerto   = 5002
        Proyecto = Join-Path $raiz "Reservas.Api"
        Dll      = Join-Path $raiz "Reservas.Api\bin\$Configuracion\net10.0\Reservas.Api.dll"
        Listo    = "http://localhost:5002/api/reservas"
    },
    [pscustomobject]@{
        Nombre   = "GatewayApi"
        Puerto   = 5000
        Proyecto = Join-Path $raiz "GatewayApi"
        Dll      = Join-Path $raiz "GatewayApi\bin\$Configuracion\net10.0\GatewayApi.dll"
        Listo    = "http://localhost:5000/gateway/platos"
    }
)

function Esperar-Puerto {
    param([int]$Puerto, [int]$Segundos = 45)

    $fin = (Get-Date).AddSeconds($Segundos)
    while ((Get-Date) -lt $fin) {
        $cliente = New-Object System.Net.Sockets.TcpClient
        try {
            $tarea = $cliente.ConnectAsync("127.0.0.1", $Puerto)
            if ($tarea.Wait(500) -and $cliente.Connected) { return $true }
        }
        catch { }
        finally { $cliente.Dispose() }
        Start-Sleep -Milliseconds 400
    }
    return $false
}

$iniciados = @()

foreach ($servicio in $servicios) {
    if (Esperar-Puerto -Puerto $servicio.Puerto -Segundos 1) {
        Write-Host "El puerto $($servicio.Puerto) ya está ocupado. Se omite $($servicio.Nombre)." -ForegroundColor Yellow
        continue
    }

    if (-not (Test-Path $servicio.Dll)) {
        throw "No se encontró $($servicio.Dll). Ejecute sin -SinCompilar."
    }

    $salida = Join-Path $logs "$($servicio.Nombre).out.log"
    $errorLog = Join-Path $logs "$($servicio.Nombre).err.log"

    $parametros = @{
        FilePath               = "dotnet"
        ArgumentList           = @($servicio.Dll, "--urls", "http://localhost:$($servicio.Puerto)")
        WorkingDirectory       = $servicio.Proyecto
        RedirectStandardOutput = $salida
        RedirectStandardError  = $errorLog
        PassThru               = $true
        WindowStyle            = "Hidden"
    }

    # PowerShell 7.4+ permite definir variables de entorno del proceso.
    if ([version]$PSVersionTable.PSVersion -ge [version]'7.4') {
        $parametros["Environment"] = @{ ASPNETCORE_ENVIRONMENT = "Development" }
        $proceso = Start-Process @parametros
    }
    else {
        $env:ASPNETCORE_ENVIRONMENT = "Development"
        $proceso = Start-Process @parametros
        Remove-Item Env:ASPNETCORE_ENVIRONMENT
    }

    if (-not (Esperar-Puerto -Puerto $servicio.Puerto)) {
        Write-Host "No respondió el puerto $($servicio.Puerto). Revise $errorLog." -ForegroundColor Red
        throw "No se pudo iniciar $($servicio.Nombre)."
    }

    $iniciados += [pscustomobject]@{
        Nombre = $servicio.Nombre
        Puerto = $servicio.Puerto
        Pid    = $proceso.Id
        Url    = "http://localhost:$($servicio.Puerto)"
    }

    Write-Host "OK  $($servicio.Nombre) -> http://localhost:$($servicio.Puerto) (PID $($proceso.Id))" -ForegroundColor Green
}

$archivoPids = Join-Path $logs "pids.json"
$iniciados | ConvertTo-Json | Set-Content $archivoPids -Encoding UTF8

Write-Host ""
Write-Host "Servicios en ejecución:" -ForegroundColor Cyan
$iniciados | Format-Table Nombre, Puerto, Pid, Url -AutoSize | Out-Host
Write-Host "Registros en $logs"
Write-Host "Detenga todo con: powershell -ExecutionPolicy Bypass -File scripts/detener-servicios.ps1"
