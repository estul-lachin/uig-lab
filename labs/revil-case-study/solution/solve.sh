# Reference solution for revil-case-study.
set -eu
umask 022
S=/srv/share B=/srv/backup/nightly-2026-06-01 E=/root/evidence C=/root/case

ext=$(sed -n 's/^"rnd_ext"=".\(.*\)"\r*$/\1/p' $C/recfg.reg)
count=$(find $S -type f -name "*.$ext" | wc -l)
skipped=$(find $S -type f ! -name "*.$ext" ! -name "$ext-readme.txt" | sed 's/.*\.//' | sort -u | paste -sd,)
read -r ip user < <(jq -r 'select(.EventID == 4624 and .LogonType == 10 and (.IpAddress | startswith("10.") | not)) | "\(.IpAddress) \(.TargetUserName)"' $C/security.jsonl)
lost=$(awk '$3 == "write" && $1 > "2026-06-01T02:00:00Z" && $1 < "2026-06-01T22:47:00Z" {print $4}' $C/fs-audit.log)

# Evidence first: move encrypted files and notes out, keeping their relative paths
( cd $S && find . -type f \( -name "*.$ext" -o -name "$ext-readme.txt" \) -print0 \
    | rsync -a --from0 --files-from=- --remove-source-files ./ $E/ )
# Then restore everything the backup has, and verify
rsync -a --exclude SHA256SUMS $B/ $S/
( cd $S && sha256sum --quiet -c $B/SHA256SUMS )

{
  echo "INITIAL_ACCESS=RDP"
  echo "TACTIC=double extortion"
  echo "ASYMMETRIC=Curve25519"
  echo "SYMMETRIC=Salsa20"
  echo "TECHNIQUE=T1486"
  echo "EXTENSION=.$ext"
  echo "RANSOM_NOTE=$ext-readme.txt"
  echo "ENCRYPTED_FILES=$count"
  echo "SKIPPED_EXTENSIONS=$skipped"
  echo "ATTACKER_IP=$ip"
  echo "ACCOUNT=$user"
  echo "SHADOW_TECHNIQUE=T1490"
  echo "LOST_CHANGES=$lost"
} > $C/answers.txt
