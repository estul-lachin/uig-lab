# LinkPeek: a Flask link-preview app with an SSRF bug, plus a mock AWS metadata
# service bound to 169.254.169.254. iproute2 adds the link-local address; curl
# is used by the startup wait and by the learner.
FROM python:3.12-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends iproute2 curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir flask==3.1.0

COPY app/app.py app/imds.py app/start.sh /opt/linkpeek/
RUN chmod +x /opt/linkpeek/start.sh && mkdir -p /flag

RUN printf '%s\n' \
  '# SSRF cloud-metadata lab - fill these in after you steal the credentials.' \
  '' \
  '# METADATA_IP: the IP address of the cloud instance metadata service (IMDS)' \
  'METADATA_IP=' \
  '' \
  '# STOLEN: what kind of secret did you exfiltrate from it? (a short phrase)' \
  'STOLEN=' \
  '' \
  '# DEFENSE: name one correct defense against SSRF' \
  'DEFENSE=' \
  > /root/answers.txt

RUN printf '%s\n' \
  'echo "Lab ssrf-cloud-metadata: LinkPeek is at http://127.0.0.1:8080 (use curl). Endpoint: GET /fetch?url=..."' \
  'echo "A cloud metadata service is mocked at http://169.254.169.254/ (reachable only from inside)."' \
  'echo "Record findings in /root/answers.txt, then from the host: ./lab check ssrf-cloud-metadata"' \
  >> /root/.bashrc

WORKDIR /root
CMD ["/opt/linkpeek/start.sh"]
