# Provisions ridgeline.local and seeds its DNS zone and users (runs once, at build time).
# The planted record and the query log come at first start: dc/plant.sh.
set -eu
umask 022
DOM=DC=ridgeline,DC=local
# Lab-only password, documented in the README.
PASS='Lab-AD-2026!'
NET=10.203.17

rm -f /etc/samba/smb.conf
# Containers can't write security.* extended attributes, so file ACLs go to a tdb file (xattr_tdb).
# No self-registration (samba_dnsupdate): it would add the container's current IP (the build
# container's, or any other) as a second A record for dc01. All records here are added explicitly.
samba-tool domain provision --realm=RIDGELINE.LOCAL --domain=RIDGELINE --server-role=dc \
  --dns-backend=SAMBA_INTERNAL --host-name=dc01 --host-ip=$NET.10 --adminpass="$PASS" \
  --use-rfc2307 --function-level=2016 \
  --option="ad dc functional level = 2016" \
  --option="vfs objects = dfs_samba4 acl_xattr xattr_tdb" \
  --option="xattr_tdb:file=/var/lib/samba/xattr.tdb" \
  --option="dns forwarder = 127.0.0.11" \
  --option="dns update command = /bin/true" >/dev/null

# Kerberos straight to the local KDC (Docker's DNS doesn't know the domain's SRV records).
cat > /etc/krb5.conf <<'KRB'
[libdefaults]
	default_realm = RIDGELINE.LOCAL
	dns_lookup_realm = false
	dns_lookup_kdc = false
	rdns = false
[realms]
	RIDGELINE.LOCAL = {
		kdc = 127.0.0.1
	}
[domain_realm]
	.ridgeline.local = RIDGELINE.LOCAL
KRB

samba-tool ou add OU=Ridgeline,$DOM >/dev/null
for u in jalvarez sbrennan bnakamura kfischer; do
  samba-tool user add $u "$PASS" --userou=OU=Ridgeline >/dev/null
done
samba-tool group addmembers DnsAdmins jalvarez,sbrennan >/dev/null

# DNS records are added over RPC, so the DC runs for a moment during the build.
samba -D
for _ in $(seq 1 60); do samba-tool dns zonelist 127.0.0.1 -U "Administrator%$PASS" >/dev/null 2>&1 && break; sleep 1; done
dns() { samba-tool dns add 127.0.0.1 ridgeline.local "$@" -U "Administrator%$PASS" >/dev/null; }
dns rdg-fs01 A $NET.21
dns rdg-sql01 A $NET.22
dns rdg-print01 A $NET.23
for i in 1 2 3 4 5 6 7 8; do dns ws-010$i A $NET.$((50 + i)); done
dns intranet CNAME rdg-fs01.ridgeline.local
pkill samba
for _ in $(seq 1 30); do pgrep -x samba >/dev/null || break; sleep 1; done
