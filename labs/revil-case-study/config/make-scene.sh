#!/usr/bin/env bash
# Build time only: the file share of Brightwater Dental (fictional) the morning after a REvil-style
# hit. Files that "were encrypted" are just replaced by random bytes of the same size and renamed:
# there is no encryption here, only its visible aftermath. Also writes the nightly backup and the logs.
set -euo pipefail
umask 022
S=/srv/share B=/srv/backup/nightly-2026-06-01 EXT=q7w2kx9
mkdir -p $S/{patients,billing,hr,imaging,apps,templates} $B

doc() { mkdir -p "$(dirname "$S/$1")"; for i in $(seq 1 "$2"); do printf '%s line %03d: Brightwater Dental internal\n' "$1" "$i"; done > "$S/$1"; }
doc patients/2026-05-intake.csv 120;   doc patients/recall-list.xlsx 80;    doc patients/consent-forms.pdf 60
doc billing/invoices-may.xlsx 150;     doc billing/insurance-claims.csv 90; doc billing/q2-close.xlsx 70
doc hr/rota-june.docx 40;              doc hr/payroll-may.csv 55;           doc hr/handbook.pdf 200
doc imaging/xray-0412.dcm 300;         doc imaging/xray-0419.dcm 300;       doc imaging/index.txt 25
doc templates/letterhead.docx 30;      doc templates/referral.docx 35
doc apps/PracticeSuite.exe 400;        doc apps/PracticeSuite.dll 250;      doc apps/Shortcut.lnk 3;   doc apps/settings.ini 12
touch -d '2026-05-31 17:00' $(find $S -type f)

# 02:00 nightly backup, with its manifest
cp -a $S/. $B/
( cd $B && find . -type f ! -name SHA256SUMS | sed 's#^\./##' | sort | xargs sha256sum > SHA256SUMS )
touch -d '2026-06-01 02:00' $B/SHA256SUMS

# 14:10 someone works on the quarter close after the backup
printf 'billing/q2-close.xlsx line 071: final adjustments, 1 June\n' >> $S/billing/q2-close.xlsx
touch -d '2026-06-01 14:10' $S/billing/q2-close.xlsx

# 22:47 the encryptor: skips executables and system-type files, as its config says
skip='\.(exe|dll|lnk|ini|sys)$'
find $S -type f | sort | while read -r f; do
  [[ $f =~ $skip ]] && continue
  head -c "$(stat -c %s "$f")" /dev/urandom > "$f.$EXT"; rm -f "$f"
done
for d in $(find $S -type d); do
  [ -n "$(find "$d" -maxdepth 1 -name "*.$EXT" -print -quit)" ] || continue
  cat > "$d/$EXT-readme.txt" <<NOTE
---=== Welcome. Again. ===---
[+] What happened? [+]
Your files are encrypted, and currently unavailable. You can check it: all files on your system have
extension $EXT. By the way, everything is possible to recover (restore), but you need to follow our
instructions. Otherwise, you cant return your data (NEVER).
[+] What guarantees? [+]
We have also downloaded your data. If you do not contact us, it will be published.
(lab reproduction of the note's structure; no real contact details)
NOTE
done
find $S -name "*.$EXT" -exec touch -d '2026-06-01 22:47' {} +
