# A mock AWS Instance Metadata Service (IMDS), bound to the real link-local
# address 169.254.169.254:80. It only exists inside the container and is reachable
# over loopback - exactly the "internal only" service SSRF is used to reach. The
# credentials are random each run and entirely fake.

import json
import secrets
from flask import Flask, Response

app = Flask(__name__)

ROLE = "webapp-ec2-role"
CREDS = {
    "Code": "Success",
    "Type": "AWS-HMAC",
    "AccessKeyId": "AKIA" + secrets.token_hex(8).upper()[:16],
    "SecretAccessKey": secrets.token_hex(20),
    "Token": secrets.token_hex(24),
}


@app.get("/latest/meta-data/iam/security-credentials/")
def roles():
    return Response(ROLE + "\n", mimetype="text/plain")


@app.get("/latest/meta-data/iam/security-credentials/<role>")
def creds(role):
    return Response(json.dumps(CREDS, indent=2) + "\n", mimetype="text/plain")


if __name__ == "__main__":
    app.run(host="169.254.169.254", port=80)
