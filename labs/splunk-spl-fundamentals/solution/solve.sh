# Reference solution for splunk-spl-fundamentals: the same searches over the REST API.
set -euo pipefail
API=https://splunk:8089
AUTH=admin:Lab-Splunk-2026
q() { curl -sk -u "$AUTH" --max-time 60 "$API/services/search/jobs/export" --data-urlencode "search=$1" \
        -d output_mode=csv -d earliest_time=0 | tail -n +2 | tr -d '"\r'; }
n() { q "search index=main $1 | stats count"; }

for _ in $(seq 1 90); do [ "$(q '| tstats count where index=main')" = 5286 ] && break; sleep 5; done

W=sourcetype=access_combined
{
  echo "TERM_FAILED=$(n 'sourcetype=linux_secure failed')"
  echo "PHRASE_ROOT=$(n 'sourcetype=linux_secure "failed password for root"')"
  echo "OK_OR_NOT_MODIFIED=$(n "$W (status=200 OR status=304)")"
  echo "LOWERCASE_OR=$(n "$W status=200 or status=304")"
  echo "NOT_200=$(n "$W NOT status=200")"
  echo "COUNT_404=$(n "$W status=404")"
  echo "BIG_RESPONSES=$(n "$W bytes>=20000")"
  echo "DISTINCT_CLIENTS=$(q "search index=main $W | dedup clientip | stats count")"
  echo "FIRST_ERROR_PATH=$(q "search index=main $W status>=500 | sort 0 _time | head 1 | table uri_path")"
} > /root/answers.txt

curl -sk -u "$AUTH" "$API/servicesNS/admin/search/saved/searches/web-errors" -X DELETE -o /dev/null || true
curl -sk -u "$AUTH" "$API/servicesNS/admin/search/saved/searches" -o /dev/null -d name=web-errors \
  --data-urlencode "search=index=main $W status>=400 | stats count BY uri_path | rename uri_path AS path | sort - count" \
  -d dispatch.earliest_time=0
