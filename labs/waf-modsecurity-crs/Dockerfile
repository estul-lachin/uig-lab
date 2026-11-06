# Larkhill storefront WAF: ModSecurity v3 + the OWASP Core Rule Set, in front of
# a small backend. Built on the official OWASP CRS nginx image (pinned), which
# ships libmodsecurity3 + CRS and templates its config from environment variables.
FROM owasp/modsecurity-crs:4.25.2-nginx-202610180210-lts

# Run as root so ./lab shell / check / solve behave like the other labs, and the
# ModSecurity audit log directory is writable.
USER root

# The audit log directory the default config points at (SecAuditLog
# /var/log/modsec/audit.log) is not created by the image - make it, world-writable
# so the nginx workers can write it whatever uid they run as.
RUN mkdir -p /var/log/modsec && chmod 1777 /var/log/modsec

# The learner records IDS/WAF concepts here; checks read it. Seeded blank so a
# fresh environment passes nothing.
RUN printf '%s\n' \
  '# ModSecurity / OWASP CRS concepts - fill these in (one word or short phrase).' \
  '' \
  '# MASTER_SWITCH: the directive that turns the ModSecurity rule engine on/off' \
  'MASTER_SWITCH=' \
  '' \
  '# ALERT_ONLY: the SecRuleEngine value that inspects and logs but never blocks' \
  'ALERT_ONLY=' \
  '' \
  '# BLOCK_CODE: the HTTP status CRS returns when it blocks a request' \
  'BLOCK_CODE=' \
  '' \
  '# HOW_DECIDES: how CRS decides to block (one rule = one block, or ______ ?)' \
  'HOW_DECIDES=' \
  '' \
  '# SQLI_FAMILY: the CRS rule-id family (first 3 digits) for SQL injection' \
  'SQLI_FAMILY=' \
  > /root/answers.txt

RUN printf '%s\n' \
  'echo "Lab waf-modsecurity-crs: the WAF listens on http://localhost:8080 and proxies to the backend."' \
  'echo "Edit /etc/modsecurity.d/modsecurity-override.conf (SecRuleEngine + your custom SecRule), then run: nginx -s reload"' \
  'echo "Audit log: /var/log/modsec/audit.log   Tasks: labs/waf-modsecurity-crs/README.md"' \
  'echo "Record concepts in /root/answers.txt, then from the host: ./lab check waf-modsecurity-crs"' \
  >> /root/.bashrc
