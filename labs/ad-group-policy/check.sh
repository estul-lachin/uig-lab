# Checks for ad-group-policy (see templates/lab/check.sh for the rules).
# Runs on WS01, a domain member. Values that depend on the GPOs are read live from the DC.

A=/root/answers.txt
PASS='Lab-AD-2026!'
H="-H ldap://dc01.ridgeline.local -U Administrator%$PASS"
DOM="DC=ridgeline,DC=local"
DDP='{31B2F340-016D-11D2-945F-00C04FB984F9}'
_kv() { sed -n "s/^$1=//p" "$A" 2>/dev/null | head -n1 | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }
_n() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' _-'; }
_any() { _v=$(_kv "$1"); shift; [ -n "$_v" ] || return 1; for _e in "$@"; do [ "$(_n "$_v")" = "$(_n "$_e")" ] && return 0; done; return 1; }
# links at the domain root, GPO display names, newest query cached once
_rootlinks() { samba-tool gpo getlink "$DOM" $H 2>/dev/null | sed -n 's/^ *Name *: //p'; }
_minpwlen() { samba-tool gpo manage security list "$DDP" $H 2>/dev/null | sed -n 's/.*MinimumPasswordLength *= *//p' | tr -d ' '; }

for _ in $(seq 1 45); do [ -e /var/lib/samba/.lab-joined ] && samba-tool gpo listall $H >/dev/null 2>&1 && break; sleep 2; done

section "0. The domain member"
check "WS01 has joined ridgeline.local and can read the GPOs" 'samba-tool gpo listall $H 2>/dev/null | grep -qi "Default Domain Policy"' \
  "The workstation joins on first start; give it a few seconds after ./lab up and run the check again"

section "1. Reading Group Policy (the core questions)"
check "GPO_CONSOLE: the .msc that opens the Group Policy Management Console" '_any GPO_CONSOLE gpmc.msc' "gpmc"
check "BANNER_GPO: the domain-root GPO that sets the pre-logon legal notice" '_any BANNER_GPO "RDG - Logon Banner" "RDG-Logon Banner" "Logon Banner"' "Its name ends in Logon Banner"
check "OU_GPO: the GPO linked to OU=Workstations" '_any OU_GPO "RDG - Workstation Lockdown" "Workstation Lockdown"' "The scope demo"
check "PWPOLICY_GPO: the built-in GPO that holds the password and lockout policy" '_any PWPOLICY_GPO "Default Domain Policy"' "Account policy for the domain lives at the domain root"
check "MIN_PW_LEN: the minimum password length it configures" '_any MIN_PW_LEN "$(_minpwlen)"' "Read it from the Default Domain Policy, not from the running domain"
check "FORCE_CMD: the Windows command that reapplies policy now" '_any FORCE_CMD "gpupdate /force" "gpupdate/force"' "gpupdate, with a switch"
check "RSOP_CMD: the Windows command that shows which GPOs applied (RSoP)" '_any RSOP_CMD "gpresult /r" "gpresult/r"' "gpresult, with a switch"
check "PROCESSING_ORDER: the acronym for Local, Site, Domain, OU" '_any PROCESSING_ORDER LSDOU' "Four letters"

section "2. Apply policy and watch precedence"
check "You applied policy: /etc/issue carries the Workstation Lockdown banner" 'grep -qi "Ridgeline workstation" /etc/issue' \
  "Run samba-gpupdate --force on WS01 (the Linux equivalent of gpupdate /force)"
check "EFFECTIVE_BANNER_GPO: the GPO whose banner actually wins on WS01" '_any EFFECTIVE_BANNER_GPO "RDG - Workstation Lockdown" "Workstation Lockdown"' \
  "Both the domain-root and the OU GPO set /etc/issue; under LSDOU the closer link wins"
check "MAX_PW_AGE: the maximum password age (days) the Default Domain Policy sets" '_any MAX_PW_AGE "$(samba-tool gpo manage security list "$DDP" $H 2>/dev/null | sed -n "s/.*MaximumPasswordAge *= *//p" | tr -d " ")"' \
  "samba-tool gpo manage security list, same GPO"

section "3. The GPO an attacker added"
check "ROGUE_GPO: the extra GPO linked at the domain root" '_any ROGUE_GPO "Printer Driver Update"' \
  "Three GPOs are linked at the domain root; two are Ridgeline's. samba-tool gpo getlink"
check "ROGUE_LINK: where it is linked (so it reaches every machine)" '_any ROGUE_LINK "DC=ridgeline,DC=local" "domain root" "domain" "ridgeline.local"' \
  "A link at the domain applies everywhere, DC included"
check "ROGUE_SCRIPT: the startup script it pushes" '_any ROGUE_SCRIPT printer-update.sh' \
  "samba-tool gpo manage scripts startup list on that GPO; it dropped a @reboot line in /etc/cron.d after gpupdate"

section "4. Cut its link"
check "The Printer Driver Update GPO is no longer linked at the domain root" \
  '! _rootlinks | grep -qi "Printer Driver Update"' \
  "samba-tool gpo dellink on the domain DN; deleting the whole GPO also works, unlinking is enough"
check "...but the two Ridgeline domain-root GPOs are still linked" \
  '_rootlinks | grep -qi "Default Domain Policy" && _rootlinks | grep -qi "Logon Banner"' \
  "Remove only the attacker's link, not the legitimate ones"
