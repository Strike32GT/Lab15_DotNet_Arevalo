param()

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$raiz = Split-Path -Parent $PSScriptRoot
$archivoPids = Join-Path $raiz "logs\pids.json"

if (-not (Test-Path $archivoPids)) {
    Write-Host "No hay PIDs registrados en $archivoPids." -ForegroundColor Yellow
    return
}

$procesos = Get-Content $archivoPids -Raw | ConvertFrom-Json
if ($procesos -isnot [array]) { $procesos = @($procesos) }

foreach ($proceso in $procesos) {
    $actual = Get-Process -Id $proceso.Pid -ErrorAction SilentlyContinue
    if ($null -eq $actual) {
        Write-Host "Ya estaba detenido: $($proceso.Nombre) (PID $($proceso.Pid))" -ForegroundColor DarkGray
        continue
    }

    Stop-Process -Id $proceso.Pid -Force
    Write-Host "Detenido: $($proceso.Nombre) (PID $($proceso.Pid))" -ForegroundColor Green
}

Remove-Item $archivoPids -Force -ErrorAction SilentlyContinue
