# Checks for syslog-collector (see templates/lab/check.sh for the rules).
# The senders log every 2 seconds, so the checks look at what arrives right now.

D=/var/log/siem
A=/root/answers.txt
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
_fresh() { [ -s "$1" ] && [ $(( $(date +%s) - $(stat -c %Y "$1") )) -le 20 ]; }
# _only FILE MARKER: recent lines all carry this source's marker, and none of the others'
_only() {
  local f=$1 m=$2 others="FW |HTTP/1.1|EventID=|cam-7"
  others=$(echo "$others" | tr "|" "\n" | grep -vxF "$m" | paste -sd "|")
  _fresh "$f" && tail -n 30 "$f" | grep -qF "$m" && ! tail -n 30 "$f" | grep -qE "$others"
}

section "1. Listening"
check "rsyslogd listens on 514/udp" 'pgrep -x rsyslogd >/dev/null && [ -n "$(ss -Huln "sport = :514")" ]' "module(load=\"imudp\") and input(type=\"imudp\" port=\"514\")"
check "rsyslogd listens on 514/tcp too" 'pgrep -x rsyslogd >/dev/null && [ -n "$(ss -Htln "sport = :514")" ]' "One device sends over TCP: imtcp"
check "The configuration is valid" 'rsyslogd -N1 >/dev/null 2>&1' "rsyslogd -N1 shows the file and line of an error"

section "2. One file per log source"
check "$D/firewall.log gets the firewall's logs only" '_only $D/firewall.log "FW "' "if \$fromhost-ip == \"10.253.80.21\" then ..."
check "$D/web.log gets the web server's logs only" '_only $D/web.log "HTTP/1.1"' "It only arrives once TCP is open"
check "$D/windows.log gets the domain controller's logs only" '_only $D/windows.log "EventID="' "10.253.80.23"
check "$D/unknown.log gets everything from unregistered sources" '_only $D/unknown.log "cam-7"' "else: route what no rule claimed here, then stop"
check "Remote logs don't end up in the local syslog" '_fresh $D/firewall.log && ! tail -n 200 /var/log/syslog 2>/dev/null | grep -qE "FW |HTTP/1.1|EventID=|cam-7"' \
  "Files in /etc/rsyslog.d load in name order: yours must come before 50-default.conf, and each route must stop"

section "3. A DSM for the firewall"
J=$D/firewall.json
check "$J gets one JSON object per firewall line" '_fresh $J && tail -n 20 $J | jq -e . >/dev/null 2>&1' "A template of type list: constants and properties"
check "Each has src, dst, dpt and action with the right values" '_fresh $J && tail -n 20 $J | jq -e -s "length > 0 and all(.[]; (.src | test(\"^[0-9.]+$\")) and (.dst | test(\"^[0-9.]+$\")) and ((.dpt | tostring) | test(\"^[0-9]+$\")) and (.action | test(\"^(ALLOW|DROP)$\")))" >/dev/null' \
  "property(name=\"msg\" regex.type=\"ERE\" regex.expression=\"SRC=([0-9.]+)\" regex.submatch=\"1\")"
check "The JSON matches the raw lines" '_fresh $J && [ "$(tail -n 40 $D/firewall.log | grep -oE "SRC=[0-9.]+" | sort -u | sed s/SRC=// | grep -c .)" -gt 0 ] && tail -n 40 $D/firewall.log | grep -oE "SRC=[0-9.]+" | sed s/SRC=// | sort -u | grep -qxF "$(tail -n 1 $J | jq -r .src)"' \
  "The newest src in the JSON should be one of the recent SRC values in the raw file"

section "4. Using the parsed data"
check "SCANNER_IP is the source with the most DROPs" '[ "$(_kv $A SCANNER_IP)" = 203.0.113.50 ]' "jq -r 'select(.action == \"DROP\") | .src' firewall.json | sort | uniq -c | sort -rn"
check "SCANNED_PORTS counts its distinct destination ports in your JSON" 'v=$(_kv $A SCANNED_PORTS); [ -n "$v" ] && [ "$v" -gt 0 ] && t=$(jq -r "select(.src == \"203.0.113.50\") | .dpt" $J 2>/dev/null | sort -u | wc -l) && [ "$v" -le "$t" ] && [ $(( t - v )) -le 30 ]' \
  "It keeps growing; a value from the last minute counts"
check "WEB_TRANSPORT is how the web server sends" '[ "$(_kv $A WEB_TRANSPORT | tr A-Z a-z)" = tcp ]' "Watch ss, or what changed when you opened which port"
check "UNKNOWN_SOURCE is the address of the unregistered device" '[ "$(_kv $A UNKNOWN_SOURCE)" = 10.253.80.66 ]' "Add fromhost-ip to the unknown.log template, or look at the raw packets"
