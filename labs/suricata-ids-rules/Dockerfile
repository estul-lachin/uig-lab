# Stage 1: craft the attack capture with scapy. Kept out of the final image so
# the generator and scapy never ship in the lab container.
FROM ubuntu:24.04 AS gen
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3-scapy ca-certificates \
 && rm -rf /var/lib/apt/lists/*
RUN mkdir /out
COPY gen/gen_capture.py /gen/gen_capture.py
RUN python3 /gen/gen_capture.py

# Stage 2: the lab box - Suricata plus jq for reading EVE JSON.
FROM ubuntu:24.04
RUN apt-get update \
 && apt-get install -y --no-install-recommends suricata jq ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /var/log/suricata /opt/pcaps

COPY --from=gen /out/larkspur-traffic.pcap /opt/pcaps/larkspur-traffic.pcap

# Seed the learner's working rules file with the rule anatomy and NO active
# rules (the one example is commented out), so a fresh environment passes nothing.
RUN printf '%s\n' \
  '# Suricata rules for the Larkspur Books investigation.' \
  '# Write your detection signatures below, one per line.' \
  '#' \
  '# Anatomy:  action header options' \
  '#   alert http any any -> any any (msg:"..."; flow:to_server; http.uri; content:"..."; nocase; sid:1000001; rev:1;)' \
  '#' \
  '# - action:  alert (IDS) or drop (inline IPS)' \
  '# - options: msg (label), content (bytes to match), sid (UNIQUE id; use 1000000+), rev' \
  '# - sticky buffers: http.uri matches the URL, http.user_agent matches the UA header' \
  '#' \
  '# Example (commented out - write your own):' \
  "#   alert http any any -> any any (msg:\"TEST\"; http.uri; content:\"/admin\"; sid:1000009; rev:1;)" \
  > /root/local.rules

RUN printf '%s\n' \
  '# IDS/IPS concepts - fill these in (one word or short phrase each).' \
  '' \
  '# PASSIVE_COPY: what feeds a passive IDS a copy of traffic it cannot block?' \
  '#   (the network device/port that mirrors traffic)' \
  'PASSIVE_COPY=' \
  '' \
  '# PASSIVE_TOOL: which of Suricata / Snort / Zeek is passive-only (no IPS mode)?' \
  'PASSIVE_TOOL=' \
  '' \
  "# OUTPUT_FILE: the JSON file Suricata writes its events (incl. alerts) to?" \
  'OUTPUT_FILE=' \
  > /root/answers.txt

RUN echo 'echo "Lab suricata-ids-rules: capture at /opt/pcaps/larkspur-traffic.pcap. Write rules in /root/local.rules, run: suricata -r /opt/pcaps/larkspur-traffic.pcap -S /root/local.rules -l /var/log/suricata  then read /var/log/suricata/eve.json. Tasks: labs/suricata-ids-rules/README.md. Check from the host: ./lab check suricata-ids-rules"' >> /root/.bashrc

WORKDIR /root
CMD ["sleep", "infinity"]
