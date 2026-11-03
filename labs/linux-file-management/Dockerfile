# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

# The analyst's case folder the tasks work on.
RUN mkdir -p /root/casefiles/old-drafts /root/casefiles/evidence /root/casefiles/backup \
             /root/casefiles/2026/q2/desk /root/casefiles/2026/q3/field/nightowl \
 && touch /root/casefiles/old-drafts/draft-1.txt /root/casefiles/old-drafts/draft-2.txt /root/casefiles/old-drafts/draft-3.txt \
 && echo "src=10.0.4.17 dst=203.0.113.50 port=443" > /root/casefiles/evidence/firewall.log \
 && echo "user=pia login=02:13 tty=pts/3" > /root/casefiles/evidence/auth.log \
 && echo "sha256 9f2c... dropper.bin" > /root/casefiles/evidence/hashes.txt \
 && printf '09:14 first alert\n09:40 host isolated\n' > /root/casefiles/notes.txt \
 && echo "nightowl is the name of the old phishing campaign, not this one" > /root/casefiles/2026/q2/desk/memo.txt \
 && printf 'callback every 60s: beacon to 203.0.113.50\nsecond beacon seen at 09:31\n' > /root/casefiles/2026/q3/field/nightowl/proxy.txt \
 && echo "the implant sends a beacon over https" > /root/casefiles/2026/q3/field/nightowl/report.txt \
 && echo "BEACON INTERVAL UNKNOWN" > /root/casefiles/2026/q3/field/nightowl/todo.txt \
 && echo "no network activity found" > /root/casefiles/2026/q3/field/nightowl/disk.txt

# Cron entries for task 7: two harmless, one that runs at every boot.
RUN mkdir -p /etc/cron.d \
 && echo '15 3 * * * root /usr/sbin/logrotate /etc/logrotate.conf' > /etc/cron.d/logrotate-extra \
 && echo '0 * * * * root find /tmp -mtime +3 -delete' > /etc/cron.d/tmp-clean \
 && echo '@reboot root /usr/local/bin/sync-agent --quiet' > /etc/cron.d/sync-agent \
 && chmod 644 /etc/cron.d/*

RUN echo 'echo "Lab linux-file-management: tasks are in labs/linux-file-management/README.md. Check from the host with: ./lab check linux-file-management"' >> /root/.bashrc

WORKDIR /root
CMD ["sleep", "infinity"]
