# First start only: bnakamura plants a wpad record. Any authenticated user may create a new name in
# an AD-integrated zone with a secure (GSS-TSIG) dynamic update, so this is how it happens for real.
# It needs the DC's own name to resolve, which only works at run time, not during the build.
set -eu
MARK=/var/lib/samba/.lab-planted
[ -e "$MARK" ] && exit 0
samba -D
for _ in $(seq 1 60); do nc -z 127.0.0.1 88 && nc -z 127.0.0.1 53 && break; sleep 1; done
sleep 2
echo 'Lab-AD-2026!' | kinit bnakamura@RIDGELINE.LOCAL >/dev/null
printf 'server dc01.ridgeline.local\nzone ridgeline.local\nupdate add wpad.ridgeline.local 900 A 10.203.17.66\nsend\n' | nsupdate -g >/dev/null 2>&1 || true
kdestroy
# nsupdate can't verify Samba's signed reply ("tsig verify failure"), but the update is applied: confirm it.
[ "$(dig +short @127.0.0.1 wpad.ridgeline.local)" = 10.203.17.66 ]
pkill -x samba || true
for _ in $(seq 1 30); do pgrep -x samba >/dev/null || break; sleep 1; done
touch "$MARK"
