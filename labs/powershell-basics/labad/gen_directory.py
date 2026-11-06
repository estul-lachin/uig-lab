# Generates directory.json, the seeded RIDGELINE domain that LabAD reads: python3 gen_directory.py directory.json
import json, uuid, sys
BASE = "DC=ridgeline,DC=local"
DOM = "S-1-5-21-3284117560-1902265547-2741039183"
NS = uuid.UUID("6a1c2f9e-1d7b-4c3e-9a55-0b8e4f2d7c11")
def guid(s): return str(uuid.uuid5(NS, s))
users = []
def u(sam, given, sur, ou, dept, title, enabled, last, created, pwset, pne=False, rid=None, desc=None, name=None):
    name = name or f"{given} {sur}"
    dn = f"CN={name},{ou},{BASE}"
    users.append({
        "SamAccountName": sam, "GivenName": given, "Surname": sur, "Name": name,
        "DisplayName": name if given else None, "DistinguishedName": dn,
        "UserPrincipalName": f"{sam}@ridgeline.local" if given or sam.startswith("svc") else None,
        "Enabled": enabled, "Department": dept, "Title": title, "Description": desc,
        "LastLogonDate": last, "PasswordLastSet": pwset, "PasswordNeverExpires": pne,
        "WhenCreated": created, "ObjectClass": "user", "ObjectGUID": guid(sam),
        "SID": f"{DOM}-{rid}",
    })
STAFF = "OU=Staff,OU=Ridgeline"
u("Administrator", None, None, "CN=Users", None, None, True, "2026-11-05T08:12:40", "2025-03-10T09:02:11", "2026-06-01T10:15:00", rid=500, desc="Built-in account for administering the computer/domain", name="Administrator")
u("Guest", None, None, "CN=Users", None, None, False, None, "2025-03-10T09:02:11", None, pne=True, rid=501, desc="Built-in account for guest access to the computer/domain", name="Guest")
u("krbtgt", None, None, "CN=Users", None, None, False, None, "2025-03-10T09:18:43", "2025-03-10T09:18:43", rid=502, desc="Key Distribution Center Service Account", name="krbtgt")
r = 1104
rows = [
 ("mreyes","Maya","Reyes","Finance","Accounts Payable Lead",True,"2026-11-04T16:41:09","2025-04-02T10:00:00","2026-09-12T08:30:00",False),
 ("dokafor","Daniel","Okafor","Finance","Financial Analyst",True,"2026-11-05T07:58:22","2025-06-16T10:00:00","2026-08-21T09:12:00",False),
 ("lchen","Lin","Chen","Finance","Controller",True,"2026-11-03T13:20:47","2025-04-02T10:05:00","2026-10-01T11:44:00",False),
 ("pnair","Priya","Nair","Finance","Payroll Specialist",True,"2026-11-04T09:03:15","2025-09-08T10:00:00","2026-07-30T15:02:00",False),
 ("jalvarez","Jorge","Alvarez","IT","IT Manager",True,"2026-11-05T08:40:31","2025-03-11T08:00:00","2026-10-14T07:55:00",False),
 ("sbrennan","Shawn","Brennan","IT","Systems Administrator",True,"2026-11-05T08:05:12","2025-03-12T08:00:00","2026-09-02T12:20:00",False),
 ("aokoye","Ada","Okoye","IT","Help Desk Technician",True,"2026-11-04T17:22:56","2026-01-19T09:00:00","2026-10-20T08:10:00",False),
 ("rkowalski","Rita","Kowalski","Sales","Sales Manager",True,"2026-11-04T15:11:38","2025-05-05T09:00:00","2026-08-05T10:33:00",False),
 ("bnakamura","Ben","Nakamura","Sales","Account Executive",True,"2026-11-05T06:47:03","2025-07-14T09:00:00","2026-10-29T22:16:00",False),
 ("tgrant","Tomas","Grant","Sales","Sales Associate",True,"2026-05-14T17:30:02","2025-10-06T09:00:00","2026-03-02T09:41:00",False),
 ("hdiallo","Hawa","Diallo","Warehouse","Shift Supervisor",True,"2026-11-04T05:59:44","2025-04-21T06:00:00","2025-04-21T06:10:00",True),
 ("kfischer","Karl","Fischer","Warehouse","Forklift Operator",True,"2026-11-03T06:02:18","2025-11-03T06:00:00","2026-08-11T06:05:00",False),
 ("evoss","Elena","Voss","Warehouse","Seasonal Associate",False,"2026-08-29T14:05:51","2026-06-01T06:00:00","2026-06-01T06:20:00",False),
]
for sam,g,s,d,t,en,last,cr,pw,pne in rows:
    u(sam,g,s,f"OU={d},{STAFF}",d,t,en,last,cr,pw,pne=pne,rid=r); r += 1
for sam, desc in [("svc-backup","Runs the nightly file server backup"),("svc-sql","SQL Server service for the inventory database")]:
    u(sam, None, None, "OU=Service Accounts,OU=Ridgeline", None, None, True, "2026-11-05T02:00:07", "2025-04-09T11:00:00", "2025-04-09T11:05:00", pne=True, rid=r, desc=desc, name=sam); r += 1
groups = []
def g(name, ou, members, rid, desc):
    groups.append({"Name": name, "SamAccountName": name, "DistinguishedName": f"CN={name},{ou},{BASE}",
        "GroupScope": "Global", "GroupCategory": "Security", "ObjectClass": "group",
        "ObjectGUID": guid("g:"+name), "SID": (f"S-1-5-32-{rid}" if ou == "CN=Builtin" else f"{DOM}-{rid}"), "Description": desc, "Members": members})
g("Domain Admins","CN=Users",["Administrator","Tier0-Admins"],512,"Designated administrators of the domain")
g("Domain Users","CN=Users",[x["SamAccountName"] for x in users if x["SamAccountName"] not in ("Guest","krbtgt")],513,"All domain users")
g("Tier0-Admins","OU=Groups,OU=Ridgeline",["jalvarez","IT-Escalation"],r,"Tier 0 administration"); r += 1
g("IT-Escalation","OU=Groups,OU=Ridgeline",["sbrennan","bnakamura"],r,"Temporary escalation for change windows"); r += 1
g("Finance-Share","OU=Groups,OU=Ridgeline",["mreyes","dokafor","lchen","pnair"],r,"Read/write on the finance share"); r += 1
g("Backup Operators","CN=Builtin",["svc-backup"],551,"Backup Operators can override security restrictions for the sole purpose of backing up or restoring files")
json.dump({"Domain": {"DistinguishedName": BASE, "NetBIOSName": "RIDGELINE", "DNSRoot": "ridgeline.local"},
           "Users": users, "Groups": groups}, open(sys.argv[1], "w"), indent=1)
