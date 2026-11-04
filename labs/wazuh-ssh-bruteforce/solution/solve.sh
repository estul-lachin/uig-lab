# Reference solution for wazuh-ssh-bruteforce.
set -eu
umask 022
O=/var/ossec
AL=$O/logs/alerts/alerts.json
for _ in $(seq 1 60); do [ -f /var/lib/lab-feed-done ] && break; sleep 5; done
ssh() { jq -c 'select(.location == "/var/log/lab/bastion-01.log") | select(.rule.groups | index("syslog"))' $AL; }
ids() { ssh | jq -r .rule.id; }

top=$(ssh | jq -r 'select(.rule.id == "5710") | .data.srcip' | sort | uniq -c | sort -k1,1rn -k2 | awk 'NR == 1 {print $2}')
breach=$(ssh | jq -c --arg ip "$top" 'select(.data.srcip == $ip and (.full_log | test("Accepted ")))')
acct=$(echo "$breach" | jq -r .data.dstuser)
reuse=$(ssh | jq -r --arg u "$acct" --arg ip "$top" 'select(.data.dstuser == $u and (.full_log | test("Accepted ")) and .data.srcip != $ip) | .data.srcip' | grep -v '^10\.' | head -n1)
{
  echo "FAILED_5710=$(ids | grep -cx 5710)"
  echo "TOP_SRC=$top"
  echo "TOP_SRC_5710=$(ssh | jq -r --arg ip "$top" 'select(.rule.id == "5710" and .data.srcip == $ip) | .rule.id' | wc -l | tr -d ' ')"
  echo "COMPROMISED=$acct"
  echo "SUCCESS_5715=$(ids | grep -cx 5715)"
  echo "BREACH_RULE=$(echo "$breach" | jq -r .rule.id)"
  echo "DISTINCT_USERS=$(ssh | jq -r --arg ip "$top" 'select(.rule.id == "5710" and .data.srcip == $ip) | .data.srcuser' | sort -u | wc -l | tr -d ' ')"
  echo "DEPLOY_GUESSES=$(ssh | jq -r --arg ip "$top" --arg u "$acct" 'select(.data.srcip == $ip and .data.dstuser == $u and (.full_log | test("Failed password"))) | .rule.id' | wc -l | tr -d ' ')"
  echo "REUSE_IP=$reuse"
} > /root/answers.txt

cat > $O/etc/rules/local_rules.xml <<'XML'
<!-- Lab rule: staff reach bastion-01 from the internal network only; anything else is an incident -->
<group name="local,lab,sshd,">
  <rule id="100340" level="12">
    <if_sid>5715</if_sid>
    <srcip negate="yes">10.0.0.0/8</srcip>
    <description>sshd: successful login for $(dstuser) from outside the internal network ($(srcip)).</description>
    <mitre><id>T1078</id></mitre>
    <group>authentication_success,</group>
  </rule>
</group>
XML
chown wazuh:wazuh $O/etc/rules/local_rules.xml
$O/bin/wazuh-analysisd -t
$O/bin/wazuh-control restart >/dev/null
for _ in $(seq 1 60); do printf 'x\n' | $O/bin/wazuh-logtest -q >/dev/null 2>&1 && break; sleep 3; done
