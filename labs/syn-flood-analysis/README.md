# syn-flood-analysis

## Concepts

**Scan vs flood — read the shape first.** Two noisy attacks look similar but behave differently.
A **port scan** sends a few probes to *many ports* on one or a few targets and needs the replies,
so it uses a real source it can receive answers on — its shape is *one source → many ports*. A
**flood (DoS)** sends a torrent to *one port* and doesn't care about replies, so it freely forges
random sources — its shape is *many sources → one port*. A fan-*in* to a single service is the flood
signature; a fan-*out* across ports is a scan.

**Naming the flood — read the TCP flags.** The probes here are bare **SYN** packets (the first step
of the 3-way handshake). Isolate them with `tcp.flags.syn==1 && tcp.flags.ack==0`. The victim answers
some of them with **SYN-ACK**, but the spoofed sources never send the final **ACK** — so SYN far
outnumbers SYN-ACK, which far outnumbers ACK. That imbalance is a pile of **half-open** connections
that exhaust the server's backlog: the fingerprint of a SYN flood.

**Victim and port.** `Statistics → Endpoints/Conversations` (or just counting `ip.dst` and
`tcp.dstport`) shows one internal host taking the vast majority of probes on one port — the victim
and the targeted service. Try an `http` filter or Follow Stream and you get nothing: no handshake
ever completes, so there is no application data. That absence is itself evidence of a flood.

**Spoofing — hiding the attacker.** Limit Endpoints to the SYN filter and you don't see one source;
you see thousands, many obviously forged (long sequential runs, implausible blocks), each sending a
packet or two. That is **source-address spoofing**: the attacker forges the source IP on every SYN
so it can't be traced or blocked, and the SYN-ACKs scatter to hosts that never asked. Recognising the
pattern (one victim, one port, thousands of implausible sources in a ~0.1 s burst) matters more than
trusting any single source IP.

**Layer 2 — VLAN tagging.** Every frame carries an 802.1Q **VLAN** tag (a `vlan` layer between
Ethernet and IP). It doesn't change the analysis, but it tells you the capture was taken on a
tagged/trunk segment — context worth noting in a report.

This lab is CLI-only (`tshark`); the fields match Wireshark exactly if you'd rather open the
`.pcapng` in the GUI on your host.

## Tasks

Start the lab with `./lab up syn-flood-analysis`, open a shell with `./lab shell syn-flood-analysis`.

The capture is at `/opt/captures/flood/synflood.pcapng`: a ~0.1-second storm against one host. Write
each finding into `/root/answers.txt` (one `KEY=value` per line; the file is already there with the
keys).

1. **Scan or flood?** Set `ATTACK_TYPE` to the classification, `ATTACK_FLAG` to the single TCP flag
   on the probes, and `SYN_FILTER` to the display filter that shows only those SYN probes
   (SYN set, ACK clear).
2. **Victim and spoofing.** Set `VICTIM_IP` to the host under attack, `TARGET_PORT` to the single
   port it targets, `VICTIM_REPLY` to what the victim sends back for each probe, and `SPOOFING` to
   the technique hiding the real attacker.
3. **Layer 2.** Set `L2_TAG` to the tagging present on every frame.

Check your work from the host: `./lab check syn-flood-analysis`

<details>
<summary>Hints</summary>

- Count the probes: `tshark -r /opt/captures/flood/synflood.pcapng -Y 'tcp.flags.syn==1 && tcp.flags.ack==0' | wc -l`.
- Compare SYN vs SYN-ACK vs ACK counts to see the half-open imbalance.
- Victim and port: `tshark -r … -T fields -e ip.dst | sort | uniq -c | sort -rn | head`, likewise `-e tcp.dstport`.
- Count the forged sources: `tshark -r … -Y 'tcp.flags.syn==1 && tcp.flags.ack==0' -T fields -e ip.src | sort -u | wc -l`.
- The `vlan` display filter matches every frame; `-e vlan.id` prints the tag.

</details>

## My notes

<!-- Screenshots: ./lab shot syn-flood-analysis ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- `wireshark-fundamentals`, `tshark-tcp-smb` — the other Wireshark/tshark forensics labs.
- `tcp-connections` — listening sockets and the TCP handshake from the host side.
