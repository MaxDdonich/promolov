param(
  [ValidateSet('alert', 'daily')]
  [string]$Mode = 'alert'
)

$ErrorActionPreference = 'Stop'

$token = $env:TELEGRAM_BOT_TOKEN
$chatId = $env:TELEGRAM_CHAT_ID
$proxy = $env:TELEGRAM_PROXY_URL
$ntfyTopic = $env:NTFY_TOPIC
if ([string]::IsNullOrWhiteSpace($ntfyTopic) -and
    ([string]::IsNullOrWhiteSpace($chatId) -or ([string]::IsNullOrWhiteSpace($token) -and [string]::IsNullOrWhiteSpace($proxy)))) {
  Write-Host 'No notification channel configured; skipping.'
  exit 0
}

function Html([string]$value) {
  if ($null -eq $value) { return '' }
  return ([string]$value).Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
}

function Read-JsonFile([string]$path) {
  if (-not (Test-Path $path)) { return $null }
  try { return (Get-Content -Raw -Encoding UTF8 $path | ConvertFrom-Json) } catch { return $null }
}

function Read-GitJson([string]$path) {
  try {
    $raw = & git show "HEAD:$path" 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $raw) { return $null }
    return ($raw | ConvertFrom-Json)
  } catch { return $null }
}

function Send-Ntfy([string]$text, [string]$priority = 'default', [string]$tags = 'bell') {
  if ([string]::IsNullOrWhiteSpace($ntfyTopic)) { return $false }
  $plain = [Net.WebUtility]::HtmlDecode(($text -replace '<[^>]+>', ' ' -replace '\s+', ' ')).Trim()
  if ($plain.Length -gt 3500) { $plain = $plain.Substring(0, 3500) + '…' }
  $raw = & curl.exe -sS --max-time 30 `
    -H 'Title: PromoLove' `
    -H "Priority: $priority" `
    -H "Tags: $tags" `
    -H 'Click: https://maxddonich.github.io/promolov/' `
    --data-binary $plain `
    "https://ntfy.sh/$ntfyTopic"
  Write-Host "ntfy response=$raw"
  try {
    $json = $raw | ConvertFrom-Json
    return [bool]$json.id
  } catch { return $false }
}

function Send-Telegram([string]$text) {
  if ([string]::IsNullOrWhiteSpace($chatId)) { return $false }
  if ([string]::IsNullOrWhiteSpace($token) -and [string]::IsNullOrWhiteSpace($env:TELEGRAM_PROXY_URL)) { return $false }
  $text = $text.Trim()
  if ($text.Length -gt 3900) { $text = $text.Substring(0, 3900) + '…' }
  for ($i = 1; $i -le 4; $i++) {
    $proxy = $env:TELEGRAM_PROXY_URL
    if (-not [string]::IsNullOrWhiteSpace($proxy)) {
      $payload = @{
        chat_id = $chatId
        text = $text
        parse_mode = 'HTML'
        disable_web_page_preview = $true
      } | ConvertTo-Json -Compress
      $raw = & curl.exe -sS --max-time 30 -X POST `
        -H 'content-type: application/json' `
        -H "x-secret: $($env:TELEGRAM_PROXY_SECRET)" `
        --data-binary $payload `
        $proxy
    }
    else {
      $raw = & curl.exe -sS -4 --http1.1 --max-time 30 `
        --data-urlencode "chat_id=$chatId" `
        --data-urlencode "text=$text" `
        --data-urlencode 'parse_mode=HTML' `
        --data-urlencode 'disable_web_page_preview=true' `
        "https://api.telegram.org/bot$token/sendMessage"
    }
    Write-Host "telegram send try=$i response=$raw"
    $json = $null
    try { $json = $raw | ConvertFrom-Json } catch { }
    if ($json -and $json.ok) { return $true }
    if ($json -and $json.error_code -eq 429) {
      $wait = 10
      if ($json.parameters -and $json.parameters.retry_after) { $wait = [int]$json.parameters.retry_after + 2 }
      Write-Host "telegram rate limited, waiting $wait sec"
      Start-Sleep -Seconds $wait
      continue
    }
    Start-Sleep -Seconds 5
  }
  return $false
}

$feed = Read-JsonFile 'data/codes.json'
$health = Read-JsonFile 'data/source-health.json'
if (-not $feed) {
  Write-Host 'No feed file; nothing to notify.'
  exit 0
}

$site = 'https://maxddonich.github.io/promolov/'
$stats = $feed.stats
$total = @($feed.codes).Count
$confirmed = if ($stats) { [int]$stats.confirmed } else { @($feed.codes | Where-Object { $_.verification -eq 'confirmed' }).Count }
$likely = if ($stats) { [int]$stats.likely } else { 0 }
$single = if ($stats) { [int]$stats.single } else { 0 }
$services = if ($stats) { [int]$stats.services } else { 0 }

if ($Mode -eq 'daily') {
  $healthSources = @()
  if ($health) { $healthSources = @($health.sources.PSObject.Properties) }
  $errors = @($healthSources | Where-Object { $_.Value.status -eq 'error' }).Count
  $empty = @($healthSources | Where-Object { $_.Value.status -eq 'empty' }).Count
  $ok = @($healthSources | Where-Object { $_.Value.status -eq 'ok' }).Count
  $text = @"
📊 <b>PromoLove за сутки</b>

Кодов: <b>$total</b>
Подтверждённых: <b>$confirmed</b>
Вероятных: <b>$likely</b>
Один источник: <b>$single</b>

Источников: <b>$($healthSources.Count)</b> (ок: $ok, ошибок: $errors, пусто: $empty)
Сервисов: <b>$services</b>
Обновлено: $(Html $feed.updatedAt)

<a href="$site">Открыть сайт</a>
"@
  $sent = Send-Ntfy $text 'default' 'bar_chart'
  if (-not $sent) { $sent = Send-Telegram $text }
  if (-not $sent) { Write-Host 'Daily notification was not sent.'; exit 1 }
  exit 0
}

$issues = New-Object System.Collections.Generic.List[string]
$recoveries = New-Object System.Collections.Generic.List[string]

if ($env:COLLECTOR_OUTCOME -eq 'failure') {
  $issues.Add('🔴 <b>Сборщик упал</b>: фид не обновился, сайт работает на прошлой версии.')
}
if ($env:VALIDATION_OUTCOME -eq 'failure') {
  $issues.Add('🔴 <b>Фид не прошёл проверку</b>: новые данные не опубликованы.')
}

$prevHealth = Read-GitJson 'data/source-health.json'
$prevMap = @{}
if ($prevHealth) {
  foreach ($p in $prevHealth.sources.PSObject.Properties) { $prevMap[$p.Name] = $p.Value }
}

if ($health) {
  foreach ($p in $health.sources.PSObject.Properties) {
    $name = $p.Name
    $cur = $p.Value
    $prev = $prevMap[$name]
    if (-not $prev) { continue }
    $curCount = [int]$cur.lastCount
    $prevCount = [int]$prev.lastCount
    $prevBad = ($prev.status -eq 'error' -or $prevCount -eq 0)

    if ($cur.status -eq 'error' -and $prev.status -ne 'error') {
      $issues.Add("🔴 <b>$(Html $name)</b>: источник упал. Кодов: $curCount, было: $prevCount.")
    }
    elseif ($curCount -eq 0 -and $prevCount -ge 3) {
      $issues.Add("🟠 <b>$(Html $name)</b>: 0 кодов, было: $prevCount.")
    }
    elseif ($curCount -lt [math]::Floor($prevCount * 0.5) -and $prevCount -ge 6) {
      $issues.Add("🟠 <b>$(Html $name)</b>: просадка до $curCount, было: $prevCount.")
    }

    if ($prevBad -and $cur.status -eq 'ok' -and $curCount -gt 0) {
      $recoveries.Add("✅ <b>$(Html $name)</b>: снова работает, $curCount кодов.")
    }
  }
}

$prevFeed = Read-GitJson 'data/codes.json'
if ($prevFeed -and $prevFeed.codes) {
  $prevTotal = @($prevFeed.codes).Count
  $prevConfirmed = if ($prevFeed.stats) { [int]$prevFeed.stats.confirmed } else { @($prevFeed.codes | Where-Object { $_.verification -eq 'confirmed' }).Count }
  if ($prevTotal -ge 50 -and $total -lt [math]::Floor($prevTotal * 0.6)) {
    $issues.Add("🔴 <b>Фид просел</b>: $total кодов, было $prevTotal.")
  }
  if ($prevConfirmed -ge 20 -and $confirmed -lt [math]::Floor($prevConfirmed * 0.7)) {
    $issues.Add("🟠 <b>Подтверждённых стало меньше</b>: $confirmed, было $prevConfirmed.")
  }
}

if ($issues.Count -eq 0 -and $recoveries.Count -eq 0) {
  Write-Host 'No alerts.'
  exit 0
}

$title = if ($issues.Count -gt 0) { '⚠️ <b>PromoLove: проблема</b>' } else { '✅ <b>PromoLove: восстановление</b>' }
$body = @()
if ($issues.Count -gt 0) { $body += ($issues | Select-Object -First 10) }
if ($recoveries.Count -gt 0) { $body += ($recoveries | Select-Object -First 6) }
$text = $title + "`n`n" + ($body -join "`n") + "`n`n<a href=`"$site`">Открыть сайт</a>"

$priority = if ($issues.Count -gt 0) { 'high' } else { 'default' }
$tags = if ($issues.Count -gt 0) { 'warning' } else { 'white_check_mark' }
$sent = Send-Ntfy $text $priority $tags
if (-not $sent) { $sent = Send-Telegram $text }
if (-not $sent) {
  Write-Host 'Alert notification was not sent.'
  exit 1
}
