# Reference solution for linux-file-management.
set -euo pipefail
C=/root/casefiles

# 1. Create
mkdir "$C/reports"
touch "$C/reports/summary.txt"

# 2. Remove
rm -r "$C/old-drafts"

# 3. Copy (backup/ already exists, so name the target explicitly)
cp -r "$C/evidence" "$C/backup/evidence"

# 4. Move and rename
mv "$C/notes.txt" "$C/reports/timeline.txt"

# 5-7. Answers
{
  echo "NIGHTOWL_PATH=$(find "$C" -name nightowl -type d)"
  echo "BEACON_FILES=$(grep -rl beacon "$C/2026/q3/field/nightowl" | wc -l)"
  echo "REBOOT_JOB=$(grep -rl '@reboot' /etc/cron.d)"
} > /root/answers.txt
