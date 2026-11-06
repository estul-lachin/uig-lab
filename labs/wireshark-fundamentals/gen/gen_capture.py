#!/usr/bin/env python3
"""Craft the lab capture with fixed values, so the build is reproducible.

A fictional flat lab segment (10.10.10.0/24) where a workstation talks to a
server over three cleartext protocols plus a DNS lookup:

  * DNS    - the workstation resolves intranet.lab.local -> 10.10.10.10
  * TELNET - a cleartext login (user "labops", password "Spring2025!")
  * FTP    - an anonymous login whose PASS value is an email-style string,
             followed by a few directory-traversal attempts
  * HTTP   - plain web recon, every request carrying a Host: header

Nothing here is real: the addresses, names and credentials are invented for
the lab. Run:  python3 gen_capture.py <output.pcap>
"""
import sys
from scapy.all import (
    Ether, IP, TCP, UDP, DNS, DNSQR, DNSRR, wrpcap,
)

# host = (ip, mac). Locally-administered MACs (02:...).
CLIENT = ("10.10.10.50", "02:42:0a:0a:0a:32")
SERVER = ("10.10.10.10", "02:42:0a:0a:0a:0a")
RESOLVER = ("10.10.10.1", "02:42:0a:0a:0a:01")

pkts = []
_clock = [1_700_000_000.0]


def emit(pkt):
    pkt.time = _clock[0]
    _clock[0] += 0.012
    pkts.append(pkt)


def eth_ip(src, dst):
    return Ether(src=src[1], dst=dst[1]) / IP(src=src[0], dst=dst[0])


def tcp_session(client, server, sport, dport, exchanges, cseq=1000, sseq=5000):
    """Emit a full TCP conversation: handshake, PSH/ACK data, teardown.

    exchanges: list of ("c"|"s", text) in the order they cross the wire.
    Sequence/ack numbers are tracked so the stream reassembles cleanly.
    """
    emit(eth_ip(client, server) / TCP(sport=sport, dport=dport, flags="S", seq=cseq))
    emit(eth_ip(server, client) / TCP(sport=dport, dport=sport, flags="SA", seq=sseq, ack=cseq + 1))
    cseq += 1
    emit(eth_ip(client, server) / TCP(sport=sport, dport=dport, flags="A", seq=cseq, ack=sseq + 1))
    sseq += 1

    for who, text in exchanges:
        data = text.encode()
        if who == "c":
            emit(eth_ip(client, server) / TCP(sport=sport, dport=dport, flags="PA", seq=cseq, ack=sseq) / data)
            cseq += len(data)
            emit(eth_ip(server, client) / TCP(sport=dport, dport=sport, flags="A", seq=sseq, ack=cseq))
        else:
            emit(eth_ip(server, client) / TCP(sport=dport, dport=sport, flags="PA", seq=sseq, ack=cseq) / data)
            sseq += len(data)
            emit(eth_ip(client, server) / TCP(sport=sport, dport=dport, flags="A", seq=cseq, ack=sseq))

    emit(eth_ip(client, server) / TCP(sport=sport, dport=dport, flags="FA", seq=cseq, ack=sseq))
    emit(eth_ip(server, client) / TCP(sport=dport, dport=sport, flags="FA", seq=sseq, ack=cseq + 1))
    emit(eth_ip(client, server) / TCP(sport=sport, dport=dport, flags="A", seq=cseq + 1, ack=sseq + 1))


# --- DNS: resolve the server's name ------------------------------------------
emit(eth_ip(CLIENT, RESOLVER) / UDP(sport=52345, dport=53) /
     DNS(id=0x1a2b, rd=1, qd=DNSQR(qname="intranet.lab.local", qtype="A")))
emit(eth_ip(RESOLVER, CLIENT) / UDP(sport=53, dport=52345) /
     DNS(id=0x1a2b, qr=1, aa=1, rd=1, ra=1,
         qd=DNSQR(qname="intranet.lab.local", qtype="A"),
         an=DNSRR(rrname="intranet.lab.local", type="A", ttl=300, rdata=SERVER[0])))

# --- TELNET: a cleartext login -----------------------------------------------
tcp_session(CLIENT, SERVER, 49201, 23, [
    ("s", "Debian GNU/Linux 12 lab-server\r\n"),
    ("s", "Reminder: rotate your password every 90 days.\r\n"),
    ("s", "lab-server login: "),
    ("c", "labops\r\n"),
    ("s", "Password: "),
    ("c", "Spring2025!\r\n"),
    ("s", "Last login: Mon Nov  3 09:14:52 from 10.10.10.50\r\n"),
    ("s", "labops@lab-server:~$ "),
    ("c", "id\r\n"),
    ("s", "uid=1000(labops) gid=1000(labops) groups=1000(labops),27(sudo)\r\n"),
    ("s", "labops@lab-server:~$ "),
    ("c", "exit\r\n"),
    ("s", "logout\r\n"),
])

# --- FTP: anonymous login + directory traversal ------------------------------
tcp_session(CLIENT, SERVER, 49202, 21, [
    ("s", "220 lab-server FTP service ready\r\n"),
    ("c", "USER anonymous\r\n"),
    ("s", "331 Please specify the password.\r\n"),
    ("c", "PASS labops@workstation.lab\r\n"),
    ("s", "230 Login successful.\r\n"),
    ("c", "SYST\r\n"),
    ("s", "215 UNIX Type: L8\r\n"),
    ("c", "CWD /../\r\n"),
    ("s", "250 Directory successfully changed.\r\n"),
    ("c", "CWD /../../etc\r\n"),
    ("s", "550 Failed to change directory.\r\n"),
    ("c", "QUIT\r\n"),
    ("s", "221 Goodbye.\r\n"),
])

# --- HTTP: plain web recon, every request with a Host: header ----------------
_http = []
for path in ("/", "/admin/", "/phpmyadmin/", "/backup.zip"):
    _http.append(("c",
        f"GET {path} HTTP/1.1\r\n"
        "Host: intranet.lab.local\r\n"
        "User-Agent: curl/8.5.0\r\n"
        "Accept: */*\r\n\r\n"))
    _http.append(("s",
        "HTTP/1.1 404 Not Found\r\n"
        "Server: nginx\r\n"
        "Content-Length: 0\r\n"
        "Connection: keep-alive\r\n\r\n"))
tcp_session(CLIENT, SERVER, 49203, 80, _http)


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: gen_capture.py <output.pcap>")
    wrpcap(sys.argv[1], pkts)
    print(f"wrote {len(pkts)} packets to {sys.argv[1]}")


if __name__ == "__main__":
    main()
