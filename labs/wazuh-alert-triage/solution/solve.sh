# Reference solution for wazuh-alert-triage: the same questions over the indexer and dashboard APIs.
set -euo pipefail
IDX=https://wazuh.indexer:9200
DASH=https://wazuh.dashboard:5601
AUTH=admin:Lab-Wazuh-2026
count() { curl -sk -u "$AUTH" -G "$IDX/wazuh-alerts-*/_count" --data-urlencode "q=$1" | jq -r .count; }
most() {  # most FIELD QUERY
  jq -n --arg f "$1" --arg q "$2" '{size:0, query:{query_string:{query:$q}}, aggs:{t:{terms:{field:$f, size:1}}}}' \
    | curl -sk -u "$AUTH" -H 'Content-Type: application/json' "$IDX/wazuh-alerts-*/_search" -d @- \
    | jq -r '.aggregations.t.buckets[0].key'
}

for _ in $(seq 1 90); do
  a=$(count '*' || true); sleep 10; b=$(count '*' || true)
  [ -f /feed/done ] && [ -n "$a" ] && [ "$a" = "$b" ] && break
done

# The successful login from an address that also shows up in rule 5710.
breach=$(jq -n '{size:50, _source:["data.srcip","data.dstuser"], query:{query_string:{query:"rule.groups:authentication_success"}}}' \
  | curl -sk -u "$AUTH" -H 'Content-Type: application/json' "$IDX/wazuh-alerts-*/_search" -d @- \
  | jq -r '.hits.hits[]._source.data | "\(.srcip) \(.dstuser)"' \
  | while read -r ip user; do
      if [ "$(count "rule.id:5710 AND data.srcip:\"$ip\"")" -gt 0 ]; then echo "$user"; fi
    done | sort -u | head -n1)

{
  echo "TOTAL_ALERTS=$(count '*')"
  echo "TOP_INVALID_USER_SRC=$(most data.srcip 'rule.id:5710')"
  echo "TOP_AUTH_FAILED_SRC=$(most data.srcip 'rule.groups:authentication_failed')"
  echo "TOP_SSH_USERNAME=$(most data.srcuser 'rule.id:5710')"
  echo "BREACHED_ACCOUNT=$breach"
  echo "FIM_MODIFIED=$(count 'rule.id:550')"
  echo "FIM_TOP_FILE=$(most syscheck.path 'rule.id:550')"
  echo "NEW_FILE=$(most syscheck.path 'rule.id:554')"
  echo "SQLI_ALERTS=$(count 'rule.id:31103')"
  echo "SQLI_SUCCESS_SRC=$(most data.srcip 'rule.id:31106')"
} > /root/answers.txt

# The saved search, as Discover would store it.
src=$(jq -cn '{query:{query:"rule.id:5710", language:"kuery"}, filter:[], indexRefName:"kibanaSavedObjectMeta.searchSourceJSON.index"}')
jq -n --arg s "$src" '{attributes:{title:"ssh-invalid-users", columns:["data.srcip","data.srcuser"], sort:[],
    kibanaSavedObjectMeta:{searchSourceJSON:$s}},
  references:[{name:"kibanaSavedObjectMeta.searchSourceJSON.index", type:"index-pattern", id:"wazuh-alerts-*"}]}' \
  | curl -sk -u "$AUTH" -H 'osd-xsrf: true' -H 'Content-Type: application/json' \
      -X POST "$DASH/api/saved_objects/search/ssh-invalid-users?overwrite=true" -d @- >/dev/null
