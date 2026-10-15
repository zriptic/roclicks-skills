#!/usr/bin/env python3
"""vfxtex: draw Roblox particle textures and flipbooks with numpy, no Blender.

Ported from vfxtex's Blender helpers (roblox-animation-vfx, MIT, TabooHarmony;
see LICENSE-ROQER-SKILLS.txt). Plain python3 + numpy (+ Pillow for review/check).

As a library, in a drawing script:

    import sys; sys.path.insert(0, "<skills-dir>/roblox-vfx/scripts")   # this skill's scripts folder
    import vfxtex as vt
    vt.OUTPUT_DIR = "vfx/slam/textures"          # default: ./vfx_textures
    def puff(t, size): ...
    vt.draw_flipbook("SmokePuff", puff, grid=4, fps=16)
    vt.draw_texture("Glint", glint, size=512)

As a command:

    vfxtex.py check   <sheet.flipbook.png ...>   grid, per-cell coverage, problems, suggested settings
    vfxtex.py review  <png ...> [-o review.png]  contact sheet over a dark ground, to look at
    vfxtex.py preview <png ...>                  copy into Studio's content folder; prints
                                                 rbxasset://textures/vfxpreview/... addresses
    vfxtex.py clean-preview                      remove every preview copy
"""
import os
import sys

OUTPUT_DIR = os.path.join(os.getcwd(), "vfx_textures")


def _out(name):
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    return os.path.join(OUTPUT_DIR, name)

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



def _check_name(name):
    if not isinstance(name, str) or not name or any(c in name for c in '/\\:*?"<>|.'):
        raise ValueError(f"name must be usable as a file name without dots, got {name!r}")


def _write_flipbook(name, sheet, note):
    """Write a packed sheet and the note `vfxtex.py check` reads it against, plus a half-size copy when the sheet is too big to attach."""
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

def tex_coords(size=256):
    """Return (x, y): two size x size float arrays running -1..1 across the image, x to the right and y up."""
    import numpy
    size = _texture_size(size)
    steps = (numpy.arange(size, dtype=numpy.float32) + 0.5) / size * 2.0 - 1.0
    return numpy.tile(steps, (size, 1)), numpy.tile(-steps[:, None], (1, size))


def tex_polar(x, y):
    """Return (r, angle) for coordinates x, y: distance from the centre, and the angle in radians from +x, counterclockwise, -pi..pi."""
    import numpy
    return numpy.hypot(x, y), numpy.arctan2(y, x)


def _texture_size(size):
    if not isinstance(size, int) or size < 8 or size > 2048:
        raise ValueError(f"size must be a whole number of pixels from 8 to 2048, got {size!r}")
    return size


def tex_noise(size=256, scale=4, octaves=4, seed=0):
    """Smooth fractal noise in 0..1 that tiles. scale is how many blobs fit across the image at the coarsest octave; each further octave adds detail at twice the frequency and half the strength."""
    import numpy
    size = _texture_size(size)
    if not isinstance(octaves, int) or octaves < 1 or octaves > 8:
        raise ValueError(f"octaves must be a whole number from 1 to 8, got {octaves!r}")
    rng = numpy.random.default_rng(seed)
    total = numpy.zeros((size, size), dtype=numpy.float32)
    weight = 0.0
    for octave in range(octaves):
        frequency = max(1, int(round(scale))) * 2 ** octave
        lattice = rng.random((frequency, frequency), dtype=numpy.float32)
        at = numpy.arange(size, dtype=numpy.float32) * frequency / size
        low = numpy.floor(at).astype(int)
        f = at - low
        f = f * f * (3.0 - 2.0 * f)
        low %= frequency
        high = (low + 1) % frequency
        top = lattice[numpy.ix_(low, low)] * (1 - f)[None, :] + lattice[numpy.ix_(low, high)] * f[None, :]
        bottom = lattice[numpy.ix_(high, low)] * (1 - f)[None, :] + lattice[numpy.ix_(high, high)] * f[None, :]
        amplitude = 0.5 ** octave
        total += (top * (1 - f)[:, None] + bottom * f[:, None]) * amplitude
        weight += amplitude
    return total / weight


def tex_cells(size=256, cells=8, seed=0):
    """Cellular (Voronoi) noise that tiles: cells x cells jittered points. Returns (near, edge): the distance to the nearest point and the gap between the nearest and second-nearest, both in cell widths. edge is 0 on the borders between cells, so tex_edge(edge, 0.05) draws the cracks, and near < radius draws round blobs."""
    import numpy
    size = _texture_size(size)
    if not isinstance(cells, int) or cells < 1 or cells > 64:
        raise ValueError(f"cells must be a whole number from 1 to 64, got {cells!r}")
    rng = numpy.random.default_rng(seed)
    jitter = rng.random((cells, cells, 2), dtype=numpy.float32)
    at = (numpy.arange(size, dtype=numpy.float32) + 0.5) * cells / size
    px, py = numpy.meshgrid(at, at)
    cx, cy = numpy.floor(px).astype(int), numpy.floor(py).astype(int)
    first = numpy.full((size, size), 9.0, dtype=numpy.float32)
    second = numpy.full((size, size), 9.0, dtype=numpy.float32)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            nx, ny = cx + dx, cy + dy
            point = jitter[ny % cells, nx % cells]
            d = numpy.hypot(px - (nx + point[..., 0]), py - (ny + point[..., 1]))
            second = numpy.where(d < first, first, numpy.minimum(second, d))
            first = numpy.minimum(first, d)
    return first, second - first


def tex_sample(image, u, v):
    """Look a 2D image up at u, v (0..1 across and down the image), wrapping and blending between pixels. Scroll, stretch or warp noise per frame with it, as in tex_sample(noise, x * 0.5 + t, y * 0.5)."""
    import numpy
    image = numpy.asarray(image, dtype=numpy.float32)
    height, width = image.shape[:2]
    x = (numpy.asarray(u, dtype=numpy.float32) % 1.0) * width - 0.5
    y = (numpy.asarray(v, dtype=numpy.float32) % 1.0) * height - 0.5
    x0, y0 = numpy.floor(x).astype(int), numpy.floor(y).astype(int)
    fx, fy = x - x0, y - y0
    x0, y0 = x0 % width, y0 % height
    x1, y1 = (x0 + 1) % width, (y0 + 1) % height
    return (image[y0, x0] * (1 - fx) * (1 - fy) + image[y0, x1] * fx * (1 - fy)
            + image[y1, x0] * (1 - fx) * fy + image[y1, x1] * fx * fy)


def tex_edge(value, at=0.0, soft=0.01):
    """0 below at and 1 above it, blended over soft: the hard, cel-shaded edge. Keep soft near 0.01 for a crisp silhouette; raise it for a glow."""
    import numpy
    soft = max(float(soft), 1e-5)
    t = numpy.clip((numpy.asarray(value, dtype=numpy.float32) - (at - soft)) / (2 * soft), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def tex_ease(t, power=3.0):
    """Ease out: fast at first, then slow, as a burst grows. t is clamped to 0..1."""
    import numpy
    return 1.0 - (1.0 - numpy.clip(t, 0.0, 1.0)) ** power


_WARP_NOISE = {}


def tex_curve(points, samples=64, closed=False):
    """A smooth curve through control points (Catmull-Rom), as an (n, 2) array of x, y in tex_coords units. closed=True joins the last point back to the first. Feed it to tex_stroke."""
    import numpy
    p = numpy.asarray(points, dtype=numpy.float32)
    if p.ndim != 2 or p.shape[1] != 2 or len(p) < 2:
        raise ValueError("points must be at least two (x, y) pairs")
    if not isinstance(samples, int) or samples < 4 or samples > 1024:
        raise ValueError(f"samples must be a whole number from 4 to 1024, got {samples!r}")
    if closed:
        p = numpy.concatenate([p[-1:], p, p[:2]])
    else:
        p = numpy.concatenate([p[:1] * 2 - p[1:2], p, p[-1:] * 2 - p[-2:-1]])
    spans = len(p) - 3
    out = []
    for i in range(spans):
        p0, p1, p2, p3 = p[i], p[i + 1], p[i + 2], p[i + 3]
        t = numpy.linspace(0, 1, max(2, samples // spans), endpoint=(i == spans - 1))[:, None]
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t ** 2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    return numpy.concatenate(out)


def tex_stroke(x, y, path, width=0.08, start=0.0, end=1.0):
    """A stroke along a path, the way a brush draws it: positive inside, about the distance to its edge, so tex_edge cuts it.

    path is an (n, 2) array of points in tex_coords units; tex_curve makes a smooth one. width is
    the full width: a number, a list of widths spread evenly from head to tail, or a function of u
    (0 at the head, 1 at the tail). Tapering it gives the thick-to-thin pen pressure of a drawn
    claw, crescent, wisp or crack. Only the part from start to end (0 to 1 along the path) is drawn:
    raise end over the frames to draw the stroke on, and start to erase it from the head. Combine
    strokes and shapes with numpy.maximum (union) or numpy.minimum (intersection; subtract one with
    numpy.minimum(a, -b)).
    """
    import numpy
    path = numpy.asarray(path, dtype=numpy.float32)
    if path.ndim != 2 or path.shape[1] != 2 or len(path) < 2:
        raise ValueError("path must be at least two (x, y) points, as tex_curve returns")
    if len(path) > 2048:
        raise ValueError(f"path has {len(path)} points; use at most 2048 (fewer tex_curve samples)")
    seg = numpy.linalg.norm(numpy.diff(path, axis=0), axis=1)
    along = numpy.concatenate([[0.0], numpy.cumsum(seg)])
    along = along / max(float(along[-1]), 1e-6)
    if callable(width):
        def profile(u):
            return numpy.asarray(width(u), dtype=numpy.float32)
    elif numpy.ndim(width) == 0:
        def profile(u):
            return numpy.full_like(u, float(width))
    else:
        keys = numpy.asarray(width, dtype=numpy.float32)

        def profile(u):
            return numpy.interp(u, numpy.linspace(0, 1, len(keys)), keys).astype(numpy.float32)
    field = numpy.full(numpy.shape(x), -1.0, dtype=numpy.float32)
    for i in range(len(path) - 1):
        a, b = path[i], path[i + 1]
        d = b - a
        length2 = max(float(d @ d), 1e-12)
        t = numpy.clip(((x - a[0]) * d[0] + (y - a[1]) * d[1]) / length2, 0.0, 1.0)
        u = along[i] + (along[i + 1] - along[i]) * t
        inside = profile(u) * 0.5 - numpy.hypot(x - (a[0] + d[0] * t), y - (a[1] + d[1] * t))
        field = numpy.maximum(field, numpy.where((u >= start) & (u <= end), inside, -1.0))
    return field


def tex_warp(x, y, amount=0.1, scale=3, seed=0, t=0.0):
    """x, y pushed around by smooth noise. Shapes drawn with the warped coordinates come out lopsided and organic instead of geometric; t drifts the noise to animate it."""
    import numpy
    key = (int(scale), int(seed))
    if key not in _WARP_NOISE:
        _WARP_NOISE[key] = (tex_noise(256, scale, 3, seed), tex_noise(256, scale, 3, seed + 101))
    nx, ny = _WARP_NOISE[key]
    u, v = x * 0.5 + 0.5 + t, y * 0.5 + 0.5
    return x + (tex_sample(nx, u, v) - 0.5) * 2 * amount, y + (tex_sample(ny, u, v) - 0.5) * 2 * amount


def tex_blob(x, y, radius=0.5, lumps=6, roughness=0.5, seed=0, centre=(0.0, 0.0)):
    """A lumpy, lopsided blob in one piece: a solid body with round lobes bulging from its edge, bigger on one side. It never splits or has holes, so it reads as one puff, not a cluster of circles. About radius from the centre; roughness runs from 0, a plain disc, to 1, the lumpiest. Positive inside; tex_edge cuts it."""
    import numpy
    rng = numpy.random.default_rng(seed)
    roughness = min(max(float(roughness), 0.0), 1.0)
    lean = rng.uniform(0, 2 * numpy.pi)
    body = radius * (0.95 - 0.35 * roughness)
    bx = centre[0] + numpy.cos(lean) * radius * 0.2 * roughness
    by = centre[1] + numpy.sin(lean) * radius * 0.2 * roughness
    field = body - numpy.hypot(x - bx, y - by)
    for _ in range(max(1, int(lumps))):
        # Each lobe is centred inside the body, so the union stays star-shaped
        # around the body's centre: one piece, no holes.
        angle = rng.uniform(0, 2 * numpy.pi)
        reach = body * rng.uniform(0.8, 1.0)
        r = radius * roughness * rng.uniform(0.4, 0.8) * (1 + 0.4 * roughness * numpy.cos(angle - lean))
        cx, cy = bx + numpy.cos(angle) * reach, by + numpy.sin(angle) * reach
        field = numpy.maximum(field, r - numpy.hypot(x - cx, y - cy))
    return field


def _drawn_rgba(result, size, mode, where):
    """A drawing function's result as size x size x 4 floats: alpha alone, (alpha, value), or RGB / RGBA."""
    import numpy
    if isinstance(result, tuple):
        if len(result) != 2:
            raise ValueError(f"{where} returned a tuple of {len(result)}; return alpha, (alpha, value) or an RGBA array")
        alpha = numpy.asarray(result[0], dtype=numpy.float32)
        value = numpy.broadcast_to(numpy.asarray(result[1], dtype=numpy.float32), (size, size))
        if alpha.shape != (size, size):
            raise ValueError(f"{where} returned alpha shaped {alpha.shape}; it must be {size} x {size}")
        rgba = numpy.stack([value, value, value, alpha], axis=-1)
    else:
        array = numpy.asarray(result, dtype=numpy.float32)
        if array.shape == (size, size):
            rgba = numpy.stack([numpy.ones_like(array)] * 3 + [array], axis=-1)
        elif array.shape == (size, size, 4):
            rgba = array
        elif array.shape == (size, size, 3):
            rgba = numpy.concatenate([array, numpy.ones((size, size, 1), dtype=numpy.float32)], axis=-1)
        else:
            raise ValueError(f"{where} returned an array shaped {array.shape}; it must be {size} x {size} (alpha), or {size} x {size} x 3 or 4")
    rgba = numpy.clip(numpy.nan_to_num(rgba), 0.0, 1.0)
    if mode == "additive":
        rgba = numpy.concatenate([rgba[..., :3] * rgba[..., 3:4], numpy.ones((size, size, 1), dtype=numpy.float32)], axis=-1)
    return (rgba * 255.0 + 0.5).astype(numpy.uint8)


def draw_flipbook(name, frame, grid=4, loop=False, fps=None, mode="alpha", padding=4):
    """Draw a particle flipbook frame by frame with numpy and pack it into a 1024 x 1024 sheet `vfxtex.py check` reads.

    frame(t, size) draws one frame size pixels square. t runs from 0 at the first frame to 1 at
    the last (to just under 1 for a loop, whose last frame leads back to the first). It returns
    alpha (a size x size array, 0..1) for a white shape, or (alpha, value) where value is the grey
    level (a number or an array), or an RGB or RGBA array. White shapes are usual: the particle's
    Color tints them, and value lets two tones in one shape take one colour. grid is 2, 4 or 8
    (4, 16 or 64 frames); 4 is what most studied artists' sheets use. fps is the speed the frames
    are meant to play at, used to suggest the Lifetime or framerate. mode "alpha" keeps a
    transparent background (LightEmission 0 or below); "additive" bakes alpha onto black for
    LightEmission 1. padding pixels around each frame stay empty. Writes <name>.flipbook.png.
    """
    import numpy
    _check_name(name)
    if not callable(frame):
        raise ValueError("frame must be a function frame(t, size) that returns the frame's alpha, (alpha, value) or an RGBA array")
    if grid not in _FLIPBOOK_GRIDS:
        raise ValueError(f"grid must be 2, 4 or 8 (Roblox's Grid2x2, Grid4x4 and Grid8x8), got {grid!r}")
    if mode not in ("alpha", "additive"):
        raise ValueError(f'mode must be "alpha" or "additive", got {mode!r}')
    cell = _FLIPBOOK_SIDE // grid
    if not isinstance(padding, int) or padding < 0 or padding > cell // 8:
        raise ValueError(f"padding must be a whole number of pixels from 0 to {cell // 8} for a {grid} x {grid} grid, got {padding!r}")
    if fps is not None and (not isinstance(fps, (int, float)) or fps <= 0):
        raise ValueError(f"fps must be a positive number or None, got {fps!r}")
    cells = grid * grid
    inner = cell - 2 * padding
    sheet = numpy.zeros((_FLIPBOOK_SIDE, _FLIPBOOK_SIDE, 4), dtype=numpy.uint8)
    if mode == "additive":
        sheet[:, :, 3] = 255
    for index in range(cells):
        t = index / cells if loop else index / (cells - 1)
        where = f"frame(t={t:.3f}, size={inner})"
        drawn = _drawn_rgba(frame(t, inner), inner, mode, where)
        row, column = divmod(index, grid)
        top, left = row * cell + padding, column * cell + padding
        sheet[top:top + inner, left:left + inner] = drawn
    return _write_flipbook(name, sheet, {"name": name, "grid": grid, "mode": mode, "padding": padding, "loop": bool(loop),
                                         "fps": float(fps) if fps is not None else None, "drawn": True})


def draw_texture(name, image, size=512, mode="alpha"):
    """Draw one texture with numpy and write it as <name>.png. image is an array, or a function image(size) returning one: alpha, (alpha, value) or RGB / RGBA, as for draw_flipbook. mode "alpha" keeps transparency; "additive" bakes it onto black."""
    import os
    _check_name(name)
    size = _texture_size(size)
    if mode not in ("alpha", "additive"):
        raise ValueError(f'mode must be "alpha" or "additive", got {mode!r}')
    drawn = _drawn_rgba(image(size) if callable(image) else image, size, mode, "image")
    path = _out(name + ".png")
    _write_png(path, drawn)
    return path



# ---------------------------------------------------------------- command line

def _load_rgba(path):
    import numpy
    from PIL import Image
    return numpy.asarray(Image.open(path).convert("RGBA"), dtype=numpy.uint8)


def _note_for(path):
    import json
    base = path[:-len(".png")] if path.endswith(".png") else path
    try:
        with open(base + ".json", encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return {}


def check(path):
    """Read a sheet from its pixels and print what to fix and which settings to use."""
    import numpy
    rgba = _load_rgba(path)
    note = _note_for(path)
    height, width = rgba.shape[:2]
    lines = [f"{os.path.basename(path)}: {width} x {height}"]
    problems, notes = [], []
    if (width, height) != (1024, 1024):
        problems.append(f"sheet is {width} x {height}; Roblox flipbooks need 1024 x 1024")
    additive = note.get("mode") == "additive" or bool((rgba[..., 3] == 255).all())
    ink = (rgba[..., :3].max(axis=-1) / 255.0) if additive else (rgba[..., 3] / 255.0)
    # The grid whose cell borders are emptiest is the one the gutters agree with.
    best, best_score = note.get("grid"), None
    if best is None:
        for grid in (8, 4, 2):
            if width % grid:
                continue
            cell = width // grid
            edges = numpy.zeros_like(ink, dtype=bool)
            for k in range(1, grid):
                edges[:, k * cell - 1:k * cell + 1] = True
                edges[k * cell - 1:k * cell + 1, :] = True
            score = float(ink[edges].mean()) if edges.any() else 1.0
            if best_score is None or score < best_score - 1e-4:
                best, best_score = grid, score
            if score < 0.002:
                best = grid
                break
    grid = int(best or 4)
    cell = width // grid
    coverage, frames = [], []
    for index in range(grid * grid):
        row, column = divmod(index, grid)
        patch = ink[row * cell:(row + 1) * cell, column * cell:(column + 1) * cell]
        coverage.append(float((patch > 0.05).mean()))
        frames.append(patch)
        rim = numpy.concatenate([patch[0], patch[-1], patch[:, 0], patch[:, -1]])
        if (rim > 0.05).mean() > 0.01:
            problems.append(f"cell {index + 1}: drawing touches the cell edge (bleeds into its neighbour; shrink it or add padding)")
    lines.append(f"grid {grid} x {grid} ({grid * grid} cells of {cell} px)")
    lines.append("coverage by cell: " + " ".join(f"{c * 100:.0f}" for c in coverage))
    empty = [i for i, c in enumerate(coverage) if c == 0]
    trailing = 0
    for c in reversed(coverage):
        if c == 0:
            trailing += 1
        else:
            break
    middle = [i + 1 for i in empty if i < len(coverage) - trailing]
    if middle:
        problems.append(f"empty cells in play: {middle}")
    if trailing:
        notes.append(f"last {trailing} cells are blank: a one-shot particle vanishes {trailing}/{grid * grid} of its life early")
    holds = [i + 1 for i in range(1, len(frames)) if coverage[i] > 0 and numpy.abs(frames[i] - frames[i - 1]).mean() < 0.002]
    if holds:
        notes.append(f"cells that repeat the one before (holds): {holds}")
    peak = int(numpy.argmax(coverage))
    notes.append(f"largest at cell {peak + 1} ({peak / max(1, grid * grid - 1) * 100:.0f}% through; studied sheets peak ~27%)")
    loop = bool(note.get("loop"))
    fps = note.get("fps")
    settings = [f"FlipbookLayout = Grid{grid}x{grid}", "FlipbookMode = " + ("Loop" if loop else "OneShot"),
                "LightEmission = " + ("1 (baked on black)" if additive else "0 or below for drawn matter, 1 for light")]
    if loop and fps:
        settings.append(f"FlipbookFramerate = {min(30, fps):g}")
    elif fps:
        settings.append(f"Lifetime about {grid * grid / fps:.2f} s to play every frame at {fps:g} fps")
    lines += [f"PROBLEM: {p}" for p in problems] + [f"note: {n}" for n in notes] + ["use: " + "; ".join(settings)]
    print("\n".join(lines))
    return not problems


def review(paths, out="review.png", cell=256):
    """Tile images over a dark ground with their names, to look at in one image."""
    from PIL import Image, ImageDraw
    images = [(os.path.basename(p), Image.open(p).convert("RGBA")) for p in paths]
    columns = min(4, len(images)) or 1
    rows = (len(images) + columns - 1) // columns
    label = 18
    sheet = Image.new("RGBA", (columns * cell, rows * (cell + label)), (30, 30, 36, 255))
    draw = ImageDraw.Draw(sheet)
    for i, (name, image) in enumerate(images):
        row, column = divmod(i, columns)
        image.thumbnail((cell - 8, cell - 8))
        x = column * cell + (cell - image.width) // 2
        y = row * (cell + label) + label + (cell - image.height) // 2
        sheet.alpha_composite(image, (x, y))
        draw.text((column * cell + 4, row * (cell + label) + 2), name[:34], fill=(220, 220, 220, 255))
    sheet.convert("RGB").save(out)
    print(out)
    return out


def _studio_texture_dirs():
    import glob
    dirs = []
    mac = "/Applications/RobloxStudio.app/Contents/Resources/content/textures"
    if os.path.isdir(mac):
        dirs.append(mac)
    mac_user = os.path.join(os.path.expanduser("~"), "Applications", "RobloxStudio.app",
                            "Contents", "Resources", "content", "textures")
    if os.path.isdir(mac_user):
        dirs.append(mac_user)
    local = os.environ.get("LOCALAPPDATA")
    if local:
        dirs += sorted(glob.glob(os.path.join(local, "Roblox", "Versions", "*", "content", "textures")))
    return dirs


def preview(paths):
    """Copy textures into Studio's content folder so a ParticleEmitter can use them before upload.

    Each run uses a fresh folder: Studio keeps a file's first image for the session, so a
    redrawn texture needs a new address. Works on this computer only; players see nothing.
    """
    import shutil, time
    dirs = _studio_texture_dirs()
    if not dirs:
        raise SystemExit("Roblox Studio's content/textures folder was not found")
    stamp = time.strftime("%H%M%S")
    for root in dirs:
        target = os.path.join(root, "vfxpreview", stamp)
        os.makedirs(target, exist_ok=True)
        for p in paths:
            shutil.copyfile(p, os.path.join(target, os.path.basename(p)))
    for p in paths:
        print(f"{os.path.basename(p)} -> rbxasset://textures/vfxpreview/{stamp}/{os.path.basename(p)}")


def clean_preview():
    import shutil
    for root in _studio_texture_dirs():
        shutil.rmtree(os.path.join(root, "vfxpreview"), ignore_errors=True)
    print("removed vfxpreview copies")


def _main(argv):
    if len(argv) < 2 or argv[1] in ("-h", "--help"):
        print(__doc__)
        return 0
    command, rest = argv[1], argv[2:]
    if command == "check":
        ok = all([check(p) for p in rest])
        return 0 if ok else 1
    if command == "review":
        out = "review.png"
        if "-o" in rest:
            i = rest.index("-o")
            out = rest[i + 1]
            rest = rest[:i] + rest[i + 2:]
        review(rest, out)
        return 0
    if command == "preview":
        preview(rest)
        return 0
    if command == "clean-preview":
        clean_preview()
        return 0
    print(f"unknown command {command}\n{__doc__}")
    return 2


if __name__ == "__main__":
    raise SystemExit(_main(sys.argv))
