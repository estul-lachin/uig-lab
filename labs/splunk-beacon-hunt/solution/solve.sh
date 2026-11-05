# Reference solution for splunk-beacon-hunt: the answers from SPL, the saved hunt over REST.
set -eu
umask 022
API=https://splunk:8089
AUTH=admin:Lab-Splunk-2026
PX="index=main sourcetype=web_proxy"
spl() { curl -sk -u $AUTH --max-time 120 "$API/services/search/jobs/export" --data-urlencode "search=$1" -d output_mode=csv -d earliest_time=0 | tail -n +2 | tr -d '"\r'; }
for _ in $(seq 1 60); do [ "$(spl '| tstats count where index=main')" = 11163 ] && break; sleep 5; done

# Gaps per pair; regular (cv < 0.3), long-lived, and talked to by fewer than 3 hosts
HUNT="search $PX | sort 0 _time | streamstats current=f last(_time) AS prev by src_ip dest_ip | eval delta=_time-prev | stats count avg(delta) AS gap stdev(delta) AS sd values(dest_port) AS dest_port values(dest_host) AS dest_host by src_ip dest_ip | eval cv=round(sd/gap, 3), gap=round(gap) | where count>50 AND cv<0.3 | eventstats dc(src_ip) AS fanin by dest_ip | where fanin<3 | sort cv | table src_ip dest_ip dest_port dest_host count gap cv"
rows=$(spl "$HUNT")
fast=$(echo "$rows" | head -n1); slow=$(echo "$rows" | sed -n 2p)
fp=$(spl "search $PX | bin span=1m _time | stats count by _time src_ip dest_ip | stats count AS m avg(count) AS a stdev(count) AS s by src_ip dest_ip | eval r=coalesce(s,0)/a | where m>60 AND r<0.3 | stats dc(src_ip) AS n by dest_ip | sort - n | head 1 | table dest_ip")
fphost=$(spl "search $PX dest_ip=$fp | head 1 | table dest_host")
c2=$(echo "$fast" | cut -d, -f2)
{
  echo "BEACON_SRC=$(echo "$fast" | cut -d, -f1)"
  echo "BEACON_DST=$c2"
  echo "BEACON_PORT=$(echo "$fast" | cut -d, -f3)"
  echo "BEACON_GAP=$(echo "$fast" | cut -d, -f6)"
  echo "RECIPE_PAIRS=$(spl "search $PX | bin span=1m _time | stats count by _time src_ip dest_ip | stats count AS m avg(count) AS a stdev(count) AS s by src_ip dest_ip | eval r=coalesce(s,0)/a | where m>60 AND r<0.3 | stats count")"
  echo "FP_HOST=$fphost"
  echo "FP_SOURCES=$(spl "search $PX dest_ip=$fp | stats dc(src_ip)")"
  echo "JITTER_SRC=$(echo "$slow" | cut -d, -f1)"
  echo "JITTER_DST=$(echo "$slow" | cut -d, -f2)"
  echo "JITTER_GAP=$(echo "$slow" | cut -d, -f6)"
  echo "C2_ASN=$(spl "| makeresults | eval dest_ip=\"$c2\" | lookup asn_lookup ip AS dest_ip OUTPUT asn | table asn")"
  echo "TASK_TIME=$(spl "search $PX dest_ip=$c2 | sort - bytes_in | head 1 | eval t=strftime(_time, \"%H:%M\") | table t")"
} > /root/answers.txt

SS=$API/servicesNS/admin/search/saved/searches
curl -sk -u $AUTH -o /dev/null -X DELETE "$SS/beacon_hunt" || true
curl -skf -u $AUTH -o /dev/null "$SS" -d name=beacon_hunt -d dispatch.earliest_time=0 -d dispatch.latest_time=now \
  --data-urlencode "search=${HUNT#search }"
