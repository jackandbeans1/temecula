// functions/api/chat.js — Cloudflare Pages Function, key never reaches the browser
const MAP = {
  venice:     { url:'https://api.venice.ai/api/v1/chat/completions',     key:'VENICE_API_KEY' },
  openrouter: { url:'https://openrouter.ai/api/v1/chat/completions',     key:'OPEN_ROUTER'    },
};

export async function onRequestPost({ request, env }){
  let body;
  try { body = await request.json(); } catch { return json({ error:'bad json' }, 400); }

  const cfg = MAP[body.provider];
  if (!cfg) return json({ error:'unknown provider' }, 400);

  const key = env[cfg.key];
  if (!key) return json({ error:`${cfg.key} unset` }, 502);

  const upstream = await fetch(cfg.url, {
    method:'POST',
    headers:{ Authorization:`Bearer ${key}`, 'Content-Type':'application/json' },
    body: JSON.stringify({ model: body.model, messages: body.messages, stream: true }),
  });

  return new Response(upstream.body, {
    status: upstream.status,
    headers:{ 'Content-Type':'text/event-stream', 'Cache-Control':'no-store', 'X-Upstream': upstream.status },
  });
}

const json = (o, s) => new Response(JSON.stringify(o), { status:s, headers:{ 'Content-Type':'application/json' } });
