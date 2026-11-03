# bash-traps-signals

## Concepts

A script that works on the happy path isn't finished. It also has to clean up when it fails, stop
politely when someone presses Ctrl+C, say *where* it broke, and refuse to run on bad input instead of
doing damage. Bash has a few tools for this, and every triage or backup script I write should use them.

**trap** runs a command when the shell receives a signal or reaches a special event:

```bash
trap 'rm -rf "$tmp"' EXIT     # whenever the script ends: normal exit, exit 3, set -e, Ctrl+C
trap on_int INT               # call the function on_int when SIGINT arrives
trap 'echo "error on line $LINENO" >&2' ERR   # whenever a command fails
```

Single quotes matter: `$tmp` and `$LINENO` are expanded when the trap *fires*, not when it's set.

**mktemp -d** creates a fresh, private directory (`/tmp/tmp.XXXXXXXXXX`), so two runs never collide.
An EXIT trap is the reliable way to remove it: the script can't forget to, whichever way it ends.

**Signals** are short messages the kernel delivers to a process. `kill -l` lists them.

| Signal | Number | Sent by | Default |
|---|---|---|---|
| SIGINT | 2 | Ctrl+C in the terminal | Terminate |
| SIGTERM | 15 | `kill PID` (the polite request) | Terminate |
| SIGKILL | 9 | `kill -9 PID` | Terminate; **cannot be trapped** |
| SIGHUP | 1 | The terminal closing | Terminate |

By convention, a program that ends because of a signal exits with **128 + the signal number**, so
Ctrl+C gives `130`. A handler that cleans up and then runs `exit 130` keeps that convention.

Bash runs a trap only between commands. While a foreground `sleep 30` is running, the handler waits
until it returns, so long waits are better written as loops of short sleeps.

**Strict mode** at the top of a script:

| Setting | Effect |
|---|---|
| `#!/usr/bin/env bash` | Find bash through `$PATH` instead of assuming `/bin/bash` |
| `set -e` | Stop at the first command that fails |
| `set -u` | Using an unset variable is an error, not an empty string |
| `set -o pipefail` | A pipeline fails if *any* part fails, not just the last one |
| `set -E` | ERR traps also fire inside functions and subshells |
| `IFS=$'\n\t'` | Split words only on newlines and tabs, so file names with spaces stay whole |

`set -e` has exceptions (commands in `if`, `&&`/`||` chains, and so on), so it's a safety net, not
error handling.

**The empty variable trap**: `rm -f "$LOGDIR"/old-*.log` with `LOGDIR` unset becomes
`rm -f /old-*.log`, which deletes in `/`. `set -u`, or `${LOGDIR:?message}` (stop with that message
if the variable is unset or empty), turns it into an error before anything is deleted.

## Tasks

Start the lab with `./lab up bash-traps-signals`, open a shell with `./lab shell bash-traps-signals`.
The shell is `root` in `/root/scripts`. Make every script executable. The check *runs* your scripts.

1. **Cleanup trap**: `cleanup.sh`
   - Create a temp directory with `mktemp -d` and register an EXIT trap that removes it.
   - Write the directory's path to `/root/scripts/last-tmpdir.txt`.
   - Create a file inside the directory, sleep 1 second, then exit with the status given as the first
     argument (default `0`).
   - The directory must be gone after the script ends, even with a non-zero status.
2. **SIGINT handler**: `graceful.sh`
   - Keep running until interrupted.
   - On SIGINT, append the line `caught SIGINT` to `/root/scripts/graceful.log` and exit with status
     `130`.
   - Try it: run it, press Ctrl+C, then `echo $?`.
3. **ERR trap**: `errtrap.sh`
   - Use `set -euo pipefail` and an ERR trap that prints `error on line <N>` to stderr.
   - Include a line `ls /does-not-exist` followed later by `echo unreachable`.
   - The trap must report the `ls` line's number, and `unreachable` must never print.
4. **Strict defaults**: `strict.sh`
   - Line 1 is `#!/usr/bin/env bash`, then `set -Eeuo pipefail` and `IFS=$'\n\t'`.
   - It prints `hello <first argument>`.
   - Called without an argument, it must fail rather than print `hello `.
5. **Fix prune-logs.sh**
   - The existing script deletes `old-*.log` files from `$LOGDIR`. Run without `LOGDIR`, it would
     delete in `/`.
   - Make it refuse to run when `LOGDIR` is unset, and keep it working when it is set.

Check your work from the host: `./lab check bash-traps-signals`

<details>
<summary>Hints</summary>

- `tmp=$(mktemp -d)`, `trap 'rm -rf "$tmp"' EXIT`, `exit "${1:-0}"`
- `on_int() { echo "caught SIGINT" >> /root/scripts/graceful.log; exit 130; }`, `trap on_int INT`,
  `while true; do sleep 1; done`
- `trap 'echo "error on line $LINENO" >&2' ERR`; `cat -n errtrap.sh` shows the line numbers
- `./strict.sh; echo $?` should print an error and a non-zero status
- `set -u` near the top, or `"${LOGDIR:?LOGDIR not set}"` in the `rm` line. Test it with
  `env -u LOGDIR ./prune-logs.sh`. Make a bait file first (`touch /old-test.log`) and see that it
  survives.

</details>

## My notes

<!-- Screenshots: ./lab shot bash-traps-signals ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [linux-server-setup](../linux-server-setup/): stdout, stderr and redirection
- [linux-101-capstone](../linux-101-capstone/): a first shell script and cron
- `help trap`, `help set`, `man 7 signal`, `man mktemp`
