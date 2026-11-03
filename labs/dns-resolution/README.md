# dns-resolution

## Concepts

People and malware use names, not addresses, so how a host turns `portal.corp.lab` into an IP decides
where its traffic really goes. A Linux host decides this with four files and tools. Each one is a lever
an attacker can pull, so a responder reads all of them. This lab has its own DNS server for the
`corp.lab` zone, so nothing depends on the internet.

**/etc/resolv.conf** lists the DNS servers to ask, one `nameserver` line each, tried in order. A
`search` line appends a domain to bare names. In Docker the runtime writes this file; on a custom
network it points at Docker's built-in resolver `127.0.0.11`, which forwards to the real servers.
(systemd's local stub is `127.0.0.53`.) A loopback address here just means a local forwarder.

**dig** asks DNS directly:
- `dig name A` gives the full answer, `dig +short name A` only the addresses. One name can have several A
  records, which is how load balancing and CDNs spread traffic.
- `dig +short -x IP` is a reverse lookup: the PTR record turns an address back into a name, handy when an
  alert only gives an IP.
- `dig name @server` asks one specific server instead of the configured ones.

**/etc/hosts** is a static `IP name` list the system checks *before* DNS. It's owned by root, and
`sudo echo ... >> /etc/hosts` fails: my own shell opens the file for `>>` before sudo runs. Let a root
process do the writing instead: `echo 'IP name' | sudo tee -a /etc/hosts`. Without `-a`, tee replaces
the whole file.

**getent hosts name** resolves the way programs do, so it sees `/etc/hosts`. dig skips that file and
only talks to DNS, so the two can disagree.

**/etc/nsswitch.conf** sets the order: `hosts: files dns` means "/etc/hosts first, DNS only if there's no
match". That order is why one line in /etc/hosts can quietly send a real domain to an attacker's server.
The same goes for a `resolv.conf` pointed at a rogue DNS server. MITRE ATT&CK lists DNS used for
command and control as T1071.004.

## Tasks

Start the lab with `./lab up dns-resolution`, open a shell with `./lab shell dns-resolution`.
The shell is `root`. For task 3, switch to the regular user `analyst` (`su - analyst`), who has sudo.

1. **Configured nameservers.** Write only the nameserver IPs from `/etc/resolv.conf` to `/root/ns.txt`,
   one per line.
2. **Lookups with dig.**
   - Write every A record of `portal.corp.lab` to `/root/a_portal.txt`, addresses only.
   - Do a reverse lookup of `10.20.0.15` and write the name to `/root/ptr.txt`.
3. **Local override.** As `analyst`, use `sudo tee -a` to make `test.corp.lab` resolve to `10.99.99.99`.
   Confirm it with `getent hosts`, and try `dig` too to see that DNS doesn't know the name. The rest of
   `/etc/hosts` must stay intact.
4. **Resolver order.** Write the `hosts:` line of `/etc/nsswitch.conf` to `/root/nss_hosts.txt`.
5. **Hosts-file hijack.** One `corp.lab` name on this machine doesn't resolve to what DNS says. Write
   `/root/findings.txt`:

   ```
   HIJACKED_NAME=<the name>
   ROGUE_IP=<the address the machine uses for it now>
   REAL_IP=<the address DNS gives>
   ```

   Then remove the rogue entry so that the name resolves to its DNS address again. Keep your own
   `test.corp.lab` line.

Check your work from the host: `./lab check dns-resolution`. `./lab reset dns-resolution` restores the
original `/etc/hosts`.

<details>
<summary>Hints</summary>

- `cat /etc/resolv.conf`; `grep ^nameserver /etc/resolv.conf | awk '{print $2}'`
- `dig portal.corp.lab A`, `dig +short portal.corp.lab A`, `dig +short -x 10.20.0.15`
- `echo '10.99.99.99 test.corp.lab' | sudo tee -a /etc/hosts`, then `getent hosts test.corp.lab`
- `grep ^hosts /etc/nsswitch.conf`
- For each name in `/etc/hosts`, compare `getent hosts <name>` with `dig +short <name>`
- Docker bind-mounts `/etc/hosts`, so `sed -i` fails ("Device or resource busy"). Filter into a temp
  file, then write it back with `cat /tmp/hosts.new > /etc/hosts`

</details>

## My notes

<!-- Screenshots: ./lab shot dns-resolution ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [tcp-connections](../tcp-connections/): which connections a host has open
- `man dig`, `man 5 resolv.conf`, `man 5 hosts`, `man 5 nsswitch.conf`, `man getent`
