#!/bin/bash
# Ransomware DRILL for this lab only. It encrypts /srv/share with a throwaway key, leaves notes, tries to
# delete /backup and wipes one log, then keeps running. Nothing leaves the container.
set -u
[ -f /var/lib/drill/started ] && { echo "The drill has already started."; exit 0; }
mkdir -p /var/lib/drill
# Business goes on after the backup: one new file nobody has backed up yet.
printf 'order,qty\n1001,4\n1002,9\n' > /srv/share/ops/orders-today.csv
date -u +%FT%TZ > /var/lib/drill/started
cp /opt/drill/lockerd.sh /usr/local/lib/.lockerd
chmod 755 /usr/local/lib/.lockerd
nohup setsid /usr/local/lib/.lockerd </dev/null >/dev/null 2>&1 &
echo "Drill started. Something is happening on this server..."
