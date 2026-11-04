#!/bin/sh
# s6 service: once per container, after analysisd is up, play the fleet's rootcheck results
# (one every 0.3 s). The marker holds the epoch second the feed ended; later events are not the fleet's.
MARK=/var/lib/lab-feed-done
[ -f "$MARK" ] && exec sleep infinity
until printf 'x\n' | /var/ossec/bin/wazuh-logtest -q >/dev/null 2>&1; do sleep 3; done
sleep 5
/var/ossec/framework/python/bin/python3 -I /opt/lab/inject.py /opt/lab/fleet.events 0.3
sleep 10
date +%s > "$MARK"
exec sleep infinity
