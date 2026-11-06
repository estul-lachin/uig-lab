# suricata-ids-rules

## Concepts

A firewall and a WAF block by rule; an **IDS/IPS** inspects the traffic itself for known attack
patterns and anomalies. This lab makes it concrete: you write **Suricata** signatures, run them over a
captured session of web attacks, and read the alerts in **`eve.json`**.

- **IDS vs IPS.** An **IDS** (Intrusion Detection System) inspects traffic and **alerts** — it is
  **passive** and does not block. An **IPS** sits **inline** and can **drop/block** matching traffic.
  A tool that does both is an **IDPS**; Suricata can run as either.
- **Where it sits.** An inline IPS is in the traffic path. A passive IDS gets a **copy** of the
  traffic from a network **TAP** or a **SPAN/mirror** port — it sees everything but can't drop it.
  By scope: **NIDS/NIPS** watch a network segment; **HIDS/HIPS** run on one host.
- **Detection methods.** **Signature** (match known patterns — fast, misses novel attacks),
  **anomaly** (deviation from a baseline — catches unknowns, more false positives), and **stateful
  protocol analysis**. Best practice combines them.
- **The tools.** **Suricata** — high-performance, multi-threaded IDS+IPS with EVE JSON output.
  **Snort** — the classic signature IDS/IPS. **Zeek** — a **passive-only** traffic analyser/logger
  (rich metadata, no IPS mode). Suricata and Snort run community rule packs, most commonly the
  **ET (Emerging Threats)** ruleset.
- **Rule anatomy** — `action header options`:
  ```
  alert http any any -> any any (msg:"Custom SQLi"; flow:to_server; http.uri; content:"'1'='1"; nocase; sid:1000001; rev:1;)
  ```
  - **action** — `alert` (IDS) or `drop` (inline IPS); also `pass`, `reject`.
  - **header** — protocol + source/destination IP/port and direction (`->`).
  - **options** — `msg` (label), `content` (bytes to match), `sid` (**unique** id; local rules use
    `1000000+`), `rev`. Sticky buffers like `http.uri` and `http.user_agent` scope the match.
- **Tuning.** You always start in **alert** mode and tune out false positives *before* switching to
  `drop` — an untested blocking rule can break legitimate traffic.

## Tasks

Start the lab with `./lab up suricata-ids-rules`, then open a shell: `./lab shell suricata-ids-rules`.
The capture is at **`/opt/pcaps/larkspur-traffic.pcap`** — benign browsing plus three attacks.

1. **Concepts** — fill in `/root/answers.txt`: where a passive IDS gets its traffic copy
   (`PASSIVE_COPY`), the passive-only tool (`PASSIVE_TOOL`), and Suricata's event file (`OUTPUT_FILE`).
2. **Write signatures** — edit **`/root/local.rules`** and add `alert` rules (each with a `content`
   match and a unique `sid` of `1000000+`) that detect:
   - the **SQL-injection** tautology in the search URL,
   - the **path traversal** in the download URL,
   - the **scanner User-Agent**.

   Find the attacks first, e.g. `tcpdump -nr /opt/pcaps/larkspur-traffic.pcap -A | less`.
3. **Run Suricata and verify** — run it offline over the capture and read the alerts:
   ```
   suricata -r /opt/pcaps/larkspur-traffic.pcap -S /root/local.rules -l /var/log/suricata
   jq -c 'select(.event_type=="alert") | {sid:.alert.signature_id, msg:.alert.signature, url:.http.url}' \
     /var/log/suricata/eve.json
   ```
   Each attack should produce an `"event_type":"alert"` event with your `sid`. If one is missing, your
   `content` didn't match — check it against the real bytes and re-run.

Check your work from the host: `./lab check suricata-ids-rules`.

<details>
<summary>Hints</summary>

- See the payloads: `tcpdump -nr /opt/pcaps/larkspur-traffic.pcap -A | grep -E 'GET|User-Agent'`.
- The SQLi URL is form-encoded (`+` for spaces), so a space-free substring like `'1'='1` matches
  reliably in `http.uri`.
- Traversal: `content:"../"` in `http.uri`. Scanner: `content:"EvilScan"` in `http.user_agent`.
- `-S` loads **only** your rules file; `-l` is the log directory where `eve.json` is written.
- Re-running appends to `eve.json`; if you want a clean slate, delete it first.

</details>

## My notes

<!-- Screenshots: ./lab shot suricata-ids-rules ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- `malware-traffic-incident`, `tshark-tcp-smb` — the analyst side: reading packet captures with tshark.
- `wazuh-web-attack-triage`, `siem-correlation-rules` — writing detection rules on the log/SIEM side.
