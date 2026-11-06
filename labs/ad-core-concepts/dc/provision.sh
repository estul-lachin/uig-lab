# Provisions the ridgeline.local forest and seeds its OUs, users and computers (runs once, at build time).
set -eu
umask 022
DOM=DC=ridgeline,DC=local
BASE=OU=Ridgeline,$DOM
# Lab-only password, documented in the README.
PASS='Lab-AD-2026!'

rm -f /etc/samba/smb.conf
# Containers can't write security.* extended attributes, so file ACLs go to a tdb file (xattr_tdb).
samba-tool domain provision --realm=RIDGELINE.LOCAL --domain=RIDGELINE --server-role=dc \
  --dns-backend=SAMBA_INTERNAL --host-name=dc01 --host-ip=10.203.15.10 --adminpass="$PASS" \
  --use-rfc2307 --function-level=2016 \
  --option="ad dc functional level = 2016" \
  --option="vfs objects = dfs_samba4 acl_xattr xattr_tdb" \
  --option="xattr_tdb:file=/var/lib/samba/xattr.tdb" \
  --option="dns forwarder = 127.0.0.11" >/dev/null

samba-tool ou add "$BASE" --description="Ridgeline Outfitters" >/dev/null
for ou in IT Finance Sales Warehouse Servers Workstations; do
  samba-tool ou add "OU=$ou,$BASE" >/dev/null
done

user() { # sam given surname ou title
  samba-tool user add "$1" "$PASS" --given-name="$2" --surname="$3" --userou="OU=$4,OU=Ridgeline" \
    --job-title="$5" --department="$4" --mail-address="$1@ridgeline.local" >/dev/null
}
user jalvarez Jorge Alvarez IT "IT Manager"
user sbrennan Shawn Brennan IT "Systems Administrator"
user aokoye Ada Okoye IT "Help Desk Technician"
user mreyes Maya Reyes Finance "Accounts Payable Lead"
user lchen Lin Chen Finance "Controller"
user rkowalski Rita Kowalski Sales "Sales Manager"
user bnakamura Ben Nakamura Sales "Account Executive"
user hdiallo Hawa Diallo Warehouse "Shift Supervisor"
user kfischer Karl Fischer Warehouse "Forklift Operator"

for c in RDG-FS01 RDG-SQL01 RDG-PRINT01; do
  samba-tool computer add "$c" --computerou="OU=Servers,OU=Ridgeline" >/dev/null
done
for c in WS-0101 WS-0102 WS-0103 WS-0104 WS-0105; do
  samba-tool computer add "$c" --computerou="OU=Workstations,OU=Ridgeline" >/dev/null
done
# Joined without an OU: it lands in the default Computers container.
samba-tool computer add WS-TEMP07 --description="Loaner laptop" >/dev/null

samba-tool group add IT-Admins --groupou="OU=IT,OU=Ridgeline" >/dev/null
samba-tool group addmembers IT-Admins jalvarez,sbrennan >/dev/null
samba-tool group add Finance-Share --groupou="OU=Finance,OU=Ridgeline" >/dev/null
samba-tool group addmembers Finance-Share mreyes,lchen >/dev/null
