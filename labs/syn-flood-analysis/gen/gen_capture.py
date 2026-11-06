#!/usr/bin/env python3
"""Craft the lab capture with a fixed seed, so the build is reproducible.

A fictional story: a sensor on a tagged (802.1Q) trunk captures a ~0.1-second
burst against one web server. The shape is a SYN flood with spoofed sources:

  * every frame carries an 802.1Q VLAN tag (vlan 60) between Ethernet and IP
  * thousands of SYN probes (SYN set, ACK clear) aimed at ONE host, ONE port
    (10.20.30.40 : 80), each from a different, often sequential, forged source IP
  * the victim answers a fraction of them with SYN-ACKs that scatter to hosts
    that never asked; almost no final ACKs -> a pile of half-open connections

Everything here is invented for the lab. All the spoofed sources share one
attacker MAC (spoofing is at the IP layer), and the addresses use the
documentation ranges plus random blocks.

Run:  python3 gen_capture.py <output.pcap>
"""
import random
import sys
from scapy.all import Ether, Dot1Q, IP, TCP, wrpcap

random.seed(1337)

VICTIM = ("10.20.30.40", "02:42:0a:14:1e:28")
ATTACKER_MAC = "02:42:ac:00:00:01"
VLAN = 60
PORT = 80

T0 = 1_700_000_000.0
BURST = 0.1  # seconds


def spoofed_sources(n):
    """A believable mix: long sequential runs plus scattered random blocks."""
    srcs = []
    for prefix, start in (("198.51.100", 10), ("203.0.113", 1), ("192.0.2", 1)):
        for i in range(start, 255):
            srcs.append(f"{prefix}.{i}")
    while len(srcs) < n:
        srcs.append(f"{random.randint(11, 223)}.{random.randint(0, 255)}."
                    f"{random.randint(0, 255)}.{random.randint(1, 254)}")
    return srcs[:n]


def build():
    pkts = []
    N_SYN = 4000
    srcs = spoofed_sources(N_SYN)

    def syn(src):
        sport = random.randint(1024, 65535)
        return (Ether(src=ATTACKER_MAC, dst=VICTIM[1]) / Dot1Q(vlan=VLAN) /
                IP(src=src, dst=VICTIM[0]) /
                TCP(sport=sport, dport=PORT, flags="S", seq=random.randint(0, 2**32 - 1)))

    def synack(dst):
        sport = random.randint(1024, 65535)
        return (Ether(src=VICTIM[1], dst=ATTACKER_MAC) / Dot1Q(vlan=VLAN) /
                IP(src=VICTIM[0], dst=dst) /
                TCP(sport=PORT, dport=sport, flags="SA", seq=random.randint(0, 2**32 - 1),
                    ack=random.randint(0, 2**32 - 1)))

    def ack(src):
        sport = random.randint(1024, 65535)
        return (Ether(src=ATTACKER_MAC, dst=VICTIM[1]) / Dot1Q(vlan=VLAN) /
                IP(src=src, dst=VICTIM[0]) /
                TCP(sport=sport, dport=PORT, flags="A", seq=1, ack=1))

    for src in srcs:
        pkts.append(syn(src))
        # The victim answers about one in ten probes with a SYN-ACK.
        if random.random() < 0.10:
            pkts.append(synack(src))
    # A handful of stray ACKs - far too few to match the SYN-ACKs (half-open).
    for src in random.sample(srcs, 40):
        pkts.append(ack(src))

    # Squeeze the whole thing into a ~0.1-second burst, in capture order.
    random.shuffle(pkts)
    step = BURST / len(pkts)
    for i, p in enumerate(pkts):
        p.time = T0 + i * step
    return pkts


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: gen_capture.py <output.pcap>")
    pkts = build()
    wrpcap(sys.argv[1], pkts)
    print(f"wrote {len(pkts)} packets to {sys.argv[1]}")


if __name__ == "__main__":
    main()
