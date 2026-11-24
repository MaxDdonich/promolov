/* ============================================================
   ПромоЛов — логика приложения
   Без сборки и зависимостей: открывается прямо из index.html.
   ============================================================ */
(function () {
  'use strict';

  const DAY = 86400000;
  const HOUR = 3600000;
  const BEST_SCORE = 78;
const MIN_PAY_SHARE = 0.50;
const MIN_PAY_ABS = 50;
  const LS_KEY = 'promolov.v2';
  const FEED_CACHE_KEY = 'promolov.feedCache.v1';

  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));
  const nf = new Intl.NumberFormat('ru-RU');
  const money = (n) => nf.format(Math.max(0, Math.round(n || 0))) + ' ₽';
  const clamp = (n, min, max) => Math.min(max, Math.max(min, n));
  const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

  const SERVICES = {
    'Яндекс Еда': { color: '#FC3F1D', mark: 'Я', site: 'https://eda.yandex.ru' },
    'Самокат': { color: '#FF3B5C', mark: 'С', site: 'https://samokat.ru' },
    'Купер': { color: '#7B61FF', mark: 'К', site: 'https://kuper.ru' },
    'ВкусВилл': { color: '#009B4E', mark: 'В', site: 'https://vkusvill.ru' },
    'ВкусМил': { color: '#6A9A23', mark: 'ВМ', site: 'https://vkusmil.ru' },
    'Додо Пицца': { color: '#FF5A00', mark: 'Д', site: 'https://dodopizza.ru' },
    'Ozon Fresh': { color: '#005BFF', mark: 'O', site: 'https://ozon.ru' },
    'Лавка': { color: '#00C2A8', mark: 'Л', site: 'https://lavka.yandex.ru' },
    'Перекрёсток': { color: '#00A651', mark: 'П', site: 'https://perekrestok.ru' },
    'Магнит': { color: '#E4002B', mark: 'М', site: 'https://magnit.ru' },
    'Пятёрочка': { color: '#00A64F', mark: '5', site: 'https://5ka.ru' },
    'Дикси': { color: '#E30613', mark: 'Д', site: 'https://dixy.ru' },
    'Sushiwok': { color: '#F25C05', mark: 'S', site: 'https://sushiwok.ru' },
    "Rostic's": { color: '#E4002B', mark: 'R', site: 'https://rostics.ru' },
    'Ollis': { color: '#FF7A00', mark: 'O', site: 'https://ollis.ru' },
    "Domino's Pizza": { color: '#0B5CAB', mark: 'D', site: 'https://dominos.ru' },
    "Papa John's": { color: '#B5121B', mark: 'PJ', site: 'https://papajohns.ru' },
    'ЁбиДоёби': { color: '#FF4D00', mark: 'Ё', site: 'https://yobidoyobi.ru' },
    'Ашан': { color: '#E4002B', mark: 'А', site: 'https://auchan.ru' },
    'Just Food': { color: '#6BBF59', mark: 'J', site: 'https://justfood.ru' },
    'Elementaree': { color: '#8BC34A', mark: 'E', site: 'https://elementaree.ru' },
    '2 Берега': { color: '#1F8A70', mark: '2', site: 'https://2berega.ru' },
    'Азбука Вкуса': { color: '#2E6BE6', mark: 'А', site: 'https://av.ru' },
    'Деливери': { color: '#FF4D00', mark: 'Д', site: 'https://delivery-club.ru' },
    'Яндекс Лавка': { color: '#FC3F1D', mark: 'Л', site: 'https://lavka.yandex.ru' },
    'Лента': { color: '#E4002B', mark: 'Л', site: 'https://lenta.com' },
    'Глобус': { color: '#E30613', mark: 'Г', site: 'https://globus.ru' },
    'Метро': { color: '#003D7C', mark: 'М', site: 'https://metro-cc.ru' },
    'KFC': { color: '#E4002B', mark: 'K', site: 'https://kfc.ru' },
    'Burger King': { color: '#D62300', mark: 'B', site: 'https://burgerking.ru' },
    'Вкусно — и точка': { color: '#FF7A00', mark: 'В', site: 'https://vkusnoitochka.ru' },
    'Sushi Master': { color: '#D62828', mark: 'S', site: 'https://sushimaster.ru' },
    'Тануки': { color: '#1F8A70', mark: 'Т', site: 'https://tanuki.ru' },
    'Якитория': { color: '#C1121F', mark: 'Я', site: 'https://yakitoria.ru' },
    'Grow Food': { color: '#6BBF59', mark: 'G', site: 'https://growfood.ru' },
    'Level Kitchen': { color: '#2A9D8F', mark: 'L', site: 'https://levelkitchen.ru' },
    "Let's Food": { color: '#8BC34A', mark: 'L', site: 'https://letsfood.ru' },
    'Chef Mike': { color: '#4F772D', mark: 'C', site: 'https://chefmike.ru' },
    'My Food': { color: '#588157', mark: 'M', site: 'https://myfood.ru' },
    'BeFit': { color: '#00A896', mark: 'B', site: 'https://befit.ru' },
    'Priem.menu': { color: '#F4A261', mark: 'P', site: 'https://priem.menu' },
    'FoodBand': { color: '#E76F51', mark: 'F', site: 'https://foodband.ru' },
    'Сибаристика': { color: '#6D597A', mark: 'С', site: 'https://sibaristica.ru' }
  };

  const serviceOf = (name) => SERVICES[name] || {
    color: '#9aa4ad',
    mark: (String(name || '?').trim()[0] || '?').toUpperCase(),
    site: '#'
  };

  /* ---------- Хранилище ---------- */

  const store = {
    fav: new Set(),
    votes: {},
    caught: new Set(),
    sources: {},
    paused: false,
    feedUrl: '',
    onlyWorking: true,
    load() {
      try {
        const raw = localStorage.getItem(LS_KEY);
        if (!raw) return;
        const data = JSON.parse(raw);
        this.fav = new Set(Array.isArray(data.fav) ? data.fav : []);
        this.votes = data.votes && typeof data.votes === 'object' ? data.votes : {};
        this.caught = new Set(Array.isArray(data.caught) ? data.caught : []);
        this.sources = data.sources && typeof data.sources === 'object' ? data.sources : {};
        this.paused = !!data.paused;
        this.feedUrl = typeof data.feedUrl === 'string' ? data.feedUrl : '';
        this.onlyWorking = data.onlyWorkingV3 === true ? data.onlyWorking !== false : true;
      } catch (err) {
        /* localStorage может быть недоступен на file:// — работаем в памяти */
      }
    },
    save() {
      try {
        localStorage.setItem(LS_KEY, JSON.stringify({
          fav: [...this.fav],
          votes: this.votes,
          caught: [...this.caught],
          sources: this.sources,
          paused: this.paused,
          feedUrl: this.feedUrl,
          onlyWorking: this.onlyWorking,
          onlyWorkingV3: true
        }));
      } catch (err) { /* ignore */ }
    }
  };
  store.load();

  /* ---------- Данные ---------- */

  function decorate(raw) {
    const now = Date.now();
    let expiresAt = null;
    if (raw.expiresInDays != null) {
      const days = Number(raw.expiresInDays);
      if (Number.isFinite(days)) {
        const safe = days < 0 ? -1 : Math.max(0.5, days);
        expiresAt = now + safe * DAY;
      }
    }
    const lastSeen = raw.lastSeenAt ? Date.parse(raw.lastSeenAt) : NaN;
    const firstSeen = raw.firstSeenAt ? Date.parse(raw.firstSeenAt) : NaN;
    return {
      ...raw,
      verifiedAt: Number.isFinite(lastSeen)
        ? lastSeen
        : (raw.fromFeed ? null : now - (raw.verifiedDaysAgo != null ? raw.verifiedDaysAgo : 2) * DAY),
      addedAt: Number.isFinite(firstSeen)
        ? firstSeen
        : (raw.fromFeed ? now : now - (raw.addedDaysAgo != null ? raw.addedDaysAgo : 2) * DAY),
      expiresAt: expiresAt,
      isNew: false
    };
  }

  const seedCodes = (window.PROMO_SEED || []).map(decorate);
  const pendingCodes = (window.PROMO_PENDING || []).map(decorate);
  const sources = (window.PROMO_SOURCES || []).map((s) => ({ ...s }));

  let codes = seedCodes.concat(pendingCodes.filter((c) => store.caught.has(c.id)));

  const ui = {
    q: '',
    service: 'all',
    collections: new Set(),
    onlyBest: false,
    onlyWorking: store.onlyWorking,
    freeDelivery: false,
    onlyFav: false,
    sort: 'score',
    limit: 24
  };
  const PAGE_SIZE = 24;

  const COLLECTIONS = [
    { id: 'all', label: 'Все коды', icon: '✦' },
    { id: 'confirmed', label: 'Только подтверждённые', icon: '✓' },
    { id: 'moscow', label: 'Москва', icon: '⌂' },
    { id: 'city', label: 'Только в городах', icon: '⌖' },
    { id: 'returning', label: 'Уже пользовался сервисом', icon: '↻' },
    { id: 'wholeCart', label: 'Скидка на всю корзину', icon: '▦' },
    { id: 'feed', label: 'Собрано с сайтов', icon: '⇣' }
  ];

  let lastUpdate = Date.now();
  let tickTimer = null;
  const srcStats = {};
  const logEntries = [];

  /* ---------- Утилиты ---------- */

  function esc(value) {
    return String(value == null ? '' : value)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  const fmtDate = (ts) => new Date(ts).toLocaleDateString('ru-RU', { day: 'numeric', month: 'short' });

  function timeAgo(ts) {
    const sec = Math.max(0, Math.round((Date.now() - ts) / 1000));
    if (sec < 15) return 'только что';
    if (sec < 60) return sec + ' сек назад';
    const min = Math.round(sec / 60);
    if (min < 60) return min + ' мин назад';
    const h = Math.round(min / 60);
    return h + ' ч назад';
  }

  function expiryLabel(ts) {
    if (!ts) return 'бессрочно';
    const left = ts - Date.now();
    if (left < 0) return 'истёк';
    const hours = left / HOUR;
    if (hours < 24) return 'истекает сегодня';
    const days = Math.round(hours / 24);
    if (days <= 2) return 'ещё ' + days + ' дн.';
    if (days <= 7) return 'ещё ' + days + ' дн.';
    return 'до ' + fmtDate(ts);
  }

  function expiryLabelFor(code) {
    if (!code.expiresAt) return code.fromFeed ? 'срок не указан' : 'бессрочно';
    return expiryLabel(code.expiresAt);
  }

  function daysLeft(ts) {
    return ts ? (ts - Date.now()) / DAY : Infinity;
  }

  function verifiedLabel(ts) {
    if (!ts) return 'не проверялся';
    const hours = (Date.now() - ts) / HOUR;
    if (hours < 1) return 'только что';
    if (hours < 24) return 'сегодня';
    const days = Math.round(hours / 24);
    if (days === 1) return 'вчера';
    return days + ' дн. назад';
  }

  /* ---------- Расчёт выгоды ---------- */

  function counts(code) {
    const vote = store.votes[code.id] || { up: 0, down: 0 };
    if (code.fromFeed) {
      // Для фида источник сообщает только популярность, а не успешность.
      // Рабочим код делает подтверждение пользователей, поэтому считаем только их голоса.
      return { works: vote.up || 0, fails: vote.down || 0 };
    }
    return {
      works: (code.works || 0) + (vote.up || 0),
      fails: (code.fails || 0) + (vote.down || 0)
    };
  }

  function statusOf(code) {
    if (code.expiresAt && code.expiresAt < Date.now()) {
      return { id: 'expired', label: 'Истёк', tone: 'bad' };
    }
    if (code.verification === 'confirmed') {
      return { id: 'confirmed', label: 'Подтверждён', tone: 'good' };
    }
    if (code.verification === 'likely') {
      return { id: 'likely', label: 'Вероятно рабочий', tone: 'good' };
    }
    if (code.verification === 'single') {
      return { id: 'single', label: 'Один источник', tone: 'warn' };
    }
    const { works, fails } = counts(code);
    const total = works + fails;
    if (total >= 5) {
      const rate = works / total;
      if (rate < 0.45) return { id: 'broken', label: 'Не работает', tone: 'bad' };
      if (rate < 0.7) return { id: 'shaky', label: 'Спорный', tone: 'warn' };
      return { id: 'working', label: 'Рабочий', tone: 'good' };
    }
    if (code.fromFeed) return { id: 'fresh', label: 'Не проверен', tone: 'warn' };
    return { id: 'demo', label: 'Демо-пример', tone: 'dim' };
  }

  function feedExists() {
    return codes.some((code) => code.fromFeed);
  }

  function workingMatch(code) {
    if (!ui.onlyWorking) return true;
    if (code.fromFeed) {
      return code.verification === 'confirmed' || code.verification === 'likely';
    }
    if (feedExists()) return false;
    return statusOf(code).id === 'working';
  }

  function workingPool() {
    return codes.filter((code) => {
      if (code.expiresAt && code.expiresAt < Date.now()) return false;
      return workingMatch(code);
    });
  }

  function savings(code, sum) {
    const min = code.minOrder || 0;
    const applicable = sum >= min;
    const partial = code.type === 'percent' && code.wholeCart === false;
    const minPay = sum > 0 ? Math.max(MIN_PAY_ABS, Math.ceil(sum * MIN_PAY_SHARE)) : 0;
    const maxDiscount = Math.max(0, sum - minPay);
    let rawDiscount = 0;
    let capped = false;
    if (applicable && !partial) {
      if (code.type === 'percent') rawDiscount = (sum * clamp(code.value || 0, 0, 100)) / 100;
      else if (code.type === 'fixed') rawDiscount = code.value || 0;
      if (code.maxDiscount) rawDiscount = Math.min(rawDiscount, code.maxDiscount);
      capped = rawDiscount > maxDiscount;
      rawDiscount = Math.min(rawDiscount, maxDiscount);
    }
    const delivery = applicable && code.freeDelivery ? (code.deliveryCost || 149) : 0;
    const maxTotal = sum > 0 ? Math.max(0, sum + delivery - minPay) : 0;
    const total = Math.min(rawDiscount + delivery, maxTotal);
    const pay = Math.max(minPay, sum + delivery - total);
    return {
      applicable,
      partial,
      need: min,
      minPay: Math.round(minPay),
      discount: Math.round(rawDiscount),
      delivery: Math.round(delivery),
      total: Math.round(total),
      pay: Math.round(pay),
      capped
    };
  }

  function scoreOf(code) {
    const ref = Math.max(1200, code.minOrder || 0);
    if (code.expiresAt && code.expiresAt < Date.now()) return 0;

    const save = savings(code, ref);
    const roi = save.total / ref;
    const { works, fails } = counts(code);
    const reliability = code.confidence
      ? clamp(code.confidence / 100, 0, 1)
      : (works + 6) / (works + fails + 12);
    const ageDays = code.verifiedAt ? Math.max(0, (Date.now() - code.verifiedAt) / DAY) : 30;
    const freshness = Math.exp(-ageDays / 16);

    let urgency = 0.55;
    if (code.expiresAt) {
      const left = daysLeft(code.expiresAt);
      urgency = 0.55 + clamp(1 - left / 18, 0, 1) * 0.45;
    }

    const score = 100 * (
      0.5 * clamp(roi / 0.35, 0, 1) +
      0.28 * reliability +
      0.17 * freshness +
      0.05 * urgency
    );
    return Math.round(clamp(score, 0, 100));
  }

  function scoreTier(score) {
    if (score >= 80) return 'high';
    if (score >= 65) return 'mid';
    return 'low';
  }

  function valueLabel(code) {
    if (code.type === 'percent') return '−' + code.value + '%';
    if (code.type === 'fixed') return '−' + money(code.value);
    return 'доставка 0 ₽';
  }

  /* ---------- Источники и журнал ---------- */

  function sourceById(id) {
    return sources.find((s) => s.id === id) || null;
  }

  function isSourceOn(src) {
    return store.sources[src.id] !== false;
  }

  function enabledSources() {
    return sources.filter(isSourceOn);
  }

  function addLog(text, kind) {
    logEntries.unshift({ text: text, kind: kind || 'info', t: Date.now() });
    if (logEntries.length > 60) logEntries.pop();
    renderLog();
  }

  function renderLog() {
    const log = $('#log');
    if (!log) return;
    $('#logCount').textContent = logEntries.length ? logEntries.length + ' записей' : '';
    if (!logEntries.length) {
      log.innerHTML = '<div class="log__empty">Пока пусто. Сборщик начнёт писать сюда при первой проверке.</div>';
      return;
    }
    log.innerHTML = logEntries.map((entry) => {
      const time = new Date(entry.t).toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
      return '<div class="log__row" data-kind="' + entry.kind + '"><span class="log__time">' + time + '</span><span>' + esc(entry.text) + '</span></div>';
    }).join('');
  }

  function renderSources() {
    const list = $('#sourceList');
    if (!list) return;

    list.innerHTML = sources.map((src) => {
      const on = isSourceOn(src);
      const stats = srcStats[src.id] || { checks: 0, found: 0, last: 0 };
      const statText = stats.checks
        ? 'проверок: ' + stats.checks + ' · найдено: ' + stats.found + ' · ' + timeAgo(stats.last)
        : 'ещё не проверялся';

      return '' +
        '<div class="source ' + (on ? 'is-on' : '') + '">' +
          '<span class="source__icon" aria-hidden="true">' + esc(src.icon || '🔗') + '</span>' +
          '<div class="source__body">' +
            '<div class="source__name">' + esc(src.name) + '</div>' +
            '<div class="source__hint">' + esc(src.hint || '') + '</div>' +
            '<div class="source__stats">' + statText + '</div>' +
          '</div>' +
          '<label class="switch" title="Включить или выключить источник">' +
            '<input type="checkbox" data-source="' + esc(src.id) + '"' + (on ? ' checked' : '') + ' aria-label="Источник ' + esc(src.name) + '">' +
            '<span class="switch__track" aria-hidden="true"><i></i></span>' +
          '</label>' +
        '</div>';
    }).join('');

    $('#srcCount').textContent = enabledSources().length;
  }

  /* ---------- Автолов ---------- */

  function checkSource(src, opts) {
    const options = opts || {};
    const stats = srcStats[src.id] || (srcStats[src.id] = { checks: 0, found: 0, last: 0 });
    stats.checks += 1;
    stats.last = Date.now();

    const pool = pendingCodes.filter((code) => !store.caught.has(code.id) && code.sourceId === src.id);
    const chance = options.chance != null ? options.chance : (options.force ? 1 : 0.45);

    if (pool.length && Math.random() < chance) {
      catchCode(pool[0], src);
    } else {
      addLog(src.name + ': новых кодов нет', 'ok');
    }

    renderSources();
  }

  function catchCode(code, src) {
    store.caught.add(code.id);
    store.save();
    codes.push(code);
    code.isNew = true;
    lastUpdate = Date.now();

    const stats = srcStats[src.id] || (srcStats[src.id] = { checks: 0, found: 0, last: Date.now() });
    stats.found += 1;

    addLog('🎣 ' + src.name + ': поймали ' + code.code + ' — ' + code.title, 'new');
    toast('🎣 Новый промокод: ' + code.code, code.service + ' · ' + valueLabel(code));
    renderAll();

    setTimeout(() => {
      code.isNew = false;
      renderGrid();
    }, 9000);
  }

  function scheduleTick(delay) {
    clearTimeout(tickTimer);
    tickTimer = setTimeout(tick, delay);
  }

  function tick() {
    if (store.paused) return;
    if (feedExists()) {
      scheduleTick(60000);
      return;
    }
    const list = enabledSources();
    if (!list.length) {
      addLog('Все источники выключены — автолов ждёт', 'err');
      scheduleTick(20000);
      return;
    }
    const src = list[Math.floor(Math.random() * list.length)];
    checkSource(src);
    scheduleTick(12000 + Math.random() * 10000);
  }

  function startCollector() {
    clearTimeout(tickTimer);
    if (store.paused) return;
    scheduleTick(4000 + Math.random() * 3000);
  }

  function updateLive() {
    const live = $('#liveStatus');
    const pauseBtn = $('#btnPause');
    const on = !store.paused;

    live.dataset.state = on ? 'on' : 'off';
    $('#liveText').textContent = on ? 'ловим промокоды' : 'автолов на паузе';
    $('#liveMeta').textContent = on
      ? 'обновлено ' + timeAgo(lastUpdate)
      : 'нажмите ▶, чтобы продолжить';
    pauseBtn.textContent = on ? '⏸' : '▶';
    pauseBtn.setAttribute('aria-label', on ? 'Пауза автолова' : 'Продолжить автолов');
    pauseBtn.title = on ? 'Пауза автолова' : 'Продолжить автолов';
    $('#srcCount').textContent = enabledSources().length;
  }

  /* ---------- Рендер ---------- */

  function baseMatch(code) {
    if (!code.fromFeed && feedExists()) return false;
    if (code.expiresAt && code.expiresAt < Date.now()) return false;
    if (!workingMatch(code)) return false;
    if (ui.service !== 'all' && code.service !== ui.service) return false;
    if (ui.onlyFav && !store.fav.has(code.id)) return false;
    if (ui.freeDelivery && !code.freeDelivery) return false;
    if (ui.onlyBest && scoreOf(code) < BEST_SCORE) return false;
    const q = ui.q.trim().toLowerCase();
    if (q) {
      const hay = [
        code.service, code.code, code.title,
        (code.category || []).join(' '), code.sourceNote || '',
        code.existingUsers ? 'повторный повторно уже пользовался' : 'первый заказ новый клиент',
        code.wholeCart ? 'вся корзина весь заказ' : '',
        (code.cities || []).join(' ')
      ].join(' ').toLowerCase();
      if (!hay.includes(q)) return false;
    }
    return true;
  }

  function moscowMatch(code) {
    if (!code.cityRestricted) return true;
    return (code.cities || []).some((city) => /москв|московск/i.test(city));
  }

  function matchesCollection(code, id) {
    if (id === 'confirmed') return code.verification === 'confirmed';
    if (id === 'returning') return !!code.existingUsers;
    if (id === 'wholeCart') return !!code.wholeCart;
    if (id === 'feed') return !!code.fromFeed;
    if (id === 'city') return !!code.cityRestricted;
    if (id === 'moscow') return moscowMatch(code);
    return true;
  }

  function collectionMatch(code) {
    for (const id of ui.collections) {
      if (!matchesCollection(code, id)) return false;
    }
    return true;
  }

  function visibleCodes() {
    const list = codes.filter((code) => baseMatch(code) && collectionMatch(code));

    list.sort((a, b) => {
      if (ui.sort === 'expiry') {
        const ea = a.expiresAt || Infinity;
        const eb = b.expiresAt || Infinity;
        return ea - eb;
      }
      if (ui.sort === 'new') {
        return b.addedAt - a.addedAt;
      }
      return scoreOf(b) - scoreOf(a);
    });

    return list;
  }

  function cardHTML(code) {
    const sv = serviceOf(code.service);
    const score = scoreOf(code);
    const status = statusOf(code);
    const metric = code.sourceCount > 1 ? status.label + ' · ' + code.sourceCount + ' ист.' : status.label;
    const fav = store.fav.has(code.id);
    const tags = [
      code.existingUsers
        ? '<span class="tag tag--ok">можно повторно</span>'
        : '<span class="tag tag--warn">только 1-й заказ</span>'
    ];
    if (code.wholeCart) tags.push('<span class="tag tag--accent">вся корзина</span>');
    if (code.freeDelivery) tags.push('<span class="tag">доставка 0 ₽</span>');
    if (code.minOrder > 0) tags.push('<span class="tag">от ' + money(code.minOrder) + '</span>');
    if (code.verification === 'confirmed') tags.push('<span class="tag tag--ok">✓ подтверждён</span>');
    else if (code.verification === 'single') tags.push('<span class="tag tag--warn">1 источник</span>');
    if (code.cityRestricted && (code.cities || []).length) {
      const cityList = code.cities;
      const cityText = cityList.length > 2
        ? cityList.slice(0, 2).join(', ') + ' +' + (cityList.length - 2)
        : cityList.join(', ');
      tags.push('<span class="tag tag--city">' + esc(cityText) + '</span>');
    }
    const left = daysLeft(code.expiresAt);
    if (left <= 3) {
      tags.push('<span class="tag tag--warn">' + esc(expiryLabel(code.expiresAt)) + '</span>');
    }

    return '' +
      '<article class="card ' + (code.isNew ? 'is-new' : '') + '" style="--brand:' + sv.color + '" data-id="' + esc(code.id) + '">' +
        (code.isNew ? '<span class="card__new">новый</span>' : '') +
        '<div class="card__top">' +
          '<div class="brand">' +
            '<span class="brand__mark" aria-hidden="true">' + esc(sv.mark) + '</span>' +
            '<span class="brand__info"><b>' + esc(code.service) + '</b><span>' + esc(code.sourceNote || 'промокод') + (code.sourceCount > 1 ? ' · ' + code.sourceCount + ' ист.' : '') + (code.fromFeed ? '' : ' · демо') + '</span></span>' +
          '</div>' +
          '<button class="fav ' + (fav ? 'is-on' : '') + '" type="button" data-action="fav" data-id="' + esc(code.id) + '" aria-pressed="' + fav + '" aria-label="В избранное" title="В избранное">' + (fav ? '★' : '☆') + '</button>' +
        '</div>' +

        '<div class="card__hero">' +
          '<div class="card__value">' + valueLabel(code) + '</div>' +
          '<div class="score-wrap">' +
            '<div class="score" data-tier="' + scoreTier(score) + '" style="--score:' + score + '" title="Индекс выгоды: ' + score + ' из 100"><span>' + score + '</span></div>' +
            '<i>выгода</i>' +
          '</div>' +
        '</div>' +

        '<p class="card__title">' + esc(code.title) + '</p>' +
        '<div class="card__tags">' + tags.join('') + '</div>' +

        '<div class="card__code">' +
          '<code>' + esc(code.code) + '</code>' +
          '<button class="btn btn--copy" type="button" data-action="copy" data-id="' + esc(code.id) + '">Скопировать</button>' +
        '</div>' +

        '<div class="card__foot">' +
          '<span>' + esc(metric) + ' · ' + esc(verifiedLabel(code.verifiedAt)) + '</span>' +
          '<button class="link" type="button" data-action="details" data-id="' + esc(code.id) + '">Детали →</button>' +
        '</div>' +
      '</article>';
  }

  function renderCollections() {
    const base = codes.filter(baseMatch);
    const selected = [...ui.collections];
    const counts = { all: base.length };

    COLLECTIONS.forEach((item) => {
      if (item.id === 'all') return;
      const others = selected.filter((id) => id !== item.id);
      counts[item.id] = base.filter((code) =>
        others.every((id) => matchesCollection(code, id)) && matchesCollection(code, item.id)
      ).length;
    });

    $('#collectionChips').innerHTML = COLLECTIONS.map((item) => {
      const active = item.id === 'all' ? ui.collections.size === 0 : ui.collections.has(item.id);
      const hint = item.id === 'all'
        ? 'Сбросить все подборки'
        : item.id === 'moscow'
          ? 'Доступны в Москве: общероссийские и Москва/МО'
          : item.id === 'city'
            ? 'Только коды с ограничением по городам'
            : '';
      return '<button class="pick ' + (active ? 'is-on' : '') + '" type="button" data-collection="' + item.id + '" aria-pressed="' + active + '"' + (hint ? ' title="' + hint + '"' : '') + '>' +
        '<span class="pick__icon" aria-hidden="true">' + item.icon + '</span>' +
        esc(item.label) +
        ' <span class="pick__count">' + counts[item.id] + '</span>' +
      '</button>';
    }).join('');
  }

  function renderChips() {
    const counter = new Map();
    workingPool().forEach((code) => {
      counter.set(code.service, (counter.get(code.service) || 0) + 1);
    });
    const services = Array.from(counter.entries()).sort((a, b) => b[1] - a[1]);
    const items = [['all', 'Все', workingPool().length]].concat(
      services.map(([name, total]) => [name, name, total])
    );

    $('#serviceChips').innerHTML = items.map(([key, label, total]) => {
      const active = ui.service === key;
      const color = key === 'all' ? 'var(--lime)' : serviceOf(key).color;
      return '<button class="chip ' + (active ? 'is-on' : '') + '" type="button" data-service="' + esc(key) + '" style="--c:' + color + '" aria-pressed="' + active + '">' +
        esc(label) + ' <span>' + total + '</span></button>';
    }).join('');
  }

  function renderGrid() {
    const all = visibleCodes();
    const showAllBtn = $('#btnShowAll');
    if (showAllBtn) showAllBtn.textContent = ui.onlyWorking ? 'Показать все' : 'Скрыть неподтверждённые';
    const list = all.slice(0, ui.limit);
    const pool = workingPool();
    $('#grid').innerHTML = list.map(cardHTML).join('');
    $('#empty').hidden = all.length > 0;

    const moreWrap = $('#loadMoreWrap');
    const moreBtn = $('#btnLoadMore');
    if (moreWrap) {
      const rest = Math.max(0, all.length - list.length);
      moreWrap.hidden = rest <= 0;
      if (moreBtn) moreBtn.hidden = rest <= 0;
      const moreCount = $('#loadMoreCount');
      if (moreCount) moreCount.textContent = rest > 0 ? '(+' + rest + ')' : '';
    }

    const selectedLabels = [...ui.collections]
      .map((id) => (COLLECTIONS.find((item) => item.id === id) || {}).label)
      .filter(Boolean);
    const collectionNote = selectedLabels.length ? ' · ' + selectedLabels.join(' + ').toLowerCase() : '';
    $('#resultsMeta').textContent = all.length
      ? list.length + ' из ' + all.length + collectionNote + (ui.onlyWorking ? ' · только рабочие' : '') + (ui.onlyBest ? ' · порог ' + BEST_SCORE : '')
      : 'ничего не найдено';

    if (!all.length) {
      const title = $('#emptyTitle');
      const text = $('#emptyText');
      if (title && text) {
        if (ui.collections.size) {
          title.textContent = 'Нет кодов с такой комбинацией подборок';
          text.textContent = 'Снимите одну из подборок или измените остальные фильтры. Подборки работают как пересечение: код должен подходить под все выбранные.';
        } else if (ui.onlyWorking) {
          title.textContent = 'Нет подтверждённых рабочих кодов';
          text.textContent = 'Попробуйте отключить «только рабочие» или обновить фид. Неподтверждённые и демо-коды скрыты.';
        } else {
          title.textContent = 'Ничего не поймали по этим фильтрам';
          text.textContent = 'Сбросьте фильтры — подходящий код найдётся.';
        }
      }
    }

    updateLive();
  }

  function renderStats() {
    const active = workingPool();
    const confirmed = active.filter((code) => code.verification === 'confirmed').length;
    const services = new Set(active.map((code) => code.service)).size;
    $('#statCount').textContent = active.length;
    $('#statBest').textContent = confirmed;
    $('#statAvg').textContent = services;
  }

  function renderAll() {
    renderStats();
    renderChips();
    renderCollections();
    renderGrid();
    renderSources();
    updateLive();
  }

  function renderResults() {
    ui.limit = PAGE_SIZE;
    renderCollections();
    renderGrid();
  }

  /* ---------- Тосты и копирование ---------- */

  function toast(title, subtitle) {
    const host = $('#toasts');
    const el = document.createElement('div');
    el.className = 'toast';
    el.innerHTML = '<b>' + esc(title) + '</b>' + (subtitle ? '<span>' + esc(subtitle) + '</span>' : '');
    host.appendChild(el);
    setTimeout(() => {
      el.classList.add('is-out');
      setTimeout(() => el.remove(), 260);
    }, 3600);
  }

  function legacyCopy(text) {
    const area = document.createElement('textarea');
    area.value = text;
    area.setAttribute('readonly', '');
    area.style.position = 'fixed';
    area.style.top = '-1000px';
    document.body.appendChild(area);
    area.select();
    const ok = document.execCommand('copy');
    area.remove();
    if (!ok) throw new Error('copy failed');
  }

  async function copyCode(code, btn) {
    let ok = false;
    try {
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(code.code);
        ok = true;
      }
    } catch (err) { /* переходим к запасному способу */ }

    if (!ok) {
      try {
        legacyCopy(code.code);
        ok = true;
      } catch (err) { /* ниже покажем ошибку */ }
    }

    if (!ok) {
      toast('Не удалось скопировать', 'Выделите код вручную и нажмите Ctrl+C');
      return;
    }

    if (btn) {
      const original = btn.textContent;
      btn.textContent = '✓ Скопировано';
      btn.classList.add('is-done');
      setTimeout(() => {
        btn.textContent = original;
        btn.classList.remove('is-done');
      }, 1600);
    }
    addLog('Скопирован ' + code.code + ' · ' + code.service, 'info');
    toast('Промокод скопирован', code.code + ' — вставьте его при оформлении заказа');
  }

  /* ---------- Ссылка для других устройств ---------- */

  async function getShareUrl() {
    if (location.protocol === 'file:') return null;
    const host = location.hostname;
    if (host === 'localhost' || host === '127.0.0.1' || host === '::1') {
      try {
        const response = await fetch('/api/info', { cache: 'no-store' });
        if (response.ok) {
          const data = await response.json();
          if (data && data.lanUrl) return data.lanUrl;
        }
      } catch (err) { /* ignore */ }
    }
    return location.origin + location.pathname;
  }

  async function writeClipboard(text) {
    let ok = false;
    try {
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(text);
        ok = true;
      }
    } catch (err) { /* fallback below */ }
    if (!ok) {
      try {
        legacyCopy(text);
        ok = true;
      } catch (err) { /* ignore */ }
    }
    return ok;
  }

  async function copyShareLink() {
    const url = await getShareUrl();
    if (!url) {
      toast('Сначала запустите сервер', 'Запустите «Запустить с сервером.bat» и откройте ссылку по сети');
      return;
    }
    const ok = await writeClipboard(url);
    if (ok) toast('Ссылка скопирована', url + ' — откройте на другом устройстве');
    else toast('Не удалось скопировать', url);
  }

  async function refreshShareBlock() {
    const input = $('#shareUrl');
    const hint = $('#shareHint');
    if (!input || !hint) return;
    const url = await getShareUrl();
    if (!url) {
      input.value = '';
      hint.textContent = 'Запустите сайт через «Запустить с сервером.bat», затем откройте ссылку по сети.';
      return;
    }
    input.value = url;
    const host = location.hostname;
    if (host === 'localhost' || host === '127.0.0.1' || host === '::1') {
      hint.textContent = 'Это ссылка для других устройств в той же Wi-Fi. Если не открывается — запустите «Разрешить в брандмауэре.bat». Для интернета — «Публичная ссылка.bat».';
    } else if (host.endsWith('.lhr.life') || host.endsWith('.trycloudflare.com')) {
      hint.textContent = 'Публичная ссылка. Работает с любого устройства, пока открыт туннель.';
    } else if (host.endsWith('github.io')) {
      hint.textContent = 'Публичная ссылка GitHub Pages. Работает с любого устройства, компьютер может быть выключен.';
    } else {
      hint.textContent = 'Ссылка для устройств в вашей сети.';
    }
  }

  /* ---------- Карточка: избранное ---------- */

  function toggleFav(id) {
    const code = codes.find((c) => c.id === id);
    if (!code) return;
    if (store.fav.has(id)) {
      store.fav.delete(id);
      toast('Убрано из избранного', code.code);
    } else {
      store.fav.add(id);
      toast('Добавлено в избранное', code.code + ' · ' + code.service);
    }
    store.save();
    renderGrid();
    if ($('#modal').classList.contains('is-open')) openDetails(id);
  }

  /* ---------- Модальное окно ---------- */

  function openDetails(id) {
    const code = codes.find((c) => c.id === id);
    if (!code) return;

    const sv = serviceOf(code.service);
    const score = scoreOf(code);
    const { works, fails } = counts(code);
    const totalVotes = works + fails;
    const rate = totalVotes ? Math.round((works / totalVotes) * 100) : 0;
    const status = statusOf(code);
    const toneClass = status.tone === 'good' ? 'is-good' : status.tone === 'warn' ? 'is-warn' : status.tone === 'bad' ? 'is-bad' : 'is-dim';
    const fav = store.fav.has(code.id);

    const conditions = (code.conditions || []).map((c) => '<li>' + esc(c) + '</li>').join('')
      || '<li>Условия уточняйте на сайте сервиса</li>';

    const siteLink = sv.site && sv.site !== '#'
      ? '<a href="' + esc(sv.site) + '" target="_blank" rel="noopener noreferrer">сайте ' + esc(code.service) + '</a>'
      : 'сайте сервиса';

    const audience = code.existingUsers ? 'Можно использовать повторно' : 'Только первый заказ';
    const applies = code.wholeCart ? 'Вся корзина' : (code.type === 'delivery' ? 'Только доставка' : 'Отдельные позиции');
    const cityLabel = code.cityRestricted && (code.cities || []).length ? code.cities.join(', ') : 'Все города';
    const sourceLink = code.sourceUrl
      ? '<a href="' + esc(code.sourceUrl) + '" target="_blank" rel="noopener noreferrer">' + esc(code.sourceName || 'источник') + '</a>'
      : '';
    const freshLabel = 'Последний раз видели';
    const demoNote = code.fromFeed
      ? (code.verification === 'confirmed'
          ? 'Код подтверждён независимыми источниками и/или историей. Это не гарантирует срабатывание в вашей корзине, но риск ниже. '
          : 'Код найден в источнике, но независимого подтверждения пока нет. Проверьте условия перед заказом. ')
      : 'Это демонстрационный код из встроенной базы, а не действующая акция. ';
    const confidence = Number(code.confidence) || 0;
    const trustValue = totalVotes ? rate : confidence;
    const trustText = totalVotes ? works + ' / ' + totalVotes : 'индекс доверия ' + confidence + '/100';
    const evidenceItems = (code.evidence || []).map((ev) => {
      const label = esc(ev.source || 'источник');
      const link = ev.url ? '<a href="' + esc(ev.url) + '" target="_blank" rel="noopener noreferrer">' + label + '</a>' : label;
      return '<li>' + link + (ev.works ? ' · ' + Number(ev.works).toLocaleString('ru-RU') + ' копирований' : '') + '</li>';
    }).join('');
    const also = (code.alsoServices || []).length
      ? '<div class="m-fact m-fact--wide"><span>Также подходит</span><b>' + esc(code.alsoServices.join(', ')) + '</b></div>'
      : '';
    const methodLabel = code.verificationMethod === 'history'
      ? 'подтверждён историей наблюдений'
      : (code.sourceCount > 1 ? 'подтверждён ' + code.sourceCount + ' источниками' : 'найден в одном источнике');

    $('#modalBody').innerHTML = '' +
      '<div class="m-head">' +
        '<span class="brand__mark" style="--brand:' + sv.color + '" aria-hidden="true">' + esc(sv.mark) + '</span>' +
        '<div><b id="modalTitle">' + esc(code.service) + '</b><span>' + esc(code.sourceNote || 'промокод') + (code.sourceCount > 1 ? ' · ' + code.sourceCount + ' ист.' : '') + (code.fromFeed ? '' : ' · демо') + ' · ' + esc(expiryLabelFor(code)) + '</span></div>' +
      '</div>' +

      '<div class="m-value">' +
        '<div>' +
          '<h2>' + valueLabel(code) + '</h2>' +
          '<p>' + esc(code.title) + '</p>' +
        '</div>' +
        '<div class="m-score">' +
          '<div class="score" data-tier="' + scoreTier(score) + '" style="--score:' + score + '"><span>' + score + '</span></div>' +
          '<i>индекс выгоды</i>' +
        '</div>' +
      '</div>' +

      '<div class="m-code"><code>' + esc(code.code) + '</code>' +
        '<button class="btn btn--lime" type="button" data-action="copy" data-id="' + esc(code.id) + '">Скопировать</button>' +
      '</div>' +

      '<div class="m-facts">' +
        '<div class="m-fact m-fact--wide"><span>Статус</span><b class="' + toneClass + '">' + esc(status.label) + '</b></div>' +
        '<div class="m-fact m-fact--wide"><span>Где действует</span><b class="' + (code.cityRestricted ? 'is-warn' : 'is-good') + '">' + esc(cityLabel) + '</b></div>' +
        '<div class="m-fact"><span>Кому подходит</span><b class="' + (code.existingUsers ? 'is-good' : '') + '">' + audience + '</b></div>' +
        '<div class="m-fact"><span>На что действует</span><b class="' + (code.wholeCart ? 'is-good' : '') + '">' + applies + '</b></div>' +
        '<div class="m-fact"><span>Срок</span><b>' + esc(expiryLabelFor(code)) + '</b></div>' +
        '<div class="m-fact"><span>' + freshLabel + '</span><b>' + esc(verifiedLabel(code.verifiedAt)) + '</b></div>' +
        '<div class="m-fact"><span>Источников</span><b>' + (code.sourceCount || 1) + ' · ' + esc(methodLabel) + '</b></div>' +
        also +
      '</div>' +

      '<div class="m-section">' +
        '<h3>Условия</h3>' +
        '<ul class="m-list">' + conditions + '</ul>' +
      '</div>' +

      '<div class="m-section">' +
        '<h3>Надёжность кода</h3>' +
        '<div class="m-trust">' +
          '<span>' + (totalVotes ? '✓ ' + rate + '%' : confidence + '/100') + '</span>' +
          '<div class="bar"><i style="width:' + clamp(trustValue, 0, 100) + '%"></i></div>' +
          '<span>' + trustText + '</span>' +
        '</div>' +
        '<div class="m-vote">' +
          '<button class="btn" type="button" data-action="vote" data-vote="up" data-id="' + esc(code.id) + '">Сработало</button>' +
          '<button class="btn" type="button" data-action="vote" data-vote="down" data-id="' + esc(code.id) + '">Не сработало</button>' +
          '<button class="btn" type="button" data-action="verify" data-id="' + esc(code.id) + '"' + (code.fromFeed ? '' : ' disabled title="Проверка доступна только для кодов из фида"') + '>Проверить</button>' +
          '<button class="btn" type="button" data-action="fav" data-id="' + esc(code.id) + '">' + (fav ? '★ В избранном' : '☆ В избранное') + '</button>' +
        '</div>' +
      '</div>' +
      (evidenceItems ? '<div class="m-section"><h3>Источники</h3><ul class="m-list">' + evidenceItems + '</ul></div>' : '') +

      '<div class="m-note">' +
        demoNote +
        'Индекс выгоды учитывает размер скидки, минимальный чек, стоимость доставки, свежесть находки и подтверждения пользователей. ' +
        'Перед заказом сверьте условия на ' + siteLink + '.' +
        (sourceLink ? ' Код собран с ' + sourceLink + ' — проверьте актуальность на источнике.' : '') +
      '</div>';

    $('#modal').classList.add('is-open');
    $('#modal').setAttribute('aria-hidden', 'false');
    document.body.classList.add('no-scroll');
  }

  function closeModal() {
    $('#modal').classList.remove('is-open');
    $('#modal').setAttribute('aria-hidden', 'true');
    document.body.classList.remove('no-scroll');
  }

  function vote(id, direction) {
    const code = codes.find((c) => c.id === id);
    if (!code) return;
    const votes = store.votes[id] || (store.votes[id] = { up: 0, down: 0 });
    votes[direction] += 1;
    store.save();
    addLog('Голос за ' + code.code + ': ' + (direction === 'up' ? 'сработал' : 'не сработал'), direction === 'up' ? 'ok' : 'err');
    toast(
      direction === 'up' ? 'Спасибо, учли!' : 'Отметили как нерабочий',
      direction === 'up' ? code.code + ' станет выше в рейтинге' : 'Рейтинг ' + code.code + ' снизится'
    );
    renderAll();
    openDetails(id);
  }

  /* ---------- Панель источников ---------- */

  function openDrawer() {
    $('#drawer').classList.add('is-open');
    $('#drawer').setAttribute('aria-hidden', 'false');
    document.body.classList.add('no-scroll');
    renderSources();
    renderLog();
    refreshShareBlock();
  }

  function closeDrawer() {
    $('#drawer').classList.remove('is-open');
    $('#drawer').setAttribute('aria-hidden', 'true');
    document.body.classList.remove('no-scroll');
  }

  /* ---------- Фид ---------- */

  function normalizeFeed(item) {
    if (!item || !item.service || !item.code) return null;
    const type = ['percent', 'fixed', 'delivery'].includes(item.type) ? item.type : 'fixed';
    const value = Number(item.value) || 0;
    if (type === 'percent' && value > 50) return null;
    const category = Array.isArray(item.category) ? item.category.slice(0, 4) : ['из фида'];
    const collections = Array.isArray(item.collections) ? item.collections.map(String) : [];
    const has = (name) => collections.includes(name);
    const firstOrderOnly = item.firstOrderOnly === true ||
      has('firstOrder') ||
      category.some((tag) => /перв/i.test(String(tag)));
    const existingUsers = item.existingUsers != null
      ? !!item.existingUsers
      : (has('returning') ? true : !firstOrderOnly);
    const wholeCart = item.wholeCart != null
      ? !!item.wholeCart
      : (collections.length ? has('wholeCart') : type !== 'delivery');
    const cities = Array.isArray(item.cities) ? item.cities.map(String).slice(0, 12) : [];
    const cityRestricted = item.cityRestricted != null ? !!item.cityRestricted : cities.length > 0;
    const sourceName = item.sourceName ? String(item.sourceName).slice(0, 60) : 'внешний фид';
    const sourceUrl = item.sourceUrl ? String(item.sourceUrl).slice(0, 500) : '';

    return decorate({
      id: 'feed-' + String(item.service + '-' + item.code).toLowerCase().replace(/[^a-zа-я0-9]+/gi, '-'),
      service: String(item.service).slice(0, 40),
      code: String(item.code).slice(0, 32).toUpperCase(),
      type: type,
      value: value,
      minOrder: Number(item.minOrder) || 0,
      maxDiscount: Number(item.maxDiscount) || 0,
      freeDelivery: !!item.freeDelivery,
      deliveryCost: Number(item.deliveryCost) || 149,
      title: item.title ? String(item.title).slice(0, 140) : 'Промокод из подключённого фида',
      category: category,
      existingUsers: existingUsers,
      wholeCart: wholeCart,
      cities: cities,
      cityRestricted: cityRestricted,
      conditions: Array.isArray(item.conditions) ? item.conditions.slice(0, 8) : [],
      expiresInDays: item.expiresInDays != null ? Number(item.expiresInDays) : null,
      confidence: Number(item.confidence) || 0,
      verification: ['confirmed', 'likely', 'single', 'expired'].includes(item.verification) ? item.verification : '',
      verificationMethod: item.verificationMethod || '',
      sourceCount: Number(item.sourceCount) || 1,
      evidence: Array.isArray(item.evidence) ? item.evidence.slice(0, 12) : [],
      alsoServices: Array.isArray(item.alsoServices) ? item.alsoServices.slice(0, 6) : [],
      firstSeenAt: item.firstSeenAt || '',
      lastSeenAt: item.lastSeenAt || '',
      seenRuns: Number(item.seenRuns) || 0,
      works: Number(item.works) || 0,
      fails: Number(item.fails) || 0,
      sourceId: 'feed',
      sourceNote: 'собрано с ' + sourceName,
      sourceName: sourceName,
      sourceUrl: sourceUrl,
      fromFeed: true
    });
  }

  function saveFeedCache(url, items) {
    try {
      localStorage.setItem(FEED_CACHE_KEY, JSON.stringify({
        url: url,
        fetchedAt: Date.now(),
        items: items.slice(0, 400)
      }));
    } catch (err) { /* ignore quota errors */ }
  }

  function readFeedCache() {
    try {
      const raw = localStorage.getItem(FEED_CACHE_KEY);
      if (!raw) return null;
      const data = JSON.parse(raw);
      if (!data || !Array.isArray(data.items)) return null;
      return data;
    } catch (err) {
      return null;
    }
  }

  function syncFeed(items, url) {
    const next = items.map(normalizeFeed).filter(Boolean);
    if (!next.length) return 0;

    codes = codes.filter((code) => !code.fromFeed);

    let added = 0;
    const seen = new Set();
    next.forEach((code) => {
      const key = code.service + '|' + code.code;
      if (seen.has(key)) return;
      seen.add(key);
      codes.push(code);
      added += 1;
    });

    if (added) lastUpdate = Date.now();

    const stats = srcStats.feed || (srcStats.feed = { checks: 0, found: 0, last: 0 });
    stats.checks += 1;
    stats.found = added;
    stats.last = Date.now();

    return added;
  }

  function hydrateFeedCache() {
    const cache = readFeedCache();
    if (!cache || !cache.items.length) return 0;
    const added = syncFeed(cache.items, cache.url || '');
    const when = cache.fetchedAt ? new Date(cache.fetchedAt).toLocaleString('ru-RU', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }) : 'неизвестно';
    addLog('Кэш фида: ' + added + ' кодов от ' + when, 'ok');
    return added;
  }

  let feedLoading = false;

  async function connectFeed(url, opts) {
    const options = opts || {};
    const hint = $('#feedHint');
    if (feedLoading) return false;
    feedLoading = true;
    if (!options.silent && hint) hint.textContent = 'Запрашиваем фид…';

    try {
      const response = await fetch(url, { cache: 'no-store' });
      if (!response.ok) throw new Error('HTTP ' + response.status);
      const data = await response.json();
      const items = Array.isArray(data) ? data : (data && Array.isArray(data.codes) ? data.codes : []);
      if (!items.length) throw new Error('в фиде нет массива codes');

      const added = syncFeed(items, url);
      store.feedUrl = url;
      store.save();
      saveFeedCache(url, items);

      let host = 'локальный фид';
      try {
        const parsed = new URL(url, location.href);
        if (parsed.hostname === location.hostname) {
          host = parsed.hostname.endsWith('github.io') ? 'GitHub Pages' : 'локальный фид';
        } else {
          host = parsed.hostname;
        }
      } catch (err) { /* ignore */ }
      const confirmedCount = codes.filter((c) => c.verification === 'confirmed').length;
      if (hint) hint.textContent = '✓ Фид обновлён: ' + added + ' кодов · ' + confirmedCount + ' подтверждено · ' + host + ' · ' + new Date().toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' });
      addLog('Фид ' + url + ': получено ' + items.length + ', в базе ' + added, 'new');
      if (!options.silent) toast('Фид подключён', added + ' промокодов в базе');
      renderAll();
      return true;
    } catch (err) {
      if (hint) hint.textContent = '✕ Фид не загрузился: ' + err.message + '. Показаны кэшированные коды, если они есть.';
      addLog('Ошибка фида: ' + err.message, 'err');
      if (!options.silent) toast('Фид не подключился', 'Проверьте соединение и обновите страницу');
      return false;
    } finally {
      feedLoading = false;
    }
  }

  /* ---------- Обновление вручную ---------- */

  async function refreshAll() {
    const btn = $('#btnRefresh');
    if (btn.disabled) return;
    btn.disabled = true;
    btn.classList.add('is-busy');

    const feedUrl = store.feedUrl || 'data/codes.json';
    let feedOk = false;
    if (store.sources.feed !== false) {
      addLog('Проверка фида: ' + feedUrl, 'info');
      feedOk = await connectFeed(feedUrl, { silent: true });
    }

    if (!feedExists()) {
      const list = enabledSources();
      for (const src of list) {
        await sleep(350 + Math.random() * 300);
        checkSource(src, { chance: 0.28 });
      }
    }

    lastUpdate = Date.now();
    renderAll();
    const working = workingPool().length;
    toast(
      feedOk ? 'Проверка завершена' : 'Источник недоступен',
      feedOk ? ('Рабочих кодов: ' + working + ' · фид обновлён') : ('Показываем кэш · рабочих кодов: ' + working)
    );
    btn.disabled = false;
    btn.classList.remove('is-busy');
  }

  async function verifyCode(id) {
    const code = codes.find((c) => c.id === id);
    if (!code) return;
    if (!code.fromFeed) {
      toast('Это демо-код', 'Проверка доступна только для кодов из фида');
      return;
    }
    toast('Проверяем код…', 'Запрашиваем актуальный фид');
    const ok = await connectFeed(store.feedUrl || 'data/codes.json', { silent: true });
    if (!ok) {
      toast('Не удалось проверить', 'Источник сейчас недоступен');
      return;
    }

    const still = codes.find((c) => c.id === id);
    if (still) {
      still.verifiedAt = Date.now();
      renderAll();
      openDetails(id);
      toast('Код подтверждён', 'Он всё ещё есть в источнике');
    } else {
      closeModal();
      toast('Код больше не в источнике', 'Убрали его из выдачи');
    }
  }

  /* ---------- События ---------- */

  $('#grid').addEventListener('click', (event) => {
    const target = event.target.closest('[data-action]');
    if (!target) return;
    const id = target.dataset.id;
    const action = target.dataset.action;
    if (action === 'copy') {
      const code = codes.find((c) => c.id === id);
      if (code) copyCode(code, target);
    } else if (action === 'fav') {
      toggleFav(id);
    } else if (action === 'details') {
      openDetails(id);
    }
  });

  $('#btnLoadMore').addEventListener('click', () => {
    ui.limit += PAGE_SIZE;
    renderGrid();
  });

  $('#modalBody').addEventListener('click', (event) => {
    const target = event.target.closest('[data-action]');
    if (!target) return;
    const id = target.dataset.id;
    const action = target.dataset.action;
    if (action === 'copy') {
      const code = codes.find((c) => c.id === id);
      if (code) copyCode(code, target);
    } else if (action === 'vote') {
      vote(id, target.dataset.vote === 'up' ? 'up' : 'down');
    } else if (action === 'verify') {
      verifyCode(id);
    } else if (action === 'fav') {
      toggleFav(id);
    }
  });

  $('#serviceChips').addEventListener('click', (event) => {
    const chip = event.target.closest('[data-service]');
    if (!chip) return;
    ui.service = chip.dataset.service;
    renderChips();
    renderResults();
  });

  $('#collectionChips').addEventListener('click', (event) => {
    const pick = event.target.closest('[data-collection]');
    if (!pick) return;
    const id = pick.dataset.collection;
    if (id === 'all') {
      ui.collections.clear();
    } else if (ui.collections.has(id)) {
      ui.collections.delete(id);
    } else {
      ui.collections.add(id);
    }
    renderResults();
  });

  $('#search').addEventListener('input', (event) => {
    ui.q = event.target.value;
    renderResults();
  });

  $('#onlyBest').addEventListener('change', (event) => {
    ui.onlyBest = event.target.checked;
    renderResults();
  });

  $('#onlyWorking').addEventListener('change', (event) => {
    ui.onlyWorking = event.target.checked;
    store.onlyWorking = ui.onlyWorking;
    store.save();
    renderAll();
  });

  $('#btnShowAll').addEventListener('click', () => {
    ui.onlyWorking = !ui.onlyWorking;
    store.onlyWorking = ui.onlyWorking;
    store.save();
    $('#onlyWorking').checked = ui.onlyWorking;
    renderAll();
  });

  $('#freeDelivery').addEventListener('change', (event) => {
    ui.freeDelivery = event.target.checked;
    renderResults();
  });

  $('#onlyFav').addEventListener('change', (event) => {
    ui.onlyFav = event.target.checked;
    renderResults();
  });

  function updateSortUI() {
    const labels = { score: 'по выгоде', expiry: 'скоро истекают', new: 'сначала новые' };
    const label = $('#sortLabel');
    if (label) label.textContent = labels[ui.sort] || labels.score;
    document.querySelectorAll('#sortMenu .sortbox__opt').forEach((opt) => {
      const on = opt.dataset.value === ui.sort;
      opt.classList.toggle('is-on', on);
      opt.setAttribute('aria-selected', String(on));
    });
  }

  function setSortMenu(open) {
    const box = $('#sortBox');
    const btn = $('#sortBtn');
    if (!box) return;
    box.classList.toggle('is-open', open);
    if (btn) btn.setAttribute('aria-expanded', String(open));
  }

  $('#sortBtn').addEventListener('click', (event) => {
    event.stopPropagation();
    const box = $('#sortBox');
    setSortMenu(!(box && box.classList.contains('is-open')));
  });

  $('#sortMenu').addEventListener('click', (event) => {
    const opt = event.target.closest('[data-value]');
    if (!opt) return;
    ui.sort = opt.dataset.value;
    setSortMenu(false);
    updateSortUI();
    renderGrid();
  });

  document.addEventListener('click', (event) => {
    if (!event.target.closest('#sortBox')) setSortMenu(false);
  });

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') setSortMenu(false);
  });

  updateSortUI();

  $('#btnReset').addEventListener('click', () => {
    ui.q = '';
    ui.service = 'all';
    ui.collections.clear();
    ui.onlyBest = false;
    ui.onlyWorking = true;
    store.onlyWorking = true;
    store.save();
    ui.freeDelivery = false;
    ui.onlyFav = false;
    $('#search').value = '';
    $('#onlyBest').checked = false;
    $('#onlyWorking').checked = true;
    $('#freeDelivery').checked = false;
    $('#onlyFav').checked = false;
    renderAll();
  });

  $('#btnRefresh').addEventListener('click', refreshAll);

  $('#btnSources').addEventListener('click', openDrawer);

  $('#btnShare').addEventListener('click', copyShareLink);

  $('#btnShareCopy').addEventListener('click', async () => {
    const input = $('#shareUrl');
    if (!input.value) await refreshShareBlock();
    const url = input.value;
    if (!url) {
      copyShareLink();
      return;
    }
    const ok = await writeClipboard(url);
    if (ok) toast('Ссылка скопирована', url + ' — откройте на другом устройстве');
    else toast('Не удалось скопировать', url);
  });

  $('#btnPause').addEventListener('click', () => {
    store.paused = !store.paused;
    store.save();
    updateLive();
    if (store.paused) {
      clearTimeout(tickTimer);
      addLog('Автолов поставлен на паузу', 'info');
    } else {
      addLog('Автолов возобновлён', 'ok');
      scheduleTick(2500);
    }
  });

  $('#sourceList').addEventListener('change', (event) => {
    const input = event.target.closest('[data-source]');
    if (!input) return;
    store.sources[input.dataset.source] = input.checked;
    store.save();
    const src = sourceById(input.dataset.source);
    if (src) {
      addLog(src.name + ': источник ' + (input.checked ? 'включён' : 'выключен'), input.checked ? 'ok' : 'info');
      if (input.checked && !store.paused) scheduleTick(3200);
    }
    renderSources();
    updateLive();
  });

  $('#btnPause').addEventListener('dblclick', (event) => event.preventDefault());

  $('#btnResetDemo').addEventListener('click', () => {
    if (!window.confirm('Сбросить избранное, голоса, пойманные коды и кэш фида? Страница перезагрузится.')) return;
    try {
      localStorage.removeItem(LS_KEY);
      localStorage.removeItem(FEED_CACHE_KEY);
    } catch (err) { /* ignore */ }
    location.reload();
  });

  document.addEventListener('click', (event) => {
    if (event.target.closest('[data-close-modal]')) closeModal();
    if (event.target.closest('[data-close-drawer]')) closeDrawer();
  });

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
      if ($('#modal').classList.contains('is-open')) closeModal();
      else if ($('#drawer').classList.contains('is-open')) closeDrawer();
    }
  });

  /* ---------- Инициализация ---------- */

  function init() {
    $('#onlyWorking').checked = ui.onlyWorking;

    const feedUrl = store.feedUrl || 'data/codes.json';

    if (store.paused) {
      addLog('Автолов был поставлен на паузу в прошлый раз', 'info');
    } else {
      addLog('Автолов запущен · источников: ' + enabledSources().length, 'ok');
    }

    hydrateFeedCache();
    renderAll();
    renderLog();

    if (!store.paused) startCollector();

    if (store.sources.feed !== false) {
      setTimeout(() => connectFeed(feedUrl, { silent: true, auto: true }), 500);
      setInterval(() => {
        if (store.sources.feed === false) return;
        connectFeed(store.feedUrl || feedUrl, { silent: true, auto: true });
      }, 15 * 60 * 1000);
    }

    setInterval(updateLive, 15000);
    setInterval(() => {
      if ($('#drawer').classList.contains('is-open')) renderSources();
    }, 20000);

    // «Свежесть» карточек и счётчик времени обновляем мягко
    setInterval(() => {
      $('#liveMeta').textContent = store.paused
        ? 'нажмите ▶, чтобы продолжить'
        : 'обновлено ' + timeAgo(lastUpdate);
    }, 10000);
  }

  init();
})();
