# meshlab modelling brief (give this to your AI agent)

You are modelling Roblox assets as **Luau code** that builds an EditableMesh, previewed
outside Studio with Lune + Blender. The toolkit is in `meshlab/`. Read `Shapes.luau`,
`Props.luau` and two or three files in `meshlab/models/` before writing anything.

## Model file shape
```lua
--!nocheck
-- <what it is, its parts, which pieces move and their pivots, units>
return function(em, lib, Shapes, part)
	local V3, CF, C3 = lib.Vector3, lib.CFrame, lib.Color3
	local P = Shapes.Props
	local rand = P.rng(lib.seed)          -- deterministic random; lib.seed comes from the CLI
	Shapes.beginBake({ cell = 1.2 })      -- ambient occlusion; finishBake at the end
	local S = Shapes.new(em, lib)         -- main mesh ("Body")
	-- local S2 = Shapes.new(part("Arm"), lib)  -- a separately MOVING piece = its own part
	...
	Shapes.finishBake(lib, { distance = 2.0, strength = 0.6, sky = 0.22 })
end
```
Units are studs (a Roblox character is about 5 tall). Front faces **-Z**. Ground is **Y = 0**.
`Shapes.PITCH` (0.6) is the stud cell size; keep one value per game.

## Toolkit
- `S:bevelBox(cf, size, color, bevel)`: box with stud UVs. **Bevel 0 (crisp) by default**;
  soft bevels (0.05 to 0.2) only on round, organic or hero pieces.
- `S:box(cf, size, color)`: cheapest 12-triangle box for tiny details (rivets, stripes).
- `S:lathe(cf, profile, segs, color or fn(ring, s))`: surface of revolution around cf's Y axis;
  profile = {{radius, y}, ...} bottom to top, radius 0 closes a cap.
- `S:loft(rings, {closed = true, caps = true, color = ...})`: sweep through cross-section rings.
- `S:tube(path, radii, segs, color)`: smooth tube along a path.
- `P.cyl(S, cf, r, h, color, segs)`: chamfered cylinder. `P.limb`, `P.dir`, `P.rng`.
- `P.lookAt(lib, pos, dir)`: **use this, never CFrame.lookAt** (Lune 0.10.5's CFrame.lookAt is
  wrong for any direction with a Z component).
- Glowing things (lamps, screens) that should not get shadowed: draw them AFTER
  `Shapes.finishBake` into `part("Glow")` (see `models/Cabin.luau`).

## Limits
One EditableMesh holds at most **20,000 triangles / 60,000 vertices**; the runner warns.
Split into more `part(...)`s or simplify. Small props 200 to 3k triangles, vehicles under 15k.

## Build and look, until it's right
```
lune run meshlab/run <Name> [seed]
blender -b -P meshlab/render.py -- meshlab/out/<Name>.obj meshlab/out/<Name>.png hero 1.4
```
**Look at every render** (hero, then front, side and rear) and fix what's wrong: floating
pieces, wrong orientation, mirrored text, clipping, too dark, missing studs. Text read from
outside on the -Z face: +X is the viewer's LEFT.

## Style
- Chunky toy look, crisp edges, flat bright saturated colours, a few real details (bolts,
  handles, stripes, labels). No "AI look": no random neon strips or floating spheres.
- Measure the reference (photos, a real object's proportions) before building; don't eyeball.
- Size every prop against a 5-stud character.

## When done
Make a labelled contact sheet of the renders, and report each model file, its parts (which
move, and their pivots), and triangle counts.
