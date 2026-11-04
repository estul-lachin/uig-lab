# Reference solution for wazuh-web-attack-triage.
set -eu
umask 022
O=/var/ossec
AL=$O/logs/alerts/alerts.json
LOGF=/var/log/lab/web-server-01-access.log
for _ in $(seq 1 60); do [ -f /var/lib/lab-feed-done ] && break; sleep 5; done
web() { jq -c --arg l "$LOGF" 'select(.location == $l)' $AL; }
ids() { web | jq -r .rule.id; }
tech() { web | jq -c 'select(.rule.id | IN("31103", "31104", "31105"))'; }
rank() { jq -r .data.srcip | sort | uniq -c | sort -k1,1rn -k2; }

top=$(tech | rank | awk 'NR == 1 {print $2}')
leak=$(grep -iE '(\.\.|%2e%2e)(%2f|%5c)' $LOGF | awk '$9 == 200 {print $7}' | head -n1 \
  | sed -e 's/.*file=//' -e 's/%2[Ff]/\//g' -e 's#^\(\.\./\)*#/#')
{
  echo "SQLI_31103=$(ids | grep -cx 31103)"
  echo "XSS_31105=$(ids | grep -cx 31105)"
  echo "TRAVERSAL_31104=$(ids | grep -cx 31104)"
  echo "TOP_ATTACKER=$top"
  echo "TOP_ATTACKER_COUNT=$(tech | jq -r .data.srcip | grep -cx "$top")"
  echo "SUCCESS_RULE=$(web | jq -r 'select(.rule.description | test("returned code 200")) | .rule.id' | head -n1)"
  echo "SUCCESS_IP=$(web | jq -r 'select(.rule.id == "31106") | .data.srcip' | head -n1)"
  echo "GROUP_TOP=$(web | jq -c 'select(.rule.groups | index("attack"))' | rank | awk 'NR == 1 {print $2}')"
  echo "ENCODED_400=$(web | jq -r 'select(.rule.id == "31101") | .data.url' | grep -ciE '(\.\.|%2e%2e)(%2f|%5c)')"
  echo "LEAKED_FILE=$leak"
} > /root/answers.txt

cat > $O/etc/rules/local_rules.xml <<'XML'
<!-- Lab rule: directory traversal with URL-encoded separators, which 31104 does not list -->
<group name="local,lab,web,accesslog,">
  <rule id="100330" level="10">
    <!-- 4xx lines go through 31101; 2xx/3xx lines stay on 31100 or 31108 -->
    <if_sid>31100, 31101, 31108</if_sid>
    <url type="pcre2">(?i)(\.\.|%2e%2e)(%2f|%5c)|%2e%2e[/\\]</url>
    <description>Directory traversal with URL-encoded separators.</description>
    <mitre><id>T1083</id></mitre>
    <group>attack,</group>
  </rule>
</group>
XML
chown wazuh:wazuh $O/etc/rules/local_rules.xml
$O/bin/wazuh-analysisd -t
$O/bin/wazuh-control restart >/dev/null
for _ in $(seq 1 60); do printf 'x\n' | $O/bin/wazuh-logtest -q >/dev/null 2>&1 && break; sleep 3; done
