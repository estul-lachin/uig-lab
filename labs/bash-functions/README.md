# bash-functions

## Concepts

Once I have more than one script, the same helpers keep coming back: add up numbers, check that I'm
root, run a command and report how it went. A small **function library** that every script sources
keeps them in one place. That only works if the functions behave: no surprise output, no leaking
variables, no killing the caller.

**Defining and calling**: `name() { ...; }`, called like any command: `total 1 2 3`. Inside, the
arguments are `$1`, `$2`, …, all of them are `"$@"` (always quoted, so each argument stays whole), and
`$#` is how many there are.

**Two ways to give something back**:
- *Output*: `echo` the result, and the caller captures it with `$(total 1 2)`.
- *Status*: `return N` (0–255, where 0 means success). It goes into `$?` and works directly in `if` and
  `&&`. A function without `return` returns the status of its last command, so
  `is_root() { [[ $EUID -eq 0 ]]; }` is complete.

**return, not exit**: in a sourced library, `exit` doesn't leave the function; it ends the whole shell
or script that sourced it. Errors go to stderr (`echo "msg" >&2`) so they don't mix with the
function's output.

**local**: variables in bash are global unless declared `local` inside the function. Without it, a
helper's `sum` or loop variable silently overwrites the caller's variable with the same name.

**Sourcing**: `source file` (or `. file`) runs the file *in the current shell*, so its functions become
available. A library should only define things: no output, no work at load time. `./toolkit.sh` is
relative to the current directory, not to the script, so a script that sources it breaks when run from
elsewhere. Build the path from the script's own location: `"$(dirname "${BASH_SOURCE[0]}")/toolkit.sh"`.

**$? is fragile**: it holds the status of the *last* command, so even an `echo` replaces it. Save it
right away (`rc=$?`) and pass it on with `exit "$rc"`. Wrapper scripts (cron jobs, CI steps,
monitoring) depend on that: a wrapper that always exits 0 hides every failure.

**Arithmetic**: `$(( a + b ))` works on integers. `[[ $n =~ ^-?[0-9]+$ ]]` checks that a string is one.

## Tasks

Start the lab with `./lab up bash-functions`, open a shell with `./lab shell bash-functions`.
The shell is `root` in `/root/scripts`. A regular user `operator2` exists for testing.

1. **total().** Create the library `/root/scripts/toolkit.sh` with a function `total` that prints the
   sum of all its integer arguments.
   - `total 1 2 3 4` prints `10`, `total` prints `0`, and negative numbers work.
   - For a non-integer argument it prints an error to stderr, prints no total, and returns `2`.
2. **is_root().** Add `is_root` to the library. It returns `0` when run as root and `1` otherwise.
   Calling it as a normal user must not end that user's shell.
3. **A well-behaved library.** Sourcing `toolkit.sh` prints nothing, and calling its functions leaves no
   new variables behind in the caller's shell.
4. **report.sh.** Create an executable `/root/scripts/report.sh` that sources the library and prints
   `total of 1 2 3 4 = 10`, using `total` for the number. It must work from any directory, e.g.
   `cd / && /root/scripts/report.sh`.
5. **relay.sh.** Create an executable `/root/scripts/relay.sh` that runs the command given as its
   arguments.
   - Let the command's own output through unchanged.
   - Print `command exited with <N>` to stderr.
   - Exit with that same code: `relay.sh false` exits 1, `relay.sh sh -c "exit 7"` exits 7,
     `relay.sh true` exits 0.

Check your work from the host: `./lab check bash-functions`

<details>
<summary>Hints</summary>

- `total() { local sum=0 n; for n in "$@"; do ...; done; echo "$sum"; }`
- Test in a fresh shell: `bash -c 'source /root/scripts/toolkit.sh; total 1 x; echo "rc=$?"'`
- As the normal user: `su operator2 -c 'source /root/scripts/toolkit.sh; is_root; echo $?'`
- Spot leaks: run `compgen -v > /tmp/before`, call your functions, run `compgen -v > /tmp/after`, then
  `comm -13 /tmp/before /tmp/after`
- `source "$(dirname "${BASH_SOURCE[0]}")/toolkit.sh"`
- `"$@"; rc=$?; echo "command exited with $rc" >&2; exit "$rc"`

</details>

## My notes

<!-- Screenshots: ./lab shot bash-functions ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [bash-traps-signals](../bash-traps-signals/): strict mode, traps and exit codes
- `help function`, `help return`, `help local`, `help source`
