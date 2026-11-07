# LinkPeek - a link-preview tool with a Server-Side Request Forgery (SSRF) bug.
#
# The /fetch endpoint takes a URL and fetches it SERVER-SIDE, with no allow-list.
# So a client can make the server request internal addresses it could never reach
# directly - including the cloud instance metadata service at 169.254.169.254,
# which hands out the instance's IAM credentials.
#
# The fix is to validate the target at the boundary: an allow-list of hosts, and
# blocking requests to internal / link-local / metadata addresses (and, on AWS,
# requiring IMDSv2).

import os
import urllib.parse
import urllib.request
from flask import Flask, request, Response

app = Flask(__name__)
METADATA_IP = "169.254.169.254"


@app.get("/")
def index():
    return Response(
        "LinkPeek - preview any link.\n"
        "  GET /fetch?url=<url>   the server fetches <url> and returns its body\n",
        mimetype="text/plain",
    )


@app.get("/fetch")
def fetch():
    url = request.args.get("url", "")
    if not url:
        return Response("Provide ?url=<url>\n", status=400, mimetype="text/plain")

    # VULNERABLE: no allow-list - the server will fetch ANY url the client gives.
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "LinkPeek/1.0"})
        with urllib.request.urlopen(req, timeout=5) as r:
            body = r.read().decode(errors="replace")
    except Exception as e:
        return Response(f"fetch error: {e}\n", status=502, mimetype="text/plain")

    # If the forged request reached the metadata service's IAM credentials, the
    # attacker has exfiltrated cloud keys through the server - record the breach.
    host = urllib.parse.urlparse(url).hostname or ""
    if host == METADATA_IP and "AccessKeyId" in body:
        os.makedirs("/flag", exist_ok=True)
        with open("/flag/solved", "w") as f:
            f.write("flag{linkpeek-ssrf-imds-credential-theft}\n")
            f.write("stolen-via: " + url + "\n")
            f.write(body if body.endswith("\n") else body + "\n")

    return Response(body, mimetype="text/plain")


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8080)
