# ============================================================
# PromoLov collector
# Собирает публичные промокоды на доставку еды с сайтов-агрегаторов
# и пишет их в data/codes.json в формате JSON-фида ПромоЛова.
#
# Запуск:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\collector.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\collector.ps1 -Force
#
# Скрипт не обходит капчи и авторизацию: читает только открытые страницы.
# ============================================================

[CmdletBinding()]
param(
  [string]$OutFile = '',
  [switch]$Force,
  [int]$MaxAgeMinutes = 45
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) { $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $OutFile) { $OutFile = Join-Path $scriptRoot 'data\codes.json' }

$script:UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36 PromoLov/1.0'
$script:Headers = @{
  'User-Agent'      = $script:UA
  'Accept'          = 'text/html,application/xhtml+xml'
  'Accept-Language' = 'ru-RU,ru;q=0.9,en;q=0.5'
}

$script:Sources = @(
  @{
    name = 'promokod.com'
    url  = 'https://promokod.com/coupon-store/eda-yandex-ru'
    kind = 'promokodcom'
  },
  @{
    name = 'promokod.com'
    url  = 'https://promokod.com/coupon-store/samokat-ru'
    kind = 'promokodcom'
  },
  @{
    name = 'promokod.com'
    url  = 'https://promokod.com/coupon-store/sbermarket-ru'
    kind = 'promokodcom'
  },
  @{
    name = 'promokod.com'
    url  = 'https://promokod.com/coupon-store/vkusvill-ru'
    kind = 'promokodcom'
  },
  @{
    name = 'promokod.com'
    url  = 'https://promokod.com/coupon-store/dodopizza-ru'
    kind = 'promokodcom'
  },
  @{
    name = 'promokod.com'
    url  = 'https://promokod.com/coupon-store/ozonfresh'
    kind = 'promokodcom'
  },
  @{
    name = 'promokod.com'
    url  = 'https://promokod.com/coupon-store/perekrestok-ru'
    kind = 'promokodcom'
  },
  @{
    name = 'promokod.com'
    url  = 'https://promokod.com/coupon-store/magnit-ru'
    kind = 'promokodcom'
  },
  @{
    name = 'promokod.com'
    url  = 'https://promokod.com/coupon-store/5ka-ru'
    kind = 'promokodcom'
  },
  @{
    name = 'ecosum.ru'
    url  = 'https://www.ecosum.ru/promokody-yandex-eda/'
    kind = 'ecosum'
  }
)

$pikabuPages = @('eda-yandex', 'samokat', 'vkusvill', 'dodopizza', 'perekrestok', '5ka')
foreach ($slug in $pikabuPages) {
  $script:Sources += @{
    name = 'promokod.pikabu.ru'
    url  = "https://promokod.pikabu.ru/shops/$slug"
    kind = 'pikabu'
  }
}

$kpPages = @(
  @{ url = 'https://www.kp.ru/promokod/yandex-eda'; service = 'Яндекс Еда' },
  @{ url = 'https://www.kp.ru/promokod/samokat/'; service = 'Самокат' },
  @{ url = 'https://www.kp.ru/promokod/vkusvill/'; service = 'ВкусВилл' },
  @{ url = 'https://www.kp.ru/promokod/pyaterochka/'; service = 'Пятёрочка' }
)
foreach ($page in $kpPages) {
  $script:Sources += @{
    name    = 'kp.ru'
    url     = $page.url
    kind    = 'kp'
    service = $page.service
  }
}

$script:Months = @{
  'января' = 1; 'февраля' = 2; 'марта' = 3; 'апреля' = 4;
  'мая' = 5; 'июня' = 6; 'июля' = 7; 'августа' = 8;
  'сентября' = 9; 'октября' = 10; 'ноября' = 11; 'декабря' = 12
}

function Write-Log {
  param([string]$Message)
  Write-Host ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $Message)
}

function Get-Html {
  param([string]$Url)
  $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -Headers $script:Headers -TimeoutSec 40
  $bytes = $response.RawContentStream.ToArray()
  if ($bytes.Length -eq 0) { return [string]$response.Content }
  return [Text.Encoding]::UTF8.GetString($bytes)
}

function Convert-HtmlToText {
  param([string]$Html)
  if (-not $Html) { return '' }
  $text = [Net.WebUtility]::HtmlDecode($Html)
  $text = [regex]::Replace($text, '(?is)<(script|style)[^>]*>.*?</\1>', ' ')
  $text = [regex]::Replace($text, '<[^>]+>', ' ')
  $text = [regex]::Replace($text, '\s+', ' ')
  return $text.Trim()
}

function ConvertTo-Number {
  param([string]$Value)
  $n = 0
  if ([int]::TryParse((($Value -replace '\s', '') -replace '[^\d]', ''), [ref]$n)) { return $n }
  return 0
}

function Get-MinOrder {
  param([string]$Text)
  $m = [regex]::Match($Text, '(?i)(?:от|От)\s+([\d\s]{2,})\s*(?:₽|руб(?:\.|лей|ля)?)')
  if (-not $m.Success) {
    $m = [regex]::Match($Text, '(?i)\(от\s*([\d\s]+)\)')
  }
  if ($m.Success) { return (ConvertTo-Number $m.Groups[1].Value) }
  return 0
}

function Get-ExpiryDays {
  param([string]$Text)
  if (-not $Text) { return $null }
  if ($Text -match '(?i)истекает\s+завтра') { return 1 }
  if ($Text -match '(?i)только\s+сегодня') { return 0 }
  if ($Text -match '(?i)бессрочн') { return $null }

  $dm = [regex]::Match($Text, '(?i)(?:до|по)\s+(\d{1,2})\.(\d{1,2})(?:\.(\d{4}))?')
  if ($dm.Success) {
    $year = (Get-Date).Year
    if ($dm.Groups[3].Success) { $year = [int]$dm.Groups[3].Value }
    try {
      $date = Get-Date -Year $year -Month ([int]$dm.Groups[2].Value) -Day ([int]$dm.Groups[1].Value) -Hour 23 -Minute 59
      if (-not $dm.Groups[3].Success -and $date.Date -lt (Get-Date).Date) { return -1 }
      return [int][math]::Ceiling(($date - (Get-Date)).TotalDays)
    } catch { return $null }
  }

  $m = [regex]::Match($Text, '(?i)до\s+(\d{1,2})\s+([а-яё]+)(?:\s+(\d{4}))?')
  if ($m.Success) {
    $monthName = $m.Groups[2].Value.ToLower()
    $month = $script:Months[$monthName]
    if ($month) {
      $year = (Get-Date).Year
      if ($m.Groups[3].Success) { $year = [int]$m.Groups[3].Value }
      $date = Get-Date -Year $year -Month $month -Day ([int]$m.Groups[1].Value) -Hour 23 -Minute 59
      if (-not $m.Groups[3].Success -and $date.Date -lt (Get-Date).Date) { return -1 }
      return [int][math]::Ceiling(($date - (Get-Date)).TotalDays)
    }
  }
  return $null
}

function Get-DiscountFromTitle {
  param([string]$Title)
  $percent = [regex]::Match($Title, '(\d+)\s*%')
  $rub = [regex]::Match($Title, '([\d\s]+)\s*(?:₽|руб)')

  if ($rub.Success -and (-not $percent.Success -or $rub.Index -lt $percent.Index)) {
    $value = ConvertTo-Number $rub.Groups[1].Value
    if ($value -gt 0) { return [ordered]@{ type = 'fixed'; value = $value; maxDiscount = 0 } }
  }
  if ($percent.Success) {
    return [ordered]@{ type = 'percent'; value = [int]$percent.Groups[1].Value; maxDiscount = 0 }
  }
  if ($Title -match '(?i)бесплатн\w*\s+доставк') {
    return [ordered]@{ type = 'delivery'; value = 0; maxDiscount = 0 }
  }
  return $null
}

function Get-DiscountInfo {
  param([string]$Discount, [string]$Text)
  $info = [ordered]@{ type = 'fixed'; value = 0; maxDiscount = 0 }
  $d = ($Discount + ' ' + $Text).Trim()

  if ($d -match '(\d+)\s*%') {
    $info.type = 'percent'
    $info.value = [int]$Matches[1]
  }
  elseif ($d -match '([\d\s]+)\s*₽') {
    $info.type = 'fixed'
    $info.value = ConvertTo-Number $Matches[1]
  }
  elseif ($d -match '(?i)бесплатн\w*\s+доставк') {
    $info.type = 'delivery'
    $info.value = 0
  }

  if ($info.type -eq 'percent') {
    $m = [regex]::Match($d, '(?i)(?:не\s+более|максимальн\w*\s+скидк\w*[^0-9]{0,20})\s*([\d\s]+)\s*(?:₽|руб)')
    if ($m.Success) { $info.maxDiscount = ConvertTo-Number $m.Groups[1].Value }
  }
  return $info
}

function Test-Food {
  param([string]$Text)
  $t = $Text.ToLower()
  $negative = '(аптек|\bвита\b|косметик|подружк|цветочн|цвет(ы|ов|ам|ами)?\b|ювелир|товар\w*\s+для\s+дома|хобби|спорт\w*|техник|электроник|одежд|обув|игрушк|зоотовар|канцтовар|бытов|куулклевер|доктор\s+столетов|оптик|очк|кешбэк|рив\s+гош)'
  $positive = '(вкусвилл|дикси|магнит|перекр[её]ст|пят[её]роч|азбука\s+вкуса|лент|ашан|самокат|купер|лавка|монетк|верный|dolce\s+milk|додо|ресторан|кафе|фастфуд|блюд|продукт|супермаркет|гипермаркет|гастроном|пицц|суши|доставк|заказ|еда\b)'
  if ($t -match $negative) { return $false }
  return [bool]($t -match $positive)
}

function Test-RubPrice {
  param([string]$Text)
  if ($Text -match '(?i)(BYN|₸|тенге|\bсум\b|\bсом\b|бел\.?\s*руб)') { return $false }
  return $true
}

function Get-ExistingUsers {
  param([string]$Text)
  $t = $Text.ToLower()
  if ($t -match 'перв\w*\s+и\s+повторн' -or $t -match 'повторн\w*\s+и\s+перв') { return $true }
  if ($t -match 'не\s+пользовал\w*\s+сервис|более\s+года') { return $false }
  if ($t -match 'перв\w*\s+заказ' -or $t -match 'нов\w*\s+клиент') { return $false }
  return $true
}

function Get-WholeCart {
  param([string]$Text, [string]$Type)
  if ($Type -eq 'delivery') { return $false }
  $t = $Text.ToLower()
  if ($t -match 'выбранн|отдельн|конкретн|специальн\w*\s+списк|определенн|выделенн') { return $false }
  if ($t -match 'раздел|отметк|подборк|категор|готов\w*\s+ед|товар\w*\s+из|ассортимент|линейк|меню') { return $false }
  if ($t -match 'пицц|рыб|колбас|молок|мяс|морепродукт|хлеб|выпечк|кофе|сладк|напит|овощ|фрукт|алкогол|витамин') { return $false }
  return $true
}

function Get-Cities {
  param([string]$Text)
  if (-not $Text) { return @() }
  $t = $Text.ToLower()
  if ($t -match 'по\s+рф|по\s+всей\s+россии|по\s+россии|все\s+города|всероссийск') { return @() }

  $map = [ordered]@{
    'Москва'              = 'москв'
    'Санкт-Петербург'     = 'санкт-петербург|петербург|\bспб\b|ленинградск'
    'Воронеж'             = 'воронеж'
    'Ростов-на-Дону'      = 'ростов'
    'Таганрог'            = 'таганрог'
    'Сочи'                = 'сочи'
    'Адлер'               = 'адлер'
    'Лазаревское'         = 'лазаревск'
    'Красная Поляна'      = 'красн\w*\s+полян'
    'Эсто-Садок'          = 'эсто-садок|эстосадок'
    'Казань'              = 'казан'
    'Екатеринбург'        = 'екатеринбург'
    'Нижний Новгород'     = 'нижн\w*\s+новгород'
    'Новосибирск'         = 'новосибирск'
    'Самара'              = 'самар'
    'Краснодар'           = 'краснодар'
    'Уфа'                 = 'уф[еыу]'
    'Пермь'               = '\bперм'
    'Челябинск'           = 'челябинск'
    'Владивосток'         = 'владивосток'
    'Калининград'         = 'калининград'
    'Тула'                = 'тул[еыу]'
    'Ярославль'           = 'ярославл'
    'Иркутск'             = 'иркутск'
    'Омск'                = '\bомск'
    'Тюмень'              = 'тюмен'
    'Саратов'             = 'саратов'
    'Волгоград'           = 'волгоград'
    'Калуга'              = 'калуг'
    'Красноярск'          = 'красноярск'
    'Томск'               = '\bтомск'
    'Рязань'              = 'рязан'
    'Пенза'               = 'пенз'
    'Липецк'              = 'липецк'
    'Киров'               = '\bкиров'
    'Барнаул'             = 'барнаул'
    'Хабаровск'           = 'хабаровск'
    'Тольятти'            = 'тольятти'
    'Ижевск'              = 'ижевск'
    'Ульяновск'           = 'ульяновск'
    'Балаково'            = 'балаков'
    'Якутск'              = 'якутск'
    'Владимир'            = 'владимир'
    'Бузулук'             = 'бузулук'
    'Березники'           = 'березник'
    'Когалым'             = 'когалым'
    'Сургут'              = 'сургут'
    'Нижневартовск'       = 'нижневартовск'
    'Чита'                = 'чита'
    'Улан-Удэ'            = 'улан-удэ'
    'Махачкала'           = 'махачкал'
    'Ставрополь'          = 'ставропол'
    'Белгород'            = 'белгород'
    'Курск'               = 'курск'
    'Орёл'                = 'ор[её]л'
    'Брянск'              = 'брянск'
    'Смоленск'            = 'смоленск'
    'Тверь'               = '\bтвер'
    'Иваново'             = 'иванов'
    'Кострома'            = 'костром'
    'Архангельск'         = 'архангельск'
    'Мурманск'            = 'мурманск'
    'Петрозаводск'        = 'петрозаводск'
    'Вологда'             = 'вологд'
    'Череповец'           = 'череповец'
    'Йошкар-Ола'          = 'йошкар'
    'Чебоксары'           = 'чебоксар'
    'Саранск'             = 'саранск'
    'Тамбов'              = 'тамбов'
    'Астрахань'           = 'астрахан'
    'Оренбург'            = 'оренбург'
    'Курган'              = 'курган'
    'Кемерово'            = 'кемеров'
    'Новокузнецк'         = 'новокузнецк'
    'Бийск'               = 'бийск'
    'Абакан'              = 'абакан'
    'Братск'              = 'братск'
    'Ангарск'             = 'ангарск'
    'Петропавловск-Камчатский' = 'петропавловск-камчат'
    'Южно-Сахалинск'      = 'южно-сахалинск'
    'Комсомольск-на-Амуре' = 'комсомольск'
    'Находка'             = 'находк'
    'Уссурийск'           = 'уссурийск'
  }

  $result = @()
  foreach ($name in $map.Keys) {
    if ($t -match $map[$name]) { $result += $name }
  }
  if ($Text -match 'московск\w*\s+област|\bМО\b|подмосковь') { $result += 'Московская область' }
  if ($Text -match 'ленинградск\w*\s+област|\bЛО\b') { $result += 'Ленинградская область' }
  return @($result | Select-Object -Unique)
}

function Get-Collections {
  param([bool]$ExistingUsers, [bool]$WholeCart)
  $result = @()
  if ($ExistingUsers) { $result += 'returning' } else { $result += 'firstOrder' }
  if ($WholeCart) { $result += 'wholeCart' }
  return $result
}

function Resolve-Service {
  param([string]$Name)
  $n = ($Name -replace '\s+', ' ').Trim()
  if (-not $n) { return 'Яндекс Еда' }
  switch -Regex ($n) {
    '^(Сбермаркет|Купер)$' { return 'Купер' }
    '^Додо' { return 'Додо Пицца' }
    '^Ozon' { return 'Ozon Fresh' }
    '^Пят' { return 'Пятёрочка' }
    '^Магнит' { return 'Магнит' }
    '^ВкусВилл' { return 'ВкусВилл' }
    '^Перекр' { return 'Перекрёсток' }
    '^Самокат' { return 'Самокат' }
    '^Яндекс' { return 'Яндекс Еда' }
  }
  return $n
}

function New-PromoEntry {
  param(
    [string]$Service,
    [string]$Code,
    [string]$Type,
    [int]$Value,
    [int]$MaxDiscount,
    [int]$MinOrder,
    [bool]$FreeDelivery,
    [string]$Title,
    $ExpiresInDays,
    [int]$Works,
    [bool]$ExistingUsers,
    [bool]$WholeCart,
    [string[]]$Cities = @(),
    [bool]$CityRestricted = $false,
    [string[]]$Conditions,
    [string]$SourceName,
    [string]$SourceUrl
  )

  return [ordered]@{
    service        = $Service
    code           = $Code
    type           = $Type
    value          = $Value
    maxDiscount    = $MaxDiscount
    minOrder       = $MinOrder
    freeDelivery   = $FreeDelivery
    deliveryCost   = 149
    title          = $Title
    category       = @('доставка еды', 'собрано с сайта')
    conditions     = $Conditions
    expiresInDays  = $ExpiresInDays
    works          = $Works
    fails          = 0
    existingUsers  = $ExistingUsers
    wholeCart      = $WholeCart
    cities         = @($Cities)
    cityRestricted = $CityRestricted
    collections    = (Get-Collections -ExistingUsers $ExistingUsers -WholeCart $WholeCart)
    sourceName     = $SourceName
    sourceUrl      = $SourceUrl
  }
}

# ---------- promokod.com ----------

function Get-PromokodComCodes {
  param([string]$Html, [string]$Url, [string]$SourceName)

  $items = @()
  $serviceName = 'Яндекс Еда'
  $storeMatch = [regex]::Match($Html, 'data-store-name="([^"]+)"')
  if ($storeMatch.Success) {
    $serviceName = Resolve-Service ([Net.WebUtility]::HtmlDecode($storeMatch.Groups[1].Value))
  }
  $chunks = [regex]::Split($Html, '<div class="coupon-wrap')

  for ($i = 1; $i -lt $chunks.Count; $i++) {
    $chunk = $chunks[$i]

    $codeMatch = [regex]::Match($chunk, 'data-code="(?<v>[A-Za-z0-9_-]{3,24})"')
    if (-not $codeMatch.Success) { continue }
    $code = $codeMatch.Groups['v'].Value.ToUpper()

    $titleHtml = [regex]::Match($chunk, '(?s)<h3 class="coupon-title">(?<v>.*?)</h3>').Groups['v'].Value
    $title = Convert-HtmlToText $titleHtml
    if (-not $title) { continue }
    $title = [regex]::Replace($title, '\s*\(от\s*[\d\s]+\)', '')

    $desc = Convert-HtmlToText ([regex]::Match($chunk, '(?s)<p class="detail-desc">(?<v>.*?)</p>').Groups['v'].Value)
    $discount = Convert-HtmlToText ([regex]::Match($chunk, '<div class="discount">(?<v>[^<]+)</div>').Groups['v'].Value)
    $valid = Convert-HtmlToText ([regex]::Match($chunk, '<span class="v-full">(?<v>.*?)</span>').Groups['v'].Value)
    $blockText = Convert-HtmlToText $chunk
    $fullText = $title + ' ' + $desc + ' ' + $blockText

    $hasDiscount = $title -match '(?i)(скидк|выгод|эконом|минус|промокод\s+на|купон\s+со\s+скидк|\d+\s*%\s+на|\d[\d\s]*\s*(₽|руб)\s+на\s+(первый|повторный|заказ|покупк))'
    if (-not $hasDiscount) { continue }

    if (-not (Test-Food $fullText)) { continue }

    $days = Get-ExpiryDays ($valid + ' ' + $blockText)
    if ($null -ne $days -and $days -lt 0) { continue }
    if ($null -eq $days -and ($valid + ' ' + $blockText) -match '(?i)действует\s+до') { continue }

    $info = Get-DiscountFromTitle $title
    if ($null -eq $info) {
      $info = Get-DiscountInfo -Discount $discount -Text ($title + ' ' + $desc)
    }
    elseif ($info.type -eq 'percent') {
      $fullInfo = Get-DiscountInfo -Discount $discount -Text ($title + ' ' + $desc)
      $info.maxDiscount = $fullInfo.maxDiscount
    }
    if ($info.value -le 0 -and $info.type -ne 'delivery') { continue }

    $minOrder = Get-MinOrder ($title + ' ' + $desc)
    $existing = Get-ExistingUsers ($title + ' ' + $desc)
    $wholeCart = Get-WholeCart ($title + ' ' + $desc) $info.type
    $cities = @(Get-Cities ($title + ' ' + $desc))
    $cityRestricted = $cities.Count -gt 0
    $freeDelivery = [bool]($fullText -match '(?i)бесплатн\w*\s+доставк')
    $works = 0
    $usesMatch = [regex]::Match($chunk, 'data-uses="(?<v>\d+)"')
    if ($usesMatch.Success) { $works = [int]$usesMatch.Groups['v'].Value }

    $conditions = @()
    if ($desc) { $conditions += $desc }
    if ($minOrder -gt 0) { $conditions += ('Минимальный заказ — от ' + $minOrder + ' ₽') }
    if ($null -ne $days -and $days -ge 0) { $conditions += ('Срок действия — примерно ' + $days + ' дн.') }

    $items += New-PromoEntry -Service $serviceName -Code $code -Type $info.type -Value $info.value `
      -MaxDiscount $info.maxDiscount -MinOrder $minOrder -FreeDelivery $freeDelivery `
      -Title $title -ExpiresInDays $days -Works $works -ExistingUsers $existing -WholeCart $wholeCart `
      -Cities $cities -CityRestricted $cityRestricted `
      -Conditions $conditions -SourceName $SourceName -SourceUrl $Url
  }

  return $items
}

# ---------- ecosum.ru ----------

function Get-EcosumCodes {
  param([string]$Html, [string]$Url, [string]$SourceName)

  $items = @()
  $found = [regex]::Matches($Html, '(?s)<p>\s*\d+\.\s*<code>(?<code>[A-Za-z0-9_-]{3,24})</code>(?<rest>.*?)</p>')

  foreach ($match in $found) {
    $code = $match.Groups['code'].Value.ToUpper()
    $desc = Convert-HtmlToText $match.Groups['rest'].Value
    $desc = [regex]::Replace($desc, '^\s*\[[^\]]*\]\s*[–—-]\s*', '')
    $desc = [regex]::Replace($desc, '^\s*[–—-]\s*', '')
    if (-not $desc) { continue }
    if (-not (Test-Food $desc)) { continue }

    $days = Get-ExpiryDays $desc
    if ($null -ne $days -and $days -lt 0) { continue }
    if ($null -eq $days -and $desc -match '(?i)действует\s+до') { continue }

    $title = ($desc -split '(?i)\.?\s*Действует до', 2)[0].Trim()
    if (-not $title) { $title = $desc }
    $title = [regex]::Replace($title, '\s*\(от\s*[\d\s]+\)', '')

    $info = Get-DiscountFromTitle $title
    if ($null -eq $info) {
      $info = Get-DiscountInfo -Discount $desc -Text $desc
    }
    elseif ($info.type -eq 'percent') {
      $fullInfo = Get-DiscountInfo -Discount $desc -Text $desc
      $info.maxDiscount = $fullInfo.maxDiscount
    }
    if ($info.value -le 0 -and $info.type -ne 'delivery') { continue }

    $minOrder = Get-MinOrder $desc
    $existing = Get-ExistingUsers $desc
    $wholeCart = Get-WholeCart $desc $info.type
    $cities = @(Get-Cities $desc)
    $cityRestricted = $cities.Count -gt 0
    $freeDelivery = [bool]($desc -match '(?i)бесплатн\w*\s+доставк')

    $conditions = @()
    $conditions += $desc
    if ($minOrder -gt 0) { $conditions += ('Минимальный заказ — от ' + $minOrder + ' ₽') }

    $items += New-PromoEntry -Service 'Яндекс Еда' -Code $code -Type $info.type -Value $info.value `
      -MaxDiscount $info.maxDiscount -MinOrder $minOrder -FreeDelivery $freeDelivery `
      -Title $title -ExpiresInDays $days -Works 0 -ExistingUsers $existing -WholeCart $wholeCart `
      -Cities $cities -CityRestricted $cityRestricted `
      -Conditions $conditions -SourceName $SourceName -SourceUrl $Url
  }

  return $items
}

function Get-BalancedArray {
  param([string]$Text, [int]$Start)
  if ($Start -lt 0 -or $Start -ge $Text.Length -or $Text[$Start] -ne '[') { return $null }
  $depth = 0
  $inString = $false
  $escaped = $false
  for ($i = $Start; $i -lt $Text.Length; $i++) {
    $c = $Text[$i]
    if ($inString) {
      if ($escaped) { $escaped = $false }
      elseif ($c -eq '\') { $escaped = $true }
      elseif ($c -eq '"') { $inString = $false }
    }
    else {
      if ($c -eq '"') { $inString = $true }
      elseif ($c -eq '[') { $depth++ }
      elseif ($c -eq ']') {
        $depth--
        if ($depth -eq 0) { return $Text.Substring($Start, $i - $Start + 1) }
      }
    }
  }
  return $null
}

function Get-PikabuCodes {
  param([string]$Html, [string]$Url, [string]$SourceName)

  $items = @()
  $idx = $Html.IndexOf('"coupons":')
  if ($idx -lt 0) { return $items }
  $arrStart = $Html.IndexOf('[', $idx)
  $json = Get-BalancedArray $Html $arrStart
  if (-not $json) { return $items }

  try { $coupons = $json | ConvertFrom-Json } catch { return $items }

  foreach ($coupon in $coupons) {
    $code = ([string]$coupon.promoCode).Trim()
    if (-not $code) { continue }
    if ($code -notmatch '^[A-Za-z0-9_-]{3,32}$') { continue }

    $title = (Convert-HtmlToText ([string]$coupon.title)).Trim()
    $desc = (Convert-HtmlToText ([string]$coupon.description)).Trim()
    $full = $title + ' ' + $desc

    if ($title -notmatch '(?i)(скидк|выгод|эконом|дисконт|минус|купон\s+на|промокод\s+на|^-\s*\d|\d+\s*%|бесплатн\w*\s+доставк)') { continue }
    if (-not (Test-RubPrice $full)) { continue }
    if (-not (Test-Food $full)) { continue }

    $days = $null
    if ($coupon.endDate -and [long]$coupon.endDate -gt 0) {
      $end = [DateTimeOffset]::FromUnixTimeSeconds([long]$coupon.endDate).LocalDateTime
      $days = [int][math]::Ceiling(($end - (Get-Date)).TotalDays)
      if ($days -lt 0) { continue }
    }

    $info = [ordered]@{ type = 'fixed'; value = 0; maxDiscount = 0 }
    if ([int]$coupon.benefitType -eq 1 -or [int]$coupon.discountPercent -gt 0) {
      $info.type = 'percent'
      $info.value = [int]$coupon.discountPercent
      if ($info.value -le 0) {
        $fromTitle = Get-DiscountFromTitle $title
        if ($fromTitle -and $fromTitle.type -eq 'percent') { $info.value = $fromTitle.value }
      }
    }
    elseif ([int]$coupon.benefitType -eq 2) {
      $info.type = 'fixed'
      $info.value = ConvertTo-Number ([string]$coupon.discountAmount)
      if ($info.value -le 0) {
        $fromTitle = Get-DiscountFromTitle $title
        if ($fromTitle) { $info.type = $fromTitle.type; $info.value = $fromTitle.value }
      }
    }

    $freeDelivery = [bool]($full -match '(?i)бесплатн\w*\s+доставк')
    if ($info.value -le 0 -and $freeDelivery) { $info.type = 'delivery' }
    if ($info.value -le 0 -and $info.type -ne 'delivery') { continue }

    if ($info.type -eq 'percent') {
      $discountInfo = Get-DiscountInfo -Discount $full -Text $full
      $info.maxDiscount = $discountInfo.maxDiscount
    }

    $minOrder = Get-MinOrder $full
    $existing = $true
    if ($coupon.forRepeatPurchase -eq $false) { $existing = $false }
    elseif (($full -match '(?i)перв\w*\s+заказ') -and ($full -notmatch '(?i)перв\w*\s+и\s+повторн|повторн\w*\s+и\s+перв')) { $existing = $false }
    $wholeCart = Get-WholeCart $full $info.type
    $cities = @(Get-Cities $full)
    $cityRestricted = $cities.Count -gt 0

    $conditions = @()
    if ($desc) { $conditions += $desc }
    if ($minOrder -gt 0) { $conditions += ('Минимальный заказ — от ' + $minOrder + ' ₽') }
    if ($null -ne $days -and $days -ge 0) { $conditions += ('Срок действия — примерно ' + $days + ' дн.') }

    $works = 0
    if ($coupon.clickCount) { $works = [int]$coupon.clickCount }

    $items += New-PromoEntry -Service (Resolve-Service ([string]$coupon.shop.altTitle)) -Code $code `
      -Type $info.type -Value $info.value -MaxDiscount $info.maxDiscount -MinOrder $minOrder `
      -FreeDelivery $freeDelivery -Title $title -ExpiresInDays $days -Works $works `
      -ExistingUsers $existing -WholeCart $wholeCart -Cities $cities -CityRestricted $cityRestricted `
      -Conditions $conditions -SourceName $SourceName -SourceUrl $Url
  }

  return $items
}

function Get-KpCodes {
  param([string]$Html, [string]$Url, [string]$SourceName, [string]$Service)

  $items = @()
  $parts = [regex]::Split($Html, '<div class="retailer-coupon"')

  for ($i = 1; $i -lt $parts.Count; $i++) {
    $chunk = $parts[$i]
    $codeMatch = [regex]::Match($chunk, 'retailer-coupon__teaser-code">([^<]+)</span>')
    if (-not $codeMatch.Success) { continue }
    $code = $codeMatch.Groups[1].Value.Trim()
    if (-not $code) { continue }

    $titleHtml = [regex]::Match($chunk, '(?s)<div class="retailer-coupon__title">(.*?)</div>\s*<div class="estimated-time').Groups[1].Value
    $title = (Convert-HtmlToText $titleHtml).Trim()
    if (-not $title) { continue }

    $desc = (Convert-HtmlToText ([regex]::Match($chunk, '(?s)<div class="retailer-coupon__description-content"[^>]*>(.*?)</div>').Groups[1].Value)).Trim()
    $validity = (Convert-HtmlToText ([regex]::Match($chunk, 'estimated-time__time-text[^>]*>(.*?)</div>').Groups[1].Value)).Trim()
    $full = $title + ' ' + $desc + ' ' + $validity

    if (-not (Test-RubPrice $full)) { continue }
    if (-not (Test-Food $full)) { continue }
    if ($title -notmatch '(?i)(скидк|выгод|эконом|минус|^-\s*\d|промокод\s+на)') { continue }

    $days = Get-ExpiryDays $validity
    if ($null -ne $days -and $days -lt 0) { continue }

    $info = Get-DiscountFromTitle $title
    if ($null -eq $info) { $info = Get-DiscountInfo -Discount $title -Text $full }
    if ($info.value -le 0 -and $info.type -ne 'delivery') { continue }

    $minOrder = Get-MinOrder $full
    $existing = Get-ExistingUsers $full
    $wholeCart = Get-WholeCart $full $info.type
    $cities = @(Get-Cities $full)
    $cityRestricted = $cities.Count -gt 0
    $freeDelivery = [bool]($full -match '(?i)бесплатн\w*\s+доставк')

    $works = 0
    $clicksMatch = [regex]::Match($chunk, '(?s)estimated-time__clicks-text.*?(\d+)\s*раз')
    if ($clicksMatch.Success) { $works = [int]$clicksMatch.Groups[1].Value }

    $conditions = @()
    if ($desc) { $conditions += $desc }
    if ($validity) { $conditions += $validity }
    if ($minOrder -gt 0) { $conditions += ('Минимальный заказ — от ' + $minOrder + ' ₽') }

    $items += New-PromoEntry -Service $Service -Code $code -Type $info.type -Value $info.value `
      -MaxDiscount $info.maxDiscount -MinOrder $minOrder -FreeDelivery $freeDelivery `
      -Title $title -ExpiresInDays $days -Works $works -ExistingUsers $existing -WholeCart $wholeCart `
      -Cities $cities -CityRestricted $cityRestricted -Conditions $conditions `
      -SourceName $SourceName -SourceUrl $Url
  }

  return $items
}

# ---------- main ----------

if (-not $Force -and (Test-Path $OutFile)) {
  $age = (Get-Date) - (Get-Item $OutFile).LastWriteTime
  if ($age.TotalMinutes -lt $MaxAgeMinutes) {
    Write-Log ('Feed is fresh ({0:N0} min), skipping. Use -Force to refresh.' -f $age.TotalMinutes)
    exit 0
  }
}

$collected = @()

foreach ($source in $script:Sources) {
  try {
    Write-Log ('Fetching ' + $source.name + ' ...')
    $html = Get-Html $source.url
    if ($source.kind -eq 'promokodcom') {
      $found = @(Get-PromokodComCodes -Html $html -Url $source.url -SourceName $source.name)
    }
    elseif ($source.kind -eq 'pikabu') {
      $found = @(Get-PikabuCodes -Html $html -Url $source.url -SourceName $source.name)
    }
    elseif ($source.kind -eq 'kp') {
      $found = @(Get-KpCodes -Html $html -Url $source.url -SourceName $source.name -Service $source.service)
    }
    else {
      $found = @(Get-EcosumCodes -Html $html -Url $source.url -SourceName $source.name)
    }
    Write-Log ('  ' + $found.Count + ' codes from ' + $source.name)
    $collected += $found
  }
  catch {
    Write-Log ('  ' + $source.name + ' failed: ' + $_.Exception.Message)
  }
}

if ($collected.Count -eq 0) {
  Write-Log 'No codes collected; keeping the previous feed.'
  exit 1
}

$unique = @{}
foreach ($item in $collected) {
  $key = ($item.code + '|' + $item.service).ToUpper()
  if (-not $unique.ContainsKey($key)) {
    $unique[$key] = $item
  }
  elseif ($unique[$key].works -lt $item.works) {
    $unique[$key] = $item
  }
}

$final = @($unique.Values | Sort-Object -Property @(
  @{ Expression = { $_.existingUsers }; Descending = $true },
  @{ Expression = { $_.value }; Descending = $true },
  @{ Expression = { $_.code }; Descending = $false }
))

$directory = Split-Path -Parent $OutFile
if (-not (Test-Path $directory)) {
  New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

$payload = [ordered]@{
  updatedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
  generator = 'PromoLov collector'
  sources   = @($script:Sources | ForEach-Object { [ordered]@{ name = $_.name; url = $_.url } })
  codes     = $final
}

$json = $payload | ConvertTo-Json -Depth 8
$tempFile = $OutFile + '.tmp'
[IO.File]::WriteAllText($tempFile, $json, (New-Object Text.UTF8Encoding($false)))
Move-Item -LiteralPath $tempFile -Destination $OutFile -Force

Write-Log ('Saved ' + $final.Count + ' unique codes to ' + $OutFile)
