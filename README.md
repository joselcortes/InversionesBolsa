# Inversiones (Flutter + Alpaca)

App para seguir y operar acciones de EE.UU. con tu cuenta de [Alpaca](https://alpaca.markets)
(modo paper o real). Pensada para inversionistas en Chile.

## Funciones

**Mercado y datos**
- Precios en tiempo real por WebSocket (feed IEX gratuito, máx. 30 símbolos) y auto-refresco.
- Estado del mercado (abierto/cerrado, cuánto falta para abrir o cerrar, en hora de Chile).
- Buscador de acciones por símbolo o nombre de empresa; la lista de seguimiento se guarda, se
  reordena y se quitan acciones deslizando (con "Deshacer").
- Detalle: gráficos 1D/1S/1M/3M/1A/5A (línea, área, velas, barras) con volumen y medias móviles,
  estadísticas del día, bid/ask, máx./mín. de 52 semanas, MM20/50/200, RSI(14) y volatilidad.
- Noticias generales o solo de tus acciones, priorizando coberturas de analistas.

**Operar**
- Órdenes a mercado o límite, por cantidad de acciones o por monto en US$ (fraccionadas).
- Validaciones: no vender más de lo disponible y no pasarse del poder de compra.
- Stop-loss/take-profit al comprar (bracket u OTO) y protección de posiciones existentes:
  stop-loss, trailing stop (%) u OCO.
- Cancelar órdenes abiertas (incluidas las patas de un bracket).
- Huella/PIN antes de cada orden. En modo real, si el teléfono no tiene bloqueo configurado o
  la autenticación falla, la orden **no** se envía.

**Automatización** (Android, cada ~15 min con Workmanager, aunque la app esté cerrada)
- Alertas: precio, % de variación diaria, volumen inusual y cruce de media móvil; de un solo uso
  o repetibles (máx. una vez al día).
- Notificaciones de órdenes ejecutadas, canceladas o rechazadas (en vivo con la app abierta).
- Compras periódicas (DCA) semanales o mensuales por monto en US$, con `client_order_id`
  para evitar compras duplicadas.
- Resumen diario al cierre del mercado.
- Widget de pantalla de inicio con el valor del portafolio.

**Portafolio y reportes**
- Evolución del patrimonio (1D a 5 años), distribución por acción con aviso de concentración,
  ganancia no realizada total y por posición.
- Montos también en pesos (dólar observado vía mindicador.cl).
- Historial de movimientos (compras, ventas, dividendos, retenciones, depósitos).
- Reporte referencial para el SII: ganancias de capital (FIFO) y dividendos en US$ y CLP con el
  dólar observado de cada fecha, exportable a CSV.

**Privacidad**
- API keys cifradas en el Keystore/Keychain; bloqueo de la app con huella; ocultar saldos;
  `FLAG_SECURE` contra capturas de pantalla. Tema claro, oscuro o del sistema.

## Versión web (usarla desde cualquier computador o celular)

La app también funciona en el navegador, publicada en Firebase Hosting (Google Cloud).
No hay servidor propio: el navegador habla directo con Alpaca, y las claves quedan solo en
ese navegador.

- App web: https://inversiones-cl-34686.web.app/
- Mi tienda (descargas y actualizaciones de Android): https://inversiones-cl-34686.web.app/tienda/

### Publicar una versión nueva

1. Sube la versión en `pubspec.yaml` (el número después del `+` debe aumentar siempre).
2. Ejecuta:

```powershell
dart run tool/publicar.dart --notas "Novedad 1|Novedad 2"
dart run tool/publicar.dart --solo-web    # solo web/tienda, sin APK nuevo
```

El script revisa el código, corre los tests, compila el APK firmado, lo sube a GitHub Releases
(`joselcortes/inversiones-tienda`, porque el plan gratuito de Firebase no permite archivos .apk),
agrega la versión con su SHA-256 a `releases/apps.json`, compila la web y publica en Firebase.
Requiere haber iniciado sesión una vez con `firebase login` y `gh auth login`.
La app instalada detecta la versión nueva al abrirse y la ofrece en **Más → Mi tienda**.

### Llave de firma (¡respáldala!)

Las versiones se firman con `%USERPROFILE%\claves-android\inversiones-release.jks`; la
contraseña está en `inversiones-release.properties` (misma carpeta). Si se pierde, Android no
permitirá actualizar la app instalada: habría que desinstalarla y perder sus datos locales.
Guarda una copia de **ambos archivos** fuera de este computador (pendrive, gestor de contraseñas).

Para probarla localmente con los mismos encabezados de seguridad que en producción:
`flutter build web --release --no-web-resources-cdn` y luego `node tool/serve_web.mjs`.

Limitaciones de la web: no hay huella, así que **no permite órdenes con dinero real** (solo
modo práctica o para mirar), y las alertas, avisos y compras automáticas funcionan solo con
la página abierta.

## Desarrollo

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Estructura: `lib/models` (datos), `lib/services` (Alpaca REST/WebSocket, almacenamiento,
notificaciones, tareas en segundo plano), `lib/utils` (indicadores, motor de alertas, cálculo
tributario, formatos), `lib/providers` (estado), `lib/screens` y `lib/widgets` (UI).

> Los indicadores y el reporte tributario son referenciales, no asesoría financiera ni tributaria.
