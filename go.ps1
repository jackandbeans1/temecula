Set-Location "$HOME\temecula-girls"
Get-NetTCPConnection -LocalPort 8787 -State Listen -EA 0 | Select-Object -Expand OwningProcess -Unique | ForEach-Object { Stop-Process -Id $_ -Force -EA 0 }
powershell -ep bypass -f .\serve.ps1 -Open