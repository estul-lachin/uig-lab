# Reference solution for wazuh-sudo-abuse.
set -eu
umask 022
O=/var/ossec
AL=$O/logs/alerts/alerts.json
for _ in $(seq 1 60); do [ -f /var/lib/lab-feed-done ] && break; sleep 5; done
n() { jq -c "select(.location == \"/var/log/lab/web-server-01.log\") | select($1)" $AL | wc -l; }

top=$(jq -r 'select(.rule.id == "5401") | .data.srcuser' $AL | sort | uniq -c | sort -rn | awk 'NR == 1 {print $2}')
first=$(jq -r --arg u "$top" 'select(.data.srcuser == $u and .data.dstuser == "root" and (.rule.description | test("sudo"))) | select(.rule.id != "5401" and .rule.id != "5404" and .rule.id != "5406") | .rule.id' $AL | sort -u | grep -v 5402 | head -n1)
bin=$(jq -r --arg u "$top" 'select((.rule.id == "5402" or .rule.id == "5403") and .data.srcuser == $u) | .data.command' $AL | head -n1 | awk '{print $1}' | sed 's#.*/##')
backdoor=$(jq -r 'select(.rule.id == "5902") | .full_log' $AL | sed -n 's/.*name=\([^,]*\),.*/\1/p' | head -n1)
{
  echo "FAILED_5401=$(n '.rule.id == "5401"')"
  echo "TOP_FAILER=$top"
  echo "FAILER_5401=$(n ".rule.id == \"5401\" and .data.srcuser == \"$top\"")"
  echo "SUCCESS_5402=$(n '.rule.id == "5402"')"
  echo "FAILER_5402=$(n ".rule.id == \"5402\" and .data.srcuser == \"$top\"")"
  echo "FIRST_TIME_RULE=$first"
  echo "FAILER_ROOT_TOTAL=$(n "(.rule.id == \"5402\" or .rule.id == \"5403\") and .data.dstuser == \"root\" and .data.srcuser == \"$top\"")"
  echo "ESCALATION_BINARY=$bin"
  echo "BACKDOOR_USER=$backdoor"
} > /root/answers.txt

cat > $O/etc/rules/local_rules.xml <<'XML'
<!-- Lab rule: sudo to root into a program that can spawn a shell (GTFOBins) -->
<group name="local,lab,sudo,">
  <rule id="100300" level="12">
    <if_sid>5402, 5403</if_sid>
    <field name="command" type="pcre2">^\S*/(vim?|less|more|find|awk|perl|python3?|bash|sh)(\s|$)</field>
    <!-- 5403 is about the user, not the target: it also fires for a first sudo -u www-data.
         The target (dstuser) is a static field, so it has its own option, <user>. -->
    <user>^root$</user>
    <description>sudo to root into $(command), which can open a root shell</description>
    <mitre><id>T1548.003</id></mitre>
  </rule>
</group>
XML
chown wazuh:wazuh $O/etc/rules/local_rules.xml
$O/bin/wazuh-analysisd -t
$O/bin/wazuh-control restart >/dev/null
for _ in $(seq 1 60); do printf 'x\n' | $O/bin/wazuh-logtest -q >/dev/null 2>&1 && break; sleep 3; done
