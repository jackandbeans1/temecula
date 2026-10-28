// imgstore.js — IndexedDB blobs, object URLs
const DB = 'temecula', STORE = 'img';
let dbp;

function open(){
  if (dbp) return dbp;
  dbp = new Promise((res, rej) => {
    const r = indexedDB.open(DB, 1);
    r.onupgradeneeded = () => { if (!r.result.objectStoreNames.contains(STORE)) r.result.createObjectStore(STORE); };
    r.onsuccess = () => res(r.result);
    r.onerror = () => rej(r.error);
  });
  return dbp;
}

async function tx(mode, fn){
  const db = await open();
  return new Promise((res, rej) => {
    const t = db.transaction(STORE, mode);
    const req = fn(t.objectStore(STORE));
    req.onsuccess = () => res(req.result);
    req.onerror = () => rej(req.error);
  });
}

export const imgPut = (id, blob) => tx('readwrite', s => s.put(blob, id));
export const imgGet = (id)         => tx('readonly',  s => s.get(id));
export const imgDel = (id)         => tx('readwrite', s => s.delete(id));

const URLS = new Map();
export async function imgURL(id){
  if (URLS.has(id)) return URLS.get(id);
  const blob = await imgGet(id);
  if (!blob) return '';
  const u = URL.createObjectURL(blob);
  URLS.set(id, u);
  return u;
}
export function dropURL(id){
  const u = URLS.get(id);
  if (u){ URL.revokeObjectURL(u); URLS.delete(id); }
}
