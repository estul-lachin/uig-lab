# Checks for ssrf-cloud-metadata (see templates/lab/check.sh for the rules).
# Runs inside the container. Every check is default-false: a fresh box has blank
# answers and no /flag/solved, so nothing passes until the learner makes the
# server fetch the metadata service and steal its credentials.

ANS=/root/answers.txt
FLAG=/flag/solved

val()  { grep -E "^$1=" "$ANS" 2>/dev/null | head -n1 | cut -d= -f2- ; }
norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -d '[:space:]' ; }

metadata_ip_ok() { printf '%s' "$(val METADATA_IP)" | grep -q '169\.254\.169\.254'; }
stolen_ok()      { printf '%s' "$(norm "$(val STOLEN)")" | grep -qE 'iam|credential|key|aws|token|secret|accesskey'; }
defense_ok()     { printf '%s' "$(val DEFENSE)" | grep -qiE 'allow ?list|white ?list|block.*(internal|link.?local|metadata|private|169)|deny.*(internal|metadata)|validate|egress|imdsv2|disable.*metadata|no.*raw.*fetch'; }

flag_present()   { [ -f "$FLAG" ]; }
# The flag carries the stolen IAM access key (AKIA...), written by the app only
# when the forged request actually reached the metadata credentials.
flag_has_key()   { grep -q 'AKIA' "$FLAG" 2>/dev/null; }

section "1. Recon: identify the target"
check "answers.txt: the metadata service IP is 169.254.169.254" \
  'metadata_ip_ok' "the cloud instance metadata service (IMDS) lives at this link-local address"
check "answers.txt: you exfiltrated the instance's IAM credentials/keys" \
  'stolen_ok' "the IMDS hands out the instance role's temporary AWS credentials"

section "2. Exploit: forge a server-side request to the metadata service"
check "/flag/solved exists (the server fetched the metadata credentials for you)" \
  'flag_present' "GET /fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/<role>"
check "the flag contains the stolen AWS access key (AKIA...)" \
  'flag_has_key' "the credentials the server returned through the SSRF"

section "3. Name the fix"
check "answers.txt: names a correct SSRF defense" \
  'defense_ok' "allow-list the hosts, block internal/link-local/metadata addresses, require IMDSv2"
