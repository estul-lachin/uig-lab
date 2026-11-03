# ransomware-drill

## Concepts

Prevention reduces the chance of ransomware; **resilience** decides how bad the day is when it gets
through anyway. This lab is a drill on a small file server, `fs-01`:
1. Prepare a backup the attacker can't destroy.
2. Set off a simulated encryptor.
3. Detect, contain, recover, and learn what was lost.

The encryptor is part of the lab. It only touches `/srv/share`, `/backup` and one log, and nothing leaves
the container.

**Backups that survive ransomware: 3-2-1-1-0**:
- **3** copies of the data
- on **2** different media
- **1** off-site
- **1** offline or **immutable**
- **0** errors when the restore is verified

Attackers look for backups first, because a backup they can delete is no backup. Here `/backup` is a
separate Docker volume (the "other medium"), and immutability comes from the filesystem:
- `chattr +i FILE` makes a file unchangeable and undeletable, even by root, until `chattr -i` removes
  the flag. `lsattr` shows it as `i`.
- It needs the `CAP_LINUX_IMMUTABLE` capability, which this container has. An attacker with full root
  could remove the flag too. Real immutability lives outside the reach of the server: object lock,
  WORM storage, an offline disk.

**Verify, don't hope**: `sha256sum` over every file gives a manifest. `sha256sum -c MANIFEST` then
reports any file that differs, and `--quiet` shows only failures. A restore isn't done until the
manifest says so.

**RPO and RTO**:
- The *recovery point objective* is how much data you may lose: everything changed since the last good
  backup.
- The *recovery time objective* is how long the restore may take.
- A drill turns both from guesses into numbers.

**Signs of ransomware**:
- Many files rewritten or renamed in a short time, often to a new extension.
- Notes with contact details.
- Deleted backups and wiped logs.
- A process still running that keeps doing it.

**Response order**: **contain first**. Stop the process, remove its persistence, isolate the host. Only
then restore, because restoring while the encryptor still runs gives it fresh files. Then verify, then
reset credentials and look for how it got in. Paying doesn't guarantee a key, and doesn't stop stolen data
from being published.

## Tasks

Start the lab with `./lab up ransomware-drill`, open a shell with `./lab shell ransomware-drill`. The
shell is `root`. The share is `/srv/share` (120 files), and backups live in `/backup`. Write
`KEY=value` answers to `/root/answers.txt`. Only put the immutable flag on files in `/backup`.

1. **An immutable, verifiable backup.** Before anything happens:
   - Archive `/srv/share` to `/backup/immutable/share.tar.gz`, as `share/...` inside the archive.
   - Write a SHA-256 manifest of all its files to `/backup/immutable/share.sha256`, with paths
     relative to `/srv/share` (`./finance/...`).
   - Make both immutable.
2. **The drill.** Run `/opt/drill/start-incident.sh`.
3. **Detection.** Write:

   ```
   ENCRYPTED_COUNT=<how many files were encrypted>
   RANSOM_NOTE=<the note's file name>
   NOTE_CONTACT=<the e-mail address in it>
   DELETED_BACKUP=<the backup that was destroyed>
   WIPED_LOG=<the log that was emptied>
   ```

4. **Containment.** Write `ENCRYPTOR_PROCESS=<the name it runs under>` and
   `ENCRYPTOR_FILE=<the file it was started from>`. Then stop it and delete that file.
5. **Recovery.** Restore the share from your immutable backup. Remove the encrypted files and notes. All
   120 files must pass your manifest, and stay that way.
6. **The recovery point.** Write `LOST_FILE=<the share file that the backup could not bring back>`.

Check your work from the host: `./lab check ransomware-drill`. `./lab reset ransomware-drill` starts the
drill over; it unlocks the immutable files first.

<details>
<summary>Hints</summary>

- `tar -C /srv -czf ... share`; `cd /srv/share && find . -type f -exec sha256sum {} + > ...`
- `chattr +i <file>`, `lsattr <file>`
- `find /srv/share -name '*.lmn' | wc -l`, `ls -la /backup/*`, `find /var/log -type f -size 0`
- `ps -eo pid,args`, `cat /opt/drill/start-incident.sh`
- `tar -C /srv -xzf ...`, `cd /srv/share && sha256sum -c --quiet <manifest>`
- `comm` or `diff` between `find /srv/share -type f` and the manifest's file list

</details>

## My notes

<!-- Screenshots: ./lab shot ransomware-drill ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [backups-rsync-cron](../backups-rsync-cron/): everyday backups and a restore drill
- [ransomware-qr-phishing](../ransomware-qr-phishing/): how an intrusion like this begins
- [cpu-load](../cpu-load/), [disk-io](../disk-io/): finding a process by what it does
- `man chattr`, `man sha256sum`; CISA *#StopRansomware Guide*
