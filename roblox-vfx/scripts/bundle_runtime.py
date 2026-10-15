#!/usr/bin/env python3
"""Bundle the skill's Luau runtime into one .rbxmx: a Folder "VFX" holding the
ModuleScripts Emit, Build, Capture and Shapes. Push it with robloxstudio
import_rbxm (reads from disk, so no source passes through the JSON transport,
which mangles "\\n" in set_script_source).

Usage: bundle_runtime.py [out.rbxmx] [--only Emit,Shapes]

Default out: /tmp/vfx_runtime.rbxmx. Import it under ReplicatedStorage; if a
VFX folder already exists there, move the modules into it (keep its effect
templates) and delete the imported folder. In edit mode `require` caches a
module's first result for the whole Studio session: after replacing a module,
also replace every module that requires it, or restart Studio.
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent / "templates"
MODULES = ["Emit", "Build", "Capture", "Shapes"]


def item(name: str, ref: int) -> str:
    source = (HERE / f"{name}.luau").read_text(encoding="utf-8").replace("]]>", "]]]]><![CDATA[>")
    return f"""    <Item class="ModuleScript" referent="RBX{ref}">
      <Properties>
        <string name="Name">{name}</string>
        <ProtectedString name="Source"><![CDATA[{source}]]></ProtectedString>
      </Properties>
    </Item>
"""


def main() -> int:
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("out", nargs="?", default="/tmp/vfx_runtime.rbxmx")
    ap.add_argument("--only", default=",".join(MODULES), help="comma list, e.g. Emit,Shapes")
    a = ap.parse_args()
    only = [n for n in a.only.split(",") if n]
    out = Path(a.out)
    body = "".join(item(n, i + 1) for i, n in enumerate(only))
    xml = f"""<roblox version="4">
  <Item class="Folder" referent="RBX0">
    <Properties>
      <string name="Name">VFX</string>
    </Properties>
{body}  </Item>
</roblox>
"""
    out.write_text(xml, encoding="utf-8")
    print(f"{out}: Folder VFX with {', '.join(only)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
