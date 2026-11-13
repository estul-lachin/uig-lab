# CLAUDE.md: rules for AI coding sessions

uig-lab turns every IT skill the owner learns into a Docker lab (one skill = one lab = one directory under
`labs/`), managed by the bash CLI `./lab`. Passes are recorded in `progress.jsonl` and published on the static
showcase https://lab.uig.me. Full design: `docs/design.md` (the source of truth).

| Part | Runs where | Who can access | Purpose |
|---|---|---|---|
| `./lab` CLI | Owner's Mac (Apple Silicon) | Only the owner | Start, check, reset labs |
| Showcase site `lab.uig.me` | GitHub Pages (static) | Everyone | Read-only portfolio of passed labs |
| Local dashboard (phase 3) | Owner's Mac, 127.0.0.1 | Only the owner | A web UI for `./lab` |

**The dashboard is never public.** It can start containers; only the static showcase (no backend, no actions)
is exposed to the internet.

## Design requirements

1. Bash 4+: `#!/usr/bin/env bash`; `./lab` checks `BASH_VERSINFO`. Host-side code must stay portable between
   macOS and Linux: no `sed -i`, GNU-only `date`, `readlink -f`, `grep -P` or `stat` flags. `./lab` works from
   any directory.
2. Solutions never live in the container: never mount or copy `check.sh` or `solution/`. Check is piped into
   `bash -s`; solve streams a tar into a temp dir.
3. `umask 022` in shell, check and solve (`docker exec` may run with umask 0000).
4. Colors: the host tests `[ -t 1 ]` and passes `FORCE_COLOR=0/1`; check-lib only colors when `FORCE_COLOR=1`.
5. JSON mode (`KL_FORMAT=json`): one object per check plus a summary line. The host renders human output from
   it; escaping round trips must survive quotes, backslashes and control characters.
6. **Negative checks need preconditions**: a "should NOT be possible" check must first confirm its precondition
   (`[ -f file ] && ! modify it`), or it passes trivially in an empty environment. Verify by running
   `./lab check` on a fresh environment: only default-true checks may pass.

## Rules

- Every lab must pass `./lab test <name>` before commit.
- Never edit `progress.jsonl` by hand, and never let `test` or `solve` write to it.
- Never commit pass records created by an AI session or by verification: `progress.jsonl` only holds the
  owner's own passes. Remove any such records before committing.
- Never fill in the "My notes" section of a lab README; the owner writes it. The same goes for screenshots.
- Documented projects (`projects/<name>/`, created with `./lab project`) are the owner's own write-ups of
  work that can't be a Docker lab (VMs, Windows, GUI tools). Never write their content or set their `DATE`:
  an AI session may only create the skeleton and fix formatting when asked. The site marks them "not
  auto-checked"; never present a project as a passed lab.
- Screenshots live in `labs/<name>/screenshots/` or `projects/<name>/screenshots/` (png/jpg/gif/webp, lowercase-hyphenated names, longest side
  1600px or less; the owner adds them with `./lab shot`) and are linked from the README with a relative path
  and real alt text. Never run `sips -Z` on a whole folder: it also enlarges small images. Terminal output goes in
  code blocks, not screenshots. Everything here is public: no usernames, hostnames, real IPs, emails or tokens.
- Every lab has a `.dockerignore` (from the template) that keeps `check.sh`, `solution/`, `screenshots/` and
  `README.md` out of the Docker build context.
- English everywhere (READMEs, comments, CLI output, website).
- Pinned image tags, never `latest`; prefer images with arm64 builds (CI runs on amd64, so both matter).
- Write original scenarios and data; never copy text or questions from source material.
- Never commit or push without being asked.

## Exceptions the owner granted

- `projects/sentinel-incident-triage` (2026-11-13): at the owner's request, an AI session wrote the README,
  set DATE, and added the screenshots (cropped and redacted from the owner's own portal screenshots). The
  triage itself, every investigation and every incident close, was done by the owner. This applies to this
  project only; the projects rule above still holds everywhere else.

## Lessons learned

<!-- One rule per AI mistake, added by the owner. -->
