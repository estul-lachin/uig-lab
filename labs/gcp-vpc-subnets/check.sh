# Checks for gcp-vpc-subnets (see templates/lab/check.sh for the rules).
# Everything is read back through gcloud itself, the way an auditor would. Answers in
# /root/answers.txt are compared case-insensitively.

A=/root/answers.txt
_kv() { sed -n "s/^$1=//p" "$A" 2>/dev/null | head -n1 | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }
_lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
_is() { _v=$(_kv "$1"); [ -n "$_v" ] && [ "$(_lc "$_v")" = "$(_lc "$2")" ]; }
_net() { gcloud compute networks describe "$1" --format="value($2)" 2>/dev/null; }
_sub() { gcloud compute networks subnets describe "$1" --region="$2" --format="value($3)" 2>/dev/null; }

section "1. A custom mode VPC"
check "Network ledger-net exists" '[ "$(_net ledger-net name)" = ledger-net ]' \
  "gcloud compute networks create"
check "...in custom subnet mode (no subnets created for you)" '[ "$(_net ledger-net autoCreateSubnetworks)" = False ]' \
  "Without --subnet-mode you get auto mode and twelve subnets you did not plan: delete the network and create it again"

section "2. Planned subnets"
check "ledger-app is in us-central1, in ledger-net" '[ "$(_sub ledger-app us-central1 "network.basename()")" = ledger-net ]' \
  "gcloud compute networks subnets create, with --network and --region"
check "...with the range 10.40.1.0/24" '[ "$(_sub ledger-app us-central1 ipCidrRange)" = 10.40.1.0/24 ]'
check "ledger-db is in europe-west1, in ledger-net" '[ "$(_sub ledger-db europe-west1 "network.basename()")" = ledger-net ]'
check "...with the range 10.40.2.0/24" '[ "$(_sub ledger-db europe-west1 ipCidrRange)" = 10.40.2.0/24 ]'
check "...and Private Google Access on" '[ "$(_sub ledger-db europe-west1 privateIpGoogleAccess)" = True ]' \
  "A flag on subnets create or subnets update; describe the subnet to see the field"
check "ledger-net holds exactly these two subnets" \
  '[ "$(gcloud compute networks subnets list --network=ledger-net --format="value(name)" 2>/dev/null | sort | tr "\n" " ")" = "ledger-app ledger-db " ]' \
  "List the subnets of ledger-net and delete anything that is not in the plan"

section "3. Inventory"
check "PROJECT: the project ID of this Cloud Shell" '_is PROJECT larchmere-netsec-sbx' "gcloud config"
check "DEFAULT_MODE: the subnet mode of the default network" '_is DEFAULT_MODE auto' "networks list has a column for it"
check "DEFAULT_SUBNETS: how many subnets the default network has" '_is DEFAULT_SUBNETS 12' \
  "Count the lines of a subnets list for one network, without the header"
check "TEMP_NET_CREATED: the day temp-net was created (YYYY-MM-DD)" '_is TEMP_NET_CREATED 2026-08-19' \
  "describe shows creationTimestamp"
check "SHARED_RANGE: the range both default and temp-net use in europe-west1" '_is SHARED_RANGE 10.132.0.0/20' \
  "Filter the subnet list by region"

section "4. Clean-up and visibility"
check "temp-net is gone, and default is still there" \
  '[ "$(_net default name)" = default ] && ! gcloud compute networks describe temp-net >/dev/null 2>&1' \
  "gcloud compute networks delete; its auto mode subnets go with it"
check "VPC Flow Logs are on for ledger-app" '[ "$(_sub ledger-app us-central1 logConfig.enable)" = True ]' \
  "subnets update has a flag for flow logs"
check "VPC Flow Logs are on for ledger-db" '[ "$(_sub ledger-db europe-west1 logConfig.enable)" = True ]'
