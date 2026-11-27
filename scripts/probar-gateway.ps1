param(
    [string]$BaseUrl = "http://localhost:5000",
    [string]$ReservasUrl = "http://localhost:5002"
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$raiz = Split-Path -Parent $PSScriptRoot
$logs = Join-Path $raiz "logs"
New-Item -ItemType Directory -Force $logs | Out-Null

function Invoke-Api {
    param(
        [string]$Metodo,
        [string]$Url,
        [string]$Token,
        $Cuerpo
    )

    $parametros = @{
        Uri             = $Url
        Method          = $Metodo
        TimeoutSec      = 30
        UseBasicParsing = $true
    }

    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $parametros["SkipHttpErrorCheck"] = $true
    }

    if ($Token) {
        $parametros["Headers"] = @{ Authorization = "Bearer $Token" }
    }

    if ($null -ne $Cuerpo) {
        $parametros["ContentType"] = "application/json"
        $parametros["Body"] = ($Cuerpo | ConvertTo-Json -Depth 6 -Compress)
    }

    try {
        $respuesta = Invoke-WebRequest @parametros
        return [pscustomobject]@{
            Codigo = [int]$respuesta.StatusCode
            Cuerpo = [string]$respuesta.Content
        }
    }
    catch {
        $respuesta = $_.Exception.Response
        if ($null -eq $respuesta) { throw }

        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $texto = $respuesta.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            return [pscustomobject]@{ Codigo = [int]$respuesta.StatusCode; Cuerpo = $texto }
        }

        $lector = New-Object System.IO.StreamReader($respuesta.GetResponseStream())
        $texto = $lector.ReadToEnd()
        $lector.Dispose()
        return [pscustomobject]@{ Codigo = [int]$respuesta.StatusCode; Cuerpo = $texto }
    }
}

$resultados = New-Object System.Collections.Generic.List[object]

function Probar {
    param(
        [string]$Caso,
        [string]$Metodo,
        [string]$Ruta,
        [string]$Token,
        $Cuerpo,
        [int]$Esperado,
        [string]$UrlBase = $BaseUrl
    )

    $respuesta = Invoke-Api -Metodo $Metodo -Url "$UrlBase$Ruta" -Token $Token -Cuerpo $Cuerpo
    $estado = if ($respuesta.Codigo -eq $Esperado) { "OK" } else { "FALLO" }

    $resultados.Add([pscustomobject]@{
        Caso     = $Caso
        Metodo   = $Metodo
        Ruta     = $Ruta
        Esperado = $Esperado
        Obtenido = $respuesta.Codigo
        Estado   = $estado
    })

    Write-Host ("{0,-52} {1,-6} {2,-42} esperado={3} obtenido={4} {5}" -f `
        $Caso, $Metodo, $Ruta, $Esperado, $respuesta.Codigo, $estado)

    return $respuesta
}

Write-Host "=== 1. Tokens (login por el gateway) ===" -ForegroundColor Cyan

$loginChef = Probar "Login Chef por el gateway" "POST" "/gateway/auth/login" $null @{
    correo = "chef@restaurante.com"
    clave  = "Chef123!"
} 200

$loginMesero = Probar "Login Mesero por el gateway" "POST" "/gateway/auth/login" $null @{
    correo = "mesero@restaurante.com"
    clave  = "Mesero123!"
} 200

if ($loginChef.Codigo -ne 200 -or $loginMesero.Codigo -ne 200) {
    throw "No se pudieron obtener los tokens. Revise que la API S14 y SQL Server estén en ejecución."
}

$tokenChef = ($loginChef.Cuerpo | ConvertFrom-Json).token
$tokenMesero = ($loginMesero.Cuerpo | ConvertFrom-Json).token

Write-Host ""
Write-Host "=== 2. Rutas públicas (200) ===" -ForegroundColor Cyan

Probar "Listar platos sin token" "GET" "/gateway/platos" $null $null 200 | Out-Null
Probar "Obtener plato 1 sin token" "GET" "/gateway/platos/1" $null $null 200 | Out-Null
Probar "Listar categorías sin token" "GET" "/gateway/categorias" $null $null 200 | Out-Null
Probar "Platos de la categoría 1 sin token" "GET" "/gateway/categorias/1/platos" $null $null 200 | Out-Null

Write-Host ""
Write-Host "=== 3. Rutas protegidas con token (200) ===" -ForegroundColor Cyan

Probar "Perfil con token Chef" "GET" "/gateway/auth/perfil" $tokenChef $null 200 | Out-Null
Probar "Listar reservas con token Chef" "GET" "/gateway/reservas" $tokenChef $null 200 | Out-Null
Probar "Obtener reserva 1 con token Mesero" "GET" "/gateway/reservas/1" $tokenMesero $null 200 | Out-Null
Probar "Filtrar reservas por estado" "GET" "/gateway/reservas?estado=Confirmada" $tokenChef $null 200 | Out-Null

Write-Host ""
Write-Host "=== 4. Escritura con rol Chef (201 y 204) ===" -ForegroundColor Cyan

$nombrePlato = "Plato Gateway $([DateTime]::Now.Ticks)"
$crearPlato = Probar "Crear plato con token Chef" "POST" "/gateway/platos" $tokenChef @{
    nombre      = $nombrePlato
    descripcion = "Creado a través del API Gateway"
    precio      = 31.90
    disponible  = $true
    categoriaId = 1
} 201

$platoId = ($crearPlato.Cuerpo | ConvertFrom-Json).platoId
Write-Host "Plato creado con id $platoId" -ForegroundColor DarkGray

Probar "Actualizar plato con token Chef" "PUT" "/gateway/platos/$platoId" $tokenChef @{
    nombre      = "$nombrePlato actualizado"
    descripcion = "Actualizado a través del API Gateway"
    precio      = 33.50
    disponible  = $true
    categoriaId = 1
} 204 | Out-Null

Write-Host ""
Write-Host "=== 5. Sin token (401) ===" -ForegroundColor Cyan

Probar "Perfil sin token" "GET" "/gateway/auth/perfil" $null $null 401 | Out-Null
Probar "Crear plato sin token" "POST" "/gateway/platos" $null @{
    nombre      = "Sin token"
    precio      = 10.00
    disponible  = $true
    categoriaId = 1
} 401 | Out-Null
Probar "Listar reservas sin token" "GET" "/gateway/reservas" $null $null 401 | Out-Null
Probar "Token malformado" "GET" "/gateway/reservas" "token.invalido.jwt" $null 401 | Out-Null

Write-Host ""
Write-Host "=== 6. Token válido sin rol Chef (403) ===" -ForegroundColor Cyan

Probar "Crear plato con token Mesero" "POST" "/gateway/platos" $tokenMesero @{
    nombre      = "Plato Mesero"
    precio      = 10.00
    disponible  = $true
    categoriaId = 1
} 403 | Out-Null

Probar "Eliminar plato con token Mesero" "DELETE" "/gateway/platos/$platoId" $tokenMesero $null 403 | Out-Null

Write-Host ""
Write-Host "=== 7. Recursos inexistentes (404) ===" -ForegroundColor Cyan

Probar "Plato inexistente" "GET" "/gateway/platos/999999" $null $null 404 | Out-Null
Probar "Reserva inexistente" "GET" "/gateway/reservas/999999" $tokenChef $null 404 | Out-Null
Probar "Ruta no configurada en el gateway" "GET" "/gateway/no-existe" $null $null 404 | Out-Null

Write-Host ""
Write-Host "=== 8. Limpieza con rol Chef (204) ===" -ForegroundColor Cyan

Probar "Eliminar plato con token Chef" "DELETE" "/gateway/platos/$platoId" $tokenChef $null 204 | Out-Null

Write-Host ""
Write-Host "=== 9. Llamada directa al microservicio 2 (sin gateway) ===" -ForegroundColor Cyan

Probar "Reservas directo sin token" "GET" "/api/reservas" $null $null 401 -UrlBase $ReservasUrl | Out-Null
Probar "Reservas directo con token" "GET" "/api/reservas/1" $tokenChef $null 200 -UrlBase $ReservasUrl | Out-Null

Write-Host ""
Write-Host "=== 10. 502 Bad Gateway ===" -ForegroundColor Cyan
Write-Host "Para el 502 detenga Reservas.Api y ejecute: scripts/probar-502.ps1" -ForegroundColor Yellow

$fallos = @($resultados | Where-Object { $_.Estado -ne "OK" }).Count

$lineas = @(
    "# Pruebas ejecutadas por el API Gateway",
    "",
    "Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "Gateway: $BaseUrl",
    "",
    "| Caso | Método | Ruta | Esperado | Obtenido | Estado |",
    "| :--- | :--- | :--- | :--- | :--- | :--- |"
)
foreach ($r in $resultados) {
    $lineas += "| $($r.Caso) | $($r.Metodo) | ``$($r.Ruta)`` | $($r.Esperado) | $($r.Obtenido) | $($r.Estado) |"
}
$lineas += ""
$lineas += "Total: $($resultados.Count) pruebas. Fallos: $fallos."

$archivo = Join-Path $logs "pruebas-gateway.md"
$lineas | Set-Content $archivo -Encoding UTF8

Write-Host ""
Write-Host "Total: $($resultados.Count) pruebas. Fallos: $fallos." -ForegroundColor $(if ($fallos -eq 0) { "Green" } else { "Red" })
Write-Host "Resultados guardados en $archivo"

if ($fallos -gt 0) { exit 1 }
