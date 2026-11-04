# Checks for blackcat-case-study (see templates/lab/check.sh for the rules).

C=/root/case
A=$C/answers.txt
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]" | tr A-Z a-z; }
_in() { local v; v=$(_kv $A "$1"); [ -n "$v" ] && for x in $2; do [ "$v" = "$x" ] && return 0; done; return 1; }
_num() { local v; v=$(_kv $A "$1"); [ -n "$v" ] && [ "$v" -ge "$2" ] 2>/dev/null && [ "$v" -le "$3" ]; }

section "1. BlackCat in brief"
check "LANGUAGE is what it was written in" '_in LANGUAGE rust' "Memory-safe, cross-compiles to Windows, Linux and ESXi"
check "FIXED_EXTENSION says whether its file extension was fixed" '_in FIXED_EXTENSION no' "yes or no"
check "EXFIL_TOOL is the tool affiliates used to steal data" '_in EXFIL_TOOL "rclone exmatter"' "R....."
check "C2_SOFTWARE is what they used for beacons" '_in C2_SOFTWARE "cobaltstrike cobalt-strike"' "The post-exploitation framework"

section "2. The intrusion at Pinecrest Health Partners"
check "ENTRY_TICKET is the help-desk ticket that let them in" '_in ENTRY_TICKET hd-4417' "Which reset was not verified?"
check "ENTRY_USER is the account they took over" '_in ENTRY_USER j.morales' "Whose MFA was reset?"
check "ATTACKER_IP is where they signed in from" '_in ATTACKER_IP 198.51.100.44' "That account, shortly after the ticket"
check "ROGUE_TOOL_HOST is where remote-access software appeared without approval" '_in ROGUE_TOOL_HOST php-ctx01' \
  "Join the EDR events with approved-remote-tools.csv"
check "ADMIN_ACCOUNT is the privileged account it moved with" '_in ADMIN_ACCOUNT adm.cortez' "Who ran PsExec?"
check "EXFIL_HOST is the host the data left from" '_in EXFIL_HOST php-fs02' "proxy.csv, by destination"
check "EXFIL_GB is how much it uploaded, in whole GB" '_num EXFIL_GB 38 39' "Sum bytes_out to Mega; 1 GB = 1000000000 bytes"
check "MINUTES_EXFIL_TO_IMPACT is from the last upload to the first VM being killed" '_num MINUTES_EXFIL_TO_IMPACT 95 97' \
  "Last Mega upload in proxy.csv, first kill in esx01-shell.log"
check "VMS_ENCRYPTED is how many virtual machines were encrypted" '_in VMS_ENCRYPTED 7' "vmdk files renamed"
check "RANSOM_EXT is the extension it added" '[ "$(_kv $A RANSOM_EXT | tr -d .)" = qhr5zfk ]' "This build's own extension"
check "RANSOM_NOTE is the note's file name" '_in RANSOM_NOTE recover-qhr5zfk-files.txt' "File created on the datastore"
check "FATIGUE_VICTIM is the user who gave in to push bombing" '_in FATIGUE_VICTIM d.ward' "Denied, denied, denied ... approved"

section "3. An MFA-fatigue detection (mfa-fatigue.sh)"
F=$C/mfa-fatigue.sh
_s() { # USER IP MINUTE MFA RESULT
  printf '{"time":"%s","user":"%s","ip":"%s","country":"XX","app":"vpn","result":"%s","mfa":"%s"}\n' \
    "$(date -u -d "@$((1800000000 + $3 * 60))" +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" "$5" "$4"
}
_d() { _s "$1" "$2" "$3" push_denied failure; }
_ok() { _s "$1" "$2" "$3" push_approved success; }
# Sign-ins the detection has never seen: u1 and u6 gave in, the others did not (or not like that).
_unseen() {
  local i
  for i in 0 1 2 3 4 5; do _d u1 192.0.2.1 $((10 + i)); done; _ok u1 192.0.2.1 17
  for i in $(seq 0 11); do _d u2 192.0.2.2 $((10 + i)); done
  for i in 0 1 2; do _d u3 192.0.2.3 $((10 + i)); done; _ok u3 192.0.2.3 14
  for i in 0 1 2 3 4 5; do _d u4 192.0.2.4 $((10 + i)); done; _ok u4 192.0.2.40 17
  for i in 0 1 2 3 4 5; do _d u5 192.0.2.5 $((10 + i * 25)); done; _ok u5 192.0.2.5 136
  for i in 0 1 2 3 4; do _d u6 192.0.2.6 $((40 + i)); done; _ok u6 192.0.2.6 48
  for i in 0 1 2 3 4 5; do _d u7 192.0.2.7 $((10 + i)); done; _ok u7 192.0.2.7 60
}
_out() { bash $F 2>/dev/null | tr -d "\r " | grep . | sort -u | paste -sd" "; }
check "mfa-fatigue.sh exists and is executable" '[ -x $F ]' "chmod +x"
check "On the case file it flags exactly the one push-bombing that worked" '[ -x $F ] && [ "$(_out < $C/idp-signins.jsonl)" = "d.ward,203.0.113.88" ]' \
  "An approved push with at least 5 denied pushes for the same user and IP in the 10 minutes before it"
check "On sign-ins it has never seen it flags exactly the right ones" '[ -x $F ] && [ "$(_unseen | _out)" = "u1,192.0.2.1 u6,192.0.2.6" ]' \
  "Same user and IP; only the 10 minutes before the approval count; no approval, no alert"
