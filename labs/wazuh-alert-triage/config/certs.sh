#!/usr/bin/env bash
# One-shot setup, once per lab start, before the manager starts:
# - a private CA and TLS certificates for the three Wazuh components (the certs volume)
# - the shop's web root and empty log files, so the manager's first FIM scan sees them as the baseline
# Everything lives in volumes that ./lab down throws away.
set -euo pipefail
umask 022
WEB=/srv/www/html LOGS=/var/log/lab
if [ ! -f "$WEB/index.php" ]; then
  mkdir -p "$WEB/uploads" "$WEB/assets" "$LOGS"
  for f in index.php cart.php login.php config.php; do printf '<?php // %s, shop v3.2\n' "$f" > "$WEB/$f"; done
  printf 'console.log("shop");\n' > "$WEB/assets/app.js"
  : > "$LOGS/auth.log"; : > "$LOGS/access.log"
fi
cd /certs
[ -f done ] && exit 0
SUBJ="/C=US/O=uig-lab/OU=lab"
openssl req -x509 -newkey rsa:2048 -nodes -days 825 -keyout root-ca.key -out root-ca.pem -subj "$SUBJ/CN=lab-root-ca" 2>/dev/null
leaf() { # name [san]
  openssl req -newkey rsa:2048 -nodes -keyout "$1.tmp" -out "$1.csr" -subj "$SUBJ/CN=$1" 2>/dev/null
  printf 'subjectAltName=DNS:%s\nkeyUsage=digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth,clientAuth\n' "$1" > "$1.ext"
  openssl x509 -req -in "$1.csr" -CA root-ca.pem -CAkey root-ca.key -CAcreateserial -days 825 -extfile "$1.ext" -out "$1.pem" 2>/dev/null
  openssl pkcs8 -topk8 -nocrypt -in "$1.tmp" -out "$1-key.pem"
  rm -f "$1.tmp" "$1.csr" "$1.ext"
}
for n in admin wazuh.indexer wazuh.manager wazuh.dashboard; do leaf "$n"; done
chmod 644 ./*.pem
touch done
echo "certificates ready"
