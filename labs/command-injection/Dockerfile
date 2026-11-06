# NetCheck: a deliberately vulnerable Flask diagnostics app for the
# command-injection lab. iputils-ping makes the legitimate ping work so recon
# looks real; curl lets the learner (and the solution) drive the endpoint.
FROM python:3.12-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends iputils-ping curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir flask==3.1.0

COPY app/app.py /opt/netcheck/app.py

# /flag is where a successful injected command proves code execution.
RUN mkdir -p /flag

# The learner records their findings here; checks read it. Seeded blank so a
# fresh environment passes nothing.
RUN printf '%s\n' \
  '# Command-injection lab - fill these in after you get command execution.' \
  '' \
  '# OPERATOR: one shell metacharacter that ends/chains a second command' \
  '#   (e.g. ; or && or | )' \
  'OPERATOR=' \
  '' \
  '# IMPACT: command injection gives code execution on the ____ (one word)' \
  'IMPACT=' \
  '' \
  '# FIX: the correct defense (how should the app run the command instead?)' \
  'FIX=' \
  > /root/answers.txt

RUN printf '%s\n' \
  'echo "Lab command-injection: NetCheck is at http://127.0.0.1:8080 (use curl). Endpoint: GET /ping?host=..."' \
  'echo "A successful injection can create/write /flag/solved. Record findings in /root/answers.txt."' \
  'echo "Then from the host: ./lab check command-injection"' \
  >> /root/.bashrc

WORKDIR /root
CMD ["python", "/opt/netcheck/app.py"]
