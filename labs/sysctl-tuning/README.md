# sysctl-tuning

## Concepts

The kernel has hundreds of runtime switches: how eagerly it swaps, whether it routes packets between
interfaces, whether it trusts ICMP redirects. Some are performance knobs; many are security settings
that every hardening benchmark checks. They live in `/proc/sys`, and `sysctl` reads and sets them.

**Reading**: `sysctl NAME` prints `name = value`, `sysctl -n NAME` prints just the value, and `sysctl -a`
prints everything. Every name is a file: dots become slashes, so `vm.swappiness` is
`/proc/sys/vm/swappiness`.

**Changing at runtime**: `sysctl -w name=value`, or write to the file. The change takes effect at once
and is gone after a reboot.

**Making it permanent**: put `name = value` lines in a file in **/etc/sysctl.d/** ending in `.conf`. At
boot, `systemd-sysctl` (or `sysctl --system` by hand) applies them:
- All files from `/etc/sysctl.d`, `/run/sysctl.d` and `/usr/lib/sysctl.d` are sorted by **file name**.
  If the same name exists in several directories, the one in `/etc` wins.
- They're applied in that order, and then `/etc/sysctl.conf`.
- **The last assignment of a key wins.** So a file called `99-zz-something.conf` silently overrides
  your `90-hardening.conf`.
- `sysctl -p FILE` applies one file and reports each key. Errors go to stderr: "cannot stat" means the
  key doesn't exist (a typo); "Read-only file system" or "permission denied" means you're not allowed
  to change it.

**Common hardening values** (CIS benchmarks and the like):

| Setting | Hardened | Why |
|---|---|---|
| `net.ipv4.ip_forward` | `0` | A server that isn't a router shouldn't forward packets between networks |
| `net.ipv4.conf.all.accept_redirects` | `0` | ICMP redirects let a neighbour reroute your traffic through itself |
| `net.ipv4.conf.all.send_redirects` | `0` | Only routers send them |
| `net.ipv4.conf.all.rp_filter` | `1` | Drop packets whose source address couldn't have come from that interface (spoofing) |
| `net.ipv4.tcp_syncookies` | `1` | Keep accepting connections during a SYN flood |

**Containers**: most `net.*` settings belong to a *network namespace*, so every container has its own,
and Docker can set them when it starts one (`sysctls:` in compose). Settings like `vm.swappiness` are
global to the machine. A container that could change them would change the shared kernel, so
`/proc/sys` is mounted read-only and `sysctl -w` is refused. That's why this lab audits and writes the
configuration, while the runtime change can only be tried. To practise live changes, use a real VM.

**For incident response**: `ip_forward = 1` on a machine that isn't a router, or `accept_redirects = 1`,
is how an attacker turns a compromised host into a pivot or a man-in-the-middle. Check both the live
values and what the configuration will apply at the next boot.

## Tasks

Start the lab with `./lab up sysctl-tuning`, open a shell with `./lab shell sysctl-tuning`. The shell is
`root`. Write `KEY=value` answers to `/root/answers.txt`.

1. **Reading parameters.** Save `vm.swappiness` as sysctl prints it (`name = value`) to `/root/swap.txt`,
   and write `SWAPPINESS_PATH=<the file under /proc/sys behind it>`.
2. **Auditing the live network settings.** Write `IP_FORWARD_NOW=<the current value>` and
   `UNSAFE_NOW=<the live settings among ip_forward, conf.all.accept_redirects and conf.all.send_redirects
   that are on>`, comma-separated, with their full names.
3. **Trying a runtime change.** Write the runtime commands that would set swappiness to 10 and turn
   forwarding off to `/root/tune.cmd`, one per line. Run one, and write `RUNTIME_ERROR=<the reason
   sysctl gives>`.
4. **Hardening drop-in.** Create `/etc/sysctl.d/90-hardening.conf` with these values. sysctl must
   recognise every key. Save the output of applying the file with `sysctl -p`, errors included, to
   `/root/reload.txt`.

   | Key | Value |
   |---|---|
   | `vm.swappiness` | 10 |
   | `net.ipv4.ip_forward` | 0 |
   | `net.ipv4.conf.all.accept_redirects` | 0 |
   | `net.ipv4.conf.all.send_redirects` | 0 |
   | `net.ipv4.conf.all.rp_filter` | 1 |
   | `net.ipv4.tcp_syncookies` | 1 |

5. **Which file wins.**
   - Work out what value of `net.ipv4.ip_forward` the next boot would apply *before* you fix anything,
     and write `EFFECTIVE_IP_FORWARD_BEFORE=<it>` and `OVERRIDE_FILE=<the file responsible>`.
   - Then fix it, so that at boot every hardening value comes from your drop-in.

Check your work from the host: `./lab check sysctl-tuning`

<details>
<summary>Hints</summary>

- `sysctl vm.swappiness`, `sysctl -n ...`, `cat /proc/sys/...`
- `sysctl -a 2>/dev/null | grep -E 'ip_forward|redirects'`
- `sysctl -w name=value`; read the error message
- `sysctl -p <file>`: compare a deliberate typo (`net.ipv4.ip_forwrad`) with a real key
- `ls /etc/sysctl.d /usr/lib/sysctl.d`, `grep -r ip_forward /etc/sysctl.d /etc/sysctl.conf /usr/lib/sysctl.d`

</details>

## My notes

<!-- Screenshots: ./lab shot sysctl-tuning ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [routing-gateway](../routing-gateway/): what forwarding and redirects mean for routing
- [ip-interfaces](../ip-interfaces/)
- `man sysctl`, `man sysctl.d`, `man 5 proc` (`/proc/sys`)
