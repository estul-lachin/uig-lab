# Reference solution for suricata-ids-rules. Runs as root inside the container.
#
# Write three Suricata signatures for the three attacks in the capture, run
# Suricata offline against the pcap, and the alerts land in eve.json. Also fill
# in the IDS concept answers.
set -euo pipefail

# 1. Signatures: alert on the SQLi tautology, the path traversal, and the scanner
#    User-Agent. Local sids start at 1000000; http.uri / http.user_agent are the
#    sticky buffers for the URL and the UA header.
cat > /root/local.rules <<'RULES'
alert http any any -> any any (msg:"LARKSPUR SQLi boolean tautology"; flow:to_server; http.uri; content:"'1'='1"; nocase; sid:1000001; rev:1;)
alert http any any -> any any (msg:"LARKSPUR path traversal"; flow:to_server; http.uri; content:"../"; sid:1000002; rev:1;)
alert http any any -> any any (msg:"LARKSPUR scanner user-agent"; flow:to_server; http.user_agent; content:"EvilScan"; nocase; sid:1000003; rev:1;)
RULES

# 2. Run Suricata offline against the capture; EVE events go to /var/log/suricata/eve.json.
mkdir -p /var/log/suricata
suricata -r /opt/pcaps/larkspur-traffic.pcap -S /root/local.rules -l /var/log/suricata >/dev/null 2>&1

# 3. Concept answers.
cat > /root/answers.txt <<'EOF'
PASSIVE_COPY=SPAN/mirror port (or network TAP)
PASSIVE_TOOL=Zeek
OUTPUT_FILE=eve.json
EOF
