# cpu-load

## Concepts

"The box is slow" needs numbers: is the CPU saturated, are processes waiting for the disk, is the
hypervisor stealing time, and which process is it? Unexplained CPU use on a server is also the classic
symptom of a cryptominer.

**Load average** (`uptime`, `/proc/loadavg`): three numbers, the average number of processes that are
running or waiting to run over 1, 5 and 15 minutes. Linux also counts processes in uninterruptible
sleep, usually waiting for disk, so a high load with idle CPUs points at I/O. A load is only "high"
compared to the number of CPUs available:
- `nproc` and `/proc/cpuinfo` show the CPUs the kernel has.
- A container can be limited to fewer by its **cgroup**: `/sys/fs/cgroup/cpu.max` holds
  `quota period` in microseconds, and quota ÷ period = CPUs (`max` means no limit).
- A container showing 8 CPUs but allowed 2 hits its limit (it gets *throttled*) at a load of about 2.

**vmstat 1 5** prints a line per second, five times. The first line is the average since boot.

| Column | Meaning |
|---|---|
| `r` | Runnable processes: the run queue. Persistently above the CPU count means CPU saturation |
| `b` | Blocked in uninterruptible sleep (usually disk) |
| `si`, `so` | Swap in / out; non-zero means memory pressure |
| `us sy id wa st` | Percent user, system, idle, waiting for I/O, and **stolen** by the hypervisor for other VMs |

**mpstat -P ALL 1 1** shows the same split per CPU. One CPU at 100% and the rest idle means a
single-threaded process.

**top**: `top -b -n 1` writes one snapshot as text, which you can save or grep. `-o %CPU` sorts by CPU.
In `top`, 100% means one full CPU, so a multi-threaded process can show 300%. `pidstat -u 1 5`
averages per process over time, which catches processes that come and go.

**Short-lived processes**: if the busy process has a new PID every time you look, something keeps
restarting it. Follow `PPID` to the parent (a loop, a supervisor, cron or systemd) and stop that first.
Miners often hide under names like `kdevtmpfsi` or `kworker...` and live in hidden directories.

## Tasks

Start the lab with `./lab up cpu-load`, open a shell with `./lab shell cpu-load`. The shell is `root`.
Write `KEY=value` answers to `/root/answers.txt`.

1. **Load average and the CPU budget.** Save the three load averages, space-separated, to
   `/root/load.txt`. Write `VISIBLE_CPUS=<what nproc reports>` and
   `CPU_LIMIT=<how many CPUs this container may really use>`.
2. **vmstat.** Save five one-second vmstat samples to `/root/vmstat.txt`. Write
   `VMSTAT_RUNQ_COLUMN=<the column for the run queue>` and
   `VMSTAT_STEAL_COLUMN=<the column for stolen time>`.
3. **Load you made yourself.** Start `yes > /dev/null` in the background, save one batch snapshot of
   `top` that shows it to `/root/top.txt`, then stop it again.
4. **mpstat per CPU.** Save one one-second `mpstat` report for all CPUs to `/root/mpstat.txt`.
5. **The miner.** Something keeps one CPU about half busy. Write:

   ```
   MINER_NAME=<the process name>
   MINER_PATH=<its program file>
   MINER_IS=<the standard program it is a renamed copy of>
   MINER_PARENT=<the program that keeps restarting it>
   ```

   Then stop it so it stays stopped, and delete both files.

Check your work from the host: `./lab check cpu-load`. While the miner runs it uses about half a core of
your Mac, so `./lab down cpu-load` when you take a break.

<details>
<summary>Hints</summary>

- `cat /proc/loadavg`, `uptime`; `nproc`; `cat /sys/fs/cgroup/cpu.max`
- `vmstat 1 5`, then read `man vmstat`
- `yes > /dev/null &`, `jobs`, `kill %1`; `top -b -n 1 -o %CPU | head -n 15`
- `mpstat -P ALL 1 1`
- `pidstat -u 1 5`, `ps -eo pid,ppid,pcpu,comm --sort=-pcpu | head`, `readlink /proc/<pid>/exe`;
  `ps -ef --forest` shows the whole chain, and there may be a helper between the loop and the miner;
  `cmp <file> /usr/bin/<name>`

</details>

## My notes

<!-- Screenshots: ./lab shot cpu-load ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [memory-swap](../memory-swap/) and [disk-io](../disk-io/): the same hunt for memory and disk
- `man uptime`, `man vmstat`, `man mpstat`, `man top`, `man pidstat`
