# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

# Task 5: a log cleanup script with a dangerous bug.
RUN mkdir -p /root/scripts \
 && printf '%s\n' \
      '#!/bin/bash' \
      '# Delete rotated logs. Called by cron as: LOGDIR=/var/log/app prune-logs.sh' \
      'rm -f "$LOGDIR"/old-*.log' \
      'echo "pruned $LOGDIR"' \
      > /root/scripts/prune-logs.sh \
 && chmod 755 /root/scripts/prune-logs.sh

RUN echo 'echo "Lab bash-traps-signals: tasks are in labs/bash-traps-signals/README.md. Check from the host with: ./lab check bash-traps-signals"' >> /root/.bashrc

WORKDIR /root/scripts
CMD ["sleep", "infinity"]
