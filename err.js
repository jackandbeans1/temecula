// err.js — failure classification and readable text
export class ChatError extends Error {
  constructor(details){ super('all providers failed'); this.name = 'ChatError'; this.details = details; }
}

const MAP = {
  401: 'key rejected',
  402: 'no credits or key missing',
  403: 'blocked by account',
  429: 'rate limited',
  500: 'provider fault',
  502: 'provider fault',
  503: 'provider down',
};

export function describe(err){
  if (err instanceof ChatError) return err.details.map(d => {
    const [id, code] = d.split(': ');
    return `${id} — ${MAP[code] ?? code}`;
  }).join('\n');
  if (err?.name === 'AbortError') return 'stopped';
  return err?.message ?? 'unknown failure';
}
