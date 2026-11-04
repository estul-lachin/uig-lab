# The analyst workstation, which also runs the lab WAF's webhook receiver.
# Always a pinned tag (never latest); prefer images with arm64 builds.
FROM ubuntu:24.04
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates jq python3 \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /opt/lab /var/log/waf
COPY config/waf.py /opt/lab/waf.py
RUN echo 'echo "Lab splunk-alerts: Splunk Web is at http://localhost:8000 on your Mac (admin / Lab-Splunk-2026). The WAF webhook is http://waf:8088/ban; what it received is in /var/log/waf/requests.jsonl. Answers go in /root/answers.txt."' >> /root/.bashrc
WORKDIR /root
CMD ["python3", "-I", "/opt/lab/waf.py"]
