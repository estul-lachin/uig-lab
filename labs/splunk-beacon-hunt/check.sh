# Checks for splunk-beacon-hunt (see templates/lab/check.sh for the rules).
# Runs on the workstation and asks Splunk over its REST API.

API=https://splunk:8089
AUTH=admin:Lab-Splunk-2026
TOTAL=11163
A=/root/answers.txt
PX="index=main sourcetype=web_proxy"
NAME=beacon_hunt
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
_spl() { curl -sk -u $AUTH --max-time 120 "$API/services/search/jobs/export" --data-urlencode "search=$1" -d output_mode=csv -d earliest_time=0 2>/dev/null | tail -n +2 | tr -d '"\r'; }
# _gap SRC DST: the average gap between connections of a pair, rounded to the second
_gap() { _spl "search $PX src_ip=$1 dest_ip=$2 | sort 0 _time | streamstats current=f last(_time) AS prev | eval d=_time-prev | stats avg(d) AS a | eval a=round(a) | table a"; }
_near() { _a=$(_kv $A "$1"); [ -n "$_a" ] && [ -n "$2" ] && [ "$_a" -ge $(( $2 - 1 )) ] 2>/dev/null && [ "$_a" -le $(( $2 + 1 )) ]; }
_ss() { curl -sk -u $AUTH -G "$API/servicesNS/-/-/saved/searches" -d output_mode=json -d count=0 --data-urlencode "search=name=\"$NAME\"" 2>/dev/null | jq -c --arg n "$NAME" '[.entry[] | select(.name == $n)][0] // empty'; }

for _ in $(seq 1 60); do [ "$(_spl "| tstats count where index=main")" = "$TOTAL" ] && break; sleep 5; done

section "0. Splunk is ready"
check "Splunk answers and has indexed all $TOTAL events" '[ "$(_spl "| tstats count where index=main")" = $TOTAL ]' \
  "Splunk needs a few minutes after ./lab up (longer the first time, under emulation); run the check again"

section "1. Profile and periodicity (the core questions)"
check "BEACON_SRC: the internal host of the 60-second beacon" '[ "$(_kv $A BEACON_SRC)" = 10.60.2.22 ]' "stats count dc(dest_port) by src_ip dest_ip dest_port; a pair with hundreds of connections"
check "BEACON_DST: where it calls" '[ "$(_kv $A BEACON_DST)" = 198.51.100.66 ]' "Only one internal host talks to it"
check "BEACON_PORT: on which port" '[ "$(_kv $A BEACON_PORT)" = 8443 ]' "dest_port"
check "BEACON_GAP: its average gap between connections, in seconds" '_near BEACON_GAP "$(_gap 10.60.2.22 198.51.100.66)"' \
  "sort 0 _time | streamstats current=f last(_time) AS prev | eval delta=_time-prev | stats avg(delta)"
check "RECIPE_PAIRS: pairs the minute-bin recipe flags (active > 60 min, ratio < 0.3)" '[ "$(_kv $A RECIPE_PAIRS)" = "$(_spl "search $PX | bin span=1m _time | stats count by _time src_ip dest_ip | stats count AS m avg(count) AS a stdev(count) AS s by src_ip dest_ip | eval r=coalesce(s,0)/a | where m>60 AND r<0.3 | stats count")" ]' \
  "Run the bin-and-stdev recipe as it is and count its rows"

section "2. Separate C2 from look-alikes"
check "FP_HOST: the regular destination host name that is not C2" '[ "$(_kv $A FP_HOST)" = v10.events.data.microsoft.com ]' "Most of the recipe rows share one dest_ip: dest_host, and how many sources?"
check "FP_SOURCES: how many internal hosts talk to it" '[ "$(_kv $A FP_SOURCES)" = "$(_spl "search $PX dest_host=v10.events.data.microsoft.com | stats dc(src_ip)")" ]' "dc(src_ip): fan-in"
check "JITTER_SRC: the second implanted host" '[ "$(_kv $A JITTER_SRC)" = 10.60.1.15 ]' "Coefficient of variation of the gaps (stdev / avg) below 0.3, outside the telemetry"
check "JITTER_DST: where it calls" '[ "$(_kv $A JITTER_DST)" = 203.0.113.77 ]' "Same search"
check "JITTER_GAP: its average gap, in seconds" '_near JITTER_GAP "$(_gap 10.60.1.15 203.0.113.77)"' "avg(delta) for that pair"

section "3. Hand-off"
check "C2_ASN: the network the 60-second C2 belongs to" '[ "$(_kv $A C2_ASN)" = AS64511 ]' "| lookup asn_lookup ip AS dest_ip OUTPUT asn org"
check "TASK_TIME: when the C2 sent a task (UTC, HH:MM)" '[ "$(_kv $A TASK_TIME)" = 11:42 ]' "A check-in is a few hundred bytes in; look for the one that is not"

section "4. Save the hunt"
check "A saved search named beacon_hunt exists" '[ -n "$(_ss)" ]' "Save As > Report (or Alert), title beacon_hunt"
check "...it returns both implants and nothing else" '[ -n "$(_ss)" ] && [ "$(_spl "| savedsearch $NAME | table src_ip dest_ip | dedup src_ip dest_ip | sort src_ip | eval p=src_ip.\">\".dest_ip | table p" | tr "\n" " ")" = "10.60.1.15>203.0.113.77 10.60.2.22>198.51.100.66 " ]' \
  "One row per pair with src_ip and dest_ip; low gap variation, and leave out what many hosts talk to"
