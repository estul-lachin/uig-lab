# Reference solution for ransomware-drill.
set -euo pipefail
B=/backup/immutable

# 1. Immutable, verifiable backup (before the incident)
mkdir -p "$B"
tar -C /srv -czf "$B/share.tar.gz" share
(cd /srv/share && find . -type f -exec sha256sum {} + | sort -k2) > "$B/share.sha256"
chattr +i "$B/share.tar.gz" "$B/share.sha256"

# 2. The drill
/opt/drill/start-incident.sh >/dev/null
for _ in $(seq 1 60); do
  [ -z "$(find /srv/share -type f ! -name '*.lmn' ! -name README_RESTORE_FILES.txt -print -quit)" ] && break
  sleep 1
done

# 3. Detection
count=$(find /srv/share -name '*.lmn' | wc -l)
note=$(find /srv/share -name 'README_*' -printf '%f\n' | sort -u | head -n1)
contact=$(grep -ohE '[[:alnum:]._-]+@[[:alnum:].-]+' /srv/share/finance/"$note" | head -n1)
wiped=$(find /var/log -type f -size 0 -name '*.log' | head -n1)

# 4. Containment: the process, its file, then kill and delete
pid=$(pgrep -f '^lockerd' | head -n1)
file=$(ls -l /proc/"$pid"/fd 2>/dev/null | grep -o '/usr/local/lib/[^ ]*' | head -n1 || true)
[ -n "$file" ] || file=/usr/local/lib/.lockerd
kill "$pid"
rm -f "$file"

# 5. Recovery from the immutable copy, verified
find /srv/share \( -name '*.lmn' -o -name README_RESTORE_FILES.txt \) -delete
tar -C /srv -xzf "$B/share.tar.gz"
(cd /srv/share && sha256sum -c --quiet "$B/share.sha256")

{
  echo "ENCRYPTED_COUNT=$count"
  echo "RANSOM_NOTE=$note"
  echo "NOTE_CONTACT=$contact"
  echo "DELETED_BACKUP=/backup/nightly/share-2026-11-02.tar.gz"
  echo "WIPED_LOG=$wiped"
  echo "ENCRYPTOR_PROCESS=lockerd"
  echo "ENCRYPTOR_FILE=$file"
  echo "LOST_FILE=ops/orders-today.csv"
} > /root/answers.txt
