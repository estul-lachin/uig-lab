# Reference solution for package-management.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
A=/root/answers.txt

# 6 first, so apt update doesn't wait on the rogue repository.
rogue=$(grep -rl '203.0.113.50' /etc/apt/sources.list.d/)
risk=$(grep -o 'trusted=yes' "$rogue" | head -n1)
rm -f -- "$rogue"

# 1. Install
apt-get update -q >/dev/null
apt-get install -y -q jq >/dev/null

# 2-4. Inspect, files, hold
dpkg --status jq > /root/jq.pkg.txt
dpkg --listfiles jq > /root/jq.files.txt
apt-mark hold jq >/dev/null
apt-mark showhold > /root/holds.txt

# 5. Sources snapshot (legacy file and both drop-in formats)
for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
  [ -f "$f" ] && cat "$f"
done > /root/sources.backup

# 7. Tampered binary: changed checksum ("5" in the third column), ignoring files the image deleted
tampered=$(dpkg --verify 2>/dev/null | awk '$1 !~ /^missing/ && substr($1,3,1) == "5" {print $NF}' | grep '^/usr/bin/' | head -n1)
pkg=$(dpkg -S "$tampered" | cut -d: -f1)
apt-get install -y -q --reinstall "$pkg" >/dev/null

{
  echo "JQ_DEPENDS=$(dpkg-query -W -f='${Depends}' jq)"
  echo "JQ_OWNER_OF_BINARY=$(dpkg -S /usr/bin/jq | cut -d: -f1)"
  echo "ROGUE_REPO_FILE=$rogue"
  echo "ROGUE_REPO_RISK=$risk"
  echo "TAMPERED_FILE=$tampered"
  echo "TAMPERED_PACKAGE=$pkg"
} > "$A"
