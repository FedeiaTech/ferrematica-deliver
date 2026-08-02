# Ferrematica Express

Scaffold Flutter para la app de delivery de Ferrematica (ver `SDD.md`).

## Configuración inicial

1. `flutter pub get`
2. Copiar `dart_define.example.json` a `dart_define.json` (ignorado por git) y
   completar los valores reales de `SUPABASE_URL` / `SUPABASE_ANON_KEY` /
   `GOOGLE_MAPS_API_KEY`.
3. Ejecutar con los secrets inyectados:
   `flutter run --dart-define-from-file=dart_define.json`

### Configuración nativa de Google Maps

La configuración nativa de Maps (Android/iOS) lee la API key desde
**archivos locales de la máquina, ignorados por git**, no desde
`dart_define.json` (los SDKs nativos no pueden leer los valores
`--dart-define` de Dart):

- Android: `android/local.properties` → `MAPS_API_KEY=...`
- iOS: copiar `ios/Runner/Config/Secrets.example.xcconfig` a
  `ios/Runner/Config/Secrets.xcconfig` y completar `GOOGLE_MAPS_API_KEY`.

Ambos archivos vienen con un valor placeholder para que la app compile sin
una key real (los pedidos a Maps simplemente van a fallar en runtime hasta
que se configure una key real).

**PASO MANUAL — no se puede automatizar con sdd-apply:** antes de publicar
la app, la API key real de Google Maps DEBE restringirse en la
[Google Cloud Console](https://console.cloud.google.com/):

- Android: restringir por el fingerprint SHA-1 del certificado de firma de
  la app + el nombre de paquete `com.ferrematica.express`.
- iOS: restringir por el Bundle ID `com.ferrematica.express`.

Una key sin restricciones embebida en un binario publicado no es secreta —
se puede extraer del APK/IPA. La restricción es lo que realmente la
protege.

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
