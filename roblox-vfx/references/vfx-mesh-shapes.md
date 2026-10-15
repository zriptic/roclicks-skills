# VFX mesh shapes

Load this with `vfx-design.md` and `vfx-craft.md` for mesh effects, shapes that
grow, spin and fade (a crescent slash, a shockwave ring, a swirl, a dome, a
ground wave), and for making those shapes.

**Two ways to make a shape:**
- **In Studio, with `Shapes`** (`ReplicatedStorage.VFX.Shapes`, the default):
  EditableMesh recipes ported from Roqer's Blender helpers. No Blender, no
  mesh upload, no moderation. Templates hold invisible *shape spots* that
  are baked into MeshParts at runtime, because EditableMesh content is not
  saved with the place.
- **In Blender** (`SK/scripts/vfxblender.py`, through the `blender` MCP),
  exported as a GLB, for shapes that need modifiers, sculpting or geometry
  nodes. Getting a mesh into Roblox is the hard part: there is no mesh
  upload in this setup, so prefer `Shapes` (or `Shapes.define` a new recipe)
  unless the developer imports the GLB by hand.

Effects are particles first (`SK/LESSONS.md`): a mesh shape is one layer of
an effect (a crescent, a shockwave), never a cluster of 3D balls standing in
for smoke or fire.

## Mesh effects in Studio

- **Mesh effects** are tweened shapes: a crescent slash, a shockwave ring, a
  twisting swirl, a sphere shell. Strong battleground-style games are built
  on them.
  - Build one as a Model with `Start` and `End` parts. The emit module moves
    `Start` to `End`.
  - **How the studied artists tween them** *(measured)*:
    - ease out (cubic) over 0.2-1 s;
    - a shockwave flattens (height x0.1-0.3) while it widens (x2-7) and spins
      120-170°;
    - a swirl stretches upward as it narrows.
  - **How they surface them** *(measured)*:
    - Faint `Neon` that fades out: starting `Transparency` 0.9-0.96 for white
      wind swirls, or 0 for a coloured one.
    - Black `Neon` swirls as dark accents.
    - A `SpecialMesh` (FileMesh) on an invisible part, with a Decal whose
      `Color3` is above 1 so it blooms, fading the Decal. `Build` passes
      colour components through unclamped (`"Color3": [4, 6, 8]`).
  - Use `Material = "Neon"` for a glowing shape, or `"ForceField"` with a
    texture for a shimmering, edge-lit shell. ForceField's animation speed
    cannot be controlled, so it suits a shield or aura, not a timed wipe.
  - A one-sided card mesh (a slash) needs `DoubleSided = true` to show from
    behind. `Shapes` builds both sides into the mesh, so its parts need
    nothing.
  - Under vertex colours, keep the part's `Color` white, because `Color`
    multiplies them.
  - A MeshPart's texture cannot scroll (`TextureID` has no offset) and
    ignores alpha (checked in Studio: nothing shows through). Animate the
    mesh's size, rotation and `Transparency` instead, or put a scrolling Beam
    alongside.
  - Set `RenderFidelity = Precise` on thin curved shapes. Automatic level of
    detail turns a crescent into a straight-sided wedge at distance.
  - For a texture that fades, put a `Decal` on the card's face and set the
    part's `Transparency` to 1. The emit module fades each Decal on `Start`
    toward the same-named Decal on `End`.
    - On a MeshPart, a Decal is projected across the part's box face and
      ignores UVs, so draw its texture for that projection.
    - On a part with a FileMesh `SpecialMesh`, the studied artists' Decals
      follow the mesh's surface. *(measured; not checked here)*
  - **Verified crescent slash** (by Roqer): two crescents (`Arc`).
    - A white `Neon` core goes from `Transparency` 0.05 to 1 over 0.2 s.
    - A larger blue `Neon` glow goes from 0.55 to 1 over 0.32 s.
    - Each grows from about 0.8 to 1.2 times its size with `Spin` 50 and
      `Quart` `Out`, and sparks come off the edge.
  - Make the shapes with `Shapes` recipes: `Arc` (crescent), `Ring`
    (shockwave or blast wall), `TornRing` (a jagged shockwave), `Cone`,
    `Swirl` (tornado, aura), `Shell` (barrier, dome), or your own with
    `Shapes.define` (see "Shapes for mesh effects" below). Each has UVs laid
    out along its sweep. A flat Neon cylinder part also works as a plain
    ground wave.
- **Shells, domes and columns:** a large mesh that is half transparent across
  its whole surface reads as tinted plastic and covers the screen. That holds
  for a blast dome, a shockwave sphere or a light column; below a
  `Transparency` of about 0.75 it looks solid against a bright sky.
  - Keep a big shell faint (0.85-0.96, as the studied wind swirls start).
  - Or give it a texture (a Decal on a FileMesh) that puts shape on its
    surface: streaks, a broken edge.
  - Let particles and a flash carry the brightness.

## Example: a ground wave

Ground wave, a mesh effect from a flat neon cylinder, timed to the hit (replace
both parts with a Blender ring mesh for a real shockwave, which can also take
`Spin`):

```json
[
  { "op": "create", "id": "wave", "className": "Model", "name": "GroundWave",
    "attributes": { "Duration": 0.35, "Easing": "Cubic", "EasingDirection": "Out", "EmitDelay": 0.16 } },
  { "op": "create", "className": "Part", "name": "Start", "parent": "$wave",
    "properties": { "Shape": "Cylinder", "Size": [0.1, 2, 2], "Material": "Neon",
      "Color": [1, 0.75, 0.4], "Transparency": 0.55, "Anchored": true, "CanCollide": false },
    "rotation": [0, 0, 90] },
  { "op": "create", "className": "Part", "name": "End", "parent": "$wave",
    "properties": { "Shape": "Cylinder", "Size": [0.05, 20, 20], "Material": "Neon",
      "Color": [1, 0.45, 0.15], "Transparency": 1, "Anchored": true, "CanCollide": false },
    "rotation": [0, 0, 90] }
]
```

## Shapes for mesh effects

**What every shape has in common:**
- It is one sheet with both sides built in, so it shows from behind.
- Its UVs run the same way: U along the sweep (0 at the start, 1 at the end),
  V across it (0 inside or at the bottom, 1 outside or at the top). In
  Roblox, `TextureID` ignores alpha (see below), so the shape itself, the
  part's `Transparency` and a Neon colour do most of the work.
- It is built around the origin in Roblox space: forward is -Z, up is +Y.
- Sizes are in studs. Params are JSON (camelCase).

**The recipes** (`VFXShape` name, then `VFXParams` keys with defaults):
- **`Arc`** `{radius=6, width=1.5, sweep=160, segments=32, taper=true}`: a
  flat crescent for a slash, sweeping `sweep` degrees centred on forward,
  from radius - width out to radius. With `taper` it is widest in the middle
  and pointed at both ends. Roll the part for a diagonal swing.
- **`Ring`** `{radius=5, width=0.5, height=0, topRadius=radius, segments=48}`:
  - with `height` 0, a flat band on the ground: a shockwave;
  - with a height, a wall from `radius` at the bottom to `topRadius` at the
    top. A flared top makes a blast wave.
- **`TornRing`** `{radius=4, width=1.5, spikes=24, seed=4, segments=96}`: a
  shockwave whose outer edge is torn into uneven spikes.
- **`Cone`** `{radius=2, height=4, tipRadius=0, segments=32}`: an open cone
  from its base at the origin up to its tip. Point it with the part's
  orientation, for example along the LookVector for a muzzle blast.
- **`Swirl`** `{radius=3, height=8, width=1.5, turns=1.5, topRadius=radius, segments=96}`:
  a ribbon `width` tall, spiralling up `turns` times to `height`, widening to
  `topRadius`. A tornado, an aura or a charge-up.
- **`Shell`** `{radius=4, segments=32, rings=16, dome=false}`: a sphere, or a
  dome standing on the ground. A barrier or a blast bubble.
- **Anything else:** `Shapes.define("Petal", function(p) return
  Shapes.strip(columns, rows, function(u, v) return Vector3.new(...) end) end)`.
  `point(u, v)` returns each grid corner for u and v from 0 to 1. Vary the
  radius with `u` for a jagged or wobbling ring, offset a strip sideways
  with noise for lightning, taper a petal with `v`. A custom recipe must be
  defined (in a module both edit-mode checks and the client require) before
  anything bakes it.

**A shape spot** in a template is an ordinary invisible Part:

```json
[
  { "op": "create", "id": "slash", "className": "Model", "name": "SlashArc",
    "attributes": { "Duration": 0.2, "Easing": "Quart", "EasingDirection": "Out", "Spin": 50 } },
  { "op": "create", "className": "Part", "name": "Start", "parent": "$slash",
    "properties": { "Material": "Neon", "Color": [1, 1, 1], "Transparency": 0.05, "Size": [0.2, 0.2, 0.2] },
    "attributes": { "VFXShape": "Arc", "VFXParams": "{\"radius\":6,\"width\":1.5,\"sweep\":150}", "VFXScale": 0.8 } },
  { "op": "create", "className": "Part", "name": "End", "parent": "$slash",
    "properties": { "Material": "Neon", "Color": [0.6, 0.8, 1], "Transparency": 1, "Size": [0.2, 0.2, 0.2] },
    "attributes": { "VFXShape": "Arc", "VFXParams": "{\"radius\":6,\"width\":1.5,\"sweep\":150}", "VFXScale": 1.2 } }
]
```

`Shapes.bake` swaps a spot for a MeshPart of the shape (size times
`VFXScale`), keeping its name, CFrame (as the shape's origin), colour,
material, transparency, attributes and children (Decals). `Start` and `End`
of one Model can be spots: the emit module then tweens between the baked
sizes.

**Playing:** `VFX.play(Shapes.prepare(template), cframe)`. `prepare` bakes a
copy once per template and caches it; call it on the client at load so the
first play does not wait. `Capture.hold` calls it for you. After editing a
template in Studio, `Shapes.clear()` (or the cache keeps the old copy).
Published games need **Allow Mesh & Image APIs** on (Game Settings >
Security), or `CreateEditableMesh` fails on clients.

**Facts about meshes in Roblox** (checked in Studio by Roqer, on imported
meshes; they hold for baked ones too):
- Set `RenderFidelity = Precise` (`Shapes` does). With Automatic, Roblox
  simplifies a thin curved card at distance until a crescent reads as a
  straight-sided wedge.
- `TextureID` ignores alpha on a MeshPart: the texture's colour covers the
  whole surface, and nothing shows through. Do not put a fading texture
  there.
- What does fade:
  - **The part's own `Transparency`.** A `Neon` card fading from about 0 to 1
    is the reliable mesh effect.
  - **A `Decal` on the card's face** (`Top`, plus `Bottom` to show from
    below), on a part with `Transparency = 1`. It fades cleanly and takes
    `Color3` and `Transparency`, but it is projected across the part's box
    face and ignores the UVs. Its texture must be drawn for that flat
    projection, not along the sweep.
  - A `SurfaceAppearance` with `AlphaMode = Transparency` follows the UVs,
    but rendered dithered in Studio, and scripts cannot change its maps at
    runtime.

**In Blender instead** (`vfxblender.py`, loaded as in
`vfx-rendered-flipbooks.md`): `vfx.vfx_arc(name, radius, width, sweep=160,
segments=32, taper=True)`, `vfx_ring(name, radius, width=0.5, height=0,
top_radius=None)`, `vfx_cone`, `vfx_swirl`, `vfx_shell`, and
`vfx_surface(name, point, columns, rows)` build the same shapes in Blender
space (Z up, -Y forward), then `vfx.export_glb("slash-effect.glb")`. Put
several shapes in one export; each arrives as its own MeshPart, 0.001 studs
thick, pivoted on its box centre. Set `DoubleSided`, `RenderFidelity`,
`Anchored`, and turn off `CanCollide`, `CanQuery`, `CanTouch` and
`CastShadow` after import.
