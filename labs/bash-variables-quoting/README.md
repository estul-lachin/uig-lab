# bash-variables-quoting

## Concepts

Most shell bugs aren't logic errors. They come from the shell doing something to a value before the
command ever sees it. After expanding an *unquoted* variable, the shell splits it into words and
expands glob characters in it. So `"a  b"` loses a space, `*` turns into the files in the current
directory, and an empty argument disappears. Quoting stops all of that.

**Quoting rules**:
- `"$var"` (double quotes) expands the variable but keeps it as **one word**, exactly as it is.
  Quote every expansion unless you want splitting.
- `'text'` (single quotes) means no expansion at all: `'$HOME'` is five characters.
- `$var` unquoted gets split on spaces, tabs and newlines, and each part is globbed.

**Arguments**:
- `$1`, `$2`, … are the positional parameters, and `$#` is how many there are.
- `"$@"` expands to every argument as its own word, empty ones included, which is what a wrapper needs
  to pass its arguments on unchanged.
- `"$*"` joins them into one string. Unquoted `$@` and `$*` both re-split everything.
- `exec cmd "$@"` replaces the wrapper with the command, so the command's exit status is the wrapper's.

**Parameter expansion** cuts strings without starting `basename`, `sed` or `tr`:

| Expansion | Result for `p=/var/log/nginx/access.log.gz` |
|---|---|
| `${p##*/}` | `access.log.gz`: remove the longest match of `*/` from the front |
| `${p%/*}` | `/var/log/nginx`: remove the shortest match of `/*` from the back |
| `${f##*.}`, `${f%.*}` | `gz` and `access.log` (with `f=access.log.gz`) |
| `${f^^}`, `${f,,}` | Upper case / lower case |
| `${#p}` | The length: 26 |
| `${p//log/LOG}` | Replace every `log`. One slash replaces only the first |

`#` and `%` cut from the front and the back; doubling them (`##`, `%%`) makes the match greedy. The
patterns are globs, so a *variable* used as a pattern should be quoted (`${line//"$secret"/x}`), or a `*`
in its value matches anything.

**Defaults and required values**:

| Expansion | Meaning |
|---|---|
| `${VAR:-default}` | Use `default` if VAR is unset *or empty* |
| `${VAR-default}` | Use `default` only if VAR is unset |
| `${VAR:=default}` | Same as `:-`, and also assign it |
| `${VAR:?message}` | If unset or empty, print the message to stderr and exit |

`: "${API_HOST:?must be set}"` at the top of a script checks a setting before anything happens. `:`
is a command that does nothing, so only the expansion's check runs.

**For incident response**: tools that print config or log lines should mask secrets before they reach
a ticket or a screen share.

## Tasks

Start the lab with `./lab up bash-variables-quoting`, open a shell with
`./lab shell bash-variables-quoting`. The shell is `root` in `/root/scripts`, where a couple of files
exist so you can watch `*` expand. Make every script executable. The check runs them.

1. **welcome.sh NAME**: uses `set -euo pipefail` and prints `Welcome, NAME!` with NAME exactly as
   given, so `"a  b"` keeps both spaces and `*` stays `*`. Without an argument it fails.
2. **Passing arguments on**:
   - `args.sh` prints how many arguments it got and each one in brackets: `args.sh "a b" c` prints
     `2 args: [a b] [c]`, and without arguments it prints `0 args:`.
   - `forward.sh` runs `args.sh` with exactly its own arguments, so
     `forward.sh "x  y" "" "*"` prints `3 args: [x  y] [] [*]`.
3. **Parameter expansion** (`pathparts.sh PATH`): print five lines, using only `${...}` and no external
   commands. For `/var/log/nginx/access.log.gz`:

   ```
   dir=/var/log/nginx
   file=access.log.gz
   ext=gz
   stem=access.log
   upper=ACCESS.LOG.GZ
   ```

4. **Defaults and required values** (`settings.sh`): print `LOGDIR=…`, `LEVEL=…` and `API_HOST=…` from
   the environment.
   - `LOGDIR` defaults to `/var/log/app`, and `LEVEL` defaults to `info`, even when it's set but empty.
   - `API_HOST` is required. Without it, the script prints an error mentioning `API_HOST` to stderr,
     prints nothing else, and exits non-zero.
5. **Masking secrets** (`mask.sh LINE SECRET`): print LINE with every occurrence of SECRET replaced
   by as many `*` as SECRET has characters. `mask.sh "key=s3cr3t retry key=s3cr3t" s3cr3t` prints
   `key=****** retry key=******`. A secret containing `*` must still be matched literally.

Check your work from the host: `./lab check bash-variables-quoting`

<details>
<summary>Hints</summary>

- Compare `echo $1` and `echo "$1"` with the argument `"*"`
- `printf ' [%s]' "$@"` repeats the format for every argument; print the count first, the newline last
- forward.sh: one line that `exec`s args.sh (found next to `$0`) with all of its own arguments
- `file=${p##*/}`, `${p%/*}`, `${file##*.}`, `${file%.*}`, `${file^^}`
- Test defaults with `env -u LEVEL ./settings.sh` and `LEVEL= ./settings.sh`
- `printf -v var '%*s' N ''` puts N spaces into `var`; then replace each space with `*`

</details>

## My notes

<!-- Screenshots: ./lab shot bash-variables-quoting ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [bash-conditionals](../bash-conditionals/), [bash-loops](../bash-loops/), [bash-functions](../bash-functions/),
  [bash-traps-signals](../bash-traps-signals/)
- `man bash`, sections QUOTING and Parameter Expansion
