# linux-file-editing

## Concepts

During an investigation I keep editing small files on the host itself: a config value, a case note,
a log excerpt where an indicator must be redacted, a quick triage record. That takes two editors and
a handful of ways to write files straight from the shell.

**nano** is modeless: I just type. The shortcut bar at the bottom shows `^` for Ctrl and `M-` for Alt.

| Keys | Action |
|---|---|
| Ctrl+O, Enter (or Ctrl+S) | Save |
| Ctrl+X | Exit (asks Y/N if there are unsaved changes) |
| Ctrl+W | Search; Ctrl+W, Enter repeats it |
| Ctrl+\ or Alt+R | Replace; answer `A` to replace all matches |
| Alt+U / Alt+E | Undo / redo |
| Ctrl+G | Help |

**vim** is modal, and it's installed even on minimal and rescue systems that have no nano.
- *Normal mode* (the start, and `Esc` from anywhere): keys are commands.
- *Insert mode* (`i`): keys are text.
- *Visual mode* (`v`): select text, then `d` to delete or `y` to copy.
- Commands typed after `:` in normal mode: `:w` save, `:q` quit, `:wq` both, `:q!` quit without saving.
  When stuck, `Esc` then `:q!` always gets me out.
- Search: `/text`, then `n` for the next match and `N` for the previous one.
- Replace: `:%s/old/new/g`, where `%` means every line and `g` every match on the line (without it only
  the first one per line changes). Add `c` to confirm each change. `old` is a regular expression, so
  `.` matches any character.

**cat**: `cat file` prints a file, `cat a b` prints them one after the other (redirect that to combine
them), `cat -n` numbers the lines. `cat > file` writes what I type until Ctrl+D; `cat >> file`
appends.

**Writing without an editor**:
- `>` overwrites a file (creating it if needed), `>>` appends.
- `echo "text"` adds a newline by itself. `printf` adds nothing I don't ask for: `\n` newline,
  `\t` tab, `%s` a placeholder for the next argument.
- `tee file` writes to the file *and* passes the text on to the screen; `tee -a` appends.

`cat -A` shows invisible characters: a tab is `^I` and a line end is `$`.

## Tasks

Start the lab with `./lab up linux-file-editing`, open a shell with `./lab shell linux-file-editing`.
The shell is `root` in `/root/work`, where all the files live. The check looks at the result, but
use the tool named in each task: that's the point of the lab.

1. **nano**
   - Create `nano-hello.txt` containing the single line `Hello from nano`.
   - In `app.conf`, replace every `staging` with `production` using nano's replace function. Nothing
     else in the file may change.
2. **vim**
   - Create `case-notes.txt` containing the single line `investigation started`.
   - In `proxy.log`, redact the attacker's address `203.0.113.50` by replacing every occurrence with
     `REDACTED` in one substitute command. The other address in the file stays.
3. **cat**
   - Create `cat-made.txt` with `cat >`: the line `written with cat`. Then append the line
     `appended with cat` with `cat >>`. Read it back with `cat -n`.
   - Combine `part1.log` and `part2.log` (in that order) into `timeline.log`.
4. **echo, printf, tee, >**
   - `greeting.txt`: write `Hello, World!` with `echo`, then append `Another line.`.
   - `users.tsv`: with one `printf`, write two lines, `user` TAB `nora` and `role` TAB `analyst`.
   - `seen.txt`: write `to both` with `tee` (watch it appear on screen), then append `next line` with
     `tee -a`.
   - `date.txt`: write the output of `date`, append a second timestamp, then overwrite the file again
     so it ends up with one line.
5. **Triage note**: write `triage.txt` whose first line is `== processes ==`, followed by the output
   of `ps aux`. Use `tee -a` so you see the list while it's saved.

Check your work from the host: `./lab check linux-file-editing`

<details>
<summary>Hints</summary>

- In nano, Ctrl+\ asks for the search text, then the replacement, then Y/N/A for each match
- In vim, `:%s/203.0.113.50/REDACTED/g`, then `:wq`. Check with `grep -c REDACTED proxy.log`
- `cat > file` waits for input; Ctrl+D on an empty line ends it
- `printf 'a\tb\n'`, then `cat -A users.tsv` to see the `^I`
- `cat -n`, `wc -l`, `head -n1`

</details>

## My notes

<!-- Screenshots: ./lab shot linux-file-editing ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

#### nano `⌃ + \` = Search and Replace

#### `vim` 
```bash
# Enter Insert mode
i
# Return to Normal mode
Esc
# Save
:w
# Quit
:q
# Save and quit
:wq
# Quit without saving
:q!
# Delete current line
dd
# Undo
u
# Replace all occurrences in the file
:%s/old/new/g
```

#### `cat`
```bash
# Display file contents
cat file.txt
# Create/overwrite a file
cat > file.txt
# Append to a file
cat >> file.txt
# Display with line numbers
cat -n file.txt
# Combine files into a new file
cat file1 file2 > file3
# Finish cat input
Ctrl + D
```
#### `echo` `printf`
```bash
# Write/overwrite
echo "Hello, World!" > a.txt

# Append
echo "Another line." >> a.txt

# Write two lines with TAB separation
printf "aaaaaaa\taaaaaaa\naaaaaaa\taaaaaaa\n" > a.tsv

# Write to file and display on screen
echo "aaaaaaa" | tee a.txt

# Append to file and display on screen
echo "bbbbbb" | tee -a seen.txt

# Write current date/time (overwrite)
date > a.txt

# Append another timestamp
date >> a.txt
```

## Related

- [linux-file-management](../linux-file-management/): creating, copying and searching files
- `man nano`, `vimtutor`, `man cat`, `man printf`, `man tee`
