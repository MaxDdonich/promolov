# Public HTTPS link for PromoLov via localhost.run (SSH tunnel).
# Keep this window open while the public link is needed.
param([int]$Port = 8787)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (-not $root) { $root = Split-Path -Parent $MyInvocation.MyCommand.Path }

$running = $false
try {
  $client = New-Object System.Net.Sockets.TcpClient
  $client.Connect('127.0.0.1', $Port)
  $client.Close()
  $running = $true
} catch { }

if (-not $running) {
  Write-Host 'Starting local server...'
  $serve = Join-Path $root 'serve.ps1'
  Start-Process -FilePath 'powershell' -ArgumentList @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', $serve
  ) -WindowStyle Minimized
  Start-Sleep -Seconds 6
}

$ssh = Get-Command ssh -ErrorAction SilentlyContinue
if (-not $ssh) {
  Write-Host 'SSH client not found. Enable "OpenSSH Client" in Windows optional features.'
  Read-Host 'Press Enter to close'
  exit 1
}

$knownHosts = Join-Path $env:TEMP 'promolov_known_hosts'
$sshArgs = @(
  '-T',
  '-o', 'StrictHostKeyChecking=accept-new',
  '-o', "UserKnownHostsFile=$knownHosts",
  '-o', 'ExitOnForwardFailure=yes',
  '-o', 'ServerAliveInterval=30',
  '-R', "80:127.0.0.1:$Port",
  'nokey@localhost.run'
)

Write-Host ''
Write-Host 'Creating a public link. The address will appear below.'
Write-Host 'Keep this window open. Press Ctrl+C to stop the public link.'
Write-Host ''

$found = $false
$ErrorActionPreference = 'Continue'
& $ssh.Source @sshArgs | ForEach-Object {
  $line = [string]$_
  Write-Host $line
  if (-not $found -and $line -match 'https://[a-z0-9]+\.app\.lhr\.life') {
    $url = $Matches[0].TrimEnd('.', ',')
    $found = $true
    try { Set-Clipboard -Value $url } catch { }
    Write-Host ''
    Write-Host ('PUBLIC URL: ' + $url) -ForegroundColor Green
    Write-Host 'Copied to clipboard. Open it on any device while this window is open.'
    Write-Host 'The free localhost.run address rotates from time to time.'
    Write-Host ''
  }
}
