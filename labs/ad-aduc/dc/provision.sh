# Provisions ridgeline.local: OUs, users, groups (with nesting), computers, and a privileged-group
# mistake to find (runs once, at build time).
set -eu
umask 022
DOM=DC=ridgeline,DC=local
BASE=OU=Ridgeline,$DOM
# Lab-only password, documented in the README.
PASS='Lab-AD-2026!'

rm -f /etc/samba/smb.conf
# Containers can't write security.* extended attributes, so file ACLs go to a tdb file (xattr_tdb).
samba-tool domain provision --realm=RIDGELINE.LOCAL --domain=RIDGELINE --server-role=dc \
  --dns-backend=SAMBA_INTERNAL --host-name=dc01 --host-ip=10.203.20.10 --adminpass="$PASS" \
  --use-rfc2307 --function-level=2016 \
  --option="ad dc functional level = 2016" \
  --option="vfs objects = dfs_samba4 acl_xattr xattr_tdb" \
  --option="xattr_tdb:file=/var/lib/samba/xattr.tdb" \
  --option="dns forwarder = 127.0.0.11" >/dev/null

samba-tool ou add "$BASE" >/dev/null
for ou in IT HR Finance Sales Servers Workstations; do samba-tool ou add "OU=$ou,$BASE" >/dev/null; done

user() { # sam given surname ou title [extra args...]
  local sam=$1 g=$2 s=$3 ou=$4 title=$5; shift 5
  samba-tool user add "$sam" "$PASS" --given-name="$g" --surname="$s" --userou="OU=$ou,OU=Ridgeline" \
    --job-title="$title" --department="$ou" "$@" >/dev/null
}
user alice   Alice   Nkemndirim IT      "Systems Administrator"
user ivan    Ivan    Petrov     IT      "Intern"
user hpatel  Hira    Patel      HR      "HR Manager"
user nokeke  Nia     Okeke      HR      "HR Generalist"
user erin    Erin    Delgado    Finance "Accountant"
user frank   Frank   Mortensen  Finance "CFO"
user dwong   David   Wong       Sales   "Account Executive"
user rkelley  Rita   Kelley     Sales   "Sales Manager"
# The former intern is kept for audit, disabled not deleted.
samba-tool user disable ivan >/dev/null

# Department groups: Global security groups (the default), one per OU.
grp() { samba-tool group add "$1" --groupou="OU=$2,OU=Ridgeline" >/dev/null; samba-tool group addmembers "$1" "$3" >/dev/null; }
grp IT-Admins    IT      alice,ivan
grp HR-Staff     HR      hpatel,nokeke
grp Finance-Team Finance erin,frank
grp Sales-Team   Sales   dwong,rkelley
# All-Staff nests the four department groups, not people.
samba-tool group add All-Staff --groupou=OU=Ridgeline >/dev/null
samba-tool group addmembers All-Staff IT-Admins,HR-Staff,Finance-Team,Sales-Team >/dev/null

# alice is the one intended privileged admin.
samba-tool group addmembers "Domain Admins" alice >/dev/null
# The mistake to find: a Sales account was added straight into Domain Admins.
samba-tool group addmembers "Domain Admins" dwong >/dev/null

# Computer accounts.
samba-tool computer add WS01 --computerou="OU=Workstations,OU=Ridgeline" >/dev/null
samba-tool computer add WS02 --computerou="OU=Workstations,OU=Ridgeline" >/dev/null
samba-tool computer add FILE01 --computerou="OU=Servers,OU=Ridgeline" >/dev/null
