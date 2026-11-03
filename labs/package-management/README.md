# package-management

## Concepts

Outdated or tampered packages are one of the easiest ways into a Linux host, and the package database
is one of the cheapest things to audit. It knows every file a package installed, with its checksum.
On Debian and Ubuntu, **apt** works with repositories (download, dependencies, upgrades) and **dpkg**
works with the packages installed on this machine.

**apt, the everyday verbs**:
- `apt update` refreshes the package lists. Always run it first, or you work from stale metadata.
- `apt install PKG`, `apt upgrade`, and `apt full-upgrade` (which may also add or remove packages).
- `apt remove` keeps the config files, while `apt purge` deletes them too. `apt autoremove` removes
  dependencies nothing needs any more.
- `apt install --reinstall PKG` puts every file of the package back as shipped.
- `apt search`, `apt show PKG`, `apt list --installed`, `apt list --upgradable`.
- In scripts, `apt-get` is the stable interface. `-y` answers yes, and `DEBIAN_FRONTEND=noninteractive`
  suppresses configuration prompts.

**dpkg, the local database**:

| Command | Answers |
|---|---|
| `dpkg -l [pattern]` | Which packages are installed (one line each) |
| `dpkg -s PKG` | The full status record: version, `Depends:`, size, description |
| `dpkg -L PKG` | Every file the package installed |
| `dpkg -S /path` | Which package installed this file |
| `dpkg -V [PKG]` | Which installed files differ from what the package shipped |

**Holding**: `apt-mark hold PKG` keeps a package at its current version during upgrades.
`apt-mark showhold` lists held packages, and `apt-mark unhold` releases one. A hold can be a deliberate
choice, or a sign that someone wanted a vulnerable version to stay.

**Where packages come from**: `/etc/apt/sources.list`, the old one-line format, and every file in
`/etc/apt/sources.list.d/`. Files there end in `.list` (one line per repository) or `.sources` (the
newer multi-line *deb822* format, with `Types:`, `URIs:`, `Suites:` and so on). Ubuntu 24.04 keeps
its own sources in `ubuntu.sources` and leaves only a comment in `sources.list`, so a backup that only
copies `sources.list` is empty. `apt-cache policy` shows every repository apt actually uses.

**For incident response**:
- **Rogue repositories** are a persistence trick: once root, an attacker adds a source, and every later
  upgrade can pull their packages. `[trusted=yes]` turns off signature checks for that source, which a
  legitimate repository never needs.
- **dpkg -V** prints one line per file that differs. Each character in the first column is one test, and
  `5` in the third position means the **checksum** changed: the file isn't what the package installed.
  Minimal container images delete docs and man pages, so expect many `missing` lines to filter out.
- A binary that `dpkg -S` doesn't know at all was never installed by a package.

## Tasks

Start the lab with `./lab up package-management`, open a shell with `./lab shell package-management`.
The shell is `root`. Tasks 1 and 7 download from Ubuntu's mirrors. Write `KEY=value` answers to
`/root/answers.txt`.

1. **Install** `jq` with apt. Read the output of `apt update` carefully: does every repository answer?
2. **Inspect.** Save `jq`'s full dpkg status record to `/root/jq.pkg.txt`, and write
   `JQ_DEPENDS=<its Depends: line>`.
3. **Files.** Save the list of files jq installed to `/root/jq.files.txt`, and write
   `JQ_OWNER_OF_BINARY=<the package that owns /usr/bin/jq>`.
4. **Hold** jq at its current version, and save the list of held packages to `/root/holds.txt`.
5. **Sources snapshot.** Write every APT source file to `/root/sources.backup`: the legacy file and the
   drop-ins in both formats.
6. **Rogue repository.** One configured repository isn't Ubuntu's. Write `ROGUE_REPO_FILE=<its file>`
   and `ROGUE_REPO_RISK=<the option on its line that disables signature checks>`, then remove it.
7. **Tampered binary.** One program in `/usr/bin` no longer matches its package. Write
   `TAMPERED_FILE=<its path>` and `TAMPERED_PACKAGE=<the package it belongs to>`, then restore the
   original from the package.

Check your work from the host: `./lab check package-management`

<details>
<summary>Hints</summary>

- `apt update`; a source that times out shows up as `Err:` or `W: Failed to fetch`
- `dpkg -s jq`, `dpkg -s jq | grep ^Depends`, `dpkg -L jq`, `dpkg -S /usr/bin/jq`
- `apt-mark hold`, `apt-mark showhold`
- `ls /etc/apt/sources.list.d/`; `cat` accepts several files and globs, and `2>/dev/null` hides
  "no such file"
- `apt-cache policy`, `grep -r . /etc/apt/sources.list.d/`
- `dpkg -V 2>/dev/null | grep -v missing`, then `dpkg -S <file>` and `apt install --reinstall <package>`;
  run `dpkg -V <package>` again to confirm

</details>

## My notes

<!-- Screenshots: ./lab shot package-management ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [special-permission-bits](../special-permission-bits/): `dpkg -S` against unpackaged SUID files
- [linux-server-setup](../linux-server-setup/): a first apt install script
- `man apt`, `man dpkg` (`--verify`), `man apt-mark`, `man 5 sources.list`
