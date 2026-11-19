#!/usr/bin/env python3
"""Checks what the downloads server serves against what was built and uploaded.

    OUT_DIR=out BASE_URL=https://downloads.example/forge-scaffold python3 tools/publish_verify.py

Downloads index.json and every archive it lists, and checks that the index is byte for byte the one
that was built, and that every archive has the sha256 and size the index gives. Retries for a short
while, because a server or CDN may take a moment to show new files.

Environment:
  OUT_DIR         the built release (default ./out)
  BASE_URL        the public https URL the archives are served from
  FETCH_BASE_URL  where to download from if that is not BASE_URL (a mirror, or a local server in a test)
  ATTEMPTS        default 5 (5 seconds apart)
"""
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request

out = os.environ.get("OUT_DIR", "out")
base = os.environ["BASE_URL"].rstrip("/")
fetch = os.environ.get("FETCH_BASE_URL", base).rstrip("/")
attempts = int(os.environ.get("ATTEMPTS", "5"))

if not base.startswith("https://"):
    sys.exit("error: BASE_URL must be https://")
if not (fetch.startswith("https://") or fetch.startswith("http://127.0.0.1") or fetch.startswith("http://localhost")):
    sys.exit("error: FETCH_BASE_URL must be https:// (plain http is only allowed for localhost)")


def get(url):
    last = None
    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(url, timeout=30) as r:
                return r.read(), r.headers
        except (urllib.error.URLError, TimeoutError) as e:
            last = e
            time.sleep(5 if attempt + 1 < attempts else 0)
    raise SystemExit(f"error: could not download {url}: {last}")


local_index = open(os.path.join(out, "index.json"), "rb").read()
served_index, headers = get(f"{fetch}/index.json")
problems = []
if served_index != local_index:
    problems.append("the index on the server is not the one that was built")
if not headers.get("ETag"):
    print("warning: the server sends no ETag for index.json, so clients cannot use conditional requests")

index = json.loads(served_index)
for e in index["templates"]:
    fname = e["dir"] + ".tar.gz"
    data, _ = get(f"{fetch}/{fname}")
    if hashlib.sha256(data).hexdigest() != e["sha256"]:
        problems.append(f"{fname}: the served file does not have the sha256 in the index")
    if len(data) != e["size"]:
        problems.append(f"{fname}: the served file has {len(data)} bytes, the index says {e['size']}")
    if not e["url"].startswith(base + "/"):
        problems.append(f"{fname}: the index url {e['url']} is not below {base}")

if problems:
    for p in problems:
        print(f"  - {p}", file=sys.stderr)
    sys.exit(1)
print(f"ok: index.json and {len(index['templates'])} archives served correctly from {fetch}")
