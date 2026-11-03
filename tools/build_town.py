"""World 1, the town: a little grove on a hill in the middle of a hillside town (the user, 2026-11-01: "The map should
be a little grove on a hill in the center of town"), set in the Pacific Northwest (the user, 2026-11-02: "it takes
place in the PNW not japan the mountain should look more rainier like and there should be other mountains as well"),
with the gentle mood of Pom Poko and Whisper of the Heart kept (the user, 2026-11-02: "the town should be inspired by
pom poko and whisper of the heart"). The layout and what goes where are Claude's:

- the grove: a clearing (the great oak, a knoll, the pond fed by a spring), an inner ring of trees, a band of open wood
  with three giant firs whose leafy platforms are perches, an outer ring, a fieldstone wall round it by the pavement;
  Douglas fir, western red cedar, bigleaf maple and alder, ferns, salal and nurse logs;
- a ring road round the hill with cars, pavements, power poles hung with wires, street lights;
- the houses on terraced lots above the road (tools/buildings.py's generated buildings: craftsman bungalows, box
  houses, a farmhouse, brick commercial blocks, a walk-up);
- down each of the hill's four faces a zone with its own theme and road layout (hill(), below);
- past the hill the valley and the Cascades: Rainier, St Helens, Adams, the Olympics (none of it solid). An unseen wall
  (`hidden_bound`: World hides `hidden_` meshes but keeps them solid) keeps him in.

Run from the project root:
    blender -b --factory-startup --python tools/build_town.py [-- <folder>]   # the folder gets pictures of it

Writes models/world1.glb (the game's World 1) and tools/town.blend. Built on tools/build_world1.py's Piece and
markers (textures by material name, texture coordinates in metres, vertex shading), and its marker names
(see its docstring), plus:

    tree_<n>_<seed>_<size%>     a climbable tree (scripts/world.gd grows it)
    treep_<n>_<seed>_<size%>_<kind>  a plain tree: fir, redcedar, maple, alder (+lo: the plainer build)
    road_<loop>_<i>             a road loop's centre line, in order (cars: scripts/hazards.gd)
    walk_<route>_<i>            a path people walk there and back
    hawk_<n>, crows_<n>, den_<n> where the hawk circles, a band of crows hangs about, the fox lives
    grove_heart                 where the raccoons gather; `haven` the middle Hazards.HAVEN_RADIUS is measured from
    haunt_<n>                   spots round town wandering raccoons visit
    npc_perch_<n>               a leafy platform up a giant fir, for a raccoon to sit on
    spring                      the spring's pool on the outcrop over the pond
    streetlamp_<n>              a street light's head, just under its lens (material "streetlamp" its glowing part)
    signal_<n>                  a traffic light (lenses "signal_red", "signal_amber", "signal_green")
    busstop_<n>, bench_<n>      a bus shelter (where a bus would stop), a bench's seat

Godot's axes: Y up; the hill's top is at the middle (0, 0); north is -Z.
"""

import math
import os
import random
import sys

import bpy
from mathutils import Vector, noise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_world1 as w1  # noqa: E402  (Piece, mark, crumb, wire, can, COLOURS)
import buildings  # noqa: E402  (the generated buildings)

ROOT = w1.ROOT
PREVIEW_DIR = w1.PREVIEW_DIR
random.seed(23)

w1.COLOURS.update({
    "blockwall": (0.84, 0.84, 0.80),
    "plaster": (0.93, 0.90, 0.82),
    "plaster2": (0.88, 0.86, 0.80),
    "shopred": (0.62, 0.22, 0.17),
    "thatch": (0.70, 0.58, 0.36),
    "glass": (0.30, 0.42, 0.50),
    "white": (0.95, 0.94, 0.90),
    "green": (0.22, 0.40, 0.32),
    "awning": (0.92, 0.88, 0.72),
    "rail": (0.66, 0.80, 0.76),
    "black": (0.14, 0.13, 0.13),
    "straw": (0.82, 0.72, 0.46),
    "wire_dark": (0.12, 0.12, 0.14),
    "zinc": (0.66, 0.68, 0.70),
    "lily": (0.34, 0.56, 0.30),
    "lily_flower": (0.96, 0.92, 0.70),
    "koi": (0.95, 0.48, 0.14),
    "trout": (0.46, 0.50, 0.40),
    "fern": (0.24, 0.44, 0.20),
    "salal": (0.20, 0.36, 0.18),
    "huckleberry": (0.36, 0.52, 0.24),
    "berry": (0.62, 0.16, 0.20),
    "moss": (0.36, 0.48, 0.24),
    "leafpad": (0.18, 0.34, 0.22),
    "shake": (0.46, 0.34, 0.26),
    "roof3": (0.30, 0.32, 0.30),
    "stream": (0.42, 0.62, 0.66),
    "falls": (0.78, 0.88, 0.92),
    "foam": (0.95, 0.97, 0.98),
    "gravel": (0.55, 0.53, 0.50),
    "orange": (0.98, 0.45, 0.10),
    "channel_water": (0.26, 0.34, 0.30),
    "chainlink": (0.55, 0.58, 0.60),
    "sign_green": (0.12, 0.42, 0.26),
    "stop_red": (0.80, 0.10, 0.10),
    "streetlamp": (1.0, 0.92, 0.70),
    "signal_red": (0.85, 0.12, 0.10),
    "signal_amber": (0.95, 0.62, 0.10),
    "signal_green": (0.20, 0.80, 0.45),
    "signal_body": (0.20, 0.22, 0.16),
    "lamp_grey": (0.56, 0.58, 0.60),
    "sky_paint": (1.0, 1.0, 1.0),
    "sky_tree": (1.0, 1.0, 1.0),
    "sky_snow": (0.94, 0.96, 1.0),
    "sky_rock": (0.52, 0.58, 0.70),
    "sky_forest": (0.30, 0.42, 0.44),
    "sleeve": (0.95, 0.78, 0.18),
    "vend_blue": (0.22, 0.42, 0.78),
    # the town below and the hills (not textured: no moire far off); the far town's colours a third of the way to the
    # haze (quieter: the user, 2026-11-02, "its way too busy in the distance")
    "far_green": (0.32, 0.52, 0.30),
    "far_forest": (0.20, 0.38, 0.26),
    "far_hill": (0.36, 0.52, 0.50),
    "far_wall": (0.77, 0.80, 0.80),
    "far_wall2": (0.65, 0.72, 0.73),
    "far_roof": (0.47, 0.53, 0.56),
    "far_roof2": (0.54, 0.53, 0.52),
    "far_roof3": (0.43, 0.50, 0.52),
    "far_road": (0.55, 0.55, 0.56),
    "far_tree": (0.16, 0.32, 0.22),
    "far_tree2": (0.22, 0.38, 0.24),
    "far_glass": (0.54, 0.66, 0.73),
    "far_brick": (0.61, 0.53, 0.52),
    "far_metal": (0.65, 0.71, 0.74),
    "far_metal2": (0.53, 0.63, 0.69),
    "far_red": (0.64, 0.34, 0.29),
    "far_blue": (0.41, 0.54, 0.69),
    "far_yellow": (0.82, 0.76, 0.47),
    "far_lumber": (0.77, 0.74, 0.64),
    "far_dirt": (0.61, 0.59, 0.55),
    "far_field": (0.65, 0.72, 0.56),
    "far_field2": (0.73, 0.74, 0.59),
    "far_field3": (0.52, 0.66, 0.52),
    "far_water": (0.48, 0.62, 0.71),
})

HILL_TOP = 2.5          # the plateau's height: a gentle mound (the user, 2026-11-02: "the grove hill is way too steep")
PLATEAU = 34.0          # its radius: the open clearing on top (the user, 2026-11-02: "the grove needs to be bigger")
HILL_FOOT = 54.5        # where the mound meets the flat (the inner pavement starts at 54.6)
INNER = (37.0, 40.0)    # the inner ring of trees, two rows (the user, 2026-11-02: "have 2 rings of trees, in between we
                        # need a couple big trees for npcs to be in")
GIANTS = [(math.cos(math.radians(d)) * 44.4, math.sin(math.radians(d)) * 44.4) for d in (160.0, 300.0, 20.0)]
OUTER = (48.5, 50.5, 52.3)   # the outer ring, three rows
WALL_R = 54.3           # the fieldstone wall round the grove, by the inner pavement
ROAD = (57.6, 69.6)     # the ring road, inner and outer edge
ROAD_MIDDLE = 63.6
PAVE = 3.0              # the pavements either side of it
LOT = (74.5, 94.0)      # the terraced lots, from the retaining wall by the road to the brink at the back
FRONT = 76.5            # where the buildings' fronts stand
BOUND = 93.6
OAK = (-20.0, -20.0)    # the great oak at the clearing's north-west edge: the raccoons' base
POOL = (19.0, 7.0)      # the pond at the clearing's east edge (the user, 2026-11-02: "the pond needs to be bigger too")
POOL_RADII = (10.0, 7.5)
KNOLL = (13.0, -16.0)   # a little grassy hill in the clearing (the user, 2026-11-02: "there should be a little hill in
KNOLL_SIZE = (11.0, 3.0)  # the grove"): its radius and height
SECTORS = 12
# Where the lost kits sit (the user, 2026-11-02: "50 kits to rescue ... or maybe lets start with 20"): marked kit_<n>
KITS = []

# Each lot round the road (sector k centred on k twelfths of a turn): what stands on it (a tools/buildings.py kind),
# and how high it is held above the road. (Claude's picks.)
LOTS = [
    ("road", 0.0),          # east: the Industrial zone's road goes down from here
    ("commercial", 0.12),
    ("craftsman", 1.6),
    ("road", 0.0),          # south: the Rural lane
    ("commercial", 0.12),
    ("craftsman", 1.8),
    ("road", 0.0),          # west: the City's boulevard
    ("farmhouse", 0.6),
    ("craftsman", 1.2),
    ("road", 0.0),          # north: the Construction zone's
    ("walkup", 2.4),        # the flats the glide Bottlecap is reached from
    ("box", 1.4),
]


def _pond_d(x, z):
    """How far (x, z) is out from the pond's middle, 1 at its bank (uneven, not an ellipse)."""
    a = math.atan2(z - POOL[1], x - POOL[0])
    wobble = 1.0 + 0.14 * math.sin(3.0 * a + 0.7) + 0.08 * math.sin(5.0 * a + 2.1)
    return math.hypot((x - POOL[0]) / POOL_RADII[0], (z - POOL[1]) / POOL_RADII[1]) / wobble


def pond_edge(a):
    """The point of the pond's bank in the way `a` from its middle."""
    lo, hi = 0.0, 18.0
    for _ in range(30):
        mid = (lo + hi) / 2
        if _pond_d(POOL[0] + math.cos(a) * mid, POOL[1] + math.sin(a) * mid) < 1.0:
            lo = mid
        else:
            hi = mid
    return POOL[0] + math.cos(a) * lo, POOL[1] + math.sin(a) * lo


def hill_height(x, z):
    r = math.hypot(x, z)
    if r >= HILL_FOOT:
        return 0.0
    t = (r - PLATEAU) / (HILL_FOOT - PLATEAU)
    s = 1.0 - (t * t * (3.0 - 2.0 * t) if t > 0.0 else 0.0)
    lumps = 0.2 * noise.noise(Vector((x * 0.13, z * 0.13, 0.5))) * min(1.0, r / PLATEAU) ** 2
    h = HILL_TOP * s + lumps * s
    # the knoll: a gentle grassy dome in the clearing, a lookout
    k = math.hypot(x - KNOLL[0], z - KNOLL[1]) / KNOLL_SIZE[0]
    if k < 1.0:
        h += KNOLL_SIZE[1] * math.cos(k * math.pi / 2) ** 2
    # the pond, sunk in the top, its banks uneven
    d = _pond_d(x, z)
    if d < 1.0:
        h -= 1.9 * min(1.0, (1.0 - d) / 0.3)
    return h


def oak_roots():
    """The great oak's gnarled roots, snaking out from its foot over the ground (solid: to walk along and climb)."""
    ox, oz = OAK
    oy = hill_height(ox, oz)
    w1.mark("great_oak", (ox, oy, oz))
    roots = w1.Piece("oak_roots")
    rng = random.Random(4)
    for k in range(8):
        a = math.tau * k / 8 + rng.uniform(-0.25, 0.25)
        reach = rng.uniform(4.5, 7.5)
        wander = rng.uniform(-0.6, 0.6)
        steps = 10
        prev_ring = None
        for i in range(steps + 1):
            t = i / steps
            # (out from the trunk's foot, bending as it goes, arching up off the ground and back down into it)
            turn = a + wander * t * t
            dist = 1.2 + reach * t
            cx, cz = ox + math.cos(turn) * dist, oz + math.sin(turn) * dist
            radius = 0.55 * (1.0 - t) + 0.12
            lift = math.sin(t * math.pi) * 0.45 + (1.0 - t) * 0.9
            cy = hill_height(cx, cz) + lift - radius * 0.6
            side = (-math.sin(turn), math.cos(turn))
            ring = [(cx + side[0] * math.cos(math.tau * j / 7) * radius, cy + math.sin(math.tau * j / 7) * radius, cz + side[1] * math.cos(math.tau * j / 7) * radius) for j in range(7)]
            if prev_ring:
                for j in range(7):
                    roots.face([prev_ring[j], prev_ring[(j + 1) % 7], ring[(j + 1) % 7], ring[j]], "darkwood")
            prev_ring = ring
    roots.done()


def undergrowth(wood):
    """The wood's floor, a Pacific Northwest understory: sword ferns, salal and huckleberry bushes, nurse logs (solid:
    fallen trees with seedlings and moss along them), tall grass to hide in (World grows it)."""
    rng = random.Random(77)
    ferns = w1.Piece("nocol_ferns")
    bushes = w1.Piece("nocol_salal")

    def clear(x, z, room):
        deg = math.degrees(math.atan2(z, x)) % 360.0
        return not (55.0 < deg < 110.0 or path_distance(x, z) < 1.6 or any(math.hypot(x - t[0], z - t[1]) < room for t in wood)
                    or any(math.hypot(x - gx, z - gz) < 1.8 for gx, gz in GIANTS))

    placed = 0
    for _try in range(1400):
        if placed >= 150:
            break
        a, r = rng.uniform(0.0, math.tau), rng.uniform(PLATEAU + 1.5, WALL_R - 1.0)
        x, z = math.cos(a) * r, math.sin(a) * r
        if not clear(x, z, 0.9):
            continue
        placed += 1
        y = hill_height(x, z) - 0.05
        for k in range(8):
            lean = math.tau * k / 8 + rng.uniform(-0.3, 0.3)
            reach = rng.uniform(0.6, 1.1)
            d = (math.cos(lean), math.sin(lean))
            side = (-d[1] * 0.1, d[0] * 0.1)
            mid = (x + d[0] * reach * 0.5, y + reach * 0.5, z + d[1] * reach * 0.5)
            tip = (x + d[0] * reach, y + reach * 0.2, z + d[1] * reach)
            ferns.face([(x, y, z), (mid[0] + side[0], mid[1], mid[2] + side[1]), tip, (mid[0] - side[0], mid[1], mid[2] - side[1])], "fern")
    # salal and huckleberry: low leafy mounds of crossed cards, huckleberries red-spotted
    placed = 0
    for _try in range(900):
        if placed >= 60:
            break
        a, r = rng.uniform(0.0, math.tau), rng.uniform(PLATEAU + 2.0, WALL_R - 1.0)
        x, z = math.cos(a) * r, math.sin(a) * r
        if not clear(x, z, 1.1):
            continue
        placed += 1
        y = hill_height(x, z) - 0.05
        size = rng.uniform(0.5, 0.9)
        mat = "salal" if placed % 3 else "huckleberry"
        for k in range(3):
            t = math.pi * k / 3 + rng.uniform(0.0, 0.5)
            dx, dz = math.cos(t) * size, math.sin(t) * size
            bushes.face([(x - dx, y, z - dz), (x + dx, y, z + dz), (x + dx * 0.7, y + size * 1.1, z + dz * 0.7), (x - dx * 0.7, y + size * 1.1, z - dz * 0.7)], mat)
        bushes.face([(x - size, y + size * 0.7, z), (x, y + size * 0.75, z - size), (x + size, y + size * 0.7, z), (x, y + size * 0.75, z + size)], mat, 1.1)
        if mat == "huckleberry":
            for k in range(3):
                bushes.box((x + rng.uniform(-size, size) * 0.5, y + size * 0.8, z + rng.uniform(-size, size) * 0.5), (0.07, 0.07, 0.07), "berry")
    ferns.done()
    bushes.done()
    # nurse logs: old fallen trees lying among the rows, moss along their tops, seedlings growing out of them
    for n, (deg, r) in enumerate(((140.0, 43.0), (252.0, 46.5), (305.0, 41.5), (20.0, 47.5), (200.0, 43.5), (120.0, 49.5), (340.0, 49.0))):
        a = math.radians(deg)
        x, z = math.cos(a) * r, math.sin(a) * r
        if path_distance(x, z) < 3.0 or any(math.hypot(x - gx, z - gz) < 5.0 for gx, gz in GIANTS):
            continue
        log = w1.Piece("fallen_log_%d" % n)
        moss = w1.Piece("nocol_log_moss_%d" % n)
        along = (-math.sin(a + 0.4), math.cos(a + 0.4))
        y = hill_height(x, z) + 0.4
        half, rad = 2.8, 0.45
        ring = [(math.cos(math.tau * i / 8) * rad, math.sin(math.tau * i / 8) * rad) for i in range(8)]

        def pt(t, c):
            return (x + along[0] * t + along[1] * c[0], y + c[1], z + along[1] * t - along[0] * c[0])
        for i in range(8):
            c0, c1 = ring[i], ring[(i + 1) % 8]
            log.face([pt(-half, c0), pt(half, c0), pt(half, c1), pt(-half, c1)], "darkwood")
            if c0[1] > 0.1 and c1[1] > 0.1:
                moss.face([pt(-half + 0.3, (c0[0] * 1.05, c0[1] * 1.05)), pt(half - 0.3, (c0[0] * 1.05, c0[1] * 1.05)),
                           pt(half - 0.3, (c1[0] * 1.05, c1[1] * 1.05)), pt(-half + 0.3, (c1[0] * 1.05, c1[1] * 1.05))], "moss")
        log.face([pt(-half, c) for c in ring], "wood")
        log.face([pt(half, c) for c in ring][::-1], "wood")
        log.done()
        moss.done()
        for s in (-1.4, 0.6):
            sx, sy, sz = pt(s, (0.0, rad))
            w1.mark("treep_%d_%d_%d_firlo" % (900 + n * 2 + (s > 0), 911 + n * 5, 18 + n % 3 * 4), (sx, sy - 0.05, sz))
    for n, (deg, r) in enumerate(((130.0, 45.0), (230.0, 49.0), (10.0, 43.0), (300.0, 47.0))):
        a = math.radians(deg)
        x, z = math.cos(a) * r, math.sin(a) * r
        empty = w1.mark("tallgrass_wood%d" % n, (x, hill_height(x, z), z))
        empty.scale = (2.5, 2.5, 2.5)


def path_point(t):
    """The path that winds up the hill, from the south foot (t 0) to the top (t 1)."""
    a = math.pi * 0.5 + t * math.tau * 0.95
    r = HILL_FOOT - (HILL_FOOT - PLATEAU) * t
    return math.cos(a) * r, math.sin(a) * r


def path_distance(x, z):
    """How far (x, z) is from the path that winds up the hill."""
    return min(math.dist((x, z), path_point(k / 79.0)) for k in range(80))


class PaintPiece(w1.Piece):
    """A piece whose faces carry colours of their own in their vertex colours (and texture coordinates if given)."""

    def paint(self, points, mat, colours, uvs=None):
        made = self.face(points, mat)
        for loop, c in zip(made.loops, colours):
            loop[self.colour] = (c[0], c[1], c[2], 1.0)
        if uvs:
            for loop, uv in zip(made.loops, uvs):
                loop[self.uv].uv = uv
        return made

    def done(self):
        # (its colours are the paint: made the render colour too, or the glTF export writes a white COLOR_0 and the
        # paint as COLOR_1, which Godot does not read)
        obj = super().done()
        obj.data.color_attributes.render_color_index = obj.data.color_attributes.active_color_index
        return obj


class Frame:
    """A lot's own directions: u along the road (anticlockwise), v out from the town's middle, y up; its origin on
    the ring of radius `r` at angle `a`."""

    def __init__(self, a, r, y=0.0):
        self.a, self.r, self.y = a, r, y
        self.along = (-math.sin(a), math.cos(a))
        self.out = (math.cos(a), math.sin(a))
        self.ox, self.oz = self.out[0] * r, self.out[1] * r

    @classmethod
    def at(cls, x, z, a, y=0.0):
        """A frame with its origin at (x, z), `out` pointing at angle a."""
        frame = cls(a, 0.0, y)
        frame.ox, frame.oz = x, z
        return frame

    def p(self, u, y, v):
        cx, cz = self.ox, self.oz
        return (cx + u * self.along[0] + v * self.out[0], self.y + y, cz + u * self.along[1] + v * self.out[1])

    def box(self, piece, u, v, su, sy, sv, mat, base=0.0, top=None, shade=1.0):
        """A box centred on (u, v), su along by sv out, from `base` up `sy`."""
        c = [self.p(u + iu * su / 2, base + (sy if iy else 0.0), v + iv * sv / 2) for iu in (-1, 1) for iy in (0, 1) for iv in (-1, 1)]
        quads = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        for k, q in enumerate(quads):
            m = top if (top and k == 3) else mat
            piece.face([c[i] for i in q], m, shade * (1.08 if k == 3 else 0.86 if k in (0, 1) else 0.95))

    def hip_roof(self, piece, u, v, w, d, eave, rise, mat, over=0.5):
        """A hipped roof (four slopes) over a w by d block centred on (u, v), its ridge along u."""
        hw, hd = w / 2 + over, d / 2 + over
        drop = rise * over / (d / 2)
        lo = eave - drop
        ridge = eave + rise
        inset = max(hw - hd, 0.2)
        a, b, c, e = self.p(u - hw, lo, v - hd), self.p(u + hw, lo, v - hd), self.p(u + hw, lo, v + hd), self.p(u - hw, lo, v + hd)
        r0, r1 = self.p(u - inset, ridge, v), self.p(u + inset, ridge, v)
        piece.face([a, b, r1, r0], mat, 1.05)
        piece.face([c, e, r0, r1], mat, 0.9)
        piece.face([b, c, r1], mat, 0.95)
        piece.face([e, a, r0], mat, 0.95)
        # its underside, a little below
        under = [self.p(u - hw, lo - 0.12, v - hd), self.p(u + hw, lo - 0.12, v - hd), self.p(u + hw, lo - 0.12, v + hd), self.p(u - hw, lo - 0.12, v + hd)]
        piece.face(under, "darkwood", 0.6)
        return ridge


def ground():
    """The hill and the flat round it as far as the lots, with the road and pavements laid over."""
    piece = w1.Piece("ground")
    step = 1.0
    edge = HILL_EDGE + 3.0
    span = int(edge * 2 / step)
    heights = {}

    def h(i, j):
        if (i, j) not in heights:
            x, z = -edge + i * step, -edge + j * step
            heights[(i, j)] = hill_height(x, z) if math.hypot(x, z) < HILL_FOOT + 0.5 else ground_global(x, z)
        return heights[(i, j)]

    for i in range(span):
        for j in range(span):
            xa, za = -edge + i * step, -edge + j * step
            xb, zb = xa + step, za + step
            xm, zm = xa + step / 2, za + step / 2
            r = math.hypot(xm, zm)
            # (the hilltop's own squares: those whose 2 m square (hill_grid's) has its middle within 67 m; under
            # the lots only by the road, where the street leaves, and behind them)
            parent = (math.floor(xm / 2.0) * 2.0 + 1.0, math.floor(zm / 2.0) * 2.0 + 1.0)
            if math.hypot(*parent) >= HILL_EDGE + 1.0 or not (r <= LOT[0] + 1.0 or in_gap(xm, zm) or r >= LOT[1] - 1.5):
                continue
            pts = [(xa, h(i, j), za), (xa, h(i, j + 1), zb), (xb, h(i + 1, j + 1), zb), (xb, h(i + 1, j), za)]
            if r < HILL_FOOT + 1.0:
                low = min(p[1] for p in pts)
                mat = "dirt" if (path_distance(xm, zm) < 1.3 or low < HILL_TOP - 1.0 and r < PLATEAU) else "grass"
            else:
                mat = "grass"
            piece.face(pts, mat)
    # The road and the pavements as smooth rings over the grass (the grid would step their edges), the pavements
    # a kerb higher
    rings = w1.Piece("road")
    for r0, r1, y, mat in ((ROAD[0], ROAD[1], 0.02, "asphalt"), (ROAD[0] - PAVE, ROAD[0], 0.12, "concrete"),
                           (ROAD[1], ROAD[1] + PAVE, 0.12, "concrete")):
        segs = 96
        for k in range(segs):
            a0, a1 = math.tau * k / segs, math.tau * (k + 1) / segs
            if r0 == ROAD[1] and min(abs(((a0 + a1) / 2 - e + math.pi) % math.tau - math.pi) for e in (0.0, math.pi / 2, math.pi, 3 * math.pi / 2)) < 0.2:
                continue  # (the pavement opens where each street goes down the hill)
            quad = [(math.cos(a0) * r0, y, math.sin(a0) * r0), (math.cos(a1) * r0, y, math.sin(a1) * r0),
                    (math.cos(a1) * r1, y, math.sin(a1) * r1), (math.cos(a0) * r1, y, math.sin(a0) * r1)]
            rings.face(quad, mat)
            if y > 0.05:
                for r in (r0, r1):
                    rings.face([(math.cos(a0) * r, 0.0, math.sin(a0) * r), (math.cos(a1) * r, 0.0, math.sin(a1) * r),
                                (math.cos(a1) * r, y, math.sin(a1) * r), (math.cos(a0) * r, y, math.sin(a0) * r)], "concrete", 0.85)
    rings.done()
    # its markings (the user, 2026-11-02: "the road needs lines painted on it"): a dashed centre line, edge lines,
    # the outer one open where each street leaves (only to look at)
    paint = w1.Piece("nocol_ring_paint")
    segs = 240
    exits = (0.0, math.pi / 2, math.pi, 3 * math.pi / 2)
    for k in range(segs):
        a0, a1 = math.tau * k / segs, math.tau * (k + 1) / segs
        near_exit = min(abs(((a0 + a1) / 2 - e + math.pi) % math.tau - math.pi) for e in exits) < 0.22
        bands = [(ROAD[0] + 0.3, ROAD[0] + 0.45)]
        if k % 2 == 0:
            bands.append((ROAD_MIDDLE - 0.08, ROAD_MIDDLE + 0.08))
        if not near_exit:
            bands.append((ROAD[1] - 0.45, ROAD[1] - 0.3))
        for r0, r1 in bands:
            paint.face([_ring_point(a0, r0, 0.035), _ring_point(a1, r0, 0.035), _ring_point(a1, r1, 0.035), _ring_point(a0, r1, 0.035)], "white")
    paint.done()
    return piece.done()


def _ring_point(a, r, y):
    return (math.cos(a) * r, y, math.sin(a) * r)


def lots():
    """Each lot a terrace held up by a block wall by the road, steps up to it from the pavement, its back edge the
    brink of the drop to the town below (a rail along it)."""
    rails = w1.Piece("nocol_rails")
    for k, (kind, height) in enumerate(LOTS):
        a0, a1 = math.tau * (k - 0.5) / SECTORS, math.tau * (k + 0.5) / SECTORS
        top = "concrete" if kind == "commercial" else "grass"
        wall = "blockwall" if height > 0.3 else "concrete"
        piece = w1.Piece("lot_%d" % k)
        segs = 8
        for s in range(segs):
            if kind == "road":
                break
            b0, b1 = a0 + (a1 - a0) * s / segs, a0 + (a1 - a0) * (s + 1) / segs
            mid_r = (LOT[0] + LOT[1]) / 2
            for r0, r1 in ((LOT[0], mid_r), (mid_r, LOT[1])):
                piece.face([_ring_point(b0, r0, height), _ring_point(b1, r0, height), _ring_point(b1, r1, height), _ring_point(b0, r1, height)], top if r0 < mid_r else "grass")
            # the wall by the road
            piece.face([_ring_point(b0, LOT[0], -0.1), _ring_point(b1, LOT[0], -0.1), _ring_point(b1, LOT[0], height), _ring_point(b0, LOT[0], height)], wall, 0.95)
            # the drop at the back, down to the next terrace below
            piece.face([_ring_point(b0, LOT[1], height), _ring_point(b1, LOT[1], height), _ring_point(b1, LOT[1], height - 7.0), _ring_point(b0, LOT[1], height - 7.0)], "blockwall", 0.9)
            # the rail along the brink
            for r_rail in (BOUND - 0.15,):
                for y_rail in (0.55, 1.05):
                    lo = _ring_point(b0, r_rail, height + y_rail)
                    hi = _ring_point(b1, r_rail, height + y_rail)
                    _bar(rails, lo, hi, 0.05, "rail")
                post = _ring_point(b0, r_rail, height)
                _bar(rails, post, (post[0], post[1] + 1.1, post[2]), 0.06, "rail")
        # the wall between this lot and the next, the height between them
        nxt = LOTS[(k + 1) % SECTORS][1]
        lo, hi = min(height, nxt), max(height, nxt)
        if hi - lo > 0.05:
            piece.face([_ring_point(a1, LOT[0], lo), _ring_point(a1, LOT[1], lo), _ring_point(a1, LOT[1], hi), _ring_point(a1, LOT[0], hi)],
                       "blockwall" if hi - lo > 0.3 else "concrete", 0.92)
        piece.done()
        if height > 0.3:
            _steps(k, a0, height)
    rails.done()


def _bar(piece, a, b, thick, mat):
    """A thin square bar from a to b (for rails, wires, handrails)."""
    d = Vector(b) - Vector(a)
    if d.length < 1e-6:
        return
    side = d.cross(Vector((0, 1, 0)))
    if side.length < 1e-6:
        side = Vector((1, 0, 0))
    side = side.normalized() * thick / 2
    up = side.cross(d).normalized() * thick / 2
    va, vb = Vector(a), Vector(b)
    corners = [side + up, -side + up, -side - up, side - up]
    for i in range(4):
        c0, c1 = corners[i], corners[(i + 1) % 4]
        piece.face([tuple(va + c0), tuple(vb + c0), tuple(vb + c1), tuple(va + c1)], mat)


def _steps(k, a0, height):
    """Concrete steps up the face of the wall from the pavement, along it, with a handrail on the road side."""
    count = max(2, math.ceil(height / 0.2))
    rise = height / count
    run = 0.32
    r = LOT[0] - 0.55
    piece = w1.Piece("steps_%d" % k)
    rail = w1.Piece("nocol_handrail_%d" % k)
    start = a0 + 0.035
    for i in range(count):
        a = start + (i + 0.5) * run / r
        frame = Frame(a, r)
        frame.box(piece, 0.0, 0.0, run + 0.02, (i + 1) * rise, 0.98, "concrete")
    a_end = start + count * run / r
    p0 = _ring_point(start, r - 0.5, 0.9)
    p1 = _ring_point(a_end, r - 0.5, height + 0.9)
    _bar(rail, p0, p1, 0.06, "metal")
    for a, y in ((start, 0.0), (a_end, height)):
        post = _ring_point(a, r - 0.5, y)
        _bar(rail, post, (post[0], post[1] + 0.9, post[2]), 0.06, "metal")
    piece.done()
    rail.done()
    return a_end


def window(frame, piece, u, v_face, w, h, base, out=-1.0, sill=True):
    """A window in the wall at v_face (its outside towards `out`): a white frame, the glass set in it, a bar down the
    middle (sliding panes), a sill."""
    frame.box(piece, u, v_face + out * 0.04, w + 0.18, h + 0.18, 0.08, "white", base=base - 0.09)
    frame.box(piece, u, v_face + out * 0.09, w, h, 0.04, "glass", base=base)
    frame.box(piece, u, v_face + out * 0.12, 0.06, h, 0.03, "white", base=base)
    if sill:
        frame.box(piece, u, v_face + out * 0.14, w + 0.3, 0.07, 0.22, "white", base=base - 0.16)


def laundry(frame, line, u0, u1, v, y, rng):
    """A laundry pole across a balcony, with a few things hung on it (only to look at)."""
    _bar(line, frame.p(u0, y, v), frame.p(u1, y, v), 0.04, "metal")
    colours = ("white", "awning", "vend_blue", "red", "pampas", "white")
    u = u0 + 0.2
    while u < u1 - 0.5:
        wide = rng.uniform(0.35, 0.7)
        drop = rng.uniform(0.45, 0.8)
        line.face([frame.p(u, y - 0.02, v), frame.p(u + wide, y - 0.02, v), frame.p(u + wide, y - drop, v), frame.p(u, y - drop, v)], rng.choice(colours))
        u += wide + rng.uniform(0.15, 0.5)


def garden_wall(frame, piece, v_front, half, back_to, gate=1.6, tall=1.1):
    """A block wall round the front garden, open at the gate (two pillars), its capped top a path to run along."""
    for u0, u1 in ((-half, -gate / 2), (gate / 2, half)):
        frame.box(piece, (u0 + u1) / 2, v_front, u1 - u0, tall, 0.16, "blockwall")
        frame.box(piece, (u0 + u1) / 2, v_front, u1 - u0, 0.08, 0.24, "concrete", base=tall)
    for su in (-1, 1):
        frame.box(piece, su * half, (v_front + back_to) / 2, 0.16, tall, back_to - v_front, "blockwall")
        frame.box(piece, su * half, (v_front + back_to) / 2, 0.24, 0.08, back_to - v_front, "concrete", base=tall)
        frame.box(piece, su * (gate / 2 + 0.18), v_front, 0.36, tall + 0.35, 0.36, "concrete")


def _half_round(piece, frame, a, b, out, y, radius=0.075):
    """A half-round gutter from a to b (frame u, v), open at the top, its middle `out` (unit u, v) beyond the line."""
    ring = [(math.cos(math.pi * i / 6) * radius, -math.sin(math.pi * i / 6) * radius) for i in range(7)]
    for (o0, y0), (o1, y1) in zip(ring, ring[1:]):
        quad = [frame.p(a[0] + out[0] * (radius + o0), y + y0, a[1] + out[1] * (radius + o0)),
                frame.p(b[0] + out[0] * (radius + o0), y + y0, b[1] + out[1] * (radius + o0)),
                frame.p(b[0] + out[0] * (radius + o1), y + y1, b[1] + out[1] * (radius + o1)),
                frame.p(a[0] + out[0] * (radius + o1), y + y1, a[1] + out[1] * (radius + o1))]
        piece.face(quad, "zinc", 0.95)


def gutters(piece, frame, u, v, w, d, eave, rise, over):
    """Half-round gutters all round a hipped roof's eaves (the roof hip_roof drew), their lips at its edge. Returns
    the edge's height."""
    edge = eave - rise * over / (d / 2)
    hw, hd = w / 2 + over, d / 2 + over
    corners = [(u - hw, v - hd), (u + hw, v - hd), (u + hw, v + hd), (u - hw, v + hd)]
    outs = [(0.0, -1.0), (1.0, 0.0), (0.0, 1.0), (-1.0, 0.0)]
    for k in range(4):
        _half_round(piece, frame, corners[k], corners[(k + 1) % 4], outs[k], edge + 0.01)
    return edge


def _prism(piece, frame, u, v, n, t, profile, half):
    """A solid from a profile (out from the wall, up) drawn along the wall `half` either side of (u, v)."""
    def at(o, y, side):
        return frame.p(u + n[0] * o + t[0] * side, y, v + n[1] * o + t[1] * side)

    piece.face([at(o, y, -half) for o, y in profile], "concrete")
    piece.face([at(o, y, half) for o, y in profile][::-1], "concrete")
    for (o0, y0), (o1, y1) in zip(profile, profile[1:] + profile[:1]):
        piece.face([at(o0, y0, -half), at(o1, y1, -half), at(o1, y1, half), at(o0, y0, half)], "concrete")


def _column(piece, frame, u, v, n, t, centres, radius=0.16):
    """A round column through `centres` ((out from the wall, up) at the wall point (u, v)), its rings level."""
    sides = 8
    rings = []
    for o, y in centres:
        rings.append([frame.p(u + n[0] * (o + math.cos(math.tau * i / sides) * radius) + t[0] * math.sin(math.tau * i / sides) * radius, y,
                              v + n[1] * (o + math.cos(math.tau * i / sides) * radius) + t[1] * math.sin(math.tau * i / sides) * radius)
                      for i in range(sides)])
    for r0, r1 in zip(rings, rings[1:]):
        for i in range(sides):
            piece.face([r0[i], r0[(i + 1) % sides], r1[(i + 1) % sides], r1[i]], "concrete")
    piece.face(rings[0], "concrete")
    piece.face(rings[-1][::-1], "concrete")


def downpipes(name, frame, spots):
    """Drainpipes (the user, 2026-11-02: "there needs to be drains and gutter pipes to scurry up"; "the gutters dont
    look like gutters, and should be up against the side of the buildings, and need to be easier to climb"): a round
    zinc pipe 9 cm across a few centimetres off the wall, clamped to it by a bracket every metre, a swan neck out to
    the gutter at the top, a shoe at the foot over a drain grate. `spots`: (u, v, nu, nv, edge, over): where on a
    wall (frame u, v), the wall's outward normal, the height of the roof's edge (or the parapet's top) and how far
    the edge stands out from the wall (0 for a flush parapet).

    What he climbs is an unseen round column 32 cm across round the pipe, ground to roof (climb_..._hidden: World
    makes it climbable and hides it): fatter than the pipe so Scurry's probe always has it; under eaves it leans out
    with the swan neck to beyond their edge, so whichever side of it he holds he comes out past the overhang (not
    stuck under it) and hops over onto the roof."""
    seen = w1.Piece("nocol_pipes_" + name)
    feel = w1.Piece("climb_pipes_%s_hidden" % name)
    radius, off = 0.045, 0.075
    for u, v, nu, nv, edge, over in spots:
        n, t = (nu, nv), (-nv, nu)
        cu, cv = u + nu * off, v + nv * off
        top = edge - 0.35 - over * 0.6 if over > 0.0 else edge - 0.1
        seen.cylinder(frame.p(cu, 0.25, cv), radius, top - 0.25, "zinc", 8)
        if over > 0.0:
            # the swan neck out under the eaves to the gutter's outlet
            outlet = (u + nu * (over + 0.075), v + nv * (over + 0.075))
            _bar(seen, frame.p(cu, top, cv), frame.p(outlet[0], edge - 0.16, outlet[1]), 0.08, "zinc")
            _bar(seen, frame.p(outlet[0], edge - 0.2, outlet[1]), frame.p(outlet[0], edge - 0.02, outlet[1]), 0.08, "zinc")
        else:
            # a hopper at the parapet's top
            frame.box(seen, cu, cv, 0.2, 0.2, 0.2, "zinc", base=top - 0.2)
        # brackets
        y = 0.7
        while y < top - 0.2:
            frame.box(seen, u + nu * 0.04, v + nv * 0.04, 0.08 if nu else 0.13, 0.04, 0.13 if nu else 0.08, "zinc", base=y)
            y += 1.0
        # the shoe, and the grate it pours onto
        _bar(seen, frame.p(cu, 0.3, cv), frame.p(cu + nu * 0.16, 0.1, cv + nv * 0.16), 0.085, "zinc")
        frame.box(seen, u + nu * 0.3, v + nv * 0.3, 0.34, 0.03, 0.34, "black", base=0.0)
        # what he climbs
        if over > 0.2:
            _column(feel, frame, u, v, n, t, [(0.17, 0.0), (0.17, edge - 2.4), (over + 0.7, edge - 0.9), (over + 0.7, edge + 0.05)])
        else:
            _column(feel, frame, u, v, n, t, [(0.2, 0.0), (0.2, edge + 0.05)])
    seen.done()
    feel.done()


def made_at_origin(kind, name, seed, crumbs=3):
    """One of tools/buildings.py's buildings (the user, 2026-11-02: "a house generator that can function as a mini
    level generator essentially") built at the origin, facing +z (its street side), to be set in place with set_made.
    `kind` may also be "barn" (the Rural farm's, built here)."""
    before = set(bpy.data.objects)
    if kind == "barn":
        made = barn(name, Frame.at(0.0, 0.0, -math.pi / 2, 0.0))
    else:
        made = buildings.make(kind, name, 0.0, 0.0, 0.0, 0.0, seed, marks=True, crumbs=crumbs)
    made["objs"] = list(set(bpy.data.objects) - before)
    made["kind"] = kind
    x0, z0, x1, z1 = made["bounds"]
    made["width"], made["depth"] = x1 - x0, z1 - z0
    return made


def drop_made(made):
    """Takes away a building that found no place."""
    for obj in made["objs"]:
        data = obj.data
        bpy.data.objects.remove(obj)
        if data is not None and data.users == 0:
            bpy.data.meshes.remove(data)


def set_made(made, fx, fz, out, y):
    """Sets a building made at the origin in place: its street side on the line across `out` (the way from the road
    into its lot, an angle across the ground) through (fx, fz), its middle there, standing at height y. Its route's top
    and a `place` (its own frame's points to the world's) go into `made`."""
    x0, z0, x1, z1 = made["bounds"]
    t = math.atan2(-math.cos(out), -math.sin(out))
    c, s = math.cos(t), math.sin(t)
    xm = (x0 + x1) / 2
    ox = fx + math.cos(out) * z1 - xm * c
    oz = fz + math.sin(out) * z1 + xm * s
    for obj in made["objs"]:
        bx, by = obj.location.x, obj.location.y
        obj.location.x, obj.location.y = bx * c - by * s + ox, bx * s + by * c - oz
        obj.location.z += y
        obj.rotation_euler.z += t

    def place(p):
        return (ox + p[0] * c + p[2] * s, y + p[1], oz - p[0] * s + p[2] * c)

    made["place"] = place
    made["at"] = place(made["top"])
    made["front"] = (fx, fz, out, y)
    return made


def barn(name, frame):
    """A red barn (the Rural zone's farm): a gambrel roof, big doors, a hayloft door high in its gable end with a
    ledge inside it; hay bales stacked up to it. Returns it as buildings.make does (bounds, top) in `frame`'s terms."""
    piece = w1.Piece(name)
    w, d, eave = 12.0, 16.0, 4.2
    frame.box(piece, 0.0, d / 2, w, eave, d, "shopred")
    knee_u, knee_y, ridge_y = w / 2 * 0.72, eave + 3.0, eave + 4.4
    profile = [(-w / 2 - 0.4, eave - 0.2), (-knee_u, knee_y), (0.0, ridge_y), (knee_u, knee_y), (w / 2 + 0.4, eave - 0.2)]
    for i in range(4):
        (u0, y0), (u1, y1) = profile[i], profile[i + 1]
        piece.face([frame.p(u0, y0, -0.4), frame.p(u1, y1, -0.4), frame.p(u1, y1, d + 0.4), frame.p(u0, y0, d + 0.4)], "roof3")
    for vv in (0.0, d):
        gable = [frame.p(-w / 2, eave, vv), frame.p(-knee_u, knee_y, vv), frame.p(0.0, ridge_y, vv), frame.p(knee_u, knee_y, vv), frame.p(w / 2, eave, vv)]
        piece.face(gable if vv else gable[::-1], "shopred", 0.95)
    frame.box(piece, 0.0, -0.05, 4.4, 3.6, 0.12, "white")
    frame.box(piece, 0.0, -0.06, 4.0, 3.4, 0.12, "shopred")
    frame.box(piece, 0.0, -0.05, 1.6, 1.6, 0.12, "black", base=eave + 0.6)
    frame.box(piece, 0.0, -0.45, 1.8, 0.15, 0.9, "wood", base=eave + 0.5)
    piece.done()
    bales = w1.Piece(name + "_bales")
    for k, (bu, bv) in enumerate(((-3.6, -2.4), (-2.4, -2.4), (-2.4, -1.4))):
        frame.box(bales, bu, bv, 1.2, 1.2 * (k + 1), 1.0, "straw")
    bales.done()
    top = frame.p(0.0, eave + 0.65, -0.45)
    return {"name": name, "bounds": (-w / 2 - 0.5, -d - 0.5, w / 2 + 0.5, 3.0), "top": top, "route": [], "problems": []}


def buildings_ring():
    """What stands on each lot (a generated building, its street side by the lot's front wall), trash cans beside it.
    Returns each lot's Frame (u along the road, v out) for the markers."""
    frames = {}
    for k, (kind, height) in enumerate(LOTS):
        a = math.tau * k / SECTORS
        if kind == "road":
            continue
        made = made_at_origin(kind, "%s_%d" % ("flats" if kind == "walkup" else kind, k), 40 + k)
        set_made(made, math.cos(a) * (LOT[0] + 0.8), math.sin(a) * (LOT[0] + 0.8), a, height)
        frame = Frame(a, FRONT, height)
        frame.made = made
        frames[k] = frame
        for du in (13.0, 13.8):
            w1.can(frame.p(-du, 0.0, 1.0))
    return frames


def poles_and_wires(frames):
    """Wooden power poles round the outer pavement with crossarms and transformers, the phone line strung from each
    to the next (the wires he walks), the power lines above it (wires too)."""
    poles = w1.Piece("climb_poles")
    things = w1.Piece("pole_things")
    count = 20
    r = ROAD[1] + 1.2
    tops = []
    arms = []
    for k in range(count):
        a = math.tau * (k + 0.5) / count
        x, z = math.cos(a) * r, math.sin(a) * r
        poles.cylinder((x, 0.0, z), 0.18, 8.2, "pole", 8)
        frame = Frame(a, r)
        frame.box(things, 0.0, 0.0, 1.8, 0.14, 0.14, "pole", base=7.6)
        if k % 2 == 0:
            c = frame.p(0.0, 5.3, 0.38)
            things.cylinder(c, 0.26, 0.9, "metal", 8)
        tops.append((x, 6.48, z))
        if k == 0:
            # (the smoke test scurries up this one: a step from it, facing it)
            w1.mark("smoke_pole", (x + 0.15, 0.15, z - 1.2))
        arms.append((frame.p(-0.8, 7.78, 0.0), frame.p(0.8, 7.78, 0.0)))
    for k in range(count):
        w1.wire(tops[k], tops[(k + 1) % count], 4)
        # (the power lines above, wires he walks too: the user, 2026-11-02, "you phase through half the wires")
        for side in (0, 1):
            w1.wire(arms[k][side], arms[(k + 1) % count][side])
    poles.done()
    things.done()


# --- Street furniture (the user, 2026-11-02: "there needs to be street lights", "stop signs, street lights",
# "telephone booths", "covered bus stops", "benches"). Every post is climbable and named for a pole (PointPerches
# finds its top for the handstand). Styles by zone are Claude's picks.

_furn_count = {"lamp": 0, "signal": 0, "busstop": 0, "bench": 0, "booth": 0, "stop": 0}


def _facing_turn(facing):
    """A marker's turn so its -Z points along `facing` (a way across the ground)."""
    return math.atan2(-facing[0], -facing[1])


class Furniture:
    """One area's street furniture, its parts batched into a few meshes: climbable posts (climb_..._pole), solid
    parts, parts only to look at."""

    def __init__(self, tag):
        self.tag = tag
        self.poles = w1.Piece("climb_street_pole_" + tag)
        self.solid = w1.Piece("street_things_" + tag)
        self.see = w1.Piece("nocol_street_things_" + tag)

    def done(self):
        self.poles.done()
        self.solid.done()
        self.see.done()

    def _f(self, at, facing):
        """A frame at `at` whose u runs across `facing` and v along it (v>0 the way it faces)."""
        a = math.atan2(facing[1], facing[0])
        return Frame.at(at[0], at[2], a, at[1])

    def light(self, at, facing, style):
        """A street light on the pavement at `at`, its head out over the road the way `facing` points. Styles: cobra
        (a grey pole, an arm out, a cobra head), ornament (a black lamp post with a lantern), work (a floodlight
        stand), lantern (a short wooden post with a lantern, for the grove's paths). Its lens is "streetlamp";
        streetlamp_<n> marks the head just under it."""
        f = self._f(at, facing)
        n = _furn_count["lamp"]
        _furn_count["lamp"] += 1
        if style == "cobra":
            self.poles.cylinder(f.p(0.0, 0.0, 0.0), 0.13, 8.4, "lamp_grey", 8)
            _bar(self.solid, f.p(0.0, 7.7, 0.0), f.p(0.0, 8.1, 1.2), 0.1, "lamp_grey")
            _bar(self.solid, f.p(0.0, 8.1, 1.2), f.p(0.0, 8.15, 2.2), 0.1, "lamp_grey")
            f.box(self.solid, 0.0, 2.6, 0.45, 0.22, 1.0, "lamp_grey", base=8.0)
            f.box(self.solid, 0.0, 2.65, 0.36, 0.04, 0.7, "streetlamp", base=7.97)
            head = f.p(0.0, 7.9, 2.65)
        elif style == "ornament":
            self.poles.cylinder(f.p(0.0, 0.0, 0.0), 0.09, 4.0, "black", 8)
            self.solid.cylinder(f.p(0.0, 0.0, 0.0), 0.22, 0.6, "black", 8)
            f.box(self.solid, 0.0, 0.0, 0.5, 0.06, 0.5, "black", base=4.0)
            f.box(self.see, 0.0, 0.0, 0.38, 0.6, 0.38, "streetlamp", base=4.06)
            f.box(self.see, 0.0, 0.0, 0.56, 0.08, 0.56, "black", base=4.66)
            self.see.cylinder(f.p(0.0, 4.74, 0.0), 0.08, 0.25, "black", 6)
            head = f.p(0.0, 4.2, 0.0)
        elif style == "work":
            for k in range(3):
                t = math.tau * k / 3
                _bar(self.solid, f.p(math.cos(t) * 0.7, 0.0, math.sin(t) * 0.7), f.p(0.0, 1.4, 0.0), 0.06, "safety")
            self.poles.cylinder(f.p(0.0, 0.0, 0.0), 0.07, 4.2, "safety", 6)
            f.box(self.solid, 0.0, 0.0, 1.2, 0.08, 0.08, "safety", base=3.9)
            for u in (-0.45, 0.45):
                f.box(self.solid, u, 0.15, 0.4, 0.3, 0.2, "black", base=3.75)
                f.box(self.solid, u, 0.26, 0.34, 0.24, 0.02, "streetlamp", base=3.78)
            head = f.p(0.0, 3.8, 0.4)
        else:
            self.poles.box(f.p(0.0, 1.2, 0.0), (0.16, 2.4, 0.16), "darkwood")
            _bar(self.solid, f.p(0.0, 2.2, 0.0), f.p(0.0, 2.2, 0.45), 0.06, "black")
            f.box(self.see, 0.0, 0.45, 0.24, 0.32, 0.24, "streetlamp", base=1.8)
            f.box(self.see, 0.0, 0.45, 0.32, 0.06, 0.32, "black", base=2.12)
            head = f.p(0.0, 1.9, 0.45)
        w1.mark("streetlamp_%d" % n, head)

    def stop_sign(self, at, facing, line=None):
        """A red octagonal stop sign on a post, its face the way `facing` points (to the traffic coming); `line`
        ((a, b) two points across the lane) a painted stop line."""
        f = self._f(at, facing)
        _furn_count["stop"] += 1
        self.poles.cylinder(f.p(0.0, 0.0, 0.0), 0.05, 2.6, "metal", 6)
        ring = [f.p(math.cos(math.tau * (i + 0.5) / 8) * 0.38, 2.2 + math.sin(math.tau * (i + 0.5) / 8) * 0.38, 0.07) for i in range(8)]
        self.solid.face(ring, "stop_red")
        self.solid.face([f.p(math.cos(math.tau * (i + 0.5) / 8) * 0.38, 2.2 + math.sin(math.tau * (i + 0.5) / 8) * 0.38, 0.04) for i in range(8)][::-1], "metal")
        f.box(self.see, 0.0, 0.08, 0.5, 0.1, 0.01, "white", base=2.15)
        if line:
            (ax, ay, az), (bx, by, bz) = line
            dx, dz = bx - ax, bz - az
            length = math.hypot(dx, dz) or 1.0
            nx, nz = -dz / length * 0.2, dx / length * 0.2
            self.see.face([(ax - nx, ay + 0.05, az - nz), (bx - nx, by + 0.05, bz - nz), (bx + nx, by + 0.05, bz + nz), (ax + nx, ay + 0.05, az + nz)], "white")

    def signal(self, at, facing, reach):
        """A traffic light on a mast arm (a Pacific Northwest junction's): a pole on the corner, an arm out over the
        road `reach` metres the way `facing` points, two signal heads hung from it facing back along the road's
        traffic. Lenses signal_red / signal_amber / signal_green; signal_<n> marks each head."""
        f = self._f(at, facing)
        self.poles.cylinder(f.p(0.0, 0.0, 0.0), 0.16, 7.0, "lamp_grey", 8)
        _bar(self.solid, f.p(0.0, 6.4, 0.0), f.p(0.0, 6.4, reach), 0.14, "lamp_grey")
        _bar(self.solid, f.p(0.0, 7.0, 0.0), f.p(0.0, 6.5, reach * 0.5), 0.06, "lamp_grey")
        for v in (reach * 0.45, reach * 0.9):
            n = _furn_count["signal"]
            _furn_count["signal"] += 1
            f.box(self.solid, -0.0, v, 0.36, 1.05, 0.3, "signal_body", base=5.25)
            for k, mat in enumerate(("signal_red", "signal_amber", "signal_green")):
                y = 6.12 - k * 0.32
                f.box(self.see, 0.17, v, 0.04, 0.22, 0.22, mat, base=y - 0.11)
            w1.mark("signal_%d" % n, f.p(0.2, 5.78, v), _facing_turn((f.along[0], f.along[1])))
        # a pedestrian push button and a signal on the pole itself
        f.box(self.solid, 0.0, 0.0, 0.3, 0.8, 0.26, "signal_body", base=2.6)
        for k, mat in enumerate(("signal_red", "signal_amber", "signal_green")):
            f.box(self.see, 0.15, 0.0, 0.03, 0.18, 0.18, mat, base=3.15 - k * 0.24)

    def bench(self, at, facing, weathered=False):
        """A wooden slat bench on iron legs, its seat to the way `facing` points (solid: to stand on and hop along).
        bench_<n> marks the middle of its seat."""
        f = self._f(at, facing)
        wood = "darkwood" if weathered else "wood"
        for u in (-0.75, 0.75):
            f.box(self.solid, u, 0.0, 0.08, 0.45, 0.5, "black")
        for k in range(3):
            f.box(self.solid, 0.0, -0.15 + k * 0.16, 1.8, 0.05, 0.12, wood, base=0.45)
        for k in range(2):
            f.box(self.solid, 0.0, -0.27, 1.8, 0.11, 0.05, wood, base=0.62 + k * 0.17)
        n = _furn_count["bench"]
        _furn_count["bench"] += 1
        w1.mark("bench_%d" % n, f.p(0.0, 0.5, 0.0), _facing_turn((f.out[0], f.out[1])))

    def bus_shelter(self, at, facing):
        """A bus shelter on the pavement, open to the road the way `facing` points: perspex back and ends, a flat roof
        to walk along (up by the bin at its end, then its edge), a bench, a timetable panel, a bus stop sign post.
        busstop_<n> marks the kerb in front of it. Returns the top of its roof."""
        f = self._f(at, facing)
        n = _furn_count["busstop"]
        _furn_count["busstop"] += 1
        for u in (-1.9, 1.9):
            f.box(self.solid, u, -0.75, 0.08, 2.35, 0.08, "metal")
            f.box(self.solid, u, 0.75, 0.08, 2.35, 0.08, "metal")
            f.box(self.solid, u, 0.0, 0.04, 2.2, 1.45, "glass", base=0.1)
        f.box(self.solid, 0.0, -0.75, 3.8, 2.2, 0.04, "glass", base=0.1)
        f.box(self.solid, 0.0, 0.0, 4.2, 0.12, 1.9, "metal", base=2.35)
        f.box(self.see, -1.2, -0.7, 1.0, 1.5, 0.05, "sign2", base=0.6)
        self.bench((f.p(0.4, 0.0, -0.45)), (f.out[0], f.out[1]))
        f.box(self.solid, 2.5, 0.2, 0.55, 1.0, 0.55, "sign_green")
        sx, sy, sz = f.p(-2.4, 0.0, 0.9)
        self.poles.cylinder((sx, sy, sz), 0.05, 2.9, "metal", 6)
        f.box(self.see, -2.4, 0.9, 0.04, 0.5, 0.36, "sign2", base=2.3)
        w1.mark("busstop_%d" % n, f.p(0.0, 0.12, 1.8), _facing_turn((f.out[0], f.out[1])))
        return f.p(0.0, 2.47, 0.0)

    def booth(self, at, facing):
        """A telephone booth (aluminium and glass, a phone inside, a solid roof), a newspaper box beside it to get up
        by, and its corner post climbable. Returns the top of its roof."""
        f = self._f(at, facing)
        _furn_count["booth"] += 1
        f.box(self.solid, 0.0, 0.0, 1.0, 2.25, 1.0, "glass")
        for u in (-0.5, 0.5):
            for v in (-0.5, 0.5):
                f.box(self.solid, u, v, 0.07, 2.25, 0.07, "zinc")
        f.box(self.solid, 0.0, 0.0, 1.15, 0.22, 1.15, "zinc", base=2.25)
        f.box(self.see, 0.0, 0.0, 0.9, 0.16, 0.02, "sign2", base=2.27)
        f.box(self.solid, 0.0, -0.4, 0.3, 0.5, 0.15, "black", base=1.1)
        self.poles.box(f.p(0.55, 1.25, 0.55), (0.12, 2.5, 0.12), "zinc")
        f.box(self.solid, -1.0, 0.1, 0.5, 1.0, 0.45, "vend_blue")
        return f.p(0.0, 2.47, 0.0)


def ring_furniture(frames):
    """The ring road's: cobra-head lights round both pavements (alternating, about 28 m apart), stop signs where each
    zone's road comes up to the ring, bus shelters, benches, a phone booth outside the shops."""
    furn = Furniture("ring")
    count = 16
    for k in range(count):
        a = math.tau * (k + 0.25) / count
        if min(abs(((a - e + math.pi) % math.tau) - math.pi) for e in (0.0, math.pi / 2, math.pi, 3 * math.pi / 2)) < 0.12:
            a += 0.14
        outer = k % 2 == 0
        r = ROAD[1] + 0.6 if outer else ROAD[0] - 0.6
        way = -1.0 if outer else 1.0
        furn.light((math.cos(a) * r, 0.12, math.sin(a) * r), (math.cos(a) * way, math.sin(a) * way), "cobra")
    for e in (0.0, math.pi / 2, math.pi, 3 * math.pi / 2):
        # (at each zone's road, coming up to the ring: on its right as it comes up)
        r = ROAD[1] + 1.2
        side = 0.16
        at = (math.cos(e - side) * (r + 1.0), 0.12, math.sin(e - side) * (r + 1.0))
        line = (_ring_point(e - 0.11, ROAD[1] + 0.6, 0.0), _ring_point(e - 0.0, ROAD[1] + 0.6, 0.0))
        furn.stop_sign(at, (math.cos(e), math.sin(e)), line)
    for deg in (18.0, 126.0, 198.0, 342.0):
        a = math.radians(deg)
        r = ROAD[1] + 1.8
        furn.bus_shelter((math.cos(a) * r, 0.12, math.sin(a) * r), (-math.cos(a), -math.sin(a)))
    for deg in (65.7, 155.7, 245.7, 300.0):
        a = math.radians(deg)
        r = ROAD[1] + 2.3
        furn.bench((math.cos(a) * r, 0.12, math.sin(a) * r), (-math.cos(a), -math.sin(a)), weathered=deg in (155.7, 245.7))
    for k in (1, 4):
        frame = frames[k]
        furn.bench(frame.p(14.0, 0.0, 0.6), (-frame.out[0], -frame.out[1]))
    a = math.radians(108.0)
    furn.booth((math.cos(a) * (ROAD[1] + 2.0), 0.12, math.sin(a) * (ROAD[1] + 2.0)), (-math.cos(a), -math.sin(a)))
    furn.done()


def grove():
    """The grove, a Pacific Northwest wood on the hilltop (the user, 2026-11-02: "the grove needs to be bigger, and have
    2 rings of trees, in between we need a couple big trees for npcs to be in. There should be like leaf platforms to
    stand on in the big trees"): an open clearing (the great oak at its north-west edge, the raccoons' base; a little
    knoll; the pond fed by a spring falling off a mossy outcrop), an inner ring of trees, a band of open wood with three
    giant firs whose leafy platforms the raccoons perch on, an outer ring, and a fieldstone wall round it all by the ring
    road's pavement. A trail arch where the path comes up, an old stump circle, a cedar-shake cabin."""
    rng_wood = random.Random(17)
    wood = []   # [x, z, size%, kind, degrees]
    # (Douglas fir, western red cedar, bigleaf maple, red alder: TreeGen Fir, Spruce, Maple, Birch in World; "lo"
    # the plainer, cheaper kind)
    # (the outer rows fewer and bigger, cedars over alders (a plain alder is some 8k triangles, a cedar 1.3k):
    # the grove's trees had grown to about 800k triangles; these keep the wall of wood the user asked for, "a denser
    # surround woods", at about 550k)
    rings = [(INNER[0], 4.4, ("fir", "redcedar", "fir", "maplelo")), (INNER[1], 5.2, ("firlo", "redcedarlo", "alderlo", "firlo", "redcedarlo", "redcedarlo")),
             (OUTER[0], 6.0, ("redcedarlo", "firlo", "redcedarlo")), (OUTER[1], 6.4, ("redcedarlo", "redcedarlo", "firlo", "redcedarlo")),
             (OUTER[2], 6.8, ("redcedarlo", "firlo", "redcedarlo", "redcedarlo"))]
    for row, (radius, spacing, kinds) in enumerate(rings):
        count = int(math.tau * radius / spacing)
        for i in range(count):
            deg = (360.0 * (i + 0.5 * (row % 2)) / count + rng_wood.uniform(-4.0, 4.0)) % 360.0
            if 55.0 < deg < 110.0:
                continue
            r = radius + rng_wood.uniform(-0.5, 0.5)
            kind = kinds[i % len(kinds)]
            size = rng_wood.randint(120, 170) if kind.startswith(("fir", "redcedar")) else rng_wood.randint(85, 120)
            if row >= 2:
                size = int(size * 1.2)
            wood.append([math.cos(math.radians(deg)) * r, math.sin(math.radians(deg)) * r, size, kind, deg])
    # young firs scattered in both rings
    for i in range(8):
        deg = rng_wood.uniform(0.0, 360.0)
        if 55.0 < deg < 110.0:
            continue
        r = rng_wood.choice((rng_wood.uniform(INNER[0] - 1.0, INNER[1] + 1.0), rng_wood.uniform(OUTER[0] - 1.0, OUTER[2] + 1.0)))
        wood.append([math.cos(math.radians(deg)) * r, math.sin(math.radians(deg)) * r, rng_wood.randint(35, 55), "firlo", deg])
    # (the climbing trees: the great oak, two climbing oaks in the inner ring)
    for deg, kind in ((227.0, "camphor"), (165.0, "climb"), (320.0, "climb")):
        best = min((t for t in wood if abs(math.hypot(t[0], t[1]) - INNER[0]) < 1.5 and t[3] not in ("camphor", "climb")), key=lambda t: abs(((t[4] - deg + 180.0) % 360.0) - 180.0))
        best[3] = kind
        best[2] = 160 if kind == "camphor" else 100
    # (the great oak, the raccoons' base (the user, 2026-11-02: "the main base should be at the base of a great big oak
    # tree with gnarled roots, where the giant raccoon sits and snoozes"): out of the row, into the clearing's
    # north-west edge, the wood cleared round its crown)
    great = next(t for t in wood if t[3] == "camphor")
    great[0], great[1] = OAK
    for t in wood:
        if t is not great and math.hypot(t[0] - great[0], t[1] - great[1]) < 14.0:
            t[3] = None
    # (room round the giant firs and out of the pond's and the knoll's way)
    for t in wood:
        if t[3] and any(math.hypot(t[0] - gx, t[1] - gz) < 5.0 for gx, gz in GIANTS):
            t[3] = None
    # (the path spirals round the mound, so it runs along each row a long way: a tree within a metre and a half of it
    # is moved in or out along its radius till clear, else left out)
    for t in wood:
        if t[3] is None or path_distance(t[0], t[1]) >= 1.8:
            continue
        r, a = math.hypot(t[0], t[1]), math.atan2(t[1], t[0])
        for step in (0.8, -0.8, 1.6, -1.6, 2.4, -2.4):
            if path_distance(math.cos(a) * (r + step), math.sin(a) * (r + step)) >= 1.8 and PLATEAU + 1.0 < r + step < WALL_R - 1.0:
                t[0], t[1] = math.cos(a) * (r + step), math.sin(a) * (r + step)
                break
        else:
            t[3] = None
    wood = [t for t in wood if t[3]]
    trees = [(t[0], t[1], t[2]) for t in wood]
    for k, (x, z, size, kind, _deg) in enumerate(wood):
        at = (x, hill_height(x, z) - 0.05, z)
        if kind in ("camphor", "climb"):
            w1.mark("tree_%d_%d_%d" % (k, 101 + k * 7, size), at)
        else:
            w1.mark("treep_%d_%d_%d_%s" % (k, 101 + k * 7, size, kind), at)
    cost = {"camphor": 41000, "climb": 41000, "fir": 4400, "redcedar": 3560, "firlo": 2180, "redcedarlo": 1290, "maplelo": 6500, "alderlo": 7900}   # (measured in game)
    tris = sum(cost.get(t[3], 3000) for t in wood)
    kinds = sorted(set(t[3] for t in wood))
    print("GROVE TREES %d (%s), about %d triangles" % (len(wood), ", ".join("%d %s" % (sum(t[3] == k for t in wood), k) for k in kinds), tris))
    giant_firs()
    undergrowth(wood)
    oak_roots()
    stone_wall()
    spring_falls()
    steepest = max(math.degrees(math.atan(math.hypot(hill_height(x + 0.25, z) - hill_height(x - 0.25, z), hill_height(x, z + 0.25) - hill_height(x, z - 0.25)) / 0.5))
                   for x in range(-44, 45) for z in range(-44, 45) if math.hypot(x, z) < HILL_FOOT - 0.2 and _pond_d(x, z) > 1.5 and math.hypot(x - KNOLL[0], z - KNOLL[1]) > 6.0)
    print("MOUND STEEPEST %.1f deg (the pond's banks and the spring's rocks aside)" % steepest)
    # garden trees behind the ring's houses (bigleaf maples and firs)
    for n, (k, u, v, size) in enumerate(((7, -15.0, 8.0, 80), (5, 15.0, 10.0, 85), (11, 15.0, 6.0, 75), (8, -15.0, 10.0, 70))):
        frame = Frame(math.tau * k / SECTORS, FRONT, LOTS[k][1])
        p = frame.p(u, -0.05, v)
        w1.mark("treep_%d_%d_%d_%s" % (len(trees) + n, 211 + n * 13, size, "maplelo" if n % 2 == 0 else "fir"), p)
    # An old stump circle round a ring of fire stones, at the clearing's north edge
    sx, sz = 0.5, -(PLATEAU - 4.0)
    stumps = w1.Piece("stump_circle")
    rng = random.Random(8)
    for k in range(7):
        a = math.tau * k / 7 + rng.uniform(-0.2, 0.2)
        cx, cz = sx + math.cos(a) * 2.6, sz + math.sin(a) * 2.6
        stumps.cylinder((cx, hill_height(cx, cz) - 0.1, cz), rng.uniform(0.35, 0.6), rng.uniform(0.45, 0.75), "darkwood", 9, top="wood")
    for k in range(10):
        a = math.tau * k / 10
        cx, cz = sx + math.cos(a) * 0.8, sz + math.sin(a) * 0.8
        stumps.box((cx, hill_height(cx, cz) + 0.08, cz), (0.32, 0.22, 0.32), "stone")
    stumps.done()
    w1.mark("haunt_1", (sx, hill_height(sx, sz + 3.6), sz + 3.6))
    # The trail arch where the path comes up onto the top: two log posts, a crossbar, a hanging sign board
    tx, tz = path_point(1.0)
    turn = math.atan2(tz, tx)
    frame = Frame(turn, math.hypot(tx, tz) - 0.6, hill_height(tx, tz) - 0.1)
    arch = w1.Piece("trail_arch")
    for side in (-1.5, 1.5):
        arch.cylinder(frame.p(side, 0.0, 0.0), 0.2, 3.4, "darkwood", 8)
    _bar(arch, frame.p(-2.1, 3.3, 0.0), frame.p(2.1, 3.3, 0.0), 0.32, "darkwood")
    frame.box(arch, 0.0, 0.0, 2.2, 0.6, 0.08, "wood", base=2.4)
    arch.done()
    # The cedar-shake cabin at the clearing's south-west edge
    hx, hz = -(PLATEAU - 4.5) * 0.71, (PLATEAU - 4.5) * 0.71
    hy = min(hill_height(hx + dx, hz + dz) for dx in (-1.8, 1.8) for dz in (-1.6, 1.6)) - 0.1
    hut_frame = Frame(math.atan2(hz, hx), math.hypot(hx, hz), hy)
    hut = w1.Piece("cabin")
    hut_frame.box(hut, 0.0, 0.0, 4.4, 2.4, 3.4, "darkwood")
    hut_frame.box(hut, 0.0, -1.72, 1.0, 1.8, 0.06, "door")
    hut_frame.hip_roof(hut, 0.0, 0.0, 4.4, 3.4, 2.4, 1.6, "shake", over=0.6)
    hut.done()
    w1.mark("haunt_6", hut_frame.p(1.0, 0.1, -2.6))
    # Reeds round the pond and on the slopes (markers only: World grows Warren's reeds there)
    rng = random.Random(5)
    placed = 0
    for _try in range(600):
        if placed >= 6:
            break
        a = rng.uniform(0.0, math.tau)
        r = rng.uniform(INNER[1] + 1.5, OUTER[0] - 1.5)
        x, z = math.cos(a) * r, math.sin(a) * r
        if path_distance(x, z) < 3.5 or any(math.hypot(x - tx_, z - tz_) < 3.0 for tx_, tz_, _s in trees):
            continue
        empty = w1.mark("reeds_%d" % placed, (x, hill_height(x, z) - 0.05, z))
        size = rng.uniform(2.0, 3.5)
        empty.scale = (size, size, size)
        placed += 1
    # The pond at the clearing's east edge (the user, 2026-11-02: "there should be a pond in the grove and a fishing
    # minigame", "the pond needs to be bigger too"): its banks uneven (hill_height), a wooden jetty out from the
    # clearing's side to fish from, lily pads, a few fish, reeds on the far bank
    water_y = HILL_TOP - 0.25
    w1.mark("pool", (POOL[0], water_y, POOL[1]))
    w1.mark("pool_size", (POOL_RADII[0] * 2.5, 1.6, POOL_RADII[1] * 2.5))
    w1.mark("fishing_water", (POOL[0], water_y, POOL[1]))
    toward = (-POOL[0], -POOL[1])
    length = math.hypot(*toward)
    out_a = math.atan2(-toward[1] / length, -toward[0] / length)   # (from the clearing out over the water)
    bank = pond_edge(out_a + math.pi)
    jetty = Frame.at(bank[0], bank[1], out_a, water_y + 0.32)
    deck = w1.Piece("jetty")
    jetty.box(deck, 0.0, 1.4, 1.3, 0.12, 4.6, "wood")
    for pu in (-0.55, 0.55):
        for pv in (-0.6, 1.6, 3.4):
            deck.cylinder(jetty.p(pu, -1.9, pv), 0.07, 2.0, "darkwood", 6)
    deck.done()
    # (standing at its end, facing out over the water: the marker's -Z points over the water)
    spot = jetty.p(0.0, 0.12, 3.4)
    out = (math.cos(out_a), math.sin(out_a))
    w1.mark("fishing_spot", spot, math.atan2(-out[0], -out[1]))
    pads = w1.Piece("nocol_lily_pads")
    rng_p = random.Random(9)
    for k in range(10):
        a, r = rng_p.uniform(0.0, math.tau), rng_p.uniform(0.55, 0.95)
        px, pz = POOL[0] + math.cos(a) * POOL_RADII[0] * 0.75 * r, POOL[1] + math.sin(a) * POOL_RADII[1] * 0.75 * r
        size = rng_p.uniform(0.25, 0.45)
        ring = [(px + math.cos(math.tau * i / 9) * size, water_y + 0.015, pz + math.sin(math.tau * i / 9) * size) for i in range(1, 9)]
        pads.face([(px, water_y + 0.015, pz)] + ring, "lily")
        if k % 3 == 0:
            pads.box((px + size * 0.3, water_y + 0.06, pz), (0.12, 0.08, 0.12), "lily_flower")
    pads.done()
    fish = w1.Piece("nocol_fish")
    for k in range(5):
        a = rng_p.uniform(0.0, math.tau)
        kx, kz = POOL[0] + math.cos(a) * POOL_RADII[0] * 0.5, POOL[1] + math.sin(a) * POOL_RADII[1] * 0.5
        f = Frame.at(kx, kz, rng_p.uniform(0.0, math.tau), water_y - 0.35)
        f.box(fish, 0.0, 0.0, 0.14, 0.1, 0.5, "koi" if k % 2 else "trout")
        f.box(fish, 0.0, 0.31, 0.02, 0.12, 0.14, "trout")
    fish.done()
    far = pond_edge(out_a)
    empty = w1.mark("reeds_pond", (far[0], hill_height(*far), far[1]))
    empty.scale = (2.4, 2.4, 2.4)
    w1.mark("haunt_7", (bank[0] - math.cos(out_a) * 1.5, hill_height(bank[0] - math.cos(out_a) * 1.5, bank[1] - math.sin(out_a) * 1.5), bank[1] - math.sin(out_a) * 1.5))
    # Lantern posts up the path, benches by the pond and on the knoll (the user, 2026-11-02: "there needs to be street
    # lights", "benches")
    furn = Furniture("grove")
    for t in (0.06, 0.3, 0.55, 0.8, 0.99):
        x, z = path_point(t)
        x2, z2 = path_point(min(t + 0.01, 1.0))
        side = (-(z2 - z), x2 - x)
        length = math.hypot(*side) or 1.0
        lx, lz = x + side[0] / length * 1.3, z + side[1] / length * 1.3
        furn.light((lx, hill_height(lx, lz) - 0.05, lz), (-side[0], -side[1]), "lantern")
    for a in (math.pi + 0.5, math.pi - 0.3):
        bx, bz = pond_edge(a)
        bx, bz = bx + math.cos(a) * 1.6, bz + math.sin(a) * 1.6
        furn.bench((bx, hill_height(bx, bz) - 0.02, bz), (-math.cos(a), -math.sin(a)))
    furn.bench((KNOLL[0] - 1.0, hill_height(KNOLL[0] - 1.0, KNOLL[1]) - 0.05, KNOLL[1]), (-1.0, 0.4))
    furn.done()
    # Crumbs up the winding path
    for k in range(18):
        x, z = path_point((k + 0.5) / 18 * 0.94)
        w1.crumb((x, hill_height(x, z) + 0.35, z))


def giant_firs():
    """Three giant firs in the band between the rings (the user: "a couple big trees for npcs to be in. There should be
    like leaf platforms to stand on in the big trees"): only their markers here, `giantfir_<n>_<seed>` at each foot on
    the ground; World grows them (a TreeGen preset with leaf pads) and adds their perches."""
    for n, (gx, gz) in enumerate(GIANTS):
        w1.mark("giantfir_%d_%d" % (n, 60 + n), (gx, hill_height(gx, gz), gz))


def stone_wall():
    """A fieldstone wall round the grove right along the ring road's inner pavement (the user, 2026-11-02: "there
    should be a stone fence surround the grove next to the sidewalk", then "the stone wall surrounding the grove should
    be taller than a person"): 2.2 m, its stones climbable (climb_: he scurries up its face and hops onto the top), a
    capped top he can run along, moss on it and ivy down it; open with an arch on stone pillars where the path comes
    in and at the three other quarters."""
    wall = w1.Piece("climb_grove_wall")
    ivy = w1.Piece("nocol_wall_ivy")
    arches = w1.Piece("grove_wall_arches")
    rng = random.Random(12)
    gap = path_point(0.0)
    gap_a = math.atan2(gap[1], gap[0])
    gaps = [gap_a, gap_a + math.pi / 2, gap_a + math.pi, gap_a - math.pi / 2]
    half_gap = 0.045
    segs = 220
    tall = 2.2
    for k in range(segs):
        a0, a1 = math.tau * k / segs, math.tau * (k + 1) / segs
        if any(abs(((a0 + a1) / 2 - g + math.pi) % math.tau - math.pi) < half_gap for g in gaps):
            continue
        y0, y1 = hill_height(*_ring_point(a0, WALL_R, 0.0)[::2]), hill_height(*_ring_point(a1, WALL_R, 0.0)[::2])
        bump = rng.uniform(-0.04, 0.05)
        for r in (WALL_R - 0.3, WALL_R + 0.3):
            wall.face([_ring_point(a0, r, y0 - 0.15), _ring_point(a1, r, y1 - 0.15), _ring_point(a1, r, y1 + tall + bump), _ring_point(a0, r, y0 + tall + bump)], "stone", 0.9)
        wall.face([_ring_point(a0, WALL_R - 0.34, y0 + tall + bump), _ring_point(a1, WALL_R - 0.34, y1 + tall + bump),
                   _ring_point(a1, WALL_R + 0.34, y1 + tall + bump), _ring_point(a0, WALL_R + 0.34, y0 + tall + bump)], "moss" if rng.random() < 0.35 else "stone", 1.1)
        # ivy down its faces in patches
        if rng.random() < 0.18:
            r = WALL_R + rng.choice((-0.33, 0.33))
            drop = rng.uniform(0.8, 1.9)
            ivy.face([_ring_point(a0, r, y0 + tall - drop), _ring_point(a1, r, y1 + tall - drop * rng.uniform(0.6, 1.0)), _ring_point(a1, r, y1 + tall + 0.02), _ring_point(a0, r, y0 + tall + 0.02)], "fern", 1.0)
    # the arches over the gaps: a pillar either side, a beam over (a ledge he catches from the pillars' tops)
    for g in gaps:
        for side in (-1.0, 1.0):
            a = g + side * (half_gap + 0.012)
            x, _y, z = _ring_point(a, WALL_R, 0.0)
            y = hill_height(x, z)
            arches.box((x, y + 1.3, z), (0.8, 2.9, 0.8), "stone", top="moss")
        p0, p1 = _ring_point(g - half_gap, WALL_R, 0.0), _ring_point(g + half_gap, WALL_R, 0.0)
        y = max(hill_height(p0[0], p0[2]), hill_height(p1[0], p1[2]))
        _bar(arches, (p0[0], y + 3.0, p0[2]), (p1[0], y + 3.0, p1[2]), 0.45, "darkwood")
    wall.done()
    ivy.done()
    arches.done()


def spring_falls():
    """The spring's mossy rock outcrop at the pond's bank, on the knoll's side (the user, 2026-11-02: "needs to be fed
    by a little waterfall spring", then "the spring and waterfall need a ton of work ... a small bubbling pond with a
    real waterfall"): solid rock with a round basin in its top for the spring's pool, a notch in its rim on the pond's
    side whose floor is the lip the falls spill over (overhanging the rock face), stepping stones up beside it. The
    water itself is the WATER work's, drawn in code at its markers: `spring_pool` (the pool's surface middle, scale.x
    its radius, scale.y its depth), `waterfall_top` (the lip's middle at the water level), `waterfall_bottom` (where
    the falls meet the pond); `spring` as before."""
    water_y = HILL_TOP - 0.25
    way = math.atan2(KNOLL[1] - POOL[1], KNOLL[0] - POOL[0])
    d = (math.cos(way), math.sin(way))                    # from the pond in towards the outcrop
    side = (-d[1], d[0])
    lip = pond_edge(way)
    radius, deep, outer = 1.4, 0.6, 3.2
    ox, oz = lip[0] + d[0] * (outer - 0.4), lip[1] + d[1] * (outer - 0.4)
    wl = water_y + 2.6                                    # the spring pool's water level
    rocks = w1.Piece("spring_rocks")
    segs = 16
    notch = 0.42                                          # half the notch's angle
    front = way + math.pi

    def ring(a, r, y):
        return (ox + math.cos(a) * r, y, oz + math.sin(a) * r)

    def ground_under(a, r):
        x, _y, z = ring(a, r, 0.0)
        return hill_height(x, z) - 0.4

    for k in range(segs):
        a0, a1 = math.tau * k / segs, math.tau * (k + 1) / segs
        in_notch = abs(((a0 + a1) / 2 - front + math.pi) % math.tau - math.pi) < notch
        top = wl if in_notch else wl + 0.1 + 0.25 * ((k * 7) % 3) / 2
        mat = "stone" if in_notch else "moss"
        rocks.face([ring(a0, radius, top), ring(a0, outer, top), ring(a1, outer, top), ring(a1, radius, top)][::-1], mat, 1.05)
        rocks.face([ring(a0, radius, wl - deep), ring(a0, radius, top), ring(a1, radius, top), ring(a1, radius, wl - deep)][::-1], "stone", 0.8)
        rocks.face([ring(a0, outer, ground_under(a0, outer)), ring(a1, outer, ground_under(a1, outer)), ring(a1, outer, top), ring(a0, outer, top)][::-1], "stone", 0.9)
        rocks.face([ring(a0, 0.0, wl - deep), ring(a0, radius, wl - deep), ring(a1, radius, wl - deep)][::-1], "stone", 0.7)
    # the lip: a slab out past the rock face under the notch, the water spilling off its edge
    lx, lz = ox + math.cos(front) * outer, oz + math.sin(front) * outer
    half = math.sin(notch) * outer
    lip_out = 0.25
    corners = [(lx + side[0] * s - d[0] * o, lz + side[1] * s - d[1] * o) for s, o in ((-half, -0.3), (half, -0.3), (half, lip_out), (-half, lip_out))]
    rocks.face([(x, wl, z) for x, z in corners], "stone", 1.0)
    rocks.face([(x, wl - 0.3, z) for x, z in corners][::-1], "stone", 0.7)
    for (ax, az), (bx, bz) in zip(corners, corners[1:] + corners[:1]):
        rocks.face([(ax, wl - 0.3, az), (bx, wl - 0.3, bz), (bx, wl, bz), (ax, wl, az)], "stone", 0.85)
    # boulders round its foot, and stepping stones up beside it
    rng = random.Random(21)
    for k in range(7):
        a = way + rng.uniform(0.8, math.tau - 0.8)
        r = outer + rng.uniform(0.3, 1.2)
        x, _y, z = ring(a, r, 0.0)
        h = rng.uniform(0.6, 1.4)
        rocks.box((x, hill_height(x, z) - 0.2 + h / 2, z), (rng.uniform(0.9, 1.5), h, rng.uniform(0.9, 1.4)), "stone", top="moss")
    for k, h in enumerate((0.7, 1.4, 2.1)):
        x, z = lx + side[0] * (half + 1.2 + k * 0.2) + d[0] * (0.6 + k * 0.9), lz + side[1] * (half + 1.2 + k * 0.2) + d[1] * (0.6 + k * 0.9)
        y = hill_height(x, z)
        rocks.box((x, y - 0.3 + (h + 0.3) / 2, z), (1.0, h + 0.3, 1.0), "stone", top="moss")
    rocks.done()
    empty = w1.mark("spring_pool", (ox, wl, oz))
    empty.scale = (radius, deep, radius)
    w1.mark("waterfall_top", (lx - d[0] * lip_out, wl, lz - d[1] * lip_out))
    w1.mark("waterfall_bottom", (lx - d[0] * (lip_out + 0.5), water_y, lz - d[1] * (lip_out + 0.5)))
    w1.mark("spring", (ox, wl, oz))


def far_height(r, a):
    """The land beyond the hill: the valley floor at the hill's foot out past the play area, then rising to the low
    hills (the zones' towns carry on across it: beyond())."""
    valley = PLAY + 30.0
    foot = foot_at(a)
    if r < valley:
        h = foot - 0.6
        rough = 1.5
    else:
        t = min(1.0, (r - valley) / 130.0)
        h = foot - 0.6 + 32.0 * t * t * (3.0 - 2.0 * t)
        rough = 1.5 + 7.0 * t
    bumps = noise.noise(Vector((math.cos(a) * r * 0.012, math.sin(a) * r * 0.012, 3.1)))
    return h + bumps * rough


def beyond():
    """What he sees past the rail (none of it solid): terraces down from the lots, the town in the valley, the hills."""
    land = w1.Piece("nocol_far_land")
    rings = [PLAY + 2.0, PLAY + 25.0, PLAY + 60.0, PLAY + 100.0, PLAY + 160.0]
    segs = 64
    for i in range(len(rings) - 1):
        for s in range(segs):
            b0, b1 = math.tau * s / segs, math.tau * (s + 1) / segs
            r0, r1 = rings[i], rings[i + 1]
            mat = "far_green" if r1 <= 195.0 else ("far_forest" if r1 <= 260.0 else "far_hill")
            # (a little under the hill's own squares where they overlap)
            sink0, sink1 = (-0.4 if r0 < PLAY + 10.0 else 0.0), (-0.4 if r1 < PLAY + 10.0 else 0.0)
            land.face([_ring_point(b0, r0, far_height(r0, b0) + sink0), _ring_point(b1, r0, far_height(r0, b1) + sink0),
                       _ring_point(b1, r1, far_height(r1, b1) + sink1), _ring_point(b0, r1, far_height(r1, b0) + sink1)], mat)
    land.done()
    # The middle distance past each face's foot carries on its zone (the user, 2026-11-02: "each zone should have a
    # different view in the distance", "so the city zone sees more city in the distance, suburbs more suburb,
    # construction more construction, factories factories etc"): past the City more city, towers rising to a
    # downtown with a needle tower; past the Industrial side warehouses, stacks, a rail yard and the port's cranes on a
    # bay; past the Construction side cleared dirt, half-built subdivisions and tower cranes; past the Rural side
    # fields, farmhouses, red barns and rows of trees. Then the hills and the mountains. Only to look at, cheap boxes.
    town = w1.Piece("nocol_far_town")
    rng = random.Random(11)
    zones = {zone: math.pi / 2 - turn for turn, _t, zone in FACES}

    def zone_at(a):
        return min(zones, key=lambda z: abs((a - zones[z] + math.pi) % math.tau - math.pi))

    def block(x, z, turn, w, d, tall, wall, roof=None, rise=0.0, top=None):
        """A box turned `turn` on the land at (x, z), a gable roof if `roof`."""
        y = _cone(x, z) - 0.4
        c, s = math.cos(turn), math.sin(turn)

        def p(u, yy, v):
            return (x + u * c - v * s, y + yy, z + u * s + v * c)
        # (k[iu * 4 + iy * 2 + iv]: its four walls are the iu and iv sides; they were the floor, the top and two of the
        # walls, so each far building was a pair of walls with a lid, see-through from two sides: the "garbled shapes")
        k = [p(iu * w / 2, iy * tall, iv * d / 2) for iu in (-1, 1) for iy in (0, 1) for iv in (-1, 1)]
        for q, shade in (((0, 1, 3, 2), 0.86), ((4, 6, 7, 5), 0.86), ((0, 2, 6, 4), 0.95), ((1, 5, 7, 3), 0.95)):
            town.face([k[i] for i in q], wall, shade)
        if roof:
            e = [p(-w / 2 - 0.4, tall, -d / 2 - 0.4), p(w / 2 + 0.4, tall, -d / 2 - 0.4), p(w / 2 + 0.4, tall, d / 2 + 0.4), p(-w / 2 - 0.4, tall, d / 2 + 0.4)]
            r0, r1 = p(-w / 2 - 0.4, tall + rise, 0.0), p(w / 2 + 0.4, tall + rise, 0.0)
            town.face([e[0], e[1], r1, r0], roof, 1.05)
            town.face([e[2], e[3], r0, r1], roof, 0.85)
            town.face([k[2], k[3], r0], wall, 0.86)
            town.face([k[6], k[7], r1], wall, 0.86)
        else:
            town.face([k[2], k[3], k[7], k[6]], top or wall, 1.08)
        return p

    def bar(x, y, z, turn, length, high, wide, mat):
        """A box turned `turn` about the upright, its middle at (x, y, z), `length` along the turn."""
        c, s = math.cos(turn), math.sin(turn)
        k = [(x + c * u - s * v, y + yy, z + s * u + c * v) for u in (-length / 2, length / 2) for yy in (-high / 2, high / 2) for v in (-wide / 2, wide / 2)]
        for q in [(0, 1, 3, 2), (4, 6, 7, 5), (0, 2, 6, 4), (1, 5, 7, 3), (2, 6, 7, 3), (0, 1, 5, 4)]:
            town.face([k[i] for i in q], mat, 0.95)

    def fir(x, z, tall, mat):
        """A far fir: a six-sided cone."""
        y = _cone(x, z) - 0.2
        wide = tall * 0.24
        for i in range(6):
            t0, t1 = math.tau * i / 6, math.tau * (i + 1) / 6
            town.face([(x + math.cos(t0) * wide, y + tall * 0.12, z + math.sin(t0) * wide), (x + math.cos(t1) * wide, y + tall * 0.12, z + math.sin(t1) * wide),
                       (x, y + tall, z)], mat, 0.85 + 0.25 * math.cos(t0 - 0.8))

    def mast(x, z, tall, jib, turn, mat):
        """A tower crane's silhouette: a mast, a jib across its top."""
        y = _cone(x, z) - 0.3
        town.box((x, y + tall / 2, z), (1.2, tall, 1.2), mat)
        c, s = math.cos(turn), math.sin(turn)
        # (the jib a long thin bar turned with the crane, from a short counter-jib behind the mast out over the site: as
        # an upright box turned any way but square it came out a broad flat plate)
        y0, y1 = y + tall + 0.1, y + tall + 1.1
        back, out, half = -jib * 0.25, jib * 0.75, 0.5
        k = [(x + c * u - s * v, yy, z + s * u + c * v) for u in (back, out) for yy in (y0, y1) for v in (-half, half)]
        for q in [(0, 1, 3, 2), (4, 6, 7, 5), (0, 2, 6, 4), (1, 5, 7, 3), (2, 6, 7, 3), (0, 1, 5, 4)]:
            town.face([k[i] for i in q], mat, 0.95)
        # (and a hook line hanging from near its end)
        town.box((x + c * jib * 0.6, y + tall - 4.0, z + s * jib * 0.6), (0.3, 8.0, 0.3), mat)

    # (calmer, the user, 2026-11-02: "the city is just arandom mess of garbeld shapes, its way too busy in the distance
    # for all the zones cconsidering how bare each zone is": a few big plain shapes to each zone, kept to a wedge
    # straight out past its face with open land and firs between, none overlapping, in the hazier colours above)
    placed = []

    def free(x, z, size):
        if any(math.hypot(x - px, z - pz) < size + ps for px, pz, ps in placed):
            return False
        placed.append((x, z, size))
        return True

    def spot(zone, r0, r1, spread=0.5, size=10.0, tries=30):
        """A free spot in the zone's wedge (within `spread` of straight out past its face), or None."""
        for _i in range(tries):
            a = zones[zone] + rng.uniform(-spread, spread)
            r = rng.uniform(r0, r1)
            x, z = math.cos(a) * r, math.sin(a) * r
            if free(x, z, size):
                return x, z, a
        return None

    # City: a modest downtown far out, its towers the taller the nearer its middle; a few low blocks nearer
    dx, dz = math.cos(zones["City"]) * (PLAY + 135.0), math.sin(zones["City"]) * (PLAY + 135.0)
    for n in range(11):
        for _i in range(30):
            d = rng.uniform(0.0, 50.0)
            t = rng.uniform(0.0, math.tau)
            x, z = dx + math.cos(t) * d, dz + math.sin(t) * d
            if free(x, z, 12.0):
                tall = 26.0 + 44.0 * (1.0 - d / 50.0) + rng.uniform(-4.0, 4.0)
                block(x, z, zones["City"] + rng.uniform(-0.05, 0.05), rng.uniform(16.0, 22.0), rng.uniform(16.0, 22.0), tall,
                      "far_glass" if n % 2 else "far_wall", top="far_roof3")
                break
    for n in range(10):
        s = spot("City", PLAY + 40.0, PLAY + 95.0, 0.45, 14.0)
        if s:
            block(s[0], s[1], s[2], rng.uniform(18.0, 24.0), rng.uniform(14.0, 20.0), rng.uniform(9.0, 14.0), "far_wall2", top="far_roof3")
    nx, nz = math.cos(zones["City"] + 0.3) * (PLAY + 150.0), math.sin(zones["City"] + 0.3) * (PLAY + 150.0)
    ny = _cone(nx, nz)
    town.cylinder((nx, ny, nz), 1.6, 110.0, "far_wall", 8)
    town.cylinder((nx, ny + 100.0, nz), 10.0, 4.0, "far_wall", 16)
    town.cylinder((nx, ny + 104.0, nz), 1.0, 18.0, "far_wall", 6)
    # Industrial: long sheds, three stacks, a group of tanks, and past them the bay with its cranes and a ship
    for n in range(7):
        s = spot("Industrial", PLAY + 30.0, PLAY + 100.0, 0.5, 30.0)
        if s:
            block(s[0], s[1], s[2] + math.pi / 2, rng.uniform(44.0, 60.0), rng.uniform(20.0, 26.0), rng.uniform(9.0, 12.0), "far_metal2", "far_roof", 2.0)
    for n in range(3):
        s = spot("Industrial", PLAY + 40.0, PLAY + 100.0, 0.4, 8.0)
        if s:
            town.cylinder((s[0], _cone(s[0], s[1]) - 0.5, s[1]), 2.2, rng.uniform(38.0, 48.0), "far_brick", 8)
    s = spot("Industrial", PLAY + 50.0, PLAY + 90.0, 0.4, 16.0)
    if s:
        for k in range(3):
            town.cylinder((s[0] + (k - 1) * 8.0, _cone(s[0], s[1]) - 0.5, s[1]), 3.4, 12.0, "far_metal", 10)
    ia = zones["Industrial"]
    bay_r0, bay_r1 = PLAY + 110.0, PLAY + 175.0
    bay_y = max(far_height(rr, aa) for rr in (bay_r0, (bay_r0 + bay_r1) / 2, bay_r1) for aa in [ia - 0.5 + k * 0.05 for k in range(21)]) + 0.4
    for k in range(10):
        a0, a1 = ia - 0.5 + k * 0.1, ia - 0.5 + (k + 1) * 0.1
        town.face([_ring_point(a0, bay_r0, bay_y), _ring_point(a1, bay_r0, bay_y), _ring_point(a1, bay_r1, bay_y), _ring_point(a0, bay_r1, bay_y)][::-1], "far_water")
    for k in range(3):
        a = ia - 0.25 + k * 0.25
        cx, cz = math.cos(a) * (bay_r0 - 4.0), math.sin(a) * (bay_r0 - 4.0)
        side = (math.cos(a + math.pi / 2), math.sin(a + math.pi / 2))
        for leg in (-6.0, 6.0):
            bar(cx + side[0] * leg, bay_y + 15.0, cz + side[1] * leg, a, 1.4, 30.0, 1.4, "far_red")
        bar(cx + math.cos(a) * 10.0, bay_y + 31.0, cz + math.sin(a) * 10.0, a, 44.0, 2.0, 2.0, "far_red")
        bar(cx, bay_y + 30.0, cz, a + math.pi / 2, 14.0, 1.4, 1.4, "far_red")
    sx, sz = math.cos(ia) * (bay_r0 + 30.0), math.sin(ia) * (bay_r0 + 30.0)
    bar(sx, bay_y + 3.0, sz, ia + math.pi / 2, 80.0, 7.0, 14.0, "far_metal2")
    # Construction: cleared dirt, a few streets of new houses (some still bare frames), two tower cranes
    for n in range(4):
        s = spot("Construction", PLAY + 30.0, PLAY + 120.0, 0.5, 26.0)
        if s:
            y = _cone(s[0], s[1]) + 0.2
            w = rng.uniform(36.0, 50.0)
            town.face([(s[0] - w / 2, y, s[1] - w / 2), (s[0] - w / 2, y, s[1] + w / 2), (s[0] + w / 2, y, s[1] + w / 2), (s[0] + w / 2, y, s[1] - w / 2)], "far_dirt")
    for n in range(3):
        s = spot("Construction", PLAY + 30.0, PLAY + 110.0, 0.45, 26.0)
        if s:
            turn = s[2] + math.pi / 2
            for k in range(4):
                hx, hz = s[0] + math.cos(turn) * (k - 1.5) * 13.0, s[1] + math.sin(turn) * (k - 1.5) * 13.0
                block(hx, hz, turn, 8.0, 9.0, 5.5, "far_lumber" if k % 3 == 1 else "far_wall2", "far_roof" if k % 3 != 1 else None, 2.2, top="far_lumber")
    for n in range(2):
        s = spot("Construction", PLAY + 50.0, PLAY + 110.0, 0.35, 20.0)
        if s:
            mast(s[0], s[1], rng.uniform(34.0, 42.0), rng.uniform(28.0, 36.0), rng.uniform(0.0, math.tau), "far_yellow")
    # Rural: big fields, a few barns and farmhouses, rows of trees along the fields' edges
    for n in range(16):
        s = spot("Rural", PLAY + 20.0, PLAY + 150.0, 0.6, 26.0)
        if s:
            y = _cone(s[0], s[1]) + 0.2
            w, d = rng.uniform(46.0, 70.0), rng.uniform(32.0, 50.0)
            c, sn = math.cos(s[2]), math.sin(s[2])
            q = [(s[0] + u * c - v * sn, y, s[1] + u * sn + v * c) for u, v in ((-w / 2, -d / 2), (-w / 2, d / 2), (w / 2, d / 2), (w / 2, -d / 2))]
            town.face(q, ("far_field", "far_field2", "far_field3")[n % 3])
    for n in range(7):
        s = spot("Rural", PLAY + 30.0, PLAY + 130.0, 0.55, 8.0)
        if s:
            if n < 3:
                block(s[0], s[1], s[2], 10.0, 16.0, 6.0, "far_red", "far_roof", 4.0)
            else:
                block(s[0], s[1], s[2], 9.0, 8.0, 5.5, "far_wall", "far_roof2", 2.4)
    for n in range(4):
        s = spot("Rural", PLAY + 30.0, PLAY + 140.0, 0.55, 6.0)
        if s:
            c, sn = math.cos(s[2] + math.pi / 2), math.sin(s[2] + math.pi / 2)
            for k in range(7):
                fir(s[0] + c * k * 7.0, s[1] + sn * k * 7.0, 11.0, "far_tree2")
    # firs about it all (cones: no round-leaf clumps), most between the zones' wedges, few past the City
    for n in range(160):
        a = rng.uniform(0.0, math.tau)
        if zone_at(a) == "City" and rng.random() < 0.8:
            continue
        r = rng.uniform(PLAY + 8.0, PLAY + 160.0)
        x, z = math.cos(a) * r, math.sin(a) * r
        if any(math.hypot(x - px, z - pz) < ps for px, pz, ps in placed):
            continue
        fir(x, z, rng.uniform(10.0, 16.0), "far_tree" if n % 3 else "far_tree2")
    town.done()
    # Rolling hills in the distance, ridge behind ridge as in a Ghibli background painting (the user, 2026-11-02:
    # "there should be rolling hills in the distance for the skybox", then "the hills in the distance need a little more
    # work, and some 2D anime style trees"): each ridge's face painted in its vertex colours (sky_paint: World draws
    # sky_ unshaded and out of the fog), darker forest green along its top fading to a pale band of mist at its foot,
    # each farther ridge bluer and paler; fields and little buildings on the nearer ones; flat painted trees (sky_tree,
    # textures/anime_tree.png) along the ridgelines and in copses down them, tinted by their ridge's haze.
    layers = [
        # (radius, height at the foot of its rounded tops, how high they roll, the colour along its top, its mist)
        # (their feet well over the far land's rim, which rises to about 18 m: lower, the ridges hid behind it and their
        # painted trees seemed to float in a ring over the far town; the user, 2026-11-02, "why is there a floating ring
        # of trees in the distance")
        (430.0, 30.0, 26.0, (0.24, 0.42, 0.30), (0.70, 0.82, 0.84)),
        (620.0, 44.0, 36.0, (0.34, 0.50, 0.50), (0.76, 0.85, 0.90)),
        (860.0, 56.0, 48.0, (0.48, 0.60, 0.70), (0.80, 0.87, 0.94)),
        (1150.0, 66.0, 62.0, (0.60, 0.70, 0.82), (0.84, 0.89, 0.96)),
    ]
    trees = PaintPiece("nocol_painted_trees")
    rng_s = random.Random(31)

    def lerp3(a, b, t):
        return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))

    for layer, (r, base, amp, top_colour, mist) in enumerate(layers):
        ridge = PaintPiece("nocol_ridges_%d" % layer)
        segs = 180
        seed = 1.3 + layer * 3.7

        def top_at(a):
            # (rounded rolling tops: a slow swell and a softer one, eased so the crests are round, not peaked)
            roll = noise.noise(Vector((math.cos(a) * 1.8, math.sin(a) * 1.8, seed))) * 0.65 + noise.noise(Vector((math.cos(a) * 4.2, math.sin(a) * 4.2, seed + 2.0))) * 0.35
            t = 0.5 + roll * 0.9
            t = max(0.0, min(1.0, t))
            return base + amp * (t * t * (3.0 - 2.0 * t))

        rows = [0.0, 0.18, 0.45, 0.75, 1.0]   # down the face from the top, out to the misty foot

        def at(a, row):
            top = top_at(a)
            return _ring_point(a, r - 110.0 * row, top + (-70.0 - top) * row)

        def colour(a, row):
            tone = 1.0 + 0.07 * noise.noise(Vector((math.cos(a) * 9.0, math.sin(a) * 9.0, seed + 5.0 + row * 3.0)))
            c = lerp3(top_colour, mist, min(1.0, row * row * 1.3 + row * 0.2))
            return tuple(min(1.0, v * tone) for v in c)

        for k in range(segs):
            a0, a1 = math.tau * k / segs, math.tau * (k + 1) / segs
            for j in range(len(rows) - 1):
                q = [at(a0, rows[j]), at(a0, rows[j + 1]), at(a1, rows[j + 1]), at(a1, rows[j])]
                ridge.paint(q, "sky_paint", [colour(a0, rows[j]), colour(a0, rows[j + 1]), colour(a1, rows[j + 1]), colour(a1, rows[j])])
        # fields and terraces, and little buildings, on the nearer two
        if layer < 2:
            for n in range(70 if layer == 0 else 40):
                a = rng_s.uniform(0.0, math.tau)
                row = rng_s.uniform(0.25, 0.6)
                c = at(a, row)
                inward = (-math.cos(a), -math.sin(a))
                side = (-math.sin(a), math.cos(a))
                w, h = rng_s.uniform(14.0, 30.0) * (1.0 + layer), rng_s.uniform(6.0, 12.0) * (1.0 + layer)
                field = lerp3((0.62, 0.70, 0.42) if n % 3 else (0.72, 0.70, 0.46), mist, 0.25 + 0.3 * layer + row * 0.3)
                p = (c[0] + inward[0] * 1.5, c[1], c[2] + inward[1] * 1.5)
                ridge.paint([(p[0] - side[0] * w / 2, p[1] - h / 2, p[2] - side[1] * w / 2), (p[0] + side[0] * w / 2, p[1] - h / 2, p[2] + side[1] * w / 2),
                             (p[0] + side[0] * w / 2, p[1] + h / 2, p[2] + side[1] * w / 2), (p[0] - side[0] * w / 2, p[1] + h / 2, p[2] - side[1] * w / 2)],
                            "sky_paint", [field] * 4)
            for n in range(90 if layer == 0 else 50):
                a = rng_s.uniform(0.0, math.tau)
                row = rng_s.uniform(0.45, 0.72)
                c = at(a, row)
                inward = (-math.cos(a), -math.sin(a))
                side = (-math.sin(a), math.cos(a))
                s = rng_s.uniform(3.0, 6.0) * (1.0 + 0.6 * layer)
                wall = lerp3((0.92, 0.9, 0.84), mist, 0.3 + 0.3 * layer)
                roof = lerp3((0.36, 0.40, 0.48) if n % 3 else (0.62, 0.38, 0.30), mist, 0.3 + 0.3 * layer)
                p = (c[0] + inward[0] * 3.0, c[1], c[2] + inward[1] * 3.0)
                ridge.paint([(p[0] - side[0] * s, p[1], p[2] - side[1] * s), (p[0] + side[0] * s, p[1], p[2] + side[1] * s),
                             (p[0] + side[0] * s, p[1] + s, p[2] + side[1] * s), (p[0] - side[0] * s, p[1] + s, p[2] - side[1] * s)], "sky_paint", [wall] * 4)
                ridge.paint([(p[0] - side[0] * s * 1.2, p[1] + s, p[2] - side[1] * s * 1.2), (p[0] + side[0] * s * 1.2, p[1] + s, p[2] + side[1] * s * 1.2),
                             (p[0], p[1] + s * 1.6, p[2])], "sky_paint", [roof] * 3)
        ridge.done()
        # the painted trees: along the ridgeline, and in copses down its face
        if layer < 3:
            tint = lerp3((0.44, 0.62, 0.44), mist, 0.15 + 0.3 * layer)
            dark = lerp3((0.30, 0.46, 0.34), mist, 0.15 + 0.3 * layer)
            count = (420, 320, 220)[layer]
            scale = (1.0, 1.5, 2.1)[layer]
            for n in range(count):
                a = rng_s.uniform(0.0, math.tau)
                if n % 3 == 0:
                    row = rng_s.uniform(0.15, 0.5)
                else:
                    row = rng_s.uniform(0.0, 0.05)
                base_p = at(a, row)
                copse = 1 + (rng_s.randint(0, 4) if n % 3 == 0 else rng_s.randint(0, 2))
                for c_ in range(copse):
                    da = rng_s.uniform(-0.004, 0.004) * (1.0 + c_)
                    p = at(a + da, row)
                    tall = rng_s.uniform(12.0, 20.0) * scale
                    wide = tall * rng_s.uniform(0.75, 1.0)
                    col = tint if (n + c_) % 3 else dark
                    for turn in (a, a + math.pi / 2):
                        ox, oz = -math.sin(turn) * wide / 2, math.cos(turn) * wide / 2
                        trees.paint([(p[0] - ox, p[1] - tall * 0.08, p[2] - oz), (p[0] + ox, p[1] - tall * 0.08, p[2] + oz),
                                     (p[0] + ox, p[1] + tall, p[2] + oz), (p[0] - ox, p[1] + tall, p[2] - oz)],
                                    "sky_tree", [col] * 4, [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)])
    trees.done()
    cascades()


def _peak(name, cx, cz, foot_y, height, foot_r, shape, seed, snow_line=0.55, crater=0.0):
    """A volcano of the Cascades, only to look at: rings up from its broad foot, `shape(s)` the radius at s (0 foot,
    1 top) as a share of foot_r; glaciers (snow) down from `snow_line`, tongues of it down the gullies; rock between;
    forest round its foot. A crater cuts its top flat at `crater` (St Helens)."""
    piece = w1.Piece(name)
    segs, rows = 72, 18
    rng = random.Random(seed)
    tongue = [snow_line - rng.uniform(0.0, 0.32) * (k % 3 != 1) for k in range(segs)]
    rough = [rng.uniform(0.94, 1.06) for _ in range(segs)]
    top_s = 1.0 - crater
    rings = []
    for j in range(rows + 1):
        s = top_s * j / rows
        radius = foot_r * shape(s)
        rings.append([(cx + math.cos(math.tau * k / segs) * radius * rough[k], foot_y + height * s, cz + math.sin(math.tau * k / segs) * radius * rough[k]) for k in range(segs)])
    for j in range(rows):
        s = top_s * (j + 0.5) / rows
        for k in range(segs):
            q = [rings[j][k], rings[j][(k + 1) % segs], rings[j + 1][(k + 1) % segs], rings[j + 1][k]]
            light = 0.84 + 0.24 * math.cos(math.tau * (k + 0.5) / segs - 2.4)
            mat = "sky_snow" if s > tongue[k] else ("sky_forest" if s < 0.16 else "sky_rock")
            piece.face(q, mat, light)
    if crater > 0.0:
        # the crater: a bowl open to the north
        inner = [(cx + (p[0] - cx) * 0.6, p[1] - height * 0.08, cz + (p[2] - cz) * 0.6) for p in rings[-1]]
        for k in range(segs):
            if abs(((math.tau * k / segs) + math.pi / 2 + math.pi) % math.tau - math.pi) < 0.5:
                continue
            piece.face([rings[-1][k], rings[-1][(k + 1) % segs], inner[(k + 1) % segs], inner[k]], "sky_rock", 0.8)
        piece.face(inner[::-1], "sky_rock", 0.7)
    else:
        piece.face(rings[-1][::-1], "sky_snow", 1.1)
    piece.done()


def cascades():
    """The mountains (the user, 2026-11-02: "it takes place in the PNW not japan the mountain should look more rainier
    like and there should be other mountains as well"): Rainier to the south-east, huge, broad and glaciated, its top a
    rounded dome; St Helens to the south, low, its top blown off into a crater; Adams beyond, broad; Baker far to the
    north; and the Olympics along the west, a jagged snowy range. Where each stands and its size are Claude's picks."""
    # Rainier: a broad foot swelling into steep shoulders and a rounded summit dome (no point, no flat cut)
    _peak("nocol_rainier", 520.0, 900.0, -90.0, 470.0, 820.0, lambda s: 0.06 + 0.94 * (1.0 - s) ** 1.9 + 0.05 * math.sin(math.pi * s) - 0.06 * s ** 6, 3, 0.5)
    # St Helens: lower, its top gone: a truncated cone with a crater open to the north
    _peak("nocol_st_helens", -260.0, 1150.0, -90.0, 260.0, 520.0, lambda s: 0.12 + 0.88 * (1.0 - s) ** 1.6, 5, 0.62, crater=0.22)
    # Adams: a broad lumpy dome far off to the south-south-east
    _peak("nocol_adams", 150.0, 1500.0, -90.0, 330.0, 700.0, lambda s: 0.1 + 0.9 * (1.0 - s) ** 1.4, 7, 0.45)
    # Baker: far to the north, a white cone
    _peak("nocol_baker", 200.0, -1600.0, -90.0, 360.0, 620.0, lambda s: 0.05 + 0.95 * (1.0 - s) ** 1.7, 9, 0.4)
    # The Olympics: a jagged range along the west, snow on the peaks
    range_ = w1.Piece("nocol_olympics")
    rng = random.Random(13)
    peaks = []
    a = math.radians(140.0)
    while a < math.radians(235.0):
        peaks.append((a, rng.uniform(150.0, 260.0)))
        a += rng.uniform(0.035, 0.07)
    r_top, r_foot = 1250.0, 1050.0
    for (a0, h0), (a1, h1) in zip(peaks, peaks[1:]):
        am = (a0 + a1) / 2
        hm = min(h0, h1) * rng.uniform(0.55, 0.75)   # the col between two peaks
        for (pa, ph), (qa, qh) in (((a0, h0), (am, hm)), ((am, hm), (a1, h1))):
            top_p, top_q = _ring_point(pa, r_top, -40.0 + ph), _ring_point(qa, r_top, -40.0 + qh)
            foot_p, foot_q = _ring_point(pa, r_foot, -80.0), _ring_point(qa, r_foot, -80.0)
            mid_p = _ring_point(pa, (r_top + r_foot) / 2, -40.0 + ph * 0.55)
            mid_q = _ring_point(qa, (r_top + r_foot) / 2, -40.0 + qh * 0.55)
            light = 0.86 + 0.2 * math.cos(pa * 7.0)
            range_.face([foot_p, foot_q, mid_q, mid_p], "sky_forest", light)
            range_.face([mid_p, mid_q, top_q, top_p], "sky_snow" if min(ph, qh) > 175.0 else "sky_rock", light)
    range_.done()


# --- The hill. The whole level is one hill (the user, 2026-11-02: "The level should be this whole hill"; "it should be
# a 4 sided hill with windy roads down each side, thus breaking the map up into 4 zones"), set in the Pacific
# Northwest ("it takes place in the PNW not japan"): the grove and the ring of lots on its top, and down each face a
# zone with its own theme and its own road layout (the user: "one of the zones should be a neighborhood under
# construction, one a more rural suburb vibe, one more commercial and city like, and one zone needs to be sewers,
# substations, factories and warehouses"; "and the zones need different road layouts"). Which face is which, and
# each layout, are Claude's picks:
#   W City:          a grid on the slope (a steep Seattle grid): a boulevard straight down with a planted median,
#                    three cross streets level across it with traffic lights, two avenues; brick commercial blocks and
#                    walk-ups, ornamental lamp posts, bus shelters, phone booths, the station at the foot.
#   E Industrial:    a trunk road straight down at an even grade, level gravel yard roads off it either side, the yards
#                    terraced below them (a factory with its stack, two warehouses, a fenced substation); an open sewer
#                    channel down its west side, manholes; cobra-head lights.
#   N Construction:  three runs and hairpins; houses going up along them (studs, scaffolding, tower cranes) between
#                    new box houses and bungalows, work lights on stands, the billboard.
#   S Rural:         one long lazy lane winding down, cul-de-sacs off it; a barn and its pasture, farmhouses, cabins,
#                    houses round the courts, an orchard, the woodlot with the hollow log.
# Every building is tools/buildings.py's (generated, a little level of its own), set on a lot levelled for it.
#
# Each face is built in its own frame, as if it were the south one (x across the face, z down it), and turned into
# place (Godot's turn about Y is Blender's about Z, the same angle). Its ground is the hill's slope, cut and built up
# to its roads, flattened under its yards, cut by its channel (ground_y), joined to the ridges between the faces.

HILL_EDGE = LOT[1] + 1.0   # the hilltop (the ring and its lots) is level out to here
HILL_SLOPE = 0.36     # how steeply the hill falls away along its ridges (between the faces) and beyond
FOOT_Y = -34.0        # the foot of the face being built (set by _use_face from FOOTS)
FOOT_Z = HILL_EDGE + 128.0      # where each face levels out at its foot
CORRIDOR = 56.0       # a face's zone: |x| within this (past it the face turns to the plain ridge)
PLAZA = (0.0, FOOT_Z + 16.0)    # the turning circle at the foot
CIRCLE = (3.5, 11.0, 15.0)      # its lawn, its road's outer edge, its pavement's
PLAY = PLAZA[1] + 36.0          # the play area: everything within this of the middle (the unseen wall round it)
# (the user, 2026-11-02: "the construction and suburb zone should be across from each other and should be flat not on a
# slope, and then the city and warehouse zone shoujld be across from each other and ona slope": the City and Rural
# sides swapped, so City faces Industrial and Rural faces Construction)
FACES = [
    (0.0, "S", "Rural"),
    (math.pi / 2, "E", "Industrial"),
    (math.pi, "N", "Construction"),
    (3 * math.pi / 2, "W", "City"),
]
_tag = "S"
_count = {"haunt": 20, "dog": 3, "kit": 0, "tree": 1200, "dumpster": 0}
_face_roads = {}      # face -> its roads
_face_pads = {}       # face -> its level yards: (x0, z0, x1, z1, y)
_face_channels = {}   # face -> its channels: (points, half, depth)
_roads = []           # the face being built's (or asked about)
_pads = []
_channels = []


def _smooth(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3.0 - 2.0 * t)


# How far each face falls to its foot (the user, 2026-11-02: "the hill slope doesn't need to be so severe in the
# zones", "or not all of them at least", then "the construction and suburb zone ... should be flat not on a slope",
# "the city and warehouse zone ... ona slope"): the City and Industrial sides on their slopes, the Construction and
# Rural sides level with the hilltop all the way out
FOOTS = {"City": -16.0, "Industrial": -14.0, "Construction": 0.0, "Rural": 0.0}
_turn_now = 0.0


def foot_at(a):
    """The foot's height in the way `a` (the world's angle across the ground): each face's, eased between them."""
    dirs = sorted(((math.pi / 2 - turn) % math.tau, FOOTS[zone]) for turn, _t, zone in FACES)
    a %= math.tau
    for (a0, y0), (a1, y1) in zip(dirs, dirs[1:] + [(dirs[0][0] + math.tau, dirs[0][1])]):
        if a0 <= a < a1 or a1 > math.tau and a < a1 - math.tau:
            t = ((a - a0) % math.tau) / (a1 - a0)
            return y0 + (y1 - y0) * t * t * (3.0 - 2.0 * t)
    return FOOT_Y


def slope_y(z):
    """The face's own fall, down from the hilltop's edge to the foot (a straight fall eased at both ends)."""
    if z <= HILL_EDGE:
        return 0.0
    t = min(1.0, (z - HILL_EDGE) / (FOOT_Z - HILL_EDGE))
    return FOOT_Y * (0.5 * t + 0.5 * t * t * (3.0 - 2.0 * t))


def _cone(x, z, turn=0.0):
    """The hill's ridges and beyond: falling evenly, then out into the valley's own lie. (x, z) in a frame turned
    `turn` (a face's), the world's by default."""
    r = math.hypot(x, z)
    if r <= HILL_EDGE:
        return 0.0
    a = math.atan2(z, x) - turn
    foot = foot_at(a)
    level = HILL_EDGE - foot / HILL_SLOPE
    if r <= level:
        return -HILL_SLOPE * (r - HILL_EDGE)
    return foot + (far_height(r, a) - foot) * _smooth(level, level + 28.0, r)


def natural(x, z):
    """A face's ground before its roads (its frame): level on top, its fall down the middle, the ridge to its sides."""
    r = math.hypot(x, z)
    if r <= HILL_EDGE:
        return 0.0
    outside = _cone(x, z, _turn_now)
    if z < HILL_EDGE * 0.35:
        return outside
    return slope_y(z) + (outside - slope_y(z)) * _smooth(CORRIDOR - 14.0, CORRIDOR + 2.0, abs(x))


class Road:
    """A road of a face: its centre (x, z, y) a point about every metre, its half width, its pavements' outer edge
    (no pavements when the same), its surface, its paint (None, "white" or "yellow" centre line), whether its cars go
    up and down it, and a turning bulb at its end. A road that `follow`s the slope takes its height from the face's
    fall at every point of it (the City's grid: where its streets cross, their surfaces meet with no step); one off a
    `base` road eases from that road's height to its own over its first metres (no step where it joins)."""

    def __init__(self, pts, half, pave=None, surface="asphalt", paint="white", main=False, bulb=0.0, follow=False, base=None):
        self.pts = pts
        self.follow = follow
        self.base = base
        self.half = half
        self.pave = pave if pave is not None else half
        self.surface = surface
        self.paint = paint
        self.main = main
        self.bulb = bulb
        xs = [p[0] for p in pts]
        zs = [p[1] for p in pts]
        grow = self.pave + 30.0 + bulb
        self.box = (min(xs) - grow, min(zs) - grow, max(xs) + grow, max(zs) + grow)

    def bench(self):
        return self.pave + 1.5

    def near(self, x, z):
        """How far (x, z) is from the road, and its height there (between its points; the bulb counts as the road)."""
        best, at = 1e9, 0
        for i, (px, pz, _py) in enumerate(self.pts):
            d = (x - px) * (x - px) + (z - pz) * (z - pz)
            if d < best:
                best, at = d, i
        best = math.sqrt(best)
        height = self.pts[at][2]
        # (along the segment to the neighbour it lies towards: the road's height there, not its nearest point's)
        for j in (at - 1, at + 1):
            if 0 <= j < len(self.pts):
                ax, az, ay = self.pts[at]
                bx, bz, by = self.pts[j]
                seg = (bx - ax) ** 2 + (bz - az) ** 2
                t = ((x - ax) * (bx - ax) + (z - az) * (bz - az)) / seg if seg > 1e-9 else 0.0
                if t > 0.0:
                    height = ay + (by - ay) * min(t, 1.0)
                    break
        if self.bulb > 0.0:
            ex, ez, ey = self.pts[-1]
            de = math.hypot(x - ex, z - ez) - (self.bulb - self.half)
            if de < best:
                best, height = max(de, 0.0), ey
        return best, self.y_at(x, z, height)

    def y_at(self, x, z, y):
        """The road's surface height at (x, z), y the height of its centre line there."""
        if self.follow:
            return slope_y(z)
        if self.base is not None:
            d, by = self.base.near(x, z)
            return by + (y - by) * _smooth(self.base.pave, self.base.pave + 8.0, d)
        return y


def trace(*parts, step=1.0):
    """The points of a line made of straight runs ("line", a, b) and arcs ("arc", centre, radius, from, to)."""
    pts = []
    for part in parts:
        if part[0] == "line":
            a, b = part[1], part[2]
            n = max(1, int(math.dist(a, b) / step))
            for i in range(n):
                t = i / n
                pts.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
        else:
            c, r, t0, t1 = part[1], part[2], part[3], part[4]
            n = max(2, int(abs(t1 - t0) * r / step))
            for i in range(n):
                t = t0 + (t1 - t0) * i / n
                pts.append((c[0] + math.cos(t) * r, c[1] + math.sin(t) * r))
    last = parts[-1]
    pts.append(last[2] if last[0] == "line" else (last[1][0] + math.cos(last[4]) * last[2], last[1][1] + math.sin(last[4]) * last[2]))
    return pts


def graded(xz, y0=0.0, y1=None):
    """Heights for a road down the face: level to the hilltop's edge, then an even grade to its end, eased in and out
    over its first and last 30 m (no kink for a car's wheels where the grade starts and ends)."""
    y1 = FOOT_Y if y1 is None else y1
    start = next((i for i, p in enumerate(xz) if p[1] >= HILL_EDGE + 0.5), 0)
    run = [0.0]
    for i in range(1, len(xz)):
        run.append(run[-1] + math.dist(xz[i - 1], xz[i]))
    total = max(run[-1] - run[start], 1e-6)
    ease = min(30.0, total / 4.0)
    grade = (y1 - y0) / (total - ease)

    def drop(s):
        if s < ease:
            return grade * s * s / (2.0 * ease)
        if s > total - ease:
            return (y1 - y0) - grade * (total - s) ** 2 / (2.0 * ease)
        return grade * (s - ease / 2.0)

    return [(x, z, y0 if i <= start else y0 + drop(run[i] - run[start])) for i, (x, z) in enumerate(xz)]


def sloped(xz):
    """Heights for a road that follows the face's fall (a grid street)."""
    return [(x, z, slope_y(z)) for x, z in xz]


def level(xz, y):
    return [(x, z, y) for x, z in xz]


def ground_y(x, z):
    """The face's ground as built (its frame): a channel's floor in the channel, a yard level, a road's shelf level, and
    between them the slope eased to them all (the nearer a road or yard, the more its height)."""
    for pts, half, depth in _channels:
        best, floor = 1e9, 0.0
        for px, pz, py in pts:
            d = math.hypot(x - px, z - pz)
            if d < best:
                best, floor = d, py
        if best <= half:
            return floor
    if abs(x) < 30.0 and z > FOOT_Z:
        return FOOT_Y
    n = natural(x, z)
    for x0, z0, x1, z1, y in _pads:
        if x0 <= x <= x1 and z0 <= z <= z1:
            return y
    for lot in _lots:
        u, v = _local(lot, x, z)
        if lot[6] is not None and abs(u) <= lot[4] and abs(v) <= lot[5]:
            return lot[6]
    total, weights, nearest = 0.0, 0.0, 1e9
    for road in _roads:
        bx0, bz0, bx1, bz1 = road.box
        if not (bx0 <= x <= bx1 and bz0 <= z <= bz1):
            continue
        d, y = road.near(x, z)
        out = d - road.bench()
        if out <= 0.0:
            if out < nearest:
                nearest = out
                inside = y - 0.12
            continue
        w = (1.0 - _smooth(0.0, 16.0, out)) ** 3 / (out + 0.5) ** 2
        total += w * y
        weights += w
    for x0, z0, x1, z1, y in _pads:
        out = max(x0 - x, x - x1, z0 - z, z - z1)
        if out < 12.0:
            w = (1.0 - _smooth(0.0, 12.0, out)) ** 3 / (out + 0.5) ** 2
            total += w * y
            weights += w
    for lot in _lots:
        u, v = _local(lot, x, z)
        out = max(abs(u) - lot[4], abs(v) - lot[5])
        if out < 10.0 and lot[6] is not None:
            w = (1.0 - _smooth(0.0, 10.0, out)) ** 3 / (out + 0.5) ** 2
            total += w * lot[6]
            weights += w
    if nearest < 1e8:
        return inside
    if weights <= 0.0:
        return n
    # (the natural ground's share grows as the roads' fall away)
    wn = 0.02
    return (total + wn * n) / (weights + wn)


def to_face(x, z, turn):
    """A point of the world in a face's frame (the face turned by `turn`)."""
    c, s = math.cos(turn), math.sin(turn)
    return x * c - z * s, x * s + z * c


def face_of(x, z):
    """The face a point of the world is on: the one it lies furthest down."""
    return max(range(len(FACES)), key=lambda f: to_face(x, z, FACES[f][0])[1])


def _use_face(f):
    global _roads, _pads, _channels, _lots, FOOT_Y, _turn_now
    _roads, _pads, _channels, _lots = _face_roads[f], _face_pads[f], _face_channels[f], _face_lots[f]
    _turn_now, FOOT_Y = FACES[f][0], FOOTS[FACES[f][2]]


def ground_global(x, z):
    """The ground as built anywhere in the world."""
    f = face_of(x, z)
    _use_face(f)
    lx, lz = to_face(x, z, FACES[f][0])
    return ground_y(lx, lz)


def in_gap(x, z):
    """Whether (x, z) is in one of the lots where a road leaves the ring (no lot there)."""
    a = math.atan2(z, x) % math.tau
    k = int(round(a / (math.tau / SECTORS))) % SECTORS
    return LOTS[k][0] == "road"



# --- each zone's roads (its frame)

TOP = (0.0, ROAD[1] - 0.5)     # where a street leaves the ring road
CROSS = [HILL_EDGE + 18.0 + 44.0 * k for k in range(3)]   # the City's cross streets
SPURS = [HILL_EDGE + 20.0, HILL_EDGE + 70.0]             # the Industrial zone's yard roads
LEGS = [HILL_EDGE + 11.0 + 34.0 * k for k in range(3)]    # the Construction zone's runs


def layout(zone):
    """The zone's roads, yards and channels."""
    roads, pads, channels = [], [], []
    if zone == "City":
        # a grid on the slope: a boulevard straight down, three cross streets level across it, two avenues down
        down = trace(("line", TOP, (0.0, PLAZA[1] - CIRCLE[1] + 1.0)))
        roads.append(Road(sloped(down), 8.5, 11.5, main=True, follow=True))
        for z in CROSS:
            roads.append(Road(level(trace(("line", (-46.0, z), (46.0, z))), slope_y(z)), 5.0, 7.5, follow=True))
        for x in (-38.0, 38.0):
            roads.append(Road(sloped(trace(("line", (x, CROSS[0]), (x, CROSS[-1])))), 4.5, 7.0, follow=True))
    elif zone == "Industrial":
        # a trunk road straight down at an even grade, level gravel yard roads off it either side, the yards below
        # them terraced into the slope; an open sewer channel down the west side
        roads.append(Road(graded(trace(("line", TOP, (0.0, PLAZA[1] - CIRCLE[1] + 1.0)))), 7.5, 9.5, main=True))
        trunk = roads[0]
        for z in SPURS:
            y = trunk.near(0.0, z)[1]
            for way in (-1.0, 1.0):
                roads.append(Road(level(trace(("line", (way * 9.0, z), (way * 50.0, z))), y), 3.5, 3.5, surface="gravel", paint=None, base=trunk))
                x0, x1 = sorted((way * 12.0, way * 50.0))
                pads.append((x0, z + 4.0, x1, z + 40.0, y + 0.05))
        line_pts = trace(("line", (-53.5, HILL_EDGE + 6.0), (-53.5, FOOT_Z + 30.0)))
        channels.append(([(x, z, natural(x, z) - 2.2 if z < FOOT_Z else FOOT_Y - 2.2) for x, z in line_pts], 2.0, 2.2))
    elif zone == "Construction":
        # three runs and hairpins
        b = 17.0
        main = trace(("line", TOP, (0.0, HILL_EDGE + 1.0)), ("arc", (10.0, HILL_EDGE + 1.0), 10.0, math.pi, math.pi / 2),
                     ("line", (10.0, LEGS[0]), (24.0, LEGS[0])), ("arc", (24.0, LEGS[0] + b), b, -math.pi / 2, math.pi / 2),
                     ("line", (24.0, LEGS[1]), (-24.0, LEGS[1])), ("arc", (-24.0, LEGS[1] + b), b, -math.pi / 2, -3 * math.pi / 2),
                     ("line", (-24.0, LEGS[2]), (-10.0, LEGS[2])), ("arc", (-10.0, LEGS[2] + 10.0), 10.0, -math.pi / 2, 0.0),
                     ("line", (0.0, LEGS[2] + 10.0), (0.0, PLAZA[1] - CIRCLE[1] + 1.0)))
        roads.append(Road(graded(main), 6.0, 8.5, main=True))
    else:
        # one long lazy lane winding down, cul-de-sacs off it
        xz = trace(("line", TOP, (0.0, HILL_EDGE + 1.0)))
        z = HILL_EDGE + 1.0
        while z < FOOT_Z + 6.0:
            z += 0.6
            xz.append((26.0 * math.sin(math.pi * (z - HILL_EDGE - 1.0) / 56.0) * _smooth(HILL_EDGE, HILL_EDGE + 20.0, z) * (1.0 - _smooth(FOOT_Z - 18.0, FOOT_Z + 4.0, z)), z))
        xz += trace(("line", xz[-1], (0.0, PLAZA[1] - CIRCLE[1] + 1.0)))[1:]
        roads.append(Road(graded(xz), 4.0, 4.0, paint="yellow", main=True))
        lane = roads[0]
        for z in (HILL_EDGE + 30.0, HILL_EDGE + 66.0, HILL_EDGE + 100.0):
            p = min(lane.pts, key=lambda q: abs(q[1] - z))
            way = -1.0 if p[0] > 0.0 else 1.0
            end = (p[0] + way * 24.0, p[1])
            if abs(end[0]) > CORRIDOR - 14.0:
                end = (math.copysign(CORRIDOR - 14.0, end[0]), p[1])
            roads.append(Road(level(trace(("line", (p[0] + way * 3.0, p[1]), end)), p[2]), 3.5, 3.5, paint=None, bulb=8.0, base=lane))
    return roads, pads, channels


# --- the ground

def hill_grid():
    """The hill's ground in 2 m squares: solid over the whole play area (the four faces and the ridges between),
    only to look at beyond it. The hilltop's own ground (ground()) has every 2 m square whose middle is within 74 m."""
    solid = w1.Piece("hill")
    view = w1.Piece("nocol_hill")
    step = 2.0
    reach = PLAY + 6.0
    n = int(reach * 2 / step)
    heights = {}

    def h(i, j):
        if (i, j) not in heights:
            heights[(i, j)] = ground_global(-reach + i * step, -reach + j * step)
        return heights[(i, j)]

    for i in range(n):
        for j in range(n):
            xa, za = -reach + i * step, -reach + j * step
            xm, zm = xa + step / 2, za + step / 2
            r = math.hypot(xm, zm)
            if r > reach or r < HILL_EDGE + 1.0:
                continue
            pts = [(xa, h(i, j), za), (xa, h(i, j + 1), za + step), (xa + step, h(i + 1, j + 1), za + step), (xa + step, h(i + 1, j), za)]
            if r < PLAY + 2.0:
                f = face_of(xm, zm)
                _use_face(f)
                lx, lz = to_face(xm, zm, FACES[f][0])
                under = any(road.near(lx, lz)[0] < road.half + 1.0 for road in _roads if road.box[0] <= lx <= road.box[2] and road.box[1] <= lz <= road.box[3])
                in_pad = any(x0 <= lx <= x1 and z0 <= lz <= z1 for x0, z0, x1, z1, _y in _pads)
                lot = next((lot for lot in _lots if lot[6] is not None and abs(_local(lot, lx, lz)[0]) <= lot[4] and abs(_local(lot, lx, lz)[1]) <= lot[5]), None)
                solid.face(pts, "dirt" if under else ("concrete" if in_pad else (lot[7] if lot else "grass")))
            else:
                view.face(pts, "far_green")
    solid.done()
    view.done()


# --- roads, paint, walls

def _side_of(road, i, sign):
    """The point beside road point i, `sign` metres to its right (of the way it runs)."""
    pts = road.pts
    x0, z0, _y = pts[max(i - 1, 0)]
    x1, z1, _y = pts[min(i + 1, len(pts) - 1)]
    dx, dz = x1 - x0, z1 - z0
    length = math.hypot(dx, dz) or 1.0
    rx, rz = -dz / length, dx / length
    x, z, y = pts[i]
    sx, sz = x + rx * sign, z + rz * sign
    return sx, sz, road.y_at(sx, sz, y)


def surface(road, k):
    """A road's carriageway and pavements (kerbed), its bulb, its paint."""
    piece = w1.Piece("road_%s_%d" % (_tag, k))
    mat = "asphalt" if road.surface == "asphalt" else "gravel"
    strips = [(-road.half, road.half, 0.03, mat)]
    if road.pave > road.half + 0.1:
        strips += [(-road.pave, -road.half, 0.12, "concrete"), (road.half, road.pave, 0.12, "concrete")]
    pts = road.pts
    me = _roads.index(road)

    def v(p, lift):
        return (p[0], p[2] + lift, p[1])

    def on_other(x, z, before):
        """Whether (x, z) is on another road's carriageway (only those drawn before this one if `before`)."""
        for j, other in enumerate(_roads):
            if other is road or before and j > me:
                continue
            if other.box[0] <= x <= other.box[2] and other.box[1] <= z <= other.box[3] and other.near(x, z)[0] < other.half - 0.05:
                return True
        return False

    for i in range(len(pts) - 1):
        if pts[i][1] < ROAD[1] - 0.6:
            continue
        for s0, s1, lift, m in strips:
            a0, a1 = _side_of(road, i, s0), _side_of(road, i, s1)
            b0, b1 = _side_of(road, i + 1, s0), _side_of(road, i + 1, s1)
            mx, mz = (a0[0] + a1[0] + b0[0] + b1[0]) / 4, (a0[1] + a1[1] + b0[1] + b1[1]) / 4
            # (where streets cross, the first road's carriageway is the crossing; pavements stop at a carriageway)
            if on_other(mx, mz, lift < 0.05):
                continue
            piece.face([v(a0, lift), v(a1, lift), v(b1, lift), v(b0, lift)], m)
            if lift > 0.05:
                for s in (s0, s1):
                    p, q = _side_of(road, i, s), _side_of(road, i + 1, s)
                    piece.face([v(p, -0.05), v(q, -0.05), v(q, lift), v(p, lift)], "concrete", 0.85)
    if road.bulb > 0.0:
        ex, ez, ey = pts[-1]
        segs = 20
        for s in range(segs):
            t0, t1 = math.tau * s / segs, math.tau * (s + 1) / segs
            piece.face([(ex, ey + 0.035, ez), (ex + math.cos(t1) * road.bulb, ey + 0.035, ez + math.sin(t1) * road.bulb),
                        (ex + math.cos(t0) * road.bulb, ey + 0.035, ez + math.sin(t0) * road.bulb)], mat)
    piece.done()
    if not road.paint:
        return
    # its paint (the user, 2026-11-02: "the road needs lines painted on it"): a dashed centre line (yellow on the
    # country lane), white edge lines on the town's roads, a median kerb on the boulevard
    paint = w1.Piece("nocol_road_paint_%s_%d" % (_tag, k))
    lift = 0.045
    for i in range(len(pts) - 1):
        if pts[i][1] < ROAD[1] + 1.0:
            continue
        lines = []
        if road.paint == "white":
            lines += [(-road.half + 0.3, -road.half + 0.45), (road.half - 0.45, road.half - 0.3)]
        if road.half > 8.0:
            lines += [(-1.1, -0.95), (0.95, 1.1)]
        elif (i // 3) % 2 == 0:
            lines.append((-0.08, 0.08))
        for s0, s1 in lines:
            a0, a1, b0, b1 = _side_of(road, i, s0), _side_of(road, i, s1), _side_of(road, i + 1, s0), _side_of(road, i + 1, s1)
            if on_other((a0[0] + b1[0]) / 2, (a0[1] + b1[1]) / 2, False):
                continue
            paint.face([v(a0, lift), v(a1, lift), v(b1, lift), v(b0, lift)], "yellow" if road.paint == "yellow" else "white")
    paint.done()


def zebra(road, i, name):
    """A zebra crossing across a road at its point i."""
    piece = w1.Piece("nocol_zebra_%s_%s" % (_tag, name))
    lift = 0.047
    c = -road.half + 0.9
    while c < road.half - 0.6:
        for j in range(max(i - 1, 0), min(i + 2, len(road.pts) - 1)):
            a0, a1, b0, b1 = _side_of(road, j, c - 0.22), _side_of(road, j, c + 0.22), _side_of(road, j + 1, c - 0.22), _side_of(road, j + 1, c + 0.22)
            piece.face([(a0[0], a0[2] + lift, a0[1]), (a1[0], a1[2] + lift, a1[1]), (b1[0], b1[2] + lift, b1[1]), (b0[0], b0[2] + lift, b0[1])], "white")
        c += 1.0
    piece.done()


def roadside_walls(road, k, plinths):
    """Block retaining walls along a road's shelf where the ground is cut or built up a good way (not where a plinth
    already stands)."""
    walls = w1.Piece("street_walls_%s_%d" % (_tag, k))
    for sign in (-1.0, 1.0):
        prev = None
        for i in range(0, len(road.pts), 2):
            x, z, y = road.pts[i]
            px, pz, _py = _side_of(road, i, sign * (road.bench() + 0.2))
            if z < HILL_EDGE + 1.0 or z > FOOT_Z or abs(px) > CORRIDOR + 1.0:
                prev = None
                continue
            if any(x0 <= px <= x1 and abs(pz - zf) < 2.6 for x0, x1, zf in plinths):
                prev = None
                continue
            nx, nz, _ny = _side_of(road, i, sign * (road.bench() + 2.4))
            lie = ground_y(nx, nz)
            if abs(lie - y) < 1.0:
                prev = None
                continue
            here = (px, pz, min(lie, y) - 0.3, max(lie, y))
            if prev:
                walls.face([(prev[0], prev[2], prev[1]), (here[0], here[2], here[1]), (here[0], here[3], here[1]), (prev[0], prev[3], prev[1])], "blockwall", 0.92)
            prev = here
    walls.done()


def turning_circle():
    """At the foot: the turning circle round a little lawn, paved round."""
    y = FOOT_Y
    square = w1.Piece("square_" + _tag)
    segs = 32
    cx, cz = PLAZA
    for s in range(segs):
        t0, t1 = math.tau * s / segs, math.tau * (s + 1) / segs
        for r0, r1, lift, mat in ((0.0, CIRCLE[0], 0.15, "grass"), (CIRCLE[0], CIRCLE[1], 0.03, "asphalt"), (CIRCLE[1], CIRCLE[2], 0.12, "concrete")):
            q = [(cx + math.cos(t0) * r0, y + lift, cz + math.sin(t0) * r0), (cx + math.cos(t0) * r1, y + lift, cz + math.sin(t0) * r1),
                 (cx + math.cos(t1) * r1, y + lift, cz + math.sin(t1) * r1), (cx + math.cos(t1) * r0, y + lift, cz + math.sin(t1) * r0)]
            square.face(q, mat)
        for r, lift in ((CIRCLE[0], 0.15), (CIRCLE[1], 0.12)):
            square.face([(cx + math.cos(t0) * r, y, cz + math.sin(t0) * r), (cx + math.cos(t1) * r, y, cz + math.sin(t1) * r),
                         (cx + math.cos(t1) * r, y + lift, cz + math.sin(t1) * r), (cx + math.cos(t0) * r, y + lift, cz + math.sin(t0) * r)], "concrete", 0.85)
    square.done()



def hill_wires(road):
    """Poles along a road on one side, a phone line from each to the next (a wire he walks), the power lines above."""
    poles = w1.Piece("climb_hill_poles_" + _tag)
    things = w1.Piece("hill_pole_things_" + _tag)
    tops, arms, last = [], [], None
    for i in range(10, len(road.pts) - 6, 22):
        x, z, y = _side_of(road, i, road.pave - 0.8)
        if z < HILL_EDGE + 3.0:
            continue
        y += 0.12
        poles.cylinder((x, y, z), 0.18, 8.2, "pole", 8)
        poles.cylinder((x, y, z), 0.21, 1.6, "sleeve", 8, cap=False)
        things.box((x, y + 7.67, z), (0.8, 0.14, 0.8), "pole")
        here = (x, y + 6.48, z)
        if last and math.dist(last, here) < 30.0:
            w1.wire(last, here, 3)
        last = here
    poles.done()
    things.done()


def hill_bound():
    """The unseen wall that keeps him in, round the whole hill near its foot."""
    bound = w1.Piece("hidden_bound")
    segs = 96
    for s in range(segs):
        a0, a1 = math.tau * s / segs, math.tau * (s + 1) / segs
        bound.face([_ring_point(a0, PLAY, -60.0), _ring_point(a1, PLAY, -60.0), _ring_point(a1, PLAY, 45.0), _ring_point(a0, PLAY, 45.0)], "concrete")
    bound.done()


def _mark_count(kind, name_fmt, at):
    empty = w1.mark(name_fmt % _count[kind], at)
    _count[kind] += 1
    return empty


def kit(at):
    """A lost kit sits here (the surface under it)."""
    _mark_count("kit", "kit_%d", at)


def haunt(at):
    _mark_count("haunt", "haunt_%d", at)


def dumpster(at, facing):
    """A dumpster stands here (the user, 2026-11-02: "there should be dumpsters to jump into"): the marker's -Z points
    the way its lid's front faces (`facing`, a way across the ground)."""
    _mark_count("dumpster", "dumpster_%d", at).rotation_euler = (0.0, 0.0, math.atan2(-facing[0], -facing[1]))


def tree_marker(x, z, size, kind):
    w1.mark("treep_%d_%d_%d_%s" % (_count["tree"], 400 + _count["tree"], size, kind), (x, ground_y(x, z) - 0.05, z))
    _count["tree"] += 1



def rail_fence(name, pts):
    """A split-rail fence along a line of points (x, z)."""
    piece = w1.Piece(name)
    for (ax, az), (bx, bz) in zip(pts, pts[1:]):
        n = max(1, int(math.dist((ax, az), (bx, bz)) / 3.0))
        for i in range(n + 1):
            t = i / n
            px, pz = ax + (bx - ax) * t, az + (bz - az) * t
            y = ground_y(px, pz)
            _bar(piece, (px, y - 0.2, pz), (px, y + 1.2, pz), 0.12, "darkwood")
            if i < n:
                qx, qz = ax + (bx - ax) * (i + 1) / n, az + (bz - az) * (i + 1) / n
                qy = ground_y(qx, qz)
                for hy in (0.5, 1.0):
                    _bar(piece, (px, y + hy, pz), (qx, qy + hy, qz), 0.08, "wood")
    piece.done()



# --- lots: where the generated buildings stand, levelled (an oriented rectangle each)

def _corners(r):
    cx, cz, ax, az, hu, hv = r[:6]
    return [(cx + ax * hu * su + az * hv * sv, cz + az * hu * su - ax * hv * sv) for su in (-1, 1) for sv in (-1, 1)]


def _overlap(r1, r2):
    """Whether two oriented rectangles (cx, cz, along x, along z, half along, half across) overlap."""
    c1, c2 = _corners(r1), _corners(r2)
    for r in (r1, r2):
        for ax, az in ((r[2], r[3]), (r[3], -r[2])):
            p1 = [x * ax + z * az for x, z in c1]
            p2 = [x * ax + z * az for x, z in c2]
            if max(p1) < min(p2) or max(p2) < min(p1):
                return False
    return True


def _local(r, x, z):
    dx, dz = x - r[0], z - r[1]
    return dx * r[2] + dz * r[3], dx * r[3] - dz * r[2]


def free_lot(r):
    """Whether a lot is clear of the face's roads and their pavements, channels, yards, other lots, the square at the
    foot, and stays on the face."""
    for x, z in _corners(r) + [(r[0], r[1])]:
        if abs(x) > CORRIDOR - 1.0 or z < HILL_EDGE + 2.0 or math.hypot(x, z) < HILL_EDGE + 2.0:
            return False
    reach = max(r[4], r[5])
    for road in _roads:
        if not (road.box[0] - reach <= r[0] <= road.box[2] + reach and road.box[1] - reach <= r[1] <= road.box[3] + reach):
            continue
        for px, pz, _py in road.pts:
            u, v = _local(r, px, pz)
            if abs(u) < r[4] + road.pave + 0.3 and abs(v) < r[5] + road.pave + 0.3:
                return False
        if road.bulb > 0.0:
            u, v = _local(r, road.pts[-1][0], road.pts[-1][1])
            if abs(u) < r[4] + road.bulb + 0.5 and abs(v) < r[5] + road.bulb + 0.5:
                return False
    for pts, half, _depth in _channels:
        for px, pz, _py in pts[::2]:
            u, v = _local(r, px, pz)
            if abs(u) < r[4] + half + 1.5 and abs(v) < r[5] + half + 1.5:
                return False
    for x0, z0, x1, z1, _y in _pads:
        if _overlap(r, ((x0 + x1) / 2, (z0 + z1) / 2, 1.0, 0.0, (x1 - x0) / 2, (z1 - z0) / 2)):
            return False
    for other in _lots:
        if _overlap(r, other):
            return False
    u, v = _local(r, PLAZA[0], PLAZA[1])
    if math.hypot(max(abs(u) - r[4], 0.0), max(abs(v) - r[5], 0.0)) < CIRCLE[2] + 1.0:
        return False
    return True


def lot_for(made, fx, fz, out, y, side=1.5):
    """The lot a building set at (fx, fz) facing `out` stands on: its footprint, a margin `side` either side (level
    ground beside it) and a metre behind."""
    width, depth = made["width"], made["depth"]
    ax, az = -math.sin(out), math.cos(out)
    cx, cz = fx + math.cos(out) * (depth + 1.0) / 2, fz + math.sin(out) * (depth + 1.0) / 2
    mat = "concrete" if made["kind"] in ("commercial", "factory", "warehouse", "substation", "walkup") else ("dirt" if made["kind"] == "construction" else "grass")
    return (cx, cz, ax, az, width / 2 + side, (depth + 1.0) / 2, y, mat)


def try_spot(made, fx, fz, out, y, side=1.5):
    """Sets `made` here if its lot is free (and takes the lot). Returns whether it was."""
    lot = lot_for(made, fx, fz, out, y, side)
    if not free_lot(lot):
        return False
    _lots.append(lot)
    set_made(made, fx, fz, out, y)
    made["lot"] = lot
    _face_made[_face].append(made)
    return True


def line_up(roads, kinds, prefix, seed, gap=1.0, every=3, sides=(-1.0, 1.0), limit=99):
    """Generated buildings along `roads`, both sides, at each spot where a lot is free (its front `gap` past the
    pavement): the kinds in turn, the next one tried where one does not fit. Returns those set."""
    placed = []
    pool = {}
    made_count = [0]

    def get(kind):
        if kind not in pool:
            n = made_count[0]
            made_count[0] += 1
            pool[kind] = made_at_origin(kind, "%s_%s_%d" % (prefix, _tag, n), seed + n)
        return pool[kind]

    for road in roads:
        for i in range(2, len(road.pts) - 2, every):
            if road.pts[i][1] < HILL_EDGE + 3.0:
                continue
            for sign in sides:
                if len(placed) >= limit:
                    break
                fx, fz, y = _side_of(road, i, sign * (road.pave + gap))
                cx, cz, _y = _side_of(road, i, sign * road.half)
                out = math.atan2(fz - cz, fx - cx)
                for j in range(len(kinds)):
                    kind = kinds[(len(placed) + j) % len(kinds)]
                    made = get(kind)
                    if try_spot(made, fx, fz, out, y + 0.14):
                        placed.append(made)
                        del pool[kind]
                        break
    for made in pool.values():
        drop_made(made)
    return placed


def fitting(kind, prefix, width, depth, seeds=range(1, 12)):
    """A generated `kind` no wider and deeper than given (trying seeds), or None."""
    for seed in seeds:
        made = made_at_origin(kind, "%s_%s" % (prefix, _tag), seed)
        if made["width"] <= width and made["depth"] <= depth:
            return made
        drop_made(made)
    return None


_face = 0
_face_made = {}    # face -> its buildings set (generated), in the face's frame
_face_lots = {}
_lots = []


def plan_face(f):
    """Builds each face's generated buildings and sets them on their lots (in its frame), before the ground is made
    (the lots level it)."""
    global _tag, _face
    _turn, _tag, zone = FACES[f]
    _face = f
    _use_face(f)
    _face_made[f] = []
    roads = _roads
    if zone == "City":
        # brick blocks and walk-ups facing the boulevard, a block each side between the cross streets; houses down the
        # avenues' outer sides; shops either side of the square at the foot
        line_up([roads[0]], ["commercial", "walkup", "commercial", "box"], "city", 300 + f)
        line_up(roads[4:6], ["box", "craftsman"], "city_house", 340 + f, every=4)
        for k, (x, out) in enumerate(((-CIRCLE[2] - 3.0, math.pi), (CIRCLE[2] + 3.0, 0.0))):
            made = fitting("commercial", "foot_shop_%d" % k, 26.0, 18.0)
            if made and not try_spot(made, x, PLAZA[1] + 2.0, out, FOOT_Y + 0.12, side=1.0):
                drop_made(made)
    elif zone == "Industrial":
        # a building to each yard, facing its yard road
        for k, (x0, z0, x1, z1, y) in enumerate(_pads):
            kind = ("factory", "warehouse", "substation", "warehouse")[k]
            made = fitting(kind, "%s_%d" % (kind, k), x1 - x0 - 1.0, z1 - z0 - 1.0)
            if made is None:
                print("ZONE Industrial: no %s fits yard %d" % (kind, k))
                continue
            set_made(made, (x0 + x1) / 2, z0 + 0.4, math.pi / 2, y)
            made["lot"] = ((x0 + x1) / 2, (z0 + z1) / 2, 1.0, 0.0, (x1 - x0) / 2, (z1 - z0) / 2, y, "concrete")
            _face_made[f].append(made)
    elif zone == "Construction":
        # (the billboard's spot kept clear first)
        _lots.append((-35.0, HILL_EDGE + 6.0, 1.0, 0.0, 3.0, 2.0, None, "grass"))
        line_up([roads[0]], ["construction", "box", "construction", "craftsman"], "site", 400 + f)
    else:
        # (the pasture, the orchard and the woodlot kept clear first: build_face lays them out)
        px = -38.0 if roads[0].pts[len(roads[0].pts) // 2][0] > 0 else 38.0
        _lots.append((px, FOOT_Z - 35.0, 1.0, 0.0, 13.0, 16.0, None, "grass"))
        _lots.append((-px * 0.5, HILL_EDGE + 46.0, 1.0, 0.0, 12.0, 9.0, None, "grass"))
        _lots.append((-px * 0.6, FOOT_Z + 6.0, 1.0, 0.0, 8.0, 8.0, None, "grass"))
        made = made_at_origin("barn", "barn_%s" % _tag, 0)
        spots = [(i, s) for i in range(30, len(roads[0].pts) - 30, 4) for s in (-1.0, 1.0)]
        for i, s in spots:
            fx, fz, y = _side_of(roads[0], i, s * (roads[0].pave + 4.0))
            cx, cz, _y = _side_of(roads[0], i, 0.0)
            if try_spot(made, fx, fz, math.atan2(fz - cz, fx - cx), y + 0.1, side=4.0):
                break
        else:
            drop_made(made)
        line_up([roads[0]], ["farmhouse", "craftsman", "aframe", "box"], "farm", 500 + f, gap=3.0, every=5)
        # houses round the cul-de-sacs' bulbs, facing in
        for k, road in enumerate(roads[1:]):
            ex, ez, ey = road.pts[-1]
            made = None
            for j in range(10):
                if made is None:
                    made = made_at_origin(("craftsman", "box", "aframe")[(k + j) % 3], "court_%s_%d_%d" % (_tag, k, j), 520 + k * 10 + j)
                a = math.tau * j / 10 + 0.3
                if try_spot(made, ex + math.cos(a) * (road.bulb + 1.5), ez + math.sin(a) * (road.bulb + 1.5), a, ey + 0.1):
                    made = None
            if made is not None:
                drop_made(made)


# --- each face

def build_face(f):
    """Everything down one face, in its own frame (to be turned into place), but its generated buildings (set by
    plan_face). Returns the zone's kit spots, easiest first."""
    global _tag, _face
    turn, _tag, zone = FACES[f]
    _face = f
    _use_face(f)
    rng = random.Random(50 + f)
    main = _roads[0]
    made = _face_made[f]
    furn = Furniture(_tag)
    lamp = {"City": "ornament", "Industrial": "cobra", "Construction": "work", "Rural": "cobra"}[zone]
    easy, middling, hard = [], [], []
    for k, road in enumerate(_roads):
        surface(road, k)
    zebra(main, next(i for i, p in enumerate(main.pts) if p[1] >= HILL_EDGE + 3.0), "top")
    # Street lights along every road, about 28 m apart, alternating sides; a stop sign where each side road meets the
    # main one and at the cul-de-sacs' mouths
    for k, road in enumerate(_roads):
        if road.surface != "asphalt" and zone != "Industrial":
            continue
        for n, i in enumerate(range(6, len(road.pts) - 3, 28)):
            if road.pts[i][1] < HILL_EDGE + 2.0:
                continue
            sign = 1.0 if n % 2 else -1.0
            x, z, y = _side_of(road, i, sign * (road.pave - 0.5))
            cx, cz, _y = _side_of(road, i, 0.0)
            furn.light((x, y + 0.12, z), (cx - x, cz - z), lamp)
        if k > 0:
            ends = [0] if road.bulb or zone == "Industrial" else [0, len(road.pts) - 1]
            for e in ends:
                i = min(max(e, 1), len(road.pts) - 2)
                inward = 1 if e == 0 else -1
                x, z, y = _side_of(road, i + inward * 2, -inward * (road.half + 0.6))
                ax_, az_, ay_ = road.pts[i]
                bx_, bz_, by_ = road.pts[i + inward]
                way = (ax_ - bx_, az_ - bz_)
                a0 = _side_of(road, i + inward * 2, 0.0)
                a1 = _side_of(road, i + inward * 2, -inward * road.half)
                furn.stop_sign((x, y + 0.12, z), (-way[0], -way[1]), ((a0[0], a0[2], a0[1]), (a1[0], a1[2], a1[1])))
    if zone == "City":
        # traffic lights where the cross streets cross the boulevard: a mast arm on two corners of each
        for z in CROSS:
            y = slope_y(z)
            for sx, sz in ((1.0, -1.0), (-1.0, 1.0)):
                furn.signal((sx * 10.5, y + 0.12, z + sz * 6.8), (-sx, 0.0), 7.5)
        # the boulevard's planted median, trees on it
        median = w1.Piece("median_" + _tag)
        for i in range(len(main.pts) - 1):
            if main.pts[i][1] < HILL_EDGE + 3.0 or any(abs(main.pts[i][1] - z) < 6.0 for z in CROSS):
                continue
            a0, a1, b0, b1 = _side_of(main, i, -0.9), _side_of(main, i, 0.9), _side_of(main, i + 1, -0.9), _side_of(main, i + 1, 0.9)
            median.face([(a0[0], a0[2] + 0.18, a0[1]), (a1[0], a1[2] + 0.18, a1[1]), (b1[0], b1[2] + 0.18, b1[1]), (b0[0], b0[2] + 0.18, b0[1])], "grass")
        median.done()
        for i in range(30, len(main.pts) - 20, 14):
            x, z, y = main.pts[i]
            if z > HILL_EDGE + 6.0 and not any(abs(z - zc) < 7.0 for zc in CROSS):
                tree_marker(x, z, 70, "maplelo")
        x, z, y = main.pts[len(main.pts) // 2 + 7]
        middling.append((x, y + 0.18, z))
        # bus shelters, benches and phone booths along the boulevard
        for n, i in enumerate((50, 95)):
            x, z, y = _side_of(main, i, -(main.half + 1.6) if n else main.half + 1.6)
            cx, cz, _y = _side_of(main, i, 0.0)
            hard.append(furn.bus_shelter((x, y + 0.12, z), (cx - x, cz - z)))
        for n, i in enumerate((30, 70, 110)):
            x, z, y = _side_of(main, i, main.pave - 0.9)
            cx, cz, _y = _side_of(main, i, 0.0)
            furn.bench((x, y + 0.12, z), (cx - x, cz - z))
        for i in (58, 102):
            x, z, y = _side_of(main, i, -(main.pave - 1.0))
            cx, cz, _y = _side_of(main, i, 0.0)
            hard.append(furn.booth((x, y + 0.12, z), (cx - x, cz - z)))
        # at the foot: the station, a bus shelter, benches and a phone in the square
        frame = station()
        hard.append(frame.p(10.0, 1.0, 8.0 + 2.2))
        cx, cz = PLAZA
        hard.append(furn.bus_shelter((cx + 7.0, FOOT_Y + 0.12, cz + CIRCLE[1] + 2.0), (0.0, -1.0)))
        for a in (0.6, 2.5, 3.8):
            furn.bench((cx + math.cos(a) * (CIRCLE[1] + 2.5), FOOT_Y + 0.12, cz + math.sin(a) * (CIRCLE[1] + 2.5)), (-math.cos(a), -math.sin(a)))
        furn.booth((cx - 6.0, FOOT_Y + 0.12, cz + CIRCLE[1] + 2.2), (0.0, -1.0))
        start = next(i for i, p in enumerate(main.pts) if p[1] >= HILL_EDGE - 20.0)
        w1.mark("race_start", (main.pts[start][0] + 3.0, main.pts[start][2] + 0.17, main.pts[start][1]))
        for k in range(8):
            x, z, y = main.pts[start + 10 + 13 * k]
            w1.mark("race_%d" % k, (x - 3.0, y + 0.4, z))
        x, z, y = main.pts[start + 10 + 13 * 8]
        w1.mark("cap_race", (x - 3.0, y + 0.6, z))
        for k, road in enumerate(_roads[1:4]):
            zebra(road, len(road.pts) // 2, "cross_%d" % k)
        for k in range(6):
            road = _roads[1 + k % 3]
            fx, fz, fy = _side_of(road, 8 + 30 * (k // 3), -(road.pave + 1.2))
            dumpster((fx, fy + 0.12, fz), (0.0, 1.0))
    elif zone == "Industrial":
        for m in made:
            if m["kind"] == "factory":
                # (its stack is the chimney to scurry up: the "Up the chimney" Bottlecap on top)
                w1.mark("cap_roof", m["at"])
            else:
                hard.append(m["at"])
        # the sewer channel: concrete walls down its sides, water along its floor, manholes on the trunk road
        pts, half, depth = _channels[0]
        walls = w1.Piece("channel_" + _tag)
        water = w1.Piece("nocol_channel_water_" + _tag)
        for (ax, az, ay), (bx, bz, by) in zip(pts, pts[1:]):
            for side in (-half, half):
                walls.face([(ax + side, ay, az), (bx + side, by, bz), (bx + side, by + depth + 0.3, bz), (ax + side, ay + depth + 0.3, az)], "concrete", 0.85)
            water.face([(ax - half, ay + 0.15, az), (bx - half, by + 0.15, bz), (bx + half, by + 0.15, bz), (ax + half, ay + 0.15, az)], "channel_water")
        walls.done()
        water.done()
        mid = pts[len(pts) // 2]
        hard.append((mid[0], mid[2], mid[1]))
        holes = w1.Piece("nocol_manholes_" + _tag)
        for i in range(40, len(main.pts) - 10, 45):
            x, z, y = main.pts[i]
            holes.cylinder((x + 2.5, y + 0.035, z), 0.4, 0.015, "black", 10)
        holes.done()
        # (dumpsters on the trunk road's shelf beside its pavements, between the yard roads)
        for k, z in enumerate((SPURS[0] + 12.0, SPURS[0] + 26.0, SPURS[1] + 12.0, SPURS[1] + 26.0, SPURS[1] - 14.0)):
            x = (main.pave + 1.1) * (1.0 if k % 2 else -1.0)
            dumpster((x, main.near(0.0, z)[1] - 0.05, z), (-math.copysign(1.0, x), 0.0))
        furn.booth((main.pave + 1.0, main.near(main.pave + 1.0, SPURS[1] - 12.0)[1] + 0.12, SPURS[1] - 12.0), (-1.0, 0.0))
        for z in (SPURS[0] - 9.0, SPURS[1] - 9.0):
            y = main.near(0.0, z)[1]
            hard.append(furn.bus_shelter((-(main.pave - 1.2), y + 0.12, z), (1.0, 0.0)))
    elif zone == "Construction":
        bz = HILL_EDGE + 6.0
        billboard(-35.0, bz, 1.0)
        w1.mark("cap_glide", (-35.0, 1.45, bz))
        for m in made:
            hard.append(m["at"])
            if m["kind"] == "construction":
                x0, z0, x1, z1 = m["bounds"]
                dumpster(m["place"]((x1 + 1.3, 0.0, z1 - 2.0)), (0.0, 1.0))
        for n, i in enumerate((60, 150)):
            x, z, y = _side_of(main, i, -(main.half + 1.6))
            cx, cz, _y = _side_of(main, i, 0.0)
            hard.append(furn.bus_shelter((x, y + 0.12, z), (cx - x, cz - z)))
            x, z, y = _side_of(main, i + 20, main.pave - 0.9)
            furn.bench((x, y + 0.12, z), (cx - x, cz - z))
    else:
        for m in made:
            hard.append(m["at"])
        # the pasture and its fence, the orchard, the woodlot with the hollow log
        side = -1.0 if main.pts[len(main.pts) // 2][0] > 0 else 1.0
        px = side * 38.0
        rail_fence("pasture_fence_" + _tag, [(px - 12.0, FOOT_Z - 50.0), (px + 12.0, FOOT_Z - 50.0), (px + 12.0, FOOT_Z - 20.0), (px - 12.0, FOOT_Z - 20.0), (px - 12.0, FOOT_Z - 50.0)])
        for k in range(12):
            ox, oz = -px * 0.5 + (k % 4) * 6.0 - 9.0, HILL_EDGE + 40.0 + (k // 4) * 6.0
            if not any(road.near(ox, oz)[0] < road.pave + 1.5 for road in _roads):
                tree_marker(ox, oz, 55, "maplelo")
        lx, lz = -px * 0.6, FOOT_Z + 6.0
        for k in range(6):
            a = math.tau * k / 6
            if not any(road.near(lx + math.cos(a) * 6.0, lz + math.sin(a) * 6.0)[0] < road.pave + 1.5 for road in _roads):
                tree_marker(lx + math.cos(a) * 6.0, lz + math.sin(a) * 6.0, 130, "firlo" if k % 2 else "redcedarlo")
        ly = ground_y(lx, lz)
        log = w1.Piece("log")
        for k in range(12):
            a0, a1 = math.tau * k / 12, math.tau * (k + 1) / 12
            outer = [(lx - 1.6, ly + 0.62 + math.sin(a0) * 0.62, lz + math.cos(a0) * 0.62), (lx + 1.6, ly + 0.62 + math.sin(a0) * 0.62, lz + math.cos(a0) * 0.62),
                     (lx + 1.6, ly + 0.62 + math.sin(a1) * 0.62, lz + math.cos(a1) * 0.62), (lx - 1.6, ly + 0.62 + math.sin(a1) * 0.62, lz + math.cos(a1) * 0.62)]
            inner = [(qx, ly + 0.62 + (qy - ly - 0.62) * 0.78, lz + (qz - lz) * 0.78) for qx, qy, qz in outer][::-1]
            log.face(outer, "darkwood")
            log.face(inner, "wood")
        log.done()
        w1.mark("cap_hidden", (lx, ly + 0.25, lz))
        # a forlorn phone booth by the lane, a bus shelter and weathered benches
        for n, i in enumerate((len(main.pts) // 3, 3 * len(main.pts) // 4)):
            x, z, y = _side_of(main, i, -(main.pave + 1.4))
            cx, cz, _y = _side_of(main, i, 0.0)
            if n == 0:
                hard.append(furn.booth((x, y + 0.05, z), (cx - x, cz - z)))
            else:
                hard.append(furn.bus_shelter((x, y + 0.05, z), (cx - x, cz - z)))
        for i in (len(main.pts) // 6, len(main.pts) // 2, 5 * len(main.pts) // 6):
            x, z, y = _side_of(main, i, main.pave + 1.2)
            cx, cz, _y = _side_of(main, i, 0.0)
            furn.bench((x, y + 0.05, z), (cx - x, cz - z), weathered=True)
        dumpster((main.pts[60][0] + main.pave + 3.0, main.pts[60][2] + 0.03, main.pts[60][1]), (-1.0, 0.0))
    # the lots: level ground beside each building (an easy kit beside the first few)
    for m in made:
        x0, z0, x1, z1 = m["bounds"]
        at = m["place"]((x1 + 1.0, 0.0, (z0 + z1) / 2))
        if m["lot"][4] - m["width"] / 2 >= 2.5 and zone != "Industrial":
            middling.append(at)
            w1.can(m["place"]((x0 - 1.2, 0.0, z1 - 0.8)))
    turning_circle()
    hill_wires(main)
    for k, road in enumerate(_roads):
        roadside_walls(road, k, [])
    # Crumbs along the main road's pavement, a few metres apart, and along the others (trimmed to the zone's 50
    # food at the end: markers' loose crumbs); easy kits on the main road's pavement
    for k, road in enumerate(_roads):
        for i in range(0, len(road.pts), 6 if road.main else 9):
            if road.pts[i][1] < HILL_EDGE + 2.0:
                continue
            x, z, y = _side_of(road, i, -(road.half + 0.8))
            LOOSE.add("crumb_%03d" % w1._count["crumb"])
            w1.crumb((x, y + 0.47, z))
    for t in (0.15, 0.4, 0.65, 0.9):
        i = int(len(main.pts) * t)
        x, z, y = _side_of(main, i, (main.half + main.pave) / 2 if main.pave > main.half + 0.5 else main.half - 0.6)
        easy.append((x, y + (0.12 if main.pave > main.half + 0.5 else 0.03), z))
    # Cars down the main road and back up it, round the circle at the foot; people on its pavement
    # (in the right-hand lane: on the boulevard the median is down the middle)
    lane = main.half * 0.45 if main.half > 8.0 else 0.0
    down = [(x, y, z) for x, z, y in (_side_of(main, i, -lane) for i in range(0, len(main.pts), 4)) if z >= ROAD[1] - 0.6]
    up = [(x, y, z) for x, z, y in (_side_of(main, i, lane) for i in range(0, len(main.pts), 4)) if z >= ROAD[1] - 0.6]
    cx, cz = PLAZA
    round_square = [(cx + math.cos(-math.pi / 2 + math.tau * s / 16) * (CIRCLE[0] + CIRCLE[1]) / 2, FOOT_Y + 0.03,
                     cz + math.sin(-math.pi / 2 + math.tau * s / 16) * (CIRCLE[0] + CIRCLE[1]) / 2) for s in range(1, 16)]
    loop = down + round_square + up[::-1][1:-1]
    for i, p in enumerate(loop):
        w1.mark("road_%d_%d" % (1 + f, i), p)
    walk = [_side_of(main, i, main.half + 1.2) for i in range(0, len(main.pts), 8) if main.pts[i][1] >= HILL_EDGE + 1.0]
    for i, (x, z, y) in enumerate(walk):
        w1.mark("walk_%d_%d" % (2 + f, i), (x, y + 0.12, z))
    # Checkpoints along the main road and at the foot; the zone's marker in the middle of the face
    for i in range(4):
        x, z, y = _side_of(main, int(len(main.pts) * (0.2 + 0.2 * i)), -(main.half + 1.2))
        w1.mark("check_%s_%d" % (_tag, i), (x, y + 0.3, z))
    w1.mark("check_foot_%s" % _tag, (0.0, FOOT_Y + 0.3, PLAZA[1] - CIRCLE[2] - 2.0))
    mid = HILL_EDGE + (FOOT_Z - HILL_EDGE) / 2
    w1.mark("zone_%d_%s" % (f, zone), (0.0, ground_y(0.0, mid), mid))
    # Places the wandering raccoons visit
    for i in (len(main.pts) // 3, 2 * len(main.pts) // 3):
        x, z, y = _side_of(main, i, main.pave + 1.5)
        haunt((x, ground_y(x, z), z))
    haunt((CIRCLE[2] - 2.0, FOOT_Y + 0.15, PLAZA[1] - 2.0))
    w1.mark("crows_%d" % (2 + f), (-CIRCLE[2] + 2.0, FOOT_Y + 0.12, PLAZA[1] + 2.0))
    if f == 0:
        w1.mark("hawk_1", (0.0, -18.0, mid))
    # Tall grass to hide in (World grows it), reeds by the wet ground, a dog's yard
    placed = 0
    for x, z in ((-46.0, HILL_EDGE + 30.0), (46.0, HILL_EDGE + 60.0), (-46.0, FOOT_Z - 10.0), (46.0, FOOT_Z - 30.0), (-30.0, HILL_EDGE + 70.0), (30.0, HILL_EDGE + 95.0)):
        if placed < 3 and free_lot((x, z, 1.0, 0.0, 3.5, 3.5)):
            empty = w1.mark("tallgrass_%s%d" % (_tag, placed), (x, ground_y(x, z), z))
            empty.scale = (3.5, 3.5, 3.5)
            placed += 1
    for n, (x, z) in enumerate(((50.0, HILL_EDGE + 45.0), (-50.0, FOOT_Z + 6.0))):
        empty = w1.mark("reeds_%s%d" % (_tag, n), (x, ground_y(x, z), z))
        empty.scale = (3.0, 3.0, 3.0)
    x, z, y = _side_of(main, len(main.pts) // 2, -(main.pave + 4.0))
    _mark_count("dog", "dog_%d", (x, ground_y(x, z) + 0.05, z))
    furn.done()
    # Lost kits (the user, 2026-11-02: "each of the 4 zones should have 10 raccoons to save"): ten, easy to hard
    spots = easy[:3] + middling[:3] + hard
    if len(spots) < 10:
        spots += easy[3:] + middling[3:]
    for at in spots[:10]:
        kit(at)
    if len(spots) < 10:
        print("ZONE %s has only %d kit spots" % (zone, len(spots)))
    return turn


LOOSE = set()     # the names of the loose crumbs (along the pavements): the ones trimmed to each zone's 50 food


def hill():
    """Everything down the hill: each face's roads laid out and its buildings set, the ground made from them all, the
    wall round it, then each face built in its frame and turned into place."""
    for f, (turn, _t, zone) in enumerate(FACES):
        global FOOT_Y, _turn_now
        _turn_now, FOOT_Y = turn, FOOTS[zone]
        roads, pads, channels = layout(zone)
        _face_roads[f], _face_pads[f], _face_channels[f] = roads, pads, channels
        _face_lots[f] = []
    for f in range(len(FACES)):
        plan_face(f)
    hill_grid()
    hill_bound()
    for f in range(len(FACES)):
        before = set(bpy.data.objects)
        turn = build_face(f)
        c, s = math.cos(turn), math.sin(turn)
        objs = (set(bpy.data.objects) - before) | {o for m in _face_made[f] for o in m["objs"]}
        for obj in objs:
            bx, by = obj.location.x, obj.location.y
            obj.location.x, obj.location.y = bx * c - by * s, bx * s + by * c
            obj.rotation_euler.z += turn
        print("ZONE %s buildings %d (%s)" % (FACES[f][2], len(_face_made[f]), ", ".join(m["kind"] for m in _face_made[f])))


def station():
    """The Station face's foot: the station, its platform and a train waiting, shops either side (Claude's picks)."""
    y = FOOT_Y
    frame = Frame.at(0.0, PLAZA[1] + CIRCLE[2] + 1.0, math.pi / 2, y + 0.12)
    house = w1.Piece("station")
    w, d, eave = 18.0, 8.0, 7.2
    frame.box(house, 0.0, d / 2, w, eave, d, "plaster2")
    frame.box(house, 0.0, d / 2, w + 0.3, 0.5, d + 0.3, "concrete", base=eave)
    frame.box(house, 0.0, -0.06, 4.0, 2.7, 0.14, "black")
    for wu in (-6.0, -3.5, 3.5, 6.0):
        window(frame, house, wu, 0.0, 1.8, 1.6, 0.9)
    for wu in (-6.0, -2.0, 2.0, 6.0):
        window(frame, house, wu, 0.0, 2.2, 1.3, 4.4)
    frame.box(house, 0.0, -1.3, 8.0, 0.2, 2.6, "concrete", base=3.0)
    # its name board over the door
    frame.box(house, 0.0, -0.1, 7.0, 1.3, 0.12, "white", base=5.6)
    frame.box(house, 0.0, -0.18, 6.4, 0.9, 0.06, "vend_blue", base=5.8)
    # a clock on a pole by the door
    _bar(house, frame.p(5.0, 0.0, -2.5), frame.p(5.0, 3.0, -2.5), 0.12, "metal")
    clock = frame.p(5.0, 3.3, -2.5)
    house.cylinder((clock[0], clock[1] - 0.35, clock[2]), 0.4, 0.7, "white", 12)
    house.done()
    platform = w1.Piece("platform")
    frame.box(platform, 0.0, d + 2.2, 44.0, 1.0, 4.4, "concrete")
    frame.box(platform, 0.0, d + 2.6, 4.0, 3.2, 0.2, "metal", base=1.0)
    frame.box(platform, 0.0, d + 2.6, 12.0, 0.15, 3.0, "metal", base=3.2)
    platform.done()
    track = w1.Piece("nocol_track")
    frame.box(track, 0.0, d + 6.3, 60.0, 0.25, 3.2, "stone")
    for side in (-0.75, 0.75):
        frame.box(track, 0.0, d + 6.3 + side, 60.0, 0.12, 0.08, "metal", base=0.25)
    track.done()
    train = w1.Piece("train")
    for car in (-19.0, 0.0, 19.0):
        frame.box(train, car, d + 6.3, 18.2, 3.2, 2.9, "green", base=0.6, top="white")
        frame.box(train, car, d + 6.3, 18.3, 0.9, 2.95, "awning", base=1.9)
        for wu in (-6.0, -2.0, 2.0, 6.0):
            frame.box(train, car + wu, d + 4.83, 1.6, 0.8, 0.04, "glass", base=1.95)
    train.done()
    # shops either side of the square
    return frame


def billboard(x, z, top):
    """A billboard on two tall posts, its walkway's top at `top` (the glide Bottlecap on it), the board on its downhill
    side (he glides in from the hilltop onto the walkway, not into the board's back)."""
    y = ground_y(x, z) - 0.1
    board = w1.Piece("billboard")
    board.box((x, top - 0.08, z), (4.0, 0.16, 1.6), "metal")
    for dx in (-1.8, 1.8):
        board.box((x + dx, (y + top) / 2, z + 0.6), (0.14, top - y, 0.14), "metal")
    board.box((x, top + 1.7, z + 0.8), (4.6, 3.4, 0.2), "yellow")
    board.done()


def _xz(p):
    return (p[0], p[2])


def markers(frames):
    # He starts in the grove, a step from its heart (the user, 2026-11-02: "you should spawn in the center of the
    # grove and there shouldnt be enemies there"): the band's base just in front of the great oak; nothing hunts him
    # within Hazards.HAVEN_RADIUS of the hill's middle (`haven`)
    hx, hz = OAK[0] * 0.55, OAK[1] * 0.55
    w1.mark("grove_heart", (hx, hill_height(hx, hz), hz))
    w1.mark("haven", (0.0, hill_height(0.0, 0.0), 0.0))
    # (facing south-east, out over the clearing: the spawn's turn is his facing_yaw)
    sx, sz = hx + 2.4, hz + 2.4
    w1.mark("spawn", (sx, hill_height(sx, sz) + 0.1, sz), 0.0)
    w1.mark("check_top", (sx, hill_height(sx, sz) + 0.1, sz))
    w1.mark("check_south", (0.0, 0.17, ROAD[1] + 1.2))
    w1.mark("check_east", (ROAD[1] + 1.2, 0.17, 0.0))
    w1.mark("check_west", (-ROAD[1] - 1.2, 0.17, 0.0))
    # Cars round the ring road; people on the pavements (none up in the grove)
    for i in range(28):
        a = math.tau * i / 28
        w1.mark("road_0_%d" % i, (math.cos(a) * ROAD_MIDDLE, 0.0, math.sin(a) * ROAD_MIDDLE))
    for i in range(15):
        a = math.tau * i / 28
        w1.mark("walk_0_%d" % i, (math.cos(a) * (ROAD[1] + 1.2), 0.0, math.sin(a) * (ROAD[1] + 1.2)))
        a2 = math.pi + math.tau * i / 28
        w1.mark("walk_1_%d" % i, (math.cos(a2) * (ROAD[0] - 1.2), 0.0, math.sin(a2) * (ROAD[0] - 1.2)))
    # The hawk over the houses to the north-west, crows by the shops and the flats, the fox's den in a back garden:
    # all out of the grove
    a = math.tau * 8 / SECTORS
    w1.mark("hawk_0", (math.cos(a) * (FRONT + 6.0), 0.0, math.sin(a) * (FRONT + 6.0)))
    for n, k in enumerate((1, 10)):
        a = math.tau * k / SECTORS
        w1.mark("crows_%d" % n, (math.cos(a) * (ROAD[1] + 1.8), 0.0, math.sin(a) * (ROAD[1] + 1.8)))
    w1.mark("den_0", frames[11].p(15.0, 0.05, 13.0))
    # Dogs' yards on the ring: beside the houses
    for n, k in enumerate((5, 11, 8)):
        w1.mark("dog_%d" % n, frames[k].p(-15.0, 0.05, 4.0))
    w1.mark("tallgrass_ring", frames[5].p(15.0, 0.0, 8.0)).scale = (2.0, 2.0, 2.0)
    # Yard cats about the town, on the outer pavement
    for k, a in enumerate((0.95, 2.6, 4.4, 5.6)):
        r = ROAD[1] + 1.9
        w1.mark("cat_%d" % k, (math.cos(a) * r, 0.17, math.sin(a) * r))
    w1.mark("cap_cats", (0.0, HILL_TOP + 0.6, 0.0))
    # Dumpsters round the ring (the faces' are in build_face), the lid's front to the road, a can beside
    for k in (1, 4, 7, 10):
        frame = frames[k]
        dumpster(frame.p(-15.5, 0.0, 6.0), (-frame.out[0], -frame.out[1]))
        w1.can(frame.p(-15.5, 0.0, 8.0))
    # Crumbs round the inner pavement
    for k in range(20):
        a = math.tau * k / 20
        w1.crumb((math.cos(a) * (ROAD[0] - 1.2), 0.35, math.sin(a) * (ROAD[0] - 1.2)))
    # Spots round town the wandering raccoons visit (haunt_1, 6, 7 are in the grove: grove())
    w1.mark("haunt_0", frames[1].p(-15.0, 0.0, 2.0))
    w1.mark("haunt_2", frames[4].p(15.0, 0.0, 1.0))
    w1.mark("haunt_4", frames[5].p(15.0, 0.0, 12.0))
    w1.mark("haunt_5", frames[1].p(15.0, 0.0, 1.0))
    w1.mark("haunt_8", frames[7].p(-15.0, 0.0, 12.0))
    w1.mark("haunt_12", frames[10].p(-15.0, 0.0, 5.0))


def _godot(obj):
    return (obj.location.x, obj.location.z, -obj.location.y)


def zone_food():
    """Each side zone's food made exactly 50 (the user, 2026-11-02: "each of the 4 zones should have 10 raccoons to
    save and 50 pieces of food"): the loose Crumbs, three a trash can, four a dumpster, counted in the zone Zones
    (scripts/zones.gd) puts them in (the grove within 72 m of the hill's middle, else the nearest zone marker); loose
    Crumbs along the pavements taken away, evenly, where there are too many. Prints each zone's count."""
    objs = {o.name: o for o in bpy.data.objects}
    middles = [(o.name, _godot(o)) for o in objs.values() if o.name.startswith("zone_")]

    def zone_of(p):
        if math.hypot(p[0], p[2]) < 72.0:
            return "Grove"
        return min(middles, key=lambda m: math.hypot(p[0] - m[1][0], p[2] - m[1][2]))[0]

    food, loose, others = {}, {}, {}
    for name, o in objs.items():
        worth = 1 if name.startswith("crumb_") else 3 if name.startswith("can_") else 4 if name.startswith("dumpster_") else 0
        if not worth:
            continue
        z = zone_of(_godot(o))
        food[z] = food.get(z, 0) + worth
        if name in LOOSE:
            loose.setdefault(z, []).append(o)
        elif worth == 1:
            others.setdefault(z, []).append(o)
    for z, total in sorted(food.items()):
        if z == "Grove":
            continue
        extra = total - 50
        spare = loose.get(z, []) + others.get(z, [])
        if extra > 0:
            step = len(spare) / extra if extra <= len(spare) else 1.0
            for k in range(min(extra, len(spare))):
                bpy.data.objects.remove(spare[int(k * step)])
            food[z] = total - min(extra, len(spare))
    kits = {}
    for o in bpy.data.objects:
        if o.name.startswith("kit_"):
            z = zone_of(_godot(o))
            kits[z] = kits.get(z, 0) + 1
    for z in sorted(food):
        print("ZONE FOOD %s %d kits %d" % (z, food[z], kits.get(z, 0)))


def snap_kits():
    """Each lost kit set down on the solid surface under it (within a metre): a building's route top is a little over
    its floor."""
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    scene = bpy.context.scene
    for o in bpy.data.objects:
        if not o.name.startswith("kit_"):
            continue
        start = o.location + Vector((0.0, 0.0, 0.4))
        for _try in range(6):
            hit, at, _n, _i, obj, _m = scene.ray_cast(depsgraph, start, Vector((0.0, 0.0, -1.0)), distance=1.6)
            if not hit:
                break
            if obj.name.startswith("nocol_") or "_paint" in obj.name:
                start = at - Vector((0.0, 0.0, 0.01))
                continue
            o.location.z = at.z + 0.02
            break


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    lots()
    frames = buildings_ring()
    poles_and_wires(frames)
    ring_furniture(frames)
    grove()
    hill()
    ground()
    markers(frames)
    beyond()
    zone_food()
    snap_kits()
    print("CRUMBS %d WIRES %d CANS %d LAMPS %d SIGNALS %d BUS STOPS %d BENCHES %d BOOTHS %d STOP SIGNS %d" % (
        w1._count["crumb"], w1._count["wire"], w1._count["can"], _furn_count["lamp"], _furn_count["signal"],
        _furn_count["busstop"], _furn_count["bench"], _furn_count["booth"], _furn_count["stop"]))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "tools", "town.blend"))
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(ROOT, "models", "world1.glb"),
        export_format="GLB",
        export_yup=True,
        export_animations=False,
        export_vertex_color="ACTIVE",
        export_extras=False,
    )
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == "MESH")
    print("BUILT town tris=%d" % tris)


def look(folder):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.render.resolution_x, scene.render.resolution_y = 1200, 900
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.55, 0.7, 0.85)
    for obj in bpy.data.objects:
        if obj.name.startswith("hidden_"):
            obj.hide_render = True
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.clip_end = 900.0
    scene.collection.objects.link(camera)
    scene.camera = camera
    for view, at, target in (("above", (0.01, 640.0, 0.0), (0.0, 0.0, 0.0)), ("south", (-30.0, 30.0, 80.0), (0.0, 4.0, 0.0)),
                             ("north", (20.0, 25.0, -75.0), (0.0, 2.0, 0.0)), ("street", (0.0, 2.0, 35.0), (-20.0, 3.0, 40.0)),
                             ("plaza", (8.0, 2.5, 24.0), (frame_x(3), 3.0, frame_z(3))), ("grove", (2.0, 9.0, 12.0), (0.0, 8.0, -6.0)),
                             ("hill_south", (10.0, 25.0, 250.0), (0.0, -12.0, 100.0)), ("hill_side", (130.0, 15.0, 110.0), (0.0, -15.0, 105.0)),
                             ("hill_street", (30.0, -5.0, 95.0), (-10.0, -12.0, 112.0))):
        camera.location = w1.to_blender(at)
        direction = w1.to_blender(target) - w1.to_blender(at)
        camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "town_%s.png" % view)
        bpy.ops.render.render(write_still=True)


def frame_x(k):
    return math.cos(math.tau * (k + 0.5) / SECTORS) * FRONT


def frame_z(k):
    return math.sin(math.tau * (k + 0.5) / SECTORS) * FRONT


build()
if PREVIEW_DIR:
    look(PREVIEW_DIR)
