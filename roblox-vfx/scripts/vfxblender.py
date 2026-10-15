"""vfxblender: Blender-side VFX helpers, ported from vfxtex (roblox-animation-vfx,
MIT, TabooHarmony; see LICENSE-ROQER-SKILLS.txt).

Load it inside Blender through the blender MCP's execute_blender_code:

    import os, types
    vfx = types.ModuleType("vfx")
    exec(open("<skills-dir>/roblox-vfx/scripts/vfxblender.py").read(), vfx.__dict__)   # real path here
    vfx.OUTPUT_DIR = "/abs/path/to/project/vfx/out"
    # rendered flipbook: build a scene + camera, then
    vfx.flipbook("GlowBurst", grid=4, mode="additive")
    # mesh shapes (prefer templates/Shapes.luau in Studio; these are for a GLB)
    vfx.vfx_arc("Slash", radius=6, width=1.5, sweep=150)
    vfx.export_glb("slash-effect.glb")

Units are studs. Blender is Z-up with -Y as Roblox's forward; glTF export
converts to Roblox's Y-up.
"""
import os
import bpy, bmesh
from mathutils import Vector

OUTPUT_DIR = os.path.join(os.path.expanduser("~"), "vfx_out")


def _out(name):
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    return os.path.join(OUTPUT_DIR, name)


def export_glb(filename, selected_only=False):
    """Export the visible scene (or the selection) as a GLB in OUTPUT_DIR."""
    path = _out(filename)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True,
                              use_visible=not selected_only, use_selection=selected_only)
    return path

_COLOR_LAYER = "Col"


def _vector(value, name):
    try:
        vector = Vector(value)
    except (TypeError, ValueError):
        raise ValueError(f"{name} must be three numbers, got {value!r}") from None
    if len(vector) != 3:
        raise ValueError(f"{name} must be three numbers, got {value!r}")
    return vector


def _positive(value, name):
    if not isinstance(value, (int, float)) or value <= 0:
        raise ValueError(f"{name} must be a positive number of studs, got {value!r}")
    return float(value)


def paint(obj, rgba):
    """Colour every corner of an object's mesh; the colour travels in the GLB as vertex colour."""
    if len(rgba) == 3:
        rgba = (*rgba, 1.0)
    mesh = obj.data
    layer = mesh.color_attributes.get(_COLOR_LAYER) or mesh.color_attributes.new(_COLOR_LAYER, "BYTE_COLOR", "CORNER")
    for corner in layer.data:
        corner.color = rgba
    mesh.color_attributes.active_color = layer
    return obj


def _object(name, bm, rgba):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    if rgba is not None:
        paint(obj, rgba)
    return obj


def _frame(start, end, across):
    """Unit vectors: along start to end, the given width direction made perpendicular, and the third."""
    along = end - start
    if along.length < 1e-6:
        raise ValueError("start and end are the same point")
    along = along.normalized()
    side = across - along * across.dot(along)
    if side.length < 1e-6:
        side = Vector((1, 0, 0)) - along * along.x
        if side.length < 1e-6:
            side = Vector((0, 1, 0)) - along * along.y
    side = side.normalized()
    return along, side, along.cross(side).normalized()



_FLIPBOOK_SIDE = 1024
_FLIPBOOK_GRIDS = (2, 4, 8)
# A sheet larger than this is not attached to the result, so a half-size copy is written to look at.
_FLIPBOOK_PREVIEW_BYTES = 1800 * 1024


def _write_png(path, rgba):
    """Write rows of 8-bit RGBA, top row first, as a PNG."""
    import struct, zlib
    height, width = rgba.shape[0], rgba.shape[1]

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    import numpy
    rows = numpy.zeros((height, width * 4 + 1), dtype=numpy.uint8)
    rows[:, 1:] = rgba.reshape(height, width * 4)
    with open(path, "wb") as handle:
        handle.write(b"\x89PNG\r\n\x1a\n")
        handle.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)))
        handle.write(chunk(b"IDAT", zlib.compress(rows.tobytes(), 9)))
        handle.write(chunk(b"IEND", b""))


def flipbook(name, grid=4, mode="alpha", start=None, end=None, loop=False, padding=4):
    """Render the scene's animation through its camera into one particle flipbook sheet.

    The sheet is 1024 x 1024, the size seen playing as a flipbook in Roblox. grid is 2, 4 or
    8: 4, 16 or 64 frames. Frames from start to end (the scene's own by default) are sampled
    evenly to fill every cell, because Roblox plays every cell; a shorter animation holds some
    frames for two cells. The scene is rendered as it is, so any material, simulation or
    compositor setup shows in the sheet. mode "alpha" renders on a
    transparent film, for smoke, dust and anything that darkens (LightEmission 0); "additive"
    renders on black, for fire, energy and glows (LightEmission 1). Each frame is rendered
    padding pixels inside its cell, so frames cannot run into each other. loop says the last
    frame leads back into the first, as for a burning fire; leave it False for a burst that plays
    once. The scene's render engine is used: Eevee or Workbench render a 64-frame sheet in
    seconds, Cycles can take minutes. Colour is rendered with the Standard view transform, so
    glows stay bright. Writes <name>.flipbook.png to OUTPUT_DIR, which vfxtex.py check reads.
    """
    import json, os, time, numpy
    if not isinstance(name, str) or not name or any(c in name for c in '/\\:*?"<>|.'):
        raise ValueError(f"name must be the sheet's name, usable as a file name without dots, got {name!r}")
    if grid not in _FLIPBOOK_GRIDS:
        raise ValueError(f"grid must be 2, 4 or 8 (Roblox's Grid2x2, Grid4x4 and Grid8x8), got {grid!r}")
    if mode not in ("alpha", "additive"):
        raise ValueError(f'mode must be "alpha" (transparent film, LightEmission 0) or "additive" (black background, LightEmission 1), got {mode!r}')
    cell = _FLIPBOOK_SIDE // grid
    if not isinstance(padding, int) or padding < 0 or padding > cell // 8:
        raise ValueError(f"padding must be a whole number of pixels from 0 to {cell // 8} for a {grid} x {grid} grid, got {padding!r}")
    scene = bpy.context.scene
    if scene.camera is None:
        raise ValueError("the scene has no camera; add one and set scene.camera, framed so the whole effect stays in view")
    start = scene.frame_start if start is None else int(start)
    end = scene.frame_end if end is None else int(end)
    cells = grid * grid
    span = end - start + (0 if loop else 1)
    if end <= start:
        raise ValueError(f"end ({end}) must be after start ({start})")
    if span < cells:
        print(f"vfx.flipbook: frames {start} to {end} give {span} distinct frames for {cells} cells, so some frames are held "
              f"for two cells; a longer animation or a smaller grid avoids the holds", flush=True)
    if loop:
        frames = [start + round((end - start) * i / cells) for i in range(cells)]
    else:
        frames = [start + round((end - start) * i / (cells - 1)) for i in range(cells)]

    render = scene.render
    view = scene.view_settings
    saved = {
        "resolution_x": render.resolution_x, "resolution_y": render.resolution_y,
        "resolution_percentage": render.resolution_percentage, "film_transparent": render.film_transparent,
        "filepath": render.filepath, "file_format": render.image_settings.file_format,
        "color_mode": render.image_settings.color_mode, "view_transform": view.view_transform,
        "look": view.look, "world": scene.world, "frame": scene.frame_current,
    }
    inner = cell - 2 * padding
    frames_dir = os.path.join(OUTPUT_DIR, "flipbook-frames", name)
    os.makedirs(frames_dir, exist_ok=True)
    seconds = []
    sheet = numpy.zeros((_FLIPBOOK_SIDE, _FLIPBOOK_SIDE, 4), dtype=numpy.uint8)
    if mode == "additive":
        sheet[:, :, 3] = 255
    black = None
    try:
        render.resolution_x = render.resolution_y = inner
        render.resolution_percentage = 100
        render.image_settings.file_format = "PNG"
        view.view_transform = "Standard"
        view.look = "None"
        if mode == "alpha":
            render.film_transparent = True
            render.image_settings.color_mode = "RGBA"
        else:
            render.film_transparent = False
            render.image_settings.color_mode = "RGB"
            black = bpy.data.worlds.new("VFXFlipbookBlack")
            black.color = (0.0, 0.0, 0.0)
            if black.node_tree is not None:
                for node in black.node_tree.nodes:
                    if node.type == "BACKGROUND":
                        node.inputs["Color"].default_value = (0.0, 0.0, 0.0, 1.0)
                        node.inputs["Strength"].default_value = 0.0
            scene.world = black
        for index, frame in enumerate(frames):
            scene.frame_set(frame)
            path = os.path.join(frames_dir, f"{index:02d}.png")
            render.filepath = path
            began = time.perf_counter()
            bpy.ops.render.render(write_still=True)
            seconds.append(round(time.perf_counter() - began, 3))
            image = bpy.data.images.load(path, check_existing=False)
            try:
                width, height = image.size
                if (width, height) != (inner, inner):
                    raise RuntimeError(f"frame {frame} rendered at {width} x {height}, not {inner} x {inner}")
                pixels = numpy.empty(width * height * 4, dtype=numpy.float32)
                image.pixels.foreach_get(pixels)
            finally:
                bpy.data.images.remove(image)
            # Blender keeps rows bottom first; the sheet is written top first.
            frame_rgba = numpy.flipud((numpy.clip(pixels, 0.0, 1.0) * 255.0 + 0.5).astype(numpy.uint8).reshape(height, width, 4))
            if mode == "additive":
                frame_rgba[:, :, 3] = 255
            row, column = divmod(index, grid)
            top, left = row * cell + padding, column * cell + padding
            sheet[top:top + inner, left:left + inner] = frame_rgba
    finally:
        render.resolution_x, render.resolution_y = saved["resolution_x"], saved["resolution_y"]
        render.resolution_percentage = saved["resolution_percentage"]
        render.film_transparent = saved["film_transparent"]
        render.filepath = saved["filepath"]
        render.image_settings.file_format = saved["file_format"]
        render.image_settings.color_mode = saved["color_mode"]
        view.view_transform, view.look = saved["view_transform"], saved["look"]
        scene.world = saved["world"]
        if black is not None:
            bpy.data.worlds.remove(black)
        scene.frame_set(saved["frame"])

    fps = render.fps / render.fps_base
    return _write_flipbook(name, sheet, {"name": name, "grid": grid, "mode": mode, "padding": padding, "loop": bool(loop),
                                         "fps": round(cells / ((frames[-1] - frames[0] + (frames[1] - frames[0] if loop else 0)) / fps), 3) if frames[-1] > frames[0] else None,
                                         "frames": frames, "engine": render.engine, "renderSeconds": seconds})


def _check_name(name):
    if not isinstance(name, str) or not name or any(c in name for c in '/\\:*?"<>|.'):
        raise ValueError(f"name must be usable as a file name without dots, got {name!r}")


def _write_flipbook(name, sheet, note):
    """Write a packed sheet and the note vfxtex.py check reads it against, plus a half-size copy when the sheet is too big to attach."""
    import json, os, numpy
    path = _out(name + ".flipbook.png")
    _write_png(path, sheet)
    if os.path.getsize(path) > _FLIPBOOK_PREVIEW_BYTES:
        half = sheet.reshape(_FLIPBOOK_SIDE // 2, 2, _FLIPBOOK_SIDE // 2, 2, 4).mean(axis=(1, 3))
        _write_png(_out(name + ".flipbook-preview.png"), (half + 0.5).astype(numpy.uint8))
    with open(_out(name + ".flipbook.json"), "w", encoding="utf-8") as handle:
        json.dump(note, handle)
    return path


# 2D texture drawing with numpy, for the hard-edged, stylised shapes most Roblox
# VFX textures are: a shape built from coordinates, broken up by noise, cut
# with a hard edge, and eaten away over the frames. Images are float arrays,
# row 0 at the top. tex_coords runs -1..1 with x to the right and y up.

_MAX_VFX_SEGMENTS = 256


def _segments(value, name, low):
    if not isinstance(value, int) or value < low or value > _MAX_VFX_SEGMENTS:
        raise ValueError(f"{name} must be a whole number from {low} to {_MAX_VFX_SEGMENTS}, got {value!r}")
    return value


def vfx_surface(name, point, columns=32, rows=1, rgba=None):
    """Any shape you can describe as a function: a sheet of columns x rows quads, where point(u, v)
    gives the position (three numbers, in studs) of each grid corner for u and v from 0 to 1, and
    the corner's UV is (u, v). Corners that land on the same spot are merged, so closed loops and
    poles need no special care. The named vfx_ shapes are built with it; use it for anything they
    do not cover: a jagged shockwave (vary the radius with u), a forked lightning card, petals, a
    wobbling wave, a spiked burst.
    """
    if not callable(point):
        raise ValueError("point must be a function point(u, v) returning (x, y, z) in studs")
    columns = _segments(columns, "columns", 1)
    rows = _segments(rows, "rows", 1)
    return _strip(name, columns, rows, lambda u, v: _vector(point(u, v), "point(u, v)"), rgba)


def _strip(name, columns, rows, point, rgba):
    """A grid of columns x rows quads at point(u, v), with UVs (u, v); u and v run 0 to 1."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    grid = [[bm.verts.new(point(c / columns, r / rows)) for r in range(rows + 1)] for c in range(columns + 1)]
    for c in range(columns):
        for r in range(rows):
            corners = [(c, r), (c + 1, r), (c + 1, r + 1), (c, r + 1)]
            face = bm.faces.new([grid[i][j] for i, j in corners])
            for loop, (i, j) in zip(face.loops, corners):
                loop[uv].uv = (i / columns, j / rows)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    obj = _object(name, bm, rgba)
    return obj


def _around(angle):
    """Unit direction at angle radians from Blender -Y (Roblox's forward), turning toward +X."""
    import math
    return Vector((math.sin(angle), -math.cos(angle), 0.0))


def vfx_arc(name, radius, width, sweep=160, segments=32, taper=True, rgba=None):
    """A flat crescent card for a slash, lying in the horizontal plane around the origin.

    It sweeps sweep degrees centred on forward (Blender -Y), from radius - width to radius.
    With taper the band is widest in the middle and comes to a point at both ends: a crescent.
    U runs along the sweep from its start (+X side) to its end (-X side), V from the inner edge
    to the outer. Roll or tilt the MeshPart in Studio for a diagonal swing, and set DoubleSided.
    """
    import math
    radius, width = _positive(radius, "radius"), _positive(width, "width")
    if width >= radius:
        raise ValueError(f"width ({width}) must be less than radius ({radius}): the band runs from radius - width to radius")
    if not isinstance(sweep, (int, float)) or not 10 <= sweep <= 350:
        raise ValueError(f"sweep must be 10 to 350 degrees, got {sweep!r}")
    segments = _segments(segments, "segments", 4)
    half = math.radians(sweep) / 2

    def point(u, v):
        across = math.sin(math.pi * u) if taper else 1.0
        inner = radius - width * max(across, 0.02)
        return _around(half - 2 * half * u) * (inner + (radius - inner) * v)

    return _strip(name, segments, 1 if not taper else 2, point, rgba)


def vfx_ring(name, radius, width=0.5, height=0.0, top_radius=None, segments=48, rgba=None):
    """A shockwave ring around the vertical axis.

    With height 0 it is a flat band on the ground from radius - width to radius. With a height
    it is a wall from radius at the bottom to top_radius (radius by default) at the top: flare
    the top outward for a blast wave. U runs once around, V across the band or up the wall.
    """
    import math
    radius = _positive(radius, "radius")
    segments = _segments(segments, "segments", 8)
    if not isinstance(height, (int, float)) or height < 0:
        raise ValueError(f"height must be 0 (a flat band) or a positive number of studs, got {height!r}")
    if height == 0:
        width = _positive(width, "width")
        if width >= radius:
            raise ValueError(f"width ({width}) must be less than radius ({radius})")
        return _strip(name, segments, 1, lambda u, v: _around(2 * math.pi * u) * (radius - width + width * v), rgba)
    top = radius if top_radius is None else _positive(top_radius, "top_radius")
    return _strip(name, segments, 1, lambda u, v: _around(2 * math.pi * u) * (radius + (top - radius) * v) + Vector((0, 0, height * v)), rgba)


def vfx_cone(name, radius, height, tip_radius=0.0, segments=32, rgba=None):
    """An open cone shell from a base of radius at the origin up to tip_radius at height.

    Point it with the MeshPart's orientation in Studio: up the axis for a burst, along the
    LookVector for a muzzle blast. U runs around, V from the base to the tip.
    """
    import math
    radius, height = _positive(radius, "radius"), _positive(height, "height")
    if not isinstance(tip_radius, (int, float)) or tip_radius < 0:
        raise ValueError(f"tip_radius must be 0 (a point) or a positive number of studs, got {tip_radius!r}")
    segments = _segments(segments, "segments", 8)
    return _strip(name, segments, 4,
                  lambda u, v: _around(2 * math.pi * u) * (radius + (max(tip_radius, 0.001) - radius) * v) + Vector((0, 0, height * v)), rgba)


def vfx_swirl(name, radius, height, width, turns=1.5, top_radius=None, segments=96, rgba=None):
    """A ribbon spiralling up around the vertical axis: a tornado, an aura, a charge-up.

    It turns the given number of times while rising from 0 to height, its radius going from radius to
    top_radius (radius by default), and the ribbon is width tall. U runs along the ribbon from
    the bottom end, V across it from its lower edge.
    """
    import math
    radius, height, width = _positive(radius, "radius"), _positive(height, "height"), _positive(width, "width")
    if not isinstance(turns, (int, float)) or not 0.1 <= turns <= 8:
        raise ValueError(f"turns must be 0.1 to 8, got {turns!r}")
    top = radius if top_radius is None else _positive(top_radius, "top_radius")
    segments = _segments(segments, "segments", 8)

    def point(u, v):
        return _around(2 * math.pi * turns * u) * (radius + (top - radius) * u) + Vector((0, 0, height * u + width * (v - 0.5)))

    return _strip(name, segments, 1, point, rgba)


def vfx_shell(name, radius, segments=32, rings=16, dome=False, rgba=None):
    """A sphere, or with dome a half sphere standing on the ground, as one shell: a barrier,
    a blast bubble, a shield. U runs around, V from the bottom (the equator for a dome) to the top.
    """
    import math
    radius = _positive(radius, "radius")
    segments = _segments(segments, "segments", 8)
    rings = _segments(rings, "rings", 2)

    def point(u, v):
        polar = (math.pi / 2) * (1 - v) if dome else math.pi * (1 - v)
        return _around(2 * math.pi * u) * (radius * math.sin(polar)) + Vector((0, 0, radius * math.cos(polar)))

    return _strip(name, segments, rings, point, rgba)


