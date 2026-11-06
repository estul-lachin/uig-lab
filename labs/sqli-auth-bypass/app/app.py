# Meridian Freight staff portal - a deliberately vulnerable demo app for the
# sqli-auth-bypass lab.
#
# The /login endpoint builds its SQL by interpolating the submitted username and
# password straight into the query string (an f-string), instead of using a
# parameterized query. That lets an attacker change the *structure* of the query
# and bypass the password check - classic SQL-injection authentication bypass.
#
# The admin password is random each run and is never seeded anywhere readable,
# so the only way to log in as admin is injection. The flag is written only when
# a login succeeds as admin with a password that does NOT match the real one -
# i.e. a genuine bypass, not a lucky guess.
#
# Nothing here attacks anyone: it is a self-contained lab.

import os
import secrets
import sqlite3
from flask import Flask, request, Response

# Random admin secret, generated at startup. Not written to disk, not exposed by
# any endpoint - unguessable on purpose.
ADMIN_PW = secrets.token_hex(16)

db = sqlite3.connect(":memory:", check_same_thread=False)
db.executescript(
    "CREATE TABLE users("
    "  id INTEGER PRIMARY KEY,"
    "  username TEXT,"
    "  password TEXT,"
    "  is_admin INTEGER"
    ");"
)
# admin is row 1 so a tautology that returns the first row also lands on admin.
db.execute("INSERT INTO users VALUES (1, 'admin', ?, 1)", (ADMIN_PW,))
db.execute("INSERT INTO users VALUES (2, 'rwong', 'autumn-maple-71', 0)")
db.execute("INSERT INTO users VALUES (3, 'jmalik', 'harbor-lantern-48', 0)")
db.commit()

FLAG_FILE = "/flag/solved"

app = Flask(__name__)


def page(body):
    return (
        "<!doctype html><html lang='en'><head><meta charset='utf-8'>"
        "<title>Meridian Freight - Staff Portal</title></head><body>"
        "<header><strong>Meridian Freight</strong> &middot; staff portal "
        "<em>(authorized users only)</em></header>" + body + "</body></html>"
    )


@app.get("/")
def index():
    return Response(page(
        "<h1>Sign in</h1>"
        "<form action='/login' method='post'>"
        "<p>Username: <input type='text' name='username'></p>"
        "<p>Password: <input type='password' name='password'></p>"
        "<button type='submit'>Sign in</button>"
        "</form>"
        "<p>Staff sign in with their corporate credentials.</p>"
    ), mimetype="text/html")


@app.post("/login")
def login():
    u = request.form.get("username", "")
    p = request.form.get("password", "")

    # VULNERABLE: the inputs are interpolated directly into the query. A
    # parameterized query (db.execute(sql, (u, p))) would make this safe.
    query = (
        "SELECT id, username, is_admin, password FROM users "
        f"WHERE username = '{u}' AND password = '{p}'"
    )
    try:
        row = db.execute(query).fetchone()
    except sqlite3.Error as e:
        return Response(page(f"<p>Query error: {e}</p>"), status=400, mimetype="text/html")

    if not row:
        return Response(page("<p>Invalid credentials.</p>"), status=401, mimetype="text/html")

    _id, name, is_admin, real_pw = row
    legit = (p == real_pw)

    # A successful admin login WITHOUT the real password is an injection bypass.
    if is_admin and not legit:
        os.makedirs("/flag", exist_ok=True)
        with open(FLAG_FILE, "w") as f:
            f.write(
                "flag{meridian-sqli-auth-bypass}\n"
                f"bypassed-account: {name}\n"
            )
        return Response(page(
            f"<h1>Welcome, {name}.</h1><p>You are signed in as an administrator.</p>"
        ), mimetype="text/html")

    return Response(page(f"<h1>Welcome, {name}.</h1>"), mimetype="text/html")


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8080, threaded=True)
