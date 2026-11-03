# Reference solution for bash-conditionals.
set -euo pipefail
D=/root/scripts

cat > $D/pathtype.sh <<'S'
#!/usr/bin/env bash
if [[ -L $1 ]]; then echo symlink
elif [[ -d $1 ]]; then echo directory
elif [[ -f $1 ]]; then echo file
else echo missing; exit 1
fi
S

cat > $D/sign.sh <<'S'
#!/usr/bin/env bash
n=${1-}
[[ $n =~ ^-?[0-9]+$ ]] || { echo "sign: not an integer: '$n'" >&2; exit 2; }
if (( n > 0 )); then echo positive
elif (( n == 0 )); then echo zero
else echo negative
fi
S

cat > $D/svc.sh <<'S'
#!/usr/bin/env bash
usage() { echo "usage: svc.sh start|stop|restart"; }
action=${1-}
case "${action,,}" in
  start)     echo starting ;;
  stop)      echo stopping ;;
  restart)   echo restarting ;;
  -h|--help) usage; exit 0 ;;
  *)         usage >&2; exit 64 ;;
esac
S

cat > $D/is-ipv4.sh <<'S'
#!/usr/bin/env bash
[[ ${1-} =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]] || exit 1
for part in "${BASH_REMATCH[@]:1}"; do
  (( 10#$part <= 255 )) || exit 1
done
exit 0
S

cat > $D/ipclass.sh <<'S'
#!/usr/bin/env bash
ip=${1-}
"$(dirname "$0")/is-ipv4.sh" "$ip" || { echo invalid; exit 1; }
case $ip in
  127.*)                                   echo loopback ;;
  10.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*) echo private ;;
  *)                                       echo public ;;
esac
S

chmod +x $D/*.sh
