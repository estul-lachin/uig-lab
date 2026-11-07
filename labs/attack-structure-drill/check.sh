# Checks for attack-structure-drill (see templates/lab/check.sh for the rules).
# The learner applies the ATT&CK object model in /root/answers.txt. Every check is
# default-false: a fresh answers file is blank, so nothing passes.

ANS=/root/answers.txt
val()  { grep -E "^$1=" "$ANS" 2>/dev/null | head -n1 | cut -d= -f2- ; }
norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -d '[:space:][:punct:]' ; }
want() { printf '%s' "$(norm "$(val "$1")")" | grep -qE "$2"; }

section "1. The ID scheme (object types)"
check "ID A (TA0002) is a tactic" 'want ID_A "^tactic$"' "TA prefix = Tactic"
check "ID B (T1059) is a technique" 'want ID_B "^technique$"' "T prefix = Technique"
check "ID C (T1059.001) is a sub-technique" 'want ID_C "subtechnique"' "T + .nnn = Sub-technique"
check "ID D (S0154) is software" 'want ID_D "software|malware|tool"' "S prefix = Software (malware/tools)"
check "ID E (G0016) is a group" 'want ID_E "group|actor|adversary|intrusionset"' "G prefix = Group"
check "ID F (C0001) is a campaign" 'want ID_F "campaign"' "C prefix = Campaign"
check "ID G (M1049) is a mitigation" 'want ID_G "mitigation|defen[sc]e"' "M prefix = Mitigation"

section "2. The Pyramid of Pain"
check "the TOP (most pain) level is TTPs" \
  'want PAIN_MOST "^ttps?$|tacticstechniques"' "TTPs are hardest to change - ATT&CK lives here"
check "the BOTTOM (least pain) level is Hash Values" \
  'want PAIN_LEAST "hash"' "hashes are trivial for the adversary to swap"

section "3. The object-model levels"
check "Item 1 ('Persistence', a column) is a tactic" 'want LEVEL_1 "^tactic$"' "a matrix column = the why = tactic"
check "Item 2 ('Command and Scripting Interpreter', T1059) is a technique" 'want LEVEL_2 "^technique$"' "a matrix cell = the how = technique"
check "Item 3 (an APT29 Procedure Example) is a procedure" 'want LEVEL_3 "procedure"' "a real actor/tool implementation = procedure"

section "4. Foundations"
check "ACRONYM: Adversarial Tactics, Techniques, and Common Knowledge" \
  'v="$(norm "$(val ACRONYM)")"; printf "%s" "$v" | grep -q "adversarial" && printf "%s" "$v" | grep -q "common"' \
  "Adversarial Tactics, Techniques, and Common Knowledge"
check "MAINTAINER: MITRE" 'want MAINTAINER "mitre"' "the non-profit that curates ATT&CK"
check "PHILOSOPHY: threat-informed defense" 'want PHILOSOPHY "threatinformed"' "prioritise defenses around real adversary behaviour"

section "5. The v18 detection model"
check "the PLAN (what behaviour to look for) is the Detection Strategy" \
  'want PLAN "detectionstrategy"' "DET#### - the structured plan, replacing the old Detection paragraph"
check "the IMPLEMENTATION (platform-specific logic) is the Analytic" \
  'want IMPLEMENTATION "analytic"' "AN#### - one per platform, pointing at exact telemetry"
check "a Detection Strategy id prefix is DET" 'want DET_PREFIX "^det$"' "DET0119"
check "an Analytic id prefix is AN" 'want AN_PREFIX "^an$"' "AN0351"
check "Log Sources now live inside Data Components" \
  'want LOGSOURCE_HOME "datacomponent"' "v18 moved Log Sources inside Data Components"
check "the Windows Security event log is named wineventlog:security" \
  'want WIN_SECURITY "wineventlogsecurity"' "the clear source:channel naming convention"
