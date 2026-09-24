// Hook UserPromptSubmit de Claude Code: guarda cada pedido del usuario con fecha y hora en
// informacion/registro_prompts.md. Solo actúa si la sesión está dentro de InversionesBolsa.
// Nunca bloquea el pedido: ante cualquier error, termina sin hacer nada.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const raiz = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const destino = path.join(raiz, 'informacion', 'registro_prompts.md');

let entrada = '';
process.stdin.on('data', (d) => (entrada += d));
process.stdin.on('end', () => {
  try {
    const { prompt, cwd = '' } = JSON.parse(entrada);
    const rel = path.relative(raiz.toLowerCase(), path.resolve(cwd).toLowerCase());
    const dentro = path.isAbsolute(cwd) && !rel.startsWith('..') && !path.isAbsolute(rel);
    // Los avisos del sistema (ej. <task-notification>) no son pedidos del usuario.
    if (!prompt || !dentro || /^\s*<[a-z-]+>/i.test(prompt)) return;
    const fecha = new Date().toLocaleString('es-CL', { timeZone: 'America/Santiago' });
    if (!fs.existsSync(destino)) {
      fs.writeFileSync(destino, '# Registro de pedidos\n\nCada pedido enviado a Claude en este proyecto, en orden.\n');
    }
    const texto = prompt.trim().split('\n').map((l) => `> ${l}`).join('\n');
    fs.appendFileSync(destino, `\n## ${fecha}\n\n${texto}\n`);
  } catch {
    // Sin registro antes que interrumpir la sesión.
  }
});
