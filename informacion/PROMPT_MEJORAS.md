# Prompt: mejoras a la app Inversiones (Flutter + Alpaca + Firebase)

## Contexto

Estoy trabajando en mi app "Inversiones" (Flutter, Alpaca API, versión web en Firebase Hosting).
Soy inversionista en Chile y uso la app para seguir y operar acciones de EE.UU. Lee `README.md`
para ver lo que ya existe antes de proponer nada.

Objetivo general: que la app me ayude a **tomar la mejor decisión posible con números reales**,
que **aprenda de su propio historial** y que pueda **usar Claude desde el celular** dentro de la app.

Trabaja por fases, en orden. Al terminar cada fase: corre `flutter analyze` y `flutter test`,
actualiza la bitácora (Fase 0) y muéstrame un resumen antes de seguir con la siguiente.

### Datos de mi proyecto Firebase (completar antes de ejecutar)

- ID del proyecto: `<ID_DEL_PROYECTO>`
- Plan: `<Spark o Blaze>` (Cloud Functions, Cloud Scheduler y Secret Manager **requieren Blaze**)
- Región de datos y funciones: `southamerica-west1` (Santiago), salvo que haya una razón para otra
- Cuenta de Google con la que entro a la app: `<mi correo>`

---

## Fase 0 — Memoria del proyecto (hacer primero)

Quiero que Claude recuerde el proyecto entre sesiones.

1. Crea `CLAUDE.md` en la raíz del proyecto (Claude Code lo lee automáticamente cada vez que
   se abre en esta carpeta). Debe incluir:
   - Resumen de la app, arquitectura (`lib/models`, `services`, `providers`, `screens`, `utils`,
     `functions/`) y comandos (`flutter analyze`, `flutter test`, emuladores y despliegue).
   - Convenciones: idioma español (Chile), formato de montos, reglas de seguridad (no enviar
     órdenes reales sin huella, claves nunca en el código ni en el repo).
   - La instrucción: **"Antes de trabajar, lee `informacion/BITACORA.md` y los reportes más
     recientes de `informacion/reportes/`; al terminar, agrega una entrada a la bitácora."**
2. Crea `informacion/BITACORA.md` con estas secciones, siempre de lo más reciente a lo más antiguo:
   - **Plan / pendientes** (checklist).
   - **Registro de cambios** (fecha, qué se hizo, archivos tocados, por qué).
   - **Decisiones** (qué se eligió y qué se descartó, con la razón).
   - **Problemas conocidos**.

## Fase 1 — Corrección de errores (rápido, alta prioridad)

1. **Signo de moneda antes del número.** `lib/utils/formatters.dart` usa
   `NumberFormat.currency(locale: 'es_CL')`, que pone el símbolo al final (`1.234,56 US$`).
   Todos los montos deben quedar como `US$ 1.234,56` y `$ 1.234.567` (CLP sin decimales),
   incluidos los negativos (`-US$ 12,30`). Corrígelo en el formateador y revisa pantallas,
   notificaciones, widget de inicio y CSV. Agrega tests del formato.
2. **"Hoy ganaste" muestra lo mismo que "Mi dinero".** `AccountInfo.dayChange` se calcula como
   `equity - lastEquity`. Cuando `last_equity` viene en 0 (cuenta nueva o primer día con fondos)
   el "ganaste" es igual al total; además un **depósito** del día se cuenta como ganancia:
   - Si `lastEquity` es 0 o no es confiable, mostrar "Sin datos de ayer" en vez de un monto.
   - Restar los depósitos/retiros del día (actividades `CSD`/`CSW` de Alpaca), de modo que
     la ganancia del día sea **solo por variación de precios**.
   - Aplicarlo también al resumen diario (`automation_runner.dart`) y al widget de inicio.
   - Tests unitarios: cuenta nueva, día con depósito, día normal con ganancia y con pérdida.

## Fase 2 — Infraestructura en Firebase

Esta fase es la base de las Fases 3 a 7. Antes de escribir código, muéstrame qué servicios vas a
activar, el costo mensual estimado y qué tengo que hacer yo en la consola.

### 2.1 Configuración

- Crear `.firebaserc` con mi ID de proyecto y correr `flutterfire configure` para Android y web
  (genera `lib/firebase_options.dart`).
- Agregar paquetes: `firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`,
  `firebase_app_check`.
- Carpeta `functions/` en **TypeScript** (Cloud Functions 2ª generación, Node LTS), con
  `firestore.rules`, `firestore.indexes.json` y la configuración de emuladores en `firebase.json`.
- Actualizar `publicar_web.ps1` (o crear `desplegar.ps1`) para publicar hosting, reglas y
  funciones, con un parámetro para elegir qué publicar.
- Crear una **alerta de presupuesto** en Google Cloud (ej. US$ 10/mes) y decirme cómo hacerlo.

### 2.2 Acceso y seguridad

- **Firebase Auth con Google.** La app es solo para mí: permitir únicamente mi UID
  (lista blanca en las reglas de Firestore y en cada función). Cualquier otra cuenta ve
  "Acceso no autorizado".
- **App Check**: Play Integrity en Android y reCAPTCHA Enterprise en web; las funciones lo exigen.
- **Secret Manager** para las claves del servidor. Las claves de Alpaca que use el servidor deben
  ser de una cuenta **paper y solo para leer datos de mercado**; las claves de la cuenta real
  siguen solo en el teléfono (Keystore) y el servidor **nunca** envía órdenes.
- Actualizar el `Content-Security-Policy` de `firebase.json` (`connect-src`) para permitir los
  dominios de Firebase que se usen (Firestore, Auth, Functions, App Check), sin abrir nada más.
- Ningún archivo de credenciales (`service-account*.json`, `.env`) en el repo: agregarlos a
  `.gitignore`.

### 2.3 Datos en Firestore

Proponme el esquema antes de implementarlo. Punto de partida:

```
users/{uid}/snapshots/{fecha}        valor del portafolio, efectivo, ganancia del día
users/{uid}/estimaciones/{id}        estimación, datos usados, plazo, resultado real
users/{uid}/chats/{id}/mensajes/{id} conversaciones con Claude
market/{simbolo}/diario/{fecha}      OHLCV + indicadores (MM20/50/200, RSI, volatilidad)
config/{uid}                         lista de seguimiento, perfil de riesgo, límites de uso
```

- Reglas: cada usuario lee/escribe solo lo suyo; `market/*` solo lo escriben las funciones.
- Activar la caché sin conexión de Firestore para que la app funcione sin internet.
- Tests de las reglas con el emulador.

### 2.4 Funciones

| Función | Tipo | Qué hace |
|---|---|---|
| `guardarCierreDiario` | Programada, lun–vie 17:30 hora de Nueva York | Guarda velas diarias e indicadores de mi lista y portafolio en `market/`, y el snapshot del portafolio. Si faltan días, los rellena. |
| `evaluarEstimaciones` | Programada, diaria | Compara las estimaciones vencidas con lo que pasó y guarda el acierto (Fase 5). |
| `preguntarAClaude` | Invocable (callable) | Chat con Claude (Fase 7). |
| `ejecutarAgentes` | Programada, lun–vie después del cierre | Trader e Inversionista revisan sus carteras simuladas (Fase 6). |
| `reporteSemanal` | Programada, sábados | Claude resume la semana (rendimiento, aciertos, riesgos) y lo guarda como reporte. |

Todas con reintentos seguros (si se ejecutan dos veces no duplican datos) y logs claros.

### 2.5 Sincronización con mi PC

- Script `tool/descargar_datos.mjs` (o `.ps1`) que baje desde Firestore a
  `informacion/historicos/` (CSV por símbolo) y a `informacion/reportes/` (Markdown por fecha).
- Así Claude Code, al abrir el proyecto en mi PC, puede leer los mismos datos que la app.
- Explicarme cómo autenticarlo en mi PC sin guardar claves en el proyecto
  (ej. `gcloud auth application-default login`).

## Fase 3 — Historial de mercado propio

- Ya existe una versión en el PC: `tool/registrar_mercado.mjs` guarda 5 años de datos diarios en
  `informacion/historicos/`. Reusar su lógica de indicadores e importar esos datos a Firestore.
- Implementar el guardado con `guardarCierreDiario` (Fase 2.4), no en el teléfono: así se guarda
  aunque el celular esté apagado.
- Primer uso: rellenar hacia atrás con los datos históricos de Alpaca (ej. 5 años) para no
  partir de cero.
- En la app, los gráficos y cálculos usan primero el historial de Firestore y solo piden a
  Alpaca lo que falte.

## Fase 4 — Motor de decisiones con números reales

Para cada acción (y para una compra/venta que esté evaluando) mostrar una ficha con:

- **Resultado real neto**: precio, comisiones, spread bid/ask, tipo de cambio del día
  e impuesto estimado en Chile (reusar la lógica existente del reporte SII).
- **Escenarios con probabilidad**: pesimista / base / optimista a 1 semana, 1 mes y 3 meses,
  calculados con la volatilidad histórica (rangos de 1 y 2 desviaciones estándar o simulación
  Monte Carlo). Siempre como rango, nunca como una cifra única.
- **Riesgo**: pérdida máxima histórica (drawdown), beta vs. S&P 500 (SPY), tamaño de posición
  sugerido según cuánto estoy dispuesto a perder (ej. 1–2 % del capital por operación) y
  relación riesgo/beneficio del stop-loss / take-profit.
- **Comparación contra no hacer nada**: ¿la operación le gana a comprar SPY o a dejar la plata
  en un depósito a plazo en pesos?
- Explicar el porqué de cada señal en lenguaje simple y mostrar las fórmulas usadas.
- Cada ficha se guarda como estimación en `users/{uid}/estimaciones` para verificarla después.

## Fase 5 — Verificación con el tiempo (backtesting y aciertos)

- `evaluarEstimaciones` compara cada estimación vencida con lo que realmente pasó.
- Pantalla "¿Qué tan bien le ha ido al modelo?": % de veces que el precio real cayó dentro del
  rango estimado, error promedio, y comparación contra comprar y mantener SPY.
- Antes de usar una estrategia nueva, probarla con el historial guardado (backtest) y mostrar
  sus resultados, incluyendo comisiones y el peor período.

## Fase 6 — Carteras (varias cuentas con distintas estrategias)

Quiero manejar mi inversión de varias formas a la vez y comparar cuál rinde más. Cada **cartera**
tiene su capital, sus posiciones, su ganancia y su estrategia. Ver `informacion/AGENTES.md`.

- Carteras iniciales: **Mi cartera** (mis decisiones), **Trader** (agente de corto plazo) e
  **Inversionista** (agente de largo plazo). Poder crear más (ej. "Dividendos", "Ahorro casa").
- Tipos: **simulada** (dinero ficticio, precios reales) o **real** (vinculada a Alpaca).
- Varias carteras reales en una sola cuenta Alpaca: marcar cada orden con un prefijo en
  `client_order_id` (ej. `trd-`, `inv-`, `mia-`) y atribuir posiciones, efectivo y ganancias a
  cada cartera. Si Alpaca permite varias cuentas paper, ofrecer vincular una cartera a cada una.
- Firestore: `users/{uid}/carteras/{id}` con operaciones, posiciones, estimaciones e historial de
  valor. Migrar desde los JSON de `informacion/carteras/`.
- Pantalla **Carteras**: lista con valor, ganancia (US$, CLP y %), gráfico comparativo de todas
  contra SPY, ranking, aciertos de las estimaciones, caída máxima y operaciones recientes.
- Ganancia **consolidada** (suma de todas las carteras reales) y por cartera.
- Los agentes corren en el servidor (función programada diaria usando Claude) sobre sus carteras
  simuladas y dejan su reporte. Pasar una cartera de agente a dinero real solo con mi
  confirmación explícita, y cada orden igual se confirma con huella/PIN.

## Fase 7 — Claude dentro de la app (celular y web)

### Cómo conectar Claude (compárame ambas opciones y recomiéndame una)

- **Opción A — Claude en Vertex AI** (dentro de Google Cloud): se habilita el modelo en Model
  Garden, se factura en la misma cuenta de Google Cloud y la función se autentica con su cuenta
  de servicio, **sin API key que guardar**. Verificar en qué región está disponible el modelo.
- **Opción B — API de Anthropic**: API key en Secret Manager, facturación aparte en Anthropic.

### Función `preguntarAClaude`

- Exige usuario autenticado (mi UID) y App Check.
- Arma el contexto **en el servidor** leyendo Firestore: portafolio, órdenes recientes,
  historial de la acción consultada, ficha de decisión (Fase 4) y aciertos previos (Fase 5).
  La app solo envía la pregunta y el símbolo, así no se puede inyectar contexto falso.
- Límite diario de consultas y de gasto (configurable en `config/{uid}`); mostrar el costo
  estimado de cada consulta y el acumulado del mes.
- Guardar cada conversación en `users/{uid}/chats`.
- Usar el modelo Claude más reciente disponible, con respuestas en español (Chile).

### En la app

- Pantalla "Pregúntale a Claude" en Android y web, y un botón "Preguntar a Claude" en el detalle
  de cada acción que abra el chat con esa acción como contexto.
- Claude puede sugerir, pero **nunca ejecutar órdenes**: si propone una operación, abre la hoja
  de orden prellenada y yo confirmo con huella/PIN.
- Toda respuesta con cifras lleva el aviso: "Referencial, no es asesoría financiera".

---

## Reglas generales

- No romper lo que ya funciona; mantener los tests existentes pasando y agregar tests nuevos.
- Probar todo con los **emuladores de Firebase** antes de desplegar; nunca desplegar sin mi OK.
- Todo el texto de la app en español (Chile); montos en US$ y CLP con el signo antes del número.
- Si algo no es posible o tiene un costo (plan Blaze, API pagada, límites del plan gratis de
  Alpaca/IEX), avísame antes de implementarlo y propón una alternativa.
- Si tienes dudas de diseño importantes, pregúntame antes de escribir código.
