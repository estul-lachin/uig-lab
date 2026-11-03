# disk-io

## Concepts

"The server is slow" often means "the disk is busy". The questions are which device is busy, how busy
it is, and who is causing it. Linux keeps per-device counters in `/proc/diskstats` and per-process
counters in `/proc/<pid>/io`. `iostat` and `pidstat` (from the `sysstat` package) turn them into rates.
In a container, the devices you see are those of the Docker VM, so names and numbers differ from
machine to machine; read your own.

**iostat**: `iostat -xz 1 3` prints extended statistics (`-x`) for devices with activity (`-z`), every
second, three times. The **first report covers the time since boot**; the later ones cover each
interval, so with `-z` an idle interval can list no devices at all. Columns worth knowing:

| Column | Meaning |
|---|---|
| `r/s`, `w/s` | Reads and writes per second |
| `rkB/s`, `wkB/s` | Throughput |
| `r_await`, `w_await` | Average time per request in ms, queueing included; the latency users feel |
| `aqu-sz` | Average queue length |
| `%util` | Share of time the device had requests in flight. On SSDs and virtual disks that serve many requests at once, 100% doesn't mean "full" |

`avg-cpu: %iowait` is CPU time spent idle while waiting for I/O.

**/proc/diskstats** has one line per device and partition: `major minor name` followed by counters.
Field 4 is reads completed, **field 10 is sectors written** (always 512 bytes, whatever the hardware),
and field 13 is milliseconds spent doing I/O. The counters only grow, so take a snapshot before and
after, then subtract.

**dd** copies blocks: `dd if=/dev/zero of=FILE bs=1M count=200` writes 200 MiB. Without `conv=fsync`
much of it may still sit in the page cache when dd says it's done; with it, dd waits until the data is
on disk. dd prints its summary (bytes, seconds, rate) on **stderr**.

**Per process**: `pidstat -d 1 5` shows `kB_rd/s` and `kB_wr/s` per process. `/proc/<pid>/io` has the raw
`read_bytes` and `write_bytes`. `ls -l /proc/<pid>/fd` shows which files a process has open (`lsof -p`
does the same, when installed).

**Stopping something for good**: a process that comes back after `kill` usually has a **parent** that
restarts it: a loop, a supervisor, systemd, cron. Find it with `ps -o ppid= -p PID`, then deal with the
parent first.

## Tasks

Start the lab with `./lab up disk-io`, open a shell with `./lab shell disk-io`. The shell is `root`.
Write `KEY=value` answers to `/root/answers.txt`.

1. **iostat baseline.** Save three one-second extended iostat reports, active devices only, to
   `/root/iostat.txt`.
2. **Write load.**
   - Write 200 MiB of zeros to `/tmp/io.bin` with dd, in 1 MiB blocks, forcing the data to disk at the
     end.
   - Save dd's summary to `/root/dd.txt`, and write `DD_SECONDS=<the seconds dd reported>`.
3. **Disk counters around the load.**
   - Copy `/proc/diskstats` to `/root/diskstats.before` right before the dd in task 2, and to
     `/root/diskstats.after` right after it. (Redo task 2 if you need to.)
   - Write `DISK=<the device that took the write>` and `WRITTEN_MB=<how many MiB it wrote between the two
     snapshots>`, rounded down.
4. **Busiest device.** Write the device with the highest `%util` anywhere in your `iostat.txt` to
   `/root/busy.txt`.
5. **The hidden writer.** Something on this machine keeps writing to disk.
   - Write `WRITER_NAME=<the process>`, `WRITER_FILE=<the file it writes>` and
     `WRITER_PARENT=<the program that keeps restarting it>`.
   - Then stop it so it stays stopped, and delete its file and both programs.

Check your work from the host: `./lab check disk-io`. The check recomputes your numbers from your own
files.

<details>
<summary>Hints</summary>

- `iostat -xz <interval> <count>`; look at the `%util` column of every device line
- `dd ... conv=fsync 2> /root/dd.txt`
- `awk '{print $3, $10}' /proc/diskstats` shows device names and sectors written
- `diff` the two snapshots, or `awk 'NR == FNR {...; next} {...}' before after` to subtract
- `pidstat -d 1 5`, `cat /proc/<pid>/io`, `ls -l /proc/<pid>/fd`
- `ps -o pid,ppid,args -e`; kill the parent, then the child

</details>

## My notes

<!-- Screenshots: ./lab shot disk-io ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [tcp-connections](../tcp-connections/): `/proc/<pid>` and tracking a process to its program
- [linux-server-setup](../linux-server-setup/): lsblk and the disks themselves
- `man iostat`, `man pidstat`, `man dd`, kernel docs `Documentation/admin-guide/iostats.rst`
