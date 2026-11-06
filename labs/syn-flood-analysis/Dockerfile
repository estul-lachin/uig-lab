# Stage 1: craft the capture with scapy (fixed seed -> reproducible). Pinned, multi-arch tags.
FROM python:3.12-slim AS gen
RUN pip install --no-cache-dir scapy==2.5.0
COPY gen/gen_capture.py /gen_capture.py
RUN python3 /gen_capture.py /tmp/lab.pcap

# Stage 2: the analyst's triage box - tshark only, no GUI.
FROM ubuntu:24.04
RUN echo "wireshark-common wireshark-common/install-setuid boolean false" | debconf-set-selections \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tshark \
 && rm -rf /var/lib/apt/lists/*

# Convert to pcapng (full packets - this is a header-only flood, nothing to truncate).
COPY --from=gen /tmp/lab.pcap /tmp/lab.pcap
RUN umask 022 \
 && mkdir -p /opt/captures/flood \
 && editcap -F pcapng /tmp/lab.pcap /opt/captures/flood/synflood.pcapng \
 && rm -f /tmp/lab.pcap \
 && chmod 644 /opt/captures/flood/synflood.pcapng

# An answers file to fill in (one KEY=value per line). Empty values fail the checks.
RUN umask 022 && printf '%s\n' \
  '# SYN flood analysis - fill in each value after the = sign, then:' \
  '#   ./lab check syn-flood-analysis' \
  'ATTACK_TYPE=' \
  'ATTACK_FLAG=' \
  'SYN_FILTER=' \
  'VICTIM_IP=' \
  'TARGET_PORT=' \
  'VICTIM_REPLY=' \
  'SPOOFING=' \
  'L2_TAG=' \
  > /root/answers.txt

RUN echo 'echo "Lab syn-flood-analysis: capture at /opt/captures/flood/synflood.pcapng, answers in /root/answers.txt; tasks in labs/syn-flood-analysis/README.md. Check from the host with: ./lab check syn-flood-analysis"' >> /root/.bashrc

WORKDIR /root
CMD ["sleep", "infinity"]
