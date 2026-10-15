# Headless preview of a meshlab OBJ, lit to look like Roblox Studio's default place:
#   blender -b -P meshlab/render.py -- meshlab/out/Pumpkin.obj meshlab/out/Pumpkin.png [view]
# Vertex colours + the tiling square-stud normal map on the UVs (the AnimalPack look),
# backfaces culled so bad winding shows as holes.
#
# Studio look (default Baseplate place, Future lighting, ClockTime ~14:30):
#   * one warm sun from high up, crisp shadows (Future lighting / low ShadowSoftness)
#   * flat grey-blue ambient fill from every side (Ambient + OutdoorAmbient), not an HDRI
#   * blue gradient sky behind, which does not light the model (Roblox's sky box doesn't)
#   * Plastic: mostly diffuse, low specular
#   * "Standard" colour transform: no filmic curve, so colours stay as saturated as Roblox
#   * the default Baseplate: dark grey with the 4-stud checker grid overlay
import bpy, sys, math, os
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[:2]
view = argv[2] if len(argv) > 2 else "back"  # "front" = look at Roblox's front (-Z) face
BLEND = src.endswith(".blend")  # a baked PBR .blend (tools/bake_pbr.py): keep its materials
if BLEND:
    bpy.ops.wm.open_mainfile(filepath=src)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
else:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.wm.obj_import(filepath=src, forward_axis="NEGATIVE_Z", up_axis="Y")
    obj = bpy.context.selected_objects[0]

def srgb(r, g, b):
    def lin(c):
        c /= 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (lin(r), lin(g), lin(b), 1)

# --- model material: Roblox Plastic ---
mat = bpy.data.materials.new("vc")
mat.use_nodes = True
mat.use_backface_culling = True
nt = mat.node_tree
bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
attr = nt.nodes.new("ShaderNodeVertexColor")
nt.links.new(attr.outputs[0], bsdf.inputs[0])
bsdf.inputs["Roughness"].default_value = 0.68
for name in ("Specular IOR Level", "Specular"):
    if name in bsdf.inputs:
        bsdf.inputs[name].default_value = 0.22
        break
NOSTUD = os.environ.get("MESHLAB_NOSTUD") == "1"  # organic (non-stud) models: no stud normal map
LIGHT = os.environ.get("MESHLAB_LIGHT", "studio")   # "dark": moody horror preview
tex = nt.nodes.new("ShaderNodeTexImage")
tex.image = bpy.data.images.load(os.path.join(os.path.dirname(os.path.abspath(__file__)), "textures", "stud_normal.png"))
tex.image.colorspace_settings.name = "Non-Color"
tex.interpolation = "Linear"
nmap = nt.nodes.new("ShaderNodeNormalMap")
nt.links.new(tex.outputs[0], nmap.inputs[1])
if not NOSTUD:
    nt.links.new(nmap.outputs[0], bsdf.inputs["Normal"])
if not BLEND:
    obj.data.materials.append(mat)

pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
center, size = (lo + hi) / 2, (hi - lo).length

# --- the default Baseplate: dark grey plastic with the 4-stud checker overlay ---
bpy.ops.mesh.primitive_plane_add(size=max(size * 8, 40.0), location=(center.x, center.y, lo.z))
ground = bpy.context.active_object
gmat = bpy.data.materials.new("baseplate")
gmat.use_nodes = True
gn = gmat.node_tree
gb = next(n for n in gn.nodes if n.type == "BSDF_PRINCIPLED")
gb.inputs["Roughness"].default_value = 0.8
coord = gn.nodes.new("ShaderNodeTexCoord")
checker = gn.nodes.new("ShaderNodeTexChecker")
checker.inputs["Scale"].default_value = 1.0 / 8.0 * 2  # 4-stud squares (1 Blender unit = 1 stud)
checker.inputs["Color1"].default_value = srgb(99, 99, 103)
checker.inputs["Color2"].default_value = srgb(112, 112, 117)
gn.links.new(coord.outputs["Object"], checker.inputs["Vector"])
gn.links.new(checker.outputs["Color"], gb.inputs[0])
ground.data.materials.append(gmat)

scene = bpy.context.scene
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
cam.data.lens = 50
# OBJ -Z (Roblox front) lands on Blender +Y with these import axes.
direction = {"front": Vector((0.45, 1.3, 0.3)), "straight": Vector((0.0, 1.0, 0.12)), "hero": Vector((1.1, 1.0, 0.75)), "rear": Vector((-1.0, -1.1, 0.7)), "side": Vector((1.0, 0.08, 0.22)), "left": Vector((-1.0, 0.25, 0.15)), "left34": Vector((-1.0, 0.7, 0.35))}.get(view, Vector((1.0, -1.3, 0.8)))
zoom = float(argv[3]) if len(argv) > 3 else 1.6
cam.location = center + direction.normalized() * size * zoom
cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.camera = cam

# --- sun: warm, high afternoon sun, crisp shadows ---
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.2
sun.data.color = srgb(255, 246, 232)[:3]
sun.data.angle = math.radians(2.5)
to_sun = Vector((0.55, 0.45, 1.0)).normalized()
sun.rotation_euler = (-to_sun).to_track_quat("-Z", "Y").to_euler()
scene.collection.objects.link(sun)

# --- world: sky gradient for the camera, flat ambient for the lighting ---
world = bpy.data.worlds.new("w")
world.use_nodes = True
wn = world.node_tree
bg_out = wn.nodes["World Output"]
for n in list(wn.nodes):
    if n.type != "OUTPUT_WORLD":
        wn.nodes.remove(n)
lp = wn.nodes.new("ShaderNodeLightPath")
wc = wn.nodes.new("ShaderNodeTexCoord")
sep = wn.nodes.new("ShaderNodeSeparateXYZ")
ramp = wn.nodes.new("ShaderNodeValToRGB")
ramp.color_ramp.elements[0].position = 0.0
ramp.color_ramp.elements[0].color = srgb(196, 222, 245)  # horizon
ramp.color_ramp.elements[1].position = 0.55
ramp.color_ramp.elements[1].color = srgb(86, 156, 230)   # zenith
sky = wn.nodes.new("ShaderNodeBackground")
amb = wn.nodes.new("ShaderNodeBackground")
amb.inputs[0].default_value = srgb(150, 156, 170)       # Ambient/OutdoorAmbient grey-blue
amb.inputs[1].default_value = 0.85
mix = wn.nodes.new("ShaderNodeMixShader")
wn.links.new(wc.outputs["Generated"], sep.inputs[0])
wn.links.new(sep.outputs["Z"], ramp.inputs[0])
wn.links.new(ramp.outputs[0], sky.inputs[0])
wn.links.new(lp.outputs["Is Camera Ray"], mix.inputs[0])
wn.links.new(amb.outputs[0], mix.inputs[1])
wn.links.new(sky.outputs[0], mix.inputs[2])
wn.links.new(mix.outputs[0], bg_out.inputs[0])
scene.world = world

if LIGHT == "dark":
    # night scene like a horror showcase: dim warm key, faint cold fill, black sky
    sun.data.energy = 0.9
    sun.data.color = srgb(255, 214, 160)[:3]
    amb.inputs[1].default_value = 0.18
    ramp.color_ramp.elements[0].color = srgb(10, 10, 14)
    ramp.color_ramp.elements[1].color = srgb(2, 2, 4)
    spot = bpy.data.objects.new("spot", bpy.data.lights.new("spot", "SPOT"))
    spot.data.energy = 900 * (size / 10) ** 2
    spot.data.color = srgb(255, 200, 140)[:3]
    spot.data.spot_size = math.radians(60)
    spot.location = center + Vector((size * 0.5, size * 0.6, size * 0.7))
    spot.rotation_euler = (center - spot.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(spot)
    checker.inputs["Color1"].default_value = srgb(60, 50, 40)
    checker.inputs["Color2"].default_value = srgb(62, 52, 42)

for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
    try:
        scene.render.engine = eng
        break
    except TypeError:
        pass
# Roblox has no filmic tone curve: keep colours punchy.
try:
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
except TypeError:
    pass
scene.render.resolution_x = scene.render.resolution_y = 1024
scene.render.filepath = dst
bpy.ops.render.render(write_still=True)
print("rendered", dst)
