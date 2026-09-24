# Inversionista: reporte 2026-09-23 (primera ejecución)

> Cartera simulada. No se envió ninguna orden real. Referencial, no es asesoría financiera.

**Fecha de las operaciones: 2026-09-21**, el último cierre real disponible en `historicos/`. La ejecución se hizo el 2026-09-23 sin volver a descargar datos, porque otro agente estaba corriendo el script en paralelo. Precio simulado = cierre +0,05 %.

## 1. Estado de la cartera

| Símbolo | Peso objetivo | Cantidad | Precio (cierre +0,05 %) | Monto US$ |
|---|---|---|---|---|
| SPY | 50 % | 6,460893 | 773,8868 | 5.000,00 |
| QQQ | 10 % | 1,347998 | 741,8407 | 1.000,00 |
| BRK-B | 12 % | 2,389196 | 502,2610 | 1.200,00 |
| MSFT | 7 % | 1,394809 | 501,8608 | 700,00 |
| GOOGL | 6 % | 1,689439 | 355,1475 | 600,00 |
| AAPL | 5 % | 1,474276 | 339,1495 | 500,00 |
| AMZN | 4 % | 1,546915 | 258,5792 | 400,00 |
| Efectivo | 6 % | | | 600,00 |

- Invertido: US$ 9.400,00. Efectivo: US$ 600,00.
- Valor a precio de cierre: **US$ 9.995,30**. Los US$ 4,70 que faltan corresponden al costo simulado.
- SPY al inicio: 773,50. USDCLP: 947,47, así que la cartera equivale a unos $9,47 millones CLP.
- Próximo aporte: US$ 500 en la primera ejecución de octubre de 2026.

## 2. Lectura del mercado de largo plazo (datos de 5 años, 2021-09 a 2026-09)

| Símbolo | Rend. anual 5a | Rend. anual 3a | Vol. anual | Caída máx. 5a | Beta vs SPY | % sobre SMA200 |
|---|---|---|---|---|---|---|
| SPY | 13,3 % | 23,0 % | 17,2 % | -24,5 % (2022) | 1,00 | +8,5 % |
| QQQ | 15,4 % | 28,2 % | 23,0 % | -35,1 % | 1,27 | +12,1 % |
| AAPL | 18,8 % | 25,5 % | 28,0 % | -33,4 % | 1,17 | +18,4 % |
| MSFT | 11,8 % | 17,1 % | 28,1 % | -37,1 % | 1,13 | +16,6 % |
| GOOGL | 20,5 % | 40,0 % | 32,1 % | -44,3 % | 1,25 | +5,2 % |
| AMZN | 8,6 % | 26,0 % | 36,4 % | -55,7 % | 1,50 | +7,5 % |
| META | 16,7 % | 36,3 % | 45,7 % | -74,9 % | 1,60 | +18,9 % |
| NVDA | 59,1 % | 77,1 % | 51,6 % | -66,3 % | 2,13 | +14,7 % |
| TSLA | 8,4 % | 13,6 % | 59,8 % | -73,6 % | 2,03 | -5,5 % |
| BRK-B | 12,6 % | 11,4 % | 17,2 % | -26,6 % | 0,58 | +1,9 % |

- **Valoración por tendencia.** El mercado está caro frente a su propia tendencia. SPY rindió un 23 % anual en los últimos 3 años, contra un 13,3 % en 5 años. Está un 8,5 % sobre su SMA200 y a menos del 1 % de su máximo de 52 semanas (777,88). Las alzas recientes se concentraron en megacaps: AAPL subió 43 % en un año, y AAPL y META están unos 18 % sobre su SMA200. No es una señal de venta, pero sí una razón para esperar retornos futuros más bajos que los recientes. Por eso uso un 7 % anual como escenario base.
- **Riesgos.** En 2022 SPY cayó un 24,5 % y QQQ un 35 %; META, NVDA y TSLA llegaron a caer entre 66 y 75 %. Una corrección del 20-25 % en los próximos 12-24 meses es plausible y la cartera tiene que poder resistirla sin vender.
- **Concentración en tecnología.** Las tecnológicas se mueven juntas. QQQ tiene una correlación de 0,95 con SPY, y las megacaps tienen correlaciones de 0,44 a 0,79 con QQQ. Comprar QQQ o varias tecnológicas encima de SPY suma poca diversificación y más volatilidad. BRK-B es el mejor diversificador disponible: correlación de 0,58 con SPY y de 0,23 a 0,44 con las tecnológicas, con beta 0,58.
- **Dólar (USDCLP).** Está en 947, dentro de un rango de 5 años entre 778 y 1.050, y un año atrás estaba en 955. La correlación semanal entre SPY y USDCLP es de -0,30: cuando la bolsa cae, el dólar tiende a subir, lo que amortigua en pesos las caídas en dólares. En pesos, SPY subió un 125 % en 5 años. Para un inversionista en Chile, tener la cartera en USD es una cobertura natural. No hay que cambiar pesos por dólares de golpe: conviene hacerlo gradualmente, igual que el DCA.

## 3. Justificación de la cartera

- **Un 60 % en ETF amplios** (SPY 50 % y QQQ 10 %), que es el máximo permitido. SPY es la referencia y el núcleo. QQQ se limita al 10 % porque aporta poco frente a SPY y cae más (-35 % contra -24,5 %).
- **Un 34 % en empresas de calidad con historial largo**, cada una muy por debajo del tope del 20 %:
  - BRK-B con 12 %: es la posición individual más grande por su rol defensivo y diversificador.
  - MSFT 7 %, GOOGL 6 %, AAPL 5 % y AMZN 4 %: son empresas de calidad, pero con pesos bajos porque SPY ya contiene mucho de ellas. GOOGL recibe más peso que AAPL porque está menos estirada (+5 % sobre su SMA200 contra +18 %).
- **Excluidas:** NVDA (vol 52 %, caída de -66 %, beta 2,1, y ya está dentro de SPY/QQQ), TSLA (vol 60 %, caída de -74 %, rendimiento de solo 8,4 % anual en 5 años) y META (caída de -75 %, vol 46 %). No cumplen el criterio de bajo riesgo de pérdidas grandes. Su exposición llega indirectamente a través de los ETF.
- **Un 6 % en efectivo** (el mínimo es 5 %) para aprovechar caídas y rebalancear.
- **Backtest de 5 años con estos pesos** (rebalanceo diario, 100 % invertido): rendimiento del 14,5 % anual, volatilidad del 17,0 % y caída máxima de -23,9 %. SPY en el mismo período: 14,0 % anual, volatilidad del 17,2 % y caída de -24,5 %. El riesgo es parecido al de SPY, con algo más de diversificación por BRK-B. Ojo: este backtest se beneficia de haber conocido a los ganadores de antemano.
- **Exposición tecnológica aproximada** (sumando lo que hay dentro de SPY y QQQ más las acciones directas): entre 40 y 45 % de la cartera. Es algo más que SPY solo, que tiene alrededor de un tercio. Es un riesgo aceptado pero vigilado.

## 4. Estimaciones (a verificar)

Estas estimaciones son para el valor de la cartera **sin contar aportes futuros**, partiendo de US$ 10.000. La base supone un 7 % anual. El rango pesimista-optimista es de ±1 desviación estándar con una volatilidad del 16 % (17 % × 94 % invertido), así que la probabilidad de quedar dentro del rango es de alrededor del 68 %.

| Horizonte | Verificación | Pesimista | Base | Optimista |
|---|---|---|---|---|
| 3 meses | 2026-12-21 | 9.355 | 10.133 | 10.977 |
| 6 meses | 2027-03-22 | 9.171 | 10.269 | 11.498 |
| 12 meses | 2027-09-21 | 8.986 | 10.544 | 12.373 |

- Escenario de estrés a 12 meses (percentil 5): unos US$ 8.100 (-19 %).
- **Comparación esperada con SPY a 12 meses:** base de unos 817, en un rango de 688 a 971 (±1σ con vol 17,2 %). Espero un rendimiento parecido a SPY, entre 0,5 y 1 punto por debajo en un año alcista por el 6 % en efectivo, y algo mejor en las caídas por BRK-B y el efectivo. Para evaluar, cada aporte se medirá contra una compra equivalente de SPY.

## 5. Reglas para las próximas ejecuciones

- Aporte de US$ 500 en la primera ejecución de cada mes, destinado a las posiciones que estén más bajo su peso objetivo.
- Rebalanceo solo si una posición se desvía más de 5 puntos de su peso objetivo. De preferencia se hará con aportes y no con ventas, para no generar impuesto a la ganancia de capital en Chile.
- No vender por caídas de mercado. Si SPY cae más de 15 %, se usa el efectivo por sobre el 5 %.

## 6. Lecciones

- Es la primera ejecución y todavía no hay estimaciones anteriores que verificar.
- El dato de USDCLP incluye fines de semana (1.299 filas contra 1.253 de las acciones). Para las correlaciones se alinearon las fechas.
