# firewall-stateful-egress

## Concepts

A firewall is a control point that allows or denies traffic across a **trust boundary** by a rule
set. This lab builds a **host firewall** (protecting one machine) with `nftables` and puts the
fundamentals to work.

- **Stateless vs stateful.** A stateless packet filter judges each packet alone; a **stateful**
  firewall tracks connections in a state table, so when it allows an outbound request it
  automatically recognises the matching reply (`ct state established,related accept`). Every modern
  firewall is stateful — it's safer and simpler. Packets with no valid state
  (`ct state invalid`) are dropped.
- **The 5-tuple.** A rule matches on source IP, destination IP, source port, destination port and
  protocol — the five fields that identify a flow (e.g. `ip saddr … tcp dport 22`).
- **Default-deny + first-match.** The safe baseline blocks everything unless a rule explicitly allows
  it (`policy drop`, the implicit deny). Rules are evaluated top-to-bottom and the **first match
  wins**, so a deny must sit **above** a broader allow or the allow will win.
- **Drop vs reject.** `drop` silently discards a packet (the sender just times out), hiding the
  firewall; `reject` sends back an error (RST / ICMP unreachable), failing fast but revealing it.
  You drop traffic you don't want to tip off (malware C2); you reject where a fast, clear failure
  helps the user.
- **Ingress vs egress.** Ingress filtering controls what comes in; **egress** filtering controls what
  goes out. Egress filtering is underused but vital in a SOC — it's how you stop a compromised host
  from reaching its command-and-control server or exfiltrating data.

> A firewall decides allow/deny by rule — it does **not** understand the content of an attack inside
> allowed traffic. Spotting a known exploit in permitted HTTP is the job of a **WAF** (web/Layer-7)
> or an **IDS/IPS**, not a packet filter. Knowing where the firewall's job ends tells you which
> control to check during an incident.

## Tasks

Start the lab with `./lab up firewall-stateful-egress`, open a shell with `./lab shell firewall-stateful-egress`.

This workstation (`ws-25`, `10.50.10.25`) is wide open. Edit **`/root/host.nft`** and **apply it**:

```
nft -c -f /root/host.nft   # check syntax
nft -f /root/host.nft      # apply
```

Build the ruleset so that:

1. **Default-deny, stateful** — both the `input` and `output` chains default to `drop`; allow
   `established,related` (and loopback); drop `ct state invalid`.
2. **First-match & drop vs reject (egress)** — silently **drop** all egress to the C2 server
   `198.51.100.66`, placed **before** the web allow so first-match catches it; **reject** outbound
   SMB (`tcp/445`) so it fails fast.
3. **Egress allow-list & a 5-tuple rule** — allow outbound DNS (`udp`/`tcp 53`) and web
   (`tcp 80, 443`); allow inbound SSH (`tcp/22`) **only** from the mgmt subnet `10.50.99.0/24`.

Check your work from the host: `./lab check firewall-stateful-egress`
(the checks read the **loaded** ruleset, so apply `host.nft` before checking).

<details>
<summary>Hints</summary>

- Default-deny: `type filter hook output priority 0; policy drop;` — then explicitly allow what's needed.
- Order matters: put `ip daddr 198.51.100.66 drop` **above** `tcp dport { 80, 443 } accept`, or egress
  to the C2 on 443 slips through.
- Silent vs loud: `… drop` (no reply) vs `tcp dport 445 reject`.
- A 5-tuple rule: `ip saddr 10.50.99.0/24 tcp dport 22 ct state new accept`.
- Inspect order with `nft list chain inet fw output`.

</details>

## My notes

<!-- Screenshots: ./lab shot firewall-stateful-egress ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- `firewall-rules-nat-zones` — the edge-firewall companion (NAT, WAN/LAN/DMZ zones).
- `routing-gateway`, `tcp-connections` — other networking labs.
