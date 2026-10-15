#!/bin/bash
# Typecheck + lint Roblox Luau with plain luau-analyze (no Roblox type definitions needed).
# Prepends a ONE-LINE prelude that declares Roblox globals/types as `any`, then reports line numbers
# shifted back to the real file. Usage: check_luau.sh file.luau [...]
set -u
PRELUDE='type Vector3=any; type CFrame=any; type Instance=any; type Folder=any; type Humanoid=any; type BasePart=any; type Model=any; type ProximityPrompt=any; type Player=any; type RBXScriptSignal=any; type Color3=any; local game: any, workspace: any, Vector3: any, CFrame: any, Enum: any, task: any, Instance: any, DateTime: any, Random: any, RaycastParams: any, Color3: any, UDim2: any, warn: any, shared: any = nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil; local _ = {game, workspace, Vector3, CFrame, Enum, task, Instance, DateTime, Random, RaycastParams, Color3, UDim2, warn, shared};'
tmpd=$(mktemp -d)
rc=0
for f in "$@"; do
  base=$(basename "$f")
  # keep a leading --! directive line first so it still applies
  first=$(head -1 "$f")
  if [[ "$first" == --!* ]]; then
    { echo "$first"; echo "--!nolint UnknownType"; echo "$PRELUDE"; tail -n +2 "$f"; } > "$tmpd/$base"
    shift_lines=2
  else
    { echo "--!nolint UnknownType"; echo "$PRELUDE"; cat "$f"; } > "$tmpd/$base"
    shift_lines=2
  fi
  out=$(cd "$tmpd" && luau-analyze "$base" 2>&1)
  if [ -n "$out" ]; then
    rc=1
    echo "$out" | python3 -c '
import re,sys
s=int(sys.argv[1]); real=sys.argv[2]
for line in sys.stdin:
    m=re.match(r"^\S*?\((\d+),(\d+)\): (.*)$", line.rstrip("\n"))
    print(f"{real}:{int(m.group(1))-s}:{m.group(2)}: {m.group(3)}" if m else line.rstrip("\n"))
' "$shift_lines" "$f"
  else
    echo "OK  $f"
  fi
done
rm -rf "$tmpd"
exit $rc
