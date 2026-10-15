# meshlab: how every visible thing gets built (phases 2 + 3)

The developer's rule: **meshlab builds everything.** Every visible object (buildings, roads,
floors, walls, props, vehicles, character gear) is a meshlab model: Luau code that builds an
EditableMesh, previewed outside Studio, baked to data, and rebuilt in the game. Parts are only for
**invisible** things: colliders, triggers, SpawnLocations, seats.

Toolkit: the meshlab toolkit (github.com/zriptic/roclicks-skills, folder `meshlab/`). Run every
command below from the folder that contains `meshlab/`.

## 1. Model (outside Studio)
- Read `meshlab/BRIEF.md` (toolkit, loop, limits) and write a per-game brief such as
  `<game>/MODEL_BRIEF.md`: the game, the model prefix (`<PREFIX>_`), scale (R15 = 5 studs),
  palette, which parts move (`part("Name")`) and their pivots.
- One file per model: `meshlab/models/<PREFIX>_<Name>.luau`. Front = -Z, ground = Y 0.
- Loop: `lune run meshlab/run <Name>` → `blender -b -P meshlab/render.py -- meshlab/out/<Name>.obj meshlab/out/<Name>.png hero 1.4`.
  Look at every render; fix; contact sheet `meshlab/out/<PREFIX>_<Group>_sheet.png`.
- Big batches: run 3-4 background modelling agents in parallel (furniture / props / gags / decor),
  each with its own model list; none edits shared files. Check every contact sheet yourself.
- Style rules: stud UVs + the stud normal map (square studs in a tiling normal map on stud-cell UVs,
  never stud geometry), crisp edges, soft bevels only on round/hero bits (sharp box edges by default),
  no neon strips or random spheres.
- Organic creatures: the SDF sculpt (one blended body: signed-distance shapes, marching cubes,
  per-part decimate, then a PBR bake), not Organic tubes. The SDF tools are not in the public
  meshlab kit yet; until they are, build creatures in Blender or with the kit's `Organic.luau`.
- Seeded variants (`lib.seed`) are baked as `<Name>_s<seed>`; list them in VARIANTS in the bake tool.

## 2. Ship as REAL uploaded meshes (default for a whole game)
Runtime EditableMesh can't carry a full map: players' clients have a small EditableMesh memory
budget (and in a Studio playtest the server shares it), so parts show as magenta/blue checker or
white boxes. A city tycoon proved it three ways before switching. Ship uploaded meshes:
```
lune run meshlab/tools/export_parts <PREFIX> <game>/out/parts      # centred OBJ per part + manifest.json
blender -b -P meshlab/tools/pack_glb.py -- <game>/out/parts <game>/out/<Game>Meshes.glb
```
- Import the GLB in Studio (File > Import, or do it for the developer with computer-use): **Creator = the
  group that will publish the game** (`<your-group-id>`), Scale Unit Stud, Merge Meshes OFF. One import
  uploads every part (vertex colours and UVs survive).
- Turn the imported MeshParts into `ReplicatedStorage.MeshTemplates` (name `<Key>__<Part>`, CFrame origin,
  attribute `Center` from manifest.json, stud SurfaceAppearance on non-Glow parts), export them with
  `export_rbxm` to `<game>/out/MeshTemplates.rbxm`, and have make_place load that file.
- **The glTF import turns meshes 180 degrees about Y**: place parts at `CFrame.new(Center) * CFrame.Angles(0, math.pi, 0)`
  (do it in one shared mesh-cache module in your game, e.g. `src/server/MeshCache.luau`).
- `AssetService:CreateAssetAsync` (upload from code) said "not available yet" in the Studio this was
  tested in; don't rely on it.

## 3. Runtime EditableMesh (only for a few small models)
For a handful of props, the old route still works: `meshlab/tools/bake_meshdata` -> `ReplicatedStorage.MeshData`;
the server builds plain boxes (`MeshDataLoader.boxes`, tagged `ML`) and each client covers them with
shared-mesh clones (a small client script in your game). Never build EditableMesh on the server; never
ApplyMesh per part.

## 4. Settings and checks
- **Shading check:** `lune run meshlab/tools/probe_shading <Model>` prints average face brightness with and
  without the AO bake. Keep the loss around 10-15%. The bake caps darkening (`Shapes.AO_MAX`,
  `Shapes.SKY_MAX`) because Roblox lighting already shades sides; embedded detail boxes no longer
  black out the faces they sit in (fixed after dark artifacts showed up in a review).
- **Published games: Game Settings > Security > Allow Mesh & Image APIs** must be on (the developer turns
  it on).
- Edit-mode check: build the world from the live modules with an edit harness in your game (e.g.
  `tools/EditHarness.luau`, whose `H.cover()` draws the meshes over the boxes like a client),
  12+ screenshots from player height, then clean up (everything Archivable = false).
- Triangle limits: 20k triangles / 60k vertices per part; split into `part()`s.
- **Client memory budget:** players' EditableMesh memory is small. Over it, the client logs "Failed to create
  empty EditableMesh ... memory budget limits" and parts show as magenta/blue checker boxes. The bake welds
  shared data and the client builds models on demand; keep a whole game's meshes around 40k triangles
  (`lune run meshlab/tools/count_mesh <PREFIX>`), and ask the developer to playtest after adding many models.
