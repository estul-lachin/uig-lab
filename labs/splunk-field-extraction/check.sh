# Checks for splunk-field-extraction (see templates/lab/check.sh for the rules).
# Runs on the workstation and asks Splunk over its REST API.

API=https://splunk:8089
AUTH=admin:Lab-Splunk-2026
TOTAL=5645   # 5286 shop events + 359 from bastion-01
A=/root/answers.txt
F='search index=main sourcetype=linux_secure "Failed password"'
IP='\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
_spl() { curl -sk -u $AUTH --max-time 90 "$API/services/search/jobs/export" --data-urlencode "search=$1" -d output_mode=csv -d earliest_time=0 2>/dev/null | tail -n +2 | tr -d '"\r'; }
# Saved (EXTRACT-) field extractions on linux_secure, one regex per line
_extractions() {
  curl -sk -u $AUTH -G "$API/servicesNS/-/-/data/props/extractions" -d output_mode=json -d count=0 2>/dev/null \
    | jq -r '.entry[] | select(.content.stanza == "linux_secure" and .content.type == "Inline") | .content.value'
}

for _ in $(seq 1 60); do [ "$(_spl "| tstats count where index=main")" = "$TOTAL" ] && break; sleep 5; done

section "0. Splunk is ready"
check "Splunk answers and has indexed all $TOTAL events" '[ "$(_spl "| tstats count where index=main")" = $TOTAL ]' \
  "Splunk needs a few minutes after ./lab up (longer the first time, under emulation); run the check again"

section "1. erex and rex"
check "ERX_DISTINCT: distinct firstwords values erex extracts from windbag" '[ "$(_kv $A ERX_DISTINCT)" = "$(_spl "| windbag | erex firstwords examples=\"Unë, Կրնամ\" | stats dc(firstwords)")" ]' \
  "| windbag | erex ... | stats dc(firstwords); Job > Inspect Job shows the rex it wrote"
check "URI_PATHS: distinct paths you extracted from the request line of access_combined" '[ "$(_kv $A URI_PATHS)" = "$(_spl "search index=main sourcetype=access_combined | rex \"\\\"[A-Z]+ (?<p>[^ ?\\\"]+)\" | stats dc(p)")" ]' \
  "The path sits between the method and HTTP/1.1; compare with the uri_path field Splunk already has"

section "2. Failed SSH logons"
check "TOP_USER_FAILS: failed attempts for the most-targeted user name" '[ "$(_kv $A TOP_USER_FAILS)" = "$(_spl "$F | rex \"for (?:invalid user )?(?<u>\\S+) from\" | stats count by u | sort - count | head 1 | table count")" ]' \
  "Some lines say \"for invalid user NAME from\": does your pattern catch them?"
check "TOP_USER: that user name" '[ "$(_kv $A TOP_USER)" = "$(_spl "$F | rex \"for (?:invalid user )?(?<u>\\S+) from\" | stats count by u | sort - count | head 1 | table u")" ]' "The same search"
check "INTERNAL_FAILS: failed attempts from 10.0.0.0/8" '[ "$(_kv $A INTERNAL_FAILS)" = "$(_spl "$F | rex \"from (?<s>$IP)\" | regex s=\"^10\\.\" | stats count")" ]' \
  "rex the address, then | regex src=\"^10\\.\""
check "DISTINCT_ATTACKERS: distinct source addresses of failed attempts" '[ "$(_kv $A DISTINCT_ATTACKERS)" = "$(_spl "$F | rex \"from (?<s>$IP)\" | stats dc(s)")" ]' "dc()"
check "INSIDER_IP: the internal address doing the spraying" '[ "$(_kv $A INSIDER_IP)" = 10.30.5.17 ]' "Internal, many user names that do not exist"

section "3. A saved extraction"
check "linux_secure has a saved extraction that names src, user or portNum" '_extractions | grep -qE "\(\?(P)?<(src|user|portNum)>"' \
  "Fields sidebar > Extract New Fields, sourcetype linux_secure, Regular Expression, Save"
check "...and that field now exists without any rex" '_extractions | grep -qE "\(\?(P)?<(src|user|portNum)>" && [ "$(_spl "search index=main sourcetype=linux_secure \"Failed password\" | eval n = coalesce(src, user, portNum) | where isnotnull(n) | stats count")" -gt 0 ]' \
  "Search sourcetype=linux_secure without rex; the field should be in the sidebar"
check "WIZARD_FIELDS: you saw the new field in the fields bar" '[ "$(_kv $A WIZARD_FIELDS | tr A-Z a-z)" = yes ] && _extractions | grep -qE "\(\?(P)?<(src|user|portNum)>"' "Look at the left sidebar"
