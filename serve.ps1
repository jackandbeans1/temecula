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