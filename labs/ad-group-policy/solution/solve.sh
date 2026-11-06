# Reference solution for ad-group-policy: apply policy, read the answers from the DC, cut the rogue link.
set -eu
umask 022
PASS='Lab-AD-2026!'
H="-H ldap://dc01.ridgeline.local -U Administrator%$PASS"
DOM="DC=ridgeline,DC=local"
DDP='{31B2F340-016D-11D2-945F-00C04FB984F9}'
for _ in $(seq 1 45); do [ -e /var/lib/samba/.lab-joined ] && samba-tool gpo listall $H >/dev/null 2>&1 && break; sleep 2; done

# Apply Group Policy on this workstation (gpupdate /force).
samba-gpupdate --force >/dev/null 2>&1 || true

sec() { samba-tool gpo manage security list "$DDP" $H 2>/dev/null | sed -n "s/.*$1 *= *//p" | tr -d ' '; }
# The rogue GPO: linked at the domain root, not one of Ridgeline's two.
rogue=$(samba-tool gpo getlink "$DOM" $H 2>/dev/null | sed -n 's/^ *Name *: //p' \
        | grep -viE 'Default Domain Policy|Logon Banner' | head -n1)
rguid=$(samba-tool gpo listall $H 2>/dev/null | awk -v n="$rogue" '/^GPO/ {g=$3} /^display name/ {sub(/^display name *: /,""); if ($0==n) print g}')
script=$(samba-tool gpo manage scripts startup list "$rguid" $H 2>/dev/null | grep -oE '[^\\/[:space:]]+\.sh' | head -n1)
{
  echo "GPO_CONSOLE=gpmc.msc"
  echo "BANNER_GPO=RDG - Logon Banner"
  echo "OU_GPO=RDG - Workstation Lockdown"
  echo "PWPOLICY_GPO=Default Domain Policy"
  echo "MIN_PW_LEN=$(sec MinimumPasswordLength)"
  echo "FORCE_CMD=gpupdate /force"
  echo "RSOP_CMD=gpresult /r"
  echo "PROCESSING_ORDER=LSDOU"
  echo "EFFECTIVE_BANNER_GPO=RDG - Workstation Lockdown"
  echo "MAX_PW_AGE=$(sec MaximumPasswordAge)"
  echo "ROGUE_GPO=$rogue"
  echo "ROGUE_LINK=DC=ridgeline,DC=local"
  echo "ROGUE_SCRIPT=$script"
} > /root/answers.txt

# Remediation: cut the attacker's link at the domain root (the legitimate GPOs stay).
samba-tool gpo dellink "$DOM" "$rguid" $H >/dev/null
