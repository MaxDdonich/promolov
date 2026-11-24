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
$script:BrowserUA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36'
$script:Headers = @{
  'User-Agent'      = $script:BrowserUA
  'Accept'          = 'text/html,application/xhtml+xml'
  'Accept-Language' = 'ru-RU,ru;q=0.9,en;q=0.5'
}
$script:FetchProxyUrl = $env:PROMOLOV_FETCH_PROXY_URL
$script:FetchProxySecret = $env:PROMOLOV_FETCH_PROXY_SECRET

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

$pikabuPages = @('eda-yandex', 'samokat', 'vkusvill', 'dodopizza', 'perekrestok', '5ka', 'sbermarket', 'ozon-fresh')
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

$script:Sources += @{
  name = 'promokodi.komukupon.ru'
  url  = 'https://promokodi.komukupon.ru/categories/produkty-i-eda/'
  kind = 'komukupon'
}
$script:Sources += @{
  name = 'promokodex.ru'
  url  = 'https://www.promokodex.ru/actions/edim-doma'
  kind = 'promokodex'
}

$promokodSitePages = @(
  @{ url = 'https://promokod.site/vkusvill/'; service = 'ВкусВилл' },
  @{ url = 'https://promokod.site/vkusmil/'; service = 'ВкусМил' }
)
foreach ($page in $promokodSitePages) {
  $script:Sources += @{
    name    = 'promokod.site'
    url     = $page.url
    kind    = 'promokodsite'
    service = $page.service
  }
}

$promokodStorePages = @(
  'https://promokod.store/promokody/eda-i-napitki',
  'https://promokod.store/promokody/eda-i-napitki?page=2',
  'https://promokod.store/promokody/eda-i-napitki?page=3',
  'https://promokod.store/promokody/eda-i-napitki?page=4',
  'https://promokod.store/promokody/eda-i-napitki?page=5',
  'https://promokod.store/promokody/eda-i-napitki?page=6',
  'https://promokod.store/promokody/eda-i-napitki?page=7',
  'https://promokod.store/promokody/eda-i-napitki?page=8'
)
$storeIndex = 0
foreach ($u in $promokodStorePages) {
  $storeIndex++
  $script:Sources += @{
    name  = 'promokod.store · Еда ' + $storeIndex
    url   = $u
    kind  = 'promokodstore'
    group = 'promokod.store'
  }
}

$script:Sources += @{
  name  = 'promocodex.ru · Еда'
  url   = 'https://promocodex.ru/categories/food/'
  kind  = 'promocodex'
  group = 'promocodex.ru'
}
$script:Sources += @{
  name  = 'promocodex.ru · Рестораны'
  url   = 'https://promocodex.ru/categories/restaurants/'
  kind  = 'promocodex'
  group = 'promocodex.ru'
}
$script:Sources += @{
  name  = 'promocodex.ru · Суши'
  url   = 'https://promocodex.ru/categories/sushi/'
  kind  = 'promocodex'
  group = 'promocodex.ru'
}

$okodoPages = @(
  @{ label = 'Яндекс Еда'; url = 'https://okodo.ru/yandex-eda/' },
  @{ label = 'Деливери'; url = 'https://okodo.ru/deliveri/' },
  @{ label = 'Самокат'; url = 'https://okodo.ru/samokat/' },
  @{ label = 'Яндекс Лавка'; url = 'https://okodo.ru/yandex-lavka/' },
  @{ label = 'Перекрёсток'; url = 'https://okodo.ru/perekrestok/' },
  @{ label = 'Магнит'; url = 'https://okodo.ru/magnit/' },
  @{ label = 'Ашан'; url = 'https://okodo.ru/auchan/' },
  @{ label = 'Глобус'; url = 'https://okodo.ru/globus/' },
  @{ label = 'Метро'; url = 'https://okodo.ru/metro/' },
  @{ label = "Rostic's"; url = 'https://okodo.ru/rostics/' },
  @{ label = 'Sushi Master'; url = 'https://okodo.ru/sushi-master/' }
)
foreach ($page in $okodoPages) {
  $script:Sources += @{
    name  = 'okodo.ru · ' + $page.label
    url   = $page.url
    kind  = 'okodo'
    group = 'okodo.ru'
  }
}

$script:Sources += @{
  name  = 'okodo.ru · Все коды'
  url   = 'https://okodo.ru/'
  kind  = 'okodo'
  group = 'okodo.ru'
}
$script:Sources += @{
  name  = 'promokodikov.ru'
  url   = 'https://promokodikov.ru/category/dostavka-edy/'
  kind  = 'promokodikov'
}
$script:Sources += @{
  name = 'pickpoint.ru'
  url  = 'https://pickpoint.ru/promokod/category/dostavka-edi/'
  kind = 'pickpoint'
}
$script:Sources += @{
  name = 'fooody.ru'
  url  = 'https://fooody.ru/moskva/promo/'
  kind = 'fooody'
}

$telegramChannels = @(
  @{ channel = 'promokod_rostics'; group = 'tg-rostics' },
  @{ channel = 'promokod_perekrestok'; group = 'tg-perekrestok' },
  @{ channel = 'promokody_skidki'; group = 'tg-generic-1' },
  @{ channel = 'promokody'; group = 'tg-generic-2' },
  @{ channel = 'promokod_yakitoria'; group = 'tg-yakitoria' },
  @{ channel = 'promokod_growfood'; group = 'tg-growfood' },
  @{ channel = 'promokod_vkusvill'; group = 'tg-vkusvill' },
  @{ channel = 'promokod_tanuki'; group = 'tg-tanuki' },
  @{ channel = 'promokod_kfc'; group = 'tg-kfc' },
  @{ channel = 'promokod_magnit'; group = 'tg-magnit' },
  @{ channel = 'promokod_vkusnoitochka'; group = 'tg-vkusno' },
  @{ channel = 'promokod_papajohns'; group = 'tg-papajohns' }
)
foreach ($tg in $telegramChannels) {
  $script:Sources += @{
    name    = 't.me/' + $tg.channel
    url     = 'https://t.me/s/' + $tg.channel
    kind    = 'telegram'
    channel = $tg.channel
    group   = $tg.group
  }
}

$script:Months = @{
  'января' = 1; 'февраля' = 2; 'марта' = 3; 'апреля' = 4;
  'мая' = 5; 'июня' = 6; 'июля' = 7; 'августа' = 8;
  'сентября' = 9; 'октября' = 10; 'ноября' = 11; 'декабря' = 12
}
$script:MonthStems = @{
  'янв' = 1; 'фев' = 2; 'мар' = 3; 'апр' = 4; 'май' = 5; 'мая' = 5;
  'июн' = 6; 'июл' = 7; 'авг' = 8; 'сен' = 9; 'окт' = 10; 'ноя' = 11; 'дек' = 12
}

function Write-Log {
  param([string]$Message)
  Write-Host ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $Message)
}

function Get-Html {
  param([string]$Url)
  try {
    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -Headers $script:Headers -TimeoutSec 40
    $bytes = $response.RawContentStream.ToArray()
    if ($bytes.Length -eq 0) { return [string]$response.Content }
    return [Text.Encoding]::UTF8.GetString($bytes)
  }
  catch {
    $tmp = Join-Path $env:TEMP ('html-' + [guid]::NewGuid().ToString('N') + '.html')
    try {
      $status = & curl.exe -s -L --compressed --http1.1 --max-time 40 -A $script:BrowserUA -H 'Accept-Language: ru-RU,ru;q=0.9' $Url -o $tmp -w '%{http_code}'
      if ($status -ne '200' -and $script:FetchProxyUrl -and $script:FetchProxySecret) {
        Write-Log ('  proxy fallback for ' + $Url)
        $encoded = [uri]::EscapeDataString($Url)
        $status = & curl.exe -s -L --compressed --max-time 50 -H "x-secret: $($script:FetchProxySecret)" "$($script:FetchProxyUrl)/fetch?url=$encoded" -o $tmp -w '%{http_code}'
      }
      if ($status -ne '200') { throw ('HTTP ' + $status) }
      return [IO.File]::ReadAllText($tmp, [Text.Encoding]::UTF8)
    }
    finally {
      Remove-Item $tmp -ErrorAction SilentlyContinue
    }
  }
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
  if ($Text -match '(?i)бессрочн|без\s+ограничен') { return $null }

  $through = [regex]::Match($Text, '(?i)(?:через|ещё|еще)\s+(\d+)\s*(?:дн|день|дня)')
  if ($through.Success) { return [int]$through.Groups[1].Value }

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

  $m = [regex]::Match($Text, '(?i)до\s+(\d{1,2})\s+([а-яё]+)\.?(?:\s+(\d{4}))?')
  if ($m.Success) {
    $monthName = $m.Groups[2].Value.ToLower()
    $month = $script:Months[$monthName]
    if (-not $month -and $monthName.Length -ge 3) {
      $month = $script:MonthStems[$monthName.Substring(0, 3)]
    }
    if ($month) {
      $year = (Get-Date).Year
      if ($m.Groups[3].Success) { $year = [int]$m.Groups[3].Value }
      try {
        $date = Get-Date -Year $year -Month $month -Day ([int]$m.Groups[1].Value) -Hour 23 -Minute 59
        if (-not $m.Groups[3].Success -and $date.Date -lt (Get-Date).Date) { return -1 }
        return [int][math]::Ceiling(($date - (Get-Date)).TotalDays)
      } catch { return $null }
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
  $negative = '(аптек|\bвита\b|косметик|подружк|цветочн|цвет(ы|ов|ам|ами)?\b|ювелир|товар\w*\s+для\s+дома|хобби|спорт\w*|техник|электроник|одежд|обув|игрушк|зоотовар|канцтовар|бытов|куулклевер|доктор\s+столетов|оптик|очк|кешбэк|рив\s+гош|winelab|алкогол)'
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
  $n = $n -replace '\s*!\s*$', ''
  $n = $n -replace '\.(ru|com)$', ''

  switch -Regex ($n) {
    '^(Сбермаркет|Купер)$' { return 'Купер' }
    '^Vkusvill|^Food\.vkusvill' { return 'ВкусВилл' }
    '^Perekrestok' { return 'Перекрёсток' }
    '^5ka' { return 'Пятёрочка' }
    '^Samokat' { return 'Самокат' }
    '^Dixy' { return 'Дикси' }
    '^Dodopizza' { return 'Додо Пицца' }
    '^Dominopizza|^Domino' { return "Domino's Pizza" }
    '^Dostavka\.magnit|^Magnit' { return 'Магнит' }
    '^Ollis' { return 'Ollis' }
    '^Yobidoyobi' { return 'ЁбиДоёби' }
    '^Sushiwok' { return 'Sushiwok' }
    '^Rostics' { return "Rostic's" }
    '^Winelab' { return 'Winelab' }
    '^Elementaree' { return 'Elementaree' }
    '^Just Food' { return 'Just Food' }
    '^Ашан' { return 'Ашан' }
    '^2 Берега' { return '2 Берега' }
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

function Resolve-ServiceFromText {
  param([string]$Text)
  if (-not $Text) { return '' }
  $t = $Text.ToLower().Replace('ё', 'е')
  $map = @(
    @('яндекс лавка', 'Яндекс Лавка'), @('yandex lavka', 'Яндекс Лавка'),
    @('яндекс еда', 'Яндекс Еда'), @('yandex eda', 'Яндекс Еда'),
    @('самокат', 'Самокат'), @('samokat', 'Самокат'),
    @('купер', 'Купер'), @('kuper', 'Купер'), @('сбермаркет', 'Купер'),
    @('вкусвилл', 'ВкусВилл'), @('vkusvill', 'ВкусВилл'),
    @('вкусмил', 'ВкусМил'), @('vkusmil', 'ВкусМил'),
    @('перекресток', 'Перекрёсток'), @('perekrestok', 'Перекрёсток'),
    @('магнит', 'Магнит'), @('magnit', 'Магнит'),
    @('пятерочка', 'Пятёрочка'), @('pyaterochka', 'Пятёрочка'), @('5ka', 'Пятёрочка'),
    @('дикси', 'Дикси'), @('dixy', 'Дикси'),
    @('ашан', 'Ашан'), @('auchan', 'Ашан'),
    @('лента', 'Лента'), @('lenta', 'Лента'),
    @('глобус', 'Глобус'), @('globus', 'Глобус'),
    @('метро', 'Метро'), @('metro', 'Метро'),
    @('ozon fresh', 'Ozon Fresh'), @('озон фреш', 'Ozon Fresh'),
    @('додо', 'Додо Пицца'), @('dodo', 'Додо Пицца'),
    @('domino', "Domino's Pizza"), @('домино', "Domino's Pizza"),
    @('pizzasushiwok', 'Sushiwok'), @('sushiwok', 'Sushiwok'), @('суши вок', 'Sushiwok'),
    @('sushi master', 'Sushi Master'), @('суши мастер', 'Sushi Master'),
    @('тануки', 'Тануки'), @('tanuki', 'Тануки'),
    @('якитория', 'Якитория'), @('yakitoria', 'Якитория'),
    @('rostic', "Rostic's"), @('ростикс', "Rostic's"),
    @('kfc', 'KFC'), @('кфс', 'KFC'),
    @('burger king', 'Burger King'), @('бургер кинг', 'Burger King'),
    @('вкусно и точка', 'Вкусно — и точка'), @('вкусно — и точка', 'Вкусно — и точка'),
    @('papa john', "Papa John's"), @('папа джон', "Papa John's"),
    @('ебидоеби', 'ЁбиДоёби'), @('yobidoyobi', 'ЁбиДоёби'),
    @('elementaree', 'Elementaree'), @('элементари', 'Elementaree'),
    @('just food', 'Just Food'), @('justfood', 'Just Food'),
    @('grow food', 'Grow Food'), @('growfood', 'Grow Food'),
    @('level kitchen', 'Level Kitchen'), @('levelkitchen', 'Level Kitchen'),
    @("let's food", "Let's Food"), @('letsfood', "Let's Food"),
    @('chef mike', 'Chef Mike'), @('chefmike', 'Chef Mike'),
    @('2 берега', '2 Берега'), @('2berega', '2 Берега'),
    @('азбука вкуса', 'Азбука Вкуса'), @('av.ru', 'Азбука Вкуса'),
    @('утконос', 'Утконос'), @('utkonos', 'Утконос'),
    @('окей', 'Окей'), @('okey', 'Окей'),
    @('деливери', 'Деливери'), @('delivery', 'Деливери'),
    @('сибаристика', 'Сибаристика'), @('sibaristica', 'Сибаристика'),
    @('foodband', 'FoodBand'), @('фудбенд', 'FoodBand'),
    @('priem.menu', 'Priem.menu'), @('прием', 'Priem.menu'),
    @('befit', 'BeFit'), @('be fit', 'BeFit'),
    @('korston', 'Korston'), @('vipfish', 'Vipfish'),
    @('my food', 'My Food'), @('myfood', 'My Food')
  )
  foreach ($pair in $map) {
    if ($t.Contains($pair[0])) { return $pair[1] }
  }
  return ''
}

function Resolve-ServiceSlug {
  param([string]$Slug)
  $s = ([string]$Slug).ToLower()
  if (-not $s) { return '' }
  if ($s -match 'yandexlavka|yandex-lavka|lavka') { return 'Яндекс Лавка' }
  if ($s -match 'yandexeda|yandex-eda|eda-yandex|edadeal') { return 'Яндекс Еда' }
  if ($s -match 'samokat') { return 'Самокат' }
  if ($s -match 'kuper|sbermarket') { return 'Купер' }
  if ($s -match 'vkusvill|vkus-vill') { return 'ВкусВилл' }
  if ($s -match 'vkusmil') { return 'ВкусМил' }
  if ($s -match 'perekrestok') { return 'Перекрёсток' }
  if ($s -match 'magnit') { return 'Магнит' }
  if ($s -match '5ka|pyaterochka') { return 'Пятёрочка' }
  if ($s -match 'dixy') { return 'Дикси' }
  if ($s -match 'auchan|ashan') { return 'Ашан' }
  if ($s -match 'lenta') { return 'Лента' }
  if ($s -match 'globus') { return 'Глобус' }
  if ($s -match 'metro') { return 'Метро' }
  if ($s -match 'ozon') { return 'Ozon Fresh' }
  if ($s -match 'dodo') { return 'Додо Пицца' }
  if ($s -match 'dominos|domino') { return "Domino's Pizza" }
  if ($s -match 'sushiwok') { return 'Sushiwok' }
  if ($s -match 'sushi') { return 'Sushi Master' }
  if ($s -match 'tanuki') { return 'Тануки' }
  if ($s -match 'yakitoria') { return 'Якитория' }
  if ($s -match 'rostic|kfc') { return "Rostic's" }
  if ($s -match 'burger') { return 'Burger King' }
  if ($s -match 'vkusno') { return 'Вкусно — и точка' }
  if ($s -match 'yobidoyobi') { return 'ЁбиДоёби' }
  if ($s -match 'elementaree') { return 'Elementaree' }
  if ($s -match 'justfood') { return 'Just Food' }
  if ($s -match 'growfood') { return 'Grow Food' }
  if ($s -match 'levelkitchen') { return 'Level Kitchen' }
  if ($s -match 'letsfood') { return "Let's Food" }
  if ($s -match 'chefmike') { return 'Chef Mike' }
  if ($s -match '2berega') { return '2 Берега' }
  if ($s -match 'utkonos') { return 'Утконос' }
  if ($s -match 'okey') { return 'Окей' }
  if ($s -match 'delivery|deliveri') { return 'Деливери' }
  if ($s -match 'sibaristica') { return 'Сибаристика' }
  if ($s -match 'foodband') { return 'FoodBand' }
  if ($s -match 'priem') { return 'Priem.menu' }
  if ($s -match 'befit') { return 'BeFit' }
  if ($s -match 'korston') { return 'Korston' }
  if ($s -match 'vipfish') { return 'Vipfish' }
  return ''
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

function Get-NuxtValue {
  param($Data, $Index)
  if ($null -eq $Index) { return $null }
  if ($Index -is [string] -or $Index -is [bool]) { return $Index }

  if ($Index -is [int] -or $Index -is [long]) {
    $i = [int]$Index
    if ($i -lt 0 -or $i -ge $Data.Count) { return $Index }
    $value = $Data[$i]
    if ($value -is [string] -or $value -is [int] -or $value -is [long] -or $value -is [bool] -or $null -eq $value) {
      return $value
    }
    if ($value -is [array]) {
      if ($value.Count -ge 2 -and $value[0] -is [string]) {
        $tag = [string]$value[0]
        if ($tag -eq 'Date') { return $value[1] }
        if ($tag -in @('ShallowReactive', 'Reactive', 'Ref')) { return (Get-NuxtValue $Data $value[1]) }
      }
      return $value
    }
    return $value
  }
  return $Index
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

function Get-KomukuponCodes {
  param([string]$Html, [string]$Url, [string]$SourceName)

  $items = @()
  $payload = [regex]::Match($Html, '(?s)<script[^>]*id="__NUXT_DATA__"[^>]*>(.*?)</script>')
  if (-not $payload.Success) { return $items }

  try { $data = $payload.Groups[1].Value | ConvertFrom-Json } catch { return $items }

  for ($i = 0; $i -lt $data.Count; $i++) {
    $obj = $data[$i]
    if (-not ($obj -is [pscustomobject])) { continue }
    $names = $obj.PSObject.Properties.Name
    if (-not ($names -contains 'code' -and $names -contains 'title' -and $names -contains 'endAt' -and $names -contains 'discount' -and $names -contains 'shop')) { continue }

    $code = ([string](Get-NuxtValue $data $obj.code)).Trim()
    if ($code -notmatch '^[A-Za-z0-9_-]{3,32}$') { continue }

    $title = (Convert-HtmlToText ([string](Get-NuxtValue $data $obj.title))).Trim()
    if (-not $title) { continue }

    $shopObj = Get-NuxtValue $data $obj.shop
    $shopName = ''
    if ($shopObj -is [pscustomobject] -and $shopObj.PSObject.Properties.Name -contains 'shopName') {
      $shopName = [string](Get-NuxtValue $data $shopObj.shopName)
    }

    $discountObj = Get-NuxtValue $data $obj.discount
    if (-not ($discountObj -is [pscustomobject])) { continue }
    $discountType = [string](Get-NuxtValue $data $discountObj.type)
    $discountValue = Get-NuxtValue $data $discountObj.value
    $minOrder = Get-NuxtValue $data $discountObj.minOrder
    $upTo = Get-NuxtValue $data $discountObj.upTo
    $firstOrder = Get-NuxtValue $data $discountObj.firstOrder

    $conditions = @()
    $conditionArray = Get-NuxtValue $data $obj.conditions
    if ($conditionArray -is [array]) {
      foreach ($conditionIndex in $conditionArray) {
        $conditionObj = Get-NuxtValue $data $conditionIndex
        if ($conditionObj -is [pscustomobject] -and $conditionObj.PSObject.Properties.Name -contains 'text') {
          $text = [string](Get-NuxtValue $data $conditionObj.text)
          if ($text) { $conditions += (Convert-HtmlToText $text) }
        }
      }
    }

    $full = $title + ' ' + ($conditions -join ' ') + ' ' + $shopName
    if (-not (Test-RubPrice $full)) { continue }
    if (-not (Test-Food $full)) { continue }

    $days = $null
    $endAt = [string](Get-NuxtValue $data $obj.endAt)
    if ($endAt) {
      try {
        $end = [datetime]::Parse($endAt, [Globalization.CultureInfo]::InvariantCulture)
        $days = [int][math]::Ceiling(($end.ToLocalTime() - (Get-Date)).TotalDays)
        if ($days -lt 0) { continue }
      } catch { }
    }

    $info = [ordered]@{ type = 'fixed'; value = 0; maxDiscount = 0 }
    if ($discountType -eq 'percent') {
      $info.type = 'percent'
      $info.value = [int]$discountValue
      if ($upTo -is [int] -or $upTo -is [long]) { $info.maxDiscount = [int]$upTo }
    }
    elseif ($discountType -eq 'fixed') {
      $info.type = 'fixed'
      $info.value = [int]$discountValue
    }
    if ($info.value -le 0) { continue }

    $min = 0
    if ($minOrder -is [int] -or $minOrder -is [long]) { $min = [int]$minOrder }
    $existing = -not [bool]$firstOrder
    $freeDelivery = [bool]($full -match '(?i)бесплатн\w*\s+доставк')
    $wholeCart = Get-WholeCart $full $info.type
    $cities = @(Get-Cities $full)
    $cityRestricted = $cities.Count -gt 0

    if ($min -gt 0) { $conditions += ('Минимальный заказ — от ' + $min + ' ₽') }

    $items += New-PromoEntry -Service (Resolve-Service $shopName) -Code $code `
      -Type $info.type -Value $info.value -MaxDiscount $info.maxDiscount -MinOrder $min `
      -FreeDelivery $freeDelivery -Title $title -ExpiresInDays $days -Works 0 `
      -ExistingUsers $existing -WholeCart $wholeCart -Cities $cities -CityRestricted $cityRestricted `
      -Conditions $conditions -SourceName $SourceName -SourceUrl $Url
  }

  return $items
}

function Get-PromokodSiteCodes {
  param([string]$Html, [string]$Url, [string]$SourceName, [string]$Service)

  $items = @()
  $parts = [regex]::Split($Html, '<article class="coupon"')

  for ($i = 1; $i -lt $parts.Count; $i++) {
    $chunk = $parts[$i]
    $codeMatch = [regex]::Match($chunk, 'card-code__val">([^<]+)</code>')
    if (-not $codeMatch.Success) { continue }
    $code = $codeMatch.Groups[1].Value.Trim()
    if ($code -notmatch '^[A-Za-z0-9_-]{3,32}$') { continue }

    $title = (Convert-HtmlToText ([regex]::Match($chunk, '(?s)<h3 class="coupon__title">(.*?)</h3>').Groups[1].Value)).Trim()
    if (-not $title) { continue }
    $discount = (Convert-HtmlToText ([regex]::Match($chunk, '<span class="coupon__disc">(.*?)</span>').Groups[1].Value)).Trim()
    $store = (Convert-HtmlToText ([regex]::Match($chunk, '<a class="coupon__store"[^>]*>(.*?)</a>').Groups[1].Value)).Trim()
    $dateText = [regex]::Match($chunk, '<time datetime="([^"]+)"').Groups[1].Value
    $full = $title + ' ' + $discount + ' ' + $store

    if (-not (Test-RubPrice $full)) { continue }
    if (-not (Test-Food $full)) { continue }
    if ($title -notmatch '(?i)(скидк|выгод|эконом|дисконт|минус|бесплатн\w*\s+доставк|\d+\s*%)') { continue }

    $info = Get-DiscountFromTitle $title
    if ($null -eq $info) { $info = Get-DiscountInfo -Discount $discount -Text $full }
    if ($info.value -le 0 -and $info.type -ne 'delivery') { continue }

    $days = $null
    if ($dateText) {
      try {
        $end = [datetime]::Parse($dateText, [Globalization.CultureInfo]::InvariantCulture)
        $days = [int][math]::Ceiling(($end.Date - (Get-Date).Date).TotalDays)
        if ($days -lt 0) { continue }
      } catch { }
    }

    $minOrder = Get-MinOrder $full
    $existing = Get-ExistingUsers $full
    $wholeCart = Get-WholeCart $full $info.type
    $cities = @(Get-Cities $full)
    $cityRestricted = $cities.Count -gt 0
    $freeDelivery = [bool]($full -match '(?i)бесплатн\w*\s+доставк')

    $works = 0
    $worksMatch = [regex]::Match($chunk, '(?s)Сработал\w*.*?([\d\s]+)\s*раз')
    if ($worksMatch.Success) { $works = ConvertTo-Number $worksMatch.Groups[1].Value }

    $conditions = @()
    if ($discount) { $conditions += ('Скидка: ' + $discount) }
    if ($store) { $conditions += ('Магазин: ' + $store) }
    if ($minOrder -gt 0) { $conditions += ('Минимальный заказ — от ' + $minOrder + ' ₽') }

    $items += New-PromoEntry -Service (Resolve-Service ($(if ($store) { $store } else { $Service }))) -Code $code `
      -Type $info.type -Value $info.value -MaxDiscount $info.maxDiscount -MinOrder $minOrder `
      -FreeDelivery $freeDelivery -Title $title -ExpiresInDays $days -Works $works `
      -ExistingUsers $existing -WholeCart $wholeCart -Cities $cities -CityRestricted $cityRestricted `
      -Conditions $conditions -SourceName $SourceName -SourceUrl $Url
  }

  $offerParts = [regex]::Split($Html, '<article class="offer"')
  for ($i = 1; $i -lt $offerParts.Count; $i++) {
    $chunk = $offerParts[$i]
    $code = ([regex]::Match($chunk, 'offer__code-val[^>]*>([^<]+)</code>').Groups[1].Value).Trim()
    if (-not $code) { $code = [regex]::Match($chunk, 'data-code="([^"]+)"').Groups[1].Value.Trim() }
    if ($code -notmatch '^[A-Za-z0-9_-]{3,32}$') { continue }

    $title = (Convert-HtmlToText ([regex]::Match($chunk, '(?s)offer__title">(.*?)</p>').Groups[1].Value)).Trim()
    if (-not $title) { continue }
    $discount = (Convert-HtmlToText ([regex]::Match($chunk, '(?s)offer__disc">(.*?)</p>').Groups[1].Value)).Trim()
    $full = $title + ' ' + $discount + ' ' + $Service

    if (-not (Test-RubPrice $full)) { continue }
    if (-not (Test-Food $full)) { continue }

    $info = Get-DiscountFromTitle $title
    if ($null -eq $info) { $info = Get-DiscountInfo -Discount $discount -Text $full }
    if ($info.value -le 0 -and $info.type -ne 'delivery') { continue }

    $dateText = [regex]::Match($chunk, '<time datetime="([^"]+)"').Groups[1].Value
    $days = $null
    if ($dateText) {
      try {
        $end = [datetime]::Parse($dateText, [Globalization.CultureInfo]::InvariantCulture)
        $days = [int][math]::Ceiling(($end.Date - (Get-Date).Date).TotalDays)
        if ($days -lt 0) { continue }
      } catch { }
    }

    $minOrder = Get-MinOrder $full
    $existing = Get-ExistingUsers $full
    $wholeCart = Get-WholeCart $full $info.type
    $cities = @(Get-Cities $full)
    $cityRestricted = $cities.Count -gt 0
    $freeDelivery = [bool]($full -match '(?i)бесплатн\w*\s+доставк')

    $conditions = @()
    if ($discount) { $conditions += ('Скидка: ' + $discount) }
    if ($minOrder -gt 0) { $conditions += ('Минимальный заказ — от ' + $minOrder + ' ₽') }

    $items += New-PromoEntry -Service $Service -Code $code `
      -Type $info.type -Value $info.value -MaxDiscount $info.maxDiscount -MinOrder $minOrder `
      -FreeDelivery $freeDelivery -Title $title -ExpiresInDays $days -Works 0 `
      -ExistingUsers $existing -WholeCart $wholeCart -Cities $cities -CityRestricted $cityRestricted `
      -Conditions $conditions -SourceName $SourceName -SourceUrl $Url
  }

  return $items
}

function Get-PromokodexCodes {
  param([string]$Html, [string]$Url, [string]$SourceName)

  $items = @()
  $jar = Join-Path $env:TEMP ('promokodex-' + [guid]::NewGuid().ToString('N') + '.txt')
  $pageFile = Join-Path $env:TEMP ('promokodex-' + [guid]::NewGuid().ToString('N') + '.html')

  try {
    $pageArgs = @('-s', '-L', '--max-time', '30', '-A', $script:BrowserUA, '-H', 'Accept-Language: ru-RU,ru;q=0.9', '-c', $jar, $Url, '-o', $pageFile, '-w', '%{http_code}')
    $pageStatus = & curl.exe @pageArgs
    if ($pageStatus -ne '200') { return $items }

    $pageHtml = [IO.File]::ReadAllText($pageFile, [Text.Encoding]::UTF8)
    $tokenLine = Get-Content $jar -ErrorAction SilentlyContinue | Where-Object { $_ -match 'XSRF-TOKEN' } | Select-Object -First 1
    if (-not $tokenLine) { return $items }
    $xsrf = [uri]::UnescapeDataString((($tokenLine -split "`t")[-1]))

    $cards = [regex]::Matches($pageHtml, '(?s)<article[^>]*data-attributes="([^"]+)"[^>]*>(.*?)</article>')
    $processed = 0

    foreach ($card in $cards) {
      if ($processed -ge 30) { break }
      $meta = $null
      try {
        $meta = ([Net.WebUtility]::HtmlDecode($card.Groups[1].Value)) | ConvertFrom-Json
      } catch { continue }

      if ($meta.type -ne 'promocode') { continue }
      $shop = [string]$meta.shop
      $couponToken = [string]$meta.token
      if (-not $shop -or -not $couponToken) { continue }

      $inner = $card.Groups[2].Value
      $title = (Convert-HtmlToText ([regex]::Match($inner, '(?s)<div class="coupon-tile__title">(.*?)</div>').Groups[1].Value)).Trim()
      if (-not $title) { continue }
      $discount = (Convert-HtmlToText ([regex]::Match($inner, '(?s)<div class="coupon-tile__discount">(.*?)</div>').Groups[1].Value)).Trim()
      $logoAlt = [Net.WebUtility]::HtmlDecode([regex]::Match($inner, '<img[^>]*alt="([^"]+)"').Groups[1].Value)
      $service = Resolve-Service $logoAlt
      if ($service -eq 'Winelab') { continue }

      $responseFile = Join-Path $env:TEMP ('promokodex-' + [guid]::NewGuid().ToString('N') + '.json')
      try {
        $postArgs = @(
          '-s', '-b', $jar, '-A', $script:BrowserUA,
          '-H', "X-XSRF-TOKEN: $xsrf",
          '-H', 'Content-Type: application/json',
          '-H', 'X-Requested-With: XMLHttpRequest',
          '-H', "Referer: $Url",
          '-H', 'Origin: https://www.promokodex.ru',
          '-X', 'POST', '-d', '{}',
          "https://www.promokodex.ru/v3/coupon/$shop/$couponToken",
          '-o', $responseFile, '-w', '%{http_code}'
        )
        $postStatus = & curl.exe @postArgs
        $processed++
        if ($postStatus -ne '200') { continue }

        $response = $null
        try { $response = Get-Content -Raw -Encoding UTF8 $responseFile | ConvertFrom-Json } catch { continue }
        $code = ([string]$response.promocode).Trim()
        if ($code -notmatch '^[A-Za-z0-9_-]{3,32}$') { continue }

        $popup = Convert-HtmlToText ([string]$response.html)
        $full = $title + ' ' + $discount + ' ' + $popup
        if (-not (Test-RubPrice $full)) { continue }
        if (-not (Test-Food $full)) { continue }
        if ($title -notmatch '(?i)(скидк|выгод|эконом|дисконт|минус|^-\s*\d|\d+\s*%|бесплатн\w*\s+доставк)') { continue }

        $info = Get-DiscountFromTitle $title
        if ($null -eq $info) { $info = Get-DiscountInfo -Discount $discount -Text $full }
        $freeDelivery = [bool]($full -match '(?i)бесплатн\w*\s+доставк')
        if ($info.value -le 0 -and $freeDelivery) { $info.type = 'delivery' }
        if ($info.value -le 0 -and $info.type -ne 'delivery') { continue }

        $days = Get-ExpiryDays $popup
        if ($null -ne $days -and $days -lt 0) { continue }

        $minOrder = Get-MinOrder $full
        $existing = Get-ExistingUsers $full
        $wholeCart = Get-WholeCart $full $info.type
        $cities = @(Get-Cities $full)
        $cityRestricted = $cities.Count -gt 0

        $conditions = @()
        if ($popup) { $conditions += $popup }
        if ($minOrder -gt 0) { $conditions += ('Минимальный заказ — от ' + $minOrder + ' ₽') }

        $items += New-PromoEntry -Service $service -Code $code -Type $info.type -Value $info.value `
          -MaxDiscount $info.maxDiscount -MinOrder $minOrder -FreeDelivery $freeDelivery `
          -Title $title -ExpiresInDays $days -Works 0 -ExistingUsers $existing -WholeCart $wholeCart `
          -Cities $cities -CityRestricted $cityRestricted -Conditions $conditions `
          -SourceName $SourceName -SourceUrl $Url
      }
      finally {
        Remove-Item $responseFile -ErrorAction SilentlyContinue
      }
      Start-Sleep -Milliseconds 120
    }
  }
  finally {
    Remove-Item $jar, $pageFile -ErrorAction SilentlyContinue
  }

  return $items
}

function Get-PromoService {
  param([string]$Text, [string]$Slug = '', [string]$Store = '')
  $s = Resolve-ServiceFromText $Text
  if ($s) { return $s }
  if ($Slug) {
    $s = Resolve-ServiceSlug $Slug
    if ($s) { return $s }
  }
  if ($Store) {
    $s = Resolve-Service $Store
    if ($s -and $s.Length -le 40) { return $s }
  }
  return 'Доставка еды'
}

function Get-PromokodStoreCodes {
  param([string]$Html, [string]$Url, [string]$SourceName)

  $items = @()
  $parts = [regex]::Split($Html, '<article class="couponRow"')

  for ($i = 1; $i -lt $parts.Count; $i++) {
    $chunk = $parts[$i]
    $code = [regex]::Match($chunk, '(?s)<div class="couponCodeCell"[^>]*>\s*<code[^>]*>([^<]+)</code>').Groups[1].Value.Trim()
    if (-not $code) { continue }
    if ($code -notmatch '^[A-Za-zА-Яа-я0-9_-]{3,32}$') { continue }

    $title = (Convert-HtmlToText ([regex]::Match($chunk, '(?s)<h3><a[^>]*>(.*?)</a></h3>').Groups[1].Value)).Trim()
    if (-not $title) { continue }

    $store = (Convert-HtmlToText ([regex]::Match($chunk, '(?s)<div class="couponStoreLine">.*?<strong>(.*?)</strong>').Groups[1].Value)).Trim()
    $discount = (Convert-HtmlToText ([regex]::Match($chunk, '(?s)<div class="couponDiscountCell"[^>]*>(.*?)</div>').Groups[1].Value)).Trim()
    $dateText = (Convert-HtmlToText ([regex]::Match($chunk, '(?s)<div class="couponDateCell"[^>]*>(.*?)</div>').Groups[1].Value)).Trim()
    $full = $title + ' ' + $discount + ' ' + $store

    if (-not (Test-RubPrice $full)) { continue }
    if (-not (Test-Food $full)) { continue }

    $info = Get-DiscountFromTitle $title
    if ($null -eq $info) { $info = Get-DiscountInfo -Discount $discount -Text $full }
    if ($info.value -le 0 -and $info.type -ne 'delivery') { continue }

    $days = Get-ExpiryDays $dateText
    if ($null -ne $days -and $days -lt 0) { continue }

    $works = 0
    $wm = [regex]::Match($chunk, '(?s)copyMetric.*?<strong>([\d\s]+)</strong>')
    if ($wm.Success) { $works = ConvertTo-Number $wm.Groups[1].Value }

    $minOrder = Get-MinOrder $full
    $existing = Get-ExistingUsers $full
    $wholeCart = Get-WholeCart $full $info.type
    $cities = @(Get-Cities $full)
    $cityRestricted = $cities.Count -gt 0
    $freeDelivery = [bool]($full -match '(?i)бесплатн\w*\s+доставк')

    $conditions = @()
    if ($discount) { $conditions += ('Скидка: ' + $discount) }
    if ($dateText) { $conditions += $dateText }
    if ($minOrder -gt 0) { $conditions += ('Минимальный заказ — от ' + $minOrder + ' ₽') }

    $items += New-PromoEntry -Service (Get-PromoService -Text $full -Store $store) -Code $code `
      -Type $info.type -Value $info.value -MaxDiscount $info.maxDiscount -MinOrder $minOrder `
      -FreeDelivery $freeDelivery -Title $title -ExpiresInDays $days -Works $works `
      -ExistingUsers $existing -WholeCart $wholeCart -Cities $cities -CityRestricted $cityRestricted `
      -Conditions $conditions -SourceName $SourceName -SourceUrl $Url
  }

  return $items
}

function Get-PromocodexCodes {
  param([string]$Html, [string]$Url, [string]$SourceName)

  $items = @()
  $parts = [regex]::Split($Html, '<div class="col-md-4')

  for ($i = 1; $i -lt $parts.Count; $i++) {
    $chunk = $parts[$i]
    $code = [regex]::Match($chunk, 'data-clipboard-text="([^"]+)"').Groups[1].Value.Trim()
    if (-not $code) { $code = [regex]::Match($chunk, 'coupon-text"[^>]*>([^<]+)</div>').Groups[1].Value.Trim() }
    if ($code -notmatch '^[A-Za-zА-Яа-я0-9_-]{3,32}$') { continue }

    $title = (Convert-HtmlToText ([regex]::Match($chunk, '(?s)<h2[^>]*>.*?<a[^>]*>(.*?)</a>').Groups[1].Value)).Trim()
    if (-not $title) { continue }

    $discount = (Convert-HtmlToText ([regex]::Match($chunk, '(?s)<span class="f90[^"]*">(.*?)</span>').Groups[1].Value)).Trim()
    $slug = [regex]::Match($chunk, 'href="https://promocodex\.ru/promocodes/([^/"]+)/').Groups[1].Value
    $store = (Convert-HtmlToText ([regex]::Match($chunk, 'title="Все промокоды ([^"]+)"').Groups[1].Value)).Trim()
    $dateText = [regex]::Match($chunk, 'data-end="([^"]+)"').Groups[1].Value
    $desc = (Convert-HtmlToText ([regex]::Match($chunk, '(?s)<div class="small[^"]*mt-1">(.*?)</div>').Groups[1].Value)).Trim()
    $full = $title + ' ' + $discount + ' ' + $store + ' ' + $desc

    if (-not (Test-RubPrice $full)) { continue }
    if (-not (Test-Food $full)) { continue }

    $info = Get-DiscountFromTitle $title
    if ($null -eq $info) { $info = Get-DiscountInfo -Discount $discount -Text $full }
    if ($info.value -le 0 -and $info.type -ne 'delivery') { continue }

    $days = $null
    if ($dateText) {
      try {
        $end = [datetime]::Parse($dateText, [Globalization.CultureInfo]::InvariantCulture)
        $days = [int][math]::Ceiling(($end.Date - (Get-Date).Date).TotalDays)
        if ($days -lt 0) { continue }
      } catch { }
    }
    if ($null -eq $days) { $days = Get-ExpiryDays $desc }

    $minOrder = Get-MinOrder $full
    $existing = Get-ExistingUsers $full
    $wholeCart = Get-WholeCart $full $info.type
    $cities = @(Get-Cities $full)
    $cityRestricted = $cities.Count -gt 0
    $freeDelivery = [bool]($full -match '(?i)бесплатн\w*\s+доставк')

    $conditions = @()
    if ($discount) { $conditions += ('Скидка: ' + $discount) }
    if ($desc) { $conditions += $desc }
    if ($minOrder -gt 0) { $conditions += ('Минимальный заказ — от ' + $minOrder + ' ₽') }

    $items += New-PromoEntry -Service (Get-PromoService -Text $full -Slug $slug -Store $store) -Code $code `
      -Type $info.type -Value $info.value -MaxDiscount $info.maxDiscount -MinOrder $minOrder `
      -FreeDelivery $freeDelivery -Title $title -ExpiresInDays $days -Works 0 `
      -ExistingUsers $existing -WholeCart $wholeCart -Cities $cities -CityRestricted $cityRestricted `
      -Conditions $conditions -SourceName $SourceName -SourceUrl $Url
  }

  return $items
}

function Get-OkodoCodes {
  param([string]$Html, [string]$Url, [string]$SourceName)

  $items = @()
  $parts = [regex]::Split($Html, '<article class="tg')

  for ($i = 1; $i -lt $parts.Count; $i++) {
    $chunk = $parts[$i]
    $code = [regex]::Match($chunk, 'data-code="([^"]+)"').Groups[1].Value.Trim()
    if ($code -notmatch '^[A-Za-zА-Яа-я0-9_-]{3,32}$') { continue }

    $title = (Convert-HtmlToText ([regex]::Match($chunk, '(?s)class="tg-name">(.*?)</h3>').Groups[1].Value)).Trim()
    if (-not $title) { continue }

    $store = (Convert-HtmlToText ([regex]::Match($chunk, '(?s)class="tg-svc"[^>]*>(.*?)</a>').Groups[1].Value)).Trim()
    $priceN = (Convert-HtmlToText ([regex]::Match($chunk, 'class="pr-n">([^<]+)</span>').Groups[1].Value)).Trim()
    $priceU = (Convert-HtmlToText ([regex]::Match($chunk, 'class="pr-u">([^<]+)</span>').Groups[1].Value)).Trim()
    $cond = (Convert-HtmlToText ([regex]::Match($chunk, '(?s)class="tg-cond">(.*?)</p>').Groups[1].Value)).Trim()
    $src = (Convert-HtmlToText ([regex]::Match($chunk, 'class="tg-src"[^>]*>(.*?)</span>').Groups[1].Value)).Trim()
    $discount = ($priceN + $priceU).Trim()
    $full = $title + ' ' + $discount + ' ' + $store + ' ' + $cond

    if (-not (Test-RubPrice $full)) { continue }
    if (-not (Test-Food $full)) { continue }

    $info = Get-DiscountFromTitle $title
    if ($null -eq $info) { $info = Get-DiscountInfo -Discount $discount -Text $full }
    if ($info.value -le 0 -and $info.type -ne 'delivery') { continue }

    $days = Get-ExpiryDays $cond
    if ($null -ne $days -and $days -lt 0) { continue }

    $minOrder = Get-MinOrder $full
    $existing = Get-ExistingUsers $full
    $wholeCart = Get-WholeCart $full $info.type
    $cities = @(Get-Cities $full)
    $cityRestricted = $cities.Count -gt 0
    $freeDelivery = [bool]($full -match '(?i)бесплатн\w*\s+доставк')

    $conditions = @()
    if ($cond) { $conditions += $cond }
    if ($src) { $conditions += ('Источники: ' + $src) }
    if ($minOrder -gt 0) { $conditions += ('Минимальный заказ — от ' + $minOrder + ' ₽') }

    $items += New-PromoEntry -Service (Get-PromoService -Text $full -Store $store) -Code $code `
      -Type $info.type -Value $info.value -MaxDiscount $info.maxDiscount -MinOrder $minOrder `
      -FreeDelivery $freeDelivery -Title $title -ExpiresInDays $days -Works 0 `
      -ExistingUsers $existing -WholeCart $wholeCart -Cities $cities -CityRestricted $cityRestricted `
      -Conditions $conditions -SourceName $SourceName -SourceUrl $Url
  }

  return $items
}

function Get-PromokodikovCodes {
  param([string]$Html, [string]$Url, [string]$SourceName)

  $items = @()
  $parts = [regex]::Split($Html, '<div class="news-community')

  for ($i = 1; $i -lt $parts.Count; $i++) {
    $chunk = $parts[$i]
    if ($chunk -match 'expired_coupon') { continue }

    $code = [regex]::Match($chunk, 'data-clipboard-text="([^"]+)"').Groups[1].Value.Trim()
    if (-not $code) { continue }
    if ($code -notmatch '^[A-Za-zА-Яа-я0-9_-]{3,32}$') { continue }

    $title = (Convert-HtmlToText ([regex]::Match($chunk, '(?s)<h2[^>]*>.*?<a[^>]*>(.*?)</a>').Groups[1].Value)).Trim()
    if (-not $title) { $title = (Convert-HtmlToText ([regex]::Match($chunk, 'title="([^"]+)"').Groups[1].Value)).Trim() }
    if (-not $title) { continue }

    $store = [regex]::Match($chunk, 'btn_offer_block[^>]*href="https?://([^/"]+)').Groups[1].Value
    if (-not $store) { $store = [regex]::Match($chunk, '<img[^>]*alt="([^"]+)"').Groups[1].Value }
    $full = $title + ' ' + $store

    if (-not (Test-RubPrice $full)) { continue }
    if (-not (Test-Food $full)) { continue }

    $info = Get-DiscountFromTitle $title
    if ($null -eq $info) { $info = Get-DiscountInfo -Discount '' -Text $full }
    if ($info.value -le 0 -and $info.type -ne 'delivery') { continue }

    $dateText = (Convert-HtmlToText ([regex]::Match($chunk, '(?s)(?:до|До)\s+\d{1,2}[^<]{0,20}').Value)).Trim()
    $days = Get-ExpiryDays $dateText

    $works = 0
    $wm = [regex]::Match($chunk, 'thumbscount">(\d+)')
    if ($wm.Success) { $works = [int]$wm.Groups[1].Value }

    $minOrder = Get-MinOrder $full
    $existing = Get-ExistingUsers $full
    $wholeCart = Get-WholeCart $full $info.type
    $cities = @(Get-Cities $full)
    $cityRestricted = $cities.Count -gt 0
    $freeDelivery = [bool]($full -match '(?i)бесплатн\w*\s+доставк')

    $conditions = @()
    if ($dateText) { $conditions += $dateText }
    if ($minOrder -gt 0) { $conditions += ('Минимальный заказ — от ' + $minOrder + ' ₽') }

    $items += New-PromoEntry -Service (Get-PromoService -Text $full -Store $store) -Code $code `
      -Type $info.type -Value $info.value -MaxDiscount $info.maxDiscount -MinOrder $minOrder `
      -FreeDelivery $freeDelivery -Title $title -ExpiresInDays $days -Works $works `
      -ExistingUsers $existing -WholeCart $wholeCart -Cities $cities -CityRestricted $cityRestricted `
      -Conditions $conditions -SourceName $SourceName -SourceUrl $Url
  }

  return $items
}

function Get-PickpointCodes {
  param([string]$Html, [string]$Url, [string]$SourceName)

  $items = @()
  $parts = [regex]::Split($Html, '<article data-type="coupon"')

  for ($i = 1; $i -lt $parts.Count; $i++) {
    $chunk = $parts[$i]
    $code = [regex]::Match($chunk, 'data-code="([^"]+)"').Groups[1].Value.Trim()
    if ($code -notmatch '^[A-Za-zА-Яа-я0-9_-]{3,32}$') { continue }

    $title = (Convert-HtmlToText ([regex]::Match($chunk, 'data-title="([^"]+)"').Groups[1].Value)).Trim()
    if (-not $title) { $title = (Convert-HtmlToText ([regex]::Match($chunk, '(?s)promo-card__title">(.*?)</p>').Groups[1].Value)).Trim() }
    if (-not $title) { continue }

    $store = [regex]::Match($chunk, 'data-shop-domain="([^"]+)"').Groups[1].Value.Trim()
    if (-not $store) { $store = [regex]::Match($chunk, '<img[^>]*alt="([^"]+)"').Groups[1].Value.Trim() }
    $exp = (Convert-HtmlToText ([regex]::Match($chunk, 'coupon-exp-label">([^<]+)').Groups[1].Value)).Trim()
    $full = $title + ' ' + $store + ' ' + $exp

    if (-not (Test-RubPrice $full)) { continue }
    if (-not (Test-Food $full)) { continue }

    $info = Get-DiscountFromTitle $title
    if ($null -eq $info) { $info = Get-DiscountInfo -Discount '' -Text $full }
    if ($info.value -le 0 -and $info.type -ne 'delivery') { continue }

    $days = Get-ExpiryDays $exp
    if ($null -ne $days -and $days -lt 0) { continue }

    $minOrder = Get-MinOrder $full
    $existing = Get-ExistingUsers $full
    $wholeCart = Get-WholeCart $full $info.type
    $cities = @(Get-Cities $full)
    $cityRestricted = $cities.Count -gt 0
    $freeDelivery = [bool]($full -match '(?i)бесплатн\w*\s+доставк')

    $conditions = @()
    if ($exp) { $conditions += $exp }
    if ($minOrder -gt 0) { $conditions += ('Минимальный заказ — от ' + $minOrder + ' ₽') }

    $items += New-PromoEntry -Service (Get-PromoService -Text $full -Slug $store -Store $store) -Code $code `
      -Type $info.type -Value $info.value -MaxDiscount $info.maxDiscount -MinOrder $minOrder `
      -FreeDelivery $freeDelivery -Title $title -ExpiresInDays $days -Works 0 `
      -ExistingUsers $existing -WholeCart $wholeCart -Cities $cities -CityRestricted $cityRestricted `
      -Conditions $conditions -SourceName $SourceName -SourceUrl $Url
  }

  return $items
}

function Get-FooodyCodes {
  param([string]$Html, [string]$Url, [string]$SourceName)

  $items = @()
  $parts = [regex]::Split($Html, '<div class="[^"]*promo-item')

  for ($i = 1; $i -lt $parts.Count; $i++) {
    $chunk = $parts[$i]
    $code = [regex]::Match($chunk, 'data-code="([^"]+)"').Groups[1].Value.Trim()
    if ($code -notmatch '^[A-Za-zА-Яа-я0-9_-]{3,32}$') { continue }

    $title = (Convert-HtmlToText ([regex]::Match($chunk, '(?s)<h5[^>]*>.*?<a[^>]*>(.*?)</a>').Groups[1].Value)).Trim()
    if (-not $title) { continue }
    $desc = (Convert-HtmlToText ([regex]::Match($chunk, '(?s)<p class="small[^"]*">(.*?)</p>').Groups[1].Value)).Trim()
    $store = [regex]::Match($chunk, '<img[^>]*alt="([^"]+)"').Groups[1].Value.Trim()
    $full = $title + ' ' + $desc + ' ' + $store + ' еда'

    if (-not (Test-RubPrice $full)) { continue }

    $info = Get-DiscountFromTitle $title
    if ($null -eq $info) { $info = Get-DiscountInfo -Discount '' -Text $full }
    if ($info.value -le 0 -and $info.type -ne 'delivery') { continue }

    $days = Get-ExpiryDays $full
    if ($null -ne $days -and $days -lt 0) { continue }

    $minOrder = Get-MinOrder $full
    $existing = Get-ExistingUsers $full
    $wholeCart = Get-WholeCart $full $info.type
    $cities = @(Get-Cities $full)
    $cityRestricted = $cities.Count -gt 0
    $freeDelivery = [bool]($full -match '(?i)бесплатн\w*\s+доставк')

    $conditions = @()
    if ($desc) { $conditions += $desc }
    if ($minOrder -gt 0) { $conditions += ('Минимальный заказ — от ' + $minOrder + ' ₽') }

    $items += New-PromoEntry -Service (Get-PromoService -Text $full -Store $store) -Code $code `
      -Type $info.type -Value $info.value -MaxDiscount $info.maxDiscount -MinOrder $minOrder `
      -FreeDelivery $freeDelivery -Title $title -ExpiresInDays $days -Works 0 `
      -ExistingUsers $existing -WholeCart $wholeCart -Cities $cities -CityRestricted $cityRestricted `
      -Conditions $conditions -SourceName $SourceName -SourceUrl $Url
  }

  return $items
}

function Get-TelegramCodes {
  param([string]$Channel, [string]$SourceName)

  $items = @()
  $url = 'https://t.me/s/' + $Channel
  $file = Join-Path $env:TEMP ('telegram-' + [guid]::NewGuid().ToString('N') + '.html')

  $channelMap = @{
    'promokod_yandex_eda' = 'Яндекс Еда'
    'promokod_kfc'        = 'KFC'
    'promokod_magnit'     = 'Магнит'
    'promokod_rostics'    = "Rostic's"
    'promokod_perekrestok' = 'Перекрёсток'
    'promokod_yakitoria'  = 'Якитория'
    'promokod_growfood'   = 'Grow Food'
    'promokod_vkusvill'   = 'ВкусВилл'
    'promokod_tanuki'     = 'Тануки'
    'promokod_vkusnoitochka' = 'Вкусно — и точка'
    'promokod_papajohns'  = "Papa John's"
    'promokod_eda'        = ''
    'promokody_skidki'    = ''
    'promokody'           = ''
  }
  $channelService = $channelMap[$Channel]
  if (-not $channelService) { $channelService = Get-PromoService -Text $Channel }
  $genericChannel = [string]::IsNullOrWhiteSpace($channelMap[$Channel])

  try {
    $status = & curl.exe -s -L --compressed --max-time 30 -A $script:BrowserUA -H 'Accept-Language: ru-RU,ru;q=0.9' $url -o $file -w '%{http_code}'
    if ($status -ne '200') { return $items }
    $html = [IO.File]::ReadAllText($file, [Text.Encoding]::UTF8)
  }
  finally {
    Remove-Item $file -ErrorAction SilentlyContinue
  }

  $parts = [regex]::Split($html, '<div class="tgme_widget_message_wrap')

  for ($i = 1; $i -lt $parts.Count; $i++) {
    $chunk = $parts[$i]
    $textHtml = [regex]::Match($chunk, '(?s)<div class="tgme_widget_message_text[^"]*"[^>]*>(.*?)</div>').Groups[1].Value
    if (-not $textHtml) { continue }
    $text = (Convert-HtmlToText $textHtml).Trim()
    if (-not $text) { continue }
    if ($text -notmatch '(?i)промокод|по\s+коду|\bкод\b') { continue }

    $date = [regex]::Match($chunk, 'datetime="([^"]+)"').Groups[1].Value
    $link = [regex]::Match($chunk, 'class="tgme_widget_message_date"[^>]*href="([^"]+)"').Groups[1].Value
    if (-not $link) { $link = $url }

    $full = $text + ' ' + $channelService
    if (-not (Test-RubPrice $full)) { continue }
    if ($text -match '(?i)эльдорадо|мвидео|литрес|еаптек|аптек|косметик|иригатор|кондиционер|смартфон|ноутбук|телевизор|пылесос|наушник|ситимобил|такси') { continue }

    $info = Get-DiscountFromTitle $text
    if ($null -eq $info) { $info = Get-DiscountInfo -Discount '' -Text $full }
    if ($info.value -le 0) {
      if ($full -match '(?i)бесплатн\w*\s+доставк') { $info.type = 'delivery' }
      else { continue }
    }

    $days = Get-ExpiryDays $text
    if ($null -ne $days -and $days -lt 0) { continue }

    $candidates = @()
    foreach ($m in [regex]::Matches($text, '\b[A-ZА-Я0-9][A-ZА-Я0-9_-]{3,20}\b')) {
      $candidate = $m.Value
      if ($candidate -match '^(ПРОМОКОД|ПРОМОКОДЫ|СКИДКА|БЕСПЛАТНО|ЗАКАЗ|ДОСТАВКА|НОВЫЙ|ПЕРВЫЙ|ТОЛЬКО|СЕГОДНЯ|ЯНДЕКС|САМОКАТ|КУПЕР|ВКУСВИЛЛ|МАГНИТ|ПЕРЕКРЕСТОК|ПЯТЕРОЧКА|ДОДО|КФС|РОСТИКС|PROMOKOD|PROMOCODE|TELEGRAM|HTTP|HTTPS|HTML|RUSSIA|MOSCOW|NULL|TRUE|FALSE|OZON|KFC|DIXY|METRO)$') { continue }
      if ($candidate -notmatch '[A-Za-zА-Яа-я]' -or $candidate -notmatch '\d') { continue }
      if ($candidate.Length -lt 4) { continue }
      $pos = $text.IndexOf($candidate)
      $around = $text.Substring([Math]::Max(0, $pos - 80), [Math]::Min(180, $text.Length - [Math]::Max(0, $pos - 80)))
      if ($around -notmatch '(?i)промокод') { continue }
      if (-not ($candidates -contains $candidate)) { $candidates += $candidate }
      if ($candidates.Count -ge 4) { break }
    }

    foreach ($code in $candidates) {
      $service = Get-PromoService -Text $text
      if ($service -eq 'Доставка еды' -and $channelService) {
        $brandPattern = @{
          'promokod_yandex_eda' = '(?i)яндекс'
          'promokod_kfc'        = '(?i)kfc|кфс'
          'promokod_magnit'     = '(?i)магнит'
          'promokod_rostics'    = '(?i)rostic|ростикс'
          'promokod_perekrestok' = '(?i)перекр'
          'promokod_yakitoria'  = '(?i)якитория|yakitoria'
          'promokod_growfood'   = '(?i)grow food|growfood'
          'promokod_vkusvill'   = '(?i)вкусвилл|vkusvill'
          'promokod_tanuki'     = '(?i)тануки|tanuki'
          'promokod_vkusnoitochka' = '(?i)вкусно|vkusno'
          'promokod_papajohns'  = '(?i)papa\s*john|папа\s*джон'
        }
        $bp = $brandPattern[$Channel]
        if ($bp -and $text -match $bp) { $service = $channelService }
      }
      if ($service -notmatch '(?i)яндекс|самокат|купер|вкусвилл|вкусмил|перекр|магнит|пят|дикси|ашан|лента|глобус|метро|ozon fresh|додо|domino|sushiwok|sushi|тануки|якитория|rostic|kfc|burger|вкусно|ёбидоёби|elementaree|just food|grow food|level kitchen|let''s food|chef mike|2 берега|азбука|утконос|окей|деливери|сибаристика|foodband|priem|befit|korston|vipfish|my food') { continue }
      if (-not (Test-Food ($full + ' ' + $service))) { continue }
      if ($genericChannel -and $service -eq 'Доставка еды') { continue }

      $title = $text
      if ($title.Length -gt 140) { $title = $title.Substring(0, 137) + '...' }

      $minOrder = Get-MinOrder $full
      $existing = Get-ExistingUsers $full
      $wholeCart = Get-WholeCart $full $info.type
      $cities = @(Get-Cities $full)
      $cityRestricted = $cities.Count -gt 0
      $freeDelivery = [bool]($full -match '(?i)бесплатн\w*\s+доставк')

      $conditions = @()
      if ($candidates.Count -gt 0) { $conditions += ('Код из поста: ' + $code) }
      if ($days -ne $null) { $conditions += ('Срок: ' + $days + ' дн.') }
      if ($minOrder -gt 0) { $conditions += ('Минимальный заказ — от ' + $minOrder + ' ₽') }

      $items += New-PromoEntry -Service $service -Code $code `
        -Type $info.type -Value $info.value -MaxDiscount $info.maxDiscount -MinOrder $minOrder `
        -FreeDelivery $freeDelivery -Title $title -ExpiresInDays $days -Works 0 `
        -ExistingUsers $existing -WholeCart $wholeCart -Cities $cities -CityRestricted $cityRestricted `
        -Conditions $conditions -SourceName $SourceName -SourceUrl $link
    }
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
$healthRun = @{}

foreach ($source in $script:Sources) {
  if ($source.kind -eq 'telegram' -and $env:PROMOLOV_SKIP_TELEGRAM -eq '1') { continue }
  try {
    Write-Log ('Fetching ' + $source.name + ' ...')
    $html = ''
    if ($source.kind -ne 'telegram') {
      $html = Get-Html $source.url
    }
    if ($source.kind -eq 'promokodcom') {
      $found = @(Get-PromokodComCodes -Html $html -Url $source.url -SourceName $source.name)
    }
    elseif ($source.kind -eq 'pikabu') {
      $found = @(Get-PikabuCodes -Html $html -Url $source.url -SourceName $source.name)
    }
    elseif ($source.kind -eq 'kp') {
      $found = @(Get-KpCodes -Html $html -Url $source.url -SourceName $source.name -Service $source.service)
    }
    elseif ($source.kind -eq 'komukupon') {
      $found = @(Get-KomukuponCodes -Html $html -Url $source.url -SourceName $source.name)
    }
    elseif ($source.kind -eq 'promokodex') {
      $found = @(Get-PromokodexCodes -Html $html -Url $source.url -SourceName $source.name)
    }
    elseif ($source.kind -eq 'promokodsite') {
      $found = @(Get-PromokodSiteCodes -Html $html -Url $source.url -SourceName $source.name -Service $source.service)
    }
    elseif ($source.kind -eq 'promokodstore') {
      $found = @(Get-PromokodStoreCodes -Html $html -Url $source.url -SourceName $source.name)
    }
    elseif ($source.kind -eq 'promocodex') {
      $found = @(Get-PromocodexCodes -Html $html -Url $source.url -SourceName $source.name)
    }
    elseif ($source.kind -eq 'okodo') {
      $found = @(Get-OkodoCodes -Html $html -Url $source.url -SourceName $source.name)
    }
    elseif ($source.kind -eq 'promokodikov') {
      $found = @(Get-PromokodikovCodes -Html $html -Url $source.url -SourceName $source.name)
    }
    elseif ($source.kind -eq 'pickpoint') {
      $found = @(Get-PickpointCodes -Html $html -Url $source.url -SourceName $source.name)
    }
    elseif ($source.kind -eq 'fooody') {
      $found = @(Get-FooodyCodes -Html $html -Url $source.url -SourceName $source.name)
    }
    elseif ($source.kind -eq 'telegram') {
      $found = @(Get-TelegramCodes -Channel $source.channel -SourceName $source.name)
    }
    else {
      $found = @(Get-EcosumCodes -Html $html -Url $source.url -SourceName $source.name)
    }
    Write-Log ('  ' + $found.Count + ' codes from ' + $source.name)
    if (-not $healthRun.ContainsKey($source.name)) {
      $healthRun[$source.name] = @{ count = 0; error = $null }
    }
    $healthRun[$source.name].count += $found.Count
    $collected += $found
  }
  catch {
    if (-not $healthRun.ContainsKey($source.name)) {
      $healthRun[$source.name] = @{ count = 0; error = $null }
    }
    $healthRun[$source.name].error = $_.Exception.Message
    Write-Log ('  ' + $source.name + ' failed: ' + $_.Exception.Message)
  }
}

if ($collected.Count -eq 0) {
  Write-Log 'No codes collected; keeping the previous feed.'
  exit 1
}

$unique = @{}
$junkCode = '^(admitad|promokodex|promokod|promocode|promo|test|none|null)$'
$groups = @{}
$codeEvidence = @{}
foreach ($item in $collected) {
  if ($item.code -match $junkCode) { continue }
  $item['code'] = ([string]$item.code).Trim().ToUpper()
  $item['service'] = Resolve-Service ([string]$item.service)
  if ($item.type -eq 'percent' -and [int]$item.value -gt 50) { continue }
  if ($item.type -eq 'fixed' -and [int]$item.minOrder -gt 0 -and [int]$item.value -gt [math]::Floor([int]$item.minOrder * 0.6)) { continue }
  $key = $item.code
  if (-not $groups.ContainsKey($key)) { $groups[$key] = @() }
  $groups[$key] += $item
  if (-not $codeEvidence.ContainsKey($item.code)) { $codeEvidence[$item.code] = @() }
  $codeEvidence[$item.code] += $item
}

$now = Get-Date
$nowIso = $now.ToString('o')
$stateFile = Join-Path $scriptRoot 'data\state.json'
$healthFile = Join-Path $scriptRoot 'data\source-health.json'
$stateCodes = @{}
if (Test-Path $stateFile) {
  try {
    $stateRaw = Get-Content -Raw -Encoding UTF8 $stateFile | ConvertFrom-Json
    foreach ($prop in $stateRaw.codes.PSObject.Properties) {
      $oldKey = [string]$prop.Name
      $val = $prop.Value
      $codeKey = $oldKey
      $pipe = $oldKey.IndexOf('|')
      if ($pipe -gt 0) { $codeKey = $oldKey.Substring(0, $pipe) }

      if (-not $stateCodes.ContainsKey($codeKey)) {
        $stateCodes[$codeKey] = [ordered]@{
          firstSeen = [string]$val.firstSeen
          lastSeen  = [string]$val.lastSeen
          seenRuns  = [int]$val.seenRuns
          sources   = @($val.sources | Where-Object { $_ } | Select-Object -Unique)
        }
      }
      else {
        $existing = $stateCodes[$codeKey]
        $existing.seenRuns = [Math]::Max([int]$existing.seenRuns, [int]$val.seenRuns)
        try {
          $eFirst = [datetime]::Parse([string]$existing.firstSeen)
          $vFirst = [datetime]::Parse([string]$val.firstSeen)
          if ($vFirst -lt $eFirst) { $existing.firstSeen = [string]$val.firstSeen }
        } catch { }
        try {
          $eLast = [datetime]::Parse([string]$existing.lastSeen)
          $vLast = [datetime]::Parse([string]$val.lastSeen)
          if ($vLast -gt $eLast) { $existing.lastSeen = [string]$val.lastSeen }
        } catch { }
        $existing.sources = @(@($existing.sources) + @($val.sources) | Where-Object { $_ } | Select-Object -Unique)
      }
    }
  } catch { }
}

$sourceWeights = @{
  'promokod.com' = 0.9; 'promokod.pikabu.ru' = 0.9; 'promokodex.ru' = 0.85;
  'promokodi.komukupon.ru' = 0.8; 'promokod.site' = 0.9; 'kp.ru' = 0.9; 'ecosum.ru' = 0.85;
  'promokod.store' = 0.82; 'promocodex.ru' = 0.75; 'okodo.ru' = 0.8;
  'pickpoint.ru' = 0.75; 'fooody.ru' = 0.75; 'promokodikov.ru' = 0.65
}
$sourceGroups = @{}
foreach ($s in $script:Sources) {
  if ($s.group) { $sourceGroups[$s.name] = $s.group }
  elseif (-not $sourceGroups.ContainsKey($s.name)) { $sourceGroups[$s.name] = $s.name }
}

$final = @()
foreach ($key in $groups.Keys) {
  $list = @($groups[$key])
  if ($list.Count -eq 0) { continue }

  $best = @($list | Sort-Object -Property @(
    @{ Expression = { $_.works }; Descending = $true },
    @{ Expression = { $_.value }; Descending = $true }
  )) | Select-Object -First 1

  $serviceWeights = @{}
  foreach ($it in $list) {
    $w = 0.6
    $g = $sourceGroups[$it.sourceName]
    if ($g -and $sourceWeights.ContainsKey($g)) { $w = $sourceWeights[$g] }
    elseif ($sourceWeights.ContainsKey($it.sourceName)) { $w = $sourceWeights[$it.sourceName] }
    if (-not $serviceWeights.ContainsKey($it.service)) { $serviceWeights[$it.service] = 0 }
    $serviceWeights[$it.service] += $w
  }
  $bestService = $null
  if ($serviceWeights.Count -gt 0) {
    $bestService = ($serviceWeights.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
  }
  if ($bestService) {
    $preferred = @($list | Where-Object { $_.service -eq $bestService })
    if ($preferred.Count -gt 0) {
      $best = @($preferred | Sort-Object -Property @(
        @{ Expression = { $_.works }; Descending = $true },
        @{ Expression = { $_.value }; Descending = $true }
      )) | Select-Object -First 1
    }
  }

  $evidenceSources = @($list | ForEach-Object { $_.sourceName } | Where-Object { $_ } | Select-Object -Unique)
  $codeItems = @($codeEvidence[$best.code])
  if ($codeItems.Count -eq 0) { $codeItems = $list }
  $codeSources = @($codeItems | ForEach-Object { $_.sourceName } | Where-Object { $_ } | Select-Object -Unique)
  if ($codeSources.Count -gt 0) { $evidenceSources = @($codeSources) }
  $groupsList = @($evidenceSources | ForEach-Object { $sourceGroups[$_] } | Where-Object { $_ } | Select-Object -Unique)
  $sourceCount = [Math]::Max(1, $groupsList.Count)

  $weights = @($evidenceSources | ForEach-Object {
    $w = 0.6
    $g = $sourceGroups[$_]
    if ($g -and $sourceWeights.ContainsKey($g)) { $w = $sourceWeights[$g] }
    elseif ($sourceWeights.ContainsKey($_)) { $w = $sourceWeights[$_] }
    $w
  })
  $avgWeight = 0.6
  if ($weights.Count -gt 0) { $avgWeight = ($weights | Measure-Object -Average).Average }

  $works = 0
  $workValues = @($codeItems | ForEach-Object { [int]$_.works })
  if ($workValues.Count -gt 0) { $works = ($workValues | Measure-Object -Maximum).Maximum }

  $prev = $stateCodes[$key]
  $seenRuns = 1
  $firstSeen = $nowIso
  if ($prev) {
    $recent = $false
    if ($prev.lastSeen) {
      try {
        $lastSeenDate = [datetime]::Parse([string]$prev.lastSeen, [Globalization.CultureInfo]::InvariantCulture)
        if (($now - $lastSeenDate).TotalDays -le 7) { $recent = $true }
      } catch { }
    }
    if ($recent) {
      $seenRuns = [int]$prev.seenRuns + 1
      if ($prev.firstSeen) { $firstSeen = [string]$prev.firstSeen }
    }
  }

  $confidence = 18 * $sourceCount + 25 * $avgWeight
  if ($seenRuns -ge 3) { $confidence += 15 } elseif ($seenRuns -eq 2) { $confidence += 8 } else { $confidence += 5 }
  if ($works -gt 0) { $confidence += [Math]::Min(9, 3 * [Math]::Log10($works + 1)) }
  $expires = $best.expiresInDays
  if ($null -ne $expires -and [int]$expires -gt 7) { $confidence += 10 }
  elseif ($null -ne $expires) { $confidence += 4 }
  else { $confidence += 6 }
  $confidence = [int][Math]::Min(100, [Math]::Round($confidence))

  $verification = 'single'
  $verificationMethod = 'source'
  if ($sourceCount -ge 2 -and $avgWeight -ge 0.6) {
    $verification = 'confirmed'
    $verificationMethod = 'multi-source'
  }
  elseif ($sourceCount -eq 1 -and $avgWeight -ge 0.8 -and $seenRuns -ge 5) {
    $verification = 'confirmed'
    $verificationMethod = 'history'
  }
  elseif ($sourceCount -eq 1 -and $avgWeight -ge 0.8) { $verification = 'likely' }
  elseif ($sourceCount -eq 1 -and $avgWeight -ge 0.7 -and $seenRuns -ge 2) { $verification = 'likely' }
  if ($null -ne $expires -and [int]$expires -lt 0) { $verification = 'expired' }

  $evidenceMap = @{}
  foreach ($it in $codeItems) {
    if (-not $it.sourceName) { continue }
    $ev = [ordered]@{ source = $it.sourceName; url = $it.sourceUrl; works = [int]$it.works }
    if (-not $evidenceMap.ContainsKey($it.sourceName)) {
      $evidenceMap[$it.sourceName] = $ev
    }
    elseif ($evidenceMap[$it.sourceName].works -lt $ev.works) {
      $evidenceMap[$it.sourceName] = $ev
    }
  }

  $best['confidence'] = $confidence
  $best['verification'] = $verification
  $best['verificationMethod'] = $verificationMethod
  $best['sourceCount'] = $sourceCount
  $best['evidence'] = @($evidenceMap.Values)
  $best['alsoServices'] = @($list | ForEach-Object { $_.service } | Where-Object { $_ -and $_ -ne $best.service } | Select-Object -Unique)
  $best['firstSeenAt'] = $firstSeen
  $best['lastSeenAt'] = $nowIso
  $best['seenRuns'] = $seenRuns

  $final += $best
  $stateCodes[$key] = [ordered]@{
    firstSeen = $firstSeen
    lastSeen  = $nowIso
    seenRuns  = $seenRuns
    sources   = $evidenceSources
  }
}

# Prune old state entries (older than 45 days) so the file does not grow forever.
$cutoff = $now.AddDays(-45)
foreach ($key in @($stateCodes.Keys)) {
  try {
    $last = [datetime]::Parse([string]$stateCodes[$key].lastSeen, [Globalization.CultureInfo]::InvariantCulture)
    if ($last -lt $cutoff) { $stateCodes.Remove($key) }
  } catch { }
}

$final = @($final | Sort-Object -Property @(
  @{ Expression = { if ($_.verification -eq 'confirmed') { 0 } elseif ($_.verification -eq 'likely') { 1 } elseif ($_.verification -eq 'single') { 2 } else { 3 } } },
  @{ Expression = { $_.confidence }; Descending = $true },
  @{ Expression = { $_.existingUsers }; Descending = $true },
  @{ Expression = { $_.value }; Descending = $true },
  @{ Expression = { $_.code }; Descending = $false }
))

$directory = Split-Path -Parent $OutFile
if (-not (Test-Path $directory)) {
  New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

$confirmed = @($final | Where-Object { $_.verification -eq 'confirmed' }).Count
$likely = @($final | Where-Object { $_.verification -eq 'likely' }).Count
$single = @($final | Where-Object { $_.verification -eq 'single' }).Count
$expired = @($final | Where-Object { $_.verification -eq 'expired' }).Count
$serviceCount = @($final | ForEach-Object { $_.service } | Select-Object -Unique).Count

$healthPrevious = @{}
if (Test-Path $healthFile) {
  try {
    $healthRaw = Get-Content -Raw -Encoding UTF8 $healthFile | ConvertFrom-Json
    foreach ($prop in $healthRaw.sources.PSObject.Properties) {
      $healthPrevious[$prop.Name] = $prop.Value
    }
  } catch { }
}
$health = [ordered]@{}
foreach ($name in ($script:Sources | ForEach-Object { $_.name } | Select-Object -Unique)) {
  $cur = $healthRun[$name]
  if (-not $cur) { $cur = @{ count = 0; error = 'not run' } }
  $prev = $healthPrevious[$name]
  $runs = 1
  $totalCodes = [int]$cur.count
  if ($prev) {
    $runs = [int]$prev.totalRuns + 1
    $totalCodes = [int]$prev.totalCodes + [int]$cur.count
  }
  $status = 'ok'
  if ($cur.error) { $status = 'error' }
  elseif ([int]$cur.count -eq 0) { $status = 'empty' }
  $health[$name] = [ordered]@{
    lastRun      = $nowIso
    lastCount    = [int]$cur.count
    lastError    = $cur.error
    totalRuns    = $runs
    totalCodes   = $totalCodes
    averageCount = [math]::Round($totalCodes / $runs, 1)
    status       = $status
  }
}

if ($final.Count -lt 10) {
  Write-Log ('Only ' + $final.Count + ' codes collected; keeping the previous feed.')
  exit 1
}

$statePayload = [ordered]@{
  updatedAt = $nowIso
  codes     = $stateCodes
}
[IO.File]::WriteAllText($stateFile, ($statePayload | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))

$healthPayload = [ordered]@{
  updatedAt = $nowIso
  sources   = $health
}
[IO.File]::WriteAllText($healthFile, ($healthPayload | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false)))

$payload = [ordered]@{
  updatedAt = $nowIso
  generator = 'PromoLov collector v2'
  stats     = [ordered]@{
    total     = $final.Count
    confirmed = $confirmed
    likely    = $likely
    single    = $single
    expired   = $expired
    services  = $serviceCount
    sources   = @($script:Sources | ForEach-Object { $_.name } | Select-Object -Unique).Count
  }
  sources   = @($script:Sources | ForEach-Object { [ordered]@{ name = $_.name; url = $_.url; kind = $_.kind; group = $_.group } })
  codes     = $final
}

$json = $payload | ConvertTo-Json -Depth 8
$tempFile = $OutFile + '.tmp'
[IO.File]::WriteAllText($tempFile, $json, (New-Object Text.UTF8Encoding($false)))
Move-Item -LiteralPath $tempFile -Destination $OutFile -Force

Write-Log ('Saved ' + $final.Count + ' unique codes to ' + $OutFile)
Write-Log ('Confirmed: ' + $confirmed + ', likely: ' + $likely + ', single: ' + $single + ', services: ' + $serviceCount)
