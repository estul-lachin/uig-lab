# Reference solution for splunk-bruteforce-response: the answers from SPL, the alert over REST.
set -eu
umask 022
API=https://splunk:8089
AUTH=admin:Lab-Splunk-2026
SOAR=/var/log/soar/requests.jsonl
NAME="SSH Brute Force - Successful Authentication"
SEC="index=main sourcetype=linux_secure"
SRC='rex "from (?<src>\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})"'
spl() { curl -sk -u $AUTH --max-time 90 "$API/services/search/jobs/export" --data-urlencode "search=$1" -d output_mode=csv -d earliest_time=0 | tail -n +2 | tr -d '"\r'; }
for _ in $(seq 1 60); do [ "$(spl '| tstats count where index=main')" = 1058 ] && break; sleep 5; done

BOTH="search $SEC (\"Failed password\" OR \"Accepted password\") | $SRC | stats count(eval(searchmatch(\"Failed password\"))) AS fails count(eval(searchmatch(\"Accepted password\"))) AS successes by src"
row=$(spl "$BOTH | where fails>50 AND successes>0 | table src fails successes")
loud=${row%%,*}
slow=$(spl "$BOTH | where fails>10 AND successes>0 AND src!=\"$loud\" | fields src")
# The spray: many sources, few guesses each, and a success on the account
spray=$(spl "search $SEC (\"Failed password\" OR \"Accepted password\") | rex \"for (?:invalid user )?(?<user>\S+) from (?<src>\S+)\" | stats count(eval(searchmatch(\"Failed password\"))) AS fails dc(src) AS sources count(eval(searchmatch(\"Accepted password\"))) AS successes by user | eval per_source=fails/sources | where successes>0 AND sources>10 AND per_source<5 | fields user")
{
  echo "ATTACKER=$loud"
  echo "BURST=$(echo "$row" | cut -d, -f2)"
  echo "COMPROMISED=$(spl "search $SEC \"Accepted password\" \"from $loud \" | rex \"for (?<u>\S+) from\" | stats count by u | fields u")"
  echo "SUCCESSES=$(echo "$row" | cut -d, -f3)"
  echo "MOST_TARGETED=$(spl "search $SEC \"Failed password\" | rex \"for (?:invalid user )?(?<user>\S+) from\" | top limit=1 user | table user")"
  echo "SLOW_BREACH=$slow"
  echo "SPRAY_USER=$spray"
  echo "SPRAY_SOURCES=$(spl "search $SEC \"Failed password for $spray \" | $SRC | stats dc(src)")"
  echo "SPRAY_WINNER=$(spl "search $SEC \"Accepted password for $spray \" | $SRC | fields src | head 1 | table src")"
  echo "FALSE_POSITIVES=$(spl "$BOTH | where fails>0 AND successes>0 AND cidrmatch(\"10.0.0.0/8\", src) | stats count")"
} > /root/answers.txt

SS=$API/servicesNS/admin/search/saved/searches
curl -sk -u $AUTH -o /dev/null -X DELETE "$SS/$(printf '%s' "$NAME" | jq -sRr @uri)" || true
curl -skf -u $AUTH -o /dev/null "$SS" --data-urlencode "name=$NAME" \
  --data-urlencode "search=$SEC (\"Failed password\" OR \"Accepted password\") | $SRC | stats count(eval(searchmatch(\"Failed password\"))) AS fails count(eval(searchmatch(\"Accepted password\"))) AS successes by src | where fails>0 AND successes>0 AND NOT cidrmatch(\"10.0.0.0/8\", src)" \
  -d is_scheduled=1 --data-urlencode 'cron_schedule=*/15 * * * *' -d dispatch.earliest_time=0 -d dispatch.latest_time=now \
  --data-urlencode 'alert_type=number of events' --data-urlencode 'alert_comparator=greater than' -d alert_threshold=0 \
  -d alert.digest_mode=0 -d alert.suppress=1 -d alert.suppress.fields=src -d alert.suppress.period=1h \
  -d alert.track=1 -d alert.severity=4 -d actions=webhook -d action.webhook=1 \
  --data-urlencode action.webhook.param.url=http://soar:8088/ban
# Run it once now with its actions, instead of waiting for the next quarter hour
curl -skf -u $AUTH -o /dev/null -X POST "$SS/$(printf '%s' "$NAME" | jq -sRr @uri)/dispatch" -d trigger_actions=1
for _ in $(seq 1 30); do [ "$(jq -r .body.result.src $SOAR 2>/dev/null | sort -u | wc -l)" -ge 3 ] && break; sleep 5; done
echo "BANNED=$(jq -r --arg n "$NAME" 'select(.body.search_name? == $n) | .body.result.src' $SOAR | sort -u | wc -l | tr -d ' ')" >> /root/answers.txt
