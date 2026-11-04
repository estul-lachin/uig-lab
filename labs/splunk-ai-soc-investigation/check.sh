# Checks for splunk-ai-soc-investigation (see templates/lab/check.sh for the rules).
# Runs on the workstation and asks Splunk over its REST API.

API=https://splunk:8089
AUTH=admin:Lab-Splunk-2026
AGENT=ai-agent:Agent-RO-2026
TOTAL=5912   # events in web, network and linux
A=/root/case/answers.txt
_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n1 | tr -d "[:space:]"; }
_spl() { curl -sk -u "${2:-$AUTH}" --max-time 90 "$API/services/search/jobs/export" --data-urlencode "search=$1" -d output_mode=csv -d earliest_time=0 2>/dev/null | tail -n +2 | tr -d '"\r'; }
_role() { curl -sk -u $AUTH -G "$API/services/authorization/roles/soc_agent_ro" -d output_mode=json 2>/dev/null | jq -c '.entry[0].content'; }
_user() { curl -sk -u $AUTH -G "$API/services/authentication/users/ai-agent" -d output_mode=json 2>/dev/null | jq -c '.entry[0].content'; }
_kc() { _spl "| tstats count where index=web OR index=network OR index=linux"; }

for _ in $(seq 1 60); do [ "$(_kc)" = "$TOTAL" ] && break; sleep 5; done

section "0. Splunk is ready"
check "Splunk answers and has indexed all $TOTAL events in web, network and linux" '[ "$(_kc)" = $TOTAL ]' \
  "Splunk needs a few minutes after ./lab up (longer the first time, under emulation); run the check again"

section "1. The kill chain"
check "ATTACKER_IP: the source of the UNION SELECT requests" '[ "$(_kv $A ATTACKER_IP)" = 203.0.113.66 ]' "Both words in one search: one word alone also finds shoppers"
check "INJECTED_PARAM: the products.php parameter that carried it" '[ "$(_kv $A INJECTED_PARAM)" = cat ]' "Which parameter changes between the injected requests?"
check "DUMPED_TABLE: the table whose rows were read out" '[ "$(_kv $A DUMPED_TABLE | tr A-Z a-z)" = customers ]' "The last payloads, and the largest responses"
check "WEB_SHELL: the file name of the web shell" '[ "$(_kv $A WEB_SHELL)" = img_cache.php ]' "Requests with c= and a curl user-agent; the uptime check uses curl too"
check "PAYLOAD_PATH: where wget saved the second stage" '[ "$(_kv $A PAYLOAD_PATH)" = /var/tmp/.font-cache ]' "The target of -O, URL-decoded"
check "SSH_ACCOUNT: the account of the one password login" '[ "$(_kv $A SSH_ACCOUNT)" = shopsync ]' "Accepted password, not Accepted publickey"
check "C2_PORT: the port of the outbound connection" '[ "$(_kv $A C2_PORT)" = 8081 ]' "Suricata alerts whose source is 10.40.2.13"

section "2. Checking the agent"
check "WRONG_CLAIMS lists the findings of the agent that the data contradicts" '[ "$(_kv $A WRONG_CLAIMS | tr "," "\n" | grep . | sort -un | paste -sd,)" = 3,5,6 ]' \
  "Compare each of the six findings in agent-notes.md with what you found; comma-separated numbers"

section "3. A least-privilege account for the agent"
check "Role soc_agent_ro may search exactly web, network and linux" '[ "$(_role | jq -r ".srchIndexesAllowed | sort | join(\",\")")" = linux,network,web ]' \
  "Settings > Roles > New Role > Indexes"
check "...inherits no powerful role and holds no admin capabilities" 'r=$(_role); [ -n "$r" ] && echo "$r" | jq -e "(.capabilities | index(\"search\")) and ([.imported_roles[] | select(. == \"admin\" or . == \"sc_admin\" or . == \"power\" or . == \"can_delete\")] | length == 0) and ([(.capabilities + .imported_capabilities)[] | select(test(\"^(admin_all_objects|edit_user|edit_roles|indexes_edit|delete_by_keyword|change_authentication|edit_tcp|edit_server|rest_apps_management|install_apps)\$\"))] | length == 0)" >/dev/null' \
  "Start from nothing (or from user), add search; no admin, power or can_delete"
check "User ai-agent has only that role" '[ "$(_user | jq -r ".roles | join(\",\")")" = soc_agent_ro ]' "Settings > Users > New User, password Agent-RO-2026"
check "...and as ai-agent, Splunk shows web" '[ "$(_spl "| tstats count where index=web" $AGENT)" = 4152 ]' "Log in as ai-agent and search index=web"
check "...but nothing in main" '[ "$(_spl "| tstats count where index=web" $AGENT)" = 4152 ] && [ "$(_spl "| tstats count where index=main" $AGENT)" = 0 ]' \
  "Only the three indexes are allowed"
check "...and cannot create an index or a user" '[ "$(_spl "| tstats count where index=web" $AGENT)" = 4152 ] && [ "$(curl -sk -u $AGENT -o /dev/null -w "%{http_code}" "$API/services/data/indexes" -d name=lab-probe)" != 201 ] && [ "$(curl -sk -u $AGENT -o /dev/null -w "%{http_code}" "$API/services/authentication/users" -d name=lab-probe -d password=Lab-Probe-2026 -d roles=user)" != 201 ]' \
  "No indexes_edit, no edit_user"
