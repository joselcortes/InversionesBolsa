# Inversiones (Flutter + Alpaca + Firebase)

App para seguir y operar acciones de EE.UU. con Alpaca (paper o real), para un inversionista en
Chile. Android + versión web en Firebase Hosting. Ver `README.md` para las funciones.

## Antes de trabajar

1. Lee `informacion/BITACORA.md` (plan, cambios, decisiones, problemas conocidos).
2. El plan de mejoras por fases está en `informacion/PROMPT_MEJORAS.md`.
3. Si existen, revisa los reportes más recientes en `informacion/reportes/` y los datos en
   `informacion/historicos/`.

4. Agentes y carteras: `informacion/AGENTES.md`. Datos de mercado: `node tool/registrar_mercado.mjs`
   → `informacion/historicos/`.
5. Los pedidos del usuario quedan en `informacion/registro_prompts.md` (hook automático).

Después de cada pedido del usuario, agrega una entrada con fecha en `informacion/BITACORA.md` (qué se hizo, archivos,
decisiones) y actualiza la lista de pendientes.

## Sesiones desde el celular o la nube (claude.ai/code)

Configuración completa (GitHub, celular, rutina, publicación): `informacion/CONFIGURACION.md`.

- El repo en GitHub (`joselcortes/InversionesBolsa`, privado) es la fuente de verdad. Al empezar,
  `git pull`; al terminar, commit y push para que el PC y las demás sesiones lo vean.
- Si el push a `main` es rechazado, sube a la rama de la sesión (ej. `claude/...`) y abre un pull
  request hacia `main`. No generes archivos .patch ni .zip como alternativa.
- Lo que el usuario pide queda en `informacion/registro_prompts.md` (hook del proyecto): inclúyelo
  en el commit.
- En la nube Yahoo Finance responde HTTP 403: `registrar_mercado.mjs` no descarga; usa los
  históricos ya guardados e indica su fecha.
- Publicar la app (`tool/publicar.dart`) solo se puede en el PC: necesita Flutter, la llave de
  firma (fuera del repo) y Firebase CLI. Desde la nube, deja los cambios en `main` y anota en la
  bitácora que falta publicar.
- Rutina diaria en la nube "Inversiones – mercado y carteras" (lun-vie 22:00 UTC).

## Estructura

`lib/models` (datos), `lib/services` (Alpaca REST/WebSocket, almacenamiento, notificaciones,
tareas en segundo plano), `lib/utils` (indicadores, alertas, cálculo tributario, formatos),
`lib/providers` (estado), `lib/screens` y `lib/widgets` (UI), `tool/` (scripts).

## Comandos

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Publicar web: `.\publicar_web.ps1 -Proyecto <id>` (nunca publicar sin OK del usuario).

## Reglas

- Todo en español (Chile). Montos con el signo antes: `US$ 1.234,56`, `$ 1.234.567`.
- Nunca enviar órdenes reales sin huella/PIN; Claude o el servidor nunca ejecutan órdenes.
- Claves y credenciales nunca en el código ni en el repo.
- Estimaciones siempre como rango y con el aviso "Referencial, no es asesoría financiera".
