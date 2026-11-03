# routing-gateway

## Concepts

Before deciding whether a suspect host could reach an attacker's server, I need to know how its packets
leave. For every packet the kernel looks up the destination in the **routing table** and gets back two
answers: send it to whom, and out of which interface. This edge host sits on two networks: `lan`
(`10.253.60.0/24`) and `mgmt` (`10.253.61.0/24`).

**Reading `ip route`**: each line is one rule.

```
default via 10.253.60.1 dev eth1                               <- everything else: to the gateway
10.253.60.0/24 dev eth1 proto kernel scope link src 10.253.60.10  <- this network is on eth1, no router
```

- `via X` means "hand it to router X". A line without `via` is a directly connected network.
- `dev` is the interface the packet leaves through; `src` is the address the packet goes out with.
- The **default route** (`0.0.0.0/0`) matches every address, so it only wins when nothing more specific
  does. Its `via` address is the **default gateway**, the exit to everything else. With no default
  route, a host can only reach its own networks.

**Which rule wins**: the most specific one, i.e. the longest prefix. A `/24` beats a `/16`, which
beats the default `/0`. So one extra line can quietly redirect a single network, even if the default
route looks perfectly normal.

**One column with awk**: `awk '{print $3}'` prints the third space-separated field of each line.
In `default via 10.253.60.1 dev eth1` that's the gateway.

**Ask the kernel**: `ip route get ADDRESS` applies all the rules and prints the result for one
destination: the next hop (`via`, if any), the interface (`dev`) and the source address (`src`). The
`cache` line below it can be ignored. It's the quickest answer on a host with several interfaces.

**Blackhole routes**: `ip route add blackhole PREFIX` makes the kernel silently drop everything for that
range. No error goes back to the remote side, unlike a firewall *reject*. Operators use it to null-route
abusive or malicious ranges. `203.0.113.0/24`, `198.51.100.0/24` and `192.0.2.0/24` are the
documentation ranges from RFC 5737, safe to practise with. Changing routes needs the `NET_ADMIN`
capability, which this lab's container has.

**For incident response**:
- Could the host reach the C2 address at all?
- Is traffic silently null-routed, or blocked by a firewall?
- Has someone added a route that sends one network through a machine they control?

## Tasks

Start the lab with `./lab up routing-gateway`, open a shell with `./lab shell routing-gateway`.
The shell is `root`. Write answers to `/root/answers.txt` as `KEY=value` lines.

1. **The routing table.** Save the full output of `ip route` to `/root/routes.txt`.
2. **Default gateway.** Write only the default gateway's address to `/root/gw.txt`.
3. **Asking the kernel.**
   - Save the kernel's answer for how it would reach `1.1.1.1` to `/root/nh.txt`.
   - For `10.253.61.20` (a host on the management network), write `MGMT_DEV=<interface>` and
     `MGMT_VIA=<next hop, or none if there is no gateway>`.
4. **Blackhole route.** Null-route `203.0.113.0/24` for real, then confirm that the kernel refuses to
   route `203.0.113.9`.
5. **The diverted network.** One route sends a whole network to a next hop that isn't the default
   gateway. Write `ROGUE_PREFIX=<the network>` and `ROGUE_VIA=<its next hop>`. Then delete that route
   so that the network goes through the default gateway like everything else.

Check your work from the host: `./lab check routing-gateway`. `./lab reset routing-gateway` puts the
rogue route back and removes your blackhole.

<details>
<summary>Hints</summary>

- `ip route`, `ip route show default`, `ip route show default | awk '{print $3}'`
- `ip route get 1.1.1.1`, `ip route get 10.253.61.20`: a missing `via` is your answer for `MGMT_VIA`
- `ip route add blackhole <prefix>`, `ip route show type blackhole`, `ip route get 203.0.113.9`
- Compare each `via` in `ip route` with the gateway in `gw.txt`; then `ip route del <prefix>` and
  `ip route get 198.51.100.7`
- Your interface names may be swapped (mgmt on `eth0`); always read them from the output

</details>

## My notes

<!-- Screenshots: ./lab shot routing-gateway ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [dns-resolution](../dns-resolution/): turning names into addresses
- [tcp-connections](../tcp-connections/): which connections a host has open
- `man ip-route`, RFC 5737 (documentation address ranges)
