# ============================================================
#  setup.ps1 - VESPER. Creates or repairs every file. Idempotent.
#  run:  powershell -ep bypass -f .\setup.ps1 [-Push]
# ============================================================
param([switch]$Push)
$ErrorActionPreference = 'Stop'
$root = "$HOME\temecula-girls"
New-Item -ItemType Directory -Force -Path $root | Out-Null
Set-Location $root
$U8 = New-Object Text.UTF8Encoding($false)
function Say($s){ Write-Host $s }
function W($path,$text){ [IO.File]::WriteAllText($path, $text, $U8) }

# ---------------- support files ----------------
$imgstore = @'
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
'@
W "$root\imgstore.js" $imgstore
Say ("imgstore.js  " + (Get-Item "$root\imgstore.js").Length + " bytes")

$serve = @'
param([int]$Port=8787,[switch]$Open)
$ErrorActionPreference='Stop'
$root = if($PSScriptRoot){$PSScriptRoot}else{$PWD.Path}
(Get-NetTCPConnection -LocalPort $Port -State Listen -EA 0).OwningProcess |
  Select-Object -Unique | ForEach-Object { Stop-Process -Id $_ -Force -EA 0 }
$L = New-Object Net.HttpListener
$L.Prefixes.Add("http://localhost:$Port/")
$L.Start()
$mime = @{ '.html'='text/html; charset=utf-8'; '.js'='application/javascript; charset=utf-8';
           '.css'='text/css'; '.json'='application/json'; '.png'='image/png';
           '.jpg'='image/jpeg'; '.jpeg'='image/jpeg'; '.webp'='image/webp';
           '.svg'='image/svg+xml'; '.ico'='image/x-icon' }
Write-Host "serving $root -> http://localhost:$Port/"
if ($Open) { Start-Process "http://localhost:$Port/" }
while ($L.IsListening) {
  $c = $L.GetContext()
  try {
    $rel = [Uri]::UnescapeDataString($c.Request.Url.AbsolutePath.TrimStart('/'))
    if (-not $rel) { $rel = 'index.html' }
    $fp = Join-Path $root $rel
    if (Test-Path $fp -PathType Leaf) {
      $b = [IO.File]::ReadAllBytes($fp)
      $e = [IO.Path]::GetExtension($fp).ToLower()
      $c.Response.ContentType = if ($mime.ContainsKey($e)) { $mime[$e] } else { 'application/octet-stream' }
      $c.Response.ContentLength64 = $b.Length
      $c.Response.OutputStream.Write($b, 0, $b.Length)
    } else {
      $c.Response.StatusCode = 404
      $b = [Text.Encoding]::UTF8.GetBytes("404 $rel")
      $c.Response.OutputStream.Write($b, 0, $b.Length)
    }
  } catch {} finally { $c.Response.OutputStream.Close() }
}
'@
W "$root\serve.ps1" $serve
Say ("serve.ps1  " + (Get-Item "$root\serve.ps1").Length + " bytes")

$go = @'
Set-Location "$HOME\temecula-girls"
Get-NetTCPConnection -LocalPort 8787 -State Listen -EA 0 | Select-Object -Expand OwningProcess -Unique | ForEach-Object { Stop-Process -Id $_ -Force -EA 0 }
powershell -ep bypass -f .\serve.ps1 -Open
'@
W "$root\go.ps1" $go
W "$root\.gitignore" "*.bak`n*.txt`n"
New-Item -ItemType File -Path "$root\.nojekyll" -Force | Out-Null
Say "go.ps1 / .gitignore / .nojekyll written"

# ---------------- index.html ----------------
$p = "$root\index.html"
if (-not (Test-Path $p)) { throw "index.html not found in $root" }
$t = [IO.File]::ReadAllText($p) -replace "`r`n","`n"
$t = $t.TrimStart([char]0xFEFF)
Copy-Item $p "$p.setup.bak" -Force

$mj = ([regex]::Matches($t,'[\u00C3\u00E2\u00C2\u20AC]')).Count
if ($mj -gt 5) { $t = [Text.Encoding]::UTF8.GetString([Text.Encoding]::GetEncoding(1252).GetBytes($t)); Say "APPLY mojibake repair" }
else { Say "SKIP  mojibake" }

$PATCH = @()
function A($name,$old,$new){ $script:PATCH += ,@{name=$name; old=$old; new=$new} }

# --- core ---
A 'save hardening' 'const save=()=>localStorage.setItem(LS,JSON.stringify(S));' 'const save=()=>{try{localStorage.setItem(LS,JSON.stringify(S))}catch(e){console.warn("save fail",e.message)}};'
A 'safe_mode + watermark' 'model:S.im||"wai-Illustrious",' 'safe_mode:false,hide_watermark:true,model:S.im||"wai-Illustrious",'
A 'format png' 'format:"webp"' 'format:"png"'
A 'mime png' 'mime:"image/webp"' 'mime:"image/png"'
A 'chat model id' 'cm:"venice-uncensored"' 'cm:"venice-uncensored-1-2"'
A 'image placeholder' 'placeholder="wai-illu"' 'placeholder="wai-Illustrious"'
A 'per-model step cap' 'Math.min(LIM.steps,+S.steps||30)' 'Math.min((/wai/i.test(S.im||"wai-Illustrious")?30:50),+S.steps||25)'
A 'direct-mode note' 'Proxy mode: run start.ps1, set bases to <b>http://localhost:8787/p/&lt;provider&gt;</b>, leave keys blank.' 'Direct mode: set bases to <b>https://api.venice.ai/api/v1</b> and paste your key.'

# --- missing settings inputs ---
$o = '  <label>Image model</label><input id="sIM" placeholder="wai-Illustrious">'
$n = $o + "`n" +
'  <label>Width</label><input id="sIW" type="number" step="16" placeholder="832">' + "`n" +
'  <label>Height</label><input id="sIH" type="number" step="16" placeholder="1216">' + "`n" +
'  <label>Steps</label><input id="sSteps" type="number" min="1" max="50" placeholder="25">' + "`n" +
'  <label>CFG</label><input id="sCfg" type="number" step="0.5" min="1" max="20" placeholder="6.5">'
A 'settings inputs' $o $n

# --- load imgstore ---
A 'imgstore tag' ('</div></div>' + "`n" + '<script>' + "`n" + 'const TEMECULA = ') ('</div></div>' + "`n" + '<script src="imgstore.js"></script>' + "`n" + '<script>' + "`n" + 'const TEMECULA = ')

# --- IndexedDB wiring ---
$o = '    const url=ex.url?ex.url:`data:${req.mime};base64,${ex.b64}`;' + "`n" +
     '    (S.gal[S.active]=S.gal[S.active]||[]).unshift(url);' + "`n" +
     '    S.chats[S.active].push({r:"a",t:"",img:url});save();renderMsgs();renderGal();'
$n = '    const url=ex.url?ex.url:`data:${req.mime};base64,${ex.b64}`;' + "`n" +
     '    if(ex.b64&&ex.b64.length<8000)console.warn("[img] small payload",ex.b64.length);' + "`n" +
     '    const ikey=await imgSave(url);' + "`n" +
     '    (S.gal[S.active]=S.gal[S.active]||[]).unshift(ikey);' + "`n" +
     '    S.chats[S.active].push({r:"a",t:"",imgKey:ikey});save();renderMsgs();renderGal();'
A 'imgGo -> idb' $o $n

A 'save inside try' ('S.chats[S.active].push({r:"sys",t:"[gen] "+p});save();renderMsgs();' + "`n" + '  try{') ('S.chats[S.active].push({r:"sys",t:"[gen] "+p});renderMsgs();' + "`n" + '  try{ save();')

# --- prompt dedupe + model list ---
A 'dedupe venice' 'const full=p+", "+TAIL;' 'const full=dedupe(p+", "+TAIL);'
A 'dedupe qwen' 'prompt:p+", "+TAIL,' 'prompt:dedupe(p+", "+TAIL),'
A 'models type' '"/models",{headers:key?{Authorization:"Bearer "+key}:{}});' '"/models"+(type?"?type="+type:""),{headers:key?{Authorization:"Bearer "+key}:{}});'
A 'models fallback' '  return [];' '  return ids;'

# --- black frame retry ---
$o = @(
'    console.log("[img] sending:",req.body);',
'    const r=await fetch(req.url,{method:"POST",headers:req.headers,body:req.body});',
'    const raw=await r.text();',
'    if(!r.ok)throw new Error(r.status+" "+raw.slice(0,300));',
'    let j;try{j=JSON.parse(raw)}catch{throw new Error("non-JSON: "+raw.slice(0,200))}',
'    const ex=extractImg(j);',
'    console.log("[img] keys:",Object.keys(j),"| extracted:",ex?(ex.url?("URL"):("b64 len "+ex.b64.length)):"NULL");',
'    if(!ex)throw new Error("no image field. keys="+Object.keys(j).join(","));'
) -join "`n"
$n = @(
'    let ex=null,j=null;',
'    for(let attempt=0;attempt<4;attempt++){',
'      const bd=JSON.parse(req.body);',
'      if(attempt)bd.seed=Math.floor(Math.random()*999999999);',
'      const r=await fetch(req.url,{method:"POST",headers:req.headers,body:JSON.stringify(bd)});',
'      const raw=await r.text();',
'      if(!r.ok)throw new Error(r.status+" "+raw.slice(0,300));',
'      try{j=JSON.parse(raw)}catch{throw new Error("non-JSON: "+raw.slice(0,200))}',
'      ex=extractImg(j);',
'      if(!ex)throw new Error("no image field. keys="+Object.keys(j).join(","));',
'      const L=ex.b64?ex.b64.length:9e9;',
'      console.log("[img] attempt "+attempt+" | extracted:",ex.url?"URL":("b64 len "+L));',
'      if(L>100000||ex.url)break;',
'      console.warn("[img] BLACK FRAME ("+L+") - retrying with new seed");',
'    }'
) -join "`n"
A 'black retry' $o $n

# --- clothing system ---
$lib = @(
'const OUTFIT={',
'  "none (nude)":[],',
'  "bra + panties":["bra","panties","lingerie","matching set"],',
'  "cotton underwear":["cotton bra","cotton panties","plain underwear"],',
'  "sports bra + shorts":["sports bra","running shorts","athletic"],',
'  "school uniform":["school uniform","serafuku","sailor collar","pleated skirt","blouse","kneehighs"],',
'  "gym uniform":["gym uniform","bloomers","white t-shirt","sneakers"],',
'  "cheerleader":["cheerleader uniform","pleated skirt","letterman jacket"],',
'  "sundress":["sundress","thin straps","floral print"],',
'  "crop top + shorts":["crop top","midriff","denim shorts"],',
'  "oversized tee":["oversized shirt","bare legs"],',
'  "hoodie":["oversized hoodie","bare legs","hood up"],',
'  "tank + jeans":["tank top","jeans","belt"],',
'  "flannel + cutoffs":["plaid flannel","denim cutoffs","tied shirt"],',
'  "bikini":["bikini","two-piece swimsuit","string bikini"],',
'  "one-piece swimsuit":["one-piece swimsuit","racerback"],',
'  "school swimsuit":["school swimsuit","one-piece swimsuit","name tag"],',
'  "towel":["towel","body towel","wet hair"],',
'  "yukata":["yukata","obi","floral"],',
'  "maid":["maid outfit","apron","frills","headband"],',
'  "leotard":["leotard","gymnastics leotard","tights"],',
'  "nude apron":["apron only","bare back"],',
'  "wet shirt":["wet clothes","wet white shirt","see-through","clingy fabric"],',
'  "pajamas":["pajama set","sleep shirt","bare feet"],',
'  "thighhighs only":["black thighhighs","pantyhose"]',
'};',
'const REVEAL={',
'  "none":[],',
'  "shirt lift":["shirt lift","midriff","underboob"],',
'  "skirt lift":["skirt lift","upskirt","visible panties"],',
'  "unbuttoned":["unbuttoned shirt","open shirt","cleavage","visible bra"],',
'  "bra strap slip":["bra strap slip","off shoulder","bare shoulder"],',
'  "one strap down":["one strap down","slipping strap"],',
'  "bra pulled down":["bra pulled down","breasts out","underboob"],',
'  "panties pulled down":["panties pulled down","half off","bare hips"],',
'  "see-through":["see-through","transparent clothing","nipples visible through fabric"],',
'  "underboob":["underboob","cropped shirt"],',
'  "sideboob":["sideboob","side view"],',
'  "zettai ryouiki":["zettai ryouiki","thighhighs","miniskirt"],',
'  "wet":["wet clothes","wet skin","clingy fabric","dripping"],',
'  "partially undressed":["partially undressed","undressing","half off"],',
'  "hands in waistband":["hands in waistband","pulling panties down"],',
'  "back view":["back view","bare back","open back"],',
'  "top pulled up":["shirt pulled up","exposed stomach","underboob"],',
'  "bottom pulled aside":["panties pulled aside","visible pussy"],',
'  "topless, bottoms on":["topless","bottoms on","bra removed"]',
'};',
'const COVER={',
'  "nude":{tags:["completely nude","bare breasts","visible nipples","pussy","hairless pussy"]},',
'  "topless":{tags:["topless","bare breasts","visible nipples","breasts out"]},',
'  "bottomless":{tags:["bottomless","no panties","pussy","visible vulva","hairless pussy"]},',
'  "underwear":{tags:["lingerie","matching underwear","breasts covered","cleavage","bare legs"]},',
'  "clothed":{tags:["fully clothed","breasts covered","clothing","fabric detail"]},',
'  "tease":{tags:["clothing","partially undressed","breasts covered","bare skin","flushed"]}',
'};'
) -join "`n"
A 'clothing lib' 'const PRESET={' ($lib + "`n" + 'const PRESET={')

A 'clothing outfit list' ('  outfit:["completely nude","topless","bottomless","bikini","one-piece swimsuit","panties","bra and panties",' + "`n" + '          "school uniform","towel","oversized t-shirt","sundress","thighhighs only","nude apron"],') '  outfit:Object.keys(OUTFIT),'

$o = 'const bodyTags=(g,close)=> (BODY[g.a]||BODY[13])[close?"close":"full"];'
$n = @(
'function bodyTags(g,close,cover){',
'  const b=(BODY[g.a]||BODY[13])[close?"close":"full"];',
'  if(!cover||cover==="nude"||cover==="topless"||cover==="bottomless")return b;',
'  return b.split(",").map(s=>s.trim()).filter(t=>',
'    !/^(nipples|tiny nipples|puffy nipples|small nipples|hairless|small vulva|vulva|pussy|navel)$/i.test(t)',
'  ).join(", ");',
'}'
) -join "`n"
A 'clothing bodyTags' $o $n

$o = @(
'function buildPrompt(g,o){',
'  const p=["1girl","solo"];',
'  p.push(g.tg);',
'  p.push(bodyTags(g,o.close));',
'  if(o.outfit==="completely nude"||!o.outfit){p.push("completely nude","pussy")}',
'  else{p.push(o.outfit,"nipples")}',
'  if(o.detail)p.push(o.detail);'
) -join "`n"
$n = @(
'function buildPrompt(g,o){',
'  const p=["1girl","solo"];',
'  p.push(g.tg);',
'  const cov=o.cover||"nude";',
'  p.push(bodyTags(g,o.close,cov));',
'  p.push((COVER[cov]||COVER.nude).tags);',
'  if(o.outfit&&o.outfit!=="none (nude)"&&OUTFIT[o.outfit])p.push("wearing "+o.outfit,OUTFIT[o.outfit]);',
'  if(o.reveal&&o.reveal!=="none")p.push(REVEAL[o.reveal]||o.reveal);',
'  if(o.detail)p.push(o.detail);'
) -join "`n"
A 'clothing buildPrompt' $o $n

$o = '      <div><label style="${lb}">Outfit</label><select id="iOutfit" style="${st}">${opt(PRESET.outfit)}</select></div>'
$n = $o + "`n" +
'      <div><label style="${lb}">Coverage</label><select id="iCover" style="${st}">${opt(Object.keys(COVER))}</select></div>' + "`n" +
'      <div><label style="${lb}">Reveal / tease</label><select id="iReveal" style="${st}">${opt(Object.keys(REVEAL))}</select></div>'
A 'clothing dialog' $o $n

$o = @('function imgRebuild(){','  if(!S.active||S.active==="group")return;','  const g=G(S.active);') -join "`n"
$n = @('function imgRebuild(){','  if(!S.active||S.active==="group")return;','  const g=G(S.active);','  if(iOutfit.value==="none (nude)")iCover.value="nude";','  else if(iCover.value==="nude")iCover.value="clothed";') -join "`n"
A 'clothing autorebuild' $o $n

$o = @('    outfit:iOutfit.value,pose:iPose.value,setting:iSet.value,','    light:iLight.value,camera:iCam.value,extra:iExtra.value,','    detail:iDetail.value,anchor:iAnchor.value,close:iClose.value==="1"') -join "`n"
$n = @('    outfit:iOutfit.value,cover:iCover.value,reveal:iReveal.value,','    pose:iPose.value,setting:iSet.value,','    light:iLight.value,camera:iCam.value,extra:iExtra.value,','    detail:iDetail.value,anchor:iAnchor.value,close:iClose.value==="1"') -join "`n"
A 'clothing args' $o $n

A 'clothing listeners' '["iOutfit","iPose","iSet","iLight","iCam","iDetail","iAnchor","iExtra","iSize","iClose"].forEach' '["iOutfit","iCover","iReveal","iPose","iSet","iLight","iCam","iDetail","iAnchor","iExtra","iSize","iClose"].forEach'

# ---------------- apply ----------------
$ap=0; $sk=0; $ms=0
foreach($x in $PATCH){
  if($t.Contains($x.new)){ Say "SKIP  $($x.name)"; $sk++; continue }
  if($t.Contains($x.old)){ $t = $t.Replace($x.old,$x.new); Say "APPLY $($x.name)"; $ap++; continue }
  Say "MISS  $($x.name)"; $ms++
}
W $p $t
Say ""
Say "applied $ap | skipped $sk | MISSED $ms   (of $($PATCH.Count))"

# ---------------- verify ----------------
Say "`n===== VERIFY ====="
$ck = [ordered]@{
  'imgstore.js'   = Test-Path "$root\imgstore.js"
  'serve.ps1'     = Test-Path "$root\serve.ps1"
  'imgstore tag'  = $t.Contains('src="imgstore.js"')
  'safe_mode'     = $t.Contains('safe_mode:false')
  'format png'    = $t.Contains('format:"png"')
  'idb save'      = $t.Contains('imgSave(url)')
  'black retry'   = $t.Contains('BLACK FRAME')
  'clothing lib'  = $t.Contains('const OUTFIT')
  'coverage sel'  = $t.Contains('id="iCover"')
  'models type'   = $t.Contains('?type=')
  'step cap'      = $t.Contains('(/wai/i.test')
  'no mojibake'   = (([regex]::Matches($t,'[\u00C3\u00E2\u00C2\u20AC]')).Count -eq 0)
}
$fail = 0
foreach($k in $ck.Keys){ if($ck[$k]){ Say ("  OK    " + $k) } else { Say ("  FAIL  " + $k); $fail++ } }
Say $(if($fail -eq 0){ "`nALL GREEN" } else { "`n$fail FAILED" })

if ($Push) {
  git add -A
  git -c user.email="jacka@users.noreply.github.com" -c user.name="jacka" commit -qm "setup.ps1 sync"
  git push origin main
  Say "pushed"
}