param([string]$Password)
$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$idx  = Join-Path $root 'index.html'
if (-not (Test-Path $idx)) { Write-Host "[X] index.html not found" -ForegroundColor Red; exit 1 }
Copy-Item $idx "$idx.bak2" -Force
$t = [IO.File]::ReadAllText($idx) -replace "`r`n","`n"
$applied = @()

if ($t -notmatch 'vs-err-banner'){
  $banner = '<script id="vs-err">window.addEventListener("error",function(e){try{var d=document.getElementById("vs-err-banner");if(!d){d=document.createElement("div");d.id="vs-err-banner";d.style.cssText="position:fixed;left:0;right:0;bottom:0;z-index:2147483647;background:#b00020;color:#fff;font:12px/1.4 monospace;padding:6px 10px;white-space:pre-wrap;pointer-events:none";(document.body||document.documentElement).appendChild(d);}d.textContent="JS ERROR: "+e.message+"  @"+(e.filename||"").split("/").pop()+":"+e.lineno;}catch(_){}});</script>'
  if ($t -match '(?i)<head[^>]*>'){
    $t = [regex]::Replace($t,'(?i)(<head[^>]*>)', ('$1' + "`n" + $banner), 1)
    $applied += 'error banner'
  }
} else { Write-Host '[skip] banner present' -ForegroundColor DarkGray }

if ($t -notmatch 'function capPrompt'){
  if ($t -match '(?m)^function buildPrompt'){
    $block = @"
var STYLE_ANCHORS = {
  anime:     ['very aesthetic','absurdres','newest','masterpiece','anime illustration'],
  photoreal: ['photorealistic','raw photo','natural skin texture','cinematic lighting','8k'],
  cartoon:   ['flat color','cel shading','bold lineart','vector art'],
  hentai:    ['very aesthetic','absurdres','newest','uncensored','no mosaic'],
  explicit:  ['photorealistic','raw photo','detailed anatomy','uncensored','no mosaic']
};
function capPrompt(prompt, budget){
  budget = budget || 72;
  var seen = {}, out = [];
  String(prompt).split(',').forEach(function(raw){
    var t = raw.trim(); if (!t) return;
    var k = t.toLowerCase(); if (seen[k]) return; seen[k] = 1; out.push(t);
  });
  var est = function(a){ var n = 2; for (var i=0;i<a.length;i++) n += a[i].split(/\s+/).length + 1; return n; };
  var STYLE = ['anime illustration','very aesthetic','absurdres','4k','newest','masterpiece',
               'photorealistic','raw photo','natural skin texture','cinematic lighting','8k',
               'flat color','cel shading','bold lineart','vector art','uncensored','no mosaic'];
  var guard = 0;
  while (out.length > 6 && est(out) > budget && guard++ < 200){
    var idx = -1;
    for (var i = out.length - 1; i >= 0; i--){
      if (STYLE.indexOf(out[i].toLowerCase()) < 0) { idx = i; break; }
    }
    if (idx < 0) idx = out.length - 1;
    out.splice(idx, 1);
  }
  return out.join(', ');
}
function buildPrompt
"@
    $t = $t -replace '(?m)^function buildPrompt', $block
    $applied += 'capPrompt+anchors'
  } else { Write-Host '[!] buildPrompt anchor not found' -ForegroundColor Yellow }
} else { Write-Host '[skip] capPrompt present' -ForegroundColor DarkGray }

if ($t -notmatch 'return capPrompt\(finalPrompt\)'){
  if ($t -match '(?m)^\s*return\s+finalPrompt\s*;?'){
    $t = $t -replace '(?m)^(\s*)return\s+finalPrompt\s*;?', '$1return capPrompt(finalPrompt);'
    $applied += 'return wrapped'
  } else { Write-Host '[!] return anchor not found' -ForegroundColor Yellow }
} else { Write-Host '[skip] return wrapped' -ForegroundColor DarkGray }

[IO.File]::WriteAllText($idx, ($t -replace "`n","`r`n"), (New-Object Text.UTF8Encoding($false)))

Write-Host ''
Write-Host 'verification:' -ForegroundColor Cyan
$v = [IO.File]::ReadAllText($idx)
foreach ($m in 'vs-err-banner','function capPrompt','STYLE_ANCHORS','return capPrompt(finalPrompt)'){
  if ($v -match [regex]::Escape($m)) { Write-Host ('  [PASS] ' + $m) -ForegroundColor Green }
  else { Write-Host ('  [FAIL] ' + $m) -ForegroundColor Red }
}
if ($Password){
  $auth = Join-Path $root 'auth.ps1'
  if (Test-Path $auth){ & $auth -Password $Password } else { Write-Host '[!] auth.ps1 not found' -ForegroundColor Yellow }
}
Write-Host ''
if ($applied.Count){ Write-Host ('[ok] applied: ' + ($applied -join '; ')) -ForegroundColor Green }
else { Write-Host '[ok] nothing to change' -ForegroundColor Green }
Write-Host ('[backup] ' + $idx + '.bak2') -ForegroundColor DarkGray
