param(
    [string]$BaseUrl = "http://localhost:5000",
    [string]$ReservasUrl = "http://localhost:5002",
    [switch]$NoReiniciar
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$raiz = Split-Path -Parent $PSScriptRoot
$logs = Join-Path $raiz "logs"
New-Item -ItemType Directory -Force $logs | Out-Null

function Invoke-Api {
    param([string]$Metodo, [string]$Url, [string]$Token, $Cuerpo)

    $parametros = @{
        Uri             = $Url
        Method          = $Metodo
        TimeoutSec      = 30
        UseBasicParsing = $true
    }
    if ($PSVersionTable.PSVersion.Major -ge 7) { $parametros["SkipHttpErrorCheck"] = $true }
    if ($Token) { $parametros["Headers"] = @{ Authorization = "Bearer $Token" } }
    if ($null -ne $Cuerpo) {
        $parametros["ContentType"] = "application/json"
        $parametros["Body"] = ($Cuerpo | ConvertTo-Json -Depth 6 -Compress)
    }

    try {
        $r = Invoke-WebRequest @parametros
        return [pscustomobject]@{ Codigo = [int]$r.StatusCode; Cuerpo = [string]$r.Content }
    }
    catch {
        $resp = $_.Exception.Response
        if ($null -eq $resp) { throw }
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            return [pscustomobject]@{
                Codigo = [int]$resp.StatusCode
                Cuerpo = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            }
        }
        $lector = New-Object System.IO.StreamReader($resp.GetResponseStream())
        $texto = $lector.ReadToEnd(); $lector.Dispose()
        return [pscustomobject]@{ Codigo = [int]$resp.StatusCode; Cuerpo = $texto }
    }
}

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

Write-Host "=== Prueba de 502 Bad Gateway ===" -ForegroundColor Cyan

$login = Invoke-Api -Metodo "POST" -Url "$BaseUrl/gateway/auth/login" -Cuerpo @{
    correo = "chef@restaurante.com"
    clave  = "Chef123!"
}
if ($login.Codigo -ne 200) { throw "No se pudo iniciar sesión por el gateway (código $($login.Codigo))." }
$token = ($login.Cuerpo | ConvertFrom-Json).token

$conexion = Get-NetTCPConnection -LocalPort 5002 -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($null -eq $conexion) {
    throw "Reservas.Api no está escuchando en el puerto 5002. Inícielo antes de probar el 502."
}

$pidReservas = $conexion.OwningProcess
Write-Host "Deteniendo Reservas.Api (PID $pidReservas)..." -ForegroundColor Yellow
Stop-Process -Id $pidReservas -Force
Start-Sleep -Seconds 2

$respuesta = Invoke-Api -Metodo "GET" -Url "$BaseUrl/gateway/reservas" -Token $token
$estado = if ($respuesta.Codigo -eq 502) { "OK" } else { "FALLO" }

Write-Host ""
Write-Host "GET $BaseUrl/gateway/reservas con Reservas.Api detenido"
Write-Host "Esperado: 502  Obtenido: $($respuesta.Codigo)  $estado" -ForegroundColor $(if ($estado -eq "OK") { "Green" } else { "Red" })
if ($respuesta.Cuerpo) { Write-Host "Cuerpo: $($respuesta.Cuerpo)" }

$platos = Invoke-Api -Metodo "GET" -Url "$BaseUrl/gateway/platos"
Write-Host "Mientras tanto, GET $BaseUrl/gateway/platos responde $($platos.Codigo) (el microservicio 1 sigue disponible)."

$lineas = @(
    "# Prueba de 502 Bad Gateway",
    "",
    "Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "",
    "| Caso | Método | Ruta | Esperado | Obtenido | Estado |",
    "| :--- | :--- | :--- | :--- | :--- | :--- |",
    "| Reservas con el microservicio 2 detenido | GET | ``/gateway/reservas`` | 502 | $($respuesta.Codigo) | $estado |",
    "| El microservicio 1 sigue funcionando | GET | ``/gateway/platos`` | 200 | $($platos.Codigo) | $(if ($platos.Codigo -eq 200) { 'OK' } else { 'FALLO' }) |",
    "",
    "El gateway respondió 502 porque no pudo conectarse al host/puerto de destino (localhost:5002)."
)
$archivo = Join-Path $logs "prueba-502.md"
$lineas | Set-Content $archivo -Encoding UTF8
Write-Host "Resultado guardado en $archivo"

if (-not $NoReiniciar) {
    Write-Host ""
    Write-Host "Reiniciando Reservas.Api..." -ForegroundColor Cyan
    $dll = Join-Path $raiz "Reservas.Api\bin\Debug\net10.0\Reservas.Api.dll"
    $salida = Join-Path $logs "Reservas.Api.out.log"
    $errorLog = Join-Path $logs "Reservas.Api.err.log"

    $parametros = @{
        FilePath               = "dotnet"
        ArgumentList           = @($dll, "--urls", "http://localhost:5002")
        WorkingDirectory       = Join-Path $raiz "Reservas.Api"
        RedirectStandardOutput = $salida
        RedirectStandardError  = $errorLog
        PassThru               = $true
        WindowStyle            = "Hidden"
    }
    if ([version]$PSVersionTable.PSVersion -ge [version]'7.4') {
        $parametros["Environment"] = @{ ASPNETCORE_ENVIRONMENT = "Development" }
    }

    $proceso = Start-Process @parametros
    if (Esperar-Puerto -Puerto 5002) {
        Write-Host "Reservas.Api reiniciado en http://localhost:5002 (PID $($proceso.Id))" -ForegroundColor Green

        $archivoPids = Join-Path $logs "pids.json"
        if (Test-Path $archivoPids) {
            $pids = Get-Content $archivoPids -Raw | ConvertFrom-Json
            if ($pids -isnot [array]) { $pids = @($pids) }
            foreach ($p in $pids) {
                if ($p.Nombre -eq "Reservas.Api") { $p.Pid = $proceso.Id }
            }
            $pids | ConvertTo-Json | Set-Content $archivoPids -Encoding UTF8
        }
    }
    else {
        Write-Host "No se pudo reiniciar Reservas.Api. Revise $errorLog." -ForegroundColor Red
    }
}

if ($estado -ne "OK") { exit 1 }
