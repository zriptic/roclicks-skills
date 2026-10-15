# meshlab starter kit

Stud-style Roblox models written as Luau code. A model is a function that builds an
EditableMesh; under Lune it runs on a stand-in that writes an .obj, Blender renders it lit
like Studio, and an AI agent (or you) looks at the render and fixes the code. The same model
file runs unchanged on a real EditableMesh in Studio.

Full guide with pictures: https://roclicks.gg/resources/tricks/stud-models-with-lune

## Needs
- Lune (`aftman add lune-org/lune` or `rokit add lune-org/lune`)
- Blender 4.x on your PATH as `blender`
- Python 3 (for the optional tools)

## Try it
Run from the folder that CONTAINS `meshlab/`:

    lune run meshlab/run Barrel
    blender -b -P meshlab/render.py -- meshlab/out/Barrel.obj meshlab/out/Barrel.png hero 1.4

Open `meshlab/out/Barrel.png`. Views: hero, front, straight, side, rear; the last number is
camera distance. Seeded models take a seed: `lune run meshlab/run TreeBlob 3`.

## What's here
- `EditableMeshShim.luau`: the EditableMesh stand-in (same method names) that saves .obj.
- `Shapes.luau`: box / bevelBox / lathe / tube / loft / grid with stud-cell UVs, plus the
  ambient-occlusion bake (`Shapes.beginBake` / `Shapes.finishBake`).
- `Props.luau`: small shared builders (cylinder, pallet, carton, lookAt, rng).
- `Voxel.luau`, `Organic.luau`: voxel shells and soft organic shapes.
- `run.luau`: runs `models/<Name>.luau`, writes `out/<Name>.obj` (and one .obj per part).
- `render.py`: headless Blender preview with the stud normal map, lit like Studio.
- `textures/stud_normal.png`: the tiling square-stud normal map (`tools/stud_normal.py` makes it).
- `StudioBuild.luau`, `MeshDataLoader.luau`: build the same models in Studio (live, or from baked data).
- `tools/`: bake to data modules, export per-part OBJs, pack a GLB for Studio import, count
  triangles, check that the AO bake isn't darkening too much.
- `models/`: worked examples, simplest first: Cone, Barrel, Bollard, Crate, Pallet, TreeBlob,
  Cabin (glowing windows drawn after the bake), Forklift (moving parts, paint variants).

`BRIEF.md` is the brief to hand an AI agent before it models anything.

MIT licensed (see LICENSE): use and change it in your own games, free or paid.
