# Ferrematica Express

Scaffold Flutter para la app de delivery de Ferrematica (ver `SDD.md`).

## Configuración inicial

1. `flutter pub get`
2. Copiar `dart_define.example.json` a `dart_define.json` (ignorado por git) y
   completar los valores reales de `SUPABASE_URL` / `SUPABASE_ANON_KEY`.
3. Ejecutar con los secrets inyectados:
   `flutter run --dart-define-from-file=dart_define.json`

### Mapa, geocoding y ruteo — stack OpenStreetMap (sin API key)

La app usa un stack 100% gratuito basado en OpenStreetMap en lugar de
Google Maps Platform — Google exige tarjeta de crédito cargada para
**todas** las APIs de Maps Platform (Maps SDK, Directions, Geocoding), sin
excepción, y no fue posible conseguir la aprobación de una tarjeta para el
proyecto. No hace falta ninguna API key ni configuración nativa
(Android/iOS) para el mapa:

- **Mapa**: `flutter_map` + tiles raster de
  `https://tile.openstreetmap.org/{z}/{x}/{y}.png`. Sin key.
- **Geocoding** (dirección → lat/lng): **Nominatim**
  (`https://nominatim.openstreetmap.org/search`), implementado en
  `HttpGeocodingClient`. Sin key, pero su
  [política de uso](https://operations.osmfoundation.org/policies/nominatim/)
  exige un header `User-Agent` descriptivo (ya seteado:
  `Ferrematica/1.0 (delivery order geocoding)`) y limita a ~1 request/seg —
  no es un problema para este uso (un geocode por alta/edición de pedido,
  no en lote).
- **Ruteo** (Directions): **OSRM**, servidor demo público
  (`https://router.project-osrm.org`), implementado en
  `HttpDirectionsClient`. Sin key.

**El servidor demo de OSRM es solo para desarrollo** — sus
[términos de uso](http://project-osrm.org/) no lo habilitan para tráfico de
producción a escala. Antes de escalar la app en producción hay que
self-hostear una instancia propia de OSRM (o migrar a un proveedor de
ruteo pago con SLA).

## Base de datos — migraciones de Supabase

Las migraciones en `supabase/migrations/` (`0001_profiles.sql`,
`0002_orders.sql`, `0003_en_camino_and_cadete_profiles.sql`) no se aplican
solas: hay que correrlas a mano contra el proyecto Supabase real, en orden,
desde el **SQL Editor** del Dashboard (o con la Supabase CLI si el proyecto
ya está vinculado). Ninguna se aplicó nunca contra un proyecto real en este
change — no existe todavía un proyecto Supabase vivo para este repo (ver
sección siguiente), así que la corrección de las tres sigue siendo
solo revisión de código, no verificación en runtime.

`0003` en particular es la que suma soporte para `en_camino` y la
asignación de cadetes (`sdd/navegacion-cadete`): sin aplicarla, el check
constraint de `orders.status` sigue rechazando `'en_camino'` y la policy
que deja a un dueño listar `profiles` con `rol='cadete'` no existe, así
que la pantalla "Asignar cadete" no podría leer la lista de repartidores.

## Autenticación — alta de cuentas (dueño y cadete)

La app usa Supabase Auth (email/password) para ambos roles. **No hay
alta propia (self-registration)**: tanto la cuenta del dueño como las de
cada cadete se crean manualmente desde el Supabase Dashboard, nunca desde
un flujo cliente. Esto es intencional (ver `sdd/navegacion-cadete/design`,
decisión #5): la Service Role Key habilita un bypass total de la base y
**nunca debe viajar en un binario Flutter** (es extraíble de un APK/IPA).
Una Edge Function es la respuesta correcta a largo plazo, pero no hay
proyecto Supabase real todavía y agregarla ahora es scope innecesario para
esta etapa.

**Runbook manual (dueño y cadete, mismo procedimiento):**

1. Supabase Dashboard → **Authentication → Users → Add user** → cargar
   email + contraseña. Copiar el UUID generado.
2. Supabase Dashboard → **SQL Editor**, ejecutar:
   ```sql
   insert into public.profiles (id, rol, full_name)
   values ('<uuid-copiado>', 'dueno', 'Nombre y Apellido');
   -- o rol = 'cadete' para un repartidor
   ```
3. La cuenta ya puede iniciar sesión desde la pantalla de login de la app.

## Primeros pasos

Este proyecto es el punto de partida de una aplicación Flutter.

Algunos recursos útiles si es tu primer proyecto Flutter:

- [Lab: escribí tu primera app Flutter](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: ejemplos útiles de Flutter](https://docs.flutter.dev/cookbook)

Para más ayuda con el desarrollo en Flutter, mirá la
[documentación oficial](https://docs.flutter.dev/), que ofrece tutoriales,
ejemplos, guías de desarrollo mobile y la referencia completa de la API.
