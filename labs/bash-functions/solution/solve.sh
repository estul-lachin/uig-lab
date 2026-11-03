# Reference solution for bash-functions.
set -euo pipefail
D=/root/scripts

cat > $D/toolkit.sh <<'S'
# toolkit.sh - small helpers; source it, don't run it.

# total N... - print the sum of integer arguments; return 2 on a non-integer.
total() {
  local sum=0 n
  for n in "$@"; do
    if ! [[ $n =~ ^-?[0-9]+$ ]]; then
      echo "total: not an integer: $n" >&2
      return 2
    fi
    sum=$(( sum + n ))
  done
  echo "$sum"
}

# is_root - succeed only when running as root.
is_root() {
  [[ $EUID -eq 0 ]]
}
S

cat > $D/report.sh <<'S'
#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/toolkit.sh"
echo "total of 1 2 3 4 = $(total 1 2 3 4)"
S

cat > $D/relay.sh <<'S'
#!/usr/bin/env bash
"$@"
rc=$?
echo "command exited with $rc" >&2
exit "$rc"
S

chmod +x $D/report.sh $D/relay.sh
