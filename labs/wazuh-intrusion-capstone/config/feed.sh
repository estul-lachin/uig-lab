#!/bin/sh
# s6 service: once per container, after logcollector watches both logs and FIM watches in real time,
# play web-server-01's morning from the timeline, one step every 0.2 s with the current time:
#   W|ip|request|status|size|agent   a line in the nginx access log
#   S|message                         a line from sshd in the auth log
#   F|path|content                    a file written to disk (printf %b escapes)
MARK=/var/lib/lab-feed-done
OL=/var/ossec/logs/ossec.log
[ -f "$MARK" ] && exec sleep infinity
until grep -q "Analyzing file: '/var/log/lab/nginx-access.log'" $OL 2>/dev/null \
   && grep -q "Analyzing file: '/var/log/lab/secure.log'" $OL 2>/dev/null \
   && grep -q 'Real-time file integrity monitoring started' $OL 2>/dev/null; do sleep 3; done
sleep 10
pid=4100
grep -v '^#' /opt/lab/timeline.events | while IFS='|' read -r t a b c d e; do
  case "$t" in
    W) printf '%s - - [%s] "%s HTTP/1.1" %s %s "-" "%s"\n' "$a" "$(date '+%d/%b/%Y:%H:%M:%S +0000')" "$b" "$c" "$d" "$e" >> /var/log/lab/nginx-access.log ;;
    S) pid=$((pid + 7)); printf '%s web-server-01 sshd[%s]: %s\n' "$(date '+%b %e %H:%M:%S')" "$pid" "$a" >> /var/log/lab/secure.log ;;
    F) mkdir -p "$(dirname "$a")"; printf '%b' "$b" > "$a"; sleep 2 ;;
  esac
  sleep 0.2
done
sleep 15
touch "$MARK"
exec sleep infinity
