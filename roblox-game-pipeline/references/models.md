# Models (phase 3)

**Default route: meshlab for everything** (`references/meshlab.md`). The Meshy
and Blender routes below are only for when the developer asks for them or an
organic hero model needs them. (Superseded: "first ask whether Parts can do
it".)

## Routes
| Need | Route |
|---|---|
| Creature, character, weapon, organic prop | **Meshy** (MCP) from a concept image. Quote credits and wait for a yes; image-to-3d, then fix the texture (below). |
| Precise mechanical or hard-surface prop | **Blender** (blender MCP): place parts by their two ends, flat-shade, use vertex colours, keep each object under 20k triangles |
| Effect shapes (crescent, ring, swirl) | `roblox-vfx` `templates/Shapes.luau` (EditableMesh, no upload) |
| Procedural props from code | EditableMesh recipes (MeshKit pattern: a shared module in your project, e.g. `src/MeshKit.luau`, that builds meshes from recipes) |

## Meshy rules
- **Prompt for "chunky toy plastic, flat colours, side view, pure white
  background"** so the model sits beside studs and the concept image can be
  projected.
- **Meshy textures smear across UV charts.** Fix them by planar-projecting the
  cleaned concept image (two small scripts: one cleans the concept, one
  projects it): reduce it to a palette of up to 7 colours, then project it,
  fitting the projection box to the model's silhouette. That gets 82-94%
  silhouette overlap.
- `image_to_image` is always square. For 16:9 use `text_to_image`.

## Blender rules (Roblox)
- **Units and orientation:** 1 unit = 1 stud. The model's front faces Blender
  -Y, so a point at Blender (x, y, z) lands at Roblox (-x, z, y). Stand it on
  Z 0.
- **Colour** with vertex colours or a packed image. A flat material colour
  arrives white.
- **Export** with `export_apply=True` (or modifiers are lost) and
  `use_active_scene=True` (or every scene in the file is exported).
- **Joints:** plan them first, measure the gap between parts, and overlap them
  rather than just touching.

## Getting it into Roblox
- An **upload** needs an Open Cloud key with Assets write. Otherwise **File >
  Import 3D** by hand in Studio.
- **No upload at all:** convert the GLB to Luau mesh data and rebuild it with
  EditableMesh at runtime. The data survives in the place; the built mesh does
  not.
- After it's in: set the pivot, `CollisionFidelity` Box or Hull (never Precise
  on detail), `CanCollide` off for visuals with a simple invisible collider
  part, `RenderFidelity` Precise on thin curves. Screenshot it from the
  distance players will see it.
