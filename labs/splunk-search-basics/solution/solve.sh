# Reference solution for splunk-search-basics: the same searches over the REST API.
set -euo pipefail
API=https://splunk:8089
AUTH=admin:Lab-Splunk-2026
q() { curl -sk -u "$AUTH" --max-time 60 "$API/services/search/jobs/export" --data-urlencode "search=$1" \
        -d output_mode=csv -d earliest_time=0 | tail -n +2 | tr -d '"\r'; }

for _ in $(seq 1 90); do [ "$(q '| tstats count where index=main')" = 5286 ] && break; sleep 5; done

brute=$(q 'search index=main sourcetype=linux_secure "Failed password" | rex "from (?<src_addr>\S+) port" | stats count by src_addr | sort - count | head 1 | table src_addr')
{
  echo "COUNT_ACCESS=$(q '| tstats count where index=main sourcetype=access_combined')"
  echo "SOURCETYPES=$(q '| metadata type=sourcetypes index=main | stats count')"
  echo "STATUS_VALUES=$(q 'search index=main sourcetype=access_combined | stats dc(status)')"
  echo "SMART_TAB=Statistics"
  echo "COUNT_SECURE=$(q '| tstats count where index=main sourcetype=linux_secure')"
  echo "WINDOW_COUNT=$(q 'search index=main sourcetype=access_combined earliest="10/29/2026:03:00:00" latest="10/29/2026:03:30:00" | stats count')"
  echo "BRUTE_IP=$brute"
  echo "BREACHED_USER=$(q 'search index=main sourcetype=linux_secure "Accepted password" | rex "for (?<acct>\S+) from (?<from_ip>\S+) port" | search from_ip="'"$brute"'" | head 1 | table acct')"
  echo "SCANNER_IP=$(q 'search index=main sourcetype=access_combined "/wp-login.php" | stats count by clientip | sort - count | head 1 | table clientip')"
  echo "SCANNER_SIGNATURE=$(q 'search index=main sourcetype=suricata src_ip="198.51.100.77" | stats count by alert.signature | sort - count | head 1 | table alert.signature')"
} > /root/answers.txt

# The saved report (what Save As > Report creates)
curl -sk -u "$AUTH" "$API/servicesNS/admin/search/saved/searches/ssh-failures-by-src" -X DELETE -o /dev/null || true
curl -sk -u "$AUTH" "$API/servicesNS/admin/search/saved/searches" -o /dev/null \
  -d name=ssh-failures-by-src \
  --data-urlencode 'search=index=main sourcetype=linux_secure "Failed password" | rex "from (?<src_addr>\S+) port" | stats count by src_addr | sort - count' \
  -d dispatch.earliest_time=0
