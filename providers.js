// providers.js — chain, preflight, breaker, SSE
import { PROVIDERS, KEYS, PROXY } from './data.js';
import { ChatError } from './err.js';

const DEAD = new Set();
export const breaker = {
  dead: id => DEAD.has(id),
  kill: id => DEAD.add(id),
  reset: () => DEAD.clear(),
};

export function keyFor(id){
  const fromState = globalThis.S?.keys?.[id];
  return String(fromState ?? KEYS[id] ?? '').trim();
}

export function usable(p){
  if (!p) return false;
  if (DEAD.has(p.id)) return false;
  if (PROXY) return true;
  return keyFor(p.id).length > 0;
}

export function buildChain(preferred){
  const all = PROVIDERS.slice();
  const first = all.find(p => p.id === preferred);
  const rest  = all.filter(p => p.id !== preferred);
  return first ? [first, ...rest] : rest;
}

function classify(res){
  if ([401, 402, 403, 429].includes(res.status)) return 'dead';
  if (res.status >= 500) return 'retry';
  return 'ok';
}

async function* parseSSE(res){
  const reader = res.body.getReader();
  const dec = new TextDecoder();
  let buf = '';
  while (true){
    const { done, value } = await reader.read();
    if (done) break;
    buf += dec.decode(value, { stream:true });
    const lines = buf.split('\n');
    buf = lines.pop() ?? '';
    for (const line of lines){
      const t = line.trim();
      if (!t.startsWith('data:')) continue;
      const d = t.slice(5).trim();
      if (d === '[DONE]') return;
      try {
        const delta = JSON.parse(d)?.choices?.[0]?.delta?.content;
        if (delta) yield delta;
      } catch { /* keepalive or partial */ }
    }
  }
}

export async function* streamChat({ messages, signal, chain, onProvider }){
  const errors = [];
  let retried = false;

  for (const p of chain){
    if (!usable(p)){ errors.push(`${p.id}: no key`); continue; }

    const url = PROXY ? '/api/chat' : p.url;
    const headers = { 'Content-Type':'application/json' };
    if (!PROXY) headers.Authorization = `Bearer ${keyFor(p.id)}`;
    const payload = { model:p.model, messages, stream:true };
    if (PROXY) payload.provider = p.id;

    let res;
    try {
      res = await fetch(url, { method:'POST', headers, body:JSON.stringify(payload), signal });
    } catch (e){
      if (e.name === 'AbortError') return;
      errors.push(`${p.id}: network`); continue;
    }

    const kind = classify(res);
    if (kind === 'dead'){ breaker.kill(p.id); errors.push(`${p.id}: ${res.status}`); continue; }
    if (kind === 'retry' && !retried){ retried = true; errors.push(`${p.id}: ${res.status}`); continue; }
    if (!res.ok){ errors.push(`${p.id}: ${res.status}`); continue; }

    onProvider?.(p);
    yield* parseSSE(res);
    return;
  }
  throw new ChatError(errors);
}
