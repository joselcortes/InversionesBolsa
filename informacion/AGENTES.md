# Agentes y carteras

Cada agente maneja su propia **cartera** (una cuenta separada con su capital, sus posiciones y
su ganancia), para comparar distintas formas de invertir con los mismos datos.

## Los agentes

| Nombre | Archivo del agente | Cartera | Qué hace |
|---|---|---|---|
| **Trader** | `.claude/agents/trader.md` | `carteras/trader.json` | Corto plazo (2 días a 6 semanas). Análisis técnico y momentum, stop-loss obligatorio, arriesga máx. 1 % por operación, beneficio/riesgo ≥ 2:1. |
| **Inversionista** | `.claude/agents/inversionista.md` | `carteras/inversionista.json` | Inversionista minoritario de largo plazo (3+ años). ETF amplios + empresas de calidad, aporte mensual (DCA), rebalanceo, considera dólar e impuestos en Chile. |
| **Mi cartera** | — | Cuenta Alpaca real/paper (en la app) | Tus propias decisiones, para compararlas con los agentes. |

Cómo usarlos: abre Claude Code en la carpeta `InversionesBolsa` y pide, por ejemplo,
"usa el agente trader para revisar su cartera" o "que el inversionista haga su revisión mensual".

## Reglas comunes (ambos agentes)

1. **Nunca envían órdenes reales.** Sus carteras son simuladas. Si quieres copiar una decisión en
   tu cuenta, lo haces tú desde la app con huella/PIN.
2. **Precio de ejecución simulado**: el último cierre disponible en `historicos/` más **0,05 %**
   de costo (spread/deslizamiento) al comprar y menos 0,05 % al vender. Se permiten fracciones.
3. Solo operan símbolos con datos en `historicos/`. Para agregar uno: sumarlo en
   `mercado_config.json` y correr `node tool/registrar_mercado.mjs`.
4. **Toda decisión lleva números**: precio, cantidad, monto, stop/objetivo si aplica, y el porqué.
5. **Toda estimación se verifica**: se guarda con rango (pesimista/base/optimista), probabilidad y
   fecha de verificación. Al vencer, se registra lo que realmente pasó y si acertó.
6. En cada ejecución se agrega el valor de la cartera a `historial_valor` (fecha, valor, valor de
   SPY el mismo día) para medir el rendimiento contra SPY.
7. Todo es **referencial, no es asesoría financiera**.

## Formato de las carteras (`carteras/*.json`)

- `capital_inicial`, `aporte_mensual`, `fecha_inicio` (se completa en la primera ejecución), `efectivo`.
- `posiciones`: `{ simbolo, cantidad, precio_promedio, fecha_entrada, stop, objetivo }`.
- `operaciones`: `{ fecha, tipo (compra/venta/aporte), simbolo, cantidad, precio, monto, motivo }`.
- `estimaciones`: `{ fecha, simbolo, horizonte, rango: {pesimista, base, optimista}, probabilidad,
  fecha_verificacion, resultado_real, acierto }`.
- `historial_valor`: `{ fecha, valor, spy }`.

## Registro de mercado

- Script: `tool/registrar_mercado.mjs` · Símbolos: `mercado_config.json`.
- Datos: `historicos/<SIMBOLO>.csv` (diario, 5 años) + `historicos/resumen.md` / `resumen.json`
  (indicadores) + `historicos/registro_descargas.log`.
- Fuente: Yahoo Finance (no oficial, referencial). Más adelante: función de Firebase con Alpaca.
