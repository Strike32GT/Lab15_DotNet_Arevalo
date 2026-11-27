# Pruebas ejecutadas por el API Gateway

Todas las pruebas se hicieron contra `http://localhost:5000` (el gateway), salvo las dos
llamadas directas al microservicio 2 que se indican al final. Fecha: **2026-11-25**.

## Matriz de pruebas (24 casos)

| Caso | Método | Ruta | Esperado | Obtenido | Estado |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Login Chef por el gateway | POST | `/gateway/auth/login` | 200 | 200 | OK |
| Login Mesero por el gateway | POST | `/gateway/auth/login` | 200 | 200 | OK |
| Listar platos sin token | GET | `/gateway/platos` | 200 | 200 | OK |
| Obtener plato 1 sin token | GET | `/gateway/platos/1` | 200 | 200 | OK |
| Listar categorías sin token | GET | `/gateway/categorias` | 200 | 200 | OK |
| Platos de la categoría 1 sin token | GET | `/gateway/categorias/1/platos` | 200 | 200 | OK |
| Perfil con token Chef | GET | `/gateway/auth/perfil` | 200 | 200 | OK |
| Listar reservas con token Chef | GET | `/gateway/reservas` | 200 | 200 | OK |
| Obtener reserva 1 con token Mesero | GET | `/gateway/reservas/1` | 200 | 200 | OK |
| Filtrar reservas por estado | GET | `/gateway/reservas?estado=Confirmada` | 200 | 200 | OK |
| Crear plato con token Chef | POST | `/gateway/platos` | 201 | 201 | OK |
| Actualizar plato con token Chef | PUT | `/gateway/platos/13` | 204 | 204 | OK |
| Perfil sin token | GET | `/gateway/auth/perfil` | 401 | 401 | OK |
| Crear plato sin token | POST | `/gateway/platos` | 401 | 401 | OK |
| Listar reservas sin token | GET | `/gateway/reservas` | 401 | 401 | OK |
| Token malformado | GET | `/gateway/reservas` | 401 | 401 | OK |
| Crear plato con token Mesero | POST | `/gateway/platos` | 403 | 403 | OK |
| Eliminar plato con token Mesero | DELETE | `/gateway/platos/13` | 403 | 403 | OK |
| Plato inexistente | GET | `/gateway/platos/999999` | 404 | 404 | OK |
| Reserva inexistente | GET | `/gateway/reservas/999999` | 404 | 404 | OK |
| Ruta no configurada en el gateway | GET | `/gateway/no-existe` | 404 | 404 | OK |
| Eliminar plato con token Chef | DELETE | `/gateway/platos/13` | 204 | 204 | OK |
| Reservas directo sin token | GET | `http://localhost:5002/api/reservas` | 401 | 401 | OK |
| Reservas directo con token | GET | `http://localhost:5002/api/reservas/1` | 200 | 200 | OK |

**Total: 24 pruebas. Fallos: 0.**

## Prueba de 502 Bad Gateway

Para el 502 se detuvo `Reservas.Api` (puerto 5002) y se llamó a su ruta a través del gateway:

| Caso | Método | Ruta | Esperado | Obtenido | Estado |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Reservas con el microservicio 2 detenido | GET | `/gateway/reservas` | 502 | 502 | OK |
| El microservicio 1 sigue funcionando | GET | `/gateway/platos` | 200 | 200 | OK |

El registro de Ocelot confirma la causa:

```
warn: Ocelot.Responder.Middleware.ResponderMiddleware[0]
      ResponderMiddleware found 1 error ->
      ConnectionToDownstreamServiceError: Error connecting to downstream service,
      exception: System.Net.Http.HttpRequestException: No se puede establecer una conexión
      ya que el equipo de destino denegó expresamente dicha conexión. (localhost:5002)
```

Después de la prueba, `Reservas.Api` se reinició y volvió a responder 200.

## Evidencia de respuestas

Salida completa con cuerpos JSON: [`EVIDENCIA-RESPUESTAS.md`](EVIDENCIA-RESPUESTAS.md).
Resumen:

| Código | Solicitud | Respuesta |
| :--- | :--- | :--- |
| 200 | `GET /gateway/platos/1` | `{"platoId":1,"nombre":"Ceviche clásico",...}` |
| 200 | `GET /gateway/reservas/1` + token | `{"id":1,"cliente":"Lucía Ramírez",...}` |
| 201 | `POST /gateway/platos` + token Chef | `{"platoId":16,"nombre":"Plato evidencia ...",...}` |
| 204 | `PUT /gateway/platos/16` + token Chef | Sin cuerpo |
| 204 | `DELETE /gateway/platos/16` + token Chef | Sin cuerpo |
| 401 | `GET /gateway/reservas` sin token | Sin cuerpo |
| 403 | `POST /gateway/platos` + token Mesero | Sin cuerpo (token válido, rol insuficiente) |
| 404 | `GET /gateway/platos/999999` | `{"mensaje":"No existe el plato con id 999999."}` |
| 404 | `GET /gateway/no-existe` | Sin cuerpo (ruta no configurada) |
| 502 | `GET /gateway/reservas` con el servicio 2 detenido | Sin cuerpo |

## Cómo reproducirlas

```powershell
# 1) Iniciar los tres servicios
powershell -ExecutionPolicy Bypass -File scripts/iniciar-servicios.ps1

# 2) Matriz completa por el gateway
powershell -ExecutionPolicy Bypass -File scripts/probar-gateway.ps1

# 3) Detener Reservas.Api, comprobar el 502 y reiniciarlo
powershell -ExecutionPolicy Bypass -File scripts/probar-502.ps1

# 4) Guardar las respuestas completas
powershell -ExecutionPolicy Bypass -File scripts/capturar-respuestas.ps1
```

En la nube, los mismos scripts aceptan la URL publicada:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/probar-gateway.ps1 `
  -BaseUrl "https://lab15-gateway-earevalo.runasp.net" `
  -ReservasUrl "https://lab15-reservas-earevalo.runasp.net"
```
