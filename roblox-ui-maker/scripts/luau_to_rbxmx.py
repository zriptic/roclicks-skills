#!/usr/bin/env python3
"""Wrap a .luau file in a Roblox XML model (.rbxmx) so it can be pushed into
Studio via import_rbxm without the source passing through anything else.

Usage: luau_to_rbxmx.py <in.luau> <out.rbxmx> <Name> <ClassName> [RunContext]

ClassName is Script | LocalScript | ModuleScript. RunContext (Legacy|Server|
Client) only applies to Script and defaults to Legacy, which is what a script
under ServerScriptService wants.
"""
import sys
from pathlib import Path

def main() -> int:
    if len(sys.argv) < 5:
        print(__doc__, file=sys.stderr)
        return 2

    src_path, out_path, name, class_name = sys.argv[1:5]
    run_context = sys.argv[5] if len(sys.argv) > 5 else "Legacy"

    source = Path(src_path).read_text(encoding="utf-8")

    # CDATA cannot contain "]]>". Split the sequence across two sections.
    source = source.replace("]]>", "]]]]><![CDATA[>")

    run_context_tag = ""
    if class_name == "Script":
        run_context_value = {"Legacy": 0, "Server": 1, "Client": 2}[run_context]
        run_context_tag = (
            f'\n      <token name="RunContext">{run_context_value}</token>'
        )

    xml = f"""<roblox version="4">
  <Item class="{class_name}" referent="RBX0">
    <Properties>
      <string name="Name">{name}</string>
      <ProtectedString name="Source"><![CDATA[{source}]]></ProtectedString>{run_context_tag}
    </Properties>
  </Item>
</roblox>
"""
    Path(out_path).write_text(xml, encoding="utf-8")
    print(f"{out_path}: {len(source)} chars of {class_name} '{name}'")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
