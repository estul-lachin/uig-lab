# Stage 1: craft the capture with scapy (fixed values -> reproducible). Pinned, multi-arch tags.
FROM python:3.12-slim AS gen
RUN pip install --no-cache-dir scapy==2.5.0
COPY gen/gen_capture.py /gen_capture.py
RUN python3 /gen_capture.py /tmp/lab-capture.pcap

# Stage 2: the analyst's triage box - tshark only, no GUI.
FROM ubuntu:24.04
# tshark pulls wireshark-common (editcap, capinfos, ...); keep its setuid helper off and stay non-interactive.
RUN echo "wireshark-common wireshark-common/install-setuid boolean false" | debconf-set-selections \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tshark \
 && rm -rf /var/lib/apt/lists/*

# Convert to pcapng (the native Wireshark format) and drop it at a tidy, fixed path.
COPY --from=gen /tmp/lab-capture.pcap /tmp/lab-capture.pcap
RUN umask 022 \
 && mkdir -p /opt/intro \
 && editcap /tmp/lab-capture.pcap /opt/intro/lab-capture.pcapng \
 && rm -f /tmp/lab-capture.pcap \
 && chmod 644 /opt/intro/lab-capture.pcapng

# An answers file to fill in (one KEY=value per line). Empty values fail the checks.
RUN umask 022 && printf '%s\n' \
  '# Wireshark Fundamentals - fill in each value after the = sign, then:' \
  '#   ./lab check wireshark-fundamentals' \
  'BYTES_PANE=' \
  'PROTOCOL=' \
  'SERVER_IP=' \
  'TELNET_USER=' \
  'TELNET_PASS=' \
  'FTP_PASS=' \
  'FILTER_PASSWORD=' \
  'HTTP_HOST_FIELD=' \
  'HTTP_HOST=' \
  > /root/answers.txt

RUN echo 'echo "Lab wireshark-fundamentals: capture at /opt/intro/lab-capture.pcapng, answers in /root/answers.txt; tasks in labs/wireshark-fundamentals/README.md. Check from the host with: ./lab check wireshark-fundamentals"' >> /root/.bashrc

WORKDIR /root
CMD ["sleep", "infinity"]
