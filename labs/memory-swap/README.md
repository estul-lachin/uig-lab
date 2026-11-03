# memory-swap

## Concepts

"Out of memory" can mean a real leak, a misread number, or a container hitting a limit that `free`
doesn't even show. Reading memory correctly comes before deciding what to kill, and so does knowing that
a process's name can lie.

**free** (`-h` for readable units, `-m` for MiB):
- `total`, `used`, `free`, `buff/cache`.
- **available** is the kernel's *estimate* of how much a new program could use without swapping: free
  memory plus the cache that can be dropped. It's the number to watch; a small `free` with a large
  `available` is a healthy system using spare RAM for cache.
- `Swap:` shows the swap space; 0 just means there is none.

**/proc/meminfo** is the source of those numbers, in kB:
- `MemTotal`, `MemAvailable`.
- `Buffers` (block-device metadata) and `Cached` (file contents).
- `SwapTotal`, `SwapFree`.
- `Dirty`: data written but not on disk yet.

**Per process**: `RSS` is the resident memory actually in RAM, in KiB in `ps`. `VSZ` is everything the
process has mapped, much of it never touched. `ps -eo pid,comm,rss,args --sort=-rss` ranks processes.
`/proc/<pid>/status` has `VmRSS`, and `smaps_rollup` has `Pss`, which shares shared pages fairly.

**swappiness** (`vm.swappiness`, 0–200, default 60) says how willing the kernel is to swap out anonymous
memory rather than drop cache. It's a hint about preferences, not a threshold.

**Containers**: `free` and `/proc/meminfo` describe the **whole machine** (here, the Docker VM). A
container's real budget is its **cgroup**: in cgroup v2, `/sys/fs/cgroup/memory.max` (bytes, or `max`
for none) and `memory.current` (in use now). Above `memory.max`, the kernel's OOM killer picks a process
*inside the container*, even though `free` showed plenty.

**Names can lie**:
- A process chooses its own `argv[0]` (bash: `exec -a NAME`), which is what `ps args` shows. Brackets
  like `[kswapd0]` normally mark kernel threads.
- Real kernel threads have PPID 2 and no program file: `/proc/<pid>/exe` is empty. `comm` and
  `/proc/<pid>/exe` tell you what is really running.
- `/proc/<pid>/fd` shows which files it holds open, for example the script it is reading.

## Tasks

Start the lab with `./lab up memory-swap`, open a shell with `./lab shell memory-swap`. The shell is
`root`. Write `KEY=value` answers to `/root/answers.txt`.

1. **free.** Save `free -h` to `/root/free.txt`. What is the *available* column? Write `AVAILABLE_IS=estimate`
   once you've read about it.
2. **/proc/meminfo.** Save exactly the `MemTotal`, `MemAvailable` and `Buffers` lines to
   `/root/mem_highlights.txt`.
3. **Top memory consumers.** Save a header plus the top processes by RSS (at most 10) to
   `/root/topmem.txt`, largest first. The header must name the `RSS` column.
4. **Swappiness and swap.** Save the current swappiness to `/root/swappiness.txt`, and write
   `SWAP_TOTAL_MB=<the swap total in MiB, from free>`.
5. **The container's real limit.** Write `HOST_TOTAL_MB=<total memory as free -m shows it>` and
   `LIMIT_MB=<this container's memory limit in MiB>`. Which one would the OOM killer go by?
6. **The disguised process.** The biggest process in your list isn't what it looks like. Write:

   ```
   HOG_PID=<its PID>
   HOG_DISGUISE=<the name ps shows for it>
   HOG_PROGRAM=<the program file that is really running>
   HOG_SCRIPT=<the file it reads its commands from>
   HOG_RSS_MB=<its RSS in MiB>
   ```

   Then stop it, delete its script, and check that the container's memory usage dropped.

Check your work from the host: `./lab check memory-swap`

<details>
<summary>Hints</summary>

- `free -h`, `free -m`; `man free` explains *available*
- `grep -E '^(Name1|Name2):' /proc/meminfo`
- `ps -eo pid,comm,rss,args --sort=-rss | head -n 11`
- `cat /proc/sys/vm/swappiness`
- `cat /sys/fs/cgroup/memory.max /sys/fs/cgroup/memory.current`
- `ps -o pid,ppid,comm,args -p <pid>`, `readlink /proc/<pid>/exe`, `ls -l /proc/<pid>/fd`

</details>

## My notes

<!-- Screenshots: ./lab shot memory-swap ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [disk-io](../disk-io/): the same hunt for disk writes
- [sysctl-tuning](../sysctl-tuning/): vm.swappiness as a sysctl
- [tcp-connections](../tcp-connections/): `/proc/<pid>/exe` for a renamed listener
- `man free`, `man 5 proc` (meminfo, status), kernel docs `admin-guide/cgroup-v2.rst` (memory)
