"""The lab WAF: a webhook receiver that logs every POST it gets, one JSON object per line.

Listens on 0.0.0.0:8088. Each line of /var/log/waf/requests.jsonl holds the time, the path and the
body (parsed as JSON when it is JSON). It bans nothing: it only shows what an alert sent.
"""
import json
import os
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

LOG = "/var/log/waf/requests.jsonl"


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        size = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(size).decode("utf-8", "replace")
        try:
            body = json.loads(raw)
        except ValueError:
            body = raw
        line = {"time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "path": self.path, "body": body}
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(json.dumps(line) + "\n")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"status": "queued"}\n')

    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"lab WAF: POST alerts here\n")

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    open(LOG, "a").close()
    ThreadingHTTPServer(("0.0.0.0", 8088), Handler).serve_forever()
