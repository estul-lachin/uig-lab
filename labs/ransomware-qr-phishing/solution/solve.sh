# Reference solution for ransomware-qr-phishing.
set -euo pipefail
cd /root/case/logs

phish=$(jq -c 'select(.qr_code_url != null)' mail.jsonl)
enc=$(jq -r 'select(.command_line | test(" -enc ")) | .command_line' endpoint.jsonl | awk '{print $NF}')
printf '%s' "$enc" | base64 -d | iconv -f UTF-16LE -t UTF-8 > /root/case/decoded.txt

{
  echo "PHISH_SENDER=$(echo "$phish" | jq -r .from | sort -u)"
  echo "QR_DOMAIN=$(echo "$phish" | jq -r .qr_code_url | sort -u | awk -F/ '{print $3}')"
  echo "PHISH_RECIPIENTS=$(echo "$phish" | jq -r .to | sort -u | wc -l)"
  echo "ATTACKER_IP=$(jq -r 'select(.event == "password_accepted") | .src_ip' idp.jsonl)"
  echo "MFA_PUSHES=$(jq -r 'select(.event == "mfa_push_sent") | .time' idp.jsonl | wc -l)"
  echo "APPROVED_AT=$(jq -r 'select(.event == "mfa_push_approved") | .time' idp.jsonl)"
  echo "NEW_ADMIN=$(jq -r 'select(.action == "account_created") | .target' directory.jsonl)"
  echo "ADMIN_GROUP=$(jq -r 'select(.target == "svc-backup2" and .group != null) | .group' directory.jsonl)"
  echo "CREATED_BY=$(jq -r 'select(.action == "account_created") | .actor' directory.jsonl)"
  echo "PS_HOST=$(jq -r 'select(.command_line | test(" -enc ")) | .host' endpoint.jsonl)"
  echo "STAGING_FILE=$(grep -o 'C:\\Users\\Public\\[^ ;]*' /root/case/decoded.txt | head -n1)"
  echo "EXFIL_DOMAIN=$(grep -o 'https://[^/]*' /root/case/decoded.txt | head -n1 | cut -d/ -f3)"
  echo "EXFIL_MB=$(jq -s '[.[] | select(.method == "PUT") | .bytes_out] | add / 1048576 | floor' proxy.jsonl)"
  echo "ATT_INITIAL_ACCESS=T1566.002"
  echo "ATT_MFA=T1621"
  echo "ATT_LOGIN=T1078"
  echo "ATT_PERSISTENCE=T1136.002"
  echo "ATT_EXECUTION=T1059.001"
  echo "ATT_EXFIL=T1567.002"
  echo "CASE_WANNACRY=T1210"
  echo "CASE_COLONIAL=T1133"
  echo "CASE_MGM=T1656"
  echo "CASE_CHANGE=T1133"
} > /root/case/answers.txt

cat > /root/case/response.md <<'R'
# Immediate response
1. Disable svc-backup2 and remove it from Domain Admins
2. Reset priya.n's password, revoke all her sessions and MFA registrations
3. Network-isolate FIN-WS-07 and keep it for forensics
4. Block files.drop-share.net, lumen-benefits-portal.com and 203.0.113.80 at the proxy and firewall
5. Purge the phishing mail from all six mailboxes and warn the recipients
6. Tell legal/privacy: finance data left the company
R
