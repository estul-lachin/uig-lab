# Checks for powershell-basics (see templates/lab/check.sh for the rules).
# Answers are compared case-insensitively (PowerShell is); values that depend on the image are
# read from the container itself.

A=/root/answers.txt
CSV=/root/reports/finance-users.csv
_kv() { sed -n "s/^$1=//p" "$A" 2>/dev/null | head -n1 | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }
_lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
_is() { _v=$(_kv "$1"); [ -n "$_v" ] && [ "$(_lc "$_v")" = "$(_lc "$2")" ]; }
_ps() { pwsh -NoProfile -NonInteractive -Command "$1" 2>/dev/null | tr -d '\r'; }
_csv() { tr -d '"\r' < "$CSV" | sed '/^[[:space:]]*$/d' | tr '[:upper:]' '[:lower:]'; }

section "1. Orientation (CMD staples)"
check "WHOAMI: the account you are running as" '_is WHOAMI root' "whoami"
check "COMPUTER: this server s name" '_is COMPUTER rdg-fs01' "hostname"
check "IDENTITY: the same account in DOMAIN\\user form" '_is IDENTITY "rdg-fs01\\root"' \
  "On a machine that is not in a domain, the domain part is the computer itself: [Environment]::UserDomainName"
check "OS_NAME: the operating system name and release" '_is OS_NAME "$(_ps "\$PSVersionTable.OS")"' \
  "On Windows that is systeminfo; here PowerShell has a variable with an OS entry"
check "IPV4: the server s IPv4 address" '_is IPV4 10.203.14.21' \
  "On Windows ipconfig; here .NET: [System.Net.NetworkInformation.NetworkInterface] and GetIPProperties()"

section "2. The cmdlet model"
check "NAMING: the naming convention every cmdlet follows" '_is NAMING Verb-Noun' "Get-Process, Stop-Service, New-Item"
check "SERVICE_CMDLET: lists services and their status (Windows)" '_is SERVICE_CMDLET Get-Service' "The CLI version of services.msc"
check "PROCESS_CMDLET: lists running processes" '_is PROCESS_CMDLET Get-Process' "The CLI version of Task Manager"
check "DIR_ALIAS: the cmdlet behind the alias dir" '_is DIR_ALIAS Get-ChildItem' "Get-Alias"
check "PS_VERSION: the PowerShell version" '_is PS_VERSION "$(_ps "\$PSVersionTable.PSVersion.ToString()")"' "\$PSVersionTable"

section "3. Querying Active Directory"
check "AD_CMDLET: retrieves AD user accounts" '_is AD_CMDLET Get-ADUser' "Get-Command *user*"
check "AD_MODULE: the module it comes from here" '_is AD_MODULE LabAD' "The Source column of Get-Command"
check "MREYES_TITLE: the job title of mreyes" '_is MREYES_TITLE "Accounts Payable Lead"' \
  "Title is not in the default output; ask for it with -Properties"
check "DISABLED_USER: the disabled employee account" '_is DISABLED_USER evoss' \
  "Filter on Enabled; leave out the built-in accounts"

section "4. Account hygiene (SOC follow-up)"
check "STALE_USER: enabled, but no logon in the 90 days before 2026-11-05" '_is STALE_USER tgrant' \
  "LastLogonDate is a DateTime: -lt against a date 90 days back, enabled accounts only"
check "NEVER_EXPIRES_USER: the person (not a service account) whose password never expires" '_is NEVER_EXPIRES_USER hdiallo' \
  "PasswordNeverExpires; service accounts are named svc-"
check "HIDDEN_ADMIN: the Domain Admin from outside IT" '_is HIDDEN_ADMIN bnakamura' \
  "Get-ADGroupMember shows only direct members; one of them is a group. Look for -Recursive"
check "HIDDEN_VIA: the group that gives that account its rights" '_is HIDDEN_VIA IT-Escalation' \
  "Walk down from Domain Admins one level at a time"

section "5. Report"
check "$CSV exists" '[ -s "$CSV" ]' "Export-Csv; create the folder first"
check "...with exactly the columns SamAccountName, Title, Enabled" '[ -s "$CSV" ] && [ "$(_csv | head -n1)" = "samaccountname,title,enabled" ]' \
  "Select-Object before Export-Csv"
check "...one row for every user in the Finance OU, and nothing else" '[ -s "$CSV" ] && [ "$(_csv | tail -n +2 | sort | tr "\n" "|")" = "dokafor,financial analyst,true|lchen,controller,true|mreyes,accounts payable lead,true|pnair,payroll specialist,true|" ]' \
  "-SearchBase with the OU s distinguished name; Title only comes with -Properties"
