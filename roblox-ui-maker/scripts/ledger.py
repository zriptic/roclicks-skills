#!/usr/bin/env python3
"""HTML -> Roblox, step 3a: the upload ledger. Never upload the same image twice.

Usage (from the project's UI folder; preview server running on rbx.json's "port"):
    python3 $SK/scripts/ledger.py 20
        -> prints how many are done/left, then a JSON list of the next 20 http URLs to upload
    (call mcp__Roblox_Studio__upload_image with those URLs + studio_id; it returns {url: assetId})
    echo '<the JSON map upload_image returned>' | python3 .../scripts/ledger.py 20
        -> merges the result into rbx/out/uploaded.json, then prints the next batch
    python3 .../scripts/ledger.py --check     -> exit 1 if anything referenced is still missing

Keys: "art:<key>" (rbx/out/upload/<key>.png, content-hash names) and "icon:<slug>" (icons/<slug>.png).
Values are "rbxassetid://<id>" strings. Keep batches <= ~20: bigger batches time out, and some files
in a timed-out batch may still have uploaded -> re-run without input to see what is really left.
A reused ledger (copy uploaded.json from an earlier game made under the SAME group/account) saves
re-uploading shared icons. Ids from another owner can render as nothing: see VERIFY.md (probe ids).
"""
import json
import os
import re
import sys

CFG = json.load(open('rbx.json'))
OUT = os.path.join('rbx', 'out')
P = os.path.join(OUT, 'uploaded.json')
led = json.load(open(P)) if os.path.exists(P) else {}
args = [a for a in sys.argv[1:] if not a.startswith('--')]
if not sys.stdin.isatty():
    data = sys.stdin.read().strip()
    if data:
        res = json.loads(data)
        if isinstance(res, dict) and 'results' in res:
            res = res['results']
        if isinstance(res, list):   # tolerate [{url, assetId}] shapes
            res = {r.get('url') or r.get('path'): r.get('assetId') or r.get('id') for r in res}
        for url, aid in res.items():
            if not aid:
                continue
            aid = str(aid)
            if not aid.startswith('rbxassetid://'):
                aid = 'rbxassetid://' + re.sub(r'\D', '', aid)
            key = url.rsplit('/', 1)[1][:-4]
            led[('icon:' if '/icons/' in url else 'art:') + key] = aid
        json.dump(led, open(P, 'w'), indent=1, sort_keys=True)
L = json.load(open(os.path.join(OUT, 'upload_list.json')))
base = f"http://127.0.0.1:{CFG['port']}"
todo = [f'{base}/rbx/out/upload/{a}.png' for a in L['art'] if 'art:' + a not in led] + \
       [f'{base}/icons/{i}.png' for i in L['icons'] if 'icon:' + i not in led]
print(len(led), 'in ledger;', len(todo), 'left to upload')
if '--check' in sys.argv:
    sys.exit(1 if todo else 0)
n = int(args[0]) if args else 0
if n and todo:
    print(json.dumps(todo[:n]))
