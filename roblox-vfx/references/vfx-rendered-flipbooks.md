# Rendered flipbooks

Load this with `vfx-textures.md` when a flipbook should be rendered from a 3D
scene rather than drawn: a simulation, a lit volume, shaded debris. A
rendered sheet is checked, previewed and uploaded the same way as a drawn one
(`vfxtex.py check / review / preview`).

This runs in the developer's live Blender through the `blender` MCP
(`execute_blender_code`). Start with `get_addon_status`, then load the
helpers once per script:

```python
import os, types
vfx = types.ModuleType("vfx")
exec(open("<skills-dir>/roblox-vfx/scripts/vfxblender.py").read(), vfx.__dict__)   # SK/scripts; use the real path
vfx.OUTPUT_DIR = "/abs/path/to/<game>/vfx/<effect>/out"
```

It is the user's own Blender session, not a background job: build in a new
scene (`bpy.data.scenes.new`, then set `bpy.context.window.scene`) so their
work is untouched, and say so. Use `look` to see the scene before rendering.

## Rendering the scene

`vfx.flipbook(name, grid=4, mode="alpha", start=None, end=None, loop=False, padding=4)`
renders the scene's animation through `scene.camera` into
`<name>.flipbook.png`. Use it when a 3D look is the point: a simulation, a
lit volume, shaded debris, a realistic fireball. It handles the size, grid,
padding, frame sampling, colour management and packing. Use any materials,
geometry nodes, simulations, compositor passes or lighting; the helper
renders whatever the scene shows.

- **Frames:** the frames from `start` to `end` (the scene's range by default)
  are sampled evenly to fill every cell, because Roblox plays every cell. With
  fewer frames than cells, some frames are held for two cells; the helper
  prints the repeats.
- **Mode:** `"alpha"` renders on a transparent film. `"additive"` renders on
  black for `LightEmission = 1`.
- **Framing:** frame the camera so the subject stays inside the view on every
  frame, at the size you want in the cell. An orthographic camera looking
  at the effect is simplest.
- **Speed:** colour uses the Standard view transform, so glows stay bright.
  - Use Eevee for emission and Workbench for flat shapes; Eevee measured
    0.06 s a frame for the example below.
  - Cycles measured 0.28 s a frame at 32 samples for a simple sphere, and
    volumes take far longer. The note JSON beside the sheet records each
    frame's render time.

```python
import bpy, math

scene = bpy.data.scenes.new("VFXFlipbook")
bpy.context.window.scene = scene
scene.render.engine = "BLENDER_EEVEE"
scene.frame_start, scene.frame_end = 1, 16

camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
scene.collection.objects.link(camera)
camera.data.type = "ORTHO"
camera.data.ortho_scale = 4.0
camera.location = (0, -10, 0)
camera.rotation_euler = (math.radians(90), 0, 0)
scene.camera = camera

bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, segments=24, ring_count=12)
ball = bpy.context.active_object
material = bpy.data.materials.new("Glow")
material.use_nodes = True
nodes = material.node_tree.nodes
nodes.clear()
emission = nodes.new("ShaderNodeEmission")
output = nodes.new("ShaderNodeOutputMaterial")
material.node_tree.links.new(emission.outputs[0], output.inputs[0])
emission.inputs["Color"].default_value = (1.0, 0.55, 0.15, 1.0)
ball.data.materials.append(material)

# A burst: grows fast, then fades out while it keeps spreading.
for frame, scale, strength in ((1, 0.6, 6.0), (6, 3.0, 4.0), (16, 3.8, 0.0)):
    ball.scale = (scale, scale, scale)
    ball.keyframe_insert("scale", frame=frame)
    emission.inputs["Strength"].default_value = strength
    emission.inputs["Strength"].keyframe_insert("default_value", frame=frame)

vfx.flipbook("GlowBurst", grid=4, mode="additive")
```
