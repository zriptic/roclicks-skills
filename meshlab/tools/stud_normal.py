# Writes textures/stud_normal.png: one tileable cell of the AnimalPack-style square stud
# (raised square with a bevelled rim on a flat field), as a tangent-space normal map.
#   python3 meshlab/tools/stud_normal.py
import zlib, struct, os, math

N = 128            # pixels per stud cell
INNER = 0.15       # half-size of the stud's flat top (cell units), measured off the pack
OUTER = 0.21       # half-size where the bevel meets the field (stud ~42% of a cell)
SLOPE = 1.0        # bevel steepness (normal tilt)

def normal(u, v):
    x, y = u - 0.5, v - 0.5
    ax, ay = abs(x), abs(y)
    m = max(ax, ay)
    if m <= INNER or m >= OUTER:
        return (0.0, 0.0, 1.0)
    # On the bevel: tilt outward along whichever axis dominates (square stud).
    if ax >= ay:
        nx, ny = math.copysign(SLOPE, x), 0.0
    else:
        nx, ny = 0.0, math.copysign(SLOPE, y)
    l = math.sqrt(nx * nx + ny * ny + 1)
    return (nx / l, ny / l, 1 / l)

rows = []
for j in range(N):
    row = bytearray([0])
    for i in range(N):
        # v grows upward in UV space; image rows go down, so flip.
        nx, ny, nz = normal((i + 0.5) / N, 1 - (j + 0.5) / N)
        row += bytes(int(round((c * 0.5 + 0.5) * 255)) for c in (nx, ny, nz))
    rows.append(bytes(row))

def chunk(t, d):
    c = struct.pack(">I", len(d)) + t + d
    return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", N, N, 8, 2, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b"")
out = os.path.join(os.path.dirname(__file__), "..", "textures", "stud_normal.png")
open(out, "wb").write(png)
print("wrote", os.path.normpath(out))
