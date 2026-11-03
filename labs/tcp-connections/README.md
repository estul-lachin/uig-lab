# tcp-connections

## Concepts

On a host I'm investigating, two questions come first: **what is listening** (open doors) and **who is
it talking to** (conversations in progress). A listener on an odd port can be a backdoor, and a
connection that never closes can be a beacon. This lab answers both with `ss`, and uses `ncat` to create
listeners and connections so I can watch them appear and disappear.

**ss** reads socket information straight from the kernel. It replaces the older `netstat`.

| Option | Meaning |
|---|---|
| `-t` / `-u` | TCP / UDP |
| `-l` | Listening sockets only (`-a` shows all) |
| `-n` | Numbers instead of service names (`:22`, not `:ssh`) |
| `-p` | The owning process, as `users:(("name",pid=123,fd=3))`. Other users' processes need root |
| `-H` | No header line, handy for counting with `wc -l` |

`ss -tlnp` is the one to remember. `0.0.0.0:22` or `*:22` listens on every interface; `127.0.0.1:5432`
only on the machine itself. Filters narrow the output: `state established` keeps only open
conversations, and `'( sport = :80 or dport = :80 )'` keeps one port.

**ncat** (netcat from the Nmap project) can be either end of a connection:
- `ncat -l -p PORT` listens once; `-k` keeps listening after the first client leaves.
- `ncat HOST PORT` connects; `--send-only` sends its input and closes, `--no-shutdown` stays connected
  after the input ends. On the listener, `--no-shutdown` stops it from hanging up when *its* input
  ends.

**Keeping a background program alive**: `./lab check` runs in a separate session, and a plain `cmd &`
dies with the shell that started it. `nohup` ignores the hang-up signal, `setsid` gives the program its
own session, `</dev/null >file 2>&1` cuts it off from the terminal, and `& disown` backgrounds it and
removes it from the job list:

```
nohup setsid ncat -lk -p PORT </dev/null >/dev/null 2>&1 & disown
```

**Loopback counts twice**: when the client and server are both on this host, `ss` lists both ends of the
connection (`127.0.0.1:9003 → 127.0.0.1:51234` and the reverse), so one connection shows as two
ESTABLISHED lines. Between two machines, each side sees only its own end.

**From a port to a program**: `ss -p` gives the PID, and `/proc/<pid>/exe` is a link to the program file
that is actually running, whatever name it shows.

## Tasks

Start the lab with `./lab up tcp-connections`, open a shell with `./lab shell tcp-connections`.
The shell is `root`. Start every listener and client in tasks 2–4 daemonised, as shown above, so it
is still running when you check.

1. **Listening sockets.** Save the listening TCP sockets, with port numbers and owning processes, to
   `/root/listen.txt`.
2. **A listener that survives.** Start an `ncat` listener on TCP `9001` that keeps accepting clients.
   Confirm it with `ss`.
3. **Send a line.** Start a one-shot listener on `9002` that writes what it receives to `/root/recv.txt`.
   Then send it the line `case 4471 opened` with `ncat --send-only`.
4. **Hold a connection open.** Start a hold-open listener on `9003` and connect a hold-open client to it.
   Write the number of ESTABLISHED connections involving port `9003` (just the number) to
   `/root/est_count.txt`.
5. **The odd listener.** Something else was already listening when the machine started. Write
   `/root/findings.txt`:

   ```
   ODD_PORT=<its port>
   ODD_PROCESS=<the process name ss shows>
   ODD_PATH=<the full path of the program that is actually running>
   ```

   Then stop it, leaving your own listeners running.

Check your work from the host: `./lab check tcp-connections`. `./lab reset tcp-connections` starts over,
with the odd listener back.

<details>
<summary>Hints</summary>

- `ss -tlnp`, `ss -tln | grep :9001`
- `echo "case 4471 opened" | ncat --send-only 127.0.0.1 9002`, then `cat /root/recv.txt`
- `ss -H -tn state established '( sport = :9003 or dport = :9003 )' | wc -l`
- `ss -tlnp 'sport = :31337'` shows `pid=`, then `ls -l /proc/<pid>/exe`
- `kill <pid>`; check again with `ss -tln`

</details>

## My notes

<!-- Screenshots: ./lab shot tcp-connections ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [linux-cli-intro](../linux-cli-intro/): pipes, `grep` and `wc -l`
- `man ss`, `man ncat`, `man nohup`, `man setsid`, `man 5 proc` (`/proc/<pid>/exe`)
