#!/usr/bin/env bash
# Container entrypoint: the share's ACLs first, then the domain controller in the foreground.
set -eu
bash /usr/local/sbin/lab-acls >/dev/null
exec samba --interactive --no-process-group --debuglevel=1
