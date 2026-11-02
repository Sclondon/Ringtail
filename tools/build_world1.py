"""World 1: the back yard and the alley behind it, at dusk (a placeholder setting, Claude's pick).

Run from the project root:
    blender -b --factory-startup --python tools/build_world1.py
    blender -b --factory-startup --python tools/build_world1.py -- <folder>   # also renders it from above and two corners

Writes models/world1.glb and tools/world1.blend.

Everything is laid out here in Godot's axes (metres, Y up; the house is to -Z,
the alley to +X) and turned into Blender's as it is made. Each solid thing is
its own object, coloured by its material and shaded a little by vertex colours
in the N64 way (darker low down and in its corners, a little uneven face to face).
The game gives every mesh a collision shape except those whose names start
with `nocol_`. Empties mark where the game puts things:

    spawn                   where he starts
    cap_<name>              the five Bottlecaps (roof, glide, cats, race, hidden)
    crumb_<n>               the Crumbs
    cat_<n>                 where each yard cat starts
    race_start, race_<n>    the stopwatch, and the race crumbs it lights
    trampoline              its centre
    ladder                  the foot of the trellis, facing out from the wall
    pond                    the middle of the pond's surface (its size is POND_SIZE)
    check_<n>               checkpoints
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PREVIEW_DIR = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1 else None

random.seed(7)

COLOURS = {
    "grass": (0.36, 0.56, 0.24),
    "dirt": (0.45, 0.34, 0.22),
    "mud": (0.30, 0.25, 0.18),
    "siding": (0.62, 0.70, 0.78),
    "trim": (0.93, 0.92, 0.86),
    "roof": (0.42, 0.24, 0.20),
    "brick": (0.62, 0.30, 0.22),
    "wood": (0.62, 0.45, 0.28),
    "darkwood": (0.40, 0.28, 0.18),
    "fence": (0.70, 0.56, 0.38),
    "window": (1.00, 0.82, 0.45),
    "door": (0.30, 0.38, 0.32),
    "metal": (0.48, 0.52, 0.54),
    "bin": (0.26, 0.42, 0.30),
    "asphalt": (0.30, 0.30, 0.32),
    "concrete": (0.60, 0.60, 0.57),
    "stone": (0.55, 0.53, 0.50),
    "canvas": (0.18, 0.20, 0.28),
    "red": (0.78, 0.20, 0.16),
    "yellow": (0.95, 0.78, 0.25),
    "pole": (0.36, 0.27, 0.20),
    "lily": (0.30, 0.55, 0.30),
}

POND = Vector((-11.0, -0.15, 8.0))  # the middle of the water's surface
POND_RADII = (4.2, 3.4)
POND_FLOOR = -1.7
POND_SIZE = (POND_RADII[0] * 2.0 + 0.4, 1.7, POND_RADII[1] * 2.0 + 0.4)


def to_blender(p):
    return Vector((p[0], -p[2], p[1]))


def linear(c):
    return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92


_materials = {}


def material(name):
    if name not in _materials:
        made = bpy.data.materials.new(name)
        made.use_nodes = True
        colour = tuple(linear(c) for c in COLOURS[name]) + (1.0,)
        shader = next(n for n in made.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        shader.inputs["Base Color"].default_value = colour
        shader.inputs["Roughness"].default_value = 1.0
        made.diffuse_color = colour
        _materials[name] = made
    return _materials[name]


class Piece:
    """One object being made: faces added in Godot's axes, each with a material."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.colour = self.bm.loops.layers.color.new("Col")
        self.mats = []

    def _mat(self, name):
        if name not in self.mats:
            self.mats.append(name)
        return self.mats.index(name)

    def face(self, points, mat, shade=1.0):
        verts = [self.bm.verts.new(to_blender(p)) for p in points]
        made = self.bm.faces.new(verts)
        made.material_index = self._mat(mat)
        # (N64 shading in the vertices: a little uneven face to face, darker near the ground)
        jitter = random.uniform(0.92, 1.04) * shade
        for loop, p in zip(made.loops, points):
            low = 0.72 + 0.28 * min(1.0, max(0.0, (p[1] + 0.2) / 1.6))
            v = jitter * low
            loop[self.colour] = (v, v, v, 1.0)
        return made

    def box(self, centre, size, mat, top=None, shade=1.0):
        cx, cy, cz = centre
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        c = [(cx + sx * hx, cy + sy * hy, cz + sz * hz) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
        # (index = 4*sx + 2*sy + sz, each 0 or 1)
        quads = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        for k, q in enumerate(quads):
            m = top if (top and k == 3) else mat
            self.face([c[i] for i in q], m, shade * (1.08 if k == 3 else 0.86 if k in (0, 1) else 0.95))

    def cylinder(self, base, radius, height, mat, segments=12, top=None, cap=True):
        bx, by, bz = base
        ring = [(math.cos(math.tau * i / segments), math.sin(math.tau * i / segments)) for i in range(segments)]
        for i in range(segments):
            (a, b), (c, d) = ring[i], ring[(i + 1) % segments]
            self.face([(bx + a * radius, by, bz + b * radius), (bx + a * radius, by + height, bz + b * radius),
                       (bx + c * radius, by + height, bz + d * radius), (bx + c * radius, by, bz + d * radius)], mat, 0.9 + 0.12 * a)
        if cap:
            self.face([(bx + a * radius, by + height, bz + b * radius) for a, b in ring][::-1], top or mat, 1.08)
            self.face([(bx + a * radius, by, bz + b * radius) for a, b in ring], mat, 0.8)

    def prism_roof(self, x0, x1, z0, z1, eave, ridge, mat):
        """A gable roof along X, from eaves at z0 and z1 up to a ridge over the middle, with gable ends."""
        zm = (z0 + z1) / 2
        t = 0.2
        for za, zb in ((z0, zm), (z1, zm)):
            self.face([(x0, eave, za), (x1, eave, za), (x1, ridge, zb), (x0, ridge, zb)], mat, 1.05)
            self.face([(x0, eave - t, za), (x0, ridge - t, zb), (x1, ridge - t, zb), (x1, eave - t, za)], mat, 0.7)
            self.face([(x0, eave, za), (x0, eave - t, za), (x1, eave - t, za), (x1, eave, za)], mat, 0.8)

    def done(self, parent=None):
        for f in self.bm.faces:
            f.smooth = False
        # (merged first: each face made alone has no outside of its own to turn to)
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts[:], dist=0.0005)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces[:])
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for name in self.mats:
            mesh.materials.append(material(name))
        mesh.color_attributes.active_color = mesh.color_attributes["Col"]
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.collection.objects.link(obj)
        if parent:
            obj.parent = parent
        return obj


def mark(name, at, turn=0.0):
    empty = bpy.data.objects.new(name, None)
    empty.location = to_blender(at)
    empty.rotation_euler = (0.0, 0.0, turn)
    empty.empty_display_size = 0.3
    bpy.context.collection.objects.link(empty)
    return empty


# --- The ground: the lawn, with the pond sunk in it, and the alley's asphalt ---

def pond_depth(x, z):
    """0 outside the pond; down to its floor inside, sloping at the rim."""
    d = math.hypot((x - POND.x) / POND_RADII[0], (z - POND.z) / POND_RADII[1])
    if d >= 1.0:
        return 0.0
    return (POND_FLOOR - 0.0) * min(1.0, (1.0 - d) / 0.35)


def lawn():
    piece = Piece("lawn")
    step = 0.5
    x0, x1, z0, z1 = -20.0, 20.0, -22.5, 20.0
    nx, nz = int((x1 - x0) / step), int((z1 - z0) / step)

    def h(x, z):
        bump = 0.05 * math.sin(x * 0.7) * math.cos(z * 0.6)
        return pond_depth(x, z) + (bump if pond_depth(x, z) == 0.0 else 0.0)

    for i in range(nx):
        for j in range(nz):
            xa, xb = x0 + i * step, x0 + (i + 1) * step
            za, zb = z0 + j * step, z0 + (j + 1) * step
            pts = [(xa, h(xa, za), za), (xa, h(xa, zb), zb), (xb, h(xb, zb), zb), (xb, h(xb, za), za)]
            low = min(p[1] for p in pts)
            mat = "grass" if low > -0.2 else "dirt" if low > -0.8 else "mud"
            piece.face(pts, mat, 1.0)
    return piece.done()


def alley():
    piece = Piece("alley")
    piece.box((23.5, -0.1, 3.0), (7.0, 0.2, 34.0), "asphalt")
    # The wall of the building behind it, and a step of kerb along the fence
    piece.box((27.5, 3.0, 3.0), (1.0, 6.0, 34.0), "brick")
    for z in range(-12, 20, 4):
        piece.box((26.95, 3.5, z + 1.0), (0.1, 1.2, 1.6), "window", shade=1.25)
    # ...and walls closing the ends of the yard and alley
    piece.box((3.5, 4.0, -14.5 - 8.5), (48.0, 8.0, 1.0), "brick")  # (high enough that he cannot walk off the back of the roof onto it)
    piece.box((3.5, 1.5, 20.5), (48.0, 3.0, 1.0), "brick")
    piece.box((-20.5, 1.5, 3.0), (1.0, 3.0, 47.0), "brick")
    return piece.done()


# --- The house, its porch, the trellis up to the roof, and the chimney ---

HOUSE = (-12.0, 6.0, -22.0, -14.0)  # x0, x1, z0, z1
EAVE = 5.2
RIDGE = 7.5


def house():
    x0, x1, z0, z1 = HOUSE
    piece = Piece("house")
    piece.box(((x0 + x1) / 2, EAVE / 2, (z0 + z1) / 2), (x1 - x0, EAVE, z1 - z0), "siding")
    # Gable ends up to the ridge
    for x in (x0, x1):
        piece.face([(x, EAVE, z0), (x, EAVE, z1), (x, RIDGE, (z0 + z1) / 2)][:: 1 if x == x1 else -1], "siding")
    # (no overhang at the front, where the trellis comes up from the porch roof to step off onto it)
    piece.prism_roof(x0 - 0.5, x1 + 0.5, z0 - 0.6, z1 + 0.05, EAVE - 0.3, RIDGE + 0.05, "roof")
    # Windows lit from inside, and the back door, on the front wall
    for wx in (-10.0, -7.0, 3.5):
        piece.box((wx, 1.9, z1 + 0.04), (1.3, 1.2, 0.1), "window", shade=1.3)
        piece.box((wx, 4.0, z1 + 0.04), (1.3, 1.0, 0.1), "window", shade=1.3)
    piece.box((-1.0, 4.0, z1 + 0.04), (1.3, 1.0, 0.1), "window", shade=1.3)
    piece.box((-3.5, 1.9, z1 + 0.04), (1.0, 1.0, 0.1), "window", shade=1.3)
    piece.box((-1.5, 1.85, z1 + 0.05), (1.0, 2.1, 0.12), "door")
    # Chimney, up through the roof on the left
    # (low enough to catch the top of from the ridge)
    piece.box((-9.0, 7.5, -18.6), (1.3, 1.9, 1.3), "brick")
    piece.box((-9.0, 8.55, -18.6), (1.5, 0.2, 1.5), "concrete")
    mark("cap_roof", (-9.0, 8.7, -18.6))
    mark("check_roof", (-3.0, RIDGE + 0.1, -18.0))
    return piece.done()


PORCH = (-6.0, 2.0, -14.0, -10.8)  # x0, x1, z0, z1
DECK = 0.8


def porch():
    x0, x1, z0, z1 = PORCH
    piece = Piece("porch")
    # The deck, with a crawlspace under it: open at the front, only posts holding it up
    piece.box(((x0 + x1) / 2, DECK - 0.09, (z0 + z1) / 2), (x1 - x0, 0.18, z1 - z0), "wood", top="darkwood")
    for x in (x0 + 0.15, (x0 + x1) / 2, x1 - 0.15):
        for z in (z0 + 0.15, z1 - 0.15):
            piece.box((x, (DECK - 0.18) / 2, z), (0.2, DECK - 0.18, 0.2), "darkwood")
    # Lattice skirting on the sides only (the front is open to crawl in)
    for x in (x0, x1):
        piece.box((x, 0.3, (z0 + z1) / 2), (0.06, 0.6, z1 - z0), "trim")
    # Steps down to the lawn in the middle of the front
    for k in range(3):
        top = DECK - (k + 1) * 0.2
        piece.box((-2.0, top / 2, z1 + 0.175 + k * 0.35), (2.0, top, 0.35), "wood")
    # Posts up to the porch roof, and the roof
    for x in (x0 + 0.15, x1 - 0.15):
        piece.box((x, DECK + 1.1, z1 - 0.15), (0.18, 2.2, 0.18), "trim")
    piece.box(((x0 + x1) / 2, 3.1, (z0 + z1) / 2 + 0.15), (x1 - x0 + 0.5, 0.2, z1 - z0 + 0.6), "roof")
    # Railing along the front, either side of the steps
    for xa, xb in ((x0, -3.0), (-1.0, x1)):
        piece.box(((xa + xb) / 2, DECK + 0.85, z1 - 0.12), (xb - xa, 0.1, 0.1), "trim")
    # The hidden cap, at the back of the crawlspace
    mark("cap_hidden", (-4.6, 0.12, -13.2))
    return piece.done()


def crates():
    piece = Piece("crates")
    # A stack up to the porch roof at its right end: deck, crate, crate, roof
    piece.box((3.0, 0.5, -12.0), (1.0, 1.0, 1.0), "wood")
    piece.box((3.0, 1.5, -13.0), (1.0, 1.0, 1.0), "wood")
    piece.box((2.7, 2.4, -13.6), (0.8, 0.8, 0.8), "wood")
    return piece.done()


def trellis_mark():
    # The trellis climbs the wall from the porch roof to the eaves, at the porch's left end
    mark("ladder", (-5.0, 3.2, HOUSE[3] + 0.05))


# --- The yard: fence, shed, trampoline, swing set, rain barrel, clothesline ---

def fence():
    piece = Piece("fence")
    height = 1.7

    def run(a, b, gap=None):
        ax, az = a
        bx, bz = b
        length = math.hypot(bx - ax, bz - az)
        posts = int(length / 2.4) + 1
        for k in range(posts + 1):
            t = k / posts
            x, z = ax + (bx - ax) * t, az + (bz - az) * t
            if gap and gap[0] < (z if ax == bx else x) < gap[1]:
                continue
            piece.box((x, height / 2, z), (0.16, height, 0.16), "darkwood")
        # Boards, and a flat cap along the top wide enough to run on
        segs = [(0.0, 1.0)]
        if gap:
            lo = (gap[0] - (az if ax == bx else ax)) / ((bz - az) if ax == bx else (bx - ax))
            hi = (gap[1] - (az if ax == bx else ax)) / ((bz - az) if ax == bx else (bx - ax))
            segs = [(0.0, lo), (hi, 1.0)]
        for s0, s1 in segs:
            x0, z0 = ax + (bx - ax) * s0, az + (bz - az) * s0
            x1, z1 = ax + (bx - ax) * s1, az + (bz - az) * s1
            cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
            span = math.hypot(x1 - x0, z1 - z0)
            if ax == bx:
                piece.box((cx, height / 2, cz), (0.06, height - 0.1, span), "fence")
                piece.box((cx, height + 0.04, cz), (0.36, 0.08, span), "darkwood")
            else:
                piece.box((cx, height / 2, cz), (span, height - 0.1, 0.06), "fence")
                piece.box((cx, height + 0.04, cz), (span, 0.08, 0.36), "darkwood")

    run((20.0, -22.5), (20.0, 20.0), gap=(3.6, 6.4))
    run((-20.0, 20.0), (20.0, 20.0))
    return piece.done()


def shed():
    piece = Piece("shed")
    piece.box((12.5, 1.2, -9.5), (5.0, 2.4, 4.0), "wood")
    piece.box((12.5, 1.1, -7.46), (1.2, 2.0, 0.1), "darkwood")
    # A roof sloping gently to the back
    piece.face([(9.7, 2.75, -7.2), (15.3, 2.75, -7.2), (15.3, 2.45, -11.8), (9.7, 2.45, -11.8)][::-1], "roof", 1.05)
    piece.box((12.5, 2.45, -9.5), (5.6, 0.3, 4.6), "roof")
    # A rain barrel to get up by
    piece.cylinder((9.0, 0.0, -6.8), 0.45, 1.05, "bin", top="metal")
    return piece.done()


def trampoline():
    piece = Piece("nocol_trampoline")
    centre = (5.0, 0.0, 6.0)
    for k in range(6):
        a = math.tau * k / 6
        piece.box((centre[0] + math.cos(a) * 1.45, 0.3, centre[2] + math.sin(a) * 1.45), (0.08, 0.6, 0.08), "metal")
    piece.cylinder((centre[0], 0.56, centre[2]), 1.55, 0.08, "metal", 16, top="red")
    piece.cylinder((centre[0], 0.6, centre[2]), 1.3, 0.03, "canvas", 16)
    mark("trampoline", (centre[0], 0.6, centre[2]))
    return piece.done()


def swing_set():
    piece = Piece("swings")
    x0, x1, z = -4.0, 1.0, 12.0
    for x in (x0, x1):
        for dz in (-0.9, 0.9):
            # Legs leaning in to the top bar
            piece.face([(x - 0.08, 0.0, z + dz), (x + 0.08, 0.0, z + dz), (x + 0.08, 2.6, z), (x - 0.08, 2.6, z)], "red")
            piece.face([(x + 0.08, 0.0, z + dz), (x - 0.08, 0.0, z + dz), (x - 0.08, 2.6, z), (x + 0.08, 2.6, z)], "red")
    piece.box(((x0 + x1) / 2, 2.65, z), (x1 - x0 + 0.3, 0.16, 0.3), "metal")
    for sx in (-2.8, -0.2):
        piece.box((sx, 0.55, z), (0.6, 0.06, 0.25), "yellow")
    return piece.done()


def clothesline():
    piece = Piece("nocol_clothesline")
    # Low enough to jump up onto: its line is a Wire (wire_0) to walk along and bounce on
    for x in (-15.0, -7.0):
        piece.box((x, 0.6, -3.0), (0.12, 1.2, 0.12), "metal")
        piece.box((x, 1.2, -3.0), (0.12, 0.12, 1.0), "metal")
    for k, colour in enumerate(("trim", "red", "yellow", "siding")):
        piece.box((-13.6 + k * 1.8, 0.85, -3.0), (0.9, 0.5, 0.03), colour)
    wire(0, (-14.94, 1.18, -3.0), (-7.06, 1.18, -3.0))
    return piece.done()


def flower_beds():
    piece = Piece("beds")
    for x, z, w, d in ((-15.0, -12.0, 6.0, 1.4), (12.0, 15.0, 5.0, 1.4), (-6.0, 17.5, 8.0, 1.2)):
        piece.box((x, 0.2, z), (w, 0.4, d), "stone", top="dirt")
        for k in range(int(w / 0.7)):
            fx = x - w / 2 + 0.35 + k * 0.7
            piece.box((fx, 0.55, z + random.uniform(-0.3, 0.3)), (0.16, 0.3, 0.16), random.choice(("red", "yellow", "trim")))
    return piece.done()


def pond_dressing():
    piece = Piece("nocol_lilies")
    for k in range(7):
        a = k * 0.9
        x = POND.x + math.cos(a) * POND_RADII[0] * 0.55
        z = POND.z + math.sin(a) * POND_RADII[1] * 0.55
        piece.cylinder((x, POND.y + 0.01, z), 0.45, 0.04, "lily", 10)
    # Stepping stones across one end, solid
    stones = Piece("stones")
    for k, (x, z) in enumerate(((-15.4, 7.0), (-14.2, 8.4), (-12.9, 9.6))):
        stones.cylinder((x, -0.6, z), 0.5, 0.75, "stone", 10)
    mark("pond", (POND.x, POND.y, POND.z))
    stones.done()
    return piece.done()


# --- The alley: bins, dumpster, pallets, the power pole and the billboard ---

def alley_props():
    piece = Piece("alley_props")
    # Dumpster, and pallets stacked against it
    piece.box((23.0, 0.75, 9.5), (2.2, 1.5, 1.4), "bin", top="metal")
    piece.box((24.6, 1.0, 12.6), (1.2, 2.0, 1.2), "wood")
    piece.box((24.6, 2.3, 13.1), (1.2, 0.6, 1.0), "wood")
    for z in (-4.0, -2.8, -1.6, 15.5):
        piece.cylinder((21.2, 0.0, z), 0.42, 1.0, "bin", 12, top="metal")
    # The power pole, with its crossarm a high walk along the alley
    piece.cylinder((25.6, 0.0, 14.5), 0.2, 8.0, "pole", 8)
    # (a crossbar at its top, where the phone line from the house comes in)
    piece.box((25.6, 6.25, 14.5), (1.4, 0.14, 0.14), "darkwood")
    piece.cylinder((25.2, 6.32, 14.5), 0.06, 0.14, "trim", 6)
    piece.box((25.6, 3.92, 12.6), (0.6, 0.16, 4.2), "darkwood")
    piece.box((25.6, 5.8, 14.9), (0.7, 1.0, 0.6), "metal")
    # The billboard's catwalk, 6 m along the alley from the crossarm: too far for a jump even at a sprint (about 5 m), easy gliding
    piece.box((25.7, 2.7, 3.0), (2.2, 0.14, 3.0), "metal")
    for z in (1.7, 4.3):
        piece.box((26.7, 1.35, z), (0.14, 2.7, 0.14), "metal")
    piece.box((26.9, 4.3, 3.0), (0.2, 3.0, 4.2), "yellow")
    piece.box((26.8, 4.3, 3.0), (0.05, 2.2, 3.4), "red")
    mark("cap_glide", (25.6, 2.9, 3.0))
    mark("check_alley", (22.5, 0.1, 8.0))
    return piece.done()


# --- Where the game's things go ---

WIRE_SAG = 0.03  # of its length: the game uses the same (World, Wire.sag)


def wire(index, a, b):
    """Marks the ends of a wire for the game to string (scripts/wire.gd)."""
    mark("wire_%d_a" % index, a)
    mark("wire_%d_b" % index, b)


def wire_point(a, b, t):
    length = math.dist(a, b)
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t - WIRE_SAG * length * 4.0 * t * (1.0 - t), a[2] + (b[2] - a[2]) * t)


def crumbs_on_wire(a, b, count, start):
    for k in range(count):
        t = 0.15 + 0.7 * k / max(count - 1, 1)
        p = wire_point(a, b, t)
        mark("crumb_%03d" % (start + k), (p[0], p[1] + 0.35, p[2]))
    return start + count


def crumb_line(a, b, count, start):
    for k in range(count):
        t = k / max(count - 1, 1)
        mark("crumb_%03d" % (start + k), (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t))
    return start + count


def crumb_ring(centre, radius, count, start):
    for k in range(count):
        a = math.tau * k / count
        mark("crumb_%03d" % (start + k), (centre[0] + math.cos(a) * radius, centre[1], centre[2] + math.sin(a) * radius))
    return start + count


def markers():
    mark("spawn", (0.0, 0.05, 6.0), math.pi)
    mark("check_yard", (0.0, 0.05, 6.0))
    n = 0
    n = crumb_line((0.0, 0.3, 3.5), (-1.5, 0.3, -8.5), 8, n)          # the path to the porch
    n = crumb_line((-5.5, 1.1, -11.6), (1.5, 1.1, -11.6), 6, n)       # along the deck
    n = crumb_line((3.0, 1.3, -12.0), (2.7, 3.1, -13.6), 3, n)         # up the crates
    n = crumb_line((-5.5, 3.6, -11.8), (1.5, 3.6, -11.8), 6, n)       # the porch roof
    n = crumb_line((-11.0, RIDGE + 0.4, -18.0), (5.0, RIDGE + 0.4, -18.0), 10, n)  # the ridge
    n = crumb_ring((5.0, 1.6, 6.0), 1.0, 6, n)                         # round the trampoline, up high
    n = crumb_ring((5.0, 3.6, 6.0), 0.5, 4, n)
    n = crumb_line((19.9, 2.0, -12.0), (19.9, 2.0, 2.5), 8, n)        # along the fence top
    n = crumb_line((19.9, 2.0, 7.5), (19.9, 2.0, 18.5), 6, n)
    n = crumb_line((10.3, 3.0, -9.5), (14.7, 3.0, -9.5), 5, n)        # the shed roof
    n = crumb_ring((POND.x, POND.y + 0.5, POND.z), 2.4, 8, n)          # over the lily pads
    n = crumb_line((POND.x - 1.0, -1.2, POND.z), (POND.x + 1.0, -1.2, POND.z), 3, n)  # under the water
    n = crumb_line((-3.8, 3.1, 12.0), (1.3, 3.1, 12.0), 5, n)          # on the swing set's bar
    n = crumb_line((22.0, 0.3, -10.0), (22.0, 0.3, 6.0), 8, n)        # down the alley
    n = crumb_line((25.6, 4.4, 11.0), (25.6, 4.4, 14.0), 4, n)        # along the crossarm
    n = crumbs_on_wire((-14.94, 1.18, -3.0), (-7.06, 1.18, -3.0), 4, n)   # along the clothesline
    # The phone line from the house roof to the pole, and a line from the shed roof to the swing set
    wire(1, (6.45, 6.6, -16.2), (25.6, 6.4, 14.5))
    n = crumbs_on_wire((6.45, 6.6, -16.2), (25.6, 6.4, 14.5), 7, n)
    wire(2, (11.0, 2.82, -7.35), (0.95, 2.78, 12.0))
    n = crumbs_on_wire((11.0, 2.82, -7.35), (0.95, 2.78, 12.0), 5, n)
    n = crumb_line((-17.0, 0.3, 15.0), (-8.0, 0.3, 15.0), 4, n)
    print("CRUMBS %d" % n)
    for k, (x, z) in enumerate(((-6.0, 2.0), (8.0, -2.0), (-9.0, 14.0))):
        mark("cat_%d" % k, (x, 0.05, z))
    mark("cap_cats", (-2.0, 1.0, -9.6))
    mark("race_start", (17.0, 0.05, 5.0))
    route = ((21.5, 0.4, 2.0), (22.0, 0.4, -6.0), (23.0, 1.8, 9.5), (24.6, 2.4, 12.6), (25.6, 4.4, 12.5),
             (22.0, 0.4, 16.0), (16.0, 0.4, 16.0), (10.0, 0.4, 12.0))
    for k, at in enumerate(route):
        mark("race_%d" % k, at)
    mark("cap_race", (17.0, 0.6, 2.5))


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    lawn()
    alley()
    house()
    porch()
    crates()
    trellis_mark()
    fence()
    shed()
    trampoline()
    swing_set()
    clothesline()
    flower_beds()
    pond_dressing()
    alley_props()
    markers()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "tools", "world1.blend"))
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(ROOT, "models", "world1.glb"),
        export_format="GLB",
        export_yup=True,
        export_animations=False,
        export_vertex_color="ACTIVE",
        export_extras=False,
    )
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == "MESH")
    print("BUILT world1 tris=%d" % tris)


def look(folder):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.render.resolution_x, scene.render.resolution_y = 1200, 900
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.35, 0.42, 0.5)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    scene.collection.objects.link(camera)
    scene.camera = camera
    for view, at, target in (("above", (3.5, 60.0, 4.0), (3.5, 0.0, 3.0)), ("corner", (-26.0, 18.0, 30.0), (2.0, 1.0, -4.0)),
                             ("alley", (30.0, 14.0, 26.0), (18.0, 1.0, 0.0))):
        camera.location = to_blender(at)
        direction = to_blender(target) - to_blender(at)
        camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "world1_%s.png" % view)
        bpy.ops.render.render(write_still=True)


build()
if PREVIEW_DIR:
    look(PREVIEW_DIR)
