# The collector. Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends rsyslog jq iproute2 procps \
 && rm -rf /var/lib/apt/lists/* \
 && sed -i 's/^module(load="imklog"/#&/' /etc/rsyslog.conf \
 && mkdir -p /var/log/siem \
 && chown syslog:adm /var/log/siem

RUN echo 'echo "Lab syslog-collector: tasks are in labs/syslog-collector/README.md. Check from the host with: ./lab check syslog-collector"' >> /root/.bashrc

WORKDIR /root
# rsyslogd puts itself in the background; restart it after a config change with: pkill rsyslogd; rsyslogd
CMD ["sh", "-c", "rsyslogd; exec sleep infinity"]
