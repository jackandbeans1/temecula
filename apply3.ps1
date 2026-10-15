$ErrorActionPreference = 'Stop'
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$idx  = Join-Path $root 'index.html'
Copy-Item $idx "$idx.bak3" -Force
$t = [IO.File]::ReadAllText($idx) -replace "`r`n","`n"

# 1. crash-proof the NEG append (TDZ-safe)
$oldNeg = "if (typeof NEG === 'string' && NEG.indexOf('mosaic censoring') < 0) {`n  NEG += ', mosaic censoring, bar censor, censorship, worst quality, low quality, lowres, jpeg artifacts, watermark, signature, text';`n}"
$newNeg = "try { if (typeof NEG === 'string' && NEG.indexOf('mosaic censoring') < 0) NEG += ', mosaic censoring, bar censor, censorship, worst quality, low quality, lowres, jpeg artifacts, watermark, signature, text'; } catch (e) {}"
if ($t.Contains($oldNeg)) { $t = $t.Replace($oldNeg,$newNeg); Write-Host '[ok] NEG append made crash-proof' -ForegroundColor Green }
else { Write-Host '[--] NEG append not found (ok)' -ForegroundColor DarkGray }

# 2. wrap the LAST return inside buildPrompt, whatever its shape
$i = $t.IndexOf('function buildPrompt')
if ($i -lt 0) { Write-Host '[X] buildPrompt not found' -ForegroundColor Red; exit 1 }
$mn = [regex]::Match($t.Substring($i+20), '(?m)^\s*function\s+')
$j  = if ($mn.Success) { $i + 20 + $mn.Index } else { $t.Length }
$head = $t.Substring(0,$i); $body = $t.Substring($i,$j-$i); $tail = $t.Substring($j)
if ($body -match 'capPrompt\(') { Write-Host '[skip] already wrapped' -ForegroundColor DarkGray }
else {
  $ms = [regex]::Matches($body, '(?m)^(\s*)return\s+(.+?);\s*$')
  if ($ms.Count -gt 0) {
    $last = $ms[$ms.Count-1]
    $expr = $last.Groups[2].Value.Trim()
    $body = $body.Remove($last.Index,$last.Length).Insert($last.Index, ($last.Groups[1].Value + 'return capPrompt(' + $expr + ');'))
    Write-Host ('[ok] wrapped -> return capPrompt(' + $expr + ');') -ForegroundColor Green
  } else { Write-Host '[!] no return found inside buildPrompt' -ForegroundColor Yellow }
}
$t = $head + $body + $tail
[IO.File]::WriteAllText($idx, ($t -replace "`n","`r`n"), (New-Object Text.UTF8Encoding($false)))

Write-Host ''
Write-Host '===== buildPrompt now =====' -ForegroundColor Cyan
$v = [IO.File]::ReadAllText($idx)
$k = $v.IndexOf('function buildPrompt')
Write-Host $v.Substring($k, [Math]::Min(1500, $v.Length-$k))
Write-Host ''
Write-Host ('[backup] ' + $idx + '.bak3') -ForegroundColor DarkGray
