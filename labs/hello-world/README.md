# hello-world

## Concepts

Every lab in this repo works the same way: a container is the practice machine, the tasks say *what*
the end state should be, and `./lab check` inspects the container to see whether I got there. This
lab is the smallest possible example: one file, exact content, exact permissions.

- File content can be written from the shell with redirection (`>` overwrites, `>>` appends).
- Unix permissions are three groups (owner, group, others) of read/write/execute bits, often written
  in octal: `644` means owner `rw-`, group `r--`, others `r--`.

## Tasks

Start the lab with `./lab up hello-world`, open a shell with `./lab shell hello-world`.

1. Write the single line `Hello, World!` to `/root/hello.txt`.
2. Set its permissions to `644`.

Check your work from the host: `./lab check hello-world`

<details>
<summary>Hints</summary>

- `echo` writes a line; redirect it into the file.
- `chmod` changes permissions; octal mode works.
- `stat -c %a <file>` shows the octal mode, `cat -A <file>` shows hidden characters.

</details>

## My notes

### 1. Create and Write Files

```bash
touch hello.txt
echo "Hello, World!" > hello.txt
```

### 2. Check File Permissions

```bash
ls -l hello.txt
stat -c "%a %n" hello.txt
```

### 3. Change File Permissions

```bash
chmod 644 hello.txt
```

**Remember:**
- `ls -l` → Check permissions.
- `chmod` → Change permissions.
- `>` → Overwrite.
- `>>` → Append.

## Related

- `man chmod`, `man stat`
