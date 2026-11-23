function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8' }
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const secret = request.headers.get('x-secret') || url.searchParams.get('secret');
    if (!env.PROXY_SECRET || secret !== env.PROXY_SECRET) {
      return json({ ok: false, error: 'forbidden' }, 403);
    }

    if (url.pathname === '/updates') {
      const response = await fetch(`https://api.telegram.org/bot${env.BOT_TOKEN}/getUpdates?limit=100`);
      return new Response(await response.text(), {
        status: response.status,
        headers: { 'content-type': 'application/json; charset=utf-8' }
      });
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
      const response = await fetch(`https://api.telegram.org/bot${env.BOT_TOKEN}/sendMessage`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          chat_id: body.chat_id,
          text: String(body.text).slice(0, 4000),
          parse_mode: body.parse_mode || 'HTML',
          disable_web_page_preview: true
        })
      });
      return new Response(await response.text(), {
        status: response.status,
        headers: { 'content-type': 'application/json; charset=utf-8' }
      });
    }

    return json({ ok: true, service: 'promolov-telegram-proxy' });
  }
};
