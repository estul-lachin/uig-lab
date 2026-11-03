# Checks for linux-file-management (see templates/lab/check.sh for the rules).

_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
C=/root/casefiles
A=/root/answers.txt

section "1. Create"
check "$C/reports is a directory" '[ -d $C/reports ]' "mkdir"
check "$C/reports/summary.txt is an empty file" '[ -f $C/reports/summary.txt ] && [ ! -s $C/reports/summary.txt ]' "touch"

section "2. Remove"
check "old-drafts and everything in it is gone" '[ -d $C ] && [ ! -e $C/old-drafts ]' "rm -r (rmdir only works on empty directories)"
check "Nothing else was deleted" '[ -d $C/evidence ] && [ -f $C/evidence/firewall.log ]' "Only old-drafts should go"

section "3. Copy"
check "backup/evidence exists" '[ -d $C/backup/evidence ]' "cp -r evidence backup/evidence"
check "It mirrors evidence exactly" '[ -d $C/backup/evidence ] && [ -d $C/evidence ] && diff -r $C/evidence $C/backup/evidence' \
  "Same files, same content"
check "The original evidence is still there" '[ "$(ls $C/evidence | wc -l)" = 3 ]' "Copy, don't move"
check "It is not nested one level too deep" '[ -d $C/backup/evidence ] && [ ! -e $C/backup/evidence/evidence ]' \
  "cp -r into an existing directory puts the source inside it"

section "4. Move and rename"
check "reports/timeline.txt holds the notes" '[ -f $C/reports/timeline.txt ] && grep -q "first alert" $C/reports/timeline.txt' \
  "mv notes.txt reports/timeline.txt moves and renames in one step"
check "notes.txt is gone from casefiles" '[ -f $C/reports/timeline.txt ] && [ ! -e $C/notes.txt ]' "mv, not cp"

section "5. Find by name"
check "NIGHTOWL_PATH is the full path of the nightowl directory" '[ "$(_kv $A NIGHTOWL_PATH | sed "s:/*$::")" = $C/2026/q3/field/nightowl ]' \
  "find /root/casefiles -name nightowl (a file mentioning the word is not a match)"

section "6. Search contents"
check "BEACON_FILES is right" '[ "$(_kv $A BEACON_FILES)" = 2 ]' \
  "Lower-case beacon only; count files (grep -rl), not lines"

section "7. Persistence"
check "REBOOT_JOB is the cron file that runs at boot" '[ "$(_kv $A REBOOT_JOB)" = /etc/cron.d/sync-agent ]' \
  "grep -r @reboot /etc/cron.d"
