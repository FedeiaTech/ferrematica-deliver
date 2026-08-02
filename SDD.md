# SDD — Ferrematica Express (App Móvil)

## 1. Resumen del proyecto

Aplicación móvil para **Ferrematica Express**, ferretería especializada en entrega de productos en el domicilio del cliente. La app tiene dos roles:

- **Dueño**: carga pedidos, asigna cadetes, controla el estado de las entregas y los montos a cobrar.
- **Cadete / Transporte**: recibe pedidos asignados, navega hacia el destino en un mapa, ve el detalle del pedido (productos, monto a cobrar, datos del cliente) y actualiza el estado de la entrega.

No existe un tercer rol de "cliente final" en esta versión: los pedidos ingresan por teléfono/WhatsApp y el dueño los carga manualmente en el sistema.

## 2. Objetivos

- Reemplazar el seguimiento manual de pedidos (papel/WhatsApp) por un registro centralizado.
- Dar al cadete una guía de navegación clara hacia el punto de entrega.
- Mostrar de forma inequívoca **cuánto debe cobrar** el cadete y **a quién** (nombre o nick del cliente) en cada entrega.
- Mantener visibilidad del dueño sobre el estado de cada pedido y cadete en curso.

## 3. Alcance (v1)

**Incluido:**
- Gestión de pedidos por el dueño (alta, edición, asignación, cancelación).
- Vista de mapa con pin de destino, ícono personalizado y traza de recorrido (banda de ruta) para el cadete.
- Registro de cobro: monto a cobrar, método de pago (efectivo o transferencia), estado de cobro.
- Gestión de cuentas de cadetes por el dueño (alta de usuarios).
- Notas/observaciones de entrega y teléfono de contacto del cliente.
- Historial básico de pedidos entregados.
- Manejo offline básico: el cadete conserva el pedido asignado en caché local si pierde señal, y sincroniza al reconectar.

**Fuera de alcance (v1):**
- App o portal para que el cliente final haga pedidos por su cuenta.
- Asignación automática de cadetes (asignación siempre manual por el dueño).
- Cobro integrado dentro de la app (pasarela de pago in-app); la transferencia se confirma manualmente.
- Multi-sucursal / múltiples ferreterías.
- Panel tipo "centro de control" con optimización de rutas para flota grande (no aplica: 1 a 3 cadetes).

## 4. Roles y permisos

| Acción | Dueño | Cadete |
|---|---|---|
| Crear/editar pedido | ✅ | ❌ |
| Asignar cadete a pedido | ✅ | ❌ |
| Ver todos los pedidos | ✅ | ❌ (solo los propios) |
| Ver pedidos asignados a sí mismo | — | ✅ |
| Navegar al destino (mapa + ruta) | — | ✅ |
| Marcar pedido como "en camino" / "entregado" | ❌ | ✅ |
| Confirmar cobro recibido | ❌ | ✅ |
| Crear cuentas de cadetes | ✅ | ❌ |
| Ver historial de entregas | ✅ (todas) | ✅ (propias) |

## 5. Stack tecnológico

| Capa | Elección | Motivo |
|---|---|---|
| App móvil | **Flutter** | Un solo codebase Android/iOS, buen soporte de mapas y background location. |
| Backend / DB | **Supabase** (Postgres + Auth + Realtime + Storage) | Modelo relacional real para pedidos/clientes/cadetes, Realtime para tracking en vivo. |
| Autenticación | **Supabase Auth** (email + contraseña) | El dueño crea las cuentas de los cadetes desde su panel; sin fricción de SMS/OTP. |
| Mapas y ruteo | **OpenStreetMap** (`flutter_map` + Nominatim + OSRM) | Sin API key ni tarjeta de crédito requerida (Google Maps Platform exige tarjeta para todas sus APIs, sin excepción). Markers personalizados, `Polyline` para banda de recorrido; OSRM demo público sirve para el volumen esperado (1-3 cadetes) pero requiere self-host antes de escalar. |
| Estado / arquitectura app | Riverpod o Bloc (a definir en diseño técnico) | Separación por capas (presentación / dominio / datos). |

## 6. Modelo de datos (entidades principales)

### `users`
- id, email, rol (`owner` | `cadete`), nombre, teléfono, activo (bool)

### `clients`
- id, nombre o nick, teléfono, dirección habitual (opcional, para autocompletar)

### `orders`
- id
- client_id (FK, **opcional** — se puede cargar el pedido sin cliente registrado)
- assigned_cadete_id (FK, nullable hasta asignar)
- created_by (owner)
- delivery_address (texto + lat/lng geocodificado) — **único campo obligatorio**
- items: lista de productos (nombre, cantidad) — ver `order_items` — **opcional**
- amount_to_charge (numérico) — **opcional**, se puede completar/editar después
- payment_method (`efectivo` | `transferencia` | `sin_definir`) — **opcional**
- payment_status (`pendiente` | `cobrado`)
- notes (observaciones para el cadete) — **opcional**
- status (`pendiente` | `asignado` | `en_camino` | `entregado` | `cancelado`)
- created_at, delivered_at

> Regla de diseño: **solo la dirección de destino es obligatoria** para crear un pedido. Todo lo demás (cliente, productos, monto, método de pago, notas) puede completarse en el momento o editarse después, para no frenar la carga rápida de un envío. La app debe permitir marcar visualmente los pedidos con datos incompletos (ej. "sin monto cargado") para que el dueño los complete antes de que el cadete confirme el cobro.

### `order_items`
- id, order_id (FK), product_name, quantity

### `cadete_locations` (para tracking en vivo)
- cadete_id, lat, lng, updated_at (tabla o canal Realtime, se define en diseño técnico)

## 7. Flujos principales

### 7.1 Alta de pedido (Dueño) — carga rápida y libre
1. Dueño abre "Nuevo pedido".
2. Carga **solo la dirección de destino** (único dato obligatorio) y asigna cadete → el pedido ya puede despacharse.
3. El resto es opcional y se completa según disponibilidad de información en ese momento o después:
   - Cliente (nombre/nick, teléfono).
   - Productos (nombre + cantidad).
   - Monto a cobrar y método de pago (efectivo/transferencia).
   - Notas de entrega.
4. Pedido pasa a estado `asignado`; el cadete recibe notificación.
5. Si el pedido queda incompleto (sin monto, por ejemplo), la app lo marca visualmente para que el dueño lo complete antes de que el cadete cierre el cobro.

### 7.2 Entrega (Cadete)
1. Cadete ve el pedido asignado en su lista (con dirección, monto a cobrar, nombre/nick del cliente, teléfono, notas).
2. Abre el mapa: pin de destino con ícono personalizado + banda de recorrido calculada desde su ubicación actual (OSRM).
3. Marca "en camino" al salir → dueño ve el estado actualizado.
4. Al llegar, marca "entregado" y confirma cobro (efectivo recibido / transferencia confirmada).
5. Pedido pasa a `entregado`, queda en historial.

### 7.3 Pérdida de conexión (Cadete)
1. Si el cadete pierde señal, la app mantiene visible el pedido asignado (dirección, monto, notas) desde caché local.
2. Los cambios de estado que el cadete haga offline se encolan localmente.
3. Al recuperar conexión, se sincronizan contra Supabase.

## 8. Pantallas (borrador)

**Dueño:**
- Login
- Dashboard de pedidos (por estado)
- Nuevo pedido / Editar pedido
- Detalle de pedido (con mapa de seguimiento del cadete asignado)
- Gestión de cadetes (alta/baja)
- Historial

**Cadete:**
- Login
- Lista de pedidos asignados
- Detalle de pedido (productos, monto, cliente, teléfono, notas)
- Mapa de navegación (pin + ruta)
- Confirmación de entrega y cobro

## 9. Requisitos no funcionales

- **Tiempo real**: cambios de estado de pedido y ubicación del cadete deben reflejarse en la app del dueño en segundos (Supabase Realtime).
- **Offline básico**: pedido asignado visible sin conexión; sincronización diferida de cambios de estado.
- **Costos de mapas**: stack 100% gratuito (OpenStreetMap tiles, Nominatim, OSRM demo público), sin costo ni tarjeta de crédito requerida para el volumen esperado (1-3 cadetes). El servidor demo de OSRM no está licenciado para tráfico de producción a escala; escalar requeriría self-hostear OSRM.
- **Plataformas**: Android e iOS.

## 10. Seguridad

- **Autenticación**: Supabase Auth (email + contraseña), tokens JWT con expiración corta y refresh token. El dueño es el único que puede dar de alta cuentas de cadete (sin auto-registro público).
- **Autorización por rol (RLS)**: Row Level Security en todas las tablas de Postgres.
  - Un cadete solo puede leer/escribir los pedidos donde `assigned_cadete_id = auth.uid()`.
  - Solo el rol `owner` puede crear, editar o reasignar pedidos, y dar de alta cadetes.
  - Ningún usuario puede leer datos de otro cadete (ubicación, historial) salvo el dueño.
- **Transporte**: toda comunicación cliente-servidor vía HTTPS/TLS (Supabase lo fuerza por defecto). Sin excepciones para tráfico de ubicación en tiempo real.
- **Sin API keys de mapas**: el stack OpenStreetMap (`flutter_map`, Nominatim, OSRM) no requiere ninguna API key, así que no hay superficie de key filtrada/reutilizable que asegurar en este punto.
- **Datos sensibles**:
  - Contraseñas: gestionadas y hasheadas por Supabase Auth (nunca en texto plano en la app).
  - Ubicación del cadete: se persiste solo mientras el pedido está activo; no se conserva historial de tracking indefinido salvo que se decida lo contrario para auditoría.
  - Datos de cliente (nombre/nick, teléfono, dirección): accesibles solo para el dueño y el cadete con el pedido asignado.
- **Almacenamiento local (offline)**: la caché local del pedido asignado (para el modo offline) se guarda en almacenamiento cifrado del dispositivo (ej. `flutter_secure_storage` para tokens, base local cifrada para datos de pedido), no en texto plano.
- **Validación de entrada**: sanitización de campos de texto libre (notas, nombre/nick) tanto en cliente como con constraints en Postgres, para evitar inyección o payloads maliciosos.
- **Trazabilidad**: cada pedido registra `created_by` y timestamps de cada cambio de estado, para poder auditar quién cargó o modificó qué.
- **Sesión**: cierre de sesión automático tras un período de inactividad configurable (a definir monto exacto en diseño técnico).

## 11. Decisiones técnicas finales

- **Gestor de estado**: Riverpod.
- **Cola local offline**: Isar (guarda el pedido activo y encola los cambios de estado hechos sin conexión hasta sincronizar con Supabase).
- **Notificaciones push**: Firebase Cloud Messaging (FCM), disparado al asignar un pedido a un cadete.
- **Cobro pendiente**: el cadete puede marcar "entregado" sin confirmar el cobro. El pedido queda con `payment_status = pendiente` y dispara una alerta al dueño para que haga seguimiento (no bloquea el cierre del pedido, consistente con el criterio de no frenar la operación).
