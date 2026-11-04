# Reference solution for wazuh-rootcheck-trojans.
set -eu
umask 022
O=/var/ossec
AL=$O/logs/alerts/alerts.json
for _ in $(seq 1 60); do [ -f /var/lib/lab-feed-done ] && break; sleep 5; done
END=$(cat /var/lib/lab-feed-done)
rc() { jq -c --argjson end "$END" 'select(.rule.groups | index("rootcheck")) | select(.agent.id != "000") | select((.timestamp[0:19] + "Z" | fromdate) <= $end)' $AL; }
ranking=$(rc | jq -r 'select(.rule.id == "510") | .agent.name' | sort | uniq -c | sort -k1,1rn -k2)
worst=$(echo "$ranking" | awk 'NR == 1 {print $2}')
trojans=$(rc | jq -r 'select(.data.title | startswith("Trojaned")) | "\(.agent.name) \(.data.file)"')
file_of() { echo "$trojans" | awk -v h="$1" '$1 == h {print $2; exit}'; }
quiet=$(echo "$ranking" | awk '{print $2}' | while read -r h; do [ -n "$(file_of "$h")" ] && echo "$h"; done | tail -n1)
{
  echo "RC_TOTAL=$(rc | jq -r .rule.id | grep -cx 510)"
  echo "WORST_HOST=$worst"
  echo "WORST_COUNT=$(echo "$ranking" | awk 'NR == 1 {print $1}')"
  echo "TROJAN_FILE=$(file_of "$worst")"
  echo "SECOND_HOST=$(echo "$ranking" | awk 'NR == 2 {print $2}')"
  echo "KERNEL_RULE=$(rc | jq -r .rule.id | sort -u | grep -vx 510 | head -n1)"
  echo "WORST_ALL=$(rc | jq -r .agent.name | grep -cx "$worst")"
  echo "TROJAN_HOSTS=$(echo "$trojans" | awk '{print $1}' | sort -u | wc -l | tr -d ' ')"
  echo "QUIET_TROJAN_HOST=$quiet"
  echo "QUIET_TROJAN_FILE=$(file_of "$quiet")"
} > /root/answers.txt

cat > $O/etc/rules/local_rules.xml <<'XML'
<!-- Lab rule: rootcheck found a system binary that carries a known trojan signature -->
<group name="local,lab,rootcheck,">
  <rule id="100320" level="12">
    <if_sid>510</if_sid>
    <match>^Trojaned version of file </match>
    <description>Trojaned system binary: $(file)</description>
    <mitre><id>T1554</id></mitre>
  </rule>
</group>
XML
chown wazuh:wazuh $O/etc/rules/local_rules.xml
$O/bin/wazuh-analysisd -t
$O/bin/wazuh-control restart >/dev/null
for _ in $(seq 1 60); do printf 'x\n' | $O/bin/wazuh-logtest -q >/dev/null 2>&1 && break; sleep 3; done
