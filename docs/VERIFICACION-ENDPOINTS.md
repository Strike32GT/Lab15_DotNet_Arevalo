# Verificación exhaustiva de endpoints

Fecha: 2026-11-25 19:51:23
Gateway: http://localhost:5000
Microservicio 2: http://localhost:5002

| Caso | Estado | Detalle |
| :--- | :--- | :--- |
| POST /gateway/auth/login (Chef) | OK | esperado=200 obtenido=200  |
| Login Chef devuelve token y expiración | OK | longitud=268 |
| POST /gateway/auth/login (Mesero) | OK | esperado=200 obtenido=200  |
| Login Mesero devuelve token | OK |  |
| POST /gateway/auth/login (credenciales inválidas) | OK | esperado=401 obtenido=401 cuerpo={"mensaje":"Credenciales inválidas."} |
| POST /gateway/auth/login (body incompleto) | OK | esperado=400 obtenido=400  |
| GET /gateway/auth/perfil (Chef) | OK | esperado=200 obtenido=200  |
| Perfil Chef = correo y rol correctos | OK | {"correo":"chef@restaurante.com","rol":"Chef"} |
| GET /gateway/auth/perfil (Mesero) | OK | esperado=200 obtenido=200  |
| Perfil Mesero = rol Mesero | OK | {"correo":"mesero@restaurante.com","rol":"Mesero"} |
| GET /gateway/auth/perfil (sin token) | OK | esperado=401 obtenido=401  |
| POST /gateway/auth/registro (nuevo) | OK | esperado=201 obtenido=201  |
| Registro asigna rol Mesero y no devuelve clave | OK | {"usuarioId":6,"correo":"verificacion.639312330734707008@restaurante.com","rol":"Mesero"} |
| POST /gateway/auth/login (usuario recién registrado) | OK | esperado=200 obtenido=200  |
| POST /gateway/auth/registro (correo duplicado) | OK | esperado=409 obtenido=409  |
| POST /gateway/auth/registro (datos inválidos) | OK | esperado=400 obtenido=400  |
| GET /gateway/categorias | OK | esperado=200 obtenido=200  |
| Lista de categorías no vacía | OK | total=7 |
| GET /gateway/categorias?nombre=Entradas | OK | esperado=200 obtenido=200  |
| Filtro por nombre aplicado | OK | total=1 |
| GET /gateway/categorias?activo=true | OK | esperado=200 obtenido=200  |
| Filtro por activo aplicado | OK | total=6 |
| GET /gateway/categorias/1 | OK | esperado=200 obtenido=200  |
| Categoría 1 tiene las propiedades esperadas | OK | {"categoriaId":1,"nombre":"Entradas","descripcion":"Platos ligeros para comenzar la comida","activo":true,"cantidadPlatos":3} |
| GET /gateway/categorias/999999 | OK | esperado=404 obtenido=404  |
| GET /gateway/categorias/1/platos | OK | esperado=200 obtenido=200  |
| Ruta anidada devuelve solo platos de la categoría 1 | OK | total=3 |
| GET /gateway/categorias/999999/platos | OK | esperado=404 obtenido=404  |
| POST /gateway/categorias (Chef) | OK | esperado=201 obtenido=201  |
| Categoría creada con id y Location del gateway | OK | id=11 Location=http://localhost:5000/gateway/Categorias/11 |
| POST /gateway/categorias (nombre duplicado) | OK | esperado=409 obtenido=409  |
| POST /gateway/categorias (sin token) | OK | esperado=401 obtenido=401  |
| POST /gateway/categorias (Mesero) | OK | esperado=403 obtenido=403  |
| POST /gateway/categorias (token malformado) | OK | esperado=401 obtenido=401  |
| PUT /gateway/categorias/{id} (Chef) | OK | esperado=204 obtenido=204  |
| GET categoría después de PUT | OK | esperado=200 obtenido=200  |
| PUT se refleja en la consulta | OK | {"categoriaId":11,"nombre":"Categoria Verificacion 639312330734707008 actualizada","descripcion":"Actualizada","activo":false,"cantidadPlatos":0} |
| PUT /gateway/categorias/999999 | OK | esperado=404 obtenido=404  |
| GET /gateway/platos | OK | esperado=200 obtenido=200  |
| Lista de platos no vacía | OK | total=10 |
| GET /gateway/platos?categoriaId=1 | OK | esperado=200 obtenido=200  |
| Filtro categoríaId aplicado | OK | total=3 |
| GET /gateway/platos?nombre=Ceviche | OK | esperado=200 obtenido=200  |
| Filtro nombre aplicado | OK | total=1 |
| GET /gateway/platos (precioMin, precioMax, disponible) | OK | esperado=200 obtenido=200  |
| Filtros de precio y disponibilidad aplicados | OK | total=6 |
| GET /gateway/platos/1 | OK | esperado=200 obtenido=200  |
| Plato 1 tiene las propiedades esperadas | OK | {"platoId":1,"nombre":"Ceviche clásico","descripcion":"Pescado fresco marinado en limón y ají","precio":28.90,"disponible":true,"categoriaId":1,"categoriaNombre":"Entradas"} |
| GET /gateway/platos/999999 | OK | esperado=404 obtenido=404  |
| POST /gateway/platos (Chef) | OK | esperado=201 obtenido=201  |
| Plato creado con id y Location del gateway | OK | id=20 Location=http://localhost:5000/gateway/Platos/20 |
| POST /gateway/platos (precio fuera de rango) | OK | esperado=400 obtenido=400  |
| POST /gateway/platos (categoría inexistente) | OK | esperado=409 obtenido=409  |
| POST /gateway/platos (sin token) | OK | esperado=401 obtenido=401  |
| POST /gateway/platos (Mesero) | OK | esperado=403 obtenido=403  |
| PUT /gateway/platos/{id} (Chef) | OK | esperado=204 obtenido=204  |
| GET plato después de PUT | OK | esperado=200 obtenido=200  |
| PUT se refleja en la consulta | OK | {"platoId":20,"nombre":"Plato Verificacion 639312330734707008 actualizado","descripcion":"Actualizado","precio":42.75,"disponible":false,"categoriaId":1,"categoriaNombre":"Entradas"} |
| PUT /gateway/platos/999999 | OK | esperado=404 obtenido=404  |
| DELETE /gateway/platos/{id} (Mesero) | OK | esperado=403 obtenido=403  |
| DELETE /gateway/platos/{id} (sin token) | OK | esperado=401 obtenido=401  |
| DELETE /gateway/platos/{id} (Chef) | OK | esperado=204 obtenido=204  |
| GET plato eliminado | OK | esperado=404 obtenido=404  |
| DELETE /gateway/platos/999999 | OK | esperado=404 obtenido=404  |
| GET /gateway/reservas (Chef) | OK | esperado=200 obtenido=200  |
| Lista de reservas no vacía | OK | total=8 |
| GET /gateway/reservas (Mesero) | OK | esperado=200 obtenido=200  |
| GET /gateway/reservas?estado=Confirmada | OK | esperado=200 obtenido=200  |
| Filtro estado aplicado | OK | total=5 |
| GET /gateway/reservas?fecha=2026-11-25 | OK | esperado=200 obtenido=200  |
| Filtro fecha aplicado | OK | total=3 |
| GET /gateway/reservas/1 | OK | esperado=200 obtenido=200  |
| Reserva 1 tiene las propiedades esperadas | OK | {"id":1,"cliente":"Lucía Ramírez","telefono":"987654321","fecha":"2026-11-25","hora":"19:30","personas":4,"mesa":7,"estado":"Confirmada"} |
| GET /gateway/reservas/999999 | OK | esperado=404 obtenido=404  |
| GET /gateway/reservas (sin token) | OK | esperado=401 obtenido=401  |
| GET /gateway/reservas (token malformado) | OK | esperado=401 obtenido=401  |
| GET directo http://localhost:5002/api/reservas (sin token) | OK | esperado=401 obtenido=401  |
| GET directo http://localhost:5002/api/reservas/1 (con token) | OK | esperado=200 obtenido=200  |
| GET /gateway/no-existe (ruta no configurada) | OK | esperado=404 obtenido=404  |
| GET /gateway/reservas con microservicio 2 detenido | OK | esperado=502 obtenido=502 PID detenido=28536 |
| GET /gateway/platos mientras el servicio 2 está caído | OK | esperado=200 obtenido=200  |
| Reservas.Api reiniciado después del 502 | OK | PID=22580 |
| GET /gateway/reservas después de reiniciar | OK | esperado=200 obtenido=200  |

**Total: 83 comprobaciones. Fallos: 0.**
