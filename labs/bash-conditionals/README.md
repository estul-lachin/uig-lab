# bash-conditionals

## Concepts

Most of a script's bugs live in its decisions: a test that's true for the wrong reason, a comparison
of text that should be numbers, input nobody expected. This lab builds a few small decision-making
scripts and tests each one with the awkward cases on purpose.

**if and exit status**: `if cmd; then ...; elif cmd; then ...; else ...; fi` branches on a command's
exit status, where 0 means true. `test`, `[ ]`, `[[ ]]` and `(( ))` are simply commands that exit 0 or 1.

**`[[ ]]` vs `[ ]`**: `[ ]` is the old POSIX `test` command, so unquoted variables in it get split and
globbed. `[[ ]]` is bash syntax: no word splitting inside it, plus `&&`, `||`, pattern matching with
`==` and regexes with `=~`. In bash scripts I use `[[ ]]` and still quote out of habit.

**File tests**:

| Test | True when |
|---|---|
| `-e` | The path exists (follows symlinks) |
| `-f` / `-d` | Regular file / directory (follows symlinks) |
| `-L` | It is a symlink itself, even a broken one |
| `-r` `-w` `-x` | Readable / writable / executable by me |
| `-s` | Exists and isn't empty |

Because `-e`, `-f` and `-d` look *through* a link, a broken symlink fails all three. To tell a link from
what it points to, test `-L` first.

**Numbers vs strings**: `-eq -ne -lt -le -gt -ge` compare integers. Inside `[[ ]]`, `<` and `>`
compare *text*, so `[[ 10 > 9 ]]` is false because "1" sorts before "9". `(( n > 0 ))` is arithmetic
and reads naturally. Validate input before doing maths: `[[ $n =~ ^-?[0-9]+$ ]]`.

**case** matches one value against glob patterns, top to bottom, and the first match wins:

```bash
case "${1,,}" in          # ${1,,} = $1 in lower case
  start|begin) ... ;;
  -h|--help)   usage; exit 0 ;;
  *)           usage >&2; exit 64 ;;   # catch-all
esac
```

Asked-for help goes to stdout with status 0. A usage *error* goes to stderr with a non-zero status;
`64` is the conventional "bad usage" code (EX_USAGE).

**Regex with `=~`**: `[[ $s =~ ^([0-9]{1,3})\.([0-9]{1,3})$ ]]` uses extended regular expressions.
`^` and `$` anchor the match; without them it also matches *inside* longer text. The pattern must not be
quoted, or it's treated as plain text. Captured groups land in `BASH_REMATCH[1]`, `[2]`, and so on.
A regex checks *shape*, not meaning: `999.1.1.1` has the right shape, so the range check is separate.
`10#$part` stops bash from reading `08` as an invalid octal number.

**Address ranges** (RFC 1918): `10.0.0.0/8`, `172.16.0.0/12` (172.16 to 172.31) and `192.168.0.0/16` are
private. `127.0.0.0/8` is loopback. Classifying an address quickly is a constant task in alert triage.

## Tasks

Start the lab with `./lab up bash-conditionals`, open a shell with `./lab shell bash-conditionals`.
The shell is `root` in `/root/scripts`. Make every script executable. The check runs them with its own
arguments.

1. **File tests** (`pathtype.sh PATH`): print `symlink`, `directory`, `file` or `missing`, and exit 1 for
   `missing`. A symlink is reported as `symlink`, even if it's broken. Paths with spaces must work.
2. **Numeric comparison** (`sign.sh N`): print `positive`, `zero` or `negative`. If N is missing or isn't
   an integer (e.g. `abc`, `1.5`), print a message to stderr, nothing to stdout, and exit 2.
3. **Case dispatch** (`svc.sh ACTION`):
   - `start`, `stop` and `restart` print `starting`, `stopping` and `restarting`, in any capitalisation.
   - `-h` and `--help` print a usage line containing `usage` to stdout and exit 0.
   - Anything else, or no argument, prints the usage to stderr and exits 64.
4. **Regex test** (`is-ipv4.sh STRING`): exit 0 if STRING is a valid dotted IPv4 address and 1 otherwise.
   Use `[[ =~ ]]` for the shape, then reject octets above 255.
5. **Classify an address** (`ipclass.sh IP`): print `loopback`, `private` or `public`. If `is-ipv4.sh`
   rejects the address, print `invalid` and exit 1. Use `case` for the ranges, and mind the edges of
   `172.16.0.0/12`.

Check your work from the host: `./lab check bash-conditionals`

<details>
<summary>Hints</summary>

- Make test cases: `mkdir 'a dir'; touch 'a file'; ln -s 'a file' link; ln -s /nowhere broken`
- `[[ $1 =~ ^-?[0-9]+$ ]] || { echo "not an integer" >&2; exit 2; }`
- `case "${1,,}" in ... esac`; then `./svc.sh reload; echo $?`
- `^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$`, then
  `for p in "${BASH_REMATCH[@]:1}"; do (( 10#$p <= 255 )) || exit 1; done`
- `172.1[6-9].*|172.2[0-9].*|172.3[01].*` covers 172.16 to 172.31

</details>

## My notes

<!-- Screenshots: ./lab shot bash-conditionals ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [bash-loops](../bash-loops/), [bash-functions](../bash-functions/), [bash-traps-signals](../bash-traps-signals/)
- [ip-interfaces](../ip-interfaces/): addresses and prefixes
- `help test`, `help [[`, `help case`, RFC 1918
