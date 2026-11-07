#!/bin/sh
# Bring up the mock link-local metadata address, start the IMDS, wait for it to
# listen, then start the vulnerable app. (NET_ADMIN is needed for `ip addr add`.)
set -e

ip addr add 169.254.169.254/32 dev lo 2>/dev/null || true

python3 /opt/linkpeek/imds.py >/var/log/imds.log 2>&1 &

# Don't serve the app until the metadata service is actually up, so the exploit
# never races a half-started IMDS.
i=0
while [ "$i" -lt 40 ]; do
  if curl -sf -o /dev/null http://169.254.169.254/latest/meta-data/iam/security-credentials/; then
    break
  fi
  i=$((i + 1))
  sleep 0.3
done

exec python3 /opt/linkpeek/app.py
