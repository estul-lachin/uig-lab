# Reference solution for ad-aduc: answers read live from the directory, then remove the rogue admin.
set -eu
umask 022
for _ in $(seq 1 30); do samba-tool user show alice >/dev/null 2>&1 && break; sleep 2; done
attr() { samba-tool user show "$1" --attributes="$2" 2>/dev/null | sed -n "s/^$2: //p"; }
rogue=$(comm -12 \
  <(samba-tool group listmembers "Domain Admins" 2>/dev/null | sort) \
  <(samba-tool group listmembers Sales-Team 2>/dev/null | sort) | head -n1)
{
  echo "ADUC_CONSOLE=dsa.msc"
  echo "ALICE_UPN=$(attr alice userPrincipalName)"
  echo "ALICE_SID=$(attr alice objectSid)"
  echo "GROUP_SCOPE=Global"
  echo "GROUP_TYPE=Security"
  echo "NESTING_COUNT=$(samba-tool group listmembers All-Staff 2>/dev/null | grep -c .)"
  echo "FRANK_TITLE=$(attr frank title)"
  echo "FINANCE_HEADCOUNT=$(samba-tool user list --full-dn 2>/dev/null | grep -c 'OU=Finance,OU=Ridgeline')"
  echo "DISABLED_USER=ivan"
  echo "PRIVILEGED_ACCOUNT=alice"
  echo "ROGUE_ADMIN=$rogue"
} > /root/answers.txt
samba-tool group removemembers "Domain Admins" "$rogue" >/dev/null
