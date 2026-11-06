# NetCheck - a deliberately vulnerable network-diagnostics tool for the
# command-injection lab.
#
# The /ping endpoint builds a shell command by string-concatenating the user's
# "host" value and runs it with shell=True. The shell treats metacharacters
# (; && | $() backticks) as syntax, so an attacker can chain their own commands.
#
# The safe version would never build a shell string: subprocess.run with an
# argument LIST and shell=False, e.g. subprocess.run(["ping","-c","1",host]),
# so the input is always a single argument, never shell syntax.

import subprocess
from flask import Flask, request, Response

app = Flask(__name__)


def page(body):
    return (
        "<!doctype html><html lang='en'><head><meta charset='utf-8'>"
        "<title>NetCheck</title></head><body>"
        "<header><strong>NetCheck</strong> &middot; network diagnostics</header>"
        + body + "</body></html>"
    )


@app.get("/")
def index():
    return Response(page(
        "<h1>Ping a host</h1>"
        "<form action='/ping' method='get'>"
        "<input type='text' name='host' placeholder='127.0.0.1'>"
        "<button type='submit'>Ping</button>"
        "</form>"
        "<p>Checks whether a host is reachable from this server.</p>"
    ), mimetype="text/html")


@app.get("/ping")
def ping():
    host = request.args.get("host", "")
    if not host:
        return Response("Provide a host, e.g. /ping?host=127.0.0.1", status=400, mimetype="text/plain")

    # VULNERABLE: the host value is concatenated straight into a shell command.
    cmd = "ping -c 1 " + host
    try:
        proc = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
        output = proc.stdout + proc.stderr
    except subprocess.TimeoutExpired:
        output = "timed out"

    return Response("$ " + cmd + "\n\n" + output, mimetype="text/plain")


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8080)
