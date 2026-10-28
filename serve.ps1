[CmdletBinding()]
param([int]$Port = 8080)
$ErrorActionPreference = 'Stop'
$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) { throw 'python not on PATH' }
$ip = (Get-NetIPAddress -AddressFamily IPv4 |
       Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.)' -and $_.PrefixOrigin -ne 'WellKnown' } |
       Select-Object -First 1).IPAddress
"local   http://localhost:$Port"
"phone   http://${ip}:$Port"
"ctrl-c to stop"
Push-Location $PSScriptRoot
try { & python -m http.server $Port --bind 0.0.0.0 } finally { Pop-Location }
