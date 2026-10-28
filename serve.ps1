[CmdletBinding()]
param([int]$Port = 8080, [string]$KeyFile = ".dev.vars")

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw "node not on PATH" }

if (Test-Path $KeyFile) {
  Get-Content $KeyFile | Where-Object { $_ -match '^\s*[A-Z_]+\s*=' } | ForEach-Object {
    $n, $v = $_ -split '=', 2
    Set-Item -Path "env:$($n.Trim())" -Value $v.Trim()
  }
  Write-Host "loaded $KeyFile" -ForegroundColor DarkGray
}

$env:PORT = $Port
node dev-proxy.mjs
