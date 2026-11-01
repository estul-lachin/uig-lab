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

Other commands: `new`, `solve`, `test`, `status`, `info`, `site`. Run `./lab help` for the full list.

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
labs/<name>/           one lab: lab.conf, Dockerfile, docker-compose.yml, README.md, check.sh, solution/
progress.jsonl         one line per pass, read by the showcase
docs/design.md         full design
```

**Why solutions never enter the container:** `check.sh` and `solution/` are not mounted or copied into the
image. `./lab check` pipes the check script into `bash -s` inside the container, and `./lab solve` streams
`solution/` as a tar archive into a temporary directory that is deleted afterwards. While I'm working in the
lab, there is nothing in it to peek at.

## What fits as a lab

Good fits: Linux commands, service configuration, network tools, multi-container networks, vulnerable
services, log analysis: anything whose end state a script can check.

Not a fit: pure concepts (those go into notes), and Windows / Active Directory / Sysmon / GUI tools (those
belong in my VM home lab).

## Conventions

- Lab names are lowercase and hyphenated (`^[a-z0-9][a-z0-9-]*$`)
- Categories: `linux`, `network`, `security`, `web`, `db`, `cloud`, `misc`
- Pinned image tags (never `latest`), preferably images with **arm64** builds
- Every lab must pass `./lab test <name>` before it is committed
- Content from paid courses is rewritten in my own words with my own scenarios, never copied
- `PUBLIC=no` in `lab.conf` hides a lab from the showcase. The repo itself is public, so this hides it
  from the site, not from GitHub

## Showcase deployment

The site is built by `tools/build_site.py` (from `lab.conf`, `README.md` and `progress.jsonl`, never from
`check.sh` or `solution/`; the build fails if any of their content would end up in the output) and deployed by
`.github/workflows/pages.yml` to GitHub Pages on every push to `main`. Only labs with `PUBLIC=yes` that I have
passed at least once are shown. `site/` is never committed.

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
| [hello-world](labs/hello-world/) | misc | Verify the lab workflow: create a file with exact content and permissions. |
