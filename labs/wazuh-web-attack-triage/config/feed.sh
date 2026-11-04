#!/bin/sh
# s6 service: once per container, after logcollector watches the file, write web-server-01's
# morning into its nginx access log, one request every 0.2 s with the current time. Then stay idle.
LOG=/var/log/lab/web-server-01-access.log
EVENTS=/opt/lab/access.events
MARK=/var/lib/lab-feed-done
[ -f "$MARK" ] && exec sleep infinity
until grep -q "Analyzing file: '$LOG'" /var/ossec/logs/ossec.log 2>/dev/null; do sleep 3; done
sleep 5
grep -v '^#' "$EVENTS" | while IFS='|' read -r ip req status size ua; do
  printf '%s - - [%s] "%s HTTP/1.1" %s %s "-" "%s"\n' "$ip" "$(date '+%d/%b/%Y:%H:%M:%S +0000')" "$req" "$status" "$size" "$ua" >> "$LOG"
  sleep 0.2
done
sleep 10
touch "$MARK"
exec sleep infinity
