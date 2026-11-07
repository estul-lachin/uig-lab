# Quillpad: a Flask notes API with a broken JWT verifier, for the jwt-auth-bypass
# lab. The token handling is hand-rolled (stdlib only) so the alg:none flaw is
# explicit; curl lets the learner drive the API.
FROM python:3.12-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir flask==3.1.0

COPY app/app.py /opt/quillpad/app.py

RUN mkdir -p /flag

RUN printf '%s\n' \
  '# JWT auth-bypass lab - fill these in after you forge an admin token.' \
  '' \
  '# VULN_ALG: the alg header value that makes the server skip signature checks' \
  'VULN_ALG=' \
  '' \
  '# FORGED_CLAIM: which payload claim did you change to become admin?' \
  'FORGED_CLAIM=' \
  '' \
  '# FIX: the correct defense (what should the server do about the alg header?)' \
  'FIX=' \
  > /root/answers.txt

RUN printf '%s\n' \
  'echo "Lab jwt-auth-bypass: Quillpad is at http://127.0.0.1:8080 (use curl). POST /login -> JWT; GET /admin needs role=admin."' \
  'echo "Decode a JWT part with: echo <part> | base64 -d   Record findings in /root/answers.txt."' \
  'echo "Then from the host: ./lab check jwt-auth-bypass"' \
  >> /root/.bashrc

WORKDIR /root
CMD ["python", "/opt/quillpad/app.py"]
