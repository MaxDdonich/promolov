# Allow PromoLov through Windows Firewall (run as administrator).
param([int]$Port = 8787)

$ErrorActionPreference = 'Stop'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  Write-Host 'Run this script as administrator.'
  Start-Sleep -Seconds 3
  exit 1
}

$ruleName = "PromoLov $Port"
$existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if ($existing) {
  Write-Host "Firewall rule already exists: $ruleName"
} else {
  New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port -Profile Any | Out-Null
  Write-Host "Firewall rule added: $ruleName"
}

Write-Host ''
Write-Host 'Other devices on the same Wi-Fi/LAN can now open:'
$ips = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
  Select-Object -ExpandProperty IPAddress -Unique
foreach ($ip in $ips) {
  Write-Host ("  http://{0}:{1}/" -f $ip, $Port)
}
Write-Host ''
Start-Sleep -Seconds 4
