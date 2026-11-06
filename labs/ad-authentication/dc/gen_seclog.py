# Writes DC01's Security event log for 5 November 2026 (deterministic). One event per line:
#   <ISO8601Z> EventID=<id> <Field=Value> ...
# Normal background plus three incidents from 10.203.19.88: a brute force that ends in a lockout,
# a Kerberoasting burst against the MSSQL service, and a Pass-the-Hash network logon.
import random, sys
from datetime import datetime, timedelta, timezone

rnd = random.Random(20261105)
NET = "10.203.19."
ATTACKER = NET + "88"
SPN = "MSSQLSvc/sql.ridgeline.local"
staff = ["jalvarez", "sbrennan", "mreyes", "bnakamura"]
admins = ["jalvarez", "sbrennan"]
workstations = [NET + str(60 + i) for i in range(len(staff))]
rows = []
def add(t, eid, **kw):
    rows.append((t, eid, kw))
def t0(h, m, s=0):
    return datetime(2026, 11, 5, h, m, s, tzinfo=timezone.utc)

# --- Background: a normal working morning -----------------------------------------------------
t = t0(7, 55)
while t < t0(16, 0):
    t += timedelta(seconds=rnd.randint(20, 90))
    r = rnd.random()
    if r < 0.40:   # interactive/RDP logons by staff
        i = rnd.randrange(len(staff))
        add(t, 4624, TargetUser=staff[i], LogonType=rnd.choice([2, 10]),
            IpAddress=workstations[i], AuthPackage="Kerberos")
    elif r < 0.62: # Kerberos TGT at the start of a session
        add(t, 4768, TargetUser=rnd.choice(staff), IpAddress=rnd.choice(workstations), Result="0x0")
    elif r < 0.85: # service tickets for ordinary services
        add(t, 4769, TargetUser=rnd.choice(staff), ServiceName=rnd.choice(
            ["HOST/dc01.ridgeline.local", "LDAP/dc01.ridgeline.local", "cifs/dc01.ridgeline.local"]),
            IpAddress=rnd.choice(workstations), TicketEncryption="0x12")
    elif r < 0.93: # the backup service logs on over the network, normally
        add(t, 4624, TargetUser="svc_backup", LogonType=3, IpAddress=NET + "21", AuthPackage="Kerberos")
    else:          # the odd fat-fingered password
        add(t, 4625, TargetUser=rnd.choice(staff), LogonType=2,
            IpAddress=rnd.choice(workstations), AuthPackage="Kerberos", Status="0xC000006A")

# --- Incident 1: brute force on svc_backup from the attacker, then a lockout -------------------
t = t0(10, 2, 5)
for _ in range(14):
    t += timedelta(seconds=rnd.randint(2, 7))
    add(t, 4625, TargetUser="svc_backup", LogonType=3, IpAddress=ATTACKER,
        AuthPackage="NTLM", Status="0xC000006A")
add(t + timedelta(seconds=3), 4740, TargetUser="svc_backup", CallerComputer="WS-0188", IpAddress=ATTACKER)

# --- Incident 2: Kerberoasting - a burst of TGS requests for the MSSQL SPN with RC4 (0x17) -----
t = t0(10, 26, 0)
for _ in range(37):
    t += timedelta(milliseconds=rnd.randint(300, 1500))
    add(t, 4769, TargetUser="mreyes", ServiceName=SPN, IpAddress=ATTACKER, TicketEncryption="0x17")

# --- Incident 3: Pass-the-Hash - a network logon with NTLM from the attacker -------------------
add(t0(11, 8, 44), 4624, TargetUser="mreyes", LogonType=3, IpAddress=ATTACKER, AuthPackage="NTLM")

rows.sort(key=lambda r: r[0])
with open(sys.argv[1], "w") as f:
    for t, eid, kw in rows:
        fields = " ".join("%s=%s" % (k, v) for k, v in kw.items())
        f.write("%s EventID=%d %s\n" % (t.strftime("%Y-%m-%dT%H:%M:%SZ"), eid, fields))
