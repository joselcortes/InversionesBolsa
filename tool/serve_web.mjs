// Servidor local para probar la versión web con los MISMOS encabezados de
// seguridad que firebase.json (así un error de CSP se detecta antes de
// publicar). Uso: node tool/serve_web.mjs  →  http://localhost:8080
import { createServer } from 'node:http';
import { readFileSync, existsSync, statSync } from 'node:fs';
import { extname, join, normalize } from 'node:path';

const root = join(process.cwd(), 'build', 'web');
const port = Number(process.env.PORT ?? 8080);
const config = JSON.parse(readFileSync('firebase.json', 'utf8')).hosting;
const globalHeaders = config.headers.find((h) => h.source === '**').headers;

const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.bin': 'application/octet-stream',
  '.frag': 'application/octet-stream',
  '.symbols': 'text/plain',
};

createServer((req, res) => {
  const urlPath = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  let file = normalize(join(root, urlPath));
  if (!file.startsWith(root)) {
    res.writeHead(403).end();
    return;
  }
  if (!existsSync(file) || statSync(file).isDirectory()) file = join(root, 'index.html');
  for (const { key, value } of globalHeaders) {
    // HSTS no aplica sobre http://localhost.
    if (key !== 'Strict-Transport-Security') res.setHeader(key, value);
  }
  res.setHeader('Content-Type', types[extname(file)] ?? 'application/octet-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.end(readFileSync(file));
}).listen(port, () => console.log(`Sirviendo build/web en http://localhost:${port}`));
