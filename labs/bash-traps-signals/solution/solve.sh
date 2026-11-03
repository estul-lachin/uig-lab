# Reference solution for bash-traps-signals.
set -euo pipefail
D=/root/scripts
mkdir -p $D

cat > $D/cleanup.sh <<'S'
#!/usr/bin/env bash
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
echo "$tmp" > /root/scripts/last-tmpdir.txt
touch "$tmp/work-file"
sleep 1
exit "${1:-0}"
S

cat > $D/graceful.sh <<'S'
#!/usr/bin/env bash
on_int() {
  echo "caught SIGINT" >> /root/scripts/graceful.log
  exit 130
}
trap on_int INT
while true; do sleep 1; done
S

cat > $D/errtrap.sh <<'S'
#!/usr/bin/env bash
set -euo pipefail
trap 'echo "error on line $LINENO" >&2' ERR
echo "starting"
ls /does-not-exist
echo unreachable
S

cat > $D/strict.sh <<'S'
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
echo "hello $1"
S

cat > $D/prune-logs.sh <<'S'
#!/bin/bash
# Delete rotated logs. Called by cron as: LOGDIR=/var/log/app prune-logs.sh
set -u
rm -f "${LOGDIR:?LOGDIR not set}"/old-*.log
echo "pruned $LOGDIR"
S

chmod +x $D/cleanup.sh $D/graceful.sh $D/errtrap.sh $D/strict.sh $D/prune-logs.sh
