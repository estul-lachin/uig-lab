# Checks for insecure-file-upload (see templates/lab/check.sh for the rules).
# Runs inside the container. Every check is default-false: a fresh box has an
# empty uploads directory, no /flag/solved, and blank answers.

APP="http://localhost"
UPDIR=/var/www/html/uploads
ANS=/root/answers.txt
FLAG=/flag/solved

val()  { grep -E "^$1=" "$ANS" 2>/dev/null | head -n1 | cut -d= -f2- ; }
norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -d '[:space:]' ; }

trusted_ok() { v="$(norm "$(val TRUSTED_HEADER)")"; [ "${v//-/}" = contenttype ]; }
bypass_ok()  { printf '%s' "$(val BYPASS)" | grep -qiE 'php|extension|double|rename|filename|\.jpg'; }
fix_ok()     { printf '%s' "$(val FIX)" | grep -qiE 'magic|byte|random|outside|web ?root|whitelist|allow ?list|sanitiz|content|re-?encode|not? ?execut'; }

# A server-executable script sits in the served uploads dir (the check was bypassed).
script_uploaded() {
  for p in "$UPDIR"/*.php "$UPDIR"/*.phtml "$UPDIR"/*.php5 "$UPDIR"/*.phar; do
    [ -f "$p" ] && grep -q '<?php' "$p" && return 0
  done
  return 1
}

# Requesting an uploaded script returns EXECUTED output, not the raw PHP source
# (served source would still contain "<?php"). Proves real code execution.
script_executes() {
  for p in "$UPDIR"/*.php "$UPDIR"/*.phtml "$UPDIR"/*.php5 "$UPDIR"/*.phar; do
    [ -f "$p" ] && grep -q '<?php' "$p" || continue
    body="$(curl -s "$APP/uploads/$(basename "$p")" 2>/dev/null)"
    printf '%s' "$body" | grep -q '<?php' && continue   # leaked source: not executed
    return 0
  done
  return 1
}

flag_present() { [ -f "$FLAG" ]; }

section "1. Recon: understand the weak check"
check "answers.txt: the handler trusts the Content-Type header" \
  'trusted_ok' "the client fully controls that header"
check "answers.txt: your bypass abuses the filename / extension" \
  'bypass_ok' "e.g. name it shell.php (or a double extension) while sending Content-Type: image/png"

section "2. Exploit: get a script into the served directory and run it"
check "a server-executable script was uploaded into /uploads (the check was bypassed)" \
  'script_uploaded' "spoof Content-Type: image/png on a .php upload"
check "requesting the uploaded script executes it (returns output, not raw source)" \
  'script_executes' "browse /uploads/<your-shell>.php - Apache runs it"

section "3. Capture the flag and name the fix"
check "the webshell wrote /flag/solved (remote code execution achieved)" \
  'flag_present' "make your uploaded PHP write /flag/solved when it runs"
check "answers.txt: you named a correct defense against insecure upload" \
  'fix_ok' "validate magic bytes, random server-side name, store outside web root, never serve as executable"
