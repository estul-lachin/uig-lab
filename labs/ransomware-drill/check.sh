# Checks for ransomware-drill (see templates/lab/check.sh for the rules).

_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
A=/root/answers.txt
T=/backup/immutable/share.tar.gz
M=/backup/immutable/share.sha256
S=/var/lib/drill/started
_imm() { lsattr -d "$1" 2>/dev/null | cut -d" " -f1 | grep -q i; }

section "1. An immutable, verifiable backup"
check "$T exists and is immutable" '[ -f $T ] && _imm $T' "tar -C /srv -czf $T share, then chattr +i $T"
check "$M lists all 120 files of the share and is immutable" '[ "$(grep -c "  \./" $M 2>/dev/null)" = 120 ] && _imm $M' \
  "cd /srv/share && find . -type f -exec sha256sum {} + > $M; chattr +i $M"
check "Both were made before the drill started" '[ -f $S ] && [ $(stat -c %Y $T) -le $(date -d "$(cat $S)" +%s) ] && [ $(stat -c %Y $M) -le $(date -d "$(cat $S)" +%s) ]' \
  "Back up first, then start the drill"
check "The archive matches the manifest" '[ -f $T ] && d=$(mktemp -d) && tar -C $d -xzf $T && (cd $d/share && sha256sum -c --quiet $M >/dev/null 2>&1); r=$?; rm -rf "$d"; [ $r = 0 ]' \
  "The 0 in 3-2-1-1-0: a backup you have verified"

section "2. The drill ran"
check "The drill has started" '[ -f $S ]' "/opt/drill/start-incident.sh"

section "3. Detection"
check "ENCRYPTED_COUNT is how many files it encrypted" '[ "$(_kv $A ENCRYPTED_COUNT)" = 121 ]' "find /srv/share -name \"*.lmn\" | wc -l, once it has finished"
check "RANSOM_NOTE is the name of the note" '[ "$(_kv $A RANSOM_NOTE)" = README_RESTORE_FILES.txt ]' "ls /srv/share/*/"
check "NOTE_CONTACT is the address in the note" '[ "$(_kv $A NOTE_CONTACT)" = restore@lumen-unlock.example ]' "cat it"
check "DELETED_BACKUP is the backup that is gone" '[ "$(_kv $A DELETED_BACKUP)" = /backup/nightly/share-2026-11-02.tar.gz ]' "Compare /backup with what was there before"
check "WIPED_LOG is the log it emptied" '[ "$(_kv $A WIPED_LOG)" = /var/log/fs-audit.log ]' "find /var/log -type f -size 0"

section "4. Containment"
check "ENCRYPTOR_PROCESS is the process name" '[ "$(_kv $A ENCRYPTOR_PROCESS)" = lockerd ]' "ps -eo pid,args"
check "ENCRYPTOR_FILE is the script it runs from" '[ "$(_kv $A ENCRYPTOR_FILE)" = /usr/local/lib/.lockerd ]' "Where did start-incident.sh put it? Or ls -l /proc/<pid>/fd"
check "It is stopped and its file deleted" '[ -f $S ] && ! pgrep -f "^lockerd" >/dev/null && [ ! -e /usr/local/lib/.lockerd ]' "kill it before you restore anything"

section "5. Recovery"
check "No encrypted files or notes are left" '[ -f $S ] && [ -z "$(find /srv/share \( -name "*.lmn" -o -name README_RESTORE_FILES.txt \) -print -quit)" ]' "Remove them after the restore"
check "All 120 files pass the manifest" '[ -f $S ] && [ -f $M ] && (cd /srv/share && sha256sum -c --quiet $M >/dev/null 2>&1)' "tar -C /srv -xzf $T, then sha256sum -c"
check "They stay that way (nothing re-encrypts them)" '[ -f $S ] && sleep 6 && (cd /srv/share && sha256sum -c --quiet $M >/dev/null 2>&1) && [ -z "$(find /srv/share -name "*.lmn" -print -quit)" ]' \
  "If they turn into .lmn again, the encryptor is still running: contain before you recover"

section "6. The recovery point"
check "LOST_FILE is the file the backup couldn't bring back" '_kv $A LOST_FILE | grep -q "ops/orders-today.csv$"' \
  "Which file existed when the drill started but isn't in the manifest?"
