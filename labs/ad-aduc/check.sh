# Checks for ad-aduc (see templates/lab/check.sh for the rules).
# Runs on DC01. Per-build values (UPN, SID, counts) are read live from the directory.

A=/root/answers.txt
PASS='Lab-AD-2026!'
_kv() { sed -n "s/^$1=//p" "$A" 2>/dev/null | head -n1 | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }
_n() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' _-'; }
_any() { _v=$(_kv "$1"); shift; [ -n "$_v" ] || return 1; for _e in "$@"; do [ "$(_n "$_v")" = "$(_n "$_e")" ] && return 0; done; return 1; }
_attr() { samba-tool user show "$1" --attributes="$2" 2>/dev/null | sed -n "s/^$2: //p"; }
_dadmins() { samba-tool group listmembers "Domain Admins" 2>/dev/null; }

for _ in $(seq 1 30); do samba-tool user show alice >/dev/null 2>&1 && break; sleep 2; done

section "1. The console and a user (the course questions)"
check "ADUC_CONSOLE: the .msc that opens Active Directory Users and Computers" '_any ADUC_CONSOLE dsa.msc' "dsa"
check "ALICE_UPN: alice's User Principal Name" '_any ALICE_UPN "$(_attr alice userPrincipalName)"' "user@domain; samba-tool user show alice"
check "ALICE_SID: her SID (differs on every build - read it from this box)" '_any ALICE_SID "$(_attr alice objectSid)"' \
  "samba-tool user show alice --attributes=objectSid"

section "2. Groups: scope, type, nesting"
check "GROUP_SCOPE: the scope of the Sales-Team group" '_any GROUP_SCOPE Global' "Global / Domain Local / Universal"
check "GROUP_TYPE: the type of the Corp groups (so they can hold permissions)" '_any GROUP_TYPE Security' "Security vs Distribution"
check "NESTING_COUNT: how many groups are nested inside All-Staff" '_any NESTING_COUNT "$(samba-tool group listmembers All-Staff 2>/dev/null | grep -c .)"' \
  "samba-tool group listmembers All-Staff - they are groups, not people"

section "3. Accounts"
check "FRANK_TITLE: the Title attribute on frank" '_any FRANK_TITLE CFO' "samba-tool user show frank --attributes=title"
check "FINANCE_HEADCOUNT: how many user accounts are in the Finance OU" '_any FINANCE_HEADCOUNT "$(samba-tool user list --full-dn 2>/dev/null | grep -c "OU=Finance,OU=Ridgeline")"' \
  "Count users whose DN is under OU=Finance"
check "DISABLED_USER: the disabled account (the former intern)" '_any DISABLED_USER ivan' "samba-tool user list shows it; its userAccountControl has the disable bit"
check "PRIVILEGED_ACCOUNT: the IT admin who is meant to be in Domain Admins" '_any PRIVILEGED_ACCOUNT alice' "The legitimate administrator"

section "4. Find the account that doesn't belong"
check "ROGUE_ADMIN: the non-IT account added straight into Domain Admins" '_any ROGUE_ADMIN dwong "ridgeline\\dwong"' \
  "samba-tool group listmembers Domain Admins; which member is from Sales, not IT?"
check "The rogue account has been removed from Domain Admins" '! _dadmins | grep -qix dwong' \
  "samba-tool group removemembers Domain Admins <user>"
check "...but alice and the built-in Administrator are still in Domain Admins" \
  '_dadmins | grep -qix alice && _dadmins | grep -qix Administrator' \
  "Remove only the account that doesn't belong"
