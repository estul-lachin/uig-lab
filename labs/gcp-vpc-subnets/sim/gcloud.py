#!/usr/bin/env python3
"""A small stand-in for the gcloud CLI, enough for VPC networks and subnets.

It keeps a fake Google Cloud project in a JSON file and follows the real rules this lab is about:
unique network names, unique subnet names per region, no overlapping ranges inside one VPC, auto mode
networks that get one subnet in every region, a network quota, and the same command names, flags and
default output columns as gcloud. It never talks to the network.
"""
import fcntl
import ipaddress
import json
import os
import re
import sys
from datetime import datetime, timezone

STATE = os.environ.get("GCLOUD_SIM_STATE", "/var/lib/gcloud-sim/state.json")
API = "https://www.googleapis.com/compute/v1"
NAME_RE = re.compile(r"^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$")
NETWORK_QUOTA = 5

# The regions this stand-in knows, with the range an auto mode network gets in each (the real values).
REGIONS = {
    "us-central1": "10.128.0.0/20",
    "europe-west1": "10.132.0.0/20",
    "us-west1": "10.138.0.0/20",
    "asia-east1": "10.140.0.0/20",
    "us-east1": "10.142.0.0/20",
    "asia-northeast1": "10.146.0.0/20",
    "asia-southeast1": "10.148.0.0/20",
    "us-east4": "10.150.0.0/20",
    "australia-southeast1": "10.152.0.0/20",
    "europe-west2": "10.154.0.0/20",
    "europe-west3": "10.156.0.0/20",
    "northamerica-northeast1": "10.162.0.0/20",
}
ALLOWED = [ipaddress.ip_network(n) for n in ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "100.64.0.0/10")]

COMMAND = "gcloud"


class GcloudError(Exception):
    pass


def fail(msg):
    raise GcloudError(f"ERROR: ({COMMAND}) {msg}")


# ---------------------------------------------------------------- state

def load():
    with open(STATE) as f:
        return json.load(f)


def save(state):
    tmp = STATE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f, indent=2)
    os.replace(tmp, STATE)


def now():
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="milliseconds")


def proj(state):
    return state["config"]["core/project"]


def net_url(state, name):
    return f"{API}/projects/{proj(state)}/global/networks/{name}"


def region_url(state, region):
    return f"{API}/projects/{proj(state)}/regions/{region}"


def subnet_url(state, region, name):
    return f"{region_url(state, region)}/subnetworks/{name}"


def basename(v):
    return v.rsplit("/", 1)[-1] if isinstance(v, str) else v


def new_id(state):
    state["next_id"] = state.get("next_id", 5170000000000000000) + 7919
    return str(state["next_id"])


def make_network(state, name, mode, description=None, created=None):
    net = {
        "kind": "compute#network",
        "id": new_id(state),
        "creationTimestamp": created or now(),
        "name": name,
        "selfLink": net_url(state, name),
        "autoCreateSubnetworks": mode == "auto",
        "routingConfig": {"routingMode": "REGIONAL"},
        "networkFirewallPolicyEnforcementOrder": "AFTER_CLASSIC_FIREWALL",
        "subnetworks": [],
    }
    if description:
        net["description"] = description
    state["networks"][name] = net
    if mode == "auto":
        for region, rng in REGIONS.items():
            make_subnet(state, name, name, region, rng, auto=True, created=net["creationTimestamp"])
    return net


def make_subnet(state, name, network, region, rng, auto=False, pga=False, created=None):
    cidr = ipaddress.ip_network(rng)
    sub = {
        "kind": "compute#subnetwork",
        "id": new_id(state),
        "creationTimestamp": created or now(),
        "name": name,
        "network": net_url(state, network),
        "ipCidrRange": str(cidr),
        "gatewayAddress": str(cidr.network_address + 1),
        "region": region_url(state, region),
        "selfLink": subnet_url(state, region, name),
        "privateIpGoogleAccess": pga,
        "purpose": "PRIVATE",
        "stackType": "IPV4_ONLY",
        "enableFlowLogs": False,
        "logConfig": {"enable": False},
        "fingerprint": os.urandom(6).hex(),
    }
    state["subnets"][f"{region}/{name}"] = sub
    state["networks"][network]["subnetworks"].append(sub["selfLink"])
    return sub


def view_network(n):
    """A network as gcloud shows it, with the x_gcloud fields that list output adds."""
    v = dict(n)
    v["x_gcloud_subnet_mode"] = "AUTO" if n["autoCreateSubnetworks"] else "CUSTOM"
    v["x_gcloud_bgp_routing_mode"] = n["routingConfig"]["routingMode"]
    return v


# ---------------------------------------------------------------- output

def get_field(obj, path):
    transform = None
    m = re.match(r"^(.*)\.basename\(\)$", path)
    if m:
        path, transform = m.group(1), basename
    cur = obj
    for part in path.split("."):
        if isinstance(cur, dict) and part in cur:
            cur = cur[part]
        else:
            return None
    if transform:
        cur = [transform(x) for x in cur] if isinstance(cur, list) else transform(cur)
    return cur


def scalar(v):
    if v is None:
        return ""
    if isinstance(v, bool):
        return "True" if v else "False"
    if isinstance(v, list):
        return ";".join(scalar(x) for x in v)
    if isinstance(v, dict):
        return json.dumps(v, sort_keys=True)
    return str(v)


def yaml_dump(obj, indent=0):
    pad = " " * indent
    out = []
    if isinstance(obj, dict):
        for k in sorted(obj):
            v = obj[k]
            if isinstance(v, dict) and v:
                out.append(f"{pad}{k}:")
                out.extend(yaml_dump(v, indent + 2))
            elif isinstance(v, list) and v:
                out.append(f"{pad}{k}:")
                for item in v:
                    if isinstance(item, dict):
                        lines = yaml_dump(item, indent + 2)
                        out.append(f"{pad}- {lines[0].strip()}")
                        out.extend(lines[1:])
                    else:
                        out.append(f"{pad}- {yaml_scalar(item)}")
            else:
                out.append(f"{pad}{k}: {yaml_scalar(v)}")
    return out


def yaml_scalar(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if v is None:
        return "null"
    if isinstance(v, (dict, list)):
        return "{}" if isinstance(v, dict) else "[]"
    if isinstance(v, (int, float)):
        return str(v)
    s = str(v)
    if s == "" or re.search(r"[:#]\s|^[\d.]+$|^(true|false|null)$", s) or s[0] in "-[{&*!|>'\"%@`":
        return "'" + s.replace("'", "''") + "'"
    return s


def table(rows, columns):
    """columns: list of (HEADER, function(obj) -> str)"""
    cells = [[h for h, _ in columns]] + [[f(r) for _, f in columns] for r in rows]
    widths = [max(len(c[i]) for c in cells) for i in range(len(columns))]
    for c in cells:
        line = "  ".join(v.ljust(widths[i]) for i, v in enumerate(c)).rstrip()
        print(line)


def emit(objs, fmt, columns, single=False):
    """Print objects in the format asked for. Default: a table for lists, YAML for describe."""
    if fmt in (None, "") and single:
        fmt = "yaml"
    if fmt in (None, "", "default", "table"):
        if objs:
            table(objs, columns)
        elif not single:
            print("Listed 0 items.", file=sys.stderr)
        return
    if fmt == "json":
        print(json.dumps(objs[0] if single else objs, indent=2, sort_keys=True))
        return
    if fmt == "yaml":
        for i, o in enumerate(objs):
            if i or not single:
                print("---")
            print("\n".join(yaml_dump(o)))
        return
    m = re.match(r"^(value|csv|table)(\[[^\]]*\])?\((.*)\)$", fmt)
    if not m:
        fail(f"Format [{fmt}] is not supported by this stand-in. Use json, yaml, table(...), csv(...) or value(...).")
    kind, attrs, fields = m.group(1), m.group(2) or "", [f.strip() for f in m.group(3).split(",") if f.strip()]
    keys = []
    for f in fields:
        key, _, label = f.partition(":label=")
        keys.append((key.strip(), (label or re.sub(r"\.basename\(\)$", "", key).split(".")[-1]).upper()))
    if kind == "value":
        for o in objs:
            print("\t".join(scalar(get_field(o, k)) for k, _ in keys))
    elif kind == "csv":
        if "no-heading" not in attrs:
            print(",".join(re.sub(r"\.basename\(\)$", "", k) for k, _ in keys))
        for o in objs:
            print(",".join(scalar(get_field(o, k)) for k, _ in keys))
    else:
        table(objs, [(label, (lambda k: lambda o: scalar(get_field(o, k)))(k)) for k, label in keys])


def apply_filter(objs, expr):
    if not expr:
        return objs
    terms = [t.strip() for t in re.split(r"\s+AND\s+", expr.strip()) if t.strip()]
    parsed = []
    for t in terms:
        m = re.match(r"^(NOT\s+)?([A-Za-z_][\w.]*)\s*(!=|=|:|~)\s*(.+)$", t)
        if not m:
            fail(f"Filter [{expr}] is not supported by this stand-in. Use key=value, key:value or key~regex, joined with AND.")
        neg, key, op, val = m.group(1), m.group(2), m.group(3), m.group(4).strip().strip("'\"")
        parsed.append((bool(neg), key, op, val))

    def match_one(o, key, op, val):
        v = get_field(o, key)
        vals = v if isinstance(v, list) else [v]
        for x in vals:
            s, b = scalar(x), scalar(basename(x))
            if op in ("=", "!=") and val.lower() in (s.lower(), b.lower()):
                return op == "="
            if op == ":" and (val == "*" and s or val.lower() in s.lower()):
                return True
            if op == "~" and re.search(val, s):
                return True
        return op == "!="

    return [o for o in objs if all(match_one(o, k, op, v) != neg for neg, k, op, v in parsed)]


NET_COLUMNS = [
    ("NAME", lambda n: n["name"]),
    ("SUBNET_MODE", lambda n: n["x_gcloud_subnet_mode"]),
    ("BGP_ROUTING_MODE", lambda n: n["x_gcloud_bgp_routing_mode"]),
    ("IPV4_RANGE", lambda n: ""),
    ("GATEWAY_IPV4", lambda n: ""),
]
SUB_COLUMNS = [
    ("NAME", lambda s: s["name"]),
    ("REGION", lambda s: basename(s["region"])),
    ("NETWORK", lambda s: basename(s["network"])),
    ("RANGE", lambda s: s["ipCidrRange"]),
    ("STACK_TYPE", lambda s: s["stackType"]),
    ("IPV6_ACCESS_TYPE", lambda s: ""),
    ("INTERNAL_IPV6_PREFIX", lambda s: ""),
    ("EXTERNAL_IPV6_PREFIX", lambda s: ""),
]


# ---------------------------------------------------------------- argument parsing

def parse(args, flags, bools, positional_max=1):
    """flags: names that take a value. bools: names that don't (a --no- form is accepted too)."""
    pos, opts = [], {}
    i = 0
    while i < len(args):
        a = args[i]
        if a.startswith("--"):
            name, eq, val = a[2:].partition("=")
            if name in flags:
                if not eq:
                    i += 1
                    if i >= len(args):
                        fail(f"argument --{name}: expected one argument")
                    val = args[i]
                opts[name] = val
            elif name in bools:
                opts[name] = True
            elif name.startswith("no-") and name[3:] in bools:
                opts[name[3:]] = False
            else:
                fail(f"unrecognized arguments: {a}\n\nTo search the help text of gcloud commands, run:\n  gcloud help -- SEARCH_TERMS")
        else:
            pos.append(a)
        i += 1
    if len(pos) > positional_max:
        fail(f"unrecognized arguments: {' '.join(pos[positional_max:])}")
    return pos, opts


def need_name(pos, what):
    if not pos:
        fail(f"argument NAME: Must be specified.\nUsage: gcloud {what} NAME [optional flags]")
    return pos[0]


def confirm(question, items, quiet):
    print(question, file=sys.stderr)
    for it in items:
        print(f" - [{it}]", file=sys.stderr)
    print(file=sys.stderr)
    if quiet or not sys.stdin.isatty():
        return True
    try:
        ans = input("Do you want to continue (Y/n)?  ").strip().lower()
    except EOFError:
        ans = ""
    if ans in ("", "y", "yes"):
        return True
    fail("Aborted by user.")


def region_of(state, opts, name):
    region = opts.get("region") or state["config"].get("compute/region")
    if not region:
        fail(f"Underspecified resource [{name}]. Specify the [--region] flag.")
    if region not in REGIONS:
        fail(f"Could not fetch resource:\n - Invalid value for field 'region': '{region}'. Unknown region.\n"
             f"   (This stand-in knows: {', '.join(REGIONS)})")
    return region


# ---------------------------------------------------------------- commands

def networks_create(state, args, g):
    pos, opts = parse(args, {"subnet-mode", "bgp-routing-mode", "description", "mtu"}, set())
    name = need_name(pos, "compute networks create")
    mode = opts.get("subnet-mode", "auto").lower()
    if mode not in ("auto", "custom"):
        fail(f"argument --subnet-mode: Invalid choice: '{mode}'. Valid choices are [auto, custom].")
    if opts.get("bgp-routing-mode", "regional").lower() not in ("regional", "global"):
        fail("argument --bgp-routing-mode: Invalid choice. Valid choices are [global, regional].")
    if not NAME_RE.match(name):
        fail(f"Could not fetch resource:\n - Invalid value for field 'resource.name': '{name}'. Must be a match of regex "
             "'(?:[a-z](?:[-a-z0-9]{0,61}[a-z0-9])?)'")
    if name in state["networks"]:
        fail(f"Could not fetch resource:\n - The resource 'projects/{proj(state)}/global/networks/{name}' already exists")
    if len(state["networks"]) >= NETWORK_QUOTA:
        fail(f"Could not fetch resource:\n - Quota 'NETWORKS' exceeded.  Limit: {NETWORK_QUOTA}.0 globally.")
    net = make_network(state, name, mode, opts.get("description"))
    if opts.get("bgp-routing-mode", "").lower() == "global":
        net["routingConfig"]["routingMode"] = "GLOBAL"
    save(state)
    print(f"Created [{net['selfLink']}].", file=sys.stderr)
    emit([view_network(net)], g["format"], NET_COLUMNS)
    print(f"\nInstances on this network will not be reachable until firewall rules\n"
          f"are created. As an example, you can allow all internal traffic between\n"
          f"instances as well as SSH, RDP, and ICMP by running:\n\n"
          f"$ gcloud compute firewall-rules create <FIREWALL_NAME> --network {name} --allow tcp,udp,icmp --source-ranges <IP_RANGE>\n"
          f"$ gcloud compute firewall-rules create <FIREWALL_NAME> --network {name} --allow tcp:22,tcp:3389,icmp\n",
          file=sys.stderr)


def networks_list(state, args, g):
    parse(args, set(), set(), positional_max=0)
    nets = apply_filter([view_network(n) for n in state["networks"].values()], g["filter"])
    nets.sort(key=lambda n: n["name"])
    emit(nets, g["format"], NET_COLUMNS)


def networks_describe(state, args, g):
    pos, _ = parse(args, set(), set())
    name = need_name(pos, "compute networks describe")
    if name not in state["networks"]:
        fail(f"Could not fetch resource:\n - The resource 'projects/{proj(state)}/global/networks/{name}' was not found")
    emit([state["networks"][name]], g["format"], NET_COLUMNS, single=True)


def networks_delete(state, args, g):
    pos, _ = parse(args, set(), set(), positional_max=99)
    if not pos:
        need_name(pos, "compute networks delete")
    for name in pos:
        if name not in state["networks"]:
            fail(f"Could not fetch resource:\n - The resource 'projects/{proj(state)}/global/networks/{name}' was not found")
    confirm("The following networks will be deleted:", pos, g["quiet"])
    for name in pos:
        own = [k for k, s in state["subnets"].items() if basename(s["network"]) == name]
        auto = state["networks"][name]["autoCreateSubnetworks"]
        # Auto mode subnets go with their network; any other subnet keeps the network in use.
        blocking = [state["subnets"][k] for k in own
                    if not (auto and state["subnets"][k]["ipCidrRange"] == REGIONS[basename(state["subnets"][k]["region"])]
                            and state["subnets"][k]["name"] == name)]
        if blocking:
            fail(f"Could not fetch resource:\n - The network resource 'projects/{proj(state)}/global/networks/{name}' "
                 f"is already being used by 'projects/{proj(state)}/regions/{basename(blocking[0]['region'])}"
                 f"/subnetworks/{blocking[0]['name']}'")
        for k in own:
            del state["subnets"][k]
        url = state["networks"].pop(name)["selfLink"]
        state.setdefault("audit", []).append({"time": now(), "method": "v1.compute.networks.delete", "resource": name})
        save(state)
        print(f"Deleted [{url}].", file=sys.stderr)


def validate_range(state, network, rng, region, name):
    try:
        cidr = ipaddress.ip_network(rng, strict=True)
    except ValueError as e:
        if "host bits" in str(e):
            fail(f"Could not fetch resource:\n - Invalid IPCidrRange: {rng}. The address must be the first address "
                 f"of the range (host bits must be zero).")
        fail(f"Could not fetch resource:\n - Invalid value for field 'resource.ipCidrRange': '{rng}'. Invalid IPCidrRange: {rng}.")
    if cidr.version != 4:
        fail(f"Could not fetch resource:\n - Invalid value for field 'resource.ipCidrRange': '{rng}'. Must be an IPv4 range.")
    if not any(cidr.subnet_of(a) for a in ALLOWED):
        fail(f"Could not fetch resource:\n - Invalid IPCidrRange: {rng}. This stand-in accepts private ranges only "
             f"(10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 100.64.0.0/10).")
    if cidr.prefixlen > 29:
        fail(f"Could not fetch resource:\n - Invalid IPCidrRange: {rng}. The smallest subnet is a /29.")
    for s in state["subnets"].values():
        if basename(s["network"]) == network and cidr.overlaps(ipaddress.ip_network(s["ipCidrRange"])):
            fail(f"Could not fetch resource:\n - Invalid IPCidrRange: {rng} conflicts with existing subnetwork "
                 f"'{s['name']}' in region '{basename(s['region'])}'.")
    return cidr


LOG_FLAGS = {"logging-aggregation-interval", "logging-flow-sampling", "logging-metadata", "logging-filter-expr"}


def set_logging(sub, opts):
    if "enable-flow-logs" in opts:
        sub["enableFlowLogs"] = opts["enable-flow-logs"]
        if opts["enable-flow-logs"]:
            sub["logConfig"] = {"enable": True, "aggregationInterval": "INTERVAL_5_SEC",
                                "flowSampling": 0.5, "metadata": "INCLUDE_ALL_METADATA"}
        else:
            sub["logConfig"] = {"enable": False}
    if any(f in opts for f in LOG_FLAGS):
        if not sub["logConfig"].get("enable"):
            fail("Flow log settings can only be set on a subnet with flow logs enabled: add --enable-flow-logs.")
        if "logging-aggregation-interval" in opts:
            v = opts["logging-aggregation-interval"].upper().replace("-", "_")
            if v not in ("INTERVAL_5_SEC", "INTERVAL_30_SEC", "INTERVAL_1_MIN", "INTERVAL_5_MIN", "INTERVAL_10_MIN", "INTERVAL_15_MIN"):
                fail("argument --logging-aggregation-interval: Invalid choice.")
            sub["logConfig"]["aggregationInterval"] = v
        if "logging-flow-sampling" in opts:
            try:
                v = float(opts["logging-flow-sampling"])
            except ValueError:
                v = -1
            if not 0 <= v <= 1:
                fail("argument --logging-flow-sampling: Value must be between 0.0 and 1.0.")
            sub["logConfig"]["flowSampling"] = v
        if "logging-metadata" in opts:
            v = opts["logging-metadata"].upper().replace("-", "_")
            v = {"INCLUDE_ALL": "INCLUDE_ALL_METADATA", "EXCLUDE_ALL": "EXCLUDE_ALL_METADATA"}.get(v, v)
            if v not in ("INCLUDE_ALL_METADATA", "EXCLUDE_ALL_METADATA", "CUSTOM_METADATA"):
                fail("argument --logging-metadata: Invalid choice.")
            sub["logConfig"]["metadata"] = v
        if "logging-filter-expr" in opts:
            sub["logConfig"]["filterExpr"] = opts["logging-filter-expr"]


def subnets_create(state, args, g):
    pos, opts = parse(args, {"network", "region", "range", "description", "stack-type"} | LOG_FLAGS,
                      {"enable-private-ip-google-access", "enable-flow-logs"})
    name = need_name(pos, "compute networks subnets create")
    if "network" not in opts:
        fail("argument --network: Must be specified.")
    if "range" not in opts:
        fail("argument --range: Must be specified.")
    if opts.get("stack-type", "IPV4_ONLY").upper() != "IPV4_ONLY":
        fail("This stand-in supports --stack-type=IPV4_ONLY only.")
    region = region_of(state, opts, name)
    network = basename(opts["network"])
    if network not in state["networks"]:
        fail(f"Could not fetch resource:\n - The resource 'projects/{proj(state)}/global/networks/{network}' was not found")
    if not NAME_RE.match(name):
        fail(f"Could not fetch resource:\n - Invalid value for field 'resource.name': '{name}'.")
    if f"{region}/{name}" in state["subnets"]:
        fail(f"Could not fetch resource:\n - The resource 'projects/{proj(state)}/regions/{region}/subnetworks/{name}' already exists")
    validate_range(state, network, opts["range"], region, name)
    sub = make_subnet(state, name, network, region, opts["range"],
                      pga=bool(opts.get("enable-private-ip-google-access", False)))
    if opts.get("description"):
        sub["description"] = opts["description"]
    set_logging(sub, opts)
    save(state)
    print(f"Created [{sub['selfLink']}].", file=sys.stderr)
    emit([sub], g["format"], SUB_COLUMNS)


def subnets_list(state, args, g):
    _, opts = parse(args, {"network", "regions"}, set(), positional_max=0)
    subs = list(state["subnets"].values())
    if opts.get("network"):
        net = basename(opts["network"])
        subs = [s for s in subs if basename(s["network"]) == net]
    if opts.get("regions"):
        want = set(opts["regions"].split(","))
        subs = [s for s in subs if basename(s["region"]) in want]
    subs = apply_filter(subs, g["filter"])
    subs.sort(key=lambda s: (s["name"], basename(s["region"])))
    emit(subs, g["format"], SUB_COLUMNS)


def find_subnet(state, opts, name):
    region = region_of(state, opts, name)
    key = f"{region}/{name}"
    if key not in state["subnets"]:
        fail(f"Could not fetch resource:\n - The resource 'projects/{proj(state)}/regions/{region}/subnetworks/{name}' was not found")
    return key


def subnets_describe(state, args, g):
    pos, opts = parse(args, {"region"}, set())
    name = need_name(pos, "compute networks subnets describe")
    emit([state["subnets"][find_subnet(state, opts, name)]], g["format"], SUB_COLUMNS, single=True)


def subnets_update(state, args, g):
    pos, opts = parse(args, {"region"} | LOG_FLAGS, {"enable-private-ip-google-access", "enable-flow-logs"})
    name = need_name(pos, "compute networks subnets update")
    sub = state["subnets"][find_subnet(state, opts, name)]
    changes = {k for k in opts if k != "region"}
    if not changes:
        fail("At least one property must be modified.")
    if "enable-private-ip-google-access" in opts:
        sub["privateIpGoogleAccess"] = opts["enable-private-ip-google-access"]
    set_logging(sub, opts)
    sub["fingerprint"] = os.urandom(6).hex()
    save(state)
    print(f"Updated [{sub['selfLink']}].", file=sys.stderr)


def subnets_delete(state, args, g):
    pos, opts = parse(args, {"region"}, set(), positional_max=99)
    if not pos:
        need_name(pos, "compute networks subnets delete")
    keys = [find_subnet(state, opts, n) for n in pos]
    confirm("The following subnetworks will be deleted:", [f"{n}] in [{k.split('/')[0]}" for n, k in zip(pos, keys)], g["quiet"])
    for k in keys:
        sub = state["subnets"][k]
        net = state["networks"][basename(sub["network"])]
        if net["autoCreateSubnetworks"] and sub["name"] == net["name"]:
            fail(f"Could not fetch resource:\n - The subnetwork '{sub['name']}' was created automatically by an auto mode "
                 f"network and can only be removed with the network (or after switching it to custom mode).")
        net["subnetworks"].remove(sub["selfLink"])
        del state["subnets"][k]
        save(state)
        print(f"Deleted [{sub['selfLink']}].", file=sys.stderr)


def regions_list(state, args, g):
    parse(args, set(), set(), positional_max=0)
    rows = [{"name": r, "status": "UP"} for r in sorted(REGIONS)]
    emit(apply_filter(rows, g["filter"]), g["format"], [("NAME", lambda r: r["name"]), ("STATUS", lambda r: r["status"])])


CONFIG_KEYS = {"project": "core/project", "core/project": "core/project", "account": "core/account",
               "core/account": "core/account", "compute/region": "compute/region", "compute/zone": "compute/zone"}


def config_cmd(state, sub, args, g):
    if sub == "list":
        c = state["config"]
        print("[compute]")
        for k in ("region", "zone"):
            if c.get(f"compute/{k}"):
                print(f"{k} = {c[f'compute/{k}']}")
        print("[core]")
        print(f"account = {c['core/account']}")
        print(f"project = {c['core/project']}")
        print("\nYour active configuration is: [cloudshell-4518]")
        return
    pos, _ = parse(args, set(), set(), positional_max=2)
    if not pos or pos[0] not in CONFIG_KEYS:
        fail(f"This stand-in knows these properties: {', '.join(sorted(k for k in CONFIG_KEYS if '/' in k))}")
    key = CONFIG_KEYS[pos[0]]
    if sub == "get-value" or sub == "get":
        v = state["config"].get(key)
        if v:
            print(v)
        else:
            print(f"(unset)", file=sys.stderr)
    elif sub == "set":
        if len(pos) != 2:
            fail("argument VALUE: Must be specified.")
        if key in ("core/project", "core/account"):
            fail(f"This sandbox is bound to one project and account; [{pos[0]}] cannot be changed here.")
        if key == "compute/region" and pos[1] not in REGIONS:
            fail(f"Unknown region [{pos[1]}]. Known: {', '.join(REGIONS)}")
        state["config"][key] = pos[1]
        save(state)
        print(f"Updated property [{key.replace('/', '/')}].", file=sys.stderr)
    elif sub == "unset":
        if key in ("core/project", "core/account"):
            fail(f"[{pos[0]}] cannot be unset in this sandbox.")
        state["config"].pop(key, None)
        save(state)
        print(f"Unset property [{key}].", file=sys.stderr)
    else:
        fail(f"Invalid choice: '{sub}'.")


def auth_list(state, args, g):
    print("Credentialed Accounts")
    print("ACTIVE  ACCOUNT")
    print(f"*       {state['config']['core/account']}")
    print("\nTo set the active account, run:\n    $ gcloud config set account `ACCOUNT`\n")


HELP = {
    "compute networks create": "gcloud compute networks create NAME [--subnet-mode=MODE; default=auto] [--bgp-routing-mode=MODE; default=regional] [--description=DESCRIPTION]\n\n  MODE is one of: auto (one subnet in every region, fixed ranges), custom (you create the subnets).",
    "compute networks list": "gcloud compute networks list [--filter=EXPRESSION] [--format=FORMAT]",
    "compute networks describe": "gcloud compute networks describe NAME [--format=FORMAT]",
    "compute networks delete": "gcloud compute networks delete NAME [NAME ...] [--quiet]",
    "compute networks subnets create": "gcloud compute networks subnets create NAME --network=NETWORK --range=RANGE [--region=REGION] [--enable-private-ip-google-access] [--enable-flow-logs] [--logging-aggregation-interval=INTERVAL] [--logging-flow-sampling=SAMPLING] [--logging-metadata=METADATA] [--description=DESCRIPTION]",
    "compute networks subnets list": "gcloud compute networks subnets list [--network=NETWORK] [--regions=REGION,[REGION,...]] [--filter=EXPRESSION] [--format=FORMAT]",
    "compute networks subnets describe": "gcloud compute networks subnets describe NAME [--region=REGION] [--format=FORMAT]",
    "compute networks subnets update": "gcloud compute networks subnets update NAME [--region=REGION] [--[no-]enable-private-ip-google-access] [--[no-]enable-flow-logs] [--logging-aggregation-interval=INTERVAL] [--logging-flow-sampling=SAMPLING] [--logging-metadata=METADATA]",
    "compute networks subnets delete": "gcloud compute networks subnets delete NAME [NAME ...] [--region=REGION] [--quiet]",
    "compute regions list": "gcloud compute regions list [--filter=EXPRESSION] [--format=FORMAT]",
    "config list": "gcloud config list",
    "config get-value": "gcloud config get-value PROPERTY   (project, account, compute/region, compute/zone)",
    "config set": "gcloud config set PROPERTY VALUE   (compute/region, compute/zone)",
    "config unset": "gcloud config unset PROPERTY",
    "auth list": "gcloud auth list",
}

GROUPS = {
    "": ["auth", "compute", "config"],
    "compute": ["networks", "regions"],
    "compute networks": ["create", "delete", "describe", "list", "subnets"],
    "compute networks subnets": ["create", "delete", "describe", "list", "update"],
    "compute regions": ["list"],
    "config": ["get-value", "list", "set", "unset"],
    "auth": ["list"],
}


def show_help(path):
    if path in HELP:
        print(f"SYNOPSIS\n    {HELP[path]}\n\nThis is a lab stand-in for gcloud; the real reference is\n"
              f"https://cloud.google.com/sdk/gcloud/reference/{path.replace(' ', '/')}")
    else:
        print(f"gcloud {path}".strip() + " GROUP | COMMAND\n\nAvailable: " + ", ".join(GROUPS.get(path, [])))


def main(argv):
    global COMMAND
    g = {"format": None, "filter": None, "quiet": False}
    rest, i = [], 0
    while i < len(argv):
        a = argv[i]
        name, eq, val = a.partition("=")
        if name in ("--format", "--filter", "--project", "--sort-by", "--limit", "--verbosity", "--page-size"):
            if not eq:
                i += 1
                val = argv[i] if i < len(argv) else ""
            if name == "--project":
                g["project"] = val
            elif name in ("--format", "--filter"):
                g[name[2:]] = val
        elif a in ("--quiet", "-q"):
            g["quiet"] = True
        elif a in ("--help", "-h", "help"):
            g["help"] = True
        else:
            rest.append(a)
        i += 1

    path = []
    while rest and " ".join(path + [rest[0]]) in GROUPS or (rest and " ".join(path + [rest[0]]) in HELP):
        path.append(rest.pop(0))
        if " ".join(path) in HELP:
            break
    key = " ".join(path)
    COMMAND = "gcloud." + ".".join(path) if path else "gcloud"
    if g.get("help") or key in GROUPS:
        if key in GROUPS and not g.get("help") and rest:
            fail(f"Invalid choice: '{rest[0]}'.\nMaybe you meant one of: {', '.join(GROUPS[key])}")
        if key in GROUPS and not g.get("help"):
            print(f"ERROR: ({COMMAND}) Command name argument expected.\n\nAvailable: {', '.join(GROUPS[key])}", file=sys.stderr)
            return 2
        show_help(key)
        return 0
    if key == "" and rest and rest[0] == "--version":
        print("Google Cloud SDK (lab stand-in)\ncompute networks/subnets subset")
        return 0

    with open(STATE + ".lock", "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        state = load()
        if g.get("project") and g["project"] != proj(state):
            fail(f"Could not fetch resource:\n - The user does not have access to project '{g['project']}'.")
        handlers = {
            "compute networks create": networks_create,
            "compute networks list": networks_list,
            "compute networks describe": networks_describe,
            "compute networks delete": networks_delete,
            "compute networks subnets create": subnets_create,
            "compute networks subnets list": subnets_list,
            "compute networks subnets describe": subnets_describe,
            "compute networks subnets update": subnets_update,
            "compute networks subnets delete": subnets_delete,
            "compute regions list": regions_list,
            "auth list": auth_list,
        }
        if key in handlers:
            handlers[key](state, rest, g)
        elif path and path[0] == "config":
            config_cmd(state, path[1], rest, g)
        else:
            fail(f"Invalid choice: '{rest[0] if rest else key}'.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except GcloudError as e:
        print(e, file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        sys.exit(130)
