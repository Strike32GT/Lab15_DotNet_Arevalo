param(
    [string]$BaseUrl = "http://localhost:5000",
    [string]$ReservasUrl = "http://localhost:5002"
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$raiz = Split-Path -Parent $PSScriptRoot
$docs = Join-Path $raiz "docs"
New-Item -ItemType Directory -Force $docs | Out-Null

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

$loginChef = Invoke-Api "POST" "$BaseUrl/gateway/auth/login" $null @{
    correo = "chef@restaurante.com"; clave = "Chef123!"
}
$loginMesero = Invoke-Api "POST" "$BaseUrl/gateway/auth/login" $null @{
    correo = "mesero@restaurante.com"; clave = "Mesero123!"
}

$tokenChef = ($loginChef.Cuerpo | ConvertFrom-Json).token
$tokenMesero = ($loginMesero.Cuerpo | ConvertFrom-Json).token

$casos = New-Object System.Collections.Generic.List[object]

function Agregar-Caso {
    param([string]$Titulo, [string]$Metodo, [string]$Url, [string]$Token, $Cuerpo, [int]$Esperado)

    $r = Invoke-Api -Metodo $Metodo -Url $Url -Token $Token -Cuerpo $Cuerpo
    $ok = if ($r.Codigo -eq $Esperado) { "OK" } else { "FALLO" }
    $texto = if ([string]::IsNullOrWhiteSpace($r.Cuerpo)) { "(sin cuerpo)" } else { $r.Cuerpo }

    $casos.Add([pscustomobject]@{
        Titulo = $Titulo; Metodo = $Metodo; Url = $Url; Esperado = $Esperado
        Codigo = $r.Codigo; Estado = $ok; Cuerpo = $texto
    })

    Write-Host ("{0,-42} {1,-6} esperado={2} obtenido={3} {4}" -f $Titulo, $Metodo, $Esperado, $r.Codigo, $ok)
    return $r
}

Write-Host "Capturando respuestas..." -ForegroundColor Cyan

Agregar-Caso "200 - Plato por id (público)" "GET" "$BaseUrl/gateway/platos/1" $null $null 200 | Out-Null
Agregar-Caso "200 - Reserva por id (token)" "GET" "$BaseUrl/gateway/reservas/1" $tokenChef $null 200 | Out-Null

$creado = Agregar-Caso "201 - Crear plato (Chef)" "POST" "$BaseUrl/gateway/platos" $tokenChef @{
    nombre = "Plato evidencia $([DateTime]::Now.Ticks)"
    descripcion = "Creado para la evidencia de respuestas"
    precio = 27.50
    disponible = $true
    categoriaId = 1
} 201

$id = ($creado.Cuerpo | ConvertFrom-Json).platoId

Agregar-Caso "204 - Actualizar plato (Chef)" "PUT" "$BaseUrl/gateway/platos/$id" $tokenChef @{
    nombre = "Plato evidencia actualizado"
    descripcion = "Actualizado para la evidencia"
    precio = 28.00
    disponible = $true
    categoriaId = 1
} 204 | Out-Null

Agregar-Caso "401 - Reservas sin token" "GET" "$BaseUrl/gateway/reservas" $null $null 401 | Out-Null
Agregar-Caso "403 - Crear plato con Mesero" "POST" "$BaseUrl/gateway/platos" $tokenMesero @{
    nombre = "Plato Mesero"
    precio = 10.00
    disponible = $true
    categoriaId = 1
} 403 | Out-Null
Agregar-Caso "404 - Plato inexistente" "GET" "$BaseUrl/gateway/platos/999999" $null $null 404 | Out-Null
Agregar-Caso "404 - Ruta no configurada" "GET" "$BaseUrl/gateway/no-existe" $null $null 404 | Out-Null
Agregar-Caso "401 - Reservas directo sin token" "GET" "$ReservasUrl/api/reservas" $null $null 401 | Out-Null

Agregar-Caso "204 - Eliminar plato (Chef)" "DELETE" "$BaseUrl/gateway/platos/$id" $tokenChef $null 204 | Out-Null

$lineas = @(
    "# Evidencia de respuestas por el gateway",
    "",
    "Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "Gateway: $BaseUrl",
    ""
)
foreach ($c in $casos) {
    $lineas += "## $($c.Titulo)"
    $lineas += ""
    $lineas += "``$($c.Metodo) $($c.Url)`` -> **$($c.Codigo)** (esperado $($c.Esperado)) - $($c.Estado)"
    $lineas += ""
    $lineas += '```json'
    $lineas += $c.Cuerpo
    $lineas += '```'
    $lineas += ""
}

$archivo = Join-Path $docs "EVIDENCIA-RESPUESTAS.md"
$lineas | Set-Content $archivo -Encoding UTF8
Write-Host "Evidencia guardada en $archivo"
