#!/usr/bin/env python3
"""Craft the lab capture with fixed values, so the build is reproducible.

A fictional story: a workstation (172.16.20.15) reads a file off an SMB2 file
server (172.16.20.8) and the transfer is painfully slow. The capture shows why:

  * a normal SMB2 session - Negotiate, Session Setup, Tree Connect to the
    \\172.16.20.8\profiles share, and Create requests that open
    dmccoy\\backup, dmccoy\\backup\\startup.bat and dmccoy\\backup\\settings.ini
  * the file read itself: a storm of TCP duplicate ACKs with lost segments and
    retransmissions - the signature of packet loss collapsing throughput

Everything here is invented for the lab. The final image truncates this capture
to a short snaplen (editcap -s), so the file payload is cut off and
`tshark --export-objects smb,DIR` can recover nothing - that is the point of the
"carving" task.

Run:  python3 gen_capture.py <output.pcap>
"""
import sys
from scapy.all import Ether, IP, TCP, Raw, wrpcap
from scapy.layers.smb2 import (
    SMB2_Header,
    SMB2_Negotiate_Protocol_Request, SMB2_Negotiate_Protocol_Response,
    SMB2_Session_Setup_Request, SMB2_Session_Setup_Response,
    SMB2_Tree_Connect_Request, SMB2_Tree_Connect_Response,
    SMB2_Create_Request, SMB2_Create_Response,
    SMB2_Read_Request, SMB2_Read_Response,
)

CLIENT = ("172.16.20.15", "02:42:ac:10:14:0f")
SERVER = ("172.16.20.8", "02:42:ac:10:14:08")
SHARE = "\\\\172.16.20.8\\profiles"   # smb2.tree  -> share name "profiles"
SID = 0x4411223344556677
TID = 0x00000001

NEG, SES, TCON, CREATE, READ = 0x0000, 0x0001, 0x0003, 0x0005, 0x0008

_clock = [1_700_000_000.0]


def eth(src, dst):
    return Ether(src=src[1], dst=dst[1]) / IP(src=src[0], dst=dst[0])


def nbss(msg):
    """Direct-TCP (NBSS) 4-byte length prefix used by SMB over TCP/445."""
    return b"\x00" + len(msg).to_bytes(3, "big") + msg


def hdr(command, mid, tid=0):
    return SMB2_Header(Command=command, MID=mid, TID=tid, PID=0xfeff, SessionId=SID)


class Conn:
    """One TCP connection, tracking sequence/ack numbers as segments are emitted."""

    def __init__(self, client, server, sport, dport):
        self.client, self.server = client, server
        self.sport, self.dport = sport, dport
        self.cseq, self.sseq = 1000, 500000
        self.pkts = []

    def _emit(self, pkt):
        pkt.time = _clock[0]
        _clock[0] += 0.002
        self.pkts.append(pkt)

    def handshake(self):
        self._emit(eth(self.client, self.server) / TCP(sport=self.sport, dport=self.dport, flags="S", seq=self.cseq))
        self._emit(eth(self.server, self.client) / TCP(sport=self.dport, dport=self.sport, flags="SA", seq=self.sseq, ack=self.cseq + 1))
        self.cseq += 1
        self._emit(eth(self.client, self.server) / TCP(sport=self.sport, dport=self.dport, flags="A", seq=self.cseq, ack=self.sseq + 1))
        self.sseq += 1

    def _cseg(self, data):
        self._emit(eth(self.client, self.server) / TCP(sport=self.sport, dport=self.dport, flags="PA", seq=self.cseq, ack=self.sseq) / Raw(data))
        self.cseq += len(data)

    def _sseg(self, data, seq=None):
        seq = self.cseq_free(seq)
        self._emit(eth(self.server, self.client) / TCP(sport=self.dport, dport=self.sport, flags="PA", seq=seq, ack=self.cseq) / Raw(data))

    def cseq_free(self, seq):
        return self.sseq if seq is None else seq

    def c_ack(self, ack=None):
        ack = self.sseq if ack is None else ack
        self._emit(eth(self.client, self.server) / TCP(sport=self.sport, dport=self.dport, flags="A", seq=self.cseq, ack=ack))

    def s_ack(self):
        self._emit(eth(self.server, self.client) / TCP(sport=self.dport, dport=self.sport, flags="A", seq=self.sseq, ack=self.cseq))

    def client_request(self, msg):
        """Client sends an SMB2 request; server ACKs it."""
        self._cseg(nbss(msg))
        self.s_ack()

    def server_response(self, msg):
        """Server sends an SMB2 response in order; client ACKs it."""
        data = nbss(msg)
        self._sseg(data)
        self.sseq += len(data)
        self.c_ack()


def read_storm(conn, read_resp_builder, rounds=50, losses_per_round=1, dupacks=3):
    """Server streams the file as SMB2 Read Responses, losing one segment per round.

    Each lost segment makes the client fire duplicate ACKs (the packet-loss
    signature) until the server retransmits it.
    """
    for _ in range(rounds):
        # Two responses delivered cleanly.
        conn.server_response(read_resp_builder())
        conn.server_response(read_resp_builder())

        # One response is "lost": advance the server's sequence space without
        # emitting the bytes, so Wireshark sees a gap (lost segment).
        gap_bytes = nbss(read_resp_builder())
        gap_seq = conn.sseq
        conn.sseq += len(gap_bytes)

        # Later responses arrive past the gap; the client keeps re-ACKing the
        # missing byte -> a run of duplicate ACKs.
        for _ in range(dupacks):
            later = nbss(read_resp_builder())
            conn._sseg(later)
            conn.sseq += len(later)
            conn.c_ack(gap_seq)          # duplicate ACK for the hole

        # Server retransmits the lost segment, filling the hole.
        conn._sseg(gap_bytes, seq=gap_seq)
        conn.c_ack()                      # now caught up


def build():
    c = Conn(CLIENT, SERVER, 51020, 445)
    c.handshake()

    # --- SMB2 session bring-up --------------------------------------------
    c.client_request(bytes(hdr(NEG, 1) / SMB2_Negotiate_Protocol_Request(Dialects=[0x0202, 0x0210, 0x0300])))
    c.server_response(bytes(hdr(NEG, 1) / SMB2_Negotiate_Protocol_Response(DialectRevision=0x0300, ServerTime=1_700_000_000, ServerStartTime=1_699_000_000)))
    c.client_request(bytes(hdr(SES, 2) / SMB2_Session_Setup_Request()))
    c.server_response(bytes(hdr(SES, 2) / SMB2_Session_Setup_Response()))

    # --- Tree Connect to the share ----------------------------------------
    c.client_request(bytes(hdr(TCON, 3) / SMB2_Tree_Connect_Request(Buffer=[("Path", SHARE)])))
    c.server_response(bytes(hdr(TCON, 3, TID) / SMB2_Tree_Connect_Response(ShareType=1)))

    # --- Open the folder and files (smb2.filename) ------------------------
    for mid, name in ((4, "dmccoy\\backup"), (5, "dmccoy\\backup\\startup.bat")):
        c.client_request(bytes(hdr(CREATE, mid, TID) / SMB2_Create_Request(Buffer=[("Name", name)])))
        c.server_response(bytes(hdr(CREATE, mid, TID) / SMB2_Create_Response(EnfofFile=65536)))

    # --- Read startup.bat: the slow, lossy transfer -----------------------
    c.client_request(bytes(hdr(READ, 6, TID) / SMB2_Read_Request(Length=65536, Offset=0)))
    # A chunk big enough that each Read Response exceeds the capture snaplen, so the
    # final truncated file keeps the headers but loses the payload (carving fails).
    payload = b"@echo off\r\nrem lab fixture - not a real file\r\n" + b"A" * 512
    read_resp = lambda: bytes(hdr(READ, 6, TID) / SMB2_Read_Response(Buffer=[("Data", payload)]))
    read_storm(c, read_resp, rounds=50)

    # --- One more Create so smb2.filename lists the sibling file -----------
    c.client_request(bytes(hdr(CREATE, 7, TID) / SMB2_Create_Request(Buffer=[("Name", "dmccoy\\backup\\settings.ini")])))
    c.server_response(bytes(hdr(CREATE, 7, TID) / SMB2_Create_Response(EnfofFile=256)))

    return c.pkts


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: gen_capture.py <output.pcap>")
    pkts = build()
    wrpcap(sys.argv[1], pkts)
    print(f"wrote {len(pkts)} packets to {sys.argv[1]}")


if __name__ == "__main__":
    main()
