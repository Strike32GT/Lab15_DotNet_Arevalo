param(
    [string]$BaseUrl = "http://localhost:5080"
)

$ErrorActionPreference = "Stop"

function Invoke-Api {
    param(
        [string]$Metodo,
        [string]$Ruta,
        [string]$Token,
        $Cuerpo
    )

    $parametros = @{
        Uri             = "$BaseUrl$Ruta"
        Method          = $Metodo
        UseBasicParsing = $true
        TimeoutSec      = 20
    }

    if ($Token) {
        $parametros["Headers"] = @{ Authorization = "Bearer $Token" }
    }

    if ($null -ne $Cuerpo) {
        $parametros["ContentType"] = "application/json"
        $parametros["Body"] = ($Cuerpo | ConvertTo-Json -Depth 5 -Compress)
    }

    try {
        $respuesta = Invoke-WebRequest @parametros
        return [pscustomobject]@{
            Codigo = [int]$respuesta.StatusCode
            Cuerpo = $respuesta.Content
        }
    }
    catch {
        $respuesta = $_.Exception.Response

        if ($null -eq $respuesta) {
            throw
        }

        $lector = New-Object System.IO.StreamReader($respuesta.GetResponseStream())
        $texto = $lector.ReadToEnd()
        $lector.Dispose()

        return [pscustomobject]@{
            Codigo = [int]$respuesta.StatusCode
            Cuerpo = $texto
        }
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
        [int]$Esperado
    )

    $respuesta = Invoke-Api -Metodo $Metodo -Ruta $Ruta -Token $Token -Cuerpo $Cuerpo
    $estado = if ($respuesta.Codigo -eq $Esperado) { "OK" } else { "FALLO" }

    $resultados.Add([pscustomobject]@{
        Caso     = $Caso
        Metodo   = $Metodo
        Ruta     = $Ruta
        Esperado = $Esperado
        Obtenido = $respuesta.Codigo
        Estado   = $estado
    })

    Write-Host ("{0,-48} {1,-6} {2,-44} esperado={3} obtenido={4} {5}" -f `
        $Caso, $Metodo, $Ruta, $Esperado, $respuesta.Codigo, $estado)

    return $respuesta
}

Write-Host "=== Inicio de sesión y tokens ==="

$loginChef = Probar "Login Chef" "POST" "/api/auth/login" $null @{
    correo = "chef@restaurante.com"
    clave  = "Chef123!"
} 200

$loginMesero = Probar "Login Mesero" "POST" "/api/auth/login" $null @{
    correo = "mesero@restaurante.com"
    clave  = "Mesero123!"
} 200

$tokenChef = ($loginChef.Cuerpo | ConvertFrom-Json).token
$tokenMesero = ($loginMesero.Cuerpo | ConvertFrom-Json).token

$partes = $tokenChef.Split(".")
$carga = $partes[1].Replace("-", "+").Replace("_", "/")
while ($carga.Length % 4 -ne 0) { $carga += "=" }
$claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($carga)) | ConvertFrom-Json

Write-Host ""
Write-Host "Claims del token Chef:"
$claims | ConvertTo-Json -Depth 5

Write-Host ""
Write-Host "=== Pruebas públicas y de autenticación ==="

Probar "Listar categorías sin token" "GET" "/api/categorias" $null $null 200 | Out-Null
Probar "Listar platos sin token" "GET" "/api/platos" $null $null 200 | Out-Null
Probar "Obtener plato sin token" "GET" "/api/platos/1" $null $null 200 | Out-Null
Probar "Perfil con token Chef" "GET" "/api/auth/perfil" $tokenChef $null 200 | Out-Null
Probar "Perfil con token Mesero" "GET" "/api/auth/perfil" $tokenMesero $null 200 | Out-Null
Probar "Perfil sin token" "GET" "/api/auth/perfil" $null $null 401 | Out-Null
Probar "Token malformado" "GET" "/api/auth/perfil" "token.invalido.jwt" $null 401 | Out-Null
Probar "Login con clave incorrecta" "POST" "/api/auth/login" $null @{
    correo = "mesero@restaurante.com"
    clave  = "ClaveIncorrecta123!"
} 401 | Out-Null
Probar "Login con correo inexistente" "POST" "/api/auth/login" $null @{
    correo = "noexiste@restaurante.com"
    clave  = "Cualquiera123!"
} 401 | Out-Null

Write-Host ""
Write-Host "=== Registro ==="

$correoNuevo = "nuevo.$([DateTime]::Now.Ticks)@restaurante.com"

$registro = Probar "Registrar usuario nuevo" "POST" "/api/auth/registro" $null @{
    correo = $correoNuevo
    clave  = "Nuevo123!"
    rol    = "Chef"
} 201
Write-Host "Respuesta registro: $($registro.Cuerpo)"

$rolRegistrado = ($registro.Cuerpo | ConvertFrom-Json).rol
if ($rolRegistrado -ne "Mesero") {
    throw "El servidor no asignó el rol Mesero; asignó '$rolRegistrado'."
}
Write-Host "El cliente envió rol Chef y el servidor asignó: $rolRegistrado"

Probar "Registrar correo duplicado" "POST" "/api/auth/registro" $null @{
    correo = $correoNuevo
    clave  = "Nuevo123!"
} 409 | Out-Null

Probar "Registrar con clave corta" "POST" "/api/auth/registro" $null @{
    correo = "clave.corta@restaurante.com"
    clave  = "123"
} 400 | Out-Null

Write-Host ""
Write-Host "=== Permisos de Chef y Mesero ==="

Probar "Crear categoría sin token" "POST" "/api/categorias" $null @{
    nombre      = "Sin token"
    descripcion = "Debe responder 401"
} 401 | Out-Null

Probar "Crear categoría con Mesero" "POST" "/api/categorias" $tokenMesero @{
    nombre      = "Categoría Mesero"
    descripcion = "Debe responder 403"
} 403 | Out-Null

$nombreCategoria = "Temporada JWT $([DateTime]::Now.Ticks)"
$crearCategoria = Probar "Crear categoría con Chef" "POST" "/api/categorias" $tokenChef @{
    nombre      = $nombreCategoria
    descripcion = "Categoría creada con rol Chef"
} 201

$categoriaId = ($crearCategoria.Cuerpo | ConvertFrom-Json).categoriaId

Probar "Crear categoría duplicada con Chef" "POST" "/api/categorias" $tokenChef @{
    nombre      = $nombreCategoria
    descripcion = "Categoría repetida"
} 409 | Out-Null

Probar "Actualizar categoría con Chef" "PUT" "/api/categorias/$categoriaId" $tokenChef @{
    nombre      = "$nombreCategoria actualizada"
    descripcion = "Actualizada con rol Chef"
    activo      = $true
} 204 | Out-Null

Probar "Eliminar categoría con Mesero" "DELETE" "/api/categorias/$categoriaId" $tokenMesero $null 403 | Out-Null
Probar "Eliminar categoría con Chef" "DELETE" "/api/categorias/$categoriaId" $tokenChef $null 204 | Out-Null
Probar "Consultar categoría eliminada" "GET" "/api/categorias/$categoriaId" $null $null 404 | Out-Null

Write-Host ""
Write-Host "=== Platos ==="

$nombrePlato = "Plato JWT $([DateTime]::Now.Ticks)"
$crearPlato = Probar "Crear plato con Chef" "POST" "/api/platos" $tokenChef @{
    nombre      = $nombrePlato
    descripcion = "Plato creado con rol Chef"
    precio      = 25.50
    disponible  = $true
    categoriaId = 1
} 201

$platoId = ($crearPlato.Cuerpo | ConvertFrom-Json).platoId

Probar "Crear plato con Mesero" "POST" "/api/platos" $tokenMesero @{
    nombre      = "Plato Mesero"
    precio      = 10.00
    disponible  = $true
    categoriaId = 1
} 403 | Out-Null

Probar "Crear plato con precio inválido" "POST" "/api/platos" $tokenChef @{
    nombre      = "Precio inválido"
    precio      = 0
    disponible  = $true
    categoriaId = 1
} 400 | Out-Null

Probar "Actualizar plato con Chef" "PUT" "/api/platos/$platoId" $tokenChef @{
    nombre      = "$nombrePlato actualizado"
    descripcion = "Plato actualizado con rol Chef"
    precio      = 27.00
    disponible  = $false
    categoriaId = 1
} 204 | Out-Null

Probar "Eliminar plato con Mesero" "DELETE" "/api/platos/$platoId" $tokenMesero $null 403 | Out-Null
Probar "Eliminar plato con Chef" "DELETE" "/api/platos/$platoId" $tokenChef $null 204 | Out-Null
Probar "Consultar plato eliminado" "GET" "/api/platos/$platoId" $null $null 404 | Out-Null

Write-Host ""
Write-Host "=== Swagger ==="

Probar "Contrato OpenAPI" "GET" "/swagger/v1/swagger.json" $null $null 200 | Out-Null
Probar "Swagger UI" "GET" "/swagger/index.html" $null $null 200 | Out-Null

Write-Host ""
$fallos = @($resultados | Where-Object { $_.Estado -ne "OK" }).Count
Write-Host "Total: $($resultados.Count) pruebas. Fallos: $fallos."
