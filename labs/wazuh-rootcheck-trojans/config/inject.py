"""Hand rootcheck results to analysisd as if an agent had sent them.

Usage: inject.py FILE [DELAY]   lines of  agent|ip|message  (# comments and blank lines skipped)
"""
import socket
import sys
import time

QUEUE = "/var/ossec/queue/sockets/queue"
ROOTCHECK_MQ = "9"


def main():
    path = sys.argv[1]
    delay = float(sys.argv[2]) if len(sys.argv) > 2 else 0.0
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    sock.connect(QUEUE)
    with open(path, encoding="utf-8") as f:
        lines = [l.rstrip("\n") for l in f if l.strip() and not l.startswith("#")]
    for n, line in enumerate(lines, 1):
        agent, ip, msg = line.split("|", 2)
        agent_id = "%03d" % (sum(map(ord, agent)) % 900 + 100)
        sock.send(("%s:[%s] (%s) %s->rootcheck:%s" % (ROOTCHECK_MQ, agent_id, agent, ip, msg)).encode())
        time.sleep(delay)


if __name__ == "__main__":
    main()
