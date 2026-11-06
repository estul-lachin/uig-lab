#!/usr/bin/env bash
# DC01 entrypoint: fix the sysvol ACLs (xattr_tdb is keyed by inode, which changes in a new
# container, so this can't be baked into the image), then run the domain controller.
set -eu
umask 022
samba-tool ntacl sysvolreset >/dev/null 2>&1 || true
exec samba --interactive --no-process-group --debuglevel=1
