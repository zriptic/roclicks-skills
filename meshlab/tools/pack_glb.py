# Pack exported meshlab parts (tools/export_parts.luau) into ONE .glb for Roblox Studio's
# File > Import 3D, so every part becomes a real uploaded mesh asset in one go.
#   blender -b -P meshlab/tools/pack_glb.py -- <partsDir> <out.glb>
# Each OBJ becomes one object named after the file ("TreeBlob_s2__Body"), keeping its vertex colours
# (COLOR_0), stud UVs and normals. Objects are laid out on a grid so they don't overlap in the
# importer preview; the game re-places them from the manifest anyway.
import bpy, sys, os, math

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)

files = sorted(f for f in os.listdir(src) if f.endswith(".obj"))
cols = math.ceil(math.sqrt(len(files)))
for i, f in enumerate(files):
    bpy.ops.object.select_all(action="DESELECT")
    # same axes as render.py: the OBJ is Roblox space (Y up, -Z front)
    bpy.ops.wm.obj_import(filepath=os.path.join(src, f), forward_axis="NEGATIVE_Z", up_axis="Y")
    obj = bpy.context.selected_objects[0]
    name = f[:-4]
    obj.name = name
    obj.data.name = name
    obj.location = ((i % cols) * 12.0, -(i // cols) * 12.0, 0.0)
    # a plain material that uses the vertex colours, so viewers show them too
    mat = bpy.data.materials.new(name + "_mat")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    attr = nodes.new("ShaderNodeVertexColor")
    if obj.data.color_attributes:
        attr.layer_name = obj.data.color_attributes[0].name
    mat.node_tree.links.new(attr.outputs[0], bsdf.inputs[0])
    bsdf.inputs["Roughness"].default_value = 0.8
    obj.data.materials.clear()
    obj.data.materials.append(mat)

kw = dict(filepath=out, export_format="GLB", export_yup=True, export_normals=True, export_texcoords=True)
props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
if "export_vertex_color" in props:
    kw["export_vertex_color"] = "ACTIVE"
elif "export_colors" in props:
    kw["export_colors"] = True
if "export_all_vertex_colors" in props:
    kw["export_all_vertex_colors"] = True
bpy.ops.export_scene.gltf(**kw)
print("wrote", out, "with", len(files), "objects")
