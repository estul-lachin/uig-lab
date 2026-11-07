# Checks for attack-navigator-coverage (see templates/lab/check.sh for the rules).
# The learner authors a Navigator layer JSON and does a gap analysis. Every check
# is default-false: a fresh box has no /root/attack-layer.json and blank answers.

LAYER=/root/attack-layer.json
ANS=/root/answers.txt
# The six techniques of the attack chain in /opt/nav/report.txt.
SIX="T1566.001 T1059.001 T1105 T1003.001 T1021.001 T1486"

val()  { grep -E "^$1=" "$ANS" 2>/dev/null | head -n1 | cut -d= -f2- ; }
norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9' ; }
want() { printf '%s' "$(norm "$(val "$1")")" | grep -qE "$2"; }

valid_json()  { jq -e . "$LAYER" >/dev/null 2>&1; }
valid_layer() { jq -e '.domain=="enterprise-attack" and (.versions|type=="object") and (.techniques|type=="array")' "$LAYER" >/dev/null 2>&1; }
has_all_six() { for id in $SIX; do jq -e --arg i "$id" '(.techniques//[])|map(.techniqueID)|index($i)!=null' "$LAYER" >/dev/null 2>&1 || return 1; done; }
all_scored()  { for id in $SIX; do jq -e --arg i "$id" '(.techniques//[])|map(select(.techniqueID==$i))|.[0].score|type=="number"' "$LAYER" >/dev/null 2>&1 || return 1; done; }

# GAPS must name the three uncovered techniques and none of the three covered ones.
gaps_ok() {
  g="$(norm "$(val GAPS)")"
  printf '%s' "$g" | grep -q 't1566001' && printf '%s' "$g" | grep -q 't1105' && printf '%s' "$g" | grep -q 't1021001' \
  && ! printf '%s' "$g" | grep -q 't1059001' && ! printf '%s' "$g" | grep -q 't1003001' && ! printf '%s' "$g" | grep -q 't1486'
}

section "1. Build the attack-chain Navigator layer"
check "/root/attack-layer.json is valid JSON" 'valid_json' "a Navigator layer is a JSON file"
check "it is a valid Navigator Enterprise layer (domain, versions, techniques[])" \
  'valid_layer' "domain = enterprise-attack, with a versions object and a techniques array"
check "the layer contains all six attack-chain techniques" \
  'has_all_six' "T1566.001, T1059.001, T1105, T1003.001, T1021.001, T1486"
check "each of the six techniques has a numeric score (drives the heatmap)" \
  'all_scored' "scoring is what colours the cells"

section "2. Coverage gap analysis"
check "GAPS lists the three uncovered techniques (and none of the covered ones)" \
  'gaps_ok' "attack chain minus the coverage layer: T1566.001, T1105, T1021.001"

section "3. Navigator concepts"
check "UNIT: the core unit of work is a layer" 'want UNIT "layer"' "a saved, annotated view of the matrix"
check "FORMAT: a layer is saved/shared as JSON" 'want FORMAT "json"' "download the JSON and re-import it"
check "OVERLAY: combine two layers with a score expression" \
  'want OVERLAY "expression|scoreexpression|^ab$|a\\+b"' "e.g. a + b, to overlay group vs coverage"
check "ANALYSIS: this enables gap analysis" 'want ANALYSIS "gap"' "red cells are your blind spots / to-build list"
