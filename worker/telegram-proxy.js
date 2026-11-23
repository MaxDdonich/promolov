function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8' }
  });
}

async function fetchWithTimeout(url, options = {}, timeoutMs = 12000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...options, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const secret = request.headers.get('x-secret') || url.searchParams.get('secret');
    if (!env.PROXY_SECRET || secret !== env.PROXY_SECRET) {
      return json({ ok: false, error: 'forbidden' }, 403);
    }

    if (url.pathname === '/diag') {
      const started = Date.now();
      try {
        const response = await fetchWithTimeout('https://api.telegram.org/', {}, 10000);
        return json({
          ok: true,
          token_present: Boolean(env.BOT_TOKEN),
          token_length: env.BOT_TOKEN ? env.BOT_TOKEN.length : 0,
          telegram_status: response.status,
          ms: Date.now() - started
        });
      } catch (error) {
        return json({
          ok: false,
          token_present: Boolean(env.BOT_TOKEN),
          token_length: env.BOT_TOKEN ? env.BOT_TOKEN.length : 0,
          error: String(error),
          ms: Date.now() - started
        }, 502);
      }
    }

    if (url.pathname === '/updates') {
      try {
        const response = await fetchWithTimeout(`https://api.telegram.org/bot${env.BOT_TOKEN}/getUpdates?limit=100`, {}, 12000);
        return new Response(await response.text(), {
          status: response.status,
          headers: { 'content-type': 'application/json; charset=utf-8' }
        });
      } catch (error) {
        return json({ ok: false, error: String(error) }, 504);
      }
    }

    if (request.method === 'POST' && (url.pathname === '/' || url.pathname === '/send')) {
      let body;
      try {
        body = await request.json();
      } catch {
        return json({ ok: false, error: 'invalid json' }, 400);
      }
      if (!body.chat_id || !body.text) {
        return json({ ok: false, error: 'chat_id and text are required' }, 400);
      }
      try {
        const response = await fetchWithTimeout(`https://api.telegram.org/bot${env.BOT_TOKEN}/sendMessage`, {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({
            chat_id: body.chat_id,
            text: String(body.text).slice(0, 4000),
            parse_mode: body.parse_mode || 'HTML',
            disable_web_page_preview: true
          })
        }, 12000);
        return new Response(await response.text(), {
          status: response.status,
          headers: { 'content-type': 'application/json; charset=utf-8' }
        });
      } catch (error) {
        return json({ ok: false, error: String(error) }, 504);
      }
    }

    return json({ ok: true, service: 'promolov-telegram-proxy' });
  }
};
