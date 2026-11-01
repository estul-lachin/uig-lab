# lib/check-lib.sh - helpers shared by every lab's check.sh.
#
# Not run directly. `./lab check <name>` pipes preamble lines, this file, the lab's check.sh
# and a final `summary` call into `bash -s` inside the lab container. Preamble variables:
#   KL_FORMAT=json   print one JSON object per check instead of human-readable output
#   FORCE_COLOR=0|1  emit ANSI colors in human mode (stdout in the container is never a TTY)

KL_FORMAT=${KL_FORMAT:-human}
FORCE_COLOR=${FORCE_COLOR:-0}
_KL_PASS=0
_KL_FAIL=0
_KL_SECTION=""

if [ "$FORCE_COLOR" = 1 ] && [ "$KL_FORMAT" != json ]; then
  _KL_G=$'\e[32m' _KL_R=$'\e[31m' _KL_Y=$'\e[33m' _KL_B=$'\e[1m' _KL_0=$'\e[0m'
else
  _KL_G="" _KL_R="" _KL_Y="" _KL_B="" _KL_0=""
fi

# Escape $1 as the inside of a JSON string; result in REPLY.
# Quoted patterns and replacements keep everything literal (also with patsub_replacement).
_kl_json_escape() {
  local s=$1 i ch rep
  s=${s//'\'/'\\'}
  s=${s//'"'/'\"'}
  s=${s//$'\n'/'\n'}
  s=${s//$'\t'/'\t'}
  s=${s//$'\r'/'\r'}
  for i in {1..31} 127; do
    case $i in 9|10|13) continue ;; esac
    printf -v ch "\\x$(printf %02x "$i")"
    [[ $s == *"$ch"* ]] || continue
    printf -v rep '\\u%04x' "$i"
    s=${s//"$ch"/"$rep"}
  done
  REPLY=$s
}

# section "Title" - start a group of checks.
section() {
  _KL_SECTION=$1
  if [ "$KL_FORMAT" != json ]; then
    printf '\n%s== %s ==%s\n' "$_KL_B" "$1" "$_KL_0"
  fi
}

# check "description" 'command string' ["hint on failure"]
# The command is eval'ed in a subshell with stdin/stdout/stderr detached.
check() {
  local desc=$1 cmd=$2 hint=${3-} ok
  if ( eval "$cmd" ) </dev/null >/dev/null 2>&1; then
    ok=true; _KL_PASS=$((_KL_PASS + 1))
  else
    ok=false; _KL_FAIL=$((_KL_FAIL + 1))
  fi
  if [ "$KL_FORMAT" = json ]; then
    local js jd jh
    _kl_json_escape "$_KL_SECTION"; js=$REPLY
    _kl_json_escape "$desc"; jd=$REPLY
    if [ -n "$hint" ]; then _kl_json_escape "$hint"; jh="\"$REPLY\""; else jh=null; fi
    printf '{"section":"%s","desc":"%s","ok":%s,"hint":%s}\n' "$js" "$jd" "$ok" "$jh"
  elif [ "$ok" = true ]; then
    printf '  %s✔%s %s\n' "$_KL_G" "$_KL_0" "$desc"
  else
    printf '  %s✘%s %s\n' "$_KL_R" "$_KL_0" "$desc"
    [ -n "$hint" ] && printf '    %s→ %s%s\n' "$_KL_Y" "$hint" "$_KL_0"
  fi
  return 0
}

# as_user <user> 'command' - run a command as another user.
# Uses setpriv, not su: su goes through PAM and hangs on a forced password change (chage -d 0).
as_user() {
  local u=$1
  setpriv --reuid="$(id -u "$u")" --regid="$(id -g "$u")" --init-groups \
    env HOME="/home/$u" USER="$u" LOGNAME="$u" bash -c "$2" </dev/null
}

# summary - print the totals; exit 1 if any check failed.
summary() {
  local total=$((_KL_PASS + _KL_FAIL))
  if [ "$KL_FORMAT" = json ]; then
    printf '{"summary":true,"pass":%d,"fail":%d}\n' "$_KL_PASS" "$_KL_FAIL"
  elif [ "$_KL_FAIL" -eq 0 ]; then
    printf '\n%sAll passed: %d/%d%s\n' "$_KL_G" "$_KL_PASS" "$total" "$_KL_0"
  else
    printf '\n%sPassed %d/%d, %d remaining%s\n' "$_KL_Y" "$_KL_PASS" "$total" "$_KL_FAIL" "$_KL_0"
  fi
  [ "$_KL_FAIL" -eq 0 ] && [ "$total" -gt 0 ] && exit 0
  exit 1
}
