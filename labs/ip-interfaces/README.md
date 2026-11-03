# ip-interfaces

## Concepts

The first question on any suspect host is: what is this machine on the network? Its interfaces, IP
addresses and MAC addresses are the ground truth. Comparing them with the asset record is how I notice
a box that isn't what it claims to be. This edge host has a `lan` and a `management` network, and
somebody has been changing things on it.

**Interfaces: `ip link`** (`ip -o link` gives one line each)

```
3: eth1@if88: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP ...
    link/ether 02:42:0a:fd:46:0a brd ff:ff:ff:ff:ff:ff
```

- `eth1` is the name. In a container it's one end of a *veth pair* (a virtual cable), and `@if88`
  points at the other end on the host. The real name is the part before `@`.
- The flags: `UP` means an admin enabled it, `LOWER_UP` means the link below has a carrier ("cable
  plugged in").
- `mtu` is the largest packet the link carries in one piece; 1500 is normal for Ethernet.
- `link/ether` is the **MAC address**: the 48-bit layer-2 address used on the local link.

Docker Desktop's kernel also shows template interfaces like `tunl0@NONE` or `gre0@NONE`. They are
always DOWN, carry no address, and can be ignored.

**Addresses: `ip addr`** (`ip -4 -o addr show IFACE` gives only IPv4, one line each). Addresses
are in CIDR form: `inet 10.253.70.10/24`, where `/24` means the first 24 bits are the network. One
interface can carry several addresses.

**/sys/class/net/IFACE/** has one plain file per fact, with nothing to filter: `address` (MAC), `mtu`,
`operstate` (`up`, `down`, or `unknown`).

**Loopback** (`lo`, `127.0.0.1/8`, the whole `127.0.0.0/8` range) is how the host talks to itself, and
it's where services listening on "localhost" live. If it's down, those break in confusing ways. Its
operstate is `unknown` even when it works: there's no physical carrier to report, so its flags
(`UP,LOWER_UP`) are what count.

**Changing state** needs the `NET_ADMIN` capability, which this lab's container has:
- `ip link set IFACE up` / `down` turns an interface on or off.
- `ip link del IFACE` removes a virtual interface.
- Bringing an interface up again also brings back the route to its own network.

**Command substitution**: `$(cmd)` puts a command's output into the line, so
`cat /sys/class/net/$(cat iface.txt)/address` works whatever the interface is called.

## Tasks

Start the lab with `./lab up ip-interfaces`, open a shell with `./lab shell ip-interfaces`.
The shell is `root`. Interface names are assigned at start-up, so read yours from the output; don't
assume `eth0`. Write the `KEY=value` answers to `/root/answers.txt`.

1. **Default interface.** Write the name of the interface that carries the default route to
   `/root/iface.txt`, without the `@ifN` part.
2. **IPv4 addresses.** That interface has more than one IPv4 address. Write all of them to
   `/root/ipv4.txt`, one per line, without the prefix length.
3. **MAC address.** Write that interface's MAC to `/root/mac.txt`, using `$(cat /root/iface.txt)` in the
   path.
4. **Loopback.** `lo` has been switched off. Bring it back up and check that `127.0.0.1` answers a ping.
   Then write its operstate to `/root/lo_state.txt`.
5. **Management interface.** The interface with the address `10.253.71.10` is down. Write
   `MGMT_IFACE=<its name>` and `MGMT_MTU=<its MTU>`, then bring it up.
6. **The unexpected interface.** `/root/asset-record.txt` lists the interfaces that should carry an
   address. One interface has an IPv4 address but isn't on that list. Write `ROGUE_IFACE=<name>` and
   `ROGUE_IP=<its address, without the prefix length>`, then delete it.

Check your work from the host: `./lab check ip-interfaces`. `./lab reset ip-interfaces` puts everything
back the way it was.

<details>
<summary>Hints</summary>

- `ip -o link`, `ip route show default`
- `ip -4 -o addr show <iface>`, or `ip -4 -o addr show` for every interface
- `cat /sys/class/net/<iface>/address`, `.../mtu`, `.../operstate`
- `ip link set lo up`, `ping -c1 127.0.0.1`
- `ip link set <iface> up`, then `ping -c1 10.253.71.1`
- `cat /root/asset-record.txt`, `ip link del <iface>`

</details>

## My notes

<!-- Screenshots: ./lab shot ip-interfaces ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [routing-gateway](../routing-gateway/): how the kernel picks an interface for each destination
- [dns-resolution](../dns-resolution/), [tcp-connections](../tcp-connections/)
- `man ip-link`, `man ip-address`
