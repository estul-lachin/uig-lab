#!/usr/bin/env bash
# MFA fatigue (push bombing): an approved push for which the same user and IP had at least 5 denied
# pushes in the 10 minutes before it. Reads sign-ins (JSON Lines) on stdin, prints user,ip.
jq -rs '
  map(. + {t: (.time | fromdateiso8601)})
  | . as $all
  | map(select(.mfa == "push_approved")) []
  | . as $ok
  | select([$all[] | select(.mfa == "push_denied" and .user == $ok.user and .ip == $ok.ip
                            and .t < $ok.t and .t >= $ok.t - 600)] | length >= 5)
  | "\(.user),\(.ip)"' | sort -u
