# Checks for revil-case-study (see templates/lab/check.sh for the rules).

C=/root/case
A=$C/answers.txt
S=/srv/share
B=/srv/backup/nightly-2026-06-01
E=/root/evidence
X=q7w2kx9
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]" | tr A-Z a-z; }
_in() { local v; v=$(_kv $A "$1"); [ -n "$v" ] && for x in $2; do [ "$v" = "$x" ] && return 0; done; return 1; }

section "1. REvil in brief"
check "INITIAL_ACCESS is the remote service affiliates abuse most" '_in INITIAL_ACCESS "rdp remotedesktop remotedesktopprotocol"' "Brute-forced when it is exposed to the internet"
check "TACTIC is the name of steal-then-encrypt pressure" '_in TACTIC "doubleextortion double-extortion"' "Two-pronged"
check "ASYMMETRIC and SYMMETRIC are its two algorithms" '_in ASYMMETRIC "curve25519 x25519 ecdh" && _in SYMMETRIC salsa20' "An elliptic curve, and a stream cipher"
check "TECHNIQUE is the ATT&CK ID for Data Encrypted for Impact" '_in TECHNIQUE t1486' "attack.mitre.org"

section "2. Triage on BWD-FS01"
check "EXTENSION is what it appended" '[ "$(_kv $A EXTENSION | tr -d .)" = $X ]' "Look at the share, then confirm in recfg.reg"
check "RANSOM_NOTE is the note's file name" '_in RANSOM_NOTE $X-readme.txt' "One per folder"
check "ENCRYPTED_FILES is how many files were encrypted" '_in ENCRYPTED_FILES 14' "Before you move anything: find -name"
check "SKIPPED_EXTENSIONS lists the file types it left alone" '[ "$(_kv $A SKIPPED_EXTENSIONS | tr "," "\n" | tr -d . | grep . | sort -u | paste -sd,)" = dll,exe,ini,lnk ]' \
  "What is still readable in the share? comma-separated"
check "ATTACKER_IP is where the successful RDP logon came from" '_in ATTACKER_IP 198.51.100.66' "Two sources brute-forced; one got in"
check "ACCOUNT is the account it got in with" '_in ACCOUNT xray' "4624, LogonType 10"
check "SHADOW_TECHNIQUE is the ATT&CK ID for what the encoded PowerShell did" '_in SHADOW_TECHNIQUE t1490' \
  "base64 -d, then iconv -f UTF-16LE: PowerShell -e takes UTF-16"

section "3. Recovery"
# Every file in the backup manifest is back in the share, byte for byte.
_restored() { [ -s $B/SHA256SUMS ] && ( cd $S 2>/dev/null && sha256sum --quiet -c $B/SHA256SUMS >/dev/null 2>&1 ); }
check "Every file in the backup manifest is back in /srv/share and matches its SHA-256" '_restored' \
  "rsync from the backup, then sha256sum -c the manifest from inside /srv/share"
check "No encrypted files or ransom notes are left in the share" '_restored && [ -z "$(find $S \( -name "*.$X" -o -name "$X-readme.txt" \) -print -quit)" ]' \
  "Move them, do not delete them"
check "The 14 encrypted files are kept in /root/evidence, in their folders" '[ "$(find $E -type f -name "*.$X" 2>/dev/null | wc -l)" = 14 ] && [ -f $E/billing/q2-close.xlsx.$X ]' \
  "Keep the relative paths: /root/evidence/billing/q2-close.xlsx.$X"
check "...and so are the 5 ransom notes" '[ "$(find $E -type f -name "$X-readme.txt" 2>/dev/null | wc -l)" = 5 ]' "patients/$X-readme.txt and so on"
check "The backup itself is untouched" 'cd $B && sha256sum --quiet -c SHA256SUMS >/dev/null 2>&1' "Never restore by moving files out of the backup"
check "LOST_CHANGES is the file whose last changes no backup has" '_in LOST_CHANGES "billing/q2-close.xlsx /srv/share/billing/q2-close.xlsx"' \
  "fs-audit.log: written after 02:00, before the attack"
