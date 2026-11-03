# bash-loops

## Concepts

Loops are where scripts meet real data, and real data is awkward: file names with spaces, directories
with nothing in them, lines that start with spaces or contain backslashes, a last line without a
newline. A loop that works on tidy test input and silently mangles real input is worse than no script.

**for over a glob**: `for f in *.log; do ...; done` loops over matching file names. The shell splits
nothing here, so `"with space.log"` arrives whole, as long as I write `"$f"` with quotes everywhere.
When *nothing* matches, the glob stays as the literal text `*.log`, and the loop runs once on a file
that doesn't exist. `shopt -s nullglob` makes an unmatched glob expand to nothing; the alternative is
`[ -e "$f" ] || continue`. `wc -l < "$f"` prints just the number, while `wc -l "$f"` adds the name.

**while read**: the safe way to process a file line by line is

```bash
while IFS= read -r line || [ -n "$line" ]; do
  printf '%s\n' "$line"
done < file
```

- `IFS=` keeps leading and trailing whitespace; by default `read` strips it.
- `-r` keeps backslashes; without it, `\t` turns into `t`.
- `read` returns failure when it hits the end of the file. On a last line without a newline it has
  still filled `$line`, so `|| [ -n "$line" ]` processes that line too.
- `< file` at the `done` feeds the whole loop. `cat file | while ...` would run the loop in a subshell,
  so variables set inside it would be lost afterwards.

**Counting loops**: `for i in {1..10}` works only with fixed numbers, because brace expansion happens
before variables are expanded, so `{1..$n}` stays as literal text. For a variable bound, use the
C-style loop `for (( i = 1; i <= n; i++ ))`. `$(( i * i ))` does the arithmetic. `break` leaves a loop
and `continue` skips to the next round.

**Process substitution**: `<(command)` runs the command and gives its output a file name such as
`/dev/fd/63`, so tools that want two *files* can compare two *commands* directly, without temp
files:

```bash
diff <(sort a.txt) <(sort b.txt)
comm -13 <(sort old) <(sort new)    # lines only in new
```

`comm` needs sorted input. `-1`, `-2` and `-3` hide the column "only in first", "only in second" and
"in both".

**For incident response**: comparing the system against a baseline snapshot works the same way for
accounts, listening ports, SUID files or cron jobs. New entries are where to look first.

## Tasks

Start the lab with `./lab up bash-loops`, open a shell with `./lab shell bash-loops`.
The shell is `root` in `/root/scripts`. Practice files are in `/root/data`. Make every script
executable. The check runs them on its own test files.

1. **Count lines per file** (`linecount.sh`): with a `for` loop over the `*.log` files *in the current
   directory*, print `name: N` for each, where N is its number of lines. File names with spaces must
   work. In a directory without `.log` files it prints nothing. Try it in `/root/data/logs`.
2. **Safe line-by-line read** (`numberlines.sh FILE`): with `while IFS= read -r`, print every line of
   FILE as `N: line`, numbered from 1. Leading spaces, backslashes, empty lines and a last line without
   a newline must all come through unchanged. Try it on `/root/data/sample.txt`.
3. **Numeric for loop** (`squares.sh [N]`): print the squares of 1 to N, one per line, with N
   defaulting to 10. So `squares.sh` prints 1 … 100 and `squares.sh 3` prints 1, 4, 9.
4. **Process substitution** (`new-accounts.sh`): `/root/data/baseline-users.txt` is a list of the
   account names taken when the server was set up. Print the accounts that exist now but aren't in
   the baseline, one per line, sorted. Use `<( )` instead of temp files. Then look at what you found:
   does anything about those accounts look suspicious?

Check your work from the host: `./lab check bash-loops`

<details>
<summary>Hints</summary>

- `shopt -s nullglob; for f in *.log; do echo "$f: $(wc -l < "$f")"; done`
- `cat -A /root/data/sample.txt` shows the leading spaces, and that the last line has no `$`
- `n=${1:-10}; for (( i = 1; i <= n; i++ )); do ...; done`
- `comm -13 <(sort /root/data/baseline-users.txt) <(cut -d: -f1 /etc/passwd | sort)`
- `getent passwd <name>` for each new account: where is its home, and what is its shell?

</details>

## My notes

<!-- Screenshots: ./lab shot bash-loops ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [bash-functions](../bash-functions/), [bash-traps-signals](../bash-traps-signals/)
- [linux-authentication](../linux-authentication/): what makes an account suspicious
- `help for`, `help while`, `help read`, `man comm`
