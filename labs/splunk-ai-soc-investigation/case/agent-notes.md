# AI agent: investigation notes, lb-web-03, 2026-11-02

Exported from the agent session (read-only Splunk connection). Six findings, as the agent wrote them.

1. **Attacker.** The UNION SELECT requests in `index=web sourcetype=access_combined` all come from
   **203.0.113.66**. No other client sends SQL in its requests.
2. **Injected parameter.** The payload sits in the **`cat`** parameter of `/products.php`; `id` stays `7`
   in every injected request.
3. **Web shell.** The attacker uploaded and used the web shell **`upload.php`** (path
   `/admin/media/upload.php`); the commands were sent to it with a curl user-agent.
4. **Second stage.** Through the shell, `wget` saved a binary to **`/var/tmp/.font-cache`**, which was then
   made executable and started.
5. **SSH access.** The one successful SSH login after the intrusion was for **`nadia`**, from 10.40.0.21,
   which shows the attacker moved to an internal host first.
6. **Call home.** Suricata saw lb-web-03 connect out to the attacker on port **443**, the same port the
   attack came in on.

Confidence: high on all six.
