#!/usr/bin/env bash
# Container entrypoint: the first-start setup, then the domain controller in the foreground.
set -eu
bash /usr/local/sbin/lab-plant
exec samba --interactive --no-process-group --debuglevel=1
