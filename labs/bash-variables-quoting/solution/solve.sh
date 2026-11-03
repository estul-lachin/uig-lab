# Reference solution for bash-variables-quoting.
set -euo pipefail
D=/root/scripts

cat > $D/welcome.sh <<'S'
#!/usr/bin/env bash
set -euo pipefail
echo "Welcome, $1!"
S

cat > $D/args.sh <<'S'
#!/usr/bin/env bash
printf '%s args:' "$#"
(( $# )) && printf ' [%s]' "$@"
echo
S

cat > $D/forward.sh <<'S'
#!/usr/bin/env bash
exec "$(dirname "$0")/args.sh" "$@"
S

cat > $D/pathparts.sh <<'S'
#!/usr/bin/env bash
p=$1
file=${p##*/}
echo "dir=${p%/*}"
echo "file=$file"
echo "ext=${file##*.}"
echo "stem=${file%.*}"
echo "upper=${file^^}"
S

cat > $D/settings.sh <<'S'
#!/usr/bin/env bash
: "${API_HOST:?API_HOST must be set}"
echo "LOGDIR=${LOGDIR:-/var/log/app}"
echo "LEVEL=${LEVEL:-info}"
echo "API_HOST=$API_HOST"
S

cat > $D/mask.sh <<'S'
#!/usr/bin/env bash
line=$1 secret=$2
printf -v stars '%*s' "${#secret}" ''
stars=${stars// /*}
echo "${line//"$secret"/$stars}"
S

chmod +x $D/*.sh
