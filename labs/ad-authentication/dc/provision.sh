# Provisions ridgeline.local, its users (incl. a Kerberoastable service account) and the lockout
# policy (runs once, at build time).
set -eu
umask 022
DOM=DC=ridgeline,DC=local
BASE=OU=Ridgeline,$DOM
# Lab-only password, documented in the README.
PASS='Lab-AD-2026!'

rm -f /etc/samba/smb.conf
# Containers can't write security.* extended attributes, so file ACLs go to a tdb file (xattr_tdb).
samba-tool domain provision --realm=RIDGELINE.LOCAL --domain=RIDGELINE --server-role=dc \
  --dns-backend=SAMBA_INTERNAL --host-name=dc01 --host-ip=10.203.19.10 --adminpass="$PASS" \
  --use-rfc2307 --function-level=2016 \
  --option="ad dc functional level = 2016" \
  --option="vfs objects = dfs_samba4 acl_xattr xattr_tdb" \
  --option="xattr_tdb:file=/var/lib/samba/xattr.tdb" \
  --option="dns forwarder = 127.0.0.11" >/dev/null

# The lockout policy for this lab: 5 bad passwords, 30-minute window and duration.
samba-tool domain passwordsettings set --account-lockout-threshold=5 \
  --account-lockout-duration=30 --reset-account-lockout-after=30 >/dev/null

samba-tool ou add "$BASE" >/dev/null
for u in jalvarez sbrennan mreyes bnakamura; do
  samba-tool user add $u "$PASS" --userou=OU=Ridgeline >/dev/null
done
# Service accounts.
samba-tool user add svc_backup "$PASS" --userou=OU=Ridgeline --description="Nightly backup service" >/dev/null
samba-tool user add svc_sql "$PASS" --userou=OU=Ridgeline --description="SQL Server service account" >/dev/null
# svc_sql runs MSSQL, so it carries a Service Principal Name: this is what makes it Kerberoastable.
samba-tool spn add MSSQLSvc/sql.ridgeline.local:1433 svc_sql >/dev/null
samba-tool spn add MSSQLSvc/sql.ridgeline.local svc_sql >/dev/null
# A DNS A record so the service name resolves (and a TGS can be requested for the SPN).
samba -D
for _ in $(seq 1 60); do samba-tool dns zonelist 127.0.0.1 -U "Administrator%$PASS" >/dev/null 2>&1 && break; sleep 1; done
samba-tool dns add 127.0.0.1 ridgeline.local sql A 10.203.19.22 -U "Administrator%$PASS" >/dev/null
pkill -x samba || true
for _ in $(seq 1 30); do pgrep -x samba >/dev/null || break; sleep 1; done

# Kerberos straight to the local KDC (the container's resolver is Docker's, not the domain's).
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
