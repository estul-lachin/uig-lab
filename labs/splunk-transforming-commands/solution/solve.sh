# Reference solution for splunk-transforming-commands.
set -eu
API=https://splunk:8089
AUTH=admin:Lab-Splunk-2026
W="search index=main sourcetype=access_combined"
q() { curl -sk -u "$AUTH" --max-time 90 "$API/services/search/jobs/export" --data-urlencode "search=$1" \
        -d output_mode=csv -d earliest_time=0 | tail -n +2 | tr -d '"\r'; }
for _ in $(seq 1 90); do [ "$(q '| tstats count where index=main')" = 6361 ] && break; sleep 5; done

busy=$(q "$W | top limit=1 clientip | table clientip")
quiet=$(q "$W | rare limit=1 clientip | table clientip")
{
  echo "BUSIEST_CLIENT=$busy"
  echo "BUSIEST_PATHS=$(q "$W clientip=$busy | stats dc(uri_path)")"
  echo "RAREST_CLIENT=$quiet"
  echo "RARE_DOWNLOAD=$(q "$W clientip=$quiet | sort - bytes | head 1 | table uri_path")"
  echo "SERVER_ERRORS=$(q "$W status>=500 | stats count")"
  echo "TOP_403_CLIENT=$(q "$W status=403 | top limit=1 clientip | table clientip")"
} > /root/answers.txt

curl -sk -u "$AUTH" -o /dev/null -X DELETE "$API/servicesNS/admin/search/saved/searches/client-profile" || true
curl -sk -u "$AUTH" -o /dev/null "$API/servicesNS/admin/search/saved/searches" -d name=client-profile \
  --data-urlencode "search=index=main sourcetype=access_combined | stats count AS hits, dc(uri_path) AS paths, values(method) AS methods by clientip | sort - hits" \
  -d dispatch.earliest_time=0
