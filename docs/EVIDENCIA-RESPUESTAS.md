# Evidencia de respuestas por el gateway

Fecha: 2026-11-25 19:30:44
Gateway: http://localhost:5000

## 200 - Plato por id (público)

`GET http://localhost:5000/gateway/platos/1` -> **200** (esperado 200) - OK

```json
{"platoId":1,"nombre":"Ceviche clásico","descripcion":"Pescado fresco marinado en limón y ají","precio":28.90,"disponible":true,"categoriaId":1,"categoriaNombre":"Entradas"}
```

## 200 - Reserva por id (token)

`GET http://localhost:5000/gateway/reservas/1` -> **200** (esperado 200) - OK

```json
{"id":1,"cliente":"Lucía Ramírez","telefono":"987654321","fecha":"2026-11-25","hora":"19:30","personas":4,"mesa":7,"estado":"Confirmada"}
```

## 201 - Crear plato (Chef)

`POST http://localhost:5000/gateway/platos` -> **201** (esperado 201) - OK

```json
{"platoId":16,"nombre":"Plato evidencia 639312318440070494","descripcion":"Creado para la evidencia de respuestas","precio":27.50,"disponible":true,"categoriaId":1,"categoriaNombre":"Entradas"}
```

## 204 - Actualizar plato (Chef)

`PUT http://localhost:5000/gateway/platos/16` -> **204** (esperado 204) - OK

```json
(sin cuerpo)
```

## 401 - Reservas sin token

`GET http://localhost:5000/gateway/reservas` -> **401** (esperado 401) - OK

```json
(sin cuerpo)
```

## 403 - Crear plato con Mesero

`POST http://localhost:5000/gateway/platos` -> **403** (esperado 403) - OK

```json
(sin cuerpo)
```

## 404 - Plato inexistente

`GET http://localhost:5000/gateway/platos/999999` -> **404** (esperado 404) - OK

```json
{"mensaje":"No existe el plato con id 999999."}
```

## 404 - Ruta no configurada

`GET http://localhost:5000/gateway/no-existe` -> **404** (esperado 404) - OK

```json
(sin cuerpo)
```

## 401 - Reservas directo sin token

`GET http://localhost:5002/api/reservas` -> **401** (esperado 401) - OK

```json
(sin cuerpo)
```

## 204 - Eliminar plato (Chef)

`DELETE http://localhost:5000/gateway/platos/16` -> **204** (esperado 204) - OK

```json
(sin cuerpo)
```

