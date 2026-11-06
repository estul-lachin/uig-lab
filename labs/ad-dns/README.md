# ad-dns

## Concepts

Active Directory doesn't work without DNS. A client that wants to log on doesn't know the name of a
domain controller: it asks DNS where the domain's LDAP and Kerberos services are. If DNS is broken,
logons fail; if DNS lies, clients go wherever the liar wants.

**AD-integrated zones.** On a DC, the DNS zone is usually **Active Directory-integrated**: there is no
zone file; every record is an object in the directory (a `dnsNode` under `CN=MicrosoftDNS`), stored in
an application partition and replicated with AD to every DC that runs DNS. Every DC can accept changes
(multi-master), and records have ACLs like any other object. The domain's zone lives in
**DomainDnsZones** (replicated to the DNS servers of that domain); the forest-wide `_msdcs` zone, with
the records every domain in the forest needs, lives in **ForestDnsZones**. On Windows you browse them in
DNS Manager (`dnsmgmt.msc`).

**Record types.**

| Type | Maps | Example |
|---|---|---|
| A | name to IPv4 address | `rdg-sql01.ridgeline.local` to an address (AAAA is IPv6) |
| CNAME | name to another name (an alias) | a friendly name for a server |
| PTR | address back to a name, in a **reverse zone** | `10.0.0.5` is the name `5.0.0.10.in-addr.arpa` |
| SRV | a service to the host and port that offer it | `priority weight port target` |
| SOA | the zone itself: primary server, serial, timers | one per zone |

**How a client finds a DC.** It looks up SRV records named `_service._protocol.<domain>`:
`_ldap._tcp.<domain>` for LDAP, `_kerberos._tcp.<domain>` for Kerberos, `_gc._tcp.<forest>` for a
Global Catalog, and site-specific variants under `_sites` and `_msdcs`. The DC registers these itself
(Netlogon on Windows). Attackers query the same names to map the DCs.

**Reverse zones** aren't created automatically. Without them `nslookup <address>` fails, and so does
every log enrichment that turns an address back into a host name.

**Tools.** On Windows `nslookup` and the PowerShell cmdlet `Resolve-DnsName` (`-Type SRV` for service
records). On Linux `dig` (`+short` for answers only, `-x` for a reverse lookup) and `nslookup`. DNS
answers on **port 53**, UDP for normal queries, TCP for large answers and zone transfers. On a Samba
DC, `samba-tool dns` lists, adds and deletes zones and records, like DNS Manager.

**Why the SOC cares.**

- **ADIDNS poisoning.** By default any authenticated user may create a *new* name in an AD-integrated
  zone (secure dynamic update, or plain LDAP). Names nobody registered are free for the taking, and the
  classic one is **`wpad`**: browsers and Windows look it up to find a proxy auto-configuration file.
  Whoever owns `wpad` can sit in the middle of web traffic and collect NTLM authentication. The record's
  owner in its security descriptor shows who created it
- **DNS tunneling.** DNS is allowed out almost everywhere, so malware hides data in the names it looks
  up: long random-looking labels, many queries in a short time, all under one domain, often TXT
  records to get data back. The query log shows it at a glance
- **Malicious domains** usually appear first as a DNS query: the log tells you which host asked, and when

**About this lab.** DC01 is a real AD domain controller (Samba 4 with its internal DNS server). The
zone, its records and their owners are real directory objects. Samba keeps no query log by default,
so the morning's log comes from the lab, in the same form a resolver would write it.

## Tasks

Start the lab with `./lab up ad-dns`, open a shell with `./lab shell ad-dns`. You are root on
**DC01**, the domain controller and DNS server of `ridgeline.local`; ask it at `127.0.0.1`. The domain
Administrator's lab password is `Lab-AD-2026!`. The DNS query log of 5 November 2026, 08:00 to 12:00 UTC,
is `/var/log/dns/queries.log` (`time client type name result [answer]`). Write the answers to
`/root/answers.txt`, one `KEY=value` per line (case doesn't matter).

1. **AD-integrated DNS.**

   ```
   DNS_CONSOLE=<the .msc command that opens DNS Manager on Windows>
   ZONE_STORAGE=<how the zone is stored, so that it replicates with the directory>
   NAME_TO_IP=<the record type that maps a host name to an IPv4 address>
   DC_IP=<the address dc01.ridgeline.local resolves to>
   DC_LOCATOR=<the SRV record name clients query to find a DC (LDAP) for the domain>
   RESOLVE_CMDLET=<the PowerShell cmdlet that resolves DNS names>
   DNS_PORT=<the port DNS uses>
   ```

2. **Inside the zone.**

   ```
   ZONE_PARTITION=<the application partition the ridgeline.local zone is stored in>
   MSDCS_PARTITION=<the one that holds _msdcs.ridgeline.local>
   KERBEROS_PORT=<the port in the _kerberos._tcp SRV record>
   INTRANET_TARGET=<the host intranet.ridgeline.local is an alias for>
   ```

3. **The reverse zone.** There is none yet. Create the reverse zone for `10.203.17.0/24` and PTR
   records so that `10.203.17.10` resolves back to `dc01.ridgeline.local` and `10.203.17.21` to
   `rdg-fs01.ridgeline.local`.

4. **The planted record.** One name in the zone belongs to no server.

   ```
   ROGUE_NAME=<the record>
   ROGUE_IP=<where it points>
   ROGUE_OWNER=<the account that created it>
   WPAD_FIRST=<when a client first received that answer, HH:MM:SS, from the log>
   WPAD_CLIENTS=<how many different clients received it>
   ```

   Then delete the record, and nothing else.

5. **DNS tunneling.** One workstation is moving data out through DNS.

   ```
   TUNNEL_CLIENT=<its address>
   TUNNEL_HOST=<its name in the zone>
   TUNNEL_DOMAIN=<the domain it sends the data to>
   TUNNEL_QTYPE=<the record type it queries>
   ```

Check your work from the host: `./lab check ad-dns`

<details>
<summary>Hints</summary>

- `dig @127.0.0.1 <name>`, `dig @127.0.0.1 SRV <name>`, `dig @127.0.0.1 -x <address>`; `+short` trims the output
- `samba-tool dns query 127.0.0.1 ridgeline.local @ ALL -U Administrator` lists every record in the zone
- DNS objects sit in application partitions, which `ldbsearch -H /var/lib/samba/private/sam.ldb` only
  searches with `--cross-ncs`
- `samba-tool dns zonecreate` and `samba-tool dns add ... PTR`: the record name in a reverse zone is the
  last octet
- `samba-tool dsacl get --objectdn=<the record's DN> -H /var/lib/samba/private/sam.ldb`: `O:` is the
  owner; search for the user whose `objectSid` it is
- `samba-tool dns delete` wants the record's type and data, like `add`
- `awk '{print $3}' /var/log/dns/queries.log | sort | uniq -c` gives a first picture; then look at the
  longest names

</details>

## My notes

<!-- Screenshots: ./lab shot ad-dns ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [ad-core-concepts](../ad-core-concepts/): the domain, the Global Catalog and its SRV record
- [dns-resolution](../dns-resolution/): how a Linux client resolves names
- [splunk-beacon-hunt](../splunk-beacon-hunt/): another C2 channel, found in proxy logs
- MITRE ATT&CK T1557.001 (LLMNR/NBT-NS Poisoning and SMB Relay, the WPAD family), T1071.004 (Application Layer Protocol: DNS), T1048 (Exfiltration Over Alternative Protocol)
