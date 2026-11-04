# uig-lab

Every IT skill I learn, turned into a small Docker lab I can reset and redo at any time.

**Showcase: https://lab.uig.me**: which labs I've done, what I learned, and when I passed them.

Inspired by [stratosphereips/stratocyberlab](https://github.com/stratosphereips/stratocyberlab), but lighter:
one bash script manages labs locally, and the public site is purely static.

## Requirements

- Docker Desktop or OrbStack (Docker Compose v2+)
- bash 4 or newer (macOS ships 3.2: `brew install bash`)
- Python 3 (only for building the showcase)

## Quick start

```bash
./lab list                    # all labs: category, title, running, passed
./lab up hello-world          # build and start
./lab shell hello-world       # work inside the container
./lab check hello-world       # check the result; a full pass is recorded in progress.jsonl
./lab down hello-world        # stop; your changes are kept for the next `up`
./lab reset hello-world       # wipe everything and start fresh
```

Other commands: `new`, `project`, `solve`, `test`, `status`, `info`, `shot`, `site`. Run `./lab help` for the full list.

## When I learn something new

1. `/new-lab <what I just learned>` in Claude Code, or `./lab new <name> [category]` by hand
2. `./lab test <name>`: the reference solution must pass on a fresh environment
3. `./lab reset <name>`, do it myself, then `./lab check <name>`
4. Write "My notes" in the lab's README
5. Commit and push (including the new line in `progress.jsonl`); the showcase updates automatically

## Layout

```
lab                    CLI (bash)
lib/check-lib.sh       helpers shared by every check.sh (section, check, as_user, summary)
templates/lab/         template for new labs
templates/project/     template for new documented projects
labs/<name>/           one lab: lab.conf, Dockerfile, docker-compose.yml, README.md, check.sh, solution/,
                       .dockerignore, optional screenshots/
projects/<name>/       one documented project: project.conf, README.md, optional screenshots/
progress.jsonl         one line per pass, read by the showcase
docs/design.md         full design
```

**Why solutions never enter the container:** `check.sh` and `solution/` are not mounted or copied into the
image (each lab's `.dockerignore` even keeps them out of the build context). `./lab check` pipes the check script into `bash -s` inside the container, and `./lab solve` streams
`solution/` as a tar archive into a temporary directory that is deleted afterwards. While I'm working in the
lab, there is nothing in it to peek at.

## What fits as a lab

Good fits: Linux commands, service configuration, network tools, multi-container networks, vulnerable
services, log analysis: anything whose end state a script can check.

Not a fit: pure concepts (those go into notes), and Windows / Active Directory / Sysmon / GUI tools, which
run in my VM home lab. Those become **documented projects** instead: `./lab project <name> [category]` creates
`projects/<name>/`, I write it up with notes and screenshots, and once I set `DATE` in `project.conf` it
appears on the showcase, clearly marked "documented project, not auto-checked". Projects have no container
and no checks, never go into `progress.jsonl` or the timeline, and lab and project names are unique across
both folders.

## Conventions

- Lab names are lowercase and hyphenated (`^[a-z0-9][a-z0-9-]*$`)
- Categories: `linux`, `network`, `security`, `web`, `db`, `cloud`, `misc`
- Pinned image tags (never `latest`), preferably images with **arm64** builds
- Every lab must pass `./lab test <name>` before it is committed
- Content from paid courses is rewritten in my own words with my own scenarios, never copied
- Screenshots: `./lab shot <lab> ~/Screenshots/<file>.png <name>` copies one into `labs/<lab>/screenshots/`,
  shrinks it to 1600px on the longest side if it is bigger (never enlarges), compresses PNGs when `pngquant`
  is installed (`brew install pngquant`), and prints the Markdown line to paste into the README:
  `![what it shows](screenshots/name.png)`. Images show up on GitHub and on the showcase. Check them for
  private details first. Terminal output goes in code blocks instead
- `PUBLIC=no` in `lab.conf` hides a lab from the showcase. The repo itself is public, so this hides it
  from the site, not from GitHub

## Showcase deployment

The site is built by `tools/build_site.py` (from `lab.conf`, `README.md` and `progress.jsonl`, never from
`check.sh` or `solution/`; the build fails if any of their content would end up in the output) and deployed by
`.github/workflows/pages.yml` to GitHub Pages on every push to `main`. Only labs with `PUBLIC=yes` that I have
passed at least once are shown, plus documented projects with `PUBLIC=yes` and a `DATE`. `site/` is never
committed.

Local preview:

```bash
python3 -m venv .venv && .venv/bin/pip install -r tools/requirements.txt   # once
./lab site
python3 -m http.server -d site 8000                                        # http://localhost:8000
```

One-time manual setup, in this order:

1. GitHub → Settings (account) → Pages → **verify the domain `uig.me`** (adds a TXT record in DNS; prevents
   anyone else from claiming my subdomains)
2. In the DNS for uig.me, add a CNAME record: `lab` → `estul-lachin.github.io`
3. Repo Settings → Pages → Source: **GitHub Actions**
4. Custom domain: `lab.uig.me`; once the certificate is issued, tick **Enforce HTTPS**

## Roadmap

A local dashboard (phase 3):

- A UI layer over `./lab`: every action runs `./lab ... --json` via subprocess; it never calls Docker directly
- Runs on the host, not in a container; never mounts the Docker socket
- Listens on 127.0.0.1 only, no login; **never deployed to lab.uig.me or any public address**
- Python 3 + FastAPI + Jinja2 + a little vanilla JS, code in `dashboard/`, started with `./lab dashboard`
- Pages: lab list and status, start/stop/reset/check buttons, rendered README, check results
- Lab names must match `[a-z0-9-]` and exist, to prevent command injection
- An in-browser terminal (xterm.js + WebSocket) comes later still

## Labs

| Lab | Category | What it practices |
|---|---|---|
| [backups-rsync-cron](labs/backups-rsync-cron/) | linux | Back up an application directory with rsync, locally and over SSH to a second machine, wrap it in a script that cron runs every night, prove the backup by restoring a file with its permissions, and remove a suspicious cron job. |
| [bash-conditionals](labs/bash-conditionals/) | linux | Write bash decisions that hold up: file tests that get symlinks right, numeric comparisons that reject bad input, a case dispatcher with proper usage errors, regex validation of IPv4 addresses, and an IP classifier built from them. |
| [bash-functions](labs/bash-functions/) | linux | Build a small bash function library: functions that take any number of arguments, return status codes instead of exiting, keep their variables local, get sourced from another script by path, and pass exit codes on unchanged. |
| [bash-loops](labs/bash-loops/) | linux | Write bash loops that survive real input: globs with spaces and no matches, line-by-line reads that keep whitespace and the last line, C-style counting loops, and process substitution to spot accounts added since a baseline. |
| [bash-traps-signals](labs/bash-traps-signals/) | linux | Make bash scripts clean up after themselves with an EXIT trap, shut down gracefully on SIGINT, report failures with an ERR trap, start from strict defaults, and fix a cleanup script that could delete the wrong files. |
| [bash-variables-quoting](labs/bash-variables-quoting/) | linux | Quote variables so input survives intact, pass arguments on with \"\$@\", take paths apart with parameter expansion, give settings defaults and required values, and mask secrets in log lines. |
| [cpu-load](labs/cpu-load/) | linux | Read load averages against the real CPU budget, sample the system with vmstat and mpstat, create and catch CPU load with top, then hunt down a miner-style process that keeps coming back under a new PID. |
| [disk-io](labs/disk-io/) | linux | Measure disk activity with iostat and /proc/diskstats, generate a controlled write load with dd and work out how much reached the disk, then track a hidden process that keeps writing back to its file and stop it for good. |
| [linux-101-capstone](labs/linux-101-capstone/) | linux | An onboarding ticket end to end: build a site workspace, set permissions, find and copy a hidden file, write and schedule a backup script, create a user, record the host's IP, then remove a malicious cron job. |
| [linux-authentication](labs/linux-authentication/) | linux | Read /etc/passwd and /etc/shadow, change accounts with usermod, log in to a second machine with a passphrase-protected SSH key, then hunt down and remove backdoors left on the box. |
| [linux-cli-intro](labs/linux-cli-intro/) | linux | Read the prompt, move around the directory tree, read logs with cat, head, tail and grep, use pipes and redirection, look things up with --help and which, and read a shell history as evidence. |
| [linux-file-editing](labs/linux-file-editing/) | linux | Edit files with nano and vim, including search and replace, and write files from the shell with cat, echo, printf, tee and redirection. |
| [linux-file-management](labs/linux-file-management/) | linux | Create, remove, copy, move and rename files and directories, find files by name and search their contents, then spot a persistence entry in cron. |
| [linux-file-permissions](labs/linux-file-permissions/) | linux | Set modes with octal and symbolic chmod, change owners with chown and chgrp, recognise SUID, SGID and the sticky bit, then audit a server for permission backdoors. |
| [linux-server-setup](labs/linux-server-setup/) | linux | Prepare a fresh Ubuntu server: SSH key, users and groups, a locked-down shared directory, an install script, stderr logging and a hardware inventory. |
| [logs-journald](labs/logs-journald/) | linux | Reconstruct an intrusion from a real systemd journal with journalctl filters (boot, unit, priority, time window, grep), search rotated and compressed plaintext logs, and set up and test log rotation with logrotate. |
| [memory-swap](labs/memory-swap/) | linux | Read memory the way the kernel reports it (free, /proc/meminfo, swappiness), see why a container's real limit lives in its cgroup, rank processes by RSS, and unmask a process that hides behind a kernel-thread name. |
| [ownership-groups](labs/ownership-groups/) | linux | Manage a team group (fixed GID, adding and removing members), share a file through it, re-own a directory tree without following a planted symlink to /etc/shadow, and clean up files left behind by deleted accounts. |
| [package-management](labs/package-management/) | linux | Install, inspect and hold packages with apt and dpkg, snapshot every APT source, then find a rogue repository and a tampered system binary with dpkg -V and repair it. |
| [sysctl-tuning](labs/sysctl-tuning/) | linux | Read kernel parameters with sysctl and /proc/sys, audit unsafe network settings, write a hardening drop-in that sysctl accepts, and work out which file really wins when another drop-in overrides it. |
| [systemd-services](labs/systemd-services/) | linux | Run real systemd in a container: write a service unit with its own user and restart policy, enable it, change it with a drop-in, fix a failing unit, and remove a backdoor service that keeps itself alive. |
| [unix-permissions](labs/unix-permissions/) | linux | Set file and directory modes with octal and symbolic chmod and check them as other users, use capital X for directories, strip 'other' access recursively, set a persistent umask, and work out what r, w and x mean on a directory. |
| [dns-resolution](labs/dns-resolution/) | network | Read the resolver configuration, run forward and reverse lookups with dig against a lab DNS server, override a name in /etc/hosts, read the resolver order, then undo a hosts-file hijack. |
| [ip-interfaces](labs/ip-interfaces/) | network | Inventory a host's interfaces, IPv4 addresses and MAC addresses with ip and /sys/class/net, bring loopback and a disabled interface back up, then remove an interface that isn't in the asset record. |
| [routing-gateway](labs/routing-gateway/) | network | Read the routing table, find the default gateway, ask the kernel how it would reach an address, add a real blackhole route, then remove a route that diverts a network to a rogue next hop. |
| [tcp-connections](labs/tcp-connections/) | network | List listening sockets and established connections with ss, stand up listeners and clients with ncat, count a live connection, then find and stop a disguised backdoor listener. |
| [blackcat-case-study](labs/blackcat-case-study/) | security | BlackCat/ALPHV's background, then a fictional intrusion that uses only valid accounts and legitimate tools, traced through sign-ins, help-desk tickets, EDR, proxy and ESXi logs, plus an MFA-fatigue detection tested against unseen sign-ins. |
| [conti-case-study](labs/conti-case-study/) | security | Conti's background, then a fictional Conti-style intrusion at a clinic traced from a phishing document to encryption in Windows Security and Sysmon events, with the earliest detection point for each stage and a beacon detector tested against unseen traffic. |
| [lockbit-case-study](labs/lockbit-case-study/) | security | LockBit's history and tradecraft, then a fictional LockBit 3.0-style night at a logistics company reconstructed from Windows Security and Sysmon events with jq, mapped to ATT&CK, and turned into a shadow-copy deletion detection tested against unseen events. |
| [posix-acls](labs/posix-acls/) | security | Give one extra user access without changing owner or group, make new files inherit it with a default ACL, read effective rights through the mask, then find and revoke an ACL that quietly exposed HR data. |
| [ransomware-drill](labs/ransomware-drill/) | security | A ransomware drill on a file server: make an immutable, verifiable backup, set off a simulated encryptor, detect what it did, contain it before recovering, restore with zero checksum errors, and name what the recovery point lost. |
| [ransomware-kill-chain](labs/ransomware-kill-chain/) | security | Work an intel report like an analyst: extract and refang the IoCs with grep and sed, map a twelve-step ransomware intrusion to the Cyber Kill Chain and MITRE ATT&CK, and name the roles and the extortion model behind it. |
| [ransomware-qr-phishing](labs/ransomware-qr-phishing/) | security | Rebuild a QR-code phishing intrusion from mail, identity, directory, endpoint and proxy logs with jq: MFA fatigue, a new admin account, encoded PowerShell and exfiltration, mapped to MITRE ATT&CK, plus the initial access of four public ransomware cases. |
| [revil-case-study](labs/revil-case-study/) | security | REvil/Sodinokibi's background, then the morning after a REvil-style hit on a file share: identify the extension and notes, find the RDP brute force and the decoded shadow-copy command, then restore from backup against a SHA-256 manifest while preserving the evidence. |
| [siem-correlation-rules](labs/siem-correlation-rules/) | security | QRadar's Building Block, Rule and Offense layers rebuilt as Wazuh rules: a CDB list and a silent base rule, a threshold rule for password guessing, and a correlation rule for a privileged login that follows it, all tested with wazuh-logtest on attack and decoy sequences. |
| [special-permission-bits](labs/special-permission-bits/) | security | Set the three special permission bits and watch what they do: a SUID program running as root, a SGID directory that hands its group to new files, a sticky upload folder, then audit SUID files and remove a privilege-escalation backdoor. |
| [splunk-ai-soc-investigation](labs/splunk-ai-soc-investigation/) | security | Rebuild a web intrusion's kill chain across web, IDS and auth indexes on a local Splunk (SQL injection, web shell, second stage, SSH login, call-home), check an AI agent's confident findings against the data, and give such an agent a least-privilege, read-only Splunk account. |
| [splunk-alerts](labs/splunk-alerts/) | security | Turn SPL into Splunk alerts: a scheduled SSH brute-force alert on a cron schedule that fires per result, throttles per source and posts each attacker to a lab WAF webhook, and a real-time server-error alert throttled per endpoint, then see what each one really caught. |
| [splunk-dashboards](labs/splunk-dashboards/) | security | Turn SPL into reports and a SOC dashboard on a local Splunk: pick the visualization that fits each search (single value, pie, bar, column, line), save and reuse a report, share it with the app, and check the panels the dashboard really holds. |
| [splunk-field-extraction](labs/splunk-field-extraction/) | security | Pull fields out of raw sshd and web lines on a local Splunk: erex by example, rex with named groups that survive the invalid-user variant, the regex command for internal addresses, distinct attackers, sed-style masking, and a saved extraction from the Extract New Fields wizard. |
| [splunk-search-basics](labs/splunk-search-basics/) | security | Find your way around Splunk Web with a local Splunk Enterprise: event metadata, sourcetypes, fields, search modes and exact time ranges, then trace an SSH brute force and a web scan and save the hunt as a report. |
| [splunk-spl-fundamentals](labs/splunk-spl-fundamentals/) | security | Write SPL against a local Splunk Enterprise: terms and phrases, implicit AND, uppercase OR and NOT, field comparisons, distinct counts, and shaping results with table, rename, sort and dedup, ending in a saved report of web errors. |
| [splunk-transforming-commands](labs/splunk-transforming-commands/) | security | Summarise web traffic on a local Splunk with top, rare and stats: the busiest client, the quiet one that rare brings to the top, server errors, distinct paths per client, the top blocked attacker, and a saved per-client profile built with stats. |
| [syslog-collector](labs/syslog-collector/) | security | Build the front end of a SIEM with rsyslog: receive syslog on 514/udp and tcp, recognise each log source by its address, route unknown devices aside, normalise firewall logs into JSON fields like a QRadar DSM, then find the scanner in the parsed data. |
| [users-sudo](labs/users-sudo/) | security | Create and lock an account, grant it exactly one command through a validated sudoers drop-in and prove nothing else works, set password aging, then audit every route to root on the box and close the ones that shouldn't exist. |
| [wannacry-case-study](labs/wannacry-case-study/) | security | WannaCry's background, then a hands-on SMB exposure audit with nmap, a file server hardened against SMBv1 and NetBIOS without breaking SMB3, and a fictional worm outbreak reconstructed from Zeek-style connection and DNS logs, kill switch included. |
| [wazuh-alert-triage](labs/wazuh-alert-triage/) | security | Triage a mixed Wazuh alert stream on a local single-node Wazuh: count it, slice it by rule.id and rule.groups, rank SSH brute-force sources and usernames, measure FIM and web-attack noise, and find the attack that worked. |
| [wazuh-fim-intrusion](labs/wazuh-fim-intrusion/) | security | Reconstruct an intrusion from real Wazuh syscheck alerts with jq: count modified, added and deleted files, find the cron persistence, read the diffs to see what the intruder changed, and write a rule that raises new cron jobs to level 12. |
| [wazuh-rootcheck-trojans](labs/wazuh-rootcheck-trojans/) | security | Rank a fleet's Wazuh rootcheck detections with jq: total, worst and second-worst host, the trojaned binary, the kernel-rootkit hits that rule 510 does not count, the quiet host that is infected too, and a level-12 rule for trojaned system binaries. |
| [wazuh-ssh-bruteforce](labs/wazuh-ssh-bruteforce/) | security | Take apart an SSH brute force on a Wazuh manager with jq: count and attribute the failures, find the account that fell and why its success is not a 5715, separate it from the staff baseline, catch the stolen password reused from a second address, and alert on every external login. |
| [wazuh-sudo-abuse](labs/wazuh-sudo-abuse/) | security | Detect privilege escalation through sudo with a Wazuh manager and jq on its alert log: count failed and successful sudo, name the abuser, catch the first-time success that rule 5402 misses, follow what came after the breakthrough, and write a rule for sudo into shell-escape binaries. |
| [wazuh-web-attack-triage](labs/wazuh-web-attack-triage/) | security | Triage a web server's attack traffic with a Wazuh manager and jq: count SQL injection, XSS and traversal alerts, rank attackers across techniques, find the attack that returned 200, see why rule.groups attack ranks a scanner first, and close the URL-encoded traversal gap with a rule. |
| [hello-world](labs/hello-world/) | misc | Verify the lab workflow: create a file with exact content and permissions. |
