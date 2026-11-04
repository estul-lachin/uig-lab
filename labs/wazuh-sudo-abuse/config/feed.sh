#!/bin/sh
# s6 service: once per container, after logcollector watches the file, write web-server-01's
# afternoon into it, one line every 0.2 s with the current time. Then stay idle.
LOG=/var/log/lab/web-server-01.log
EVENTS=/opt/lab/web-server-01.events
MARK=/var/lib/lab-feed-done
[ -f "$MARK" ] && exec sleep infinity
until grep -q "Analyzing file: '$LOG'" /var/ossec/logs/ossec.log 2>/dev/null; do sleep 3; done
sleep 5
while IFS= read -r line; do
  printf '%s %s\n' "$(date '+%b %e %H:%M:%S')" "$line" >> "$LOG"
  sleep 0.2
done < "$EVENTS"
sleep 10
touch "$MARK"
exec sleep infinity
