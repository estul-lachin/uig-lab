# Reference solution for splunk-ai-soc-investigation.
set -eu
API=https://splunk:8089
AUTH=admin:Lab-Splunk-2026
q() { curl -sk -u "$AUTH" --max-time 90 "$API/services/search/jobs/export" --data-urlencode "search=$1" \
        -d output_mode=csv -d earliest_time=0 | tail -n +2 | tr -d '"\r'; }
for _ in $(seq 1 90); do [ "$(q '| tstats count where index=web OR index=network OR index=linux')" = 5912 ] && break; sleep 5; done

W='search index=web sourcetype=access_combined'
att=$(q "$W UNION SELECT | stats count by clientip | sort - count | head 1 | table clientip")
param=$(q "$W clientip=$att UNION SELECT | rex field=uri \"[?&](?<p>[a-z]+)=[^&]*UNION\" | stats count by p | head 1 | table p")
table=$(q "$W clientip=$att UNION SELECT | sort - bytes | head 1 | rex field=uri \"FROM\\+(?<t>[a-z_]+)\" | table t")
shell=$(q "$W clientip=$att useragent=\"curl*\" uri=\"*c=*\" | stats count by uri_path | sort - count | head 1 | table uri_path")
payload=$(q "$W clientip=$att wget | eval u=urldecode(uri) | rex field=u \"-O (?<p>\\S+)\" | table p")
acct=$(q 'search index=linux sourcetype=linux_secure "Accepted password" | rex "for (?<u>\S+) from" | table u')
port=$(q 'search index=network sourcetype=suricata src_ip=10.40.2.13 | table dest_port')
{
  echo "ATTACKER_IP=$att"
  echo "INJECTED_PARAM=$param"
  echo "DUMPED_TABLE=$table"
  echo "WEB_SHELL=${shell##*/}"
  echo "PAYLOAD_PATH=$payload"
  echo "SSH_ACCOUNT=$acct"
  echo "C2_PORT=$port"
  echo "WRONG_CLAIMS=3,5,6"
} > /root/case/answers.txt

# The agent's account: search only, three indexes, nothing inherited
curl -sk -u "$AUTH" -o /dev/null -X DELETE "$API/services/authentication/users/ai-agent" || true
curl -sk -u "$AUTH" -o /dev/null -X DELETE "$API/services/authorization/roles/soc_agent_ro" || true
curl -sk -u "$AUTH" -o /dev/null "$API/services/authorization/roles" -d name=soc_agent_ro -d capabilities=search \
  -d srchIndexesAllowed=web -d srchIndexesAllowed=network -d srchIndexesAllowed=linux -d srchIndexesDefault=web
curl -sk -u "$AUTH" -o /dev/null "$API/services/authentication/users" -d name=ai-agent -d password=Agent-RO-2026 -d roles=soc_agent_ro
