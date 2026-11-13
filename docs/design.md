# Task: Build uig-lab (a Docker lab for every skill I learn + a public showcase at lab.uig.me)

> Complete instructions for Claude Code, in three phases. **Do phases 1 and 2 this time**; phase 3 comes later.
>
> | | |
> |---|---|
> | GitHub account | `estul-lachin` (logged in with `gh`) |
> | Repo | `estul-lachin/uig-lab` (public) — https://github.com/estul-lachin/uig-lab |
> | CLI | `./lab` |
> | Public showcase | https://lab.uig.me |
>
> Keep this file in the repo as `docs/design.md` — it is the source of truth for the design.

## Goal

Turn every computer/IT skill I learn into a small Docker environment I can reset and redo at any time:
**one skill = one lab = one directory under `labs/`**.
Each time I complete a lab, a progress record is committed to the repo and the public site `https://lab.uig.me`
updates automatically. The site is a portfolio of what I have learned and practiced, linked from my résumé
(I'm job hunting in Canada).

Inspired by https://github.com/stratosphereips/stratocyberlab, but lighter: one bash script manages labs locally,
and the public site is purely static.

Language: everything is in English — READMEs, code comments, CLI output and the website.

## How the three parts relate (important)

| Part | Runs where | Who can access | Purpose |
|---|---|---|---|
| `./lab` CLI | My Mac (Apple Silicon) | Only me | Start, check, reset labs |
| Showcase site `lab.uig.me` | GitHub Pages (static) | Everyone | Read-only: which labs I've done, what I learned, when I passed |
| Local dashboard (phase 3) | My Mac, 127.0.0.1 | Only me | A web UI for `./lab` |

**The local dashboard can start containers and must never be exposed to the internet. Only the static showcase
is public; it has no backend and cannot perform any action.**

---

## Phase 1: Repo skeleton, `./lab`, hello-world, AI workflow files, CI

### Layout
```
uig-lab/
├── README.md                 # Project overview, link to the showcase at the top
├── CLAUDE.md                 # Rules for AI coding sessions (see below)
├── docs/design.md            # This file
├── lab                       # CLI (bash, executable)
├── lib/check-lib.sh          # Helpers shared by every check.sh
├── templates/lab/            # Template for new labs (placeholders __NAME__, __CATEGORY__)
│   ├── lab.conf
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── README.md
│   ├── check.sh
│   ├── .dockerignore
│   └── solution/solve.sh
├── templates/project/        # Template for documented projects (project.conf, README.md)
├── labs/hello-world/         # Example lab, same structure as the template
├── projects/                 # Documented projects (see "Documented projects" in phase 2)
├── progress.jsonl            # Pass records, committed to git, read by the showcase
├── .claude/commands/new-lab.md
├── .github/workflows/test.yml
└── .gitignore                # .DS_Store, *.swp, .env, site/, .venv/
```

### Files in each lab
- `lab.conf` (bash syntax; sourced in a subshell so it never pollutes `./lab`'s own variables):
  - `TITLE`: short title
  - `SUMMARY`: one or two sentences on the skill this lab practices (shown on the showcase)
  - `CATEGORY`: linux / network / security / web / db / cloud / misc
  - `TAGS`: space-separated keywords
  - `SERVICE`: compose service that `./lab shell` enters; default `main`
  - `CLEANUP_CMD`: command run inside the container before volumes are deleted; usually empty
    (e.g. a lab with `chattr +i` files must run `chattr -R -i` first, or the volume can't be removed)
  - `PUBLIC`: `yes` / `no` — whether the lab appears on the showcase; default `yes`
- `Dockerfile`: `FROM ubuntu:24.04` by default (always a pinned tag, never `latest`), apt-install what the lab
  needs, `CMD ["sleep","infinity"]`; append an `echo` to `/root/.bashrc` pointing to the task description and
  the check command
- `docker-compose.yml`: at least one service, `init: true`; add services for multi-machine labs (same network)
- `README.md`: Concepts / Tasks (what to achieve, not how) /
  Hints in a collapsible `<details>` / My notes / Related
- `check.sh`: no shebang; `./lab check` concatenates it with the lib and runs it inside the container
- `solution/solve.sh`: entry point of the reference solution; may call other scripts in the same folder
- `.dockerignore`: keeps `check.sh`, `solution/`, `screenshots/` and `README.md` out of the build context, so a
  `COPY . …` in a Dockerfile can never put them in the image
- `screenshots/` (optional, written by me): images linked from the README with a relative path
  (`![alt](screenshots/name.png)`); png/jpg/gif/webp, lowercase-hyphenated names, longest side ≤ 1600px.
  Added with `./lab shot`. Use code blocks for terminal output; screenshots are for GUIs and visual results.
  Public, so crop out usernames, hostnames, real IPs, emails and tokens

### `./lab` commands
| Command | What it does |
|---|---|
| `list [--json]` | List all labs: name, category, title, running or not, passed or not |
| `new <name> [category]` | Copy the template, replace placeholders, print which files to edit next. Names must match `^[a-z0-9][a-z0-9-]*$`; category defaults to `misc` and must be one of the seven categories; error if the lab already exists |
| `up <name>` | `docker compose up -d --build` |
| `shell <name>` | Open a shell in the SERVICE container |
| `check <name> [--json]` | Run the checks; non-zero exit if any fail; **on a full pass, append a record to `progress.jsonl`** |
| `solve <name>` | Run the reference solution |
| `shot <name> <file> <as>` | Copy an image to `labs/<name>/screenshots/<as>.<ext>`; shrink it with `sips -Z 1600` only if the longest side is over 1600px (sips also enlarges); compress PNGs with `pngquant` if installed; print the Markdown line. Never edits the README |
| `down <name>` | **Stop only, don't remove the container** (users and config created inside are kept; continue next `up`) |
| `reset <name>` | Run CLEANUP_CMD, then `down -v --remove-orphans`, then `up` |
| `test <name>` / `test --all` | reset → solve → check must fully pass → clean up (CLEANUP_CMD + `down -v`, **also on failure**); print pass/fail per lab and a total; non-zero exit if any lab fails. **`test` never writes `progress.jsonl`** (that's the reference solution passing, not me) — disable recording with an internal flag, not an environment variable a user could set by accident |
| `status <name> [--json]` | Running or not |
| `info <name>` | Show the lab.conf fields |
| `project <name> [category]` | Copy `templates/project` to `projects/<name>` (same name and category rules as `new`; names are unique across labs and projects) |
| `site` | Build the showcase into `site/` locally for preview (see phase 2) |

Always call compose as:
`docker compose -p kl-<name> --project-directory labs/<name> -f labs/<name>/docker-compose.yml`

### progress.jsonl
One record per line, for example:
```json
{"lab":"hello-world","passed_at":"2026-11-01T10:30:00-06:00","pass":3,"total":3,"checks":["hello.txt exists","Content is exactly 'Hello, World!'","Mode is 644"]}
```
- Written only when `./lab check` fully passes; a lab may have several records (redos count too)
- `checks` holds the check descriptions **as printed at run time**, so descriptions built from shell variables
  (e.g. `"User $u exists"` in a loop) appear expanded. The showcase uses these instead of parsing `check.sh`.
  Collect them from the `--json` output internally (run check in JSON mode, render the human output from it)
- Timestamp: local time, ISO 8601 with offset. Must work with macOS BSD `date` (no `date -I` / `%:z`):
  generate `+%Y-%m-%dT%H:%M:%S%z` and insert the colon in the offset yourself
- After writing, print: `Recorded. Commit to publish on lab.uig.me: git add progress.jsonl && git commit -m "pass: <name>"`
- Never auto-commit or push
- **Only my own passes belong in this file.** Never commit pass records produced by an AI session, by
  verification, or by `solve`. If verification creates a record, remove it before committing —
  `progress.jsonl` starts empty and every line in it means "Estul did this lab himself"

### Design requirements (lessons from an earlier prototype — keep all of them)
1. **Bash 4+ required (I use bash 5.3; CI uses Ubuntu's bash 5)**: use `#!/usr/bin/env bash` so the bash on
   PATH is used, not macOS's frozen `/bin/bash` 3.2. At the top of `./lab`, check `BASH_VERSINFO[0] -ge 4`
   (`lib/check-lib.sh` doesn't need this — it runs inside the Linux container); otherwise exit with:
   `uig-lab needs bash 4 or newer (macOS: brew install bash)`. Bash 4+ features (associative arrays, `mapfile`,
   `${var,,}`) are fine. **Still portable between macOS and Linux userland**, because the host tools differ:
   no `sed -i` (BSD vs GNU syntax — write to a temp file and copy it back), no GNU-only `date`, `readlink -f`,
   `grep -P` or `stat` flags on the host side. `./lab` must work from any current directory (resolve its own
   location first).
2. **Solutions never live in the container**: don't mount `check.sh` or `solution/`.
   - check: `{ preamble lines; cat lib/check-lib.sh labs/<name>/check.sh; } | compose exec -T <service> bash -s`
   - solve: `tar -C solution -cf - . | compose exec -T <service> bash -c 'extract into mktemp -d, trap cleanup, cd in, bash ./solve.sh'`
3. **umask**: on some Docker versions `docker exec` runs with umask 0000 (new files world-writable), unlike a real
   server. Set `umask 022` in shell, check and solve (shell: `bash -c 'umask 022; exec bash'`).
4. **Colors**: stdout inside the container is not a TTY. `./lab` tests `[ -t 1 ]` on the host and passes
   `FORCE_COLOR=0/1` as a preamble line; check-lib only emits colors when `FORCE_COLOR=1`.
5. **JSON mode**: pass `KL_FORMAT=json` as a preamble line; check-lib then prints one JSON object per check,
   `{"section":…,"desc":…,"ok":true/false,"hint":…}`, and a final line `{"summary":true,"pass":N,"fail":M}`.
   `hint` is `null` when there is none. Escape quotes, backslashes and control characters correctly.
   Exit codes are unchanged. Without `--json`, the CLI shows the normal human-readable output.
   If the host renders the human output from the JSON lines (so the same run also yields the `checks` array),
   the escape → parse → unescape round trip is the riskiest part of the CLI and must be tested with special
   characters (see "How to work").
6. **Negative checks need preconditions** (see below).

### Functions in lib/check-lib.sh
- `section "Title"`: start a group of checks
- `check "description" 'command string' ["hint on failure"]`: eval in a subshell; ✔ on success,
  ✘ plus hint on failure; keep counts
- `as_user <user> 'command'`: run as that user with
  `setpriv --reuid=… --regid=$(id -g …) --init-groups env HOME=/home/… bash -c`.
  Don't use `su` — it goes through PAM and hangs on a forced password change after `chage -d 0`
- `summary`: print "All passed: N/N" or "Passed X/N, Y remaining" and `exit 1`

**Rule for writing checks:** any "should NOT be possible" check (a negative check) must first confirm its
precondition, e.g. `[ -f file ] && ! modify it`. Otherwise, in an empty environment the file doesn't exist,
"can't modify it" is trivially true, and the check passes by mistake. Verify this by running `./lab check` on a
fresh environment: nothing except things that are true by default should pass.

### Example lab: hello-world
- lab.conf: `TITLE="Hello World"`,
  `SUMMARY="Verify the lab workflow: create a file with exact content and permissions."`,
  `CATEGORY="misc"`, `SERVICE="main"`
- Tasks:
  1. Write the single line `Hello, World!` to `/root/hello.txt`
  2. Set its permissions to `644`
- check.sh: file exists / content is exactly `Hello, World!` / mode is 644 (`stat -c %a`)
- solution/solve.sh: does both steps
- README follows the template; hints mention `echo`, `chmod`, `stat`

### CLAUDE.md
Short rules for future AI sessions (Claude Code reads it automatically). Include:
- What the project is, the three-part table above, and "the dashboard is never public"
- Point to `docs/design.md` for the full design
- The design requirements and the negative-check rule above
- Every lab must pass `./lab test <name>` before commit; never edit `progress.jsonl` by hand and never let
  `test` or `solve` write to it
- Never fill in the "My notes" section of a lab README — the owner writes it
- Never commit pass records created by an AI session or by verification — `progress.jsonl` only holds the
  owner's own passes
- English everywhere; pinned image tags; prefer images with arm64 builds
- A "Lessons learned" section at the end, empty for now, where I add a rule each time the AI makes a mistake

### .claude/commands/new-lab.md
A custom slash command, used as `/new-lab <what I just learned>`:
```markdown
I just learned: $ARGUMENTS

Create a new lab for it:
1. Suggest a lab name, category, and 2–4 concrete tasks. Wait for my OK.
2. Run ./lab new <name> <category>, then fill in lab.conf, Dockerfile, README.md, check.sh, solution/.
3. Follow every rule in CLAUDE.md (negative checks need preconditions, pinned arm64-friendly images, English).
4. Run ./lab check on a fresh environment first — only default-true checks may pass.
5. Run ./lab test <name> until it passes. Show me the output.
6. Leave "My notes" in the README empty — I write that myself.
7. Add the lab to the table in the main README.
```

### .github/workflows/test.yml
On `ubuntu-latest` (Docker and Compose are preinstalled). A `plan` job runs `bash -n lab` and picks the labs:
- push / pull request: only the labs whose `labs/<name>/` changed; every lab when `lab`, `lib/`, `templates/`
  or the workflow itself changed; none when nothing under `labs/` did (progress, projects, docs).
- weekly schedule and manual run (`workflow_dispatch`): every lab, to catch images or packages that changed
  upstream.

Then one parallel `./lab test <name>` job per lab (`fail-fast: false`), so a run takes about as long as its
slowest lab. Note in a comment that CI runs on amd64 while I use arm64, so an image that only exists for one
architecture will show up here.

---

## Phase 2: Showcase site at lab.uig.me

### Build
- `tools/build_site.py`: Python 3, only depends on `markdown` (listed in `tools/requirements.txt`)
- Reads `labs/*/lab.conf` (parse `KEY="value"` lines), `labs/*/README.md` and `progress.jsonl`;
  writes static HTML to `site/`
- Copies `labs/<name>/screenshots/` (images only) next to the lab page, so relative image links in the README
  work both on GitHub and on the site; warns about images over 1 MB. Other relative links point at GitHub
  (`blob`/`tree` for links, `raw.githubusercontent.com` for images)
- `REPO_URL = "https://github.com/estul-lachin/uig-lab"` as a constant at the top
- Includes only labs with `PUBLIC=yes` that I have passed at least once. Unpassed labs get no card, no page
  and are not counted anywhere (no "not yet" cards, no "passed / total")
- **Never publishes** `solution/` or `check.sh` source. The check list on a lab page comes from the `checks`
  field of its latest progress record; labs never passed show no check list
- Parse timestamps with or without the colon in the offset
- `./lab site` runs it; local preview: `python3 -m http.server -d site 8000`

### Pages
1. **Home**:
   - One-line intro + stats: number of labs passed, passed count per category, date of the latest pass
   - Cards grouped by category: title, summary, tags, first pass date (and number of passes if more than one)
2. **Lab page** `/labs/<name>/`:
   - Title + summary, then the rendered README (keep `<details>` collapsible)
   - Check list (from the latest pass record)
   - Pass record: first pass, latest pass, number of passes
   - Link to the lab's folder: `REPO_URL/tree/main/labs/<name>`
3. **Timeline** `/timeline/`: every pass, newest first (lab passes only, never projects)
4. **Projects** `/projects/` and `/projects/<name>/`: documented projects (see below); the nav links to it only once
   there is at least one

### Documented projects
Work that can't be a Docker lab with automated checks (VMs, Windows, Active Directory, Wazuh agents, GUI
tools), such as my VM home lab, which my résumé links to. Kept clearly apart from labs so "passed" keeps its
meaning:
- `projects/<name>/project.conf`: `TITLE`, `SUMMARY`, `CATEGORY`, `TAGS`, `DATE`, `PUBLIC`.
  A project is published only when `PUBLIC=yes` **and** `DATE` is set (e.g. `2026-11`): an unfinished write-up
  stays hidden, the way an unpassed lab does
- `README.md` (Overview / What I built / What I did / What I learned / My notes / Related) and optional
  `screenshots/`, all written by me; empty sections are hidden on the site
- On the site: a "Documented projects" section on the home page and a stat for their count, a `/projects/`
  index, and one page per project, each with a "Documented project · not auto-checked" badge. Never in the
  timeline, never in `progress.jsonl`
- `./lab shot` works for projects too

### Design
- One CSS file, no JS framework; works at phone width; a dark terminal theme (mono font for headings, data and code, sans for prose; soft green accent, no glow or scanlines; a CSS-only cursor that blinks a few times then stays solid, off under `prefers-reduced-motion`) shared with the other uig.me sites
- Clean, like technical docs / a portfolio — nothing flashy
- No personal contact details (phone, email); only links to LinkedIn
  (https://www.linkedin.com/in/estul-lachin) and https://github.com/estul-lachin, in the footer
- The site says whose it is, since my résumé links to it: page titles end in "Estul Lachin", the header shows
  my name, and the home page has a one-line byline (role and city)
- Favicons (`favicon.svg`, `favicon.ico`, `apple-touch-icon.png`) and a 1200x630 link-preview image
  (`og-image.png`) live in `tools/assets/` and are copied to the site root. They are rendered from
  `favicon.svg` and `og-image.html` by `tools/render_assets.sh` (macOS, Chrome) and committed, so the build
  and CI never need a browser
- Open Graph / Twitter card meta tags on every page (title, description, URL), so links shared on LinkedIn
  or in messages show a proper preview

### Deployment
- `.github/workflows/pages.yml`, on push to main:
  `actions/setup-python` → `pip install -r tools/requirements.txt` → `python tools/build_site.py`
  → `actions/upload-pages-artifact` (path: site) → `actions/deploy-pages`;
  with `permissions: pages: write, id-token: write` and a `concurrency` group so deploys don't overlap
- `site/` is not committed (built in CI only)
- With GitHub Actions deployments the custom domain is set in repo Settings, not by a `CNAME` file
- Document in the README the manual steps I need to do (in this order):
  1. GitHub → Settings (account) → Pages → **verify the domain `uig.me`** (adds a TXT record in DNS;
     prevents anyone else from claiming my subdomains)
  2. In the DNS for uig.me, add a CNAME record: `lab` → `estul-lachin.github.io`
  3. Repo Settings → Pages → Source: **GitHub Actions**
  4. Custom domain: `lab.uig.me`; once the certificate is issued, tick **Enforce HTTPS**

---

## Phase 3 (not now): Local dashboard

Record these principles in the README under "Roadmap":
- The dashboard is a UI layer over `./lab`: every action runs `./lab ... --json` via subprocess;
  it never calls Docker directly
- Runs on the host, not in a container; never mounts the Docker socket
- Listens on 127.0.0.1 only, no login; **never deployed to lab.uig.me or any public address**
- Python 3 + FastAPI + Jinja2 + a little vanilla JS, code in `dashboard/`, started with `./lab dashboard`
- Pages: lab list and status, start/stop/reset/check buttons, rendered README, check results
- Lab names must match `[a-z0-9-]` and exist, to prevent command injection
- In-browser terminal (xterm.js + WebSocket) comes later still

---

## Main README.md must include
- One-line description + showcase link https://lab.uig.me + link to the inspiration
- Requirements: Docker Desktop or OrbStack (Compose v2+), bash 4+ (macOS: `brew install bash`),
  Python 3 (only for building the showcase)
- Quick start: list / up / shell / check / down / reset
- When I learn something new: `/new-lab` in Claude Code (or `./lab new` by hand) → `./lab test`
  → do it myself and `./lab check` → write My notes → commit + push → the showcase updates
- Layout, and why solutions never enter the container
- What fits as a lab (Linux commands, service config, network tools, multi-container networks, vulnerable
  services, log analysis) and what doesn't (pure concepts → notes; Windows / Active Directory / Sysmon / GUI
  → my VM home lab)
- Conventions: lowercase-hyphenated names; categories as above; pinned image tags, preferably with **arm64**
  builds; every lab must pass `./lab test` before commit; set `PUBLIC=no` for labs I don't want shown (note: the repo itself is
  public, so `PUBLIC=no` hides a lab from the site, not from GitHub)
- Showcase deployment steps (phase 2)
- Roadmap (phase 3)
- Lab table (only hello-world for now)

---

## How to work
1. Before writing anything, list the files you'll create and the key design choices, and wait for my OK.
2. Check the setup first (read-only): `gh auth status` shows `estul-lachin`; `git config user.name` /
   `user.email` are set (suggest the GitHub noreply address of `estul-lachin` so commits link to the profile);
   whether `origin` already points to `estul-lachin/uig-lab`; Docker and Compose versions and architecture;
   `bash --version` (must be 4+) and `python3 --version`. If the repo doesn't exist yet, create it with
   `gh repo create estul-lachin/uig-lab --public --source=. --remote=origin` — ask me first.
3. Plan one phase at a time: present the phase 1 plan, implement it, verify, commit; then the phase 2 plan.
4. After phase 1, actually run these and show me the output:
   - The version guard: if `/bin/bash --version` is older than 4 (normal on macOS), `/bin/bash ./lab list`
     must exit with the "needs bash 4 or newer" message; if `/bin/bash` is 4+, just say so and skip this step
   - `bash -n lab`
   - `./lab list` and `./lab list --json`
   - `./lab up hello-world`, then `./lab check hello-world` right away: should fail (empty environment);
     progress.jsonl unchanged
   - Do the tasks manually in the container, then `./lab check hello-world`: all pass; one new line in
     progress.jsonl with the `checks` array
   - `./lab check hello-world --json`: every line is valid JSON (validate each with `python3 -m json.tool`)
   - `./lab test hello-world`: all pass, progress.jsonl unchanged, volumes removed
     (`docker volume ls | grep kl-` prints nothing)
   - `./lab new demo-test network` → confirm no `__` placeholders remain → `./lab test demo-test` passes
     → delete `labs/demo-test`
   - `./lab new Bad_Name` must fail; `./lab new ok-name nosuchcategory` must fail
   - `./lab down hello-world` keeps the container (`docker ps -a`); `./lab reset hello-world` works
   - **Special-character round trip**: temporarily add to hello-world's check.sh a check whose description and
     hint contain double quotes, a backslash, a single quote and a tab, and whose command is `true`, e.g.
     `check 'Path "C:\temp"<TAB>it'"'"'s fine' 'true' 'say "hi"'`. Confirm the human output shows the text
     exactly, every `--json` line is valid JSON, and the resulting progress record (including `checks`) is valid
     JSON. Then remove the temporary check
   - **Before committing, remove every progress record created during verification** — `progress.jsonl` must be
     empty in the commit
5. After phase 2: `./lab site` builds successfully; serve with `python3 -m http.server -d site 8000`, open the
   home page, the hello-world page and the timeline, and show me screenshots; confirm `site/` contains no solution
   or check.sh source.
   For the preview, use a temporary progress record (or a copy of progress.jsonl) so the pages show a passed lab,
   and don't commit it.
6. Make one git commit after each phase passes. Show me `git log --stat` and ask before pushing.
