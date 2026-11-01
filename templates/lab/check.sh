# Checks for __NAME__. No shebang: ./lab check prepends lib/check-lib.sh and runs this inside
# the container, then calls summary. Available: section, check, as_user.
#
# Negative checks ("X should NOT be possible") must confirm their precondition first,
# e.g. '[ -f /data/file ] && ! as_user bob "echo x >> /data/file"'.

# Placeholder check so a fresh lab passes ./lab test - replace it.
section "Tasks"
check "/root/__NAME__.done exists" '[ -f /root/__NAME__.done ]' "Create the file with touch"
