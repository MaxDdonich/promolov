# Adds a Windows Firewall inbound rule for PromoLov so phones/tablets on the same Wi-Fi
# can open http://<LAN-IP>:8787/.
# Run: right-click -> Run with PowerShell, or start "Разрешить в брандмауэре.bat".

param([int]$Port = 8787)

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
  Write-Host 'Requesting administrator rights...'
  $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $PSCommandPath + '"'), '-Port', "$Port")
  Start-Process powershell -Verb RunAs -ArgumentList $args
  exit
}

$ruleName = "PromoLov $Port"
try {
  $existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
  if ($existing) {
    Write-Host "Firewall rule '$ruleName' already exists."
  } else {
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow -Profile Any | Out-Null
    Write-Host "Firewall rule '$ruleName' added."
  }

  Get-NetConnectionProfile -ErrorAction SilentlyContinue |
    Where-Object { $_.IPv4Connectivity -ne 'Disconnected' } |
    ForEach-Object {
      Write-Host ("Network: {0} · {1}" -f $_.Name, $_.NetworkCategory)
    }
} catch {
  Write-Host "Could not add the rule: $($_.Exception.Message)"
}
Read-Host 'Press Enter to close'
