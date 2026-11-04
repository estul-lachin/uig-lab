# Reference solution for wazuh-intrusion-capstone.
set -eu
umask 022
O=/var/ossec
AL=$O/logs/alerts/alerts.json
for _ in $(seq 1 60); do [ -f /var/lib/lab-feed-done ] && break; sleep 5; done
all() { jq -c 'select(.location | test("^/var/log/lab/|^syscheck$"))' $AL; }
ips() { all | jq -r --arg r "$1" 'select(.rule.id == $r) | .data.srcip' | sort -u; }
count() { all | jq -r --arg r "$1" --arg ip "$2" 'select(.rule.id == $r and ($ip == "" or .data.srcip == $ip)) | .rule.id' | wc -l | tr -d ' '; }

ip=$(comm -12 <(ips 31103) <(ips 5710) | comm -12 - <(ips 5715) | head -n1)
login=$(all | jq -c --arg ip "$ip" 'select(.rule.id == "5715" and .data.srcip == $ip)' | head -n1)
login_t=$(echo "$login" | jq -r .timestamp)
unit=$(all | jq -r --arg t "$login_t" 'select(.rule.id == "554" and .timestamp > $t) | .syscheck.path' | grep '\.service$' | head -n1)
runs=$(sed -n 's/^ExecStart=//p' "$unit" | awk '{print $1}')
leak=$(all | jq -r --arg ip "$ip" 'select(.rule.id == "31106" and .data.srcip == $ip) | .data.url' | head -n1)
{
  echo "ATTACKER_IP=$ip"
  echo "RECON_31103=$(count 31103 "$ip")"
  echo "BRUTE_5710=$(count 5710 "$ip")"
  echo "BREACHED_ACCOUNT=$(echo "$login" | jq -r .data.dstuser)"
  echo "PERSISTENCE_FILE=$unit"
  echo "NOISE_5710=$(count 5710 "")"
  echo "LEAK_RULE=31106"
  echo "LEAK_TABLE=$(echo "$leak" | sed -n 's/.*%20from%20\([A-Za-z_]*\).*/\1/p')"
  echo "STORM_RULE=$(all | jq -r 'select(.rule.groups | index("authentication_failures")) | .rule.id' | sort -u | head -n1)"
  echo "PERSIST_RUNS=$runs"
  echo "C2_PORT=$(grep -o '/dev/tcp/[^ ;]*' "$runs" | head -n1 | sed 's#.*/##')"
} > /root/answers.txt

cat > $O/etc/rules/local_rules.xml <<'XML'
<!-- Lab rule: a login from an address that failed before, however slowly it guessed -->
<group name="local,lab,sshd,">
  <rule id="100350" level="12" timeframe="3600">
    <if_sid>5715</if_sid>
    <if_matched_sid>5710</if_matched_sid>
    <same_srcip />
    <description>sshd: $(dstuser) logged in from $(srcip), which tried a non-existent user within the hour.</description>
    <mitre><id>T1110.001</id></mitre>
    <group>authentication_success,</group>
  </rule>
</group>
XML
chown wazuh:wazuh $O/etc/rules/local_rules.xml
$O/bin/wazuh-analysisd -t
$O/bin/wazuh-control restart >/dev/null
for _ in $(seq 1 60); do printf 'x\n' | $O/bin/wazuh-logtest -q >/dev/null 2>&1 && break; sleep 3; done
