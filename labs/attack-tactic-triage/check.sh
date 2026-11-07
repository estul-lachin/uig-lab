# Checks for attack-tactic-triage (see templates/lab/check.sh for the rules).
# The learner classifies each case by ATT&CK tactic in /root/answers.txt. Every
# check is default-false: a fresh answers file is blank, so nothing passes.
#
# Accepts the tactic NAME or its TA id. Uses the current v19 (2026) matrix, so the
# split cases require Stealth / Defense Impairment, not the retired "Defense Evasion".

ANS=/root/answers.txt
val()  { grep -E "^$1=" "$ANS" 2>/dev/null | head -n1 | cut -d= -f2- ; }
norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -d '[:space:][:punct:]' ; }
# True when the (normalised) answer for field $1 matches regex $2.
want() { printf '%s' "$(norm "$(val "$1")")" | grep -qE "$2"; }

section "1. Early lifecycle: get in and run code"
check "Case 01 - mass port scanning from one external IP = Reconnaissance" \
  'want CASE_01 "reconnaissance|recon|ta0043"' "gathering info on the target before touching it"
check "Case 02 - pre-staged look-alike domains and VPS infrastructure = Resource Development" \
  'want CASE_02 "resourcedevelopment|resourcedev|ta0042"' "building/buying infrastructure and tooling"
check "Case 03 - phishing attachment giving the first foothold = Initial Access" \
  'want CASE_03 "initialaccess|ta0001"' "the first foothold (here: phishing)"
check "Case 04 - winword spawning encoded PowerShell = Execution" \
  'want CASE_04 "execution|ta0002"' "running malicious code (Command and Scripting Interpreter)"

section "2. Hold ground and climb"
check "Case 05 - scheduled task that relaunches at logon = Persistence" \
  'want CASE_05 "persistence|ta0003"' "surviving reboots / logoffs"
check "Case 06 - stealing a SYSTEM token to run higher = Privilege Escalation" \
  'want CASE_06 "privilegeescalation|privesc|ta0004"' "gaining higher permissions"

section "3. The v19 split: hiding vs breaking the tooling"
check "Case 07 - masquerading as svchost to blend in = Stealth (TA0005)" \
  'want CASE_07 "stealth|ta0005"' "hide and look normal; tooling left intact (NOT the retired Defense Evasion)"
check "Case 08 - disabling Defender / the EDR sensor = Defense Impairment (TA0112)" \
  'want CASE_08 "defenseimpairment|defenceimpairment|ta0112"' "break/blind security tooling (NOT the retired Defense Evasion)"

section "4. Credentials, discovery, spread"
check "Case 09 - dumping LSASS for hashes = Credential Access" \
  'want CASE_09 "credentialaccess|credaccess|ta0006"' "stealing account credentials"
check "Case 10 - whoami/net group/systeminfo enumeration = Discovery" \
  'want CASE_10 "discovery|ta0007"' "learning about the environment"
check "Case 11 - PsExec to other servers with a stolen hash = Lateral Movement" \
  'want CASE_11 "lateralmovement|lateral|ta0008"' "moving to other systems"

section "5. Take the data and cause harm"
check "Case 12 - staging files into one archive = Collection" \
  'want CASE_12 "collection|ta0009"' "gathering the target data"
check "Case 13 - jittered HTTPS beaconing to an operator = Command and Control" \
  'want CASE_13 "commandandcontrol|c2|commandcontrol|ta0011"' "communicating with compromised hosts"
check "Case 14 - 2.3 GB leaving over the C2 channel = Exfiltration" \
  'want CASE_14 "exfiltration|exfil|ta0010"' "stealing the data out"
check "Case 15 - mass encryption with ransom notes = Impact" \
  'want CASE_15 "impact|ta0040"' "disrupt, destroy, extort (Data Encrypted for Impact)"

section "6. Know the current matrix"
check "answers.txt: Defense Evasion was split into Stealth AND Defense Impairment" \
  'v="$(norm "$(val V19_SPLIT)")"; printf "%s" "$v" | grep -q "stealth" && printf "%s" "$v" | grep -qE "defen[sc]eimpairment"' \
  "the v19 (2026) currency point"
