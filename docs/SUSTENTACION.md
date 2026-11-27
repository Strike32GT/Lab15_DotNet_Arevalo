# Sustentación — respuestas y guion del video

## 1. ¿Qué cambia para una aplicación cliente al usar el gateway en lugar de llamar directamente a cada servicio?

**Antes (sin gateway)** el cliente tendría que conocer una dirección por servicio
(`http://localhost:5001` y `http://localhost:5002`), repetir la configuración de CORS, TLS y
reintentos en cada uno, y cambiar su código cada vez que un servicio se mueva de host o de
puerto.

**Con el gateway**, el cliente conoce **una sola dirección** (`http://localhost:5000`), un solo
contrato de autenticación (`Authorization: Bearer <token>`) y un solo punto para TLS, CORS,
registro de solicitudes, límites de uso y versionado. El gateway oculta la topología: los
servicios pueden cambiar de host, puerto o cantidad de instancias sin tocar al cliente; solo se
edita `ocelot.json`. Además, el gateway rechaza un token inválido antes de reenviar la
solicitud.

**Costos del cambio:** hay un salto adicional de red (latencia), el gateway se vuelve un punto
único de falla que debe estar disponible, y hay que cuidar detalles como el encabezado
`Location`. En este laboratorio, Ocelot reescribe ese encabezado para que `POST /gateway/platos`
devuelva una URL del gateway y no exponga la dirección interna del servicio.

## 2. Elegir una ruta y explicar su upstream y su downstream

Ruta elegida:

| Upstream | Método | Downstream | Token |
| :--- | :--- | :--- | :--- |
| `/gateway/reservas{everything}` | GET | `http://localhost:5002/api/reservas{everything}` | Sí |

- **Upstream** es lo que el cliente ve y llama: el host y puerto del gateway (`localhost:5000`),
  el prefijo público `/gateway` y el recurso `reservas`.
- **Downstream** es lo que el gateway llama por dentro: el host y puerto reales del servicio
  (`localhost:5002`) y la ruta interna `/api/reservas`.

Entre uno y otro cambian **tres cosas**: el host/puerto (`5000` → `5002`), el prefijo
(`/gateway` → `/api`) y, en la nube, el esquema (`http` → `https`) y el puerto (`443`). La parte
variable de la ruta la transporta el comodín `{everything}`: sirve para `/gateway/reservas` y
también para `/gateway/reservas/1`; la cadena de consulta (`?estado=Confirmada`) la reenvía
Ocelot automáticamente.

**Por qué:** el prefijo `/gateway` es un espacio público propio del gateway, separado del
espacio `/api` de los servicios. Eso permite cambiar la ubicación o la versión de un servicio
sin cambiar la URL que usa el cliente. En la nube solo se edita el downstream (host público,
443, `https`) y el `BaseUrl` del gateway; el upstream sigue siendo la URL pública del gateway.

## 3. ¿Dónde se valida el token? ¿Por qué en el gateway y también en los servicios? ¿Qué desventaja trae repetirlo?

Se valida en **tres lugares**:

1. **En el gateway:** `AddAuthentication(...).AddJwtBearer(...)` registra el esquema `Bearer`
   con la misma clave, emisor y audiencia. Las rutas protegidas declaran
   `AuthenticationOptions.AuthenticationProviderKey = "Bearer"`; el middleware de Ocelot llama
   a `AuthenticateAsync("Bearer")` y responde **401** si el token falta, está vencido o la
   firma no coincide, **antes** de reenviar.
2. **En `Restaurante.Api`:** `AddJwtBearer` + `[Authorize]` en los controladores, y
   `[Authorize(Roles = "Chef")]` en la escritura. Aquí se exige el **rol**.
3. **En `Reservas.Api`:** `AddJwtBearer` con la misma configuración y `[Authorize]` a nivel de
   controlador, así que **todos** sus endpoints exigen token.

**Por qué se repite:**

- **Defensa en profundidad:** el servicio no debe confiar ciegamente en la red. Si alguien llama
  directamente al puerto 5002 (como se probó en el laboratorio), igual recibe **401** sin token.
- **El gateway no es el único cliente:** puede haber llamadas internas, pruebas, otro gateway o
  consumidores directos; cada servicio debe protegerse por sí mismo.
- **Autorización por servicio:** el gateway valida identidad, pero las reglas de negocio (por
  ejemplo, solo `Chef` escribe) viven en la API. El gateway no necesita conocer esos roles.
- **Contención:** un token inválido no llega a consumir recursos del servicio.

**Desventaja:** la configuración se duplica (la misma clave, emisor y audiencia en tres
aplicaciones), lo que puede desincronizarse: si roto la clave en un servicio y olvido otro, el
gateway acepta un token que el servicio rechaza. También se paga la validación criptográfica dos
veces por solicitud y una rotación de claves exige actualizar los tres despliegues. En un sistema
real se centraliza con un proveedor de identidad (Entra ID, Keycloak) que publica JWKS y rota las
claves, y se usa una sola audiencia/scopes para todos.

## 4. Al detener el microservicio 2, ¿qué respondió el gateway y qué siguió funcionando? ¿Qué desventaja de los microservicios notaste?

Al detener `Reservas.Api`, `GET /gateway/reservas` respondió **502 Bad Gateway**. El registro de
Ocelot muestra `ConnectionToDownstreamServiceError` porque no pudo conectarse a
`localhost:5002`. En cambio, **el microservicio 1 siguió funcionando**: `GET /gateway/platos`
respondió **200** y el login y las categorías también. Es decir, el fallo quedó aislado en las
rutas del servicio caído.

**Desventaja observada: complejidad.** Ahora hay tres procesos, tres configuraciones, tres
despliegues y tres lugares donde revisar registros. Un fallo parcial obliga al cliente a
interpretar un 502 y al equipo a monitorear cada servicio; hacen falta health checks,
reintentos, cortacircuitos (circuit breaker) y trazas centralizadas. La autenticación también se
repite. Sobre **transacciones**: en este laboratorio no hay problema porque cada servicio es
dueño de sus datos y no comparte base de datos, pero una operación de negocio que abarcara a los
dos servicios requeriría una saga o compensaciones; el gateway no resuelve transacciones
distribuidas. Además, el gateway es un punto único de falla si no se despliega con alta
disponibilidad.

---

## Guion sugerido para el video (mínimo 10 minutos)

1. **Presentación y arquitectura (2 min):** mostrar el diagrama, los tres puertos (5000, 5001,
   5002) y explicar qué hace cada servicio y por qué el cliente solo usa el 5000.
2. **`ocelot.json` (2 min):** mostrar `GlobalConfiguration.BaseUrl`, las rutas, el uso de
   `{everything}`, la diferencia upstream/downstream y dónde está `AuthenticationOptions`.
3. **JWT (2 min):** mostrar el login, el token (claims `sub`, `email`, `rol`), la configuración
   `Bearer` del gateway y el `AddJwtBearer` de los dos servicios. Explicar por qué se valida en
   los tres y la desventaja de duplicarlo.
4. **Demostración por el gateway (3 min):** 200 en `/gateway/platos`, 201 con Chef, 204 con
   Chef, 401 sin token, 403 con Mesero, 404 con un id inexistente, 502 deteniendo
   `Reservas.Api`, y la llamada directa a `http://localhost:5002/api/reservas` sin token (401).
5. **Cierre (1–2 min):** responder las preguntas 1 y 4, mostrar el repositorio y las
   conclusiones.

Recuerde: cámara encendida durante todo el video y verificar el enlace en una ventana privada.
