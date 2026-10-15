#!/usr/bin/env python3
"""HTML -> Roblox, step 4a: bundle the UI's Luau into one .rbxmx for robloxstudio import_rbxm.

Usage (from the project's UI folder):
    python3 $SK/scripts/bundle.py
        -> rbx/out/<Gui>Build.rbxmx = Folder "<Gui>Build" {
               every <luau_out>/*.luau as a ModuleScript (Builder, AssetIds, Data_*, UIKit, NumberFormat ...),
               Folder "Client" { <luau_out>/client/*.client.luau -> LocalScript, other client/*.luau -> ModuleScript } }
    python3 .../scripts/bundle.py --client
        -> rbx/out/<Gui>Client.rbxmx = only the Client folder (to refresh runtime scripts without a rebuild)

Then in Studio (robloxstudio MCP):
    1. execute_luau: destroy the old ServerStorage.<Gui>Build if present
    2. import_rbxm {source: {path: "<absolute .rbxmx path>"}, parent_path: "game.ServerStorage"}
    3. execute_luau: return require(game.ServerStorage.<Gui>Build.Builder).build()
Never push source with set_script_source / edit_script_lines: they expand "\\n" inside strings and the
script stops compiling (the push still reports success).
"""
import json
import os
import sys
from pathlib import Path

CFG = json.load(open('rbx.json'))
SRC = Path(os.path.abspath(CFG.get('luau_out', 'rbx/luau')))
GUI = CFG['gui']
ref = [0]


def esc(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def item(cls, name, src=None, kids=''):
    ref[0] += 1
    p = f'<string name="Name">{esc(name)}</string>'
    if src is not None:
        p += '<ProtectedString name="Source"><![CDATA[' + src.replace(']]>', ']]]]><![CDATA[>') + ']]></ProtectedString>'
    return f'<Item class="{cls}" referent="RBX{ref[0]}"><Properties>{p}</Properties>{kids}</Item>\n'


client = ''
for f in sorted((SRC / 'client').glob('*.luau')):
    if f.name.endswith('.client.luau'):
        client += item('LocalScript', f.name[:-len('.client.luau')], f.read_text())
    else:
        client += item('ModuleScript', f.stem, f.read_text())
client_folder = item('Folder', 'Client', kids=client)
out_dir = Path('rbx/out')
out_dir.mkdir(parents=True, exist_ok=True)
if '--client' in sys.argv:
    out = out_dir / f'{GUI}Client.rbxmx'
    out.write_text('<roblox version="4">\n' + client_folder + '</roblox>\n')
else:
    mods = ''
    for f in sorted(SRC.glob('*.luau')):
        if f.name.endswith('.client.luau'):
            sys.exit(f'{f.name}: LocalScripts go in {SRC}/client/ (LoadingScreen belongs in ReplicatedFirst, not in the bundle)')
        mods += item('ModuleScript', f.stem, f.read_text())
    out = out_dir / f'{GUI}Build.rbxmx'
    out.write_text('<roblox version="4">\n' + item('Folder', f'{GUI}Build', kids=mods + client_folder) + '</roblox>\n')
print(out.resolve(), out.stat().st_size // 1024, 'KB')
