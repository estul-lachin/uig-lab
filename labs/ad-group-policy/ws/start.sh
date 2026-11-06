#!/usr/bin/env bash
# WS01 entrypoint. On first start it joins ridgeline.local; then it idles so the student can work.
set -eu
umask 022
PASS='Lab-AD-2026!'

cat > /etc/krb5.conf <<'KRB'
[libdefaults]
	default_realm = RIDGELINE.LOCAL
	dns_lookup_realm = false
	dns_lookup_kdc = false
	rdns = false
[realms]
	RIDGELINE.LOCAL = {
		kdc = dc01.ridgeline.local
	}
[domain_realm]
	.ridgeline.local = RIDGELINE.LOCAL
KRB

if [ ! -e /var/lib/samba/.lab-joined ]; then
  cat > /etc/samba/smb.conf <<'CONF'
[global]
	workgroup = RIDGELINE
	realm = RIDGELINE.LOCAL
	security = ads
	netbios name = WS01
	apply group policies = yes
	kerberos method = secrets and keytab
	idmap config * : backend = tdb
	idmap config * : range = 3000-7999
	idmap config RIDGELINE : backend = rid
	idmap config RIDGELINE : range = 10000-999999
CONF
  # Wait for the DC's LDAP and Kerberos before joining.
  for _ in $(seq 1 90); do
    nc -z dc01.ridgeline.local 389 && nc -z dc01.ridgeline.local 88 && break
    sleep 2
  done
  sleep 3
  net ads join -U "Administrator%$PASS" createcomputer=Ridgeline/Workstations
  net ads keytab create -U "Administrator%$PASS"
  touch /var/lib/samba/.lab-joined
fi

# Keep the container alive for the session.
exec sleep infinity
