# Reference solution for bash-loops.
set -euo pipefail
D=/root/scripts

cat > $D/linecount.sh <<'S'
#!/usr/bin/env bash
shopt -s nullglob
for f in *.log; do
  echo "$f: $(wc -l < "$f")"
done
S

cat > $D/numberlines.sh <<'S'
#!/usr/bin/env bash
n=0
while IFS= read -r row || [ -n "$row" ]; do
  n=$(( n + 1 ))
  printf '%d: %s\n' "$n" "$row"
done < "$1"
S

cat > $D/squares.sh <<'S'
#!/usr/bin/env bash
n=${1:-10}
for (( i = 1; i <= n; i++ )); do
  echo $(( i * i ))
done
S

cat > $D/new-accounts.sh <<'S'
#!/usr/bin/env bash
comm -13 <(sort /root/data/baseline-users.txt) <(cut -d: -f1 /etc/passwd | sort)
S

chmod +x $D/*.sh
