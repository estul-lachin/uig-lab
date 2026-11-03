# linux-server-setup

## Concepts

A small online bookshop is about to put its order server on the internet, and I've been given the
freshly installed Ubuntu box to prepare. The job covers the basic first-day tasks on any new Linux
server: an SSH key, accounts for the teams, a private shared directory, a repeatable install script,
a script run with its errors logged, and a record of the hardware.

- **SSH keys** come in pairs. The private key stays with me (mode `600`, or ssh refuses to use it), and
  the public key (`.pub`) goes into `~/.ssh/authorized_keys` on every server I want to log in to.
- **Users and groups**: every user has exactly one *primary* group (the group of files they create) and
  any number of *supplementary* groups. `useradd` only creates the home directory with `-m`.
- **Permissions** for a shared directory: `770` gives the owner and the group full access and everyone
  else nothing. `x` on a directory means "may enter it", so without it `ls` and `cd` fail.
- **Scripted installs** must never stop for a prompt: `apt-get install -y` answers yes, and
  `apt-get clean` deletes the downloaded `.deb` files afterwards.
- **Redirection**: a process writes normal output to file descriptor 1 (stdout) and errors to 2
  (stderr). `2> file` sends only the errors to the file.
- **Inventory**: `lsblk` lists block devices and their mount points, `free -h` shows memory, `nproc`
  prints the number of CPU cores. Values depend on the host, so the check compares against the
  tools rather than a fixed number.

## Tasks

Start the lab with `./lab up linux-server-setup`, open a shell with `./lab shell linux-server-setup`.
The shell is `root`; a regular user `student` already exists.

1. **SSH key**: generate a keypair for `root` in the default location (`/root/.ssh/`). The private key
   must be readable by its owner only.
2. **Account for the audit team**: create user `nora` with primary group `auditors`, home directory
   `/home/nora` (it must exist) and login shell `/bin/bash`. The group doesn't exist yet.
3. **Private directory for accounting**: create user `hugo` and group `accounting`, and make `hugo` a
   member of it. Then create `/var/payroll`, owned by `hugo`, group `accounting`, mode `770`.
4. **Install script**: write `/root/banner-tools.sh` that refreshes the package lists, installs `figlet`
   and `lolcat` without asking for confirmation, and cleans the apt cache at the end. Make it
   executable and run it.
5. **Error log**: `/home/student/welcome.sh` has a bug. Run it so that only its error output ends up
   in `/home/student/welcome-errors.txt`; the normal output stays on the terminal.
6. **Server inventory**: write `/root/server-info.txt` with exactly these four lines, filled in from
   what the tools report on this machine:

   ```
   LARGEST_DISK=<SIZE of the biggest disk in lsblk, as printed, e.g. 926.3G>
   MOUNTPOINT=<any path from the MOUNTPOINTS column of lsblk>
   MEM_TOTAL=<the total of the Mem: row in free -h, e.g. 7.7Gi>
   CPU_CORES=<number of CPU cores>
   ```

   In a container lsblk shows the host VM's disks, and the mount points are usually files such as
   `/etc/hosts`. That's expected.

Check your work from the host: `./lab check linux-server-setup`

<details>
<summary>Hints</summary>

- `ssh-keygen` (press Enter at the prompts), `ls -l ~/.ssh`
- `groupadd`, `useradd -m -d ... -s ... -g ...`, `id <user>`, `getent passwd <user>`
- `usermod -aG <group> <user>` (without `-a` it replaces the user's supplementary groups),
  `chown user:group`, `chmod 770`, `ls -ld`
- A heredoc writes a multi-line file: `cat > file <<'EOF'` ... `EOF`; then `chmod +x`
- `./script.sh 2> errors.txt`, then `cat errors.txt`
- `lsblk`, `free -h`, `nproc`, `df -h`

</details>

## My notes

<!-- Screenshots: ./lab shot linux-server-setup ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [hello-world](../hello-world/): file content and octal permissions
- `man useradd`, `man chmod`, `man ssh-keygen`, `man bash` (section REDIRECTION), `man lsblk`
