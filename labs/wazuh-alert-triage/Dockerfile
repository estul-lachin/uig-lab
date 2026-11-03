# The analyst workstation. Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl jq ca-certificates \
 && rm -rf /var/lib/apt/lists/*
RUN echo 'echo "Lab wazuh-alert-triage: Wazuh is at https://localhost:8443 on your Mac (admin / Lab-Wazuh-2026). The feed is done when /feed/done exists. Answers go in /root/answers.txt."' >> /root/.bashrc
WORKDIR /root
CMD ["sleep", "infinity"]
