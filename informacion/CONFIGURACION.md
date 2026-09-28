# Configuración del entorno de trabajo

Cómo está armado el proyecto para trabajar desde el PC, el celular y la nube. Resumen de la
sesión del 2026-09-24 (detalle en `BITACORA.md`, pedidos textuales en `registro_prompts.md`).

## Dónde está cada cosa

| Qué | Dónde |
|---|---|
| Código y datos (fuente de verdad) | GitHub privado: https://github.com/joselcortes/InversionesBolsa (rama `main`) |
| Copia de trabajo en el PC | `C:\Users\josel\OneDrive\Escritorio\Aplicaciones Moviles\InversionesBolsa` |
| APK publicadas (público) | https://github.com/joselcortes/inversiones-tienda/releases |
| App web, tienda y `agentes/datos.json` | Firebase Hosting, proyecto `inversiones-cl-34686` (también es el único proyecto de Google Cloud) |
| Rutina diaria en la nube | https://claude.ai/code/routines/trig_01Nrj3v32xnJrY4tx7gDYKXS |

- Se decidió usar **solo GitHub** (no GitLab): Claude Code en la nube solo trabaja con GitHub.
- A futuro conviene mover la carpeta fuera de OneDrive (ej. `C:\Proyectos\InversionesBolsa`).

## Claude desde el celular (sin PC)

1. App **Claude** con la cuenta jlccaf369@gmail.com → menú → **Code** (no "Nuevo chat").
   Sin la opción Code: navegador → https://claude.ai/code.
2. Nueva sesión → repositorio **joselcortes/InversionesBolsa**, entorno **Default**.
3. La sesión lee `CLAUDE.md` y esta carpeta, así que conoce el proyecto.

- El **chat normal** no puede hacer push: solo entrega archivos (.patch/.zip). Así llegó el
  Asistente IA (aplicado en el PC con `git am`).
- Si el push a `main` es rechazado, la sesión sube a su rama `claude/...` y abre un pull request;
  se aprueba con **Merge** en la app de GitHub.
- La app de GitHub de Claude tiene acceso de escritura al repo (verificado por el usuario).
- GitHub quedó conectado a Claude con `/web-setup` (cuenta `joselcortes`).

## Claude desde el celular (con el PC encendido)

- En la terminal del PC: `/remote-control` → la sesión aparece en la app Claude → Code.
- El PC no debe suspenderse (Configuración → Sistema → Energía).

## Rutina diaria en la nube

- Nombre "Inversiones – mercado y carteras", lunes a viernes 22:00 UTC (19:00 Chile en horario de
  verano; 18:00 desde abril). Modelo `claude-sonnet-5`, entorno "Default".
- Registra el mercado, revisa las carteras simuladas, escribe reporte y bitácora, y hace push a `main`.
- **Problema abierto:** Yahoo Finance responde HTTP 403 desde la nube. Probar agregando
  `query1.finance.yahoo.com` y `query2.finance.yahoo.com` a la red del entorno Default; si sigue,
  usar Alpaca (claves paper como variables del entorno, nunca en el repo).
- Mientras tanto, la tarea de Windows "InversionesBolsa - Registrar mercado" (18:00) trae los precios.

## Registro de pedidos

- Hook `UserPromptSubmit` en `.claude/settings.json` **del proyecto** (antes estaba en
  `~/.claude/settings.json`): anota cada pedido en `registro_prompts.md` desde el PC, el celular o la nube.
- El idioma español (Chile) está en `~/.claude/settings.json` del PC; en la nube lo exige `CLAUDE.md`.

## Actualizaciones de la app

- Un cambio de código subido a GitHub **no** genera actualización.
- Solo `dart run tool/publicar.dart --notas "..."` (en el PC, con OK del usuario) publica: sube la
  APK a `inversiones-tienda`, actualiza `releases/apps.json`, la web, la tienda y `agentes/datos.json`.
- La app Android avisa al abrirla (o en Más → Mi tienda); la web se actualiza al recargar.
- Antes de publicar: subir la versión en `pubspec.yaml` (el número después del `+` siempre aumenta).
- Opción pendiente: publicar sin PC con GitHub Actions (llave de firma como secreto cifrado).

## Asistente IA (versión 1.2.0)

- Más → Asistente IA, con Gemini gratis (clave de https://aistudio.google.com/apikey, guardada
  cifrada en el teléfono).
- `agentes/datos.json` es público (carteras simuladas, reportes, mercado; sin claves).
- Cada pregunta envía la cuenta Alpaca a Google; en el plan gratuito Google puede usar esos datos.

## Detalles técnicos

- En el PC, git usa la sesión de `gh` para GitHub (configurado solo en este repo).
- La bitácora tiene saltos de línea CRLF: al editarla con scripts, buscar `\r?\n`.
