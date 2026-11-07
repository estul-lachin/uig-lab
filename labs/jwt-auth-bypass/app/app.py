# Quillpad - a notes API with a deliberately broken JWT verifier, for the
# jwt-auth-bypass lab.
#
# A JWT is header.payload.signature (three Base64url parts). The signature is
# supposed to prove the server issued the token. This verifier is vulnerable: it
# reads the algorithm from the token's own header and, if that says "none", skips
# signature verification entirely - so an attacker can forge any claims they like.
#
# The safe version pins the expected algorithm server-side (never trusts the
# header's alg) and rejects "none".

import base64
import hashlib
import hmac
import json
import os
import secrets
from flask import Flask, request, Response

# Server HMAC secret for the HS256 tokens it issues. Random each run and never
# exposed - but it doesn't matter for the alg:none bypass, which needs no secret.
SECRET = secrets.token_bytes(32)

app = Flask(__name__)


def b64url_encode(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def b64url_decode(s: str) -> bytes:
    s += "=" * (-len(s) % 4)
    return base64.urlsafe_b64decode(s.encode())


def issue_token(claims: dict) -> str:
    header = {"alg": "HS256", "typ": "JWT"}
    h = b64url_encode(json.dumps(header, separators=(",", ":")).encode())
    p = b64url_encode(json.dumps(claims, separators=(",", ":")).encode())
    sig = hmac.new(SECRET, f"{h}.{p}".encode(), hashlib.sha256).digest()
    return f"{h}.{p}.{b64url_encode(sig)}"


def verify_token(token: str):
    parts = token.split(".")
    if len(parts) != 3:
        return None
    h_b64, p_b64, s_b64 = parts
    try:
        header = json.loads(b64url_decode(h_b64))
        payload = json.loads(b64url_decode(p_b64))
    except Exception:
        return None

    alg = header.get("alg", "")
    # VULNERABLE: the algorithm comes from the attacker-controlled header.
    if alg == "none":
        return payload            # signature verification skipped entirely
    if alg == "HS256":
        expected = hmac.new(SECRET, f"{h_b64}.{p_b64}".encode(), hashlib.sha256).digest()
        if hmac.compare_digest(b64url_encode(expected), s_b64):
            return payload
    return None


def bearer():
    auth = request.headers.get("Authorization", "")
    return auth[7:] if auth.startswith("Bearer ") else ""


@app.get("/")
def index():
    return Response(
        "Quillpad API\n"
        "  POST /login            {username,password} -> a JWT (role=user)\n"
        "  GET  /admin            (Authorization: Bearer <jwt>) -> admin area\n",
        mimetype="text/plain",
    )


@app.post("/login")
def login():
    data = request.get_json(silent=True) or request.form
    username = data.get("username") or "guest"
    token = issue_token({"sub": username, "role": "user"})
    return Response(json.dumps({"token": token}) + "\n", mimetype="application/json")


@app.get("/admin")
def admin():
    token = bearer()
    if not token:
        return Response("Missing bearer token.\n", status=401, mimetype="text/plain")
    payload = verify_token(token)
    if payload is None:
        return Response("Invalid token.\n", status=401, mimetype="text/plain")
    if payload.get("role") != "admin":
        return Response("Forbidden: admin role required.\n", status=403, mimetype="text/plain")

    os.makedirs("/flag", exist_ok=True)
    with open("/flag/solved", "w") as f:
        f.write(
            "flag{quillpad-jwt-alg-none-bypass}\n"
            f"admin-as: {payload.get('sub')}\n"
            "role: admin\n"
        )
    return Response("Welcome, administrator. Flag written.\n", mimetype="text/plain")


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8080)
