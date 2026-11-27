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

$resultados = [System.Collections.Generic.List[object]]::new()

function Invoke-Api {
    param([string]$Metodo, [string]$Url, [string]$Token, $Cuerpo)

    $parametros = @{
        Uri             = $Url
        Method          = $Metodo
        TimeoutSec      = 30
        UseBasicParsing = $true
        SkipHttpErrorCheck = $true
    }
    if ($Token) { $parametros["Headers"] = @{ Authorization = "Bearer $Token" } }
    if ($null -ne $Cuerpo) {
        $parametros["ContentType"] = "application/json"
        $parametros["Body"] = ($Cuerpo | ConvertTo-Json -Depth 6 -Compress)
    }

    $r = Invoke-WebRequest @parametros
    $json = $null
    if ($r.Content) {
        try { $json = $r.Content | ConvertFrom-Json } catch { $json = $null }
    }

    return [pscustomobject]@{
        Codigo   = [int]$r.StatusCode
        Cuerpo   = [string]$r.Content
        Json     = $json
        Location = [string]($r.Headers["Location"] -join ",")
    }
}

function Afirmar {
    param([string]$Caso, [bool]$Condicion, [string]$Detalle = "")

    $estado = if ($Condicion) { "OK" } else { "FALLO" }
    $resultados.Add([pscustomobject]@{
        Caso    = $Caso
        Estado  = $estado
        Detalle = $Detalle
    })
    Write-Host ("{0,-66} {1,-6} {2}" -f $Caso, $estado, $Detalle)
}

function Codigo {
    param([string]$Caso, [int]$Esperado, [int]$Obtenido, [string]$Detalle = "")
    Afirmar $Caso ($Esperado -eq $Obtenido) "esperado=$Esperado obtenido=$Obtenido $Detalle"
}

function EsVerdad {
    param([string]$Caso, [bool]$Condicion, [string]$Detalle = "")
    Afirmar $Caso $Condicion $Detalle
}

$sufijo = [DateTime]::Now.Ticks
$correoPrueba = "verificacion.$sufijo@restaurante.com"
$clavePrueba = "Prueba123!"
$nombreCategoria = "Categoria Verificacion $sufijo"
$nombrePlato = "Plato Verificacion $sufijo"
$idCategoria = 0
$idPlato = 0

try {
    Write-Host "=== AUTENTICACIÓN ===" -ForegroundColor Cyan

    $loginChef = Invoke-Api "POST" "$BaseUrl/gateway/auth/login" $null @{
        correo = "chef@restaurante.com"; clave = "Chef123!"
    }
    Codigo "POST /gateway/auth/login (Chef)" 200 $loginChef.Codigo
    $tokenChef = if ($loginChef.Json) { [string]$loginChef.Json.token } else { "" }
    EsVerdad "Login Chef devuelve token y expiración" ($tokenChef.Length -gt 100 -and $null -ne $loginChef.Json.expira) "longitud=$($tokenChef.Length)"

    $loginMesero = Invoke-Api "POST" "$BaseUrl/gateway/auth/login" $null @{
        correo = "mesero@restaurante.com"; clave = "Mesero123!"
    }
    Codigo "POST /gateway/auth/login (Mesero)" 200 $loginMesero.Codigo
    $tokenMesero = if ($loginMesero.Json) { [string]$loginMesero.Json.token } else { "" }
    EsVerdad "Login Mesero devuelve token" ($tokenMesero.Length -gt 100)

    $loginMalo = Invoke-Api "POST" "$BaseUrl/gateway/auth/login" $null @{
        correo = "chef@restaurante.com"; clave = "ClaveIncorrecta123!"
    }
    Codigo "POST /gateway/auth/login (credenciales inválidas)" 401 $loginMalo.Codigo "cuerpo=$($loginMalo.Cuerpo)"

    $loginInvalido = Invoke-Api "POST" "$BaseUrl/gateway/auth/login" $null @{ correo = "chef@restaurante.com" }
    Codigo "POST /gateway/auth/login (body incompleto)" 400 $loginInvalido.Codigo

    $perfilChef = Invoke-Api "GET" "$BaseUrl/gateway/auth/perfil" $tokenChef
    Codigo "GET /gateway/auth/perfil (Chef)" 200 $perfilChef.Codigo
    EsVerdad "Perfil Chef = correo y rol correctos" ($perfilChef.Json.correo -eq "chef@restaurante.com" -and $perfilChef.Json.rol -eq "Chef") $perfilChef.Cuerpo

    $perfilMesero = Invoke-Api "GET" "$BaseUrl/gateway/auth/perfil" $tokenMesero
    Codigo "GET /gateway/auth/perfil (Mesero)" 200 $perfilMesero.Codigo
    EsVerdad "Perfil Mesero = rol Mesero" ($perfilMesero.Json.rol -eq "Mesero") $perfilMesero.Cuerpo

    $perfilSinToken = Invoke-Api "GET" "$BaseUrl/gateway/auth/perfil" $null
    Codigo "GET /gateway/auth/perfil (sin token)" 401 $perfilSinToken.Codigo

    $registro = Invoke-Api "POST" "$BaseUrl/gateway/auth/registro" $null @{
        correo = $correoPrueba; clave = $clavePrueba
    }
    Codigo "POST /gateway/auth/registro (nuevo)" 201 $registro.Codigo
    EsVerdad "Registro asigna rol Mesero y no devuelve clave" (
        $registro.Json.rol -eq "Mesero" -and $registro.Json.correo -eq $correoPrueba -and
        -not $registro.Cuerpo.Contains("claveHash")) $registro.Cuerpo

    $loginNuevo = Invoke-Api "POST" "$BaseUrl/gateway/auth/login" $null @{
        correo = $correoPrueba; clave = $clavePrueba
    }
    Codigo "POST /gateway/auth/login (usuario recién registrado)" 200 $loginNuevo.Codigo

    $registroDuplicado = Invoke-Api "POST" "$BaseUrl/gateway/auth/registro" $null @{
        correo = $correoPrueba; clave = $clavePrueba
    }
    Codigo "POST /gateway/auth/registro (correo duplicado)" 409 $registroDuplicado.Codigo

    $registroInvalido = Invoke-Api "POST" "$BaseUrl/gateway/auth/registro" $null @{
        correo = "no-es-un-correo"; clave = "abc"
    }
    Codigo "POST /gateway/auth/registro (datos inválidos)" 400 $registroInvalido.Codigo

    Write-Host ""
    Write-Host "=== CATEGORÍAS ===" -ForegroundColor Cyan

    $categorias = Invoke-Api "GET" "$BaseUrl/gateway/categorias" $null
    Codigo "GET /gateway/categorias" 200 $categorias.Codigo
    EsVerdad "Lista de categorías no vacía" (@($categorias.Json).Count -ge 7) "total=$(@($categorias.Json).Count)"

    $categoriasFiltradas = Invoke-Api "GET" "$BaseUrl/gateway/categorias?nombre=Entradas" $null
    Codigo "GET /gateway/categorias?nombre=Entradas" 200 $categoriasFiltradas.Codigo
    EsVerdad "Filtro por nombre aplicado" (@($categoriasFiltradas.Json).Count -ge 1 -and @($categoriasFiltradas.Json | Where-Object { $_.nombre -notlike "*Entradas*" }).Count -eq 0) "total=$(@($categoriasFiltradas.Json).Count)"

    $categoriasActivas = Invoke-Api "GET" "$BaseUrl/gateway/categorias?activo=true" $null
    Codigo "GET /gateway/categorias?activo=true" 200 $categoriasActivas.Codigo
    EsVerdad "Filtro por activo aplicado" (@($categoriasActivas.Json).Count -ge 1 -and @($categoriasActivas.Json | Where-Object { -not $_.activo }).Count -eq 0) "total=$(@($categoriasActivas.Json).Count)"

    $categoria1 = Invoke-Api "GET" "$BaseUrl/gateway/categorias/1" $null
    Codigo "GET /gateway/categorias/1" 200 $categoria1.Codigo
    EsVerdad "Categoría 1 tiene las propiedades esperadas" ($null -ne $categoria1.Json.categoriaId -and $null -ne $categoria1.Json.nombre) $categoria1.Cuerpo

    $categoriaInexistente = Invoke-Api "GET" "$BaseUrl/gateway/categorias/999999" $null
    Codigo "GET /gateway/categorias/999999" 404 $categoriaInexistente.Codigo

    $platosCategoria1 = Invoke-Api "GET" "$BaseUrl/gateway/categorias/1/platos" $null
    Codigo "GET /gateway/categorias/1/platos" 200 $platosCategoria1.Codigo
    EsVerdad "Ruta anidada devuelve solo platos de la categoría 1" (@($platosCategoria1.Json).Count -ge 1 -and @($platosCategoria1.Json | Where-Object { $_.categoriaId -ne 1 }).Count -eq 0) "total=$(@($platosCategoria1.Json).Count)"

    $platosCategoriaInexistente = Invoke-Api "GET" "$BaseUrl/gateway/categorias/999999/platos" $null
    Codigo "GET /gateway/categorias/999999/platos" 404 $platosCategoriaInexistente.Codigo

    $crearCategoria = Invoke-Api "POST" "$BaseUrl/gateway/categorias" $tokenChef @{
        nombre = $nombreCategoria; descripcion = "Categoría de verificación automática"
    }
    Codigo "POST /gateway/categorias (Chef)" 201 $crearCategoria.Codigo
    $idCategoria = if ($crearCategoria.Json) { [int]$crearCategoria.Json.categoriaId } else { 0 }
    EsVerdad "Categoría creada con id y Location del gateway" ($idCategoria -gt 0 -and $crearCategoria.Location -like "$BaseUrl/gateway/*") "id=$idCategoria Location=$($crearCategoria.Location)"

    $crearCategoriaDuplicada = Invoke-Api "POST" "$BaseUrl/gateway/categorias" $tokenChef @{
        nombre = $nombreCategoria; descripcion = "Duplicada"
    }
    Codigo "POST /gateway/categorias (nombre duplicado)" 409 $crearCategoriaDuplicada.Codigo

    $categoriaSinToken = Invoke-Api "POST" "$BaseUrl/gateway/categorias" $null @{
        nombre = "Categoria Sin Token $sufijo"
    }
    Codigo "POST /gateway/categorias (sin token)" 401 $categoriaSinToken.Codigo

    $categoriaMesero = Invoke-Api "POST" "$BaseUrl/gateway/categorias" $tokenMesero @{
        nombre = "Categoria Mesero $sufijo"
    }
    Codigo "POST /gateway/categorias (Mesero)" 403 $categoriaMesero.Codigo

    $categoriaTokenMalo = Invoke-Api "POST" "$BaseUrl/gateway/categorias" "token.invalido.jwt" @{
        nombre = "Categoria Token Malo $sufijo"
    }
    Codigo "POST /gateway/categorias (token malformado)" 401 $categoriaTokenMalo.Codigo

    if ($idCategoria -gt 0) {
        $actualizarCategoria = Invoke-Api "PUT" "$BaseUrl/gateway/categorias/$idCategoria" $tokenChef @{
            nombre = "$nombreCategoria actualizada"; descripcion = "Actualizada"; activo = $false
        }
        Codigo "PUT /gateway/categorias/{id} (Chef)" 204 $actualizarCategoria.Codigo

        $categoriaActualizada = Invoke-Api "GET" "$BaseUrl/gateway/categorias/$idCategoria" $null
        Codigo "GET categoría después de PUT" 200 $categoriaActualizada.Codigo
        EsVerdad "PUT se refleja en la consulta" ($categoriaActualizada.Json.nombre -eq "$nombreCategoria actualizada" -and -not $categoriaActualizada.Json.activo) $categoriaActualizada.Cuerpo
    }

    $putCategoriaInexistente = Invoke-Api "PUT" "$BaseUrl/gateway/categorias/999999" $tokenChef @{
        nombre = "Inexistente"; activo = $true
    }
    Codigo "PUT /gateway/categorias/999999" 404 $putCategoriaInexistente.Codigo

    Write-Host ""
    Write-Host "=== PLATOS ===" -ForegroundColor Cyan

    $platos = Invoke-Api "GET" "$BaseUrl/gateway/platos" $null
    Codigo "GET /gateway/platos" 200 $platos.Codigo
    EsVerdad "Lista de platos no vacía" (@($platos.Json).Count -ge 10) "total=$(@($platos.Json).Count)"

    $platosPorCategoria = Invoke-Api "GET" "$BaseUrl/gateway/platos?categoriaId=1" $null
    Codigo "GET /gateway/platos?categoriaId=1" 200 $platosPorCategoria.Codigo
    EsVerdad "Filtro categoríaId aplicado" (@($platosPorCategoria.Json).Count -ge 1 -and @($platosPorCategoria.Json | Where-Object { $_.categoriaId -ne 1 }).Count -eq 0) "total=$(@($platosPorCategoria.Json).Count)"

    $platosPorNombre = Invoke-Api "GET" "$BaseUrl/gateway/platos?nombre=Ceviche" $null
    Codigo "GET /gateway/platos?nombre=Ceviche" 200 $platosPorNombre.Codigo
    EsVerdad "Filtro nombre aplicado" (@($platosPorNombre.Json).Count -ge 1 -and @($platosPorNombre.Json | Where-Object { $_.nombre -notlike "*Ceviche*" }).Count -eq 0) "total=$(@($platosPorNombre.Json).Count)"

    $platosPorPrecio = Invoke-Api "GET" "$BaseUrl/gateway/platos?precioMin=1&precioMax=30&disponible=true" $null
    Codigo "GET /gateway/platos (precioMin, precioMax, disponible)" 200 $platosPorPrecio.Codigo
    EsVerdad "Filtros de precio y disponibilidad aplicados" (
        @($platosPorPrecio.Json).Count -ge 1 -and
        @($platosPorPrecio.Json | Where-Object { $_.precio -lt 1 -or $_.precio -gt 30 -or -not $_.disponible }).Count -eq 0) "total=$(@($platosPorPrecio.Json).Count)"

    $plato1 = Invoke-Api "GET" "$BaseUrl/gateway/platos/1" $null
    Codigo "GET /gateway/platos/1" 200 $plato1.Codigo
    EsVerdad "Plato 1 tiene las propiedades esperadas" ($null -ne $plato1.Json.platoId -and $null -ne $plato1.Json.nombre -and $null -ne $plato1.Json.precio) $plato1.Cuerpo

    $platoInexistente = Invoke-Api "GET" "$BaseUrl/gateway/platos/999999" $null
    Codigo "GET /gateway/platos/999999" 404 $platoInexistente.Codigo

    $crearPlato = Invoke-Api "POST" "$BaseUrl/gateway/platos" $tokenChef @{
        nombre = $nombrePlato; descripcion = "Plato de verificación automática"
        precio = 25.50; disponible = $true; categoriaId = 1
    }
    Codigo "POST /gateway/platos (Chef)" 201 $crearPlato.Codigo
    $idPlato = if ($crearPlato.Json) { [int]$crearPlato.Json.platoId } else { 0 }
    EsVerdad "Plato creado con id y Location del gateway" ($idPlato -gt 0 -and $crearPlato.Location -like "$BaseUrl/gateway/*") "id=$idPlato Location=$($crearPlato.Location)"

    $platoInvalido = Invoke-Api "POST" "$BaseUrl/gateway/platos" $tokenChef @{
        nombre = $nombrePlato; precio = 0; disponible = $true; categoriaId = 1
    }
    Codigo "POST /gateway/platos (precio fuera de rango)" 400 $platoInvalido.Codigo

    $platoCategoriaInvalida = Invoke-Api "POST" "$BaseUrl/gateway/platos" $tokenChef @{
        nombre = "$nombrePlato categoria"; precio = 10; disponible = $true; categoriaId = 999999
    }
    Codigo "POST /gateway/platos (categoría inexistente)" 409 $platoCategoriaInvalida.Codigo

    $platoSinToken = Invoke-Api "POST" "$BaseUrl/gateway/platos" $null @{
        nombre = "Sin token"; precio = 10; disponible = $true; categoriaId = 1
    }
    Codigo "POST /gateway/platos (sin token)" 401 $platoSinToken.Codigo

    $platoMesero = Invoke-Api "POST" "$BaseUrl/gateway/platos" $tokenMesero @{
        nombre = "Mesero"; precio = 10; disponible = $true; categoriaId = 1
    }
    Codigo "POST /gateway/platos (Mesero)" 403 $platoMesero.Codigo

    if ($idPlato -gt 0) {
        $actualizarPlato = Invoke-Api "PUT" "$BaseUrl/gateway/platos/$idPlato" $tokenChef @{
            nombre = "$nombrePlato actualizado"; descripcion = "Actualizado"
            precio = 42.75; disponible = $false; categoriaId = 1
        }
        Codigo "PUT /gateway/platos/{id} (Chef)" 204 $actualizarPlato.Codigo

        $platoActualizado = Invoke-Api "GET" "$BaseUrl/gateway/platos/$idPlato" $null
        Codigo "GET plato después de PUT" 200 $platoActualizado.Codigo
        EsVerdad "PUT se refleja en la consulta" (
            $platoActualizado.Json.nombre -eq "$nombrePlato actualizado" -and
            $platoActualizado.Json.precio -eq 42.75 -and -not $platoActualizado.Json.disponible) $platoActualizado.Cuerpo

        $putPlatoInexistente = Invoke-Api "PUT" "$BaseUrl/gateway/platos/999999" $tokenChef @{
            nombre = "Inexistente"; precio = 10; disponible = $true; categoriaId = 1
        }
        Codigo "PUT /gateway/platos/999999" 404 $putPlatoInexistente.Codigo

        $deletePlatoMesero = Invoke-Api "DELETE" "$BaseUrl/gateway/platos/$idPlato" $tokenMesero
        Codigo "DELETE /gateway/platos/{id} (Mesero)" 403 $deletePlatoMesero.Codigo

        $deletePlatoSinToken = Invoke-Api "DELETE" "$BaseUrl/gateway/platos/$idPlato" $null
        Codigo "DELETE /gateway/platos/{id} (sin token)" 401 $deletePlatoSinToken.Codigo

        $eliminarPlato = Invoke-Api "DELETE" "$BaseUrl/gateway/platos/$idPlato" $tokenChef
        Codigo "DELETE /gateway/platos/{id} (Chef)" 204 $eliminarPlato.Codigo

        $platoEliminado = Invoke-Api "GET" "$BaseUrl/gateway/platos/$idPlato" $null
        Codigo "GET plato eliminado" 404 $platoEliminado.Codigo
        $idPlato = 0
    }

    $deletePlatoInexistente = Invoke-Api "DELETE" "$BaseUrl/gateway/platos/999999" $tokenChef
    Codigo "DELETE /gateway/platos/999999" 404 $deletePlatoInexistente.Codigo

    Write-Host ""
    Write-Host "=== RESERVAS (MICROSERVICIO 2) ===" -ForegroundColor Cyan

    $reservas = Invoke-Api "GET" "$BaseUrl/gateway/reservas" $tokenChef
    Codigo "GET /gateway/reservas (Chef)" 200 $reservas.Codigo
    EsVerdad "Lista de reservas no vacía" (@($reservas.Json).Count -ge 2) "total=$(@($reservas.Json).Count)"

    $reservasMesero = Invoke-Api "GET" "$BaseUrl/gateway/reservas" $tokenMesero
    Codigo "GET /gateway/reservas (Mesero)" 200 $reservasMesero.Codigo

    $reservasConfirmadas = Invoke-Api "GET" "$BaseUrl/gateway/reservas?estado=Confirmada" $tokenChef
    Codigo "GET /gateway/reservas?estado=Confirmada" 200 $reservasConfirmadas.Codigo
    EsVerdad "Filtro estado aplicado" (@($reservasConfirmadas.Json).Count -ge 1 -and @($reservasConfirmadas.Json | Where-Object { $_.estado -ne "Confirmada" }).Count -eq 0) "total=$(@($reservasConfirmadas.Json).Count)"

    $reservasFecha = Invoke-Api "GET" "$BaseUrl/gateway/reservas?fecha=2026-11-25" $tokenChef
    Codigo "GET /gateway/reservas?fecha=2026-11-25" 200 $reservasFecha.Codigo
    EsVerdad "Filtro fecha aplicado" (@($reservasFecha.Json).Count -ge 1 -and @($reservasFecha.Json | Where-Object { $_.fecha -ne "2026-11-25" }).Count -eq 0) "total=$(@($reservasFecha.Json).Count)"

    $reserva1 = Invoke-Api "GET" "$BaseUrl/gateway/reservas/1" $tokenChef
    Codigo "GET /gateway/reservas/1" 200 $reserva1.Codigo
    EsVerdad "Reserva 1 tiene las propiedades esperadas" ($reserva1.Json.id -eq 1 -and $null -ne $reserva1.Json.cliente -and $null -ne $reserva1.Json.mesa) $reserva1.Cuerpo

    $reservaInexistente = Invoke-Api "GET" "$BaseUrl/gateway/reservas/999999" $tokenChef
    Codigo "GET /gateway/reservas/999999" 404 $reservaInexistente.Codigo

    $reservaSinToken = Invoke-Api "GET" "$BaseUrl/gateway/reservas" $null
    Codigo "GET /gateway/reservas (sin token)" 401 $reservaSinToken.Codigo

    $reservaTokenMalo = Invoke-Api "GET" "$BaseUrl/gateway/reservas" "token.invalido.jwt"
    Codigo "GET /gateway/reservas (token malformado)" 401 $reservaTokenMalo.Codigo

    $directoSinToken = Invoke-Api "GET" "$ReservasUrl/api/reservas" $null
    Codigo "GET directo $ReservasUrl/api/reservas (sin token)" 401 $directoSinToken.Codigo

    $directoConToken = Invoke-Api "GET" "$ReservasUrl/api/reservas/1" $tokenChef
    Codigo "GET directo $ReservasUrl/api/reservas/1 (con token)" 200 $directoConToken.Codigo

    $rutaInexistente = Invoke-Api "GET" "$BaseUrl/gateway/no-existe" $null
    Codigo "GET /gateway/no-existe (ruta no configurada)" 404 $rutaInexistente.Codigo

    Write-Host ""
    Write-Host "=== 502 BAD GATEWAY ===" -ForegroundColor Cyan

    $conexion = Get-NetTCPConnection -LocalPort 5002 -State Listen -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -eq $conexion) { throw "Reservas.Api no está escuchando en el puerto 5002." }

    $pidReservas = $conexion.OwningProcess
    Stop-Process -Id $pidReservas -Force
    Start-Sleep -Seconds 2

    $resp502 = Invoke-Api "GET" "$BaseUrl/gateway/reservas" $tokenChef
    Codigo "GET /gateway/reservas con microservicio 2 detenido" 502 $resp502.Codigo "PID detenido=$pidReservas"

    $platosVivos = Invoke-Api "GET" "$BaseUrl/gateway/platos" $null
    Codigo "GET /gateway/platos mientras el servicio 2 está caído" 200 $platosVivos.Codigo

    $dll = Join-Path $raiz "Reservas.Api\bin\Debug\net10.0\Reservas.Api.dll"
    $logOut = Join-Path $raiz "logs\Reservas.Api.out.log"
    $logErr = Join-Path $raiz "logs\Reservas.Api.err.log"
    $parametros = @{
        FilePath               = "dotnet"
        ArgumentList           = @($dll, "--urls", "http://localhost:5002")
        WorkingDirectory       = Join-Path $raiz "Reservas.Api"
        RedirectStandardOutput = $logOut
        RedirectStandardError  = $logErr
        PassThru               = $true
        WindowStyle            = "Hidden"
        Environment            = @{ ASPNETCORE_ENVIRONMENT = "Development" }
    }
    $proceso = Start-Process @parametros

    $fin = (Get-Date).AddSeconds(45)
    $reiniciado = $false
    while ((Get-Date) -lt $fin -and -not $reiniciado) {
        $prueba = New-Object System.Net.Sockets.TcpClient
        try {
            $tarea = $prueba.ConnectAsync("127.0.0.1", 5002)
            if ($tarea.Wait(500) -and $prueba.Connected) { $reiniciado = $true }
        }
        catch { }
        finally { $prueba.Dispose() }
        if (-not $reiniciado) { Start-Sleep -Milliseconds 400 }
    }
    Afirmar "Reservas.Api reiniciado después del 502" $reiniciado "PID=$($proceso.Id)"

    $archivoPids = Join-Path $raiz "logs\pids.json"
    if (Test-Path $archivoPids) {
        $pids = Get-Content $archivoPids -Raw | ConvertFrom-Json
        if ($pids -isnot [array]) { $pids = @($pids) }
        foreach ($p in $pids) {
            if ($p.Nombre -eq "Reservas.Api") { $p.Pid = $proceso.Id }
        }
        $pids | ConvertTo-Json | Set-Content $archivoPids -Encoding UTF8
    }

    $reservasTras502 = Invoke-Api "GET" "$BaseUrl/gateway/reservas" $tokenChef
    Codigo "GET /gateway/reservas después de reiniciar" 200 $reservasTras502.Codigo
}
finally {
    Write-Host ""
    Write-Host "=== LIMPIEZA ===" -ForegroundColor Cyan

    if ($idPlato -gt 0) {
        try {
            Invoke-Api "DELETE" "$BaseUrl/gateway/platos/$idPlato" $tokenChef | Out-Null
            Write-Host "Plato de prueba $idPlato eliminado." -ForegroundColor DarkGray
        } catch { Write-Host "No se pudo eliminar el plato $idPlato." -ForegroundColor Yellow }
    }

    if ($idCategoria -gt 0) {
        try {
            Invoke-Api "DELETE" "$BaseUrl/gateway/categorias/$idCategoria" $tokenChef | Out-Null
            Write-Host "Categoría de prueba $idCategoria eliminada." -ForegroundColor DarkGray
        } catch { Write-Host "No se pudo eliminar la categoría $idCategoria." -ForegroundColor Yellow }
    }

    try {
        sqlcmd -S ".\SQLEXPRESO" -E -d RestauranteDB -Q "DELETE FROM dbo.Usuarios WHERE Correo = '$correoPrueba'" 2>&1 | Out-Null
        Write-Host "Usuario de prueba $correoPrueba eliminado." -ForegroundColor DarkGray
    } catch { Write-Host "No se pudo eliminar el usuario de prueba." -ForegroundColor Yellow }
}

$fallos = @($resultados | Where-Object { $_.Estado -ne "OK" }).Count
$total = $resultados.Count

$lineas = @(
    "# Verificación exhaustiva de endpoints",
    "",
    "Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "Gateway: $BaseUrl",
    "Microservicio 2: $ReservasUrl",
    "",
    "| Caso | Estado | Detalle |",
    "| :--- | :--- | :--- |"
)
foreach ($r in $resultados) {
    $detalle = $r.Detalle -replace "\|", "\|" -replace "`r?`n", " "
    $lineas += "| $($r.Caso) | $($r.Estado) | $detalle |"
}
$lineas += ""
$lineas += "**Total: $total comprobaciones. Fallos: $fallos.**"

$archivo = Join-Path $docs "VERIFICACION-ENDPOINTS.md"
$lineas | Set-Content $archivo -Encoding UTF8

Write-Host ""
Write-Host "Total: $total comprobaciones. Fallos: $fallos." -ForegroundColor $(if ($fallos -eq 0) { "Green" } else { "Red" })
Write-Host "Informe: $archivo"

if ($fallos -gt 0) { exit 1 }
