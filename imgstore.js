const IMGC = {};
let _db = null;
function dbOpen(){
  return new Promise((res,rej)=>{
    if(_db) return res(_db);
    const r = indexedDB.open("temecula_img",1);
    r.onupgradeneeded = () => r.result.createObjectStore("img");
    r.onsuccess = () => { _db = r.result; res(_db); };
    r.onerror = () => rej(r.error);
  });
}
async function imgSave(dataUrl){
  const k = "i"+Date.now().toString(36)+Math.random().toString(36).slice(2,7);
  IMGC[k] = dataUrl;
  try{
    const d = await dbOpen();
    await new Promise((res,rej)=>{ const t=d.transaction("img","readwrite");
      t.objectStore("img").put(dataUrl,k); t.oncomplete=res; t.onerror=()=>rej(t.error); });
  }catch(e){ console.warn("idb put",e); }
  return k;
}
const IMG = x => !x ? "" : (x.startsWith("data:")||x.startsWith("http") ? x : (IMGC[x]||""));
async function imgHydrate(){
  try{
    const d = await dbOpen();
    const keys = await new Promise((res,rej)=>{ const t=d.transaction("img","readonly");
      const q=t.objectStore("img").getAllKeys(); t.oncomplete=()=>res(q.result); t.onerror=()=>rej(t.error); });
    for(const k of keys){
      IMGC[k] = await new Promise((res,rej)=>{ const t=d.transaction("img","readonly");
        const q=t.objectStore("img").get(k); t.oncomplete=()=>res(q.result); t.onerror=()=>rej(t.error); });
    }
    let n = 0;
    for(const g in S.gal){ const a=S.gal[g]||[]; for(let i=0;i<a.length;i++){ if(a[i]&&a[i].startsWith("data:")){ a[i]=await imgSave(a[i]); n++; } } }
    for(const g in S.chats){ for(const m of (S.chats[g]||[])){ if(m.img&&m.img.startsWith("data:")){ m.imgKey=await imgSave(m.img); delete m.img; n++; } } }
    if(n){ save(); console.log("[idb] migrated "+n+" images out of localStorage"); }
    console.log("[idb] ready - "+Object.keys(IMGC).length+" cached");
    if(S.active && S.active!=="group"){ renderMsgs(); renderGal(); }
  }catch(e){ console.warn("idb hydrate",e); }
}
setTimeout(imgHydrate, 0);
