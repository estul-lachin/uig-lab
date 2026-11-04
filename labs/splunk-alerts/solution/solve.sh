# Reference solution for splunk-alerts: the two alerts over REST, then wait for the WAF and the throttle.
set -eu
umask 022
API=https://splunk:8089
AUTH=admin:Lab-Splunk-2026
WAF=/var/log/waf/requests.jsonl
spl() { curl -sk -u $AUTH --max-time 90 "$API/services/search/jobs/export" --data-urlencode "search=$1" -d output_mode=csv -d earliest_time=0 | tail -n +2 | tr -d '"\r'; }
for _ in $(seq 1 60); do [ "$(spl '| tstats count where index=main')" = 5286 ] && break; sleep 5; done

# Private alerts of admin in the Search app (what Save As > Alert > Private creates)
SS=$API/servicesNS/admin/search/saved/searches
curl -sk -u $AUTH -o /dev/null -X DELETE "$SS/SSH%20Brute%20Force" || true
curl -sk -u $AUTH -o /dev/null -X DELETE "$SS/Server%20Error" || true
curl -skf -u $AUTH -o /dev/null "$SS" --data-urlencode "name=SSH Brute Force" \
  --data-urlencode 'search=index=main sourcetype=linux_secure "Failed password" | rex "from (?<src>\S+)" | stats count by src | where count>10' \
  -d is_scheduled=1 --data-urlencode 'cron_schedule=*/2 * * * *' -d dispatch.earliest_time=0 -d dispatch.latest_time=now \
  --data-urlencode 'alert_type=number of events' --data-urlencode 'alert_comparator=greater than' -d alert_threshold=0 \
  -d alert.digest_mode=0 -d alert.suppress=1 -d alert.suppress.fields=src -d alert.suppress.period=1h \
  -d alert.track=1 -d alert.severity=3 -d actions=webhook -d action.webhook=1 \
  --data-urlencode action.webhook.param.url=http://waf:8088/ban
curl -skf -u $AUTH -o /dev/null "$SS" --data-urlencode "name=Server Error" \
  --data-urlencode 'search=index=main sourcetype=access_combined status>=500' \
  -d is_scheduled=1 --data-urlencode 'cron_schedule=* * * * *' -d dispatch.earliest_time=rt -d dispatch.latest_time=rt \
  -d alert_type=always -d alert.digest_mode=0 -d alert.suppress=1 -d alert.suppress.fields=uri_path \
  -d alert.suppress.period=10m -d alert.track=1 -d alert.severity=4

# The first scheduled run posts to the WAF, the next one is throttled (up to about 5 minutes)
sup=""
for _ in $(seq 1 60); do
  sup=$(spl 'search index=_internal sourcetype=scheduler savedsearch_name="SSH Brute Force" suppressed>0 | stats max(suppressed)')
  [ -n "$sup" ] && break; sleep 10
done
banned=$(jq -r 'select(.body.search_name? == "SSH Brute Force") | .body.result.src' $WAF | sort -u | wc -l | tr -d ' ')
{
  echo "CRON_2MIN=*/2 * * * *"
  echo "ALERT_TYPE=Scheduled"
  echo "TRIGGER=Per-Result"
  echo "THROTTLE_FIELD=uri_path"
  echo "ERROR_EVENTS=$(spl 'search index=main sourcetype=access_combined status>=500 | stats count')"
  echo "BANNED_IPS=$banned"
  echo "RUN_SUPPRESSED=$sup"
  echo "RT_TRIGGERED=0"
  echo "ENDPOINTS_MAX=$(spl 'search index=main sourcetype=access_combined status>=500 | stats dc(uri_path)')"
  echo "CRON_BUSINESS=*/15 8-17 * * 1-5"
} > /root/answers.txt
