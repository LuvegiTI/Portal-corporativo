# AGENTS.md — Portal LUVEGI

Guía para agentes que trabajan en este repositorio. Idioma de trabajo y de comentarios: español.

## Repositorio y ramas

- **Rama activa de trabajo: `develop`.** `main` es antigua ("Primer commit"), NO trabajar ahí.
- Git requiere credenciales para `ls-remote`/push en esta máquina; no asumir auth disponible.
- Hay cambios locales sin commitear (módulo RDR y `php/` untracked). No commitear a menos que se pida.

## Estructura del proyecto

- **App Flutter (web + Android)** en la raíz. UI 100% en español.
- 👉 `ejecutivos/` es **OTRO proyecto Flutter separado** (su propio `pubspec.yaml`, nombre `ejecutivos`, trackeado, sin `.git` propio). NO mezclar cambios entre la app raíz y `ejecutivos/`.
- `php/` contiene copias locales de archivos PHP del backend (untracked). El backend NO vive en este repo.

## Backend (PHP)

- URL base fija: `https://portal.luvegi.com/api_luvegi/` (sin variable de entorno).
- Backend desplegado aparte (cPanel). Solo hay copias de referencia en `php/` (`reporte_compra.php`, `reporte_compra_common.php`, `reporte_luvegi_buscarpedido.php`).
- 📌 Auditoría previa: esos PHP **no autentican con Bearer**. No asumir que el backend valida tokens; verificarlo al tocar endpoints sensibles.

## Convenciones de red / sesión

- Dos estilos coexisten:
  - **`ApiClient` (lib/pages/api_client.dart)**: singleton Dio con interceptor que agrega `Authorization: Bearer <token>` y fuerza logout en 401. Usado por login/auth y la mayoría de pages.
  - **`RdrService` (lib/services/rdr_service.dart)**: usa `package:http` directo, headers Bearer manuales, tiempo de espera 15 s, y `_decode()` exige `statusCode` 2xx **y** `body['ok'] == true` (lanza `RdrApiException` con mensaje del servidor).
- Sesión en `SharedPreferences` (keys: `token`, `rol`, `nombre`, `correo`, `usuarioId`, `permisos`). `AuthService` guarda/lee sesión; `AuthGate` decide Login vs Home.
- Login envía `usuario`, `password`, `licencia`, `hardware_id` (licencia ligada a hardware).
- **Timeout de inactividad: 15 min** en `lib/main.dart` (`SessionTimeoutWrapper`) y `lib/utils/session_timeout_wrapper.dart`. Ajustar los DOS si cambia.
- Polling: `ApiClient` consulta `mis_permisos.php` cada 3 s y `AuthService.iniciarPolling()` cada 20 s.

## Módulo RDR (trabajo actual)

- Pages en `lib/pages/rdr/`: `consultar_rdr_page.dart`, `detalle_rdr_page.dart`, etc.
- Endpoints PHP usados: `registrar_rdr.php`, `mi_perfil_rdr.php`, `consultar_rdr.php`, `detalle_rdr.php`, `atender_rdr.php`, `admin_atenciones_rdr.php` (acciones `verificar`, `editar`, `historial`, `reabrir`).
- `consultarRdr()` ya es paginado (`page`, `page_size`). `obtenerHistorialAtencionRdr()` entrega lista.
- El SLA y el informe PDF **NO están en el requerimiento**: no reimplementarlos.
- Antigüedad: campo `creado_en` (o `fecha_apertura`) se usa como referencia de fechas.
- Variables de nombre del campo que acepta el servidor: `codigo_redir` / `codigo_rdir` / `codigo_rdr` se envían los tres (compatibilidad).

## Verificación

- ✅ **`flutter analyze`** es la verificación principal. Hay warnings/infos de deprecación preexistentes (`withOpacity`, imports sin usar, emojis en comentarios) — 0 errores.
- ❌ **`flutter test` FALLA** actualmente: `test/widget_test.dart` es el smoke test del template por defecto (contador) que ya no aplica. No correrlo como gate; no arreglarlo salvo que se pida.
- Web: `flutter run -d web-server --web-port=8080 --release`, `flutter build web --release`.
- Android: `flutter build apk --release`. En ambas compilaciones `build.gradle.kts` aún usa `applicationId = com.example.flutter_application_1` y firma de release con debug keys (placeholder del template).

## Entorno de esta máquina (Windows)

- Node: `C:\Program Files\nodejs` (NO está en el PATH de sesiones de terminal nuevas; exportar `PATH=/c/Program Files/nodejs:$PATH` si hace falta). Global npm en `C:\Users\Usuario\AppData\Roaming\npm` (claude, codex).
- Android SDK: `C:\Users\Usuario\AppData\Local\Android\Sdk`; usar **`cmdline-tools\12.0`** — `latest` fue renombrado a `latest-broken` (crash con Gradle, exit -1073740791).
- PowerShell `ExecutionPolicy = RemoteSigned` (CurrentUser) para correr scripts de claude/codex.
- Orca CLI: `C:\Users\Usuario\AppData\Local\Programs\orca\resources\bin\orca.exe`; usa worktrees (`agente-claude-prueba`, `agente-codex-prueba`) con agentes codex/claude.

## Reglas generales

- No añadir comentarios al código salvo que se pida; mantener el estilo existente (emojis y comentarios españoles ya presentes).
- Seguir el design system: `lib/theme/luvegi_*.dart` (Colores/Text/Spacing/Radius/Shadows) y widgets en `lib/design_system/`.
- Exportar Excel: patrón de `lib/pages/reporte_compra_page.dart` (`package:excel` como `excel_lib` + `package:file_saver` + `dart:typed_data`).