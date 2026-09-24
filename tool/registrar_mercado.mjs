// Registra el histórico diario del mercado en informacion/historicos/.
//
// Uso (desde la carpeta del proyecto):
//   node tool/registrar_mercado.mjs
//
// - Lee los símbolos de informacion/mercado_config.json.
// - La primera vez descarga el rango inicial (ej. 5 años); después solo agrega los días nuevos.
// - Guarda un CSV por símbolo y un resumen con indicadores (resumen.json y resumen.md).
// - Fuente: Yahoo Finance (endpoint público no oficial, sin API key). Es referencial; cuando
//   exista la función de Firebase (Fase 2/3 del plan) se usará Alpaca como fuente principal.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const raiz = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const dirInfo = path.join(raiz, 'informacion');
const dirHist = path.join(dirInfo, 'historicos');
const config = JSON.parse(fs.readFileSync(path.join(dirInfo, 'mercado_config.json'), 'utf8'));
fs.mkdirSync(dirHist, { recursive: true });

const COLUMNAS = 'fecha,apertura,maximo,minimo,cierre,cierre_ajustado,volumen';

/** Fecha y hora actuales en Nueva York. */
function ahoraNY() {
  const p = Object.fromEntries(
    new Intl.DateTimeFormat('en-CA', {
      timeZone: 'America/New_York', year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit', hour12: false,
    }).formatToParts(new Date()).map((x) => [x.type, x.value]),
  );
  return { fecha: `${p.year}-${p.month}-${p.day}`, minutos: Number(p.hour) * 60 + Number(p.minute) };
}

function fechaNY(epochSeg) {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'America/New_York' }).format(new Date(epochSeg * 1000));
}

function minutosNY(epochSeg) {
  const [h, m] = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'America/New_York', hour: '2-digit', minute: '2-digit', hour12: false,
  }).format(new Date(epochSeg * 1000)).split(':').map(Number);
  return h * 60 + m;
}

function nombreArchivo(simbolo) {
  return (config.alias?.[simbolo] ?? simbolo).replace(/[^A-Za-z0-9_-]/g, '_') + '.csv';
}

function leerCsv(archivo) {
  if (!fs.existsSync(archivo)) return new Map();
  const filas = fs.readFileSync(archivo, 'utf8').trim().split('\n').slice(1);
  return new Map(filas.filter(Boolean).map((l) => [l.split(',')[0], l]));
}

async function descargar(simbolo, rango) {
  const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(simbolo)}` +
    `?range=${rango}&interval=1d&includeAdjustedClose=true`;
  const res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const json = await res.json();
  const r = json.chart?.result?.[0];
  if (!r?.timestamp) throw new Error(json.chart?.error?.description ?? 'sin datos');
  const q = r.indicators.quote[0];
  const adj = r.indicators.adjclose?.[0]?.adjclose ?? [...q.close];
  // Yahoo suele publicar la última vela con el cierre en null por horas. Si esa sesión ya
  // terminó (regularMarketTime a las 16:00 NY o después), el cierre está en meta.
  const i = r.timestamp.length - 1;
  const m = r.meta;
  if (q.close[i] == null && m.regularMarketPrice != null && m.regularMarketTime &&
      fechaNY(m.regularMarketTime) === fechaNY(r.timestamp[i]) &&
      minutosNY(m.regularMarketTime) >= 16 * 60) {
    q.close[i] = m.regularMarketPrice;
    adj[i] = m.regularMarketPrice;
    q.high[i] ??= m.regularMarketDayHigh;
    q.low[i] ??= m.regularMarketDayLow;
    q.volume[i] ??= m.regularMarketVolume;
  }
  const hoy = ahoraNY();
  const mercadoCerrado = hoy.minutos >= 16 * 60 + 15;
  const filas = [];
  r.timestamp.forEach((t, i) => {
    if (q.close[i] == null) return;
    const fecha = fechaNY(t);
    // La vela de hoy no se guarda hasta que cierre el mercado (sería un dato parcial).
    if (fecha === hoy.fecha && !mercadoCerrado) return;
    const n = (v, d = 4) => (v == null ? '' : Number(v).toFixed(d));
    filas.push([fecha, `${fecha},${n(q.open[i])},${n(q.high[i])},${n(q.low[i])},${n(q.close[i])},` +
      `${n(adj[i])},${q.volume[i] ?? 0}`]);
  });
  return filas;
}

// ---------------------------------------------------------------- indicadores
const media = (a) => a.reduce((s, x) => s + x, 0) / a.length;
const sma = (a, n) => (a.length >= n ? media(a.slice(-n)) : null);
function desv(a) {
  const m = media(a);
  return Math.sqrt(a.reduce((s, x) => s + (x - m) ** 2, 0) / (a.length - 1));
}
function rsi(a, n = 14) {
  if (a.length <= n) return null;
  let g = 0, p = 0;
  for (let i = 1; i <= n; i++) {
    const d = a[i] - a[i - 1];
    d >= 0 ? (g += d) : (p -= d);
  }
  g /= n; p /= n;
  for (let i = n + 1; i < a.length; i++) {
    const d = a[i] - a[i - 1];
    g = (g * (n - 1) + Math.max(d, 0)) / n;
    p = (p * (n - 1) + Math.max(-d, 0)) / n;
  }
  return p === 0 ? 100 : 100 - 100 / (1 + g / p);
}
function volAnual(a, n) {
  const s = a.slice(-(n + 1));
  if (s.length < n + 1) return null;
  const r = s.slice(1).map((x, i) => Math.log(x / s[i]));
  return desv(r) * Math.sqrt(252) * 100;
}
function maxDrawdown(a) {
  let pico = a[0], peor = 0;
  for (const x of a) { pico = Math.max(pico, x); peor = Math.min(peor, x / pico - 1); }
  return peor * 100;
}
const rendimiento = (a, n) => (a.length > n ? (a.at(-1) / a.at(-1 - n) - 1) * 100 : null);

function indicadores(simbolo, filas) {
  const d = filas.map((l) => l.split(','));
  const cierre = d.map((x) => Number(x[4]));
  const ajust = d.map((x) => Number(x[5] || x[4]));
  const ult252 = cierre.slice(-252);
  return {
    simbolo,
    fecha: d.at(-1)[0],
    cierre: cierre.at(-1),
    variacion_dia_pct: rendimiento(ajust, 1),
    rend_1m_pct: rendimiento(ajust, 21),
    rend_3m_pct: rendimiento(ajust, 63),
    rend_1a_pct: rendimiento(ajust, 252),
    sma20: sma(cierre, 20),
    sma50: sma(cierre, 50),
    sma200: sma(cierre, 200),
    rsi14: rsi(cierre.slice(-300)),
    vol_anual_20d_pct: volAnual(ajust, 20),
    vol_anual_1a_pct: volAnual(ajust, 252),
    max_drawdown_1a_pct: maxDrawdown(ajust.slice(-252)),
    max_52s: Math.max(...ult252),
    min_52s: Math.min(...ult252),
    dias_registrados: d.length,
  };
}

// ---------------------------------------------------------------- principal
const log = [];
const resumen = [];
let errores = 0;
for (const simbolo of config.simbolos) {
  const archivo = path.join(dirHist, nombreArchivo(simbolo));
  const existentes = leerCsv(archivo);
  try {
    const nuevas = await descargar(simbolo, existentes.size ? '3mo' : config.rango_inicial);
    let agregadas = 0;
    for (const [fecha, linea] of nuevas) {
      if (!existentes.has(fecha)) agregadas++;
      existentes.set(fecha, linea); // actualiza también ajustes por dividendos/splits recientes
    }
    const filas = [...existentes.keys()].sort().map((f) => existentes.get(f));
    fs.writeFileSync(archivo, `${COLUMNAS}\n${filas.join('\n')}\n`);
    resumen.push(indicadores(simbolo, filas));
    log.push(`${simbolo}: +${agregadas} días (total ${filas.length})`);
  } catch (e) {
    log.push(`${simbolo}: ERROR ${e.message}`);
    errores++;
    // Sin descarga: el resumen se arma con lo ya guardado para no perder el símbolo.
    if (existentes.size) {
      resumen.push(indicadores(simbolo, [...existentes.keys()].sort().map((f) => existentes.get(f))));
    }
  }
  await new Promise((r) => setTimeout(r, 400)); // no saturar la fuente
}

const actualizado = new Date().toISOString();
fs.writeFileSync(path.join(dirHist, 'resumen.json'), JSON.stringify({ actualizado, datos: resumen }, null, 2));

const f = (v, d = 2) => (v == null ? '—' : v.toFixed(d));
const md = [
  `# Resumen de mercado`,
  ``,
  `Actualizado: ${actualizado} · Fuente: Yahoo Finance (referencial)`,
  ``,
  `| Símbolo | Fecha | Cierre | Día % | 1M % | 3M % | 1A % | MM50 | MM200 | RSI14 | Vol. 1A % | Caída máx. 1A % |`,
  `|---|---|---|---|---|---|---|---|---|---|---|---|`,
  ...resumen.map((r) => `| ${r.simbolo} | ${r.fecha} | ${f(r.cierre)} | ${f(r.variacion_dia_pct)} | ` +
    `${f(r.rend_1m_pct)} | ${f(r.rend_3m_pct)} | ${f(r.rend_1a_pct)} | ${f(r.sma50)} | ${f(r.sma200)} | ` +
    `${f(r.rsi14, 1)} | ${f(r.vol_anual_1a_pct, 1)} | ${f(r.max_drawdown_1a_pct, 1)} |`),
  ``,
];
fs.writeFileSync(path.join(dirHist, 'resumen.md'), md.join('\n'));
fs.appendFileSync(path.join(dirHist, 'registro_descargas.log'), `${actualizado}\n  ${log.join('\n  ')}\n`);
console.log(log.join('\n'));
if (errores) process.exitCode = 1;
