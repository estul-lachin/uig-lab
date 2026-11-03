# Reference solution for syslog-collector.
set -euo pipefail

cat > /etc/rsyslog.d/10-siem.conf <<'C'
# Receive syslog from the network.
module(load="imudp" threads="1")
input(type="imudp" port="514" name="syslog-udp")
module(load="imtcp" maxSessions="50")
input(type="imtcp" port="514" name="syslog-tcp")

# For unregistered sources, keep their address in front of each line.
template(name="withsource" type="string" string="%fromhost-ip% %timegenerated:::date-rfc3339% %syslogtag%%msg%\n")

# The firewall DSM: raw line -> JSON fields.
template(name="fw_dsm" type="list") {
  constant(value="{")
  constant(value="\"src\":\"")
  property(name="msg" regex.type="ERE" regex.expression="SRC=([0-9.]+)" regex.submatch="1")
  constant(value="\",\"dst\":\"")
  property(name="msg" regex.type="ERE" regex.expression="DST=([0-9.]+)" regex.submatch="1")
  constant(value="\",\"dpt\":")
  property(name="msg" regex.type="ERE" regex.expression="DPT=([0-9]+)" regex.submatch="1" regex.nomatchmode="ZERO")
  constant(value=",\"action\":\"")
  property(name="msg" regex.type="ERE" regex.expression="FW (ALLOW|DROP)" regex.submatch="1")
  constant(value="\"}\n")
}

# The log source table: one route per known address, everything else to unknown.
if $fromhost-ip == "10.253.80.21" then {
  action(type="omfile" file="/var/log/siem/firewall.log")
  action(type="omfile" file="/var/log/siem/firewall.json" template="fw_dsm")
  stop
}
if $fromhost-ip == "10.253.80.22" then { action(type="omfile" file="/var/log/siem/web.log") stop }
if $fromhost-ip == "10.253.80.23" then { action(type="omfile" file="/var/log/siem/windows.log") stop }
if $fromhost-ip != "127.0.0.1" then { action(type="omfile" file="/var/log/siem/unknown.log" template="withsource") stop }
C

rsyslogd -N1 >/dev/null
pkill rsyslogd || true
sleep 1
rsyslogd
sleep 12

J=/var/log/siem/firewall.json
scanner=$(jq -r 'select(.action == "DROP") | .src' "$J" | sort | uniq -c | sort -rn | awk 'NR == 1 {print $2}')
{
  echo "SCANNER_IP=$scanner"
  echo "SCANNED_PORTS=$(jq -r --arg s "$scanner" 'select(.src == $s) | .dpt' "$J" | sort -u | wc -l)"
  echo "WEB_TRANSPORT=tcp"
  echo "UNKNOWN_SOURCE=$(awk '{print $1}' /var/log/siem/unknown.log | sort -u | head -n1)"
} > /root/answers.txt
