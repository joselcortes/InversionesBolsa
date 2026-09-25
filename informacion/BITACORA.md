# Bitácora del proyecto Inversiones

Lo más reciente va arriba en cada sección.

## Plan / pendientes

- [ ] Completar en `PROMPT_MEJORAS.md` los datos del proyecto Firebase (ID, plan, correo).
- [x] Instalar gcloud y conectarlo al proyecto inversiones-cl-34686.
- [ ] Pasar el proyecto Firebase a plan Blaze y crear alerta de presupuesto.
- [x] Primera ejecución de los agentes Trader e Inversionista (armar carteras iniciales).
- [ ] Revisión del Trader (stops/objetivos) cuando haya cierres nuevos.
- [x] Automatizar `tool/registrar_mercado.mjs` a diario (Programador de tareas de Windows).
- [ ] Agregar a `mercado_config.json` las acciones de mi lista de seguimiento real de la app.
- [ ] Fase 1: signo de moneda antes del número.
- [ ] Fase 1: corregir "Hoy ganaste" (last_equity en 0 y depósitos contados como ganancia).
- [ ] Fase 2: infraestructura Firebase (Auth, App Check, Firestore, Functions, Secret Manager).
- [ ] Fase 3: historial de mercado guardado por función programada.
- [ ] Fase 4: ficha de decisión con números reales.
- [ ] Fase 5: verificación de estimaciones y backtesting.
- [ ] Fase 6: Claude dentro de la app (Vertex AI o API de Anthropic).
- [ ] Agregar `firebase-debug.log` al `.gitignore`.

## Registro de cambios

### 2026-09-25 — Revisión automática (nube)
- `registrar_mercado.mjs` volvió a fallar con HTTP 403 en los 11 símbolos; el cierre sigue siendo
  el 2026-09-23. Es el **tercer día hábil seguido** (24-sep x2 y 25-sep) sin poder descargar un
  cierre nuevo desde la nube — el bloqueo de Yahoo Finance persiste sin resolverse.
- **Trader**: sin cambios (US$ 9.965,81, −0,34 % vs inicio); AAPL y NVDA sin tocar stop/objetivo;
  MSFT (518) y GOOGL (360) sin activarse. No se registraron operaciones nuevas.
- **Inversionista**: sin cambios (US$ 9.923,05, −0,72 % vs inicio); ninguna posición se desvía más
  de 5 pp de su peso objetivo; no corresponde aporte (es en octubre).
- Reporte: `informacion/reportes/2026-09-25-revision.md`.

### 2026-09-24 — Revisión automática (nube)
- Segunda pasada de la rutina diaria del mismo día: `registrar_mercado.mjs` volvió a fallar con
  HTTP 403 (Yahoo bloqueado desde la nube); el cierre sigue siendo el 2026-09-23, sin novedades
  respecto a la revisión de esta mañana.
- **Trader**: sin cambios (US$ 9.965,81, −0,34 % vs inicio); AAPL y NVDA sin tocar stop/objetivo;
  MSFT (518) y GOOGL (360) sin activarse. No se registraron operaciones nuevas.
- **Inversionista**: sin cambios (US$ 9.923,05, −0,72 % vs inicio); ninguna posición se desvía más
  de 5 pp de su peso objetivo; no corresponde aporte (es en octubre).
- Reporte: `informacion/reportes/2026-09-24-revision.md`.

### 2026-09-24 (11) — Google Cloud CLI en el PC (pedido desde el celular, Remote Control)
- Instalado Google Cloud CLI 586 en `%LOCALAPPDATA%\google-cloud-sdk` (zip oficial, sin admin;
  winget solo ofrecía instalación de equipo con UAC). Agregado al PATH del usuario.
- Sesión iniciada como chipichipi094@gmail.com (login sin navegador). Proyecto por defecto:
  **inversiones-cl-34686** (el de Firebase). Facturación: **desactivada** (plan Spark).
- Verificado: GitHub (`gh`, joselcortes) y Firebase CLI con sesión iniciada; se pueden usar desde
  el celular vía Remote Control mientras el PC esté encendido y la sesión abierta.

### 2026-09-24 (10) — Configuración guardada
- Nuevo `informacion/CONFIGURACION.md`: resumen de esta sesión (GitHub, Claude desde el celular,
  rutina en la nube, registro de pedidos, publicación y Asistente IA). Enlazado desde `CLAUDE.md`.
- Diagnóstico: el celular usaba el chat normal (no Claude Code), que no puede hacer push.

### 2026-09-24 (9) — Push rechazado desde el celular
- Las sesiones del celular no pueden hacer push (por eso el Asistente IA llegó como .patch). La
  rutina diaria sí pudo subir a main. Causa probable: la app de GitHub de Claude sin permiso de
  escritura o push a main restringido en sesiones interactivas.
- `CLAUDE.md`: si el push a main falla, subir a la rama de la sesión y abrir un pull request.

### 2026-09-24 (8) — Registro de pedidos y sesiones desde el celular
- Hook de registro movido de `~/.claude/settings.json` a `.claude/settings.json` del proyecto
  (usa `$CLAUDE_PROJECT_DIR`): ahora también anota los pedidos hechos desde el celular o la nube.
- `CLAUDE.md`: nueva sección para sesiones en la nube (git pull/push, Yahoo 403, publicar solo en PC).

### 2026-09-24 (7) — Publicada la versión 1.2.0 (Asistente IA)
- Aplicado `asistente-ia.patch` (git am). flutter analyze: sin problemas; flutter test: 35 OK.
- Publicado con OK del usuario: APK 1.2.0+3 en GitHub (inversiones-tienda v1.2.0, SHA-256
  8ad6e97b…379aee), catálogo de la tienda, web y `agentes/datos.json` en Firebase.
- Advertido: datos.json es público (solo carteras simuladas) y el asistente envía la cuenta
  Alpaca a Gemini (plan gratuito: Google puede usar los datos).

### 2026-09-24 (6) — Asistente IA con los agentes en la app (v1.2.0+3)
- Nueva pantalla **Más → Asistente IA**: chat con Asistente (general), Trader e Inversionista.
  Botón "Pedir opinión de mi cartera", sugerencias por agente e historial guardado en el teléfono.
- Motor: **Gemini, plan gratuito** (Google AI Studio). La app llama directo a
  `generativelanguage.googleapis.com` con la clave del usuario, guardada cifrada
  (`flutter_secure_storage`). Modelos: alias `gemini-flash-latest` → `gemini-flash-lite-latest`.
- Contexto que reciben los agentes: cuenta Alpaca (patrimonio, efectivo, posiciones, lista) +
  `agentes/datos.json` (carteras simuladas, último reporte de cada agente, resumen de mercado),
  que `tool/publicar.dart` arma y publica en Firebase Hosting en cada publicación.
- Archivos nuevos: `lib/models/ai_agent.dart`, `lib/services/ai_service.dart`,
  `lib/services/ai_context.dart`, `lib/screens/assistant_screen.dart`, `test/ai_agent_test.dart`.
  Modificados: `more_screen.dart`, `firebase.json` (CSP + caché de /agentes), `tool/publicar.dart`,
  `pubspec.yaml`.
- En la app los agentes solo opinan: no modifican sus carteras ni envían órdenes.

### 2026-09-24 (5) — Revisión diaria automática (nube)
- `node tool/registrar_mercado.mjs` volvió a fallar con HTTP 403 desde la nube; se usó el cierre
  real del **2026-09-23** (caída generalizada: SPY -0,72 %, GOOGL -3,80 %) ya subido por el usuario.
- **Trader**: AAPL y NVDA retrocedieron con el mercado sin tocar stop/objetivo; ninguna condición
  de vigilancia se cumplió (MSFT 500,59 < 518, GOOGL 337,83 < 360, cada vez más lejos); se descartó
  "comprar la caída" en GOOGL/AMZN por falta de tendencia a favor. **No operó.** Cartera en
  US$ 9.965,81 (-0,34 % desde el inicio, mejor que SPY -0,74 % gracias al 54 % en efectivo).
  Reporte: `informacion/reportes/2026-09-24-trader.md`.
- **Inversionista**: valorizó en US$ 9.923,05 (-0,72 %, prácticamente igual a SPY -0,74 %); la
  caída de GOOGL solo desvió su peso -0,25 pp (muy bajo el umbral de 5 pp), sin tesis rota; no
  correspondía aporte (es en octubre). **Sin cambios en posiciones.**
  Reporte: `informacion/reportes/2026-09-24-inversionista.md`.
- Nota: la primera pasada de esta revisión se hizo por error con el cierre del 22-sep (antes de
  que llegara el push del usuario con el 23-sep); se descartó y se rehizo con el dato correcto.

### 2026-09-24 (4) — Prueba de la rutina en la nube
- Yahoo Finance responde **HTTP 403** desde la nube (en el PC funciona). La rutina no puede
  descargar precios ahí; pendiente: abrir la red del entorno o usar Alpaca como fuente.
- `tool/registrar_mercado.mjs`: si falla una descarga, el resumen se arma con lo ya guardado
  (antes quedaba vacío) y el script termina con código 1.
- Descargados en el PC los cierres del 23-09-2026.

### 2026-09-24 (3) — Repo en GitHub y rutina en la nube
- Repo privado: github.com/joselcortes/InversionesBolsa (GitHub conectado a Claude con /web-setup).
- Rutina en la nube "Inversiones – mercado y carteras" (trig_01Nrj3v32xnJrY4tx7gDYKXS): lun-vie
  22:00 UTC (19:00 Chile en horario de verano; 18:00 desde abril). Registra mercado, revisa carteras
  simuladas, escribe reporte y bitácora, y hace push a main. Modelo claude-sonnet-5.
- En el PC: hacer `git pull` al empezar cada sesión. Evaluar desactivar la tarea de Windows.

### 2026-09-24 (2) — Proyecto en git
- `git init` (rama main) y primer commit local (233 archivos). Revisados secretos: ninguno;
  keystore, key.properties, local.properties, build/ y releases/descargas/ quedan fuera.
- Pendiente (lo hace el usuario): crear repo privado en GitHub y subirlo; luego `/remote-control`
  y rutina diaria en la nube (registrar mercado + revisar carteras).

### 2026-09-24 (1) — Control desde el celular (consulta)
- Se explicaron las opciones para operar el proyecto desde el celular: Remote Control (sesión del PC
  controlada desde la app Claude) y sesiones/rutinas en la nube (claude.ai/code), que requieren
  subir el proyecto a un repositorio privado de GitHub. Aún no se aplica nada.
- Detectado: la tarea "Registrar mercado" no corrió el 23-09 a las 18:00 (1 ejecución perdida).

### 2026-09-23 (4) — Primera ejecución de los agentes (precios del cierre 21-09-2026)
- **Trader**: compró AAPL 7,3 a 339,15 (stop 329,50 / objetivo 358,45) y NVDA 9,4 a 227,49
  (stop 216,90 / objetivo 248,67). Efectivo US$ 5.385,77; riesgo abierto US$ 170 (1,7 %).
  Vigila MSFT (>518) y GOOGL (>360). Verificación: 2026-11-02.
- **Inversionista**: SPY 50 %, BRK-B 12 %, QQQ 10 %, MSFT 7 %, GOOGL 6 %, AAPL 5 %, AMZN 4 %,
  efectivo 6 %. Excluye NVDA, TSLA y META por volatilidad. Rango a 12 meses: US$ 8.986 –
  10.544 – 12.373 (verificación 2027-09-21). Aporte de US$ 500 desde octubre 2026.
- Reportes en `informacion/reportes/2026-09-23-*.md`. Totales verificados (US$ 10.000 cada una).

### 2026-09-23 (3) — Registro de mercado automático
- Tarea de Windows **"InversionesBolsa - Registrar mercado"**: todos los días a las 18:00
  (hora del PC) corre `node tool\registrar_mercado.mjs`. Si el PC estaba apagado, se ejecuta al
  encenderlo; requiere internet. Probada: resultado 0. Para verla o desactivarla: Programador de
  tareas de Windows.
- Hook de pedidos: ahora ignora los avisos del sistema (`<task-notification>`), que se estaban
  registrando como si fueran pedidos.

### 2026-09-23 (2) — Mercado, agentes y carteras
- **Registro de mercado**: nuevo `tool/registrar_mercado.mjs` + `informacion/mercado_config.json`.
  Primera descarga: 5 años diarios (1.253 días) de SPY, QQQ, AAPL, MSFT, NVDA, AMZN, GOOGL, META,
  TSLA, BRK-B y dólar USDCLP en `informacion/historicos/`, con `resumen.md`/`resumen.json`
  (MM20/50/200, RSI14, volatilidad, caída máxima, rendimientos). Último cierre: 21-09-2026
  (Yahoo aún no publicaba el cierre del 22; se completa en la próxima ejecución).
- **Agentes** (Claude Code, `.claude/agents/`): `trader` (corto plazo) e `inversionista`
  (minoritario, largo plazo). Documentados en `informacion/AGENTES.md`.
- **Carteras** simuladas: `informacion/carteras/trader.json` e `inversionista.json`
  (US$ 10.000 cada una; el Inversionista aporta US$ 500/mes). Aún sin operaciones.
- **Prompt**: nueva Fase 6 "Carteras" (varias cuentas con estrategias distintas, atribución
  por prefijo de `client_order_id`, comparación contra SPY); Claude en la app pasa a Fase 7.
- **Registro automático de pedidos**: hook `UserPromptSubmit` en `~/.claude/settings.json` que
  ejecuta `tool/hooks/registrar_prompt.mjs` y escribe en `informacion/registro_prompts.md`.

### 2026-09-23 (1)
- Idioma de Claude Code configurado en español (Chile) (`~/.claude/settings.json`).
- Creado `informacion/PROMPT_MEJORAS.md` con el plan de mejoras por fases.
- Actualizado el prompt con una fase completa de Firebase (Fase 2).
- Creados `informacion/BITACORA.md` y `CLAUDE.md` (memoria del proyecto).
- No se ha modificado código de la app todavía.

## Decisiones

### 2026-09-24
- El repositorio vive solo en **GitHub** (privado). No se usa GitLab: Claude Code en la nube y
  en el celular solo trabaja con GitHub.

### 2026-09-23 (2)
- "Cuentas agrupadas" se llamarán **Carteras**: cada una con capital, posiciones, ganancia y
  estrategia propias; pueden ser simuladas o reales.
- Los agentes operan **solo carteras simuladas** y nunca envían órdenes. Pasar a dinero real
  requiere confirmación explícita y huella/PIN en cada orden.
- Fuente de datos en el PC: Yahoo Finance (sin API key). Stooq se descartó: bloquea descargas
  automáticas. Alpaca será la fuente principal cuando exista la función de Firebase.
- Simulación: precio = último cierre ± 0,05 % de costo.

### 2026-09-23 (1)
- La memoria del proyecto vive en `CLAUDE.md` (se carga automáticamente) + esta bitácora.
- El historial de mercado se guardará en Firestore mediante una función programada, no en el
  teléfono, para que se registre aunque el celular esté apagado.
- El servidor solo usará claves Alpaca paper para leer datos; nunca envía órdenes. Las claves
  de la cuenta real quedan solo en el teléfono.
- Claude en la app: pendiente elegir entre Vertex AI (sin API key, factura Google Cloud) y
  API de Anthropic (key en Secret Manager). **Actualización 2026-09-24:** por ahora se usa
  Gemini con el plan gratuito (clave del usuario en el teléfono); se puede cambiar de motor
  editando solo `lib/services/ai_service.dart`.

## Problemas conocidos

- **Signo de moneda al final** (`1.234,56 US$`): `lib/utils/formatters.dart` usa
  `NumberFormat.currency(locale: 'es_CL')`, que pone el símbolo al final.
- **"Hoy ganaste" igual al total**: `AccountInfo.dayChange = equity - lastEquity`
  (`lib/models/account_info.dart`). Si `last_equity` es 0 el resultado es todo el patrimonio,
  y los depósitos del día se cuentan como ganancia. Afecta Inicio, Portafolio, resumen diario
  (`automation_runner.dart`) y widget de inicio.
- El CSP de `firebase.json` solo permite Alpaca y mindicador; hay que ampliarlo al integrar
  Firebase en la web.
