# Meridian Freight: a small, deliberately vulnerable Flask app for the
# sqli-auth-bypass lab. SQLite (stdlib) keeps it light - no external database.
FROM python:3.12-slim

# curl: for the learner (and the reference solution) to drive the login form.
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir flask==3.1.0

COPY app/app.py /opt/portal/app.py

# The learner records their findings here; checks read it. Seeded blank so a
# fresh environment passes nothing.
RUN printf '%s\n' \
  '# Meridian Freight SQLi lab - fill these in AFTER you bypass the login.' \
  '' \
  '# PARAM: which form field did you inject into?  username | password' \
  'PARAM=' \
  '' \
  '# PAYLOAD: the exact value you put in that field' \
  'PAYLOAD=' \
  '' \
  '# TECHNIQUE: how did it bypass the password check?  comment | tautology' \
  'TECHNIQUE=' \
  > /root/answers.txt

RUN echo 'echo "Lab sqli-auth-bypass: the Meridian portal is at http://127.0.0.1:8080 (use curl, POST /login). Tasks: labs/sqli-auth-bypass/README.md. Record findings in /root/answers.txt, then from the host: ./lab check sqli-auth-bypass"' >> /root/.bashrc

WORKDIR /root
CMD ["python", "/opt/portal/app.py"]
