// Postboard - a deliberately vulnerable demo app for the reflected-xss lab.
//
// The /search page echoes the ?q= parameter straight into the response HTML,
// INSIDE an attribute value, without escaping it. That is the reflected-XSS bug.
//
// A moderator bot reviews "reported" search results: it opens the reported URL
// in a real HTML parser + JS engine (jsdom), carrying its own session cookie.
// If an attacker's reflected <script> runs, it can read that cookie and send it
// to /xss-hit. The server only writes the flag when it receives the *real*
// moderator cookie - so the flag is proof the script actually executed.
//
// Nothing here is a real exploit against anyone: it is a self-contained lab.

const express = require('express');
const http = require('http');
const fs = require('fs');
const crypto = require('crypto');
const { JSDOM, CookieJar, VirtualConsole } = require('jsdom');

const HOST = '127.0.0.1';
const PORT = 8080;
const ORIGIN = `http://${HOST}:${PORT}`;

// The moderator's secret session token. Random each run, never written to disk
// or exposed by any endpoint - the only way to learn it is to steal the cookie.
const MOD_SECRET = 'MODSESS-' + crypto.randomBytes(9).toString('hex');

const FLAG_DIR = '/flag';
const FLAG_FILE = `${FLAG_DIR}/solved`;
try { fs.mkdirSync(FLAG_DIR, { recursive: true }); } catch (_) { /* already there */ }

const app = express();
app.disable('x-powered-by');

function page(title, body) {
  return `<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>${title}</title></head>
<body>
<header><strong>Postboard</strong> &middot; community message board</header>
${body}
</body>
</html>`;
}

// Landing page: describes the two endpoints a tester needs.
app.get('/', (_req, res) => {
  res.type('html').send(page('Postboard', `
<h1>Welcome to Postboard</h1>
<ul>
  <li><code>GET /search?q=TERM</code> - search the board; your term is shown back to you.</li>
  <li><code>GET /report?path=/search?q=TERM</code> - flag a search result for a moderator to review.
      A moderator opens the reported link in their browser, signed in.</li>
</ul>
<p>Try it: <a href="/search?q=hello">/search?q=hello</a></p>`));
});

// VULNERABLE: q is reflected into an attribute value (and a text node) unescaped.
function renderSearch(q) {
  return page('Postboard - search', `
<h1>Search results</h1>
<form action="/search" method="get">
  <input type="text" name="q" value="${q}" placeholder="search posts...">
  <button type="submit">Search</button>
</form>
<p>No posts matched "${q}".</p>
<p><a href="/report?path=/search?q=${encodeURIComponent(q)}">Report this result to a moderator</a></p>`);
}
app.get('/search', (req, res) => {
  const q = req.query.q != null ? String(req.query.q) : '';
  res.type('html').send(renderSearch(q));
});

// Callback: the flag is written ONLY when the request carries the moderator's
// real session cookie - i.e. when a reflected script read document.cookie and
// sent it here. Curling this endpoint by hand cannot work: you don't know the token.
app.get('/xss-hit', (req, res) => {
  const c = String(req.query.c || '');
  if (c.includes(MOD_SECRET)) {
    fs.writeFileSync(FLAG_FILE,
      `flag{postboard-reflected-xss-cookie-theft}\n` +
      `stolen-cookie: ${c}\n` +
      `captured-at: ${new Date().toISOString()}\n`);
  }
  res.type('text/plain').send('ok');
});

// Fetch a URL from this origin and return its body.
function getBody(url) {
  return new Promise((resolve, reject) => {
    http.get(url, (r) => {
      let d = '';
      r.on('data', (c) => (d += c));
      r.on('end', () => resolve(d));
    }).on('error', reject);
  });
}

// The moderator bot. Opens a reported search path in jsdom with its session
// cookie, executing whatever scripts the page contains - exactly what a logged-in
// victim's browser would do when they click an attacker's link.
async function moderatorVisit(path) {
  const url = ORIGIN + path;
  const jar = new CookieJar();
  jar.setCookieSync(`modsession=${MOD_SECRET}`, ORIGIN);

  const html = await getBody(url);
  const vc = new VirtualConsole(); // swallow page-script errors, keep lab logs clean

  const dom = new JSDOM(html, {
    url,
    cookieJar: jar,
    runScripts: 'dangerously',
    resources: 'usable',
    virtualConsole: vc,
    beforeParse(window) {
      // Minimal fetch so a reflected `fetch(...)` can reach this origin.
      window.fetch = (u) => {
        const full = String(u).startsWith('http') ? String(u) : ORIGIN + u;
        return new Promise((resolve) => {
          http.get(full, (r) => { r.on('data', () => {}); r.on('end', () => resolve({ ok: true })); })
            .on('error', () => resolve({ ok: false }));
        });
      };
    },
  });

  // Let any async callback the script fired complete, then tear the window down.
  await new Promise((r) => setTimeout(r, 900));
  try { dom.window.close(); } catch (_) { /* ignore */ }
}

// Report a search result. The bot only opens same-site /search links.
app.get('/report', async (req, res) => {
  const path = String(req.query.path || '');
  if (!path.startsWith('/search')) {
    return res.status(400).type('text/plain').send('Only /search results can be reported.');
  }
  try { await moderatorVisit(path); } catch (_) { /* bot error - ignore */ }
  res.type('text/plain').send('Thanks - a moderator has reviewed your report.');
});

app.listen(PORT, HOST, () => {
  console.log(`Postboard listening on ${ORIGIN}`);
});
