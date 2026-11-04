# revil-case-study

## Concepts

**REvil** (Ransomware Evil, also called **Sodinokibi**) was a ransomware-as-a-service operation from
2019, run by a Russian-speaking group. The core team maintained the ransomware, and affiliates broke
in and deployed it for a share. In 2021 it was behind about a quarter of reported ransomware attacks:
- **JBS**, the meat processor, paid about US$11 million.
- The **Kaseya** supply-chain attack hit about 1,500 downstream businesses through one IT management
  product.

**Double extortion**: it stole data before encrypting it, then threatened to publish it on a leak site.
So backups alone didn't take away the pressure to pay.

**How affiliates got in**:
- **RDP** exposed to the internet and brute-forced: one of the most common routes.
- Phishing.
- Malvertising and exploit kits.

**On the host**, it:
- Fingerprinted the system and quit on Russian and nearby keyboard layouts.
- Ran **Base64-encoded PowerShell** to delete shadow copies (T1490, *Inhibit System Recovery*).
- Disabled Defender features and stopped services (T1489).
- Encrypted files (T1486, *Data Encrypted for Impact*), **skipping executables and system files** so
  that Windows still boots and the victim can read the note and pay.

**Encryption**: **Curve25519**, an elliptic curve, is used for key agreement. The derived key drives
**Salsa20**, a fast stream cipher, which does the actual file encryption. Without the attacker's
private key the files can't be recovered from themselves.

Every infection gets a **random extension** of 5 to 10 characters, and the note is named after it:
`<ext>-readme.txt`. Researchers found that REvil writes its keys and that extension to the
registry under `recfg` (`pk_key`, `sk_key`, `0_key`, `rnd_ext`), which is useful when confirming what
hit a machine.

**After an attack, in order**:
1. **Contain.** Cut the attacker off (here: the RDP exposure).
2. **Preserve evidence.** Move encrypted files and notes aside, don't delete them. They may be needed
   for a decryptor, for insurance, or for law enforcement.
3. **Restore from a known-good backup**, and **verify** it against a manifest of hashes rather than
   trusting the copy.
4. **Account for the gap.** Anything changed after the last backup is lost. That gap is the
   *recovery point objective* (RPO) in practice.

**PowerShell `-e`** takes Base64 of **UTF-16LE** text, so decoding it takes two steps:
`base64 -d | iconv -f UTF-16LE -t UTF-8`.

## Tasks

Start the lab with `./lab up revil-case-study`, open a shell with `./lab shell revil-case-study`. You
are root on **BWD-FS01**, the file server of Brightwater Dental (fictional), on the morning of 2 June
2026. Last night something hit the share. You have:

| Path | What |
|---|---|
| `/srv/share` | The share, as it is now |
| `/srv/backup/nightly-2026-06-01` | Last night's backup, from 02:00, with `SHA256SUMS` |
| `/root/case/security.jsonl` | Logons and process starts on this server |
| `/root/case/recfg.reg` | A registry export taken during the investigation |
| `/root/case/fs-audit.log` | The share's audit log |

The "encrypted" files in this lab are only random bytes, but treat them as if they were real. Write
`KEY=value` answers to `/root/case/answers.txt`.

1. **REvil in brief.** `INITIAL_ACCESS=<the remote service>`, `TACTIC=<steal + encrypt + threaten>`,
   `ASYMMETRIC=` and `SYMMETRIC=<its two algorithms>`, `TECHNIQUE=<the ATT&CK ID for Data Encrypted for
   Impact>`.
2. **Triage**, before you move anything:

   ```
   EXTENSION=<what it appended>
   RANSOM_NOTE=<the note's file name>
   ENCRYPTED_FILES=<how many files it encrypted>
   SKIPPED_EXTENSIONS=<the file types it left alone, comma-separated>
   ATTACKER_IP=<where the successful RDP logon came from>
   ACCOUNT=<the account it got in with>
   SHADOW_TECHNIQUE=<the ATT&CK ID for what the encoded PowerShell command did>
   ```

3. **Recovery.**
   - Move every encrypted file and every ransom note out of the share into `/root/evidence`, keeping
     their folders (`/root/evidence/billing/...`).
   - Restore the share from the backup.
   - Prove with the manifest that every backed-up file is back, byte for byte.
   - Leave the backup itself unchanged.
   - Then write `LOST_CHANGES=<the file, as a path inside the share, whose latest changes no backup has>`.

Check your work from the host: `./lab check revil-case-study`

<details>
<summary>Hints</summary>

- `find /srv/share -type f | sed 's/.*\.//' | sort | uniq -c`
- `"rnd_ext"` in `recfg.reg`; the file has Windows line endings
- Two addresses brute-forced RDP; only one has a 4624 afterwards
- `jq -r 'select(.EventID == 4688) | .CommandLine'`, then decode the part after `-e`
- `rsync -a --remove-source-files` moves files and keeps paths; `--files-from=-` reads the list from stdin
- `cd /srv/share && sha256sum -c /srv/backup/nightly-2026-06-01/SHA256SUMS`
- In fs-audit.log, which write happened after 02:00 and before the attack?

</details>

## My notes

<!-- Screenshots: ./lab shot revil-case-study ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [backups-rsync-cron](../backups-rsync-cron/): the backups that make this possible
- [ransomware-drill](../ransomware-drill/): another recovery drill
- [lockbit-case-study](../lockbit-case-study/), [conti-case-study](../conti-case-study/),
  [blackcat-case-study](../blackcat-case-study/), [wannacry-case-study](../wannacry-case-study/): the
  other case studies
- MITRE ATT&CK S0496 (REvil), T1486, T1490
