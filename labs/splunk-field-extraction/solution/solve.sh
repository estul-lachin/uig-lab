# Reference solution for splunk-field-extraction.
set -eu
API=https://splunk:8089
AUTH=admin:Lab-Splunk-2026
F='search index=main sourcetype=linux_secure "Failed password"'
q() { curl -sk -u "$AUTH" --max-time 90 "$API/services/search/jobs/export" --data-urlencode "search=$1" \
        -d output_mode=csv -d earliest_time=0 | tail -n +2 | tr -d '"\r'; }
for _ in $(seq 1 90); do [ "$(q '| tstats count where index=main')" = 5645 ] && break; sleep 5; done

U='| rex "for (?:invalid user )?(?<user>\S+) from"'
S='| rex "from (?<src>\d+(?:\.\d+){3}) port"'
top=$(q "$F $U | top limit=1 user | table user count")
{
  echo "ERX_DISTINCT=$(q '| windbag | erex firstwords examples="Unë, Կրնամ" | stats dc(firstwords)')"
  echo "URI_PATHS=$(q 'search index=main sourcetype=access_combined | rex "\"\w+ (?<path>/[^ ?]*)" | stats dc(path)')"
  echo "TOP_USER=${top%%,*}"
  echo "TOP_USER_FAILS=${top##*,}"
  echo "INTERNAL_FAILS=$(q "$F $S | regex src=\"^10\\.\" | stats count")"
  echo "DISTINCT_ATTACKERS=$(q "$F $S | stats dc(src)")"
  echo "INSIDER_IP=$(q "$F \"invalid user\" $S | regex src=\"^10\\.\" | top limit=1 src | table src")"
  echo "WIZARD_FIELDS=yes"
} > /root/answers.txt

# What the wizard saves: an inline EXTRACT on the sourcetype
curl -sk -u "$AUTH" -o /dev/null -X DELETE "$API/servicesNS/admin/search/data/props/extractions/linux_secure%20%3A%20EXTRACT-src" || true
curl -sk -u "$AUTH" -o /dev/null "$API/servicesNS/admin/search/data/props/extractions" \
  -d stanza=linux_secure -d type=EXTRACT -d name=src --data-urlencode 'value=from (?<src>\d{1,3}(?:\.\d{1,3}){3}) port'
