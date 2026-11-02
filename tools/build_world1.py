"""World 1: an alley between the backs of two rows of houses (the user, 2026-11-01: "an alley way with several houses
to scurry along, trash cans to knock over"). The layout, the five Bottlecaps and the names are Claude's.

Run from the project root:
    blender -b --factory-startup --python tools/build_world1.py
    blender -b --factory-startup --python tools/build_world1.py -- <folder>   # also renders it from above and two ends

Writes models/world1.glb and tools/world1.blend.

Laid out in Godot's axes (metres, Y up). The alley runs along Z (south at -Z, where he starts; north at +Z). Four
houses stand on each side with their backs to it; their roofs' ridges run along the alley, so he can run along a
row of roofs and cross the gaps between them on wires. Each house has a back yard behind a fence along the alley
(its cap is wide enough to run on), a back porch, and a way up. Every face carries texture coordinates in metres
(laid flat on its own plane) and a vertex colour (darker low down, a little uneven face to face): the game paints
the Banjo-style textures (tools/make_textures.gd) over them by material name (World.TEXTURES).

The game gives every mesh a collision shape except those named `nocol_`. Empties mark where the game puts things:

    spawn                       where he starts
    cap_<name>                  the Bottlecaps: roof, glide, cats (where it appears), race (where it appears), hidden
    crumb_<n>                   the Crumbs
    can_<n>                     trash cans to knock over (each spills Crumbs)
    cat_<n>                     yard cats
    race_start, race_<n>        the stopwatch, and the race crumbs it lights
    wire_<n>_a, wire_<n>_b      the ends of a wire to walk along and bounce on (sag: WIRE_SAG of its length)
    ladder_<name>_<cm>          the foot of a trellis that many centimetres high, rungs facing its +Z
    pool, pool_size             the middle of the pool's water surface; and (x, depth, z) of its size as a position
    trampoline                  its bed
    check_<name>                checkpoints
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

# Material colours (sRGB). Textured materials (World.TEXTURES) take their colour from the texture instead; these
# are what Blender shows.
COLOURS = {
    "grass": (0.38, 0.70, 0.22),
    "dirt": (0.60, 0.43, 0.27),
    "asphalt": (0.32, 0.32, 0.35),
    "concrete": (0.62, 0.61, 0.58),
    "brick": (0.74, 0.32, 0.22),
    "siding": (0.60, 0.72, 0.82),
    "siding2": (0.95, 0.88, 0.50),
    "siding3": (0.60, 0.84, 0.60),
    "trim": (0.95, 0.94, 0.88),
    "roof": (0.66, 0.30, 0.22),
    "roof2": (0.42, 0.45, 0.58),
    "wood": (0.66, 0.46, 0.28),
    "darkwood": (0.42, 0.29, 0.18),
    "fence": (0.78, 0.60, 0.38),
    "window": (1.00, 0.84, 0.48),
    "door": (0.30, 0.40, 0.34),
    "metal": (0.66, 0.70, 0.72),
    "bin": (0.30, 0.50, 0.34),
    "stone": (0.60, 0.58, 0.54),
    "pole": (0.40, 0.29, 0.20),
    "red": (0.80, 0.22, 0.17),
    "yellow": (0.96, 0.78, 0.26),
    "blue": (0.30, 0.62, 0.86),
    "canvas": (0.18, 0.20, 0.28),
}

ALLEY_HALF = 3.5        # the alley's half width, kerb to kerb
FENCE_X = 3.7           # the yard fences
HOUSE_X = (10.0, 18.0)  # each house, from its back wall to its front
LENGTH = 44.0           # the alley runs from -LENGTH to +LENGTH
FENCE_H = 1.8
WIRE_SAG = 0.03         # of its length: the game uses the same (World)

# Each side's four houses: (z from, z to, eave, ridge, siding, roof, chimney?)
HOUSES = {
    1: [(-41.0, -26.0, 4.0, 5.8, "siding", "roof", False), (-21.0, -5.0, 5.4, 7.6, "siding2", "roof2", True),
        (0.0, 16.0, 3.8, 5.6, "siding3", "roof", False), (21.0, 38.0, 5.0, 7.0, "brick", "roof2", False)],
    -1: [(-40.0, -24.0, 4.6, 6.6, "brick", "roof", False), (-19.0, -4.0, 3.6, 5.4, "siding", "roof2", False),
         (1.0, 17.0, 5.0, 7.2, "siding2", "roof", False), (22.0, 39.0, 4.2, 6.0, "siding3", "roof2", False)],
}


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
    """One object being made: faces added in Godot's axes, each with a material, texture coordinates in metres on
    its own plane, and a vertex colour."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.colour = self.bm.loops.layers.color.new("Col")
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.mats = []

    def _mat(self, name):
        if name not in self.mats:
            self.mats.append(name)
        return self.mats.index(name)

    def face(self, points, mat, shade=1.0):
        points = [Vector(p) for p in points]
        verts = [self.bm.verts.new(to_blender(p)) for p in points]
        made = self.bm.faces.new(verts)
        made.material_index = self._mat(mat)
        # Texture laid flat on the face's own plane: across it level, and up (or along) it
        normal = (points[1] - points[0]).cross(points[2] - points[0])
        normal = normal.normalized() if normal.length > 1e-9 else Vector((0, 1, 0))
        if abs(normal.y) > 0.95:
            across, up = Vector((1, 0, 0)), Vector((0, 0, 1))
        else:
            across = Vector((0, 1, 0)).cross(normal).normalized()
            up = normal.cross(across).normalized()
        jitter = random.uniform(0.93, 1.04) * shade
        for loop, p in zip(made.loops, points):
            low = 0.74 + 0.26 * min(1.0, max(0.0, (p.y + 0.2) / 1.6))
            v = jitter * low
            loop[self.colour] = (v, v, v, 1.0)
            loop[self.uv].uv = (p.dot(across), -p.dot(up))
        return made

    def box(self, centre, size, mat, top=None, shade=1.0):
        cx, cy, cz = centre
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        c = [(cx + sx * hx, cy + sy * hy, cz + sz * hz) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
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

    def gable_roof(self, xb, xf, z0, z1, eave, ridge, mat, over=0.4, thick=0.2):
        """A roof over xb..xf (either order) whose ridge runs along Z over the middle, overhanging by `over` all round."""
        xm = (xb + xf) / 2
        za, zb = z0 - over, z1 + over
        half = abs(xf - xb) / 2
        drop = (ridge - eave) * over / half
        for xe in (xb + math.copysign(over, xb - xm), xf + math.copysign(over, xf - xm)):
            lo = eave - drop
            self.face([(xe, lo, za), (xm, ridge, za), (xm, ridge, zb), (xe, lo, zb)], mat, 1.05)
            self.face([(xe, lo - thick, za), (xe, lo - thick, zb), (xm, ridge - thick, zb), (xm, ridge - thick, za)], mat, 0.7)
            self.face([(xe, lo, za), (xe, lo, zb), (xe, lo - thick, zb), (xe, lo - thick, za)], mat, 0.8)
            for z in (za, zb):
                self.face([(xe, lo, z), (xm, ridge, z), (xm, ridge - thick, z), (xe, lo - thick, z)], mat, 0.8)

    def done(self):
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
        return obj


def mark(name, at, turn=0.0):
    empty = bpy.data.objects.new(name, None)
    empty.location = to_blender(at)
    empty.rotation_euler = (0.0, 0.0, turn)
    empty.empty_display_size = 0.3
    bpy.context.collection.objects.link(empty)
    return empty


_count = {"crumb": 0, "wire": 0, "can": 0}


def crumb(at):
    mark("crumb_%03d" % _count["crumb"], at)
    _count["crumb"] += 1


def crumb_line(a, b, count):
    for k in range(count):
        t = k / max(count - 1, 1)
        crumb(tuple(a[i] + (b[i] - a[i]) * t for i in range(3)))


def wire_point(a, b, t):
    length = math.dist(a, b)
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t - WIRE_SAG * length * 4.0 * t * (1.0 - t), a[2] + (b[2] - a[2]) * t)


def wire(a, b, crumbs=0):
    mark("wire_%d_a" % _count["wire"], a)
    mark("wire_%d_b" % _count["wire"], b)
    _count["wire"] += 1
    for k in range(crumbs):
        p = wire_point(a, b, 0.2 + 0.6 * k / max(crumbs - 1, 1))
        crumb((p[0], p[1] + 0.35, p[2]))


def can(at):
    mark("can_%d" % _count["can"], at)
    _count["can"] += 1


# --- The ground and the walls round it all ---

def ground():
    piece = Piece("ground")
    piece.box((0.0, -0.1, 0.0), (ALLEY_HALF * 2, 0.2, LENGTH * 2), "asphalt")
    for side in (1, -1):
        # A kerb along each side, then the yards' grass out to the far walls
        piece.box((side * (ALLEY_HALF + 0.1), 0.0, 0.0), (0.4, 0.2, LENGTH * 2), "concrete")
        piece.box((side * 11.65, -0.1, 0.0), (15.9, 0.2, LENGTH * 2), "grass")
        piece.box((side * 19.5, 4.0, 0.0), (1.0, 8.0, LENGTH * 2 + 2), "brick")
    # Walls closing the ends, too high to get over
    piece.box((0.0, 4.0, LENGTH + 0.5), (40.0, 8.0, 1.0), "brick")
    piece.box((0.0, 4.0, -LENGTH - 0.5), (40.0, 8.0, 1.0), "brick")
    return piece.done()


# --- A house: its back wall to the alley, roof ridge along the alley ---

def house(side, index, z0, z1, eave, ridge, siding, roof, chimney):
    piece = Piece("house_%s%d" % ("e" if side > 0 else "w", index))
    xb, xf = side * HOUSE_X[0], side * HOUSE_X[1]   # back (to the alley) and front
    xm = (xb + xf) / 2
    zc = (z0 + z1) / 2
    piece.box((xm, eave / 2, zc), (abs(xf - xb), eave, z1 - z0), siding)
    for z in (z0, z1):
        piece.face([(xb, eave, z), (xf, eave, z), (xm, ridge, z)], siding)
    piece.gable_roof(xb, xf, z0, z1, eave, ridge, roof)
    # Windows lit from inside and a back door, on the back wall
    face_x = xb - side * 0.05
    floors = [1.6] + ([eave - 1.5] if eave > 4.4 else [])
    for wy in floors:
        for k in range(3):
            wz = z0 + (z1 - z0) * (k + 1) / 4
            if wy < 2.0 and k == 1:
                continue
            piece.box((face_x, wy, wz), (0.12, 1.0, 1.2), "window", shade=1.3)
    piece.box((face_x, 1.05, zc), (0.14, 2.1, 1.0), "door")
    if chimney:
        cz = z0 + (z1 - z0) * 0.3
        top = ridge + 1.4
        piece.box((xm, top - 1.3, cz), (1.2, 2.6, 1.2), "brick")
        piece.box((xm, top + 0.1, cz), (1.4, 0.2, 1.4), "concrete")
        mark("cap_roof", (xm, top + 0.35, cz))
    # Along the ridge: crumbs to run along
    crumb_line((xm, ridge + 0.45, z0 + 1.0), (xm, ridge + 0.45, z1 - 1.0), max(3, int((z1 - z0) / 3)))
    return piece.done()


def back_porch(side, index, z0, z1, eave, hidden=False):
    """A deck by the back door with a crawlspace under it, a lean-to roof over it, steps down, and a way up."""
    tag = "%s%d" % ("e" if side > 0 else "w", index)
    piece = Piece("porch_" + tag)
    xb = side * HOUSE_X[0]
    zc = (z0 + z1) / 2
    depth = 2.6
    xo = xb - side * depth     # the porch's outer edge, towards the alley
    deck = 0.8
    xm = (xb + xo) / 2
    piece.box((xm, deck - 0.09, zc), (depth, 0.18, 4.0), "wood", top="darkwood")
    for x in (xo + side * 0.15, xb - side * 0.15):
        for z in (zc - 1.85, zc + 1.85):
            piece.box((x, (deck - 0.18) / 2, z), (0.2, deck - 0.18, 0.2), "darkwood")
    # Skirting on the ends only: the side to the alley is open, to crawl under
    for z in (zc - 2.0, zc + 2.0):
        piece.box((xm, 0.3, z), (depth, 0.6, 0.06), "trim")
    # Steps down towards the alley, at one end
    for k in range(3):
        top = deck - (k + 1) * 0.2
        piece.box((xo - side * (0.175 + k * 0.35), top / 2, zc + 1.2), (0.35, top, 1.4), "wood")
    # The lean-to roof on two posts, its top sloping down from the wall
    for z in (zc - 1.85, zc + 1.85):
        piece.box((xo + side * 0.1, deck + 1.0, z), (0.16, 2.0, 0.16), "trim")
    piece.box((xm - side * 0.15, 2.85, zc), (depth + 0.3, 0.2, 4.4), "roof")
    if hidden:
        mark("cap_hidden", (xm + side * 0.6, 0.12, zc - 0.8))
    crumb_line((xm, deck + 0.35, zc - 1.4), (xm, deck + 0.35, zc + 1.4), 3)
    crumb_line((xm, 3.3, zc - 1.6), (xm, 3.3, zc + 1.6), 3)
    # A trellis from the porch roof up to the eaves where they are out of reach, its rungs to the alley
    if eave - 2.95 > 1.4:
        mark("ladder_%s_%d" % (tag, int(round((eave - 2.95) * 100))), (xb - side * 0.06, 2.95, zc - 1.0),
             -math.pi / 2 if side > 0 else math.pi / 2)
    # Crates by the porch to get up onto its roof
    piece.box((xo - side * 0.6, 0.5, zc - 1.6), (1.0, 1.0, 1.0), "wood")
    piece.box((xo - side * 0.5, 1.4, zc - 1.6), (0.8, 0.8, 0.8), "wood")
    return piece.done()


def fences():
    piece = Piece("fences")
    for side in (1, -1):
        x = side * FENCE_X
        gates = [(h[0] + h[1]) / 2 for h in HOUSES[side]]
        z = -LENGTH
        edges = []
        for g in gates:
            edges.append((z, g - 0.7))
            z = g + 0.7
        edges.append((z, LENGTH))
        for za, zb in edges:
            span = zb - za
            zc = (za + zb) / 2
            piece.box((x, FENCE_H / 2, zc), (0.06, FENCE_H - 0.1, span), "fence")
            # (a flat cap along the top, wide enough to run along)
            piece.box((x, FENCE_H + 0.04, zc), (0.36, 0.08, span), "darkwood")
            posts = max(int(span / 2.4), 1)
            for k in range(posts + 1):
                piece.box((x, FENCE_H / 2, za + k * span / posts), (0.16, FENCE_H, 0.16), "darkwood")
        # Fences between the yards, from the alley fence to the houses
        for h0, h1 in zip(HOUSES[side], HOUSES[side][1:]):
            zm = (h0[1] + h1[0]) / 2
            xa, xh = side * FENCE_X, side * HOUSE_X[0]
            piece.box(((xa + xh) / 2, FENCE_H / 2, zm), (abs(xh - xa), FENCE_H - 0.1, 0.06), "fence")
            piece.box(((xa + xh) / 2, FENCE_H + 0.04, zm), (abs(xh - xa), 0.08, 0.36), "darkwood")
        crumb_line((x, FENCE_H + 0.4, -36.0), (x, FENCE_H + 0.4, -28.0), 4)
        crumb_line((x, FENCE_H + 0.4, 24.0), (x, FENCE_H + 0.4, 34.0), 4)
    return piece.done()


# --- The alley's things: dumpsters, pallets, poles and their wires, cans, the billboard ---

POLES = [(3.0, -30.0), (3.0, 0.0), (3.0, 30.0)]
POLE_TOP = 6.4


def alley_things():
    piece = Piece("alley_things")
    # Dumpsters, each with a pallet by it to climb
    for x, z in ((-2.2, -16.0), (2.2, 12.0)):
        piece.box((x, 0.75, z), (1.4, 1.5, 2.4), "bin", top="metal")
        side = 1 if x > 0 else -1
        piece.box((x - side * 0.2, 0.25, z + 1.9), (1.2, 0.5, 1.2), "wood")
    # Power poles along the east kerb, with a crossbar and steps up them, and the phone line strung along them
    for x, z in POLES:
        piece.cylinder((x, 0.0, z), 0.18, POLE_TOP + 0.4, "pole", 8)
        piece.box((x, POLE_TOP, z), (1.6, 0.14, 0.14), "darkwood")
        for k in range(9):
            piece.box((x, 0.9 + k * 0.6, z + 0.25 * (1 if k % 2 else -1)), (0.06, 0.06, 0.3), "metal")
    for (xa, za), (xb, zb) in zip(POLES, POLES[1:]):
        wire((xa, POLE_TOP + 0.08, za), (xb, POLE_TOP + 0.08, zb), 6)
    # The billboard on the north wall, its catwalk only to be reached by gliding from the roofs by it
    piece.box((-1.0, 3.6, LENGTH - 0.9), (4.0, 0.14, 1.6), "metal")
    for x in (-2.8, 0.8):
        piece.box((x, 1.8, LENGTH - 0.3), (0.14, 3.6, 0.14), "metal")
    piece.box((-1.0, 6.0, LENGTH - 0.15), (4.6, 3.6, 0.2), "yellow")
    piece.box((-1.0, 6.0, LENGTH - 0.27), (3.8, 2.8, 0.05), "red")
    mark("cap_glide", (-1.0, 3.95, LENGTH - 0.9))
    # Where the Bottlecaps for beating the cats and winning the race appear
    mark("cap_cats", (0.0, 0.6, 2.0))
    mark("cap_race", (0.0, 0.6, -40.0))
    # Trash cans by the gates and the dumpsters
    for side in (1, -1):
        for h in HOUSES[side]:
            g = (h[0] + h[1]) / 2
            can((side * (FENCE_X - 0.6), 0.0, g + 1.3))
            can((side * (FENCE_X - 0.6), 0.0, g + 2.2))
    can((-2.4, 0.0, -13.6))
    can((2.6, 0.0, 9.6))
    crumb_line((0.0, 0.35, -36.0), (0.0, 0.35, -20.0), 6)
    crumb_line((-1.0, 0.35, -2.0), (-1.0, 0.35, 10.0), 5)
    crumb_line((1.0, 0.35, 18.0), (1.0, 0.35, 36.0), 6)
    return piece.done()


# --- The back yards: a pool, a clothesline, a shed, a trampoline ---

def yards():
    piece = Piece("yards")
    # An above-ground pool behind the west house 3, with a step to climb in by
    px, pz = -6.9, 9.0
    size = (4.6, 3.6)
    wall = 1.2
    for dx in (-1, 1):
        piece.box((px + dx * size[0] / 2, wall / 2, pz), (0.16, wall, size[1] + 0.16), "blue")
    for dz in (-1, 1):
        piece.box((px, wall / 2, pz + dz * size[1] / 2), (size[0], wall, 0.16), "blue")
    piece.box((px, -0.05, pz), (size[0], 0.1, size[1]), "blue")
    piece.box((px + size[0] / 2 + 0.6, 0.5, pz), (1.0, 1.0, 1.6), "wood", top="darkwood")
    mark("pool", (px, wall - 0.15, pz))
    mark("pool_size", (size[0] - 0.1, wall - 0.05, size[1] - 0.1))
    for k in range(3):
        crumb((px - 1.2 + k * 1.2, 0.3, pz))
    # A clothesline across the east yard 3: a wire to bounce on
    for z in (3.0, 11.0):
        piece.box((6.5, 0.6, z), (0.12, 1.2, 0.12), "metal")
        piece.box((6.5, 1.2, z), (1.0, 0.12, 0.12), "metal")
    wire((6.5, 1.18, 3.06), (6.5, 1.18, 10.94), 4)
    # A shed in the east yard 1, flat-roofed to run on
    piece.box((6.8, 1.2, -34.0), (3.2, 2.4, 4.0), "wood")
    piece.box((6.8, 2.5, -34.0), (3.6, 0.2, 4.4), "roof")
    piece.box((5.15, 0.45, -31.2), (0.9, 0.9, 0.9), "wood")
    crumb_line((6.8, 2.95, -35.6), (6.8, 2.95, -32.4), 3)
    # A trampoline in the west yard 2
    tx, tz = -6.8, -11.0
    for k in range(6):
        a = math.tau * k / 6
        piece.box((tx + math.cos(a) * 1.25, 0.3, tz + math.sin(a) * 1.25), (0.08, 0.6, 0.08), "metal")
    tramp = Piece("nocol_trampoline")
    tramp.cylinder((tx, 0.56, tz), 1.35, 0.08, "metal", 16, top="red")
    tramp.cylinder((tx, 0.6, tz), 1.15, 0.03, "canvas", 16)
    tramp.done()
    mark("trampoline", (tx, 0.6, tz))
    for k in range(5):
        a = math.tau * k / 5
        crumb((tx + math.cos(a) * 0.6, 3.2, tz + math.sin(a) * 0.6))
    return piece.done()


def roof_wires():
    """Wires across the gap from each house's ridge to the next along a row, and from the middle pole over the
    alley to the ridge of the tall west house 3."""
    for side in (1, -1):
        xm = side * (HOUSE_X[0] + HOUSE_X[1]) / 2
        for h0, h1 in zip(HOUSES[side], HOUSES[side][1:]):
            wire((xm, h0[3] + 0.05, h0[1] + 0.35), (xm, h1[3] + 0.05, h1[0] - 0.35), 2)
    h = HOUSES[-1][2]
    wire((POLES[1][0] - 0.7, POLE_TOP + 0.08, POLES[1][1]), (-(HOUSE_X[0] + HOUSE_X[1]) / 2, h[3] + 0.05, h[0] + 1.2), 4)


def markers():
    mark("spawn", (0.0, 0.05, -38.0), 0.0)
    mark("check_south", (0.0, 0.05, -38.0))
    mark("check_middle", (0.0, 0.05, 0.0))
    mark("check_north", (0.0, 0.05, 36.0))
    for k, (x, z) in enumerate(((7.0, -20.0), (-1.2, -6.0), (6.8, 26.0), (-6.5, 30.0))):
        mark("cat_%d" % k, (x, 0.05, z))
    mark("race_start", (-1.8, 0.05, -34.0))
    route = ((0.0, 0.4, -26.0), (-2.2, 1.9, -16.0), (0.0, 0.4, -8.0), (FENCE_X, FENCE_H + 0.4, -2.0),
             (2.2, 1.9, 12.0), (0.0, 0.4, 20.0), (-FENCE_X, FENCE_H + 0.4, 28.0), (0.0, 0.4, 38.0))
    for k, at in enumerate(route):
        mark("race_%d" % k, at)


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    ground()
    for side in (1, -1):
        for index, (z0, z1, eave, ridge, siding, roof, chimney) in enumerate(HOUSES[side]):
            house(side, index, z0, z1, eave, ridge, siding, roof, chimney)
            back_porch(side, index, z0, z1, eave, hidden=(side > 0 and index == 1))
    fences()
    alley_things()
    yards()
    roof_wires()
    markers()
    print("CRUMBS %d WIRES %d CANS %d" % (_count["crumb"], _count["wire"], _count["can"]))
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
    camera.data.clip_end = 400.0
    scene.collection.objects.link(camera)
    scene.camera = camera
    for view, at, target in (("above", (0.01, 120.0, 0.0), (0.0, 0.0, 0.0)), ("south", (-14.0, 16.0, -58.0), (0.0, 2.0, -10.0)),
                             ("north", (12.0, 14.0, 56.0), (0.0, 2.0, 12.0))):
        camera.location = to_blender(at)
        direction = to_blender(target) - to_blender(at)
        camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "world1_%s.png" % view)
        bpy.ops.render.render(write_still=True)


build()
if PREVIEW_DIR:
    look(PREVIEW_DIR)
