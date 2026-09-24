# Inversionista: reporte 2026-09-24 — revisión diaria (cierre real usado: 2026-09-23)

> Cartera simulada. No se envió ninguna orden real. Referencial, no es asesoría financiera.

**Fecha del cierre usado: 2026-09-23** (el más reciente real disponible; el mercado del 24-sep aún no cerraba al momento de esta revisión). Intenté correr `node tool/registrar_mercado.mjs` para verificar si había datos más nuevos, pero Yahoo Finance devolvió error HTTP 403 para todos los símbolos desde este entorno (bloqueo de red, no de datos). Se usaron los datos del 23-sep ya cargados en `informacion/historicos/resumen.json`, subidos previamente por el usuario y confirmados como reales.

## 1. Contexto del día: caída generalizada

El 23-sep el mercado cayó en general:

| Símbolo | Cierre | Variación del día |
|---|---|---|
| SPY | 767,81 | -0,72 % |
| QQQ | 741,21 | -0,84 % |
| BRK-B | 507,17 | +0,73 % |
| MSFT | 500,59 | +0,52 % |
| GOOGL | 337,83 | **-3,80 %** |
| AAPL | 337,02 | -0,80 % |
| AMZN | 249,27 | -2,24 % |
| USDCLP | 960,98 | +1,50 % |

RSI14 de SPY: 53,0 (zona neutra, sin señal de sobrecompra ni sobreventa). BRK-B y MSFT subieron, amortiguando parte de la caída de las demás posiciones: exactamente el rol defensivo/diversificador para el que se compró BRK-B.

## 2. Valorización de la cartera al cierre del 23-sep

| Símbolo | Cantidad | Precio | Valor US$ | Peso real | Peso objetivo | Desviación |
|---|---|---|---|---|---|---|
| SPY | 6,460893 | 767,81 | 4.960,74 | 49,99 % | 50 % | -0,01 pp |
| QQQ | 1,347998 | 741,21 | 999,15 | 10,07 % | 10 % | +0,07 pp |
| BRK-B | 2,389196 | 507,17 | 1.211,73 | 12,21 % | 12 % | +0,21 pp |
| MSFT | 1,394809 | 500,59 | 698,23 | 7,04 % | 7 % | +0,04 pp |
| GOOGL | 1,689439 | 337,83 | 570,74 | 5,75 % | 6 % | -0,25 pp |
| AAPL | 1,474276 | 337,02 | 496,86 | 5,01 % | 5 % | +0,01 pp |
| AMZN | 1,546915 | 249,27 | 385,60 | 3,89 % | 4 % | -0,11 pp |
| Efectivo | | | 600,00 | 6,05 % | 6 % | +0,05 pp |
| **Total** | | | **9.923,05** | 100 % | 100 % | |

- Valor de la cartera: **US$ 9.923,05** (equivalente a unos **$ 9.535.400 CLP** con USDCLP 960,98).
- Aportes acumulados: US$ 10.000,00 (capital inicial; sin aportes nuevos aún).
- Rendimiento desde el inicio (21-sep, valor 9.995,30 a precio de cierre): **-0,72 %**.

## 3. Comparación vs SPY (desde el inicio, 21-sep)

| Fecha | Valor cartera | SPY | Var. cartera | Var. SPY |
|---|---|---|---|---|
| 2026-09-21 | 9.995,30 | 773,50 | — | — |
| 2026-09-22 | 9.990,43 | 773,38 | -0,05 % | -0,02 % |
| 2026-09-23 | 9.923,05 | 767,81 | -0,72 % | -0,74 % |

- Variación acumulada de la cartera desde el 21-sep: **-0,723 %**.
- Variación acumulada de SPY en el mismo período: **-0,736 %**.
- La cartera quedó **0,01 puntos porcentuales por encima de SPY** en estos tres días, principalmente porque BRK-B y MSFT subieron mientras SPY y las demás tecnológicas cayeron. Es una diferencia mínima y sin ningún significado estadístico a 3 días; se sigue esperando un comportamiento muy parecido a SPY en el largo plazo, con algo menos de caída en correcciones fuertes.

## 4. Análisis de la caída de GOOGL (-3,80 %) y verificación de umbral de rebalanceo

GOOGL fue la posición más golpeada del día, con una caída de casi 4 veces la de SPY. Esto bajó su peso real de 6 % (objetivo) a 5,75 %, es decir, una desviación de solo **-0,25 puntos porcentuales**, muy por debajo del umbral de 5 puntos que gatilla rebalanceo según las reglas de la cartera.

**Ninguna posición se desvió más de 5 puntos porcentuales de su peso objetivo.** La mayor desviación absoluta fue la de GOOGL con -0,25 pp, seguida de BRK-B con +0,21 pp. Todas las demás están dentro de ±0,11 pp. No corresponde ningún rebalanceo hoy.

Respecto al fundamento de la caída: no hay ningún hecho nuevo conocido que cambie la tesis de inversión en GOOGL (fue comprada por ser una empresa de calidad con valoración menos exigente que el resto del grupo, un 5,2 % sobre su SMA200 al momento de la compra). Una caída de un solo día, sin noticia estructural asociada, es ruido de corto plazo y no es motivo de venta para una cartera con horizonte de 3 años o más. Se mantiene la posición sin cambios.

## 5. Aporte mensual: no corresponde hoy

El primer aporte mensual de US$ 500 está programado para la **primera ejecución de octubre de 2026**, no para septiembre. Hoy 24-sep de 2026 no corresponde ningún aporte. Se mantiene el efectivo en US$ 600,00 (6,05 % de la cartera), por sobre el mínimo del 5 % exigido.

## 6. Decisión de hoy: sin cambios

- No se realizó ninguna compra ni venta.
- No se modificaron cantidades de posiciones ni el efectivo.
- Se actualizó únicamente `historial_valor` en `informacion/carteras/inversionista.json` con el punto del 23-sep (valor 9.923,05, SPY 767,81, USDCLP 960,98) y se refrescó el campo `pesos_reales` con los pesos calculados arriba.
- Justificación: ninguna posición supera el umbral de 5 pp de desviación, no corresponde aporte (es de octubre), y la caída de GOOGL de un día no constituye un cambio en la tesis de inversión ni una razón para vender.

## 7. Estimaciones vigentes (sin cambios, aún no vencen)

Las estimaciones a 3, 6 y 12 meses registradas el 2026-09-21 siguen vigentes y no han vencido (la más próxima vence el 2026-12-21). No se generan nuevas estimaciones hoy; se mantienen las de la última ejecución:

| Horizonte | Verificación | Pesimista | Base | Optimista |
|---|---|---|---|---|
| 3 meses | 2026-12-21 | 9.355 | 10.133 | 10.977 |
| 6 meses | 2027-03-22 | 9.171 | 10.269 | 11.498 |
| 12 meses | 2027-09-21 | 8.986 | 10.544 | 12.373 |

Con el valor actual de US$ 9.923,05, la cartera sigue dentro del rango pesimista-optimista de las tres estimaciones.

## 8. Lecciones

- El script `registrar_mercado.mjs` volvió a fallar con HTTP 403 en este entorno; se confirmó que los datos del 23-sep ya cargados por el usuario son consistentes y se usaron sin problemas. Conviene seguir dependiendo de la carga manual del usuario cuando el entorno de ejecución no tiene salida a Yahoo Finance.
- Una caída de un día en una sola posición (GOOGL -3,80 %) mueve su peso real menos de 0,3 puntos porcentuales sobre una cartera diversificada; confirma que el umbral de 5 pp para rebalanceo es razonable y no se gatilla por movimientos normales de mercado.

---
*Referencial, no es asesoría financiera.*
