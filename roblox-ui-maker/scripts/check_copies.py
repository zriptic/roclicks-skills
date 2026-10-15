#!/usr/bin/env python3
"""check_copies.py: fail when copies of the same runtime module have drifted apart.

The bug it prevents: the UI runtime module lived in three places (live StarterGui copy, the
Builder's private copy in ServerStorage, the source tree). Fixes went into one; the Builder's copy
fell 430 lines behind, and the next rebuild would have installed it and crashed the HUD on init.

Give it a manifest of groups. Each group lists files that must be byte-identical (after normalising
line endings and trailing whitespace). Paths are relative to the manifest. Export Studio copies to
disk first (e.g. a snapshot folder) so they can be compared here.

copies.json:
  {
    "ui-runtime": ["roblox/ui/client/UI.luau", "snapshot/ServerStorage/GameUIBuild/Client/UI.luau",
                   "snapshot/StarterGui/GameUI/UI.luau"],
    "uikit": ["roblox/ui/UIKit.luau", "snapshot/StarterGui/GameUI/UIKit.luau"],
    "controller": ["roblox/ui/client/Controller.client.luau", "snapshot/ServerStorage/GameUIBuild/Client/Controller.luau"]
  }
Snapshot a Studio copy: robloxstudio get_script_source on the instance, write it to snapshot/<path>.luau.

Usage:  python3 check_copies.py copies.json        (exit 1 on any drift; run before and after every push)
"""
import hashlib
import json
import os
import sys


def norm_hash(path):
    text = open(path, encoding="utf-8").read().replace("\r\n", "\n")
    text = "\n".join(line.rstrip() for line in text.split("\n")).strip() + "\n"
    return hashlib.sha256(text.encode()).hexdigest()[:12], text.count("\n")


def main(manifest):
    base = os.path.dirname(os.path.abspath(manifest))
    groups = json.load(open(manifest))
    bad = 0
    for name, files in groups.items():
        seen = {}
        for rel in files:
            p = os.path.join(base, rel)
            if not os.path.exists(p):
                print(f"[{name}] MISSING {rel}")
                bad += 1
                continue
            h, lines = norm_hash(p)
            seen.setdefault(h, []).append((rel, lines))
        if len(seen) > 1:
            bad += 1
            print(f"[{name}] DRIFT: {len(seen)} different versions")
            for h, items in seen.items():
                for rel, lines in items:
                    print(f"   {h}  {lines:5d} lines  {rel}")
            print("   -> copy the canonical file (source tree) over the others, then re-push.")
        else:
            print(f"[{name}] ok ({len(files)} copies)")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
