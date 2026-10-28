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
function dataUrlToBlob(d){
  const [head,b64] = d.split(",");
  const mime = (head.match(/data:([^;]+)/)||[])[1] || "image/png";
  const bin = atob(b64), arr = new Uint8Array(bin.length);
  for(let i=0;i<bin.length;i++) arr[i]=bin.charCodeAt(i);
  return new Blob([arr],{type:mime});
}
async function imgSave(dataUrl){
  const k = "i"+Date.now().toString(36)+Math.random().toString(36).slice(2,7);
  const blob = dataUrl.startsWith("data:") ? dataUrlToBlob(dataUrl) : dataUrl;
  IMGC[k] = URL.createObjectURL(blob);
  try{
    const d = await dbOpen();
    await new Promise((res,rej)=>{ const t=d.transaction("img","readwrite");
      t.objectStore("img").put(blob,k); t.oncomplete=res; t.onerror=()=>rej(t.error); });
  }catch(e){ console.warn("idb put",e); }
  return k;
}
const IMG = x => !x ? "" : (x.startsWith("data:")||x.startsWith("http")||x.startsWith("blob:") ? x : (IMGC[x]||""));
async function imgHydrate(){
  try{
    const d = await dbOpen();
    const keys = await new Promise((res,rej)=>{ const t=d.transaction("img","readonly");
      const q=t.objectStore("img").getAllKeys(); t.oncomplete=()=>res(q.result); t.onerror=()=>rej(t.error); });
    for(const k of keys){
      const v = await new Promise((res,rej)=>{ const t=d.transaction("img","readonly");
        const q=t.objectStore("img").get(k); t.oncomplete=()=>res(q.result); t.onerror=()=>rej(t.error); });
      if(!v) continue;
      IMGC[k] = v instanceof Blob ? URL.createObjectURL(v) : String(v);
    }
    if(typeof S === "undefined") return;
    let n = 0;
    for(const g in S.gal){ const a=S.gal[g]||[]; for(let i=0;i<a.length;i++){ if(a[i]&&a[i].startsWith("data:")){ a[i]=await imgSave(a[i]); n++; } } }
    for(const g in S.chats){ for(const m of (S.chats[g]||[])){ if(m.img&&m.img.startsWith("data:")){ m.imgKey=await imgSave(m.img); delete m.img; n++; } } }
    if(n){ save(); console.log("[idb] migrated "+n+" images"); }
    console.log("[idb] ready - "+Object.keys(IMGC).length+" cached");
    if(S.active && S.active!=="group"){ renderMsgs(); renderGal(); }
  }catch(e){ console.warn("idb hydrate",e); }
}
setTimeout(imgHydrate, 0);
