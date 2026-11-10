#!/usr/bin/env python3
"""Build the starting project for the lab: the default network, plus a leftover auto mode network."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gcloud  # noqa: E402

state = {
    "config": {"core/project": "larchmere-netsec-sbx", "core/account": "analyst@larchmere.example"},
    "networks": {},
    "subnets": {},
}
gcloud.make_network(state, "default", "auto", "Default network for the project",
                    created="2026-06-02T08:14:51.307-07:00")
gcloud.make_network(state, "temp-net", "auto", "quick connectivity test - remove when done",
                    created="2026-08-19T16:42:07.118-07:00")

os.makedirs(os.path.dirname(gcloud.STATE), exist_ok=True)
with open(gcloud.STATE, "w") as f:
    json.dump(state, f, indent=2)
