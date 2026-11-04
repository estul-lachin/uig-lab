# splunk-ai-soc-investigation

## Concepts

**The scenario**: 02:14 at night, an IDS alert: *possible SQL injection against the shop*.

- One SQLi alert is routine: bots throw them at every public site.
- This one keeps firing, and the follow-on events don't look like a scanner.
- The question for the morning: did the attacker get in, how far did they get, did customer data
  leave, and did anything call home?

**Follow the kill chain**: each answer is the pivot for the next search.

| Step | Question | Where |
|---|---|---|
| Who | Which client sent the SQL? | Web access log |
| How | Which parameter carried it, and what did it read? | The same requests: `uri`, `bytes` |
| Foothold | What did they upload, and what did they run through it? | Web log: unusual paths, user-agents, query strings |
| Second stage | What did they download onto the server? | The commands sent to the shell |
| Access | Which account did they log in with? | Auth log |
| Call home | Did the server connect back out? | IDS alerts with the **server** as the source |

Things that make it hard:
- The attack is buried in a normal day: shoppers, crawlers, an uptime check, and SSH brute force from
  a botnet.
- Single words mislead: customers search for "union station" and "select editions", so `union` alone
  finds shoppers too. Ask for **both words** in one event (`UNION SELECT`: a space is AND). A quoted
  phrase is stricter still, and it can miss: in the raw URL the words are joined by `+`, not a space.
- URLs arrive **URL-encoded**: `%27` is `'`, `%20` and `+` are spaces. `eval u = urldecode(uri)` makes
  them readable before a `rex`.

**Working with an AI agent.** Modern SOCs let an LLM agent run searches through a connector (for
example the Model Context Protocol, MCP). It is fast, and it has no judgment of its own:
- **It can be confidently wrong.** It may pick the first match, mix up a lookalike event, or state a
  value nothing supports. Every value it gives is a lead to verify, not an answer.
- **It gets least privilege**, enforced in two layers: its own tool allow-list, and its account in the
  SIEM. Even an agent tricked by text in a log (prompt injection) can then only read.

In Splunk, the account side is **roles**:
- **Capabilities**: what the role may do. `search` is all an investigator needs. Watch out for
  `admin_all_objects`, `edit_user`, `edit_roles`, `indexes_edit` and `delete_by_keyword`.
- **Allowed indexes**: what it may see at all.
- **Inherited roles**: `user`, `power`, `admin`. A role gets everything its parents have.

## Tasks

Start the lab with `./lab up splunk-ai-soc-investigation`. Stop other Splunk labs first, because they
share port 8000. Open **http://localhost:8000** and log in as `admin` with the lab password
`Lab-Splunk-2026`. The telemetry of **lb-web-03** (10.40.2.13), a web server of Lantern Books
(fictional), for 2 November 2026 is in three indexes:

| Index | Sourcetype | What it holds |
|---|---|---|
| `web` | `access_combined` | Every HTTP request |
| `web` | `nginx:error` | PHP and server errors |
| `network` | `suricata` | IDS alerts, JSON (`src_ip`, `dest_ip`, `dest_port`, `alert.signature`) |
| `linux` | `linux_secure` | SSH logins and sudo |

Use **All time**. In the workstation (`./lab shell splunk-ai-soc-investigation`), write `KEY=value`
answers to `/root/case/answers.txt`.

1. **The kill chain.**

   ```
   ATTACKER_IP=<the client that sent the UNION SELECT requests>
   INJECTED_PARAM=<the products.php parameter the payload was in>
   DUMPED_TABLE=<the table whose rows the last injections read out>
   WEB_SHELL=<the file name of the web shell, e.g. name.php>
   PAYLOAD_PATH=<the absolute path wget saved the second stage to>
   SSH_ACCOUNT=<the account of the one successful password login>
   C2_PORT=<the destination port of the connection lb-web-03 made out to the attacker>
   ```

2. **Checking the agent.** `/root/case/agent-notes.md` holds an AI agent's six findings on this case,
   all "high confidence". Check each against Splunk and write
   `WRONG_CLAIMS=<the numbers of the findings the data contradicts, comma-separated>`.
3. **A least-privilege account for the agent.**
   - Create a role **`soc_agent_ro`** that can search the indexes `web`, `network` and `linux` and
     nothing else, and that inherits no powerful role.
   - Create a user **`ai-agent`** (password `Agent-RO-2026`) with only that role.
   - Log in as `ai-agent` in a private window and confirm what it can and can't see.

Check your work from the host: `./lab check splunk-ai-soc-investigation`. When you're done,
`./lab down splunk-ai-soc-investigation` frees the memory.

<details>
<summary>Hints</summary>

- `index=web sourcetype=access_combined UNION SELECT | stats count by clientip`, and compare with `UNION` alone
- `| table _time uri status bytes useragent` for one client, sorted by `_time`
- Two kinds of client use curl here; only one sends `c=`
- `| eval u = urldecode(uri) | rex field=u "-O (?<payload>\S+)"`
- "Accepted password" and "Accepted publickey" are different things
- `index=network sourcetype=suricata src_ip=10.40.2.13`
- Settings > Roles > New Role: *Inheritance* (leave everything unticked), *Capabilities* (`search`),
  *Indexes* (Included)

</details>

## My notes

<!-- Screenshots: ./lab shot splunk-ai-soc-investigation ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [splunk-field-extraction](../splunk-field-extraction/): rex on raw lines
- [wazuh-alert-triage](../wazuh-alert-triage/): the same kind of triage in another SIEM
- [ransomware-kill-chain](../ransomware-kill-chain/): kill chain and ATT&CK mapping
- Splunk docs: About configuring role-based user access; urldecode; Model Context Protocol
