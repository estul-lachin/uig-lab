# Reference solution for wazuh-fim-intrusion.
set -eu
umask 022
O=/var/ossec
AL=$O/logs/alerts/alerts.json
for _ in $(seq 1 60); do [ -f /var/lib/lab-intrusion-done ] && break; sleep 5; done
END=$(cat /var/lib/lab-intrusion-done)
fim() { jq -c --argjson end "$END" 'select(.rule.groups | index("syscheck")) | select(.syscheck.path) | select((.timestamp[0:19] + "Z" | fromdate) <= $end)' $AL; }
count() { fim | jq -r '.rule.id' | grep -cx "$1"; }

persist=$(fim | jq -r 'select(.rule.id == "554") | .syscheck.path' | grep '^/etc/cron\.d/' | head -n1)
setting=$(fim | jq -r 'select(.syscheck.path == "/etc/ssh/sshd_config") | .syscheck.diff' | sed -n 's/^> *\([A-Za-z]*\) .*/\1/p' | head -n1)
exfil=$(fim | jq -r 'select(.rule.id == "550") | .syscheck.diff' | grep -oE 'https?://[0-9.]+' | head -n1 | sed 's#.*//##')
loaded=$(fim | jq -r 'select(.syscheck.path == "/var/www/html/index.php") | .syscheck.diff' | sed -n 's#.*__DIR__ \. "\(/[^"]*\)".*#\1#p' | head -n1)
runs=$(awk '!/^#/ && NF >= 7 {print $7}' "$persist" | head -n1)
{
  echo "MODIFIED_550=$(count 550)"
  echo "ADDED_554=$(count 554)"
  echo "DELETED_553=$(count 553)"
  echo "PERSISTENCE_FILE=$persist"
  echo "FIM_TOTAL=$(fim | wc -l | tr -d ' ')"
  echo "SSHD_SETTING=$setting"
  echo "EXFIL_HOST=$exfil"
  echo "WEBSHELL=/var/www/html$loaded"
  echo "CRON_RUNS=$runs"
} > /root/answers.txt

cat > $O/etc/rules/local_rules.xml <<'XML'
<!-- Lab rule: a new file in a cron directory is persistence until proven otherwise -->
<group name="local,lab,syscheck,">
  <rule id="100310" level="12">
    <if_sid>554</if_sid>
    <field name="file" type="pcre2">^/etc/cron\.(d|daily|hourly|weekly|monthly)/</field>
    <description>New cron job file: $(file)</description>
    <mitre><id>T1053.003</id></mitre>
  </rule>
</group>
XML
chown wazuh:wazuh $O/etc/rules/local_rules.xml
$O/bin/wazuh-analysisd -t
$O/bin/wazuh-control restart >/dev/null
