# Reference solution for waf-modsecurity-crs. Runs as root inside the WAF container.
#
# The WAF ships in DetectionOnly (it logs attacks but lets them through). Turn on
# enforcement and add a custom rule in the override file, reload, then the CRS
# blocks SQLi/XSS/LFI with 403 and your rule blocks the marker.
set -euo pipefail

OVERRIDE=/etc/modsecurity.d/modsecurity-override.conf

# 1 + 3: enable the engine and add a custom deny rule. The override file is loaded
# after the CRS, so SecRuleEngine On here wins over the DetectionOnly default.
cat >> "$OVERRIDE" <<'CONF'

# --- lab solution ---
SecRuleEngine On
SecRule ARGS "@contains malbeacon" "id:900100,phase:2,deny,status:403,log,msg:'Custom block: malbeacon marker'"
CONF

# Reload nginx so ModSecurity re-reads the rules.
nginx -s reload
sleep 2

# Drive one SQL-injection request so the block is recorded in the audit log.
curl -s -o /dev/null -G 'http://localhost:8080/search' --data-urlencode "id=1' OR '1'='1" || true
sleep 1

# 2: record the concept answers.
cat > /root/answers.txt <<'EOF'
MASTER_SWITCH=SecRuleEngine
ALERT_ONLY=DetectionOnly
BLOCK_CODE=403
HOW_DECIDES=anomaly scoring
SQLI_FAMILY=942
EOF
