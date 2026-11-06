# Stage 1: craft the capture with scapy (fixed values -> reproducible). Pinned, multi-arch tags.
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

# Truncate to a short snaplen: the small control packets survive (so smb2.tree and
# smb2.filename stay readable), but the large Read Responses lose their payload, so
# --export-objects can rebuild nothing. capinfos then reports the 256-byte limit.
COPY --from=gen /tmp/lab.pcap /tmp/lab.pcap
RUN umask 022 \
 && mkdir -p /opt/captures \
 && editcap -F pcapng -s 256 /tmp/lab.pcap /opt/captures/slow-smb.pcapng \
 && rm -f /tmp/lab.pcap \
 && chmod 644 /opt/captures/slow-smb.pcapng

# An answers file to fill in (one KEY=value per line). Empty values fail the checks.
RUN umask 022 && printf '%s\n' \
  '# TShark TCP + SMB analysis - fill in each value after the = sign, then:' \
  '#   ./lab check tshark-tcp-smb' \
  'READ_FLAG=' \
  'FILTER_FLAG=' \
  'FIELDS_MODE=' \
  'LOSS_FIELD=' \
  'CONDITION=' \
  'PROTOCOL=' \
  'SERVER_IP=' \
  'SHARE=' \
  'FOLDER_PATH=' \
  'EXPORT_FLAG=' \
  > /root/answers.txt

RUN echo 'echo "Lab tshark-tcp-smb: capture at /opt/captures/slow-smb.pcapng, answers in /root/answers.txt; tasks in labs/tshark-tcp-smb/README.md. Check from the host with: ./lab check tshark-tcp-smb"' >> /root/.bashrc

WORKDIR /root
CMD ["sleep", "infinity"]
