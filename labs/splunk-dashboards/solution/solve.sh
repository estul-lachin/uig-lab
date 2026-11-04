# Reference solution for splunk-dashboards: the same searches, the report and the dashboard over REST.
set -eu
API=https://splunk:8089
AUTH=admin:Lab-Splunk-2026
W="index=main sourcetype=access_combined"
q() { curl -sk -u "$AUTH" --max-time 60 "$API/services/search/jobs/export" --data-urlencode "search=$1" \
        -d output_mode=csv -d earliest_time=0 | tail -n +2 | tr -d '"\r'; }
for _ in $(seq 1 90); do [ "$(q '| tstats count where index=main')" = 6429 ] && break; sleep 5; done

{
  echo "SINGLE_503=$(q "search $W status=503 | stats count")"
  echo "PIE_SLICES=$(q "search $W status=403 | stats dc(clientip)")"
  echo "TOP_NON200=$(q "search $W status!=200 | top limit=1 status | table status")"
  echo "POST_COUNT=$(q "search $W method=POST | stats count")"
  echo "TOP_CLIENT_COUNT=$(q "search $W | top limit=1 clientip | table count")"
  echo "OUTAGE_HOST=$(q "search $W status=503 | top limit=1 host | table host")"
  echo "ALL_PANELS=yes"
} > /root/answers.txt

# The report, shared with the app
curl -sk -u "$AUTH" -o /dev/null -X DELETE "$API/servicesNS/admin/search/saved/searches/Top%20Clients" || true
curl -sk -u "$AUTH" -o /dev/null "$API/servicesNS/admin/search/saved/searches" -d name="Top Clients" \
  --data-urlencode "search=$W | top clientip" -d dispatch.earliest_time=0
curl -sk -u "$AUTH" -o /dev/null "$API/servicesNS/admin/search/saved/searches/Top%20Clients/acl" -d sharing=app -d owner=admin

# A Classic (Simple XML) dashboard with the six panels
xml=$(cat <<XML
<dashboard version="1.1">
  <label>SOC_Dashboard</label>
  <row>
    <panel><title>503s</title><single><search><query>$W status=503 | stats count</query><earliest>0</earliest></search></single></panel>
    <panel><title>Blocked by the WAF</title><chart><search><query>$W status=403 | stats count by clientip</query><earliest>0</earliest></search><option name="charting.chart">pie</option></chart></panel>
  </row>
  <row>
    <panel><title>Status codes (not 200)</title><chart><search><query>$W status!=200 | stats count by status</query><earliest>0</earliest></search><option name="charting.chart">bar</option></chart></panel>
    <panel><title>Requests by method</title><chart><search><query>$W | stats count by method</query><earliest>0</earliest></search><option name="charting.chart">column</option></chart></panel>
  </row>
  <row>
    <panel><title>503s per host</title><chart><search><query>$W status=503 | timechart span=10m count by host</query><earliest>0</earliest></search><option name="charting.chart">line</option></chart></panel>
    <panel><title>Top Clients</title><table><search ref="Top Clients"></search></table></panel>
  </row>
</dashboard>
XML
)
curl -sk -u "$AUTH" -o /dev/null -X DELETE "$API/servicesNS/admin/search/data/ui/views/soc_dashboard" || true
curl -sk -u "$AUTH" -o /dev/null "$API/servicesNS/admin/search/data/ui/views" -d name=soc_dashboard --data-urlencode "eai:data=$xml"
