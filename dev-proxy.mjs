// dev-proxy.mjs — static files + /api/chat, no deps
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';

const ROOT = process.cwd();
const PORT = Number(process.env.PORT ?? 8080);

const TYPES = { '.html':'text/html', '.js':'text/javascript', '.css':'text/css', '.json':'application/manifest+json', '.svg':'image/svg+xml' };

const MAP = {
  venice:     { url:'https://api.venice.ai/api/v1/chat/completions', key: process.env.VENICE_API_KEY },
  openrouter: { url:'https://openrouter.ai/api/v1/chat/completions', key: process.env.OPEN_ROUTER },
};

createServer(async (req, res) => {
  if (req.method === 'POST' && req.url === '/api/chat'){
    let raw = '';
    for await (const c of req) raw += c;
    let body;
    try { body = JSON.parse(raw); } catch { res.writeHead(400).end('{"error":"bad json"}'); return; }
    const cfg = MAP[body.provider];
    if (!cfg?.key){ res.writeHead(502).end('{"error":"key unset"}'); return; }

    const up = await fetch(cfg.url, {
      method:'POST',
      headers:{ Authorization:`Bearer ${cfg.key}`, 'Content-Type':'application/json' },
      body: JSON.stringify({ model: body.model, messages: body.messages, stream: true }),
    });
    res.writeHead(up.status, { 'Content-Type':'text/event-stream', 'Cache-Control':'no-store' });
    for await (const chunk of up.body) res.write(chunk);
    res.end();
    return;
  }

  const rel = normalize(decodeURIComponent(req.url.split('?')[0])).replace(/^(\.\.[/\\])+/, '');
  const file = join(ROOT, rel === '/' ? 'index.html' : rel);
  try {
    const buf = await readFile(file);
    res.writeHead(200, { 'Content-Type': TYPES[extname(file)] ?? 'application/octet-stream' }).end(buf);
  } catch {
    res.writeHead(404).end('not found');
  }
}).listen(PORT, '0.0.0.0', () => {
  console.log(`local   http://localhost:${PORT}`);
  for (const [name, addrs] of Object.entries(os.networkInterfaces()))
    for (const a of addrs) if (a.family === 'IPv4' && !a.internal) console.log(`lan     http://${a.address}:${PORT}  (${name})`);
});
