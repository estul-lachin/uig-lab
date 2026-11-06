# Provisions ridgeline.local with its OUs and GPOs (runs once, at build time).
set -eu
umask 022
DOM=DC=ridgeline,DC=local
BASE=OU=Ridgeline,$DOM
# Lab-only password, documented in the README.
PASS='Lab-AD-2026!'
U="Administrator%$PASS"

rm -f /etc/samba/smb.conf
# Containers can't write security.* extended attributes, so file ACLs go to a tdb file (xattr_tdb).
samba-tool domain provision --realm=RIDGELINE.LOCAL --domain=RIDGELINE --server-role=dc \
  --dns-backend=SAMBA_INTERNAL --host-name=dc01 --host-ip=10.203.18.10 --adminpass="$PASS" \
  --use-rfc2307 --function-level=2016 \
  --option="ad dc functional level = 2016" \
  --option="vfs objects = dfs_samba4 acl_xattr xattr_tdb" \
  --option="xattr_tdb:file=/var/lib/samba/xattr.tdb" \
  --option="dns forwarder = 127.0.0.11" \
  --option="apply group policies = yes" >/dev/null

samba-tool ou add "$BASE" >/dev/null
for ou in Staff Servers Workstations; do samba-tool ou add "OU=$ou,$BASE" >/dev/null; done
for u in jalvarez sbrennan bnakamura; do samba-tool user add $u "$PASS" --userou=OU=Staff,OU=Ridgeline >/dev/null; done

# GPOs are created over LDAP and SMB, so the DC runs for a moment during the build.
samba -D
for _ in $(seq 1 60); do samba-tool gpo listall -H ldap://127.0.0.1 -U "$U" >/dev/null 2>&1 && break; sleep 1; done
sleep 3
gpo() { samba-tool gpo "$@" -H ldap://127.0.0.1 -U "$U"; }
guid() { gpo listall | awk -v n="$1" '/^GPO/ {g=$3} /^display name/ {sub(/^display name *: /, ""); if ($0 == n) print g}'; }
DDP='{31B2F340-016D-11D2-945F-00C04FB984F9}'
gpo manage security set "$DDP" MinimumPasswordLength 10 >/dev/null
gpo manage security set "$DDP" MaximumPasswordAge 90 >/dev/null

gpo create "RDG - Logon Banner" >/dev/null
BANNER=$(guid "RDG - Logon Banner")
gpo manage issue set "$BANNER" "Authorized use only. Activity on this system is monitored." >/dev/null
gpo setlink "$DOM" "$BANNER" >/dev/null

gpo create "RDG - Workstation Lockdown" >/dev/null
WS=$(guid "RDG - Workstation Lockdown")
gpo manage issue set "$WS" "Ridgeline workstation. Lock your screen when you leave." >/dev/null
gpo manage motd set "$WS" "Managed by Ridgeline IT. Report problems to the help desk." >/dev/null
gpo setlink "OU=Workstations,$BASE" "$WS" >/dev/null

# The planted GPO: linked at the domain root (so it reaches every machine) with a boot script.
# The script body is harmless here - it only writes a marker - but the link is the finding.
printf '#!/bin/sh\n# Ridgeline IT - printer driver update\nlogger -t printer-update "agent check-in"\n' > /tmp/printer-update.sh
gpo create "Printer Driver Update" >/dev/null
ROGUE=$(guid "Printer Driver Update")
gpo manage scripts startup add "$ROGUE" /tmp/printer-update.sh >/dev/null
gpo setlink "$DOM" "$ROGUE" >/dev/null
rm -f /tmp/printer-update.sh

gpo listall
pkill -x samba || true
for _ in $(seq 1 30); do pgrep -x samba >/dev/null || break; sleep 1; done
