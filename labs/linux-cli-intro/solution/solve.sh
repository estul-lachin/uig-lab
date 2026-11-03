# Reference solution for linux-cli-intro.
set -euo pipefail
cd /root

L=/var/log/web/access.log
{
  # 1. The prompt in the README: mara@db-07:/var/log#
  echo "PROMPT_USER=mara"
  echo "PROMPT_HOST=db-07"
  echo "PROMPT_DIR=/var/log"
  echo "PROMPT_ROOT=yes"
  # 2.
  echo "HOME_USERS=$(ls /home | wc -l)"
  echo "HIDDEN_FILE=$(ls -A /home/cleo | grep '^\.' | grep -v '^\.\(bash\|profile\)' | head -n1)"
  echo "CD_RESULT=$(cd /var/log/web && cd ../.. && pwd)"
  # 3.
  echo "FIRST_IP=$(head -n 1 $L | cut -d' ' -f1)"
  echo "LAST_IP=$(tail -n 1 $L | cut -d' ' -f1)"
  echo "ACCESS_LINES=$(cat $L | wc -l)"
  # 4.
  echo "FAILED_PASSWORD=$(grep 'Failed password' /var/log/auth.log | wc -l)"
  echo "FAILED_ANY_CASE=$(grep -i failed /var/log/auth.log | wc -l)"
  # 5.
  echo "LS_SORT_TIME=-t"
  echo "WHICH_PS=$(which ps)"
  # 7.
  echo "ATTACKER_URL=$(grep -o 'http://[^ ]*' /home/ben/.bash_history | head -n1)"
} > /root/answers.txt
rm /usr/local/bin/ps

# 6. Evidence trail
mkdir -p evidence && cd evidence
echo "first finding" > notes.txt
echo "fake ps in /usr/local/bin" >> notes.txt
ls /nope 2> err.txt || true
