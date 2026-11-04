# The analyst workstation. Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates jq \
 && rm -rf /var/lib/apt/lists/*
RUN echo 'echo "Lab splunk-ai-soc-investigation: Splunk Web is at http://localhost:8000 on your Mac (admin / Lab-Splunk-2026). The case notes are in /root/case; answers go in /root/case/answers.txt."' >> /root/.bashrc
COPY case/ /root/case/
WORKDIR /root/case
CMD ["sleep", "infinity"]
