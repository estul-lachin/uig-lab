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
- Never fill in the "My notes" section of a lab README; the owner writes it.
- English everywhere (READMEs, comments, CLI output, website).
- Pinned image tags, never `latest`; prefer images with arm64 builds (CI runs on amd64, so both matter).
- Course material from paid courses is never copied: rewrite in the owner's own words with their own scenarios.
- Never commit or push without being asked.

## Lessons learned

<!-- One rule per AI mistake, added by the owner. -->
