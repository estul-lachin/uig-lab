# Postboard: a small, deliberately vulnerable web app for the reflected-xss lab.
# Node + jsdom give a real HTML parser and JS engine (the "moderator" bot), so
# attribute-context break-out and <script> execution behave exactly as in a browser
# - without shipping a full headless Chromium.
FROM node:22.12.0-bookworm-slim

# curl: for the learner (and the reference solution) to drive the app from a shell.
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/postboard
COPY app/package.json ./
RUN npm install --omit=dev --no-audit --no-fund \
 && npm cache clean --force
COPY app/server.js ./

# The learner records their findings here; checks read it. Seeded blank so a
# fresh environment passes nothing.
RUN printf '%s\n' \
  '# Postboard reflected-XSS lab - fill these in AFTER you land the exploit.' \
  '' \
  '# CONTEXT: where does ?q= get reflected? one of:  text | attribute | script' \
  'CONTEXT=' \
  '' \
  '# BREAKOUT: the exact characters you injected to escape that context (e.g.  ">)' \
  'BREAKOUT=' \
  '' \
  '# PAYLOAD: the full q value you submitted' \
  'PAYLOAD=' \
  > /root/answers.txt

RUN echo 'echo "Lab reflected-xss: the Postboard app is at http://127.0.0.1:8080 (use curl). Tasks: labs/reflected-xss/README.md. Record findings in /root/answers.txt, then from the host: ./lab check reflected-xss"' >> /root/.bashrc

WORKDIR /root
CMD ["node", "/opt/postboard/server.js"]
