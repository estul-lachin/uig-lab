# waf-modsecurity-crs

## Concepts

A network firewall controls *who* can talk; it doesn't understand HTTP attacks. That's the job of a
**WAF (Web Application Firewall)** — it works at **Layer 7** and inspects web requests, so it can
catch **SQL injection**, **XSS** and **path traversal** that a packet firewall never sees.
**ModSecurity** is the classic open-source WAF engine; the **OWASP Core Rule Set (CRS)** is the
community rule pack that gives it its detections.

- **NGFW vs WAF.** A Next-Generation Firewall adds DPI/App-ID, IPS, URL filtering and TLS inspection
  to a stateful firewall. A WAF is different: Layer-7 HTTP, application-aware.
- **The master switch — `SecRuleEngine`.** Three values:
  - `On` — inspect and **block** matching requests;
  - `DetectionOnly` — inspect and **log but never block** (the WAF equivalent of an IDS alert-only
    mode — safe for tuning);
  - `Off` — disabled.
  You start in `DetectionOnly`, tune out false positives, then switch to `On`.
- **How CRS decides — anomaly scoring.** Not "one rule = one block". Each matching rule **adds to an
  anomaly score**; when a request's inbound score reaches the threshold (default 5), CRS blocks it and
  returns **HTTP 403**. How aggressively rules match is the **Paranoia Level** (PL1–PL4): higher PL
  catches more but raises false positives.
- **CRS rule-id families** (useful when reading the log):
  `942xxx` = SQL injection, `941xxx` = XSS, `930xxx` = LFI / path traversal, `932xxx` = RCE.
- **Custom rules — `SecRule`.** `SecRule VARIABLES "OPERATOR" "ACTIONS"`, e.g.
  `SecRule ARGS "@contains attack-test" "id:900001,phase:2,deny,status:403,msg:'...'"`.
- **The audit log** (`/var/log/modsec/audit.log`) lists every matched rule with its id and message —
  it's how you find *why* a request was blocked, and a core SOC data source.

This lab puts a ModSecurity + CRS WAF in front of a small backend. It **ships in `DetectionOnly`**, so
attacks currently pass straight through.

## Tasks

Start the lab with `./lab up waf-modsecurity-crs`, then open a shell:
`./lab shell waf-modsecurity-crs`. The WAF is at `http://localhost:8080` and proxies to the backend.

1. **Concepts** — fill in `/root/answers.txt`: the master switch directive (`MASTER_SWITCH`), the
   alert-only value (`ALERT_ONLY`), the block status code (`BLOCK_CODE`), how CRS decides
   (`HOW_DECIDES`), and the SQLi rule family (`SQLI_FAMILY`).
2. **Turn on enforcement** — the WAF starts in `DetectionOnly`. Add `SecRuleEngine On` to
   **`/etc/modsecurity.d/modsecurity-override.conf`** (loaded after the CRS, so it wins), then reload:
   ```
   nginx -s reload
   ```
   Confirm an attack is now blocked:
   ```
   curl -i -G http://localhost:8080/search --data-urlencode "id=1' OR '1'='1"   # -> 403
   curl -i http://localhost:8080/                                               # -> 200
   ```
3. **Write a custom rule** — in the same override file, add a `SecRule` that denies any request whose
   arguments contain the marker **`malbeacon`** (give it an `id` of `900100`, `deny`, `status:403`),
   then reload. Verify:
   ```
   curl -i -G http://localhost:8080/search --data-urlencode "q=malbeacon"       # -> 403
   ```
4. **Read the cause** — send the SQLi again and read the audit log to find which CRS rule fired:
   ```
   grep -oE '94[0-9]{4}' /var/log/modsec/audit.log | sort | uniq -c
   ```
   You should see the SQLi family (`942100`).

Check your work from the host: `./lab check waf-modsecurity-crs`.

<details>
<summary>Hints</summary>

- The override file already exists; append your directives to the end and reload.
- `SecRuleEngine On` and your `SecRule` can both live in `modsecurity-override.conf`.
- Custom rule shape:
  `SecRule ARGS "@contains malbeacon" "id:900100,phase:2,deny,status:403,log,msg:'Custom block'"`.
- After every edit, run `nginx -s reload` — nothing changes until you do.
- Audit log is JSON; `grep 942 /var/log/modsec/audit.log` is enough to spot the SQLi rule.

</details>

## My notes

<!-- Screenshots: ./lab shot waf-modsecurity-crs ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- `suricata-ids-rules` — the network-IDS counterpart (website + WAF + Suricata share the traffic).
- `reflected-xss`, `sqli-auth-bypass` — the attacks this WAF is here to stop.
