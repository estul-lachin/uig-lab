# firewall-rules-nat-zones

## Concepts

A firewall is configured with **rules**, reshapes addresses with **NAT**, and divides the network
into **zones** by trust level. This lab puts all three together on one edge firewall with `nftables`.

- **Rule / ACL anatomy.** A rule says: for traffic matching these criteria (source, destination,
  port, protocol) take this **action** (accept / drop / reject). Rules are ordered and the first
  match wins; a clean rule set ends in an explicit **deny-all** (here, `policy drop` on the forward
  chain) and opens only what's needed — starting with a stateful `ct state established,related accept`.
- **NAT.** **SNAT** (source NAT) rewrites the source so many internal hosts share one public IP on
  the way out; the many-to-one, port-multiplexed form is **PAT**, called **masquerade** in Linux.
  **DNAT** (destination NAT) rewrites the destination — a **port-forward**, e.g. sending inbound
  `:443` to an internal server.
- **Zones.** Interfaces are grouped by trust: **WAN** (untrusted internet), **LAN** (trusted
  internal), **DMZ** (semi-trusted, for internet-facing servers). If a DMZ host is compromised it
  still must not reach the LAN. **Segmentation** — isolating zones so a breach can't spread — shrinks
  the blast radius, and east-west traffic from DMZ to LAN is a red flag.

## Tasks

Start the lab with `./lab up firewall-rules-nat-zones`, open a shell with `./lab shell firewall-rules-nat-zones`.

This box (`edge-fw`) has three zone interfaces: **`wan0`** (WAN, `203.0.113.10`), **`lan0`** (LAN,
`10.50.10.0/24`), **`dmz0`** (DMZ, `10.50.20.0/24`). The DMZ web server is **`10.50.20.10`** (HTTPS on
tcp/443). Right now the box forwards everything and does no NAT.

Edit **`/root/edge.nft`** to harden it, then **apply it**:

```
nft -c -f /root/edge.nft   # check syntax
nft -f /root/edge.nft      # apply
```

Build the ruleset so that:

1. **Default-deny forwarding** — the forward chain policy is `drop`, with `established,related` allowed.
2. **Zone rules** — the LAN may reach the WAN and the DMZ; the DMZ may reach the WAN **only**; the
   DMZ is **blocked from the LAN** (segmentation).
3. **NAT** — **masquerade** internal traffic leaving `wan0` (SNAT/PAT); **DNAT** inbound `wan0`
   tcp/443 to the DMZ web server `10.50.20.10:443` (port-forward), and let that forwarded flow
   through the filter.

Check your work from the host: `./lab check firewall-rules-nat-zones`
(the checks read the **loaded** ruleset, so apply `edge.nft` before checking).

<details>
<summary>Hints</summary>

- A chain's default: `type filter hook forward priority 0; policy drop;`.
- Zone rule shape: `iifname "lan0" oifname "wan0" accept`. A reject/drop for `dmz0 -> lan0` enforces
  segmentation even though the default already denies it — write it explicitly.
- NAT lives in its own table: `table ip nat { chain postrouting { type nat hook postrouting priority 100; oifname "wan0" masquerade } ... }`.
- Port-forward: `iifname "wan0" tcp dport 443 dnat to 10.50.20.10:443` in a `prerouting` nat chain —
  and remember the forward chain must still `accept` that flow (`wan0 -> dmz0`, daddr, dport 443).
- Inspect what's loaded with `nft list ruleset`.

</details>

## My notes

<!-- Screenshots: ./lab shot firewall-rules-nat-zones ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- `routing-gateway`, `ip-interfaces` — other host-networking labs.
