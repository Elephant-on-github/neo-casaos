"""Bump one neo-casaos component's version after its release succeeds.

Usage: bump_manifest.py <component> <tag>   e.g. bump_manifest.py ui v0.4.51

Updates, in the same commit:
  - version.json  data.components.<component>.version (and top-level
    data.version for backend releases, which must match common.VERSION)
  - build/update.sh  FALLBACK_<COMPONENT> pin
  - build/install.sh  asset URL lines for this component + installed-state line
"""
import json
import re
import sys

component, tag = sys.argv[1], sys.argv[2]
ver = tag.lstrip("v")
fallback_name = component.upper()

serverside = {
    "backend": "neo-casaos",
    "gateway": "neo-casaos-gateway",
    "ui": "neo-casaos-ui",
}
if component not in serverside:
    sys.exit(f"unknown component: {component}")

# --- version.json ------------------------------------------------------------
p = "version.json"
d = json.load(open(p, encoding="utf-8"))
d["data"]["components"][component]["version"] = ver
if component == "backend":
    d["data"]["version"] = ver
open(p, "w", encoding="utf-8", newline="\n").write(json.dumps(d, separators=(",", ":")) + "\n")

# --- build/update.sh ---------------------------------------------------------
p = "build/update.sh"
s = open(p, encoding="utf-8").read()
s, n = re.subn(rf'(FALLBACK_{fallback_name}=")v[0-9][0-9.]*(")', rf"\g<1>{tag}\g<2>", s)
if n != 1:
    sys.exit(f"update.sh: expected 1 FALLBACK_{fallback_name} pin, found {n}")
open(p, "w", encoding="utf-8", newline="\n").write(s)

# --- build/install.sh --------------------------------------------------------
p = "build/install.sh"
lines = open(p, encoding="utf-8").read().splitlines(keepends=True)
url_hits = 0
state_hits = 0
for i, line in enumerate(lines):
    if f"/{serverside[component]}/releases/download/" in line and "tar.gz" in line:
        lines[i] = re.sub(r"v[0-9]+(?:\.[0-9]+)*", tag, line.rstrip("\n")) + "\n"
        url_hits += 1
    elif re.search(rf'"{component}":"[0-9.]+"', line):
        lines[i] = re.sub(rf'("{component}":")[0-9.]+(")', rf"\g<1>{ver}\g<2>", line.rstrip("\n")) + "\n"
        state_hits += 1
s = "".join(lines)
open(p, "w", encoding="utf-8", newline="\n").write(s)

if url_hits != 1 or state_hits != 1:
    sys.exit(f"install.sh: expected 1 URL line + 1 state entry for {component}, got {url_hits}/{state_hits}")

print(f"bumped {component} -> {tag}")
