# gcp-vpc-subnets

## Concepts

A **Virtual Private Cloud (VPC)** is your own private network inside a public cloud: the machines,
containers and managed services you run in Google Cloud get their internal IP addresses from it, and
nothing outside reaches them unless you open a path. Every other network control (firewall rules,
routes, VPN or Interconnect to the office, peering) is attached to a VPC, so it is the first thing a
cloud environment needs and the first thing a security review looks at.

**Global network, regional subnets.** In Google Cloud a VPC network is a **global** resource with no
IP range of its own. The addresses live in its **subnets**, and each subnet belongs to exactly one
**region** (`us-central1`, `europe-west1` ...). One network can therefore span the world, with one
subnet per region where you actually run things.

| | Scope | Rule |
|---|---|---|
| Network | Global (project) | Name unique in the project; a project has a quota of networks (5 by default) |
| Subnet | One region | Name unique per region; range unique and non-overlapping inside its network |

**Auto mode or custom mode.** A network is created in one of two subnet modes:

- **auto**: Google creates one subnet in every region for you, always from the same fixed block
  (`10.128.0.0/9`, one `/20` per region). It is the default when you don't say otherwise, and it is
  what the `default` network of a new project uses
- **custom**: no subnets at all until you create them, with the regions and ranges *you* chose

Auto mode is convenient for a test and a problem for a company: every auto mode network uses the
same ranges, so two of them (or one of them and an office network that happens to use `10.128.x.x`)
can never be connected by VPN or peering without address conflicts. It also puts a subnet in regions
nobody asked for. Production networks are custom mode, built from an address plan.

**Ranges.** A subnet's primary range is an IPv4 CIDR block such as `10.40.1.0/24`. It must start at
a network boundary (host bits zero), and Google keeps four addresses in each range: the network
address, the default gateway (the first usable address, `.1`), the second-to-last address and the
broadcast address. A `/24` therefore gives 252 usable addresses.

**Two subnet settings the security team cares about:**

- **Private Google Access**: lets machines *without* an external IP reach Google APIs and services
  (Cloud Storage, BigQuery ...). It is what allows sensitive workloads to stay off the internet
  entirely instead of getting a public address just to reach a storage bucket
- **VPC Flow Logs**: records a sample of the network flows to and from the machines in a subnet
  (source, destination, ports, bytes) into Cloud Logging. Off by default; without it, an incident
  responder has no network record to look at

**gcloud.** The command line tool is built as nested groups, read left to right:

```
gcloud compute networks create NAME --subnet-mode=MODE
gcloud compute networks subnets create NAME --network=NET --region=REGION --range=CIDR
gcloud compute networks list
gcloud compute networks subnets list --network=NET
gcloud compute networks describe NAME
```

`gcloud` is the tool, `compute` the product (Compute Engine), `networks` and `networks subnets` the
resources, and the last word is the action (`create`, `list`, `describe`, `update`, `delete`).
Every command has `--help`. Any list or describe output can be narrowed with `--filter` and
reshaped with `--format`: `json` and `yaml` show every field, `value(field1,field2)` prints bare
values that scripts can use, and `.basename()` turns a long resource URL into its last part:

```
gcloud compute networks list --format="value(name)"
gcloud compute networks subnets list --filter="region:us-east1" --format="value(name,ipCidrRange)"
gcloud compute networks subnets describe NAME --region=REGION --format="value(network.basename())"
```

**About this lab.** A real Google Cloud project needs an account and a billing account, so the lab
runs a Cloud Shell look-alike with a **stand-in `gcloud`** over a seeded project. It knows the
commands above (plus `config`, `auth list` and `compute regions list`), with the same names, flags,
default columns, error messages and rules: unique names, no overlapping ranges in one network, auto
mode subnets in each region, the network quota. It knows twelve regions, not all of them. The same
commands work in a real Cloud Shell.

## Tasks

Start the lab with `./lab up gcp-vpc-subnets`, open a shell with `./lab shell gcp-vpc-subnets`.

You are a cloud security analyst at Larchmere Credit Union. The bank is connecting its data centre
to Google Cloud, and before the real network goes live you are building a copy of it in a sandbox
project to test its security settings. The network team's address plan:

| Subnet | Region | Range | Notes |
|---|---|---|---|
| `ledger-app` | `us-central1` | `10.40.1.0/24` | Application servers |
| `ledger-db` | `europe-west1` | `10.40.2.0/24` | Databases; no external IPs, but they back up to Cloud Storage |

1. **Create the network.** Create a VPC network named `ledger-net` that contains only the subnets
   you create yourself.

2. **Create the subnets.** Add the two subnets from the plan to `ledger-net`, each in its region
   with its range. Give `ledger-db` what it needs to reach Cloud Storage without an external IP.
   `ledger-net` should end up with these two subnets and nothing else.

3. **Inventory.** Before touching anything else, find out what the sandbox already contains. Write
   the answers to `/root/answers.txt`, one `KEY=value` per line:

   ```
   PROJECT=<the project ID this Cloud Shell works in>
   DEFAULT_MODE=<the subnet mode of the default network>
   DEFAULT_SUBNETS=<how many subnets the default network has>
   TEMP_NET_CREATED=<the day the network temp-net was created, YYYY-MM-DD>
   SHARED_RANGE=<the subnet range that default and temp-net both use in europe-west1>
   ```

4. **Clean up and turn on visibility.** `temp-net` is a forgotten test network nobody owns, and its
   ranges collide with `default`. Delete it (and only it). Then turn on VPC Flow Logs for both
   `ledger-app` and `ledger-db`, so that the security tests you run next leave a network record.

Check your work from the host: `./lab check gcp-vpc-subnets`

<details>
<summary>Hints</summary>

- `gcloud compute networks create --help` lists the subnet modes; the default is not the one you want
- A subnet needs three things besides its name: the network, the region and the range
- A subnet you created with the wrong range can't be changed: delete it and create it again
- `gcloud config list` and `gcloud auth list` describe the Cloud Shell session itself
- `wc -l` counts lines; `--format="value(name)"` leaves out the header
- Both `--regions` on `subnets list` and `--filter` narrow a list to one region
- `subnets update` changes settings of an existing subnet; `describe` shows `logConfig` before and after
- The default network is in use by every new project: read the delete prompt before you answer it

</details>

## My notes

<!-- Screenshots: ./lab shot gcp-vpc-subnets ~/Screenshots/<file>.png <name>, then link it as
     ![what it shows](screenshots/<name>.png). Prefer code blocks for terminal output. -->

## Related

- [ip-interfaces](../ip-interfaces/): addresses, prefixes and interfaces on a single host
- [routing-gateway](../routing-gateway/): what the subnet's default gateway does
- [firewall-rules-nat-zones](../firewall-rules-nat-zones/): the next step in a VPC is its firewall rules
- [ssrf-cloud-metadata](../ssrf-cloud-metadata/): why cloud workloads should stay off the internet
- MITRE ATT&CK T1580 (Cloud Infrastructure Discovery), T1562.008 (Impair Defenses: Disable or Modify Cloud Logs)
