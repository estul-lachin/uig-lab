# Generate the Larkspur Books web-traffic capture for the suricata-ids-rules lab.
# A handful of HTTP request/response flows over proper TCP streams so Suricata's
# HTTP parser reassembles them: benign browsing plus three attacks (a SQL
# injection, a path traversal, and a scanner User-Agent). Everything is invented
# lab traffic against documentation IP ranges - no real hosts.
import random
from scapy.all import Ether, IP, TCP, Raw, wrpcap

random.seed(1337)

CLIENT = "198.51.100.37"   # TEST-NET-2 (documentation)
SERVER = "203.0.113.20"    # TEST-NET-3 (documentation)
ETH = {"src": "02:00:5e:00:53:01", "dst": "02:00:5e:00:53:02"}
pkts = []


def http_flow(sport, request_lines):
    """Full TCP handshake + one HTTP request + a minimal response + FIN."""
    seq_c = random.randint(10000, 900000)
    seq_s = random.randint(10000, 900000)
    eth = Ether(**ETH)

    syn = eth / IP(src=CLIENT, dst=SERVER) / TCP(sport=sport, dport=80, flags="S", seq=seq_c)
    synack = eth / IP(src=SERVER, dst=CLIENT) / TCP(sport=80, dport=sport, flags="SA", seq=seq_s, ack=seq_c + 1)
    ack = eth / IP(src=CLIENT, dst=SERVER) / TCP(sport=sport, dport=80, flags="A", seq=seq_c + 1, ack=seq_s + 1)
    pkts.extend([syn, synack, ack])

    req = ("\r\n".join(request_lines) + "\r\n\r\n").encode()
    preq = (eth / IP(src=CLIENT, dst=SERVER)
            / TCP(sport=sport, dport=80, flags="PA", seq=seq_c + 1, ack=seq_s + 1) / Raw(load=req))
    sack = eth / IP(src=SERVER, dst=CLIENT) / TCP(sport=80, dport=sport, flags="A", seq=seq_s + 1, ack=seq_c + 1 + len(req))
    pkts.extend([preq, sack])

    body = b"<html><body>Larkspur Books</body></html>"
    resp = ("HTTP/1.1 200 OK\r\nServer: larkspur\r\nContent-Type: text/html\r\n"
            "Content-Length: %d\r\n\r\n" % len(body)).encode() + body
    presp = (eth / IP(src=SERVER, dst=CLIENT)
             / TCP(sport=80, dport=sport, flags="PA", seq=seq_s + 1, ack=seq_c + 1 + len(req)) / Raw(load=resp))
    fin = eth / IP(src=CLIENT, dst=SERVER) / TCP(sport=sport, dport=80, flags="FA",
                                                 seq=seq_c + 1 + len(req), ack=seq_s + 1 + len(resp))
    pkts.extend([presp, fin])


UA = "Mozilla/5.0 (X11; Linux x86_64) Gecko/20100101 Firefox/128.0"

# Benign browsing (noise the signatures must NOT fire on).
http_flow(41001, ["GET /index.html HTTP/1.1", "Host: larkspur.example", f"User-Agent: {UA}", "Accept: */*"])
http_flow(41002, ["GET /catalog?page=2 HTTP/1.1", "Host: larkspur.example", f"User-Agent: {UA}"])
http_flow(41003, ["GET /book?id=842 HTTP/1.1", "Host: larkspur.example", f"User-Agent: {UA}"])

# Attack 1: SQL injection (boolean tautology) in a query parameter.
http_flow(41010, ["GET /search?id=1'+OR+'1'='1 HTTP/1.1", "Host: larkspur.example", f"User-Agent: {UA}"])

# Attack 2: path traversal to read a system file.
http_flow(41011, ["GET /download?file=../../../../etc/passwd HTTP/1.1", "Host: larkspur.example", f"User-Agent: {UA}"])

# Attack 3: a vulnerability scanner identifying itself in the User-Agent.
http_flow(41012, ["GET / HTTP/1.1", "Host: larkspur.example", "User-Agent: EvilScan/2.0 (+scanner)"])

wrpcap("/out/larkspur-traffic.pcap", pkts)
print("wrote %d packets to /out/larkspur-traffic.pcap" % len(pkts))
