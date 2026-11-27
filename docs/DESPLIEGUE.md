# Preparación técnica para el despliegue

Este archivo describe únicamente la configuración del programa para la nube. El análisis de
proveedores y las respuestas de sustentación se dejan para el documento final.

El despliegue lo realiza el estudiante; en local todo funciona sin cambios de código.

## 1. Cambios entre local y nube en `ocelot.json`

| Concepto | Local | Nube |
| :--- | :--- | :--- |
| `GlobalConfiguration.BaseUrl` | `http://localhost:5000` | `https://lab15-gateway-earevalo.runasp.net` |
| `DownstreamScheme` | `http` | `https` |
| `DownstreamHostAndPorts[0].Host` | `localhost` | Host público del servicio (sin esquema ni puerto) |
| `DownstreamHostAndPorts[0].Port` | `5001` / `5002` | `443` |
| `DownstreamHeaderTransform.Location` | `http://localhost:5001/api, http://localhost:5000/gateway` | `https://lab15-restaurante-earevalo.runasp.net/api, https://lab15-gateway-earevalo.runasp.net/gateway` |

Plantilla completa: [`ocelot.cloud.example.json`](ocelot.cloud.example.json). Ya contiene los
hosts creados en MonsterASP y coincide con `GatewayApi/ocelot.json`. El prefijo
`/gateway`, el comodín `{everything}` y los requisitos de token **no cambian**.

## 2. Configuración de secretos

Los archivos `appsettings.Development.json` no se suben al repositorio (`.gitignore`) ni se
incluyen en la publicación (`CopyToPublishDirectory="Never"` en los tres `.csproj`). En la nube
use variables de entorno o los secretos del proveedor:

| Servicio | Variable | Valor |
| :--- | :--- | :--- |
| `GatewayApi` | `Jwt__Clave` | La **misma** clave JWT de los tres servicios (mínimo 32 caracteres) |
| `GatewayApi` | `Jwt__Emisor` | `RestauranteApi` |
| `GatewayApi` | `Jwt__Audiencia` | `RestauranteClientes` |
| `Restaurante.Api` | `Jwt__Clave`, `Jwt__Emisor`, `Jwt__Audiencia` | Igual que el gateway |
| `Restaurante.Api` | `ConnectionStrings__RestauranteDB` | Cadena de conexión de la base de datos en la nube |
| `Reservas.Api` | `Jwt__Clave`, `Jwt__Emisor`, `Jwt__Audiencia` | Igual que el gateway |

`Reservas.Api` no necesita cadena de conexión: usa datos en memoria.

En MonsterASP se crea una base MSSQL administrada y se ejecutan, en ella, `database/01_restaurante.monsterasp.sql`
y después `database/02_usuarios.monsterasp.sql`. Las versiones locales conservan `CREATE DATABASE`
para SQL Server propio. La segunda carga los usuarios `chef@restaurante.com`
(rol `Chef`) y `mesero@restaurante.com` (rol `Mesero`) con claves cifradas con BCrypt.

## 3. Publicación

```powershell
dotnet publish GatewayApi -c Release -o .publish/GatewayApi
dotnet publish Reservas.Api -c Release -o .publish/Reservas.Api
dotnet publish Restaurante.Api -c Release -o .publish/Restaurante.Api
```

Verificación de lo que se publica:

- `ocelot.json` **sí** está en `.publish/GatewayApi`.
- `appsettings.Development.json` **no** está en ninguno de los tres directorios.
- `appsettings.json` contiene solo valores públicos (emisor y audiencia); `Clave` está vacía.

## 4. Ajustes de código ya preparados para la nube

- `Restaurante.Api` solo llama a `UseHttpsRedirection()` en `Development`. En la nube el
  proveedor termina TLS y reenvía HTTP al contenedor; forzar la redirección dentro de la API
  provocaría que el gateway reciba un `307` en vez de la respuesta real.
- Las rutas de escritura de `ocelot.json` reescriben `Location` para que apunte al gateway y
  no al servicio interno. En local se comprobó: `POST /gateway/platos` devuelve
  `Location: http://localhost:5000/gateway/Platos/{id}`.
- Los scripts de prueba aceptan las URLs publicadas:

  ```powershell
  pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/probar-gateway.ps1 `
      -BaseUrl "https://lab15-gateway-earevalo.runasp.net" `
      -ReservasUrl "https://lab15-reservas-earevalo.runasp.net"
  ```

## 5. Verificación mínima después de publicar

1. `GET https://lab15-gateway-earevalo.runasp.net/gateway/platos` → **200** (ruta pública).
2. `POST https://lab15-gateway-earevalo.runasp.net/gateway/auth/login` con `chef@restaurante.com` / `Chef123!` → **200** y token.
3. `GET https://lab15-gateway-earevalo.runasp.net/gateway/reservas` sin token → **401**.
4. `GET https://lab15-gateway-earevalo.runasp.net/gateway/reservas` con token → **200**.
5. Detener el microservicio 2 y repetir el paso 4 → **502**.
6. Llamada directa a `https://lab15-reservas-earevalo.runasp.net/api/reservas` sin token → **401**.

En planes gratuitos la primera solicitud después de un periodo de inactividad puede tardar
bastante segundos (arranque en frío); eso no es un error de la aplicación.
