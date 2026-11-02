"""World 1, the town: a little grove on a hill in the middle of a hillside town (the user, 2026-11-01: "The map should
be a little grove on a hill in the center of town"), after Pom Poko and Whisper of the Heart (the user, 2026-11-02: "the
town should be inspired by pom poko and whisper of the heart"; "Why is there a wall around the town?"). The layout and
what goes where are Claude's, taken from the films' stills:

- the grove: a shrine in the trees with a torii at the top of the path, stone lanterns, a thatched hut and pampas
  grass (Pom Poko's forest), the pond;
- a ring road round the hill with cars, pavements, concrete power poles hung with wires, transformers;
- the houses on terraced lots above the road, held up by concrete-block retaining walls (the slanted blocks of
  Whisper of the Heart's hillside streets), with steps up from the pavement; two-storey houses under tiled roofs, white
  apartment blocks (danchi), a bath house with a tall chimney, shops with vending machines, and the red antique shop
  with its gambrel roof and balcony on a little paved plaza;
- no wall round it: past the back of the lots the hill drops away, terrace by terrace, to the rest of the town spread
  over the valley below and green hills beyond (none of it solid). A rail runs along the brink, and an unseen wall
  (`hidden_bound`: World hides `hidden_` meshes but keeps them solid) keeps him in.

Run from the project root:
    blender -b --factory-startup --python tools/build_town.py [-- <folder>]   # the folder gets pictures of it

Writes models/world1.glb (the game's World 1) and tools/town.blend. Built on tools/build_world1.py's Piece and
markers (textures by material name, texture coordinates in metres, vertex shading), and its marker names
(see its docstring), plus:

    tree_<n>_<seed>_<size%>     a climbable tree (scripts/world.gd grows it)
    road_<loop>_<i>             a road loop's centre line, in order (cars: scripts/hazards.gd)
    walk_<route>_<i>            a path people walk there and back
    hawk_<n>, crows_<n>, den_<n> where the hawk circles, a band of crows hangs about, the fox lives
    grove_heart                 the middle of the grove's clearing: where the raccoons gather, and nothing hunts him
                                near it (Hazards.HAVEN_RADIUS)
    haunt_<n>                   spots round town wandering raccoons visit (bins, the shrine, the plaza, stairs, gardens)

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

ROOT = w1.ROOT
PREVIEW_DIR = w1.PREVIEW_DIR
random.seed(23)

w1.COLOURS.update({
    "blockwall": (0.84, 0.84, 0.80),
    "kawara": (0.50, 0.55, 0.64),
    "kawara2": (0.70, 0.40, 0.30),
    "kawara3": (0.36, 0.38, 0.44),
    "plaster": (0.93, 0.90, 0.82),
    "plaster2": (0.88, 0.86, 0.80),
    "shopred": (0.74, 0.38, 0.26),
    "thatch": (0.70, 0.58, 0.36),
    "glass": (0.30, 0.42, 0.50),
    "white": (0.95, 0.94, 0.90),
    "green": (0.22, 0.48, 0.44),
    "awning": (0.92, 0.88, 0.72),
    "rail": (0.66, 0.80, 0.76),
    "vermilion": (0.86, 0.30, 0.18),
    "black": (0.14, 0.13, 0.13),
    "straw": (0.82, 0.72, 0.46),
    "pampas": (0.88, 0.82, 0.62),
    "pampas_leaf": (0.52, 0.62, 0.32),
    "wire_dark": (0.12, 0.12, 0.14),
    "sleeve": (0.95, 0.78, 0.18),
    "vend_red": (0.84, 0.20, 0.18),
    "vend_blue": (0.22, 0.42, 0.78),
    # the town below and the hills (not textured: no moire far off)
    "far_green": (0.36, 0.58, 0.30),
    "far_forest": (0.24, 0.44, 0.28),
    "far_hill": (0.40, 0.56, 0.52),
    "far_wall": (0.80, 0.78, 0.72),
    "far_wall2": (0.72, 0.70, 0.66),
    "far_roof": (0.46, 0.52, 0.62),
    "far_roof2": (0.68, 0.40, 0.32),
    "far_roof3": (0.32, 0.34, 0.40),
    "far_road": (0.55, 0.55, 0.56),
    "far_tree": (0.20, 0.38, 0.24),
    "far_tree2": (0.28, 0.46, 0.26),
})

HILL_TOP = 7.0          # the plateau's height
PLATEAU = 9.0           # its radius
HILL_FOOT = 24.0        # where the hill meets the flat
ROAD = (26.0, 33.0)     # the ring road, inner and outer edge
ROAD_MIDDLE = 29.5
PAVE = 2.4              # the pavements either side of it
LOT = (36.5, 56.0)      # the terraced lots, from the retaining wall by the road to the brink at the back
FRONT = 38.5            # where the buildings' fronts stand
BOUND = 55.6            # the unseen wall that keeps him in (the rail stands just inside it)
POOL = (3.5, -2.5)      # a pond on top of the hill
POOL_RADII = (2.6, 2.0)
SECTORS = 10

# Each lot round the road (sector k spans angles k..k+1 tenths of a turn): what stands on it, and how high it is
# held above the road. (Claude's picks.)
LOTS = [
    ("house", 1.6, "kawara"),
    ("danchi", 2.4, None),
    ("sento", 0.12, None),
    ("antique", 0.12, None),
    ("shop", 0.12, None),
    ("house", 1.8, "kawara2"),
    ("danchi", 2.8, None),
    ("house_back", 0.12, "kawara3"),
    ("house", 1.4, "kawara"),
    ("shop", 0.12, None),
]


def hill_height(x, z):
    r = math.hypot(x, z)
    if r >= HILL_FOOT:
        return 0.0
    t = (r - PLATEAU) / (HILL_FOOT - PLATEAU)
    s = 1.0 - (t * t * (3.0 - 2.0 * t) if t > 0.0 else 0.0)
    lumps = 0.35 * noise.noise(Vector((x * 0.13, z * 0.13, 0.5))) * min(1.0, r / PLATEAU)
    h = HILL_TOP * s + lumps * s
    # the pond, sunk in the top
    d = math.hypot((x - POOL[0]) / POOL_RADII[0], (z - POOL[1]) / POOL_RADII[1])
    if d < 1.0:
        h -= 1.2 * min(1.0, (1.0 - d) / 0.35)
    return h


def path_point(t):
    """The path that winds up the hill, from the south foot (t 0) to the top (t 1)."""
    a = math.pi * 0.5 + t * math.tau * 0.95
    r = HILL_FOOT - (HILL_FOOT - PLATEAU) * t
    return math.cos(a) * r, math.sin(a) * r


def path_distance(x, z):
    """How far (x, z) is from the path that winds up the hill."""
    return min(math.dist((x, z), path_point(k / 79.0)) for k in range(80))


class Frame:
    """A lot's own directions: u along the road (anticlockwise), v out from the town's middle, y up; its origin on
    the ring of radius `r` at angle `a`."""

    def __init__(self, a, r, y=0.0):
        self.a, self.r, self.y = a, r, y
        self.along = (-math.sin(a), math.cos(a))
        self.out = (math.cos(a), math.sin(a))

    def p(self, u, y, v):
        cx, cz = self.out[0] * self.r, self.out[1] * self.r
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
    edge = LOT[0] + 2.0
    span = int(edge * 2 / step)
    heights = {}

    def h(i, j):
        if (i, j) not in heights:
            heights[(i, j)] = hill_height(-edge + i * step, -edge + j * step)
        return heights[(i, j)]

    for i in range(span):
        for j in range(span):
            xa, za = -edge + i * step, -edge + j * step
            xb, zb = xa + step, za + step
            xm, zm = xa + step / 2, za + step / 2
            r = math.hypot(xm, zm)
            if r > LOT[0] + 1.0:
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
            quad = [(math.cos(a0) * r0, y, math.sin(a0) * r0), (math.cos(a1) * r0, y, math.sin(a1) * r0),
                    (math.cos(a1) * r1, y, math.sin(a1) * r1), (math.cos(a0) * r1, y, math.sin(a0) * r1)]
            rings.face(quad, mat)
            if y > 0.05:
                for r in (r0, r1):
                    rings.face([(math.cos(a0) * r, 0.0, math.sin(a0) * r), (math.cos(a1) * r, 0.0, math.sin(a1) * r),
                                (math.cos(a1) * r, y, math.sin(a1) * r), (math.cos(a0) * r, y, math.sin(a0) * r)], "concrete", 0.85)
    rings.done()
    return piece.done()


def _ring_point(a, r, y):
    return (math.cos(a) * r, y, math.sin(a) * r)


def lots():
    """Each lot a terrace held up by a block wall by the road, steps up to it from the pavement, its back edge the
    brink of the drop to the town below (a rail along it)."""
    rails = w1.Piece("nocol_rails")
    for k, (kind, height, _roof) in enumerate(LOTS):
        a0, a1 = math.tau * k / SECTORS, math.tau * (k + 1) / SECTORS
        top = "grass" if kind.startswith("house") or kind == "danchi" else ("stone" if kind == "antique" else "concrete")
        wall = "blockwall" if height > 0.3 else "concrete"
        piece = w1.Piece("lot_%d" % k)
        segs = 8
        for s in range(segs):
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
    # The unseen wall that keeps him in, round the brink
    bound = w1.Piece("hidden_bound")
    segs = 72
    for s in range(segs):
        b0, b1 = math.tau * s / segs, math.tau * (s + 1) / segs
        bound.face([_ring_point(b0, BOUND, -10.0), _ring_point(b1, BOUND, -10.0), _ring_point(b1, BOUND, 45.0), _ring_point(b0, BOUND, 45.0)], "concrete")
    bound.done()
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


def house(k, a, height, roof, set_back=0.0):
    """A two-storey house as in Whisper of the Heart's streets (the user, 2026-11-02: "realistic big houses"): about
    11 m by 9, plaster walls, a tiled hip roof with deep eaves, a strip of roof over the ground-floor windows (a ledge),
    framed windows, a canopy over the door, a balcony with a laundry pole, an air conditioner, and a block wall round
    the front garden with its gate."""
    frame = Frame(a, FRONT + set_back, height)
    piece = w1.Piece("house_%d" % k)
    line = w1.Piece("nocol_laundry_%d" % k)
    rng = random.Random(40 + k)
    w, d, eave = 11.0, 9.0, 6.0
    v = d / 2
    frame.box(piece, 0.0, v, w, eave, d, "plaster")
    ridge = frame.hip_roof(piece, 0.0, v, w, d, eave, 2.4, roof, over=0.7)
    # the ground-floor roof strip along the front, a ledge to get up by
    frame.box(piece, 0.0, -0.5, w + 0.4, 0.14, 1.0, roof, base=2.85)
    # windows: two floors at the front, smaller ones behind
    for wu in (-3.4, 3.4):
        window(frame, piece, wu, 0.0, 1.8, 1.2, 0.9)
        window(frame, piece, wu, 0.0, 1.6, 1.1, 3.75)
        window(frame, piece, wu, d, 1.2, 0.9, 1.1, out=1.0)
        window(frame, piece, wu, d, 1.2, 0.9, 3.9, out=1.0)
    # the door under its canopy, a step up to it
    frame.box(piece, 0.0, -0.05, 1.0, 2.1, 0.12, "door")
    frame.box(piece, 0.0, -0.45, 1.7, 0.1, 0.9, roof, base=2.35)
    frame.box(piece, 0.0, -0.35, 1.5, 0.15, 0.7, "concrete")
    # the balcony on the first floor over the roof strip: a slab, a rail, a glass door, a laundry pole
    frame.box(piece, 0.0, -0.6, 3.8, 0.16, 1.2, "concrete", base=2.99)
    for bu in (-1.8, -0.9, 0.0, 0.9, 1.8):
        frame.box(piece, bu, -1.15, 0.06, 1.0, 0.06, "metal", base=3.15)
    frame.box(piece, 0.0, -1.15, 3.7, 0.06, 0.08, "metal", base=4.15)
    window(frame, piece, 0.0, 0.0, 1.6, 2.0, 3.2, sill=False)
    laundry(frame, line, -1.7, 1.7, -0.85, 5.1, rng)
    # an air conditioner by the wall
    frame.box(piece, -4.6, -0.3, 0.8, 0.6, 0.35, "white", base=0.0)
    garden_wall(frame, piece, -1.85, w / 2 + 1.2, 1.0)
    piece.done()
    line.done()
    # crumbs along the ridge
    inset = max(w / 2 + 0.7 - (d / 2 + 0.7), 0.2)
    w1.crumb_line(frame.p(-inset, ridge + 0.4, v), frame.p(inset, ridge + 0.4, v), 3)
    return frame


def back_house(name, frame, u, v0, roof, eave=5.6):
    """A house in the second row, behind the front one: two storeys, a tiled hip roof, framed windows to the road,
    a roof strip, an air conditioner."""
    piece = w1.Piece(name)
    w, d = 8.5, 6.5
    v = v0 + d / 2
    frame.box(piece, u, v, w, eave, d, "plaster" if len(name) % 2 else "plaster2")
    frame.hip_roof(piece, u, v, w, d, eave, 2.1, roof, over=0.6)
    for wu in (-2.2, 2.2):
        window(frame, piece, u + wu, v0, 1.5, 1.1, 0.9)
        window(frame, piece, u + wu, v0, 1.4, 1.0, 3.6)
    frame.box(piece, u, v0 - 0.45, w + 0.3, 0.12, 0.9, roof, base=2.75)
    frame.box(piece, u, v0 - 0.05, 1.0, 2.1, 0.12, "door")
    frame.box(piece, u + w / 2 - 0.6, v0 - 0.3, 0.8, 0.6, 0.35, "white")
    piece.done()


def danchi(k, a, height):
    """A white apartment block (the user, 2026-11-02: "apartment buildings"), five storeys of four flats each: along
    the road side a balcony to every flat with its dividers, solid white parapets and laundry rails; behind, two
    stairwells with open landings rising to little rooftop houses; a flat roof with a parapet and a water tank on
    legs."""
    frame = Frame(a, FRONT + 1.0, height)
    piece = w1.Piece("danchi_%d" % k)
    line = w1.Piece("nocol_laundry_d%d" % k)
    rng = random.Random(70 + k)
    w, d, floors, storey = 21.0, 9.0, 5, 2.8
    tall = floors * storey
    v = d / 2
    flat = w / 4
    frame.box(piece, 0.0, v, w, tall, d, "plaster2")
    # the parapet round the roof
    for side in (-1, 1):
        frame.box(piece, 0.0, v + side * (d / 2 - 0.15), w, 0.7, 0.3, "plaster2", base=tall)
        frame.box(piece, side * (w / 2 - 0.15), v, 0.3, 0.7, d, "plaster2", base=tall)
    for f in range(floors):
        base = f * storey
        for i in range(4):
            u = -w / 2 + flat * (i + 0.5)
            # (the glass door onto the balcony, and a window beside it; small windows behind)
            window(frame, piece, u - 0.6, 0.0, 1.9, 2.0, base + 0.2, sill=False)
            window(frame, piece, u + 1.5, 0.0, 0.9, 1.0, base + 1.0)
            if u < -7.0 or u > -5.0 and u < 0.5 or u > 3.5:
                window(frame, piece, u, d, 1.4, 0.9, base + 1.2, out=1.0)
        if f > 0:
            # the balcony slab and its parapet along the whole face, the dividers between the flats
            frame.box(piece, 0.0, -0.6, w, 0.16, 1.2, "white", base=base)
            frame.box(piece, 0.0, -1.15, w, 1.0, 0.12, "white", base=base + 0.16)
            for i in range(1, 4):
                frame.box(piece, -w / 2 + flat * i, -0.6, 0.1, storey - 0.16, 1.2, "plaster2", base=base + 0.16)
            for i in range(4):
                u = -w / 2 + flat * (i + 0.5)
                _bar(line, frame.p(u - flat / 2 + 0.3, base + 1.9, -0.9), frame.p(u + flat / 2 - 0.3, base + 1.9, -0.9), 0.04, "metal")
                if rng.random() < 0.6:
                    laundry(frame, line, u - flat / 2 + 0.4, u + flat / 2 - 0.4, -0.9, base + 1.88, rng)
    # the stairwells behind, open at every landing, up to their little houses on the roof
    for su in (-6.0, 2.0):
        frame.box(piece, su, d + 1.1, 2.8, tall + 2.4, 2.2, "plaster2")
        frame.box(piece, su, d + 1.1, 3.1, 0.15, 2.5, "concrete", base=tall + 2.4)
        for f in range(floors):
            frame.box(piece, su, d + 2.22, 2.0, 1.1 if f else 2.1, 0.06, "black", base=f * storey + (1.3 if f else 0.0))
    piece.done()
    line.done()
    tank = w1.Piece("danchi_tank_%d" % k)
    c = frame.p(5.5, tall, v)
    for lu, lv in ((-0.9, -0.9), (0.9, -0.9), (-0.9, 0.9), (0.9, 0.9)):
        leg = frame.p(5.5 + lu, tall, v + lv)
        _bar(tank, leg, (leg[0], leg[1] + 1.4, leg[2]), 0.12, "metal")
    tank.cylinder((c[0], c[1] + 1.4, c[2]), 1.4, 0.15, "metal", 12)
    tank.cylinder((c[0], c[1] + 1.55, c[2]), 1.3, 2.2, "plaster2", 12)
    tank.done()
    w1.crumb_line(frame.p(-8.0, tall + 0.45, v), frame.p(3.0, tall + 0.45, v), 5)
    return frame


def sento(k, a, height):
    """The bath house: a big tiled hip roof, and its tall chimney behind to scurry up (the Bottlecap on top)."""
    frame = Frame(a, FRONT, height)
    piece = w1.Piece("sento_%d" % k)
    w, d, eave = 12.0, 10.0, 4.6
    v = d / 2
    frame.box(piece, 0.0, v, w, eave, d, "plaster")
    ridge = frame.hip_roof(piece, 0.0, v, w, d, eave, 3.0, "kawara3", over=0.7)
    frame.box(piece, 0.0, -0.05, 3.0, 2.3, 0.12, "awning")   # the noren over the door
    frame.box(piece, 0.0, -0.06, 2.4, 2.0, 0.14, "door")
    for wu in (-4.2, 4.2):
        frame.box(piece, wu, -0.04, 2.0, 1.0, 0.1, "glass", base=2.6)
    piece.done()
    # the chimney (anything named climb_ he can scurry up)
    chimney = w1.Piece("climb_chimney")
    top = 15.0
    frame.box(chimney, 3.5, d + 1.2, 1.4, top, 1.4, "brick")
    frame.box(chimney, 3.5, d + 1.2, 1.9, 0.25, 1.9, "concrete", base=top)
    chimney.done()
    w1.mark("cap_roof", frame.p(3.5, top + 0.7, d + 1.2))
    inset = max(w / 2 + 0.7 - (d / 2 + 0.7), 0.2)
    w1.crumb_line(frame.p(-inset, ridge + 0.4, v), frame.p(inset, ridge + 0.4, v), 3)
    return frame


def antique(k, a, height):
    """The antique shop: red plaster, a gambrel roof whose end faces the plaza, a balcony with white balusters,
    awnings over the windows, green door and shutters; a barrel of flowers by the door; a round paved plaza in front."""
    frame = Frame(a, FRONT + 1.5, height)
    piece = w1.Piece("antique_%d" % k)
    w, d, eave = 8.0, 9.0, 3.4
    v = d / 2
    frame.box(piece, 0.0, v, w, eave, d, "shopred")
    knee_u, knee_y, ridge_y = w / 2 * 0.72, eave + 2.3, eave + 3.4
    over = 0.35
    profile = [(-w / 2 - over, eave - 0.25), (-knee_u, knee_y), (0.0, ridge_y), (knee_u, knee_y), (w / 2 + over, eave - 0.25)]
    # the roof slopes, along the depth
    for i in range(4):
        (u0, y0), (u1, y1) = profile[i], profile[i + 1]
        piece.face([frame.p(u0, y0, -over), frame.p(u1, y1, -over), frame.p(u1, y1, d + over), frame.p(u0, y0, d + over)], "kawara3", 1.0 if i % 3 == 0 else 1.1)
    # the gable ends, red plaster, white-edged
    for vv in (0.0, d):
        gable = [frame.p(-w / 2, eave, vv), frame.p(-knee_u, knee_y, vv), frame.p(0.0, ridge_y, vv), frame.p(knee_u, knee_y, vv), frame.p(w / 2, eave, vv)]
        piece.face(gable if vv else gable[::-1], "shopred", 0.95)
    for i in range(4):
        (u0, y0), (u1, y1) = profile[i], profile[i + 1]
        _bar(piece, frame.p(u0, y0 + 0.08, -over - 0.02), frame.p(u1, y1 + 0.08, -over - 0.02), 0.22, "white")
    # the balcony
    frame.box(piece, 0.0, -0.5, 3.2, 0.2, 1.0, "white", base=eave + 0.05)
    for bu in (-1.4, -1.0, -0.6, -0.2, 0.2, 0.6, 1.0, 1.4):
        frame.box(piece, bu, -0.9, 0.12, 0.75, 0.12, "white", base=eave + 0.25)
    frame.box(piece, 0.0, -0.9, 3.2, 0.12, 0.2, "white", base=eave + 1.0)
    frame.box(piece, 0.0, -0.04, 1.4, 1.6, 0.1, "glass", base=eave + 0.3)
    for su in (-1.05, 1.05):
        frame.box(piece, su, -0.06, 0.6, 1.6, 0.1, "green", base=eave + 0.3)
    # the door, the windows, their awnings
    frame.box(piece, 0.0, -0.05, 1.4, 2.4, 0.12, "green")
    frame.box(piece, 0.0, -0.06, 1.0, 2.2, 0.14, "black")
    for wu in (-2.6, 2.6):
        frame.box(piece, wu, -0.04, 1.3, 1.4, 0.1, "green", base=0.9)
        frame.box(piece, wu, -0.05, 1.0, 1.1, 0.12, "glass", base=1.05)
        piece.face([frame.p(wu - 0.8, 2.75, -0.05), frame.p(wu + 0.8, 2.75, -0.05), frame.p(wu + 0.8, 2.35, -0.75), frame.p(wu - 0.8, 2.35, -0.75)], "awning", 1.05)
    piece.face([frame.p(-1.2, 2.85, -0.05), frame.p(1.2, 2.85, -0.05), frame.p(1.2, 2.5, -0.7), frame.p(-1.2, 2.5, -0.7)], "awning", 1.05)
    piece.done()
    barrel = w1.Piece("barrel")
    c = frame.p(-1.3, 0.0, -0.5)
    barrel.cylinder(c, 0.35, 0.7, "wood", 10, top="pampas_leaf")
    barrel.done()
    # the plaza: a round of paving between the road's pavement and the shop
    plaza = w1.Piece("plaza")
    centre = frame.p(0.0, 0.0, -2.2)
    segs = 24
    for s in range(segs):
        t0, t1 = math.tau * s / segs, math.tau * (s + 1) / segs
        plaza.face([(centre[0], height + 0.02, centre[2]), (centre[0] + math.cos(t1) * 3.0, height + 0.02, centre[2] + math.sin(t1) * 3.0),
                    (centre[0] + math.cos(t0) * 3.0, height + 0.02, centre[2] + math.sin(t0) * 3.0)], "concrete")
    plaza.done()
    w1.crumb_line(frame.p(0.0, ridge_y + 0.4, 0.5), frame.p(0.0, ridge_y + 0.4, d - 0.5), 3)
    return frame


def shop(k, a, height):
    """A corner shop: two storeys, a flat roof, an awning, a big shop window, vending machines by the door."""
    frame = Frame(a, FRONT, height)
    piece = w1.Piece("shop_%d" % k)
    w, d, eave = 11.0, 9.0, 5.5
    v = d / 2
    frame.box(piece, 0.0, v, w, eave, d, "plaster2")
    frame.box(piece, 0.0, v, w + 0.3, 0.5, d + 0.3, "concrete", base=eave)
    frame.box(piece, 0.0, v, w - 0.6, 0.12, d - 0.6, "concrete", base=eave + 0.42)
    frame.box(piece, -1.0, -0.04, 6.0, 1.9, 0.1, "glass", base=0.3)
    frame.box(piece, 3.4, -0.05, 1.2, 2.2, 0.12, "glass")
    for wu in (-3.0, 0.5, 3.6):
        frame.box(piece, wu, -0.04, 1.6, 1.1, 0.1, "glass", base=3.4)
    # the awning (striped red and white: two strips)
    for i, mat in enumerate(("red", "awning", "red")):
        u0 = -w / 2 + 0.3 + i * (w - 0.6) / 3
        u1 = u0 + (w - 0.6) / 3
        piece.face([frame.p(u0, 2.95, -0.05), frame.p(u1, 2.95, -0.05), frame.p(u1, 2.55, -1.4), frame.p(u0, 2.55, -1.4)], mat, 1.05)
    piece.done()
    # vending machines out front (solid: a step up)
    vend = w1.Piece("vending_%d" % k)
    for i, (vu, mat) in enumerate(((w / 2 + 0.6, "vend_red"), (w / 2 + 1.65, "vend_blue"))):
        frame.box(vend, vu, 0.5, 1.0, 1.8, 0.75, mat, top="white")
        frame.box(vend, vu, 0.12, 0.8, 1.0, 0.04, "window", base=0.75)
    vend.done()
    w1.crumb_line(frame.p(-w / 2 + 1.5, eave + 1.0, v), frame.p(w / 2 - 1.5, eave + 1.0, v), 4)
    return frame


def buildings():
    """What stands on each lot, and the trash cans by the doors and at the steps."""
    haunts = {}
    for k, (kind, height, roof) in enumerate(LOTS):
        a = math.tau * (k + 0.5) / SECTORS
        if kind == "house":
            frame = house(k, a, height, roof)
        elif kind == "house_back":
            frame = house(k, a, height, roof, set_back=5.0)
        elif kind == "danchi":
            frame = danchi(k, a, height)
        elif kind == "sento":
            frame = sento(k, a, height)
        elif kind == "antique":
            frame = antique(k, a, height)
        else:
            frame = shop(k, a, height)
        haunts[k] = frame
        # the second row behind (the town is close-packed up the hill)
        roofs = ("kawara", "kawara2", "kawara3")
        back = Frame(a, FRONT, height)
        row = {"house": (-7.0, 7.0), "shop": (-7.0, 7.0), "danchi": (8.6,), "sento": (-7.0,), "antique": (-8.5,)}.get(kind, ())
        for i, u in enumerate(row):
            back_house("back_%d_%d" % (k, i), back, u, 10.0, roofs[(k + i) % 3])
        haunts[k] = frame
        # crates by the side to get up onto the roof strip or the eaves
        crates = w1.Piece("crates_%d" % k)
        side = -6.5 if kind != "danchi" else -11.3
        frame.box(crates, side, 1.0, 1.0, 1.0, 1.0, "wood")
        frame.box(crates, side, 2.1, 1.0, 1.9, 1.0, "wood")
        crates.done()
        # trash cans by the door
        if kind in ("house", "house_back", "shop", "sento", "danchi"):
            for du in (2.0, 2.8):
                w1.can(frame.p(-du if kind != "shop" else -4.6 - du * 0.4, 0.0, -0.9 if kind != "house_back" else -0.9))
    return haunts


def poles_and_wires(frames):
    """Concrete power poles round the outer pavement with crossarms and transformers, the phone line strung from each
    to the next (the wires he walks), and the power lines above it and across to the houses (only to look at)."""
    poles = w1.Piece("climb_poles")
    things = w1.Piece("pole_things")
    lines = w1.Piece("nocol_lines")
    count = 10
    r = ROAD[1] + 1.2
    tops = []
    arms = []
    for k in range(count):
        a = math.tau * k / count
        x, z = math.cos(a) * r, math.sin(a) * r
        poles.cylinder((x, 0.0, z), 0.18, 8.2, "pole", 8)
        frame = Frame(a, r)
        frame.box(things, 0.0, 0.0, 1.8, 0.14, 0.14, "pole", base=7.6)
        # the yellow sleeve at its foot
        poles.cylinder((x, 0.0, z), 0.21, 1.6, "sleeve", 8, cap=False)
        if k % 2 == 0:
            # a transformer
            c = frame.p(0.0, 5.3, 0.38)
            things.cylinder(c, 0.26, 0.9, "metal", 8)
        tops.append((x, 6.48, z))
        arms.append((frame.p(-0.8, 7.78, 0.0), frame.p(0.8, 7.78, 0.0)))
    for k in range(count):
        w1.wire(tops[k], tops[(k + 1) % count], 4)
        # the two power lines above, sagging (each from one crossarm end to the next pole's)
        for side in (0, 1):
            a_end, b_end = arms[k][side], arms[(k + 1) % count][side]
            prev = a_end
            for s in range(1, 7):
                t = s / 6
                p = w1.wire_point(a_end, b_end, t)
                _bar(lines, prev, p, 0.035, "wire_dark")
                prev = p
    # a line to each house from the pole before it
    for k, frame in frames.items():
        pole = arms[k][1]
        eave = frame.p(-2.0, 4.6, 0.0)
        prev = pole
        for s in range(1, 5):
            p = w1.wire_point(pole, eave, s / 4)
            _bar(lines, prev, p, 0.03, "wire_dark")
            prev = p
    poles.done()
    things.done()
    lines.done()


def grove():
    """The climbable trees of the grove, the shrine, the torii at the top of the path, the lanterns, the thatched
    hut, pampas grass on the slopes, the hollow log, the pond."""
    trees = [(-1.5, -1.0, 160), (6.0, 4.5, 110), (-6.5, 4.0, 115), (-4.0, -7.0, 120), (5.0, -7.5, 105),
             (13.0, 6.0, 95), (-14.0, -3.0, 100), (2.0, 15.5, 95), (-9.0, 13.0, 90), (16.0, -9.0, 100)]
    for k, (x, z, size) in enumerate(trees):
        w1.mark("tree_%d_%d_%d" % (k, 101 + k * 7, size), (x, hill_height(x, z) - 0.05, z))
    # garden trees behind the houses
    for n, (k, u, v, size) in enumerate(((0, 0.0, 12.5, 80), (5, 0.0, 12.5, 85), (8, 0.0, 12.0, 75), (7, 8.0, 12.0, 70))):
        frame = Frame(math.tau * (k + 0.5) / SECTORS, FRONT, LOTS[k][1])
        p = frame.p(u, -0.05, v)
        w1.mark("tree_%d_%d_%d" % (len(trees) + n, 211 + n * 13, size), p)
    # The shrine, at the back of the plateau, facing the clearing (+Z)
    sx, sz = 0.5, -6.2
    sy = min(hill_height(sx + dx, sz + dz) for dx in (-1.8, 1.8) for dz in (-1.8, 1.8))
    shrine = w1.Piece("shrine")
    shrine.box((sx, sy + 0.3 - 0.4, sz), (3.6, 1.4, 3.6), "stone")
    shrine.box((sx, sy + 0.6 + 1.0, sz - 0.2), (2.8, 2.0, 2.6), "darkwood")
    shrine.box((sx, sy + 0.6 + 1.0, sz + 1.12), (2.0, 1.6, 0.06), "wood")
    shrine.gable_roof(sx - 1.9, sx + 1.9, sz - 2.0, sz + 1.9, sy + 2.6, sy + 3.9, "kawara3", over=0.3)
    for i in range(3):
        shrine.box((sx, sy + 0.1 + i * 0.2 - 0.25, sz + 2.15 + (2 - i) * 0.32), (1.8, 0.5 + 0.0, 0.34), "stone")
    # the rope and its paper streamers
    shrine.box((sx, sy + 2.45, sz + 1.3), (2.6, 0.12, 0.12), "straw")
    shrine.done()
    shide = w1.Piece("nocol_shide")
    for i in range(4):
        x = sx - 0.9 + i * 0.6
        shide.face([(x - 0.06, sy + 2.4, sz + 1.38), (x + 0.06, sy + 2.4, sz + 1.38), (x + 0.1, sy + 1.95, sz + 1.38), (x - 0.02, sy + 1.95, sz + 1.38)], "white")
    shide.done()
    w1.mark("haunt_1", (sx, hill_height(sx, sz + 3.2), sz + 3.2))
    # The torii where the path comes up on to the top, facing in
    tx, tz = path_point(1.0)
    turn = math.atan2(tz, tx)
    frame = Frame(turn, math.hypot(tx, tz) - 0.6, hill_height(tx, tz) - 0.1)
    torii = w1.Piece("torii")
    for side in (-1.3, 1.3):
        c = frame.p(side, 0.0, 0.0)
        torii.cylinder(c, 0.17, 3.3, "vermilion", 8)
    frame.box(torii, 0.0, 0.0, 3.4, 0.22, 0.3, "vermilion", base=2.55)
    frame.box(torii, 0.0, 0.0, 4.2, 0.3, 0.42, "black", base=3.3)
    torii.done()
    # A pair of stone lanterns inside it
    lanterns = w1.Piece("lanterns")
    for side in (-1.8, 1.8):
        c = frame.p(side, 0.0, -2.2)
        y = hill_height(c[0], c[2]) - 0.1
        lanterns.box((c[0], y + 0.5, c[2]), (0.5, 1.0, 0.5), "stone")
        lanterns.box((c[0], y + 1.25, c[2]), (0.45, 0.5, 0.45), "stone")
        lanterns.box((c[0], y + 1.6, c[2]), (0.75, 0.2, 0.75), "stone")
    lanterns.done()
    # The thatched hut at the edge of the top
    hx, hz = -5.5, 7.6
    hy = min(hill_height(hx + dx, hz + dz) for dx in (-1.8, 1.8) for dz in (-1.6, 1.6)) - 0.1
    hut_frame = Frame(math.atan2(hz, hx), math.hypot(hx, hz), hy)
    hut = w1.Piece("hut")
    hut_frame.box(hut, 0.0, 0.0, 4.4, 2.2, 3.0, "darkwood")
    hut_frame.box(hut, 0.0, -1.62, 1.0, 1.7, 0.06, "black")
    hut_frame.hip_roof(hut, 0.0, 0.0, 4.4, 3.0, 2.2, 2.2, "thatch", over=0.7)
    hut.done()
    w1.mark("haunt_6", hut_frame.p(1.0, 0.1, -2.4))
    # Pampas grass on the slopes
    pampas = w1.Piece("nocol_pampas")
    rng = random.Random(5)
    placed = 0
    while placed < 34:
        a = rng.uniform(0.0, math.tau)
        r = rng.uniform(PLATEAU + 1.0, HILL_FOOT - 1.5)
        x, z = math.cos(a) * r, math.sin(a) * r
        if path_distance(x, z) < 1.8 or any(math.hypot(x - tx_, z - tz_) < 2.0 for tx_, tz_, _s in trees):
            continue
        placed += 1
        y = hill_height(x, z) - 0.05
        for b in range(7):
            lean = rng.uniform(0.0, math.tau)
            tall = rng.uniform(1.1, 1.7)
            top = (x + math.cos(lean) * 0.35, y + tall, z + math.sin(lean) * 0.35)
            side = (-math.sin(lean) * 0.05, math.cos(lean) * 0.05)
            pampas.face([(x + side[0], y, z + side[1]), (x - side[0], y, z - side[1]), top], "pampas_leaf")
            plume_base = (x + math.cos(lean) * 0.25, y + tall * 0.7, z + math.sin(lean) * 0.25)
            pampas.face([(plume_base[0] + side[0] * 2, plume_base[1], plume_base[2] + side[1] * 2),
                         (plume_base[0] - side[0] * 2, plume_base[1], plume_base[2] - side[1] * 2),
                         (top[0] + math.cos(lean) * 0.12, top[1] + 0.15, top[2] + math.sin(lean) * 0.12)], "pampas")
    pampas.done()
    # The hollow log on the slope: crawl in for the hidden Bottlecap
    lx, lz = -12.0, 9.5
    ly = hill_height(lx, lz)
    log = w1.Piece("log")
    segs = 12
    turn_log = 0.6
    log_frame = Frame(0.0, 0.0)
    c, s = math.cos(turn_log), math.sin(turn_log)

    def rot(p):
        return (lx + p[0] * c - p[2] * s, p[1], lz + p[0] * s + p[2] * c)

    for i in range(segs):
        a0, a1 = math.tau * i / segs, math.tau * (i + 1) / segs
        outer = [(-1.6, ly + 0.62 + math.sin(a0) * 0.62, math.cos(a0) * 0.62), (1.6, ly + 0.62 + math.sin(a0) * 0.62, math.cos(a0) * 0.62),
                 (1.6, ly + 0.62 + math.sin(a1) * 0.62, math.cos(a1) * 0.62), (-1.6, ly + 0.62 + math.sin(a1) * 0.62, math.cos(a1) * 0.62)]
        inner = [(px, ly + 0.62 + (py - ly - 0.62) * 0.78, pz * 0.78) for px, py, pz in outer][::-1]
        log.face([rot(p) for p in outer], "darkwood")
        log.face([rot(p) for p in inner], "wood")
    del log_frame
    log.done()
    w1.mark("cap_hidden", rot((0.0, ly + 0.25, 0.0)))
    # The pond on top
    w1.mark("pool", (POOL[0], HILL_TOP - 0.25, POOL[1]))
    w1.mark("pool_size", (POOL_RADII[0] * 2.0, 1.2, POOL_RADII[1] * 2.0))
    w1.mark("haunt_7", (POOL[0] - 3.2, hill_height(POOL[0] - 3.2, POOL[1] + 0.5), POOL[1] + 0.5))
    # Crumbs up the winding path
    for k in range(18):
        x, z = path_point((k + 0.5) / 18 * 0.94)
        w1.crumb((x, hill_height(x, z) + 0.35, z))


def far_height(r, a):
    """The land beyond the lots: down from the brink to a valley full of town, then up to green hills."""
    if r < 110.0:
        t = (r - 66.0) / 44.0
        h = -20.0 - 12.0 * t * t * (3.0 - 2.0 * t)
    elif r < 190.0:
        h = -32.0 - 2.0 * math.sin((r - 110.0) / 80.0 * math.pi)
    else:
        t = min(1.0, (r - 190.0) / 110.0)
        h = -32.0 + 30.0 * t * t * (3.0 - 2.0 * t)
    bumps = noise.noise(Vector((math.cos(a) * r * 0.012, math.sin(a) * r * 0.012, 3.1)))
    return h + bumps * (3.0 if r < 190.0 else 9.0)


def beyond():
    """What he sees past the rail (none of it solid): terraces down from the lots, the town in the valley, the hills."""
    slope = w1.Piece("nocol_slope")
    segs = 80
    for s in range(segs):
        b0, b1 = math.tau * s / segs, math.tau * (s + 1) / segs
        k = int((b0 + b1) / 2 / math.tau * SECTORS) % SECTORS
        h = LOTS[k][1]
        # from the foot of the lot's wall, a grass bank down to a lower wall, then on down to the valley
        slope.face([_ring_point(b0, LOT[1], h - 7.0), _ring_point(b1, LOT[1], h - 7.0), _ring_point(b1, 63.0, -12.0), _ring_point(b0, 63.0, -12.0)], "far_green")
        slope.face([_ring_point(b0, 63.0, -12.0), _ring_point(b1, 63.0, -12.0), _ring_point(b1, 63.0, -18.0), _ring_point(b0, 63.0, -18.0)], "blockwall", 0.9)
        slope.face([_ring_point(b0, 63.0, -18.0), _ring_point(b1, 63.0, -18.0), _ring_point(b1, 66.0, far_height(66.0, b1)), _ring_point(b0, 66.0, far_height(66.0, b0))], "far_green")
    slope.done()
    land = w1.Piece("nocol_far_land")
    rings = [66.0, 80.0, 98.0, 120.0, 145.0, 170.0, 195.0, 225.0, 260.0, 300.0, 360.0]
    segs = 64
    for i in range(len(rings) - 1):
        for s in range(segs):
            b0, b1 = math.tau * s / segs, math.tau * (s + 1) / segs
            r0, r1 = rings[i], rings[i + 1]
            mat = "far_green" if r1 <= 195.0 else ("far_forest" if r1 <= 260.0 else "far_hill")
            land.face([_ring_point(b0, r0, far_height(r0, b0)), _ring_point(b1, r0, far_height(r0, b1)),
                       _ring_point(b1, r1, far_height(r1, b1)), _ring_point(b0, r1, far_height(r1, b0))], mat)
    land.done()
    # The town below: little houses, streets of them, white blocks of flats in rows
    town = w1.Piece("nocol_far_town")
    rng = random.Random(11)
    for n in range(520):
        a = rng.uniform(0.0, math.tau)
        r = rng.uniform(64.5, 185.0) if n % 4 else rng.uniform(64.5, 90.0)
        x, z = math.cos(a) * r, math.sin(a) * r
        y = far_height(r, a) - 0.3
        frame = Frame(rng.uniform(0.0, math.tau), 0.0, y)
        frame.out = (math.cos(frame.a), math.sin(frame.a))
        frame.along = (-math.sin(frame.a), math.cos(frame.a))
        frame_origin = (x, z)

        def p(u, yy, v, f=frame, o=frame_origin):
            return (o[0] + u * f.along[0] + v * f.out[0], f.y + yy, o[1] + u * f.along[1] + v * f.out[1])

        w, d, tall = rng.uniform(6.0, 9.0), rng.uniform(5.5, 7.5), rng.uniform(4.5, 6.0)
        wall = "far_wall" if rng.random() < 0.6 else "far_wall2"
        roof = rng.choice(("far_roof", "far_roof", "far_roof2", "far_roof3"))
        c = [p(iu * w / 2, iy * tall, iv * d / 2) for iu in (-1, 1) for iy in (0, 1) for iv in (-1, 1)]
        for q in [(0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]:
            town.face([c[i] for i in q], wall, 0.95)
        rise = rng.uniform(1.6, 2.4)
        hw, hd = w / 2 + 0.4, d / 2 + 0.4
        inset = max(hw - hd, 0.2)
        e = [p(-hw, tall, -hd), p(hw, tall, -hd), p(hw, tall, hd), p(-hw, tall, hd)]
        r0, r1 = p(-inset, tall + rise, 0.0), p(inset, tall + rise, 0.0)
        town.face([e[0], e[1], r1, r0], roof, 1.05)
        town.face([e[2], e[3], r0, r1], roof, 0.85)
        town.face([e[1], e[2], r1], roof, 0.95)
        town.face([e[3], e[0], r0], roof, 0.95)
    # cedars and pines among the houses (cones: no round-leaf clumps)
    for n in range(320):
        a = rng.uniform(0.0, math.tau)
        r = rng.uniform(64.0, 230.0)
        x, z = math.cos(a) * r, math.sin(a) * r
        y = far_height(r, a) - 0.2
        tall = rng.uniform(6.0, 12.0)
        wide = tall * rng.uniform(0.22, 0.32)
        mat = "far_tree" if n % 3 else "far_tree2"
        sides = 6
        for i in range(sides):
            t0, t1 = math.tau * i / sides, math.tau * (i + 1) / sides
            town.face([(x + math.cos(t0) * wide, y + tall * 0.15, z + math.sin(t0) * wide), (x + math.cos(t1) * wide, y + tall * 0.15, z + math.sin(t1) * wide),
                       (x, y + tall, z)], mat, 0.85 + 0.25 * math.cos(t0 - 0.8))
    # rows of white blocks of flats
    for g in range(7):
        a = math.tau * (g + 0.3) / 7 + rng.uniform(-0.2, 0.2)
        r = rng.uniform(95.0, 170.0)
        facing = a + math.pi / 2
        for row in range(rng.randint(3, 5)):
            rr = r + row * 22.0
            for col in (-1, 0, 1):
                aa = a + col * 36.0 / rr
                x, z = math.cos(aa) * rr, math.sin(aa) * rr
                y = far_height(rr, aa) - 0.5
                along = (math.cos(facing), math.sin(facing))
                out = (-along[1], along[0])
                w, d, tall = 30.0, 9.0, rng.choice((13.5, 13.5, 16.2))
                c = [(x + iu * w / 2 * along[0] + iv * d / 2 * out[0], y + iy * tall, z + iu * w / 2 * along[1] + iv * d / 2 * out[1])
                     for iu in (-1, 1) for iy in (0, 1) for iv in (-1, 1)]
                for q in [(0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3), (4, 6, 7, 5)]:
                    town.face([c[i] for i in q], "far_wall", 1.08 if q == (4, 6, 7, 5) else 0.95)
    town.done()


def markers(frames):
    # He starts in the grove, a step from its heart (the user, 2026-11-02: "you should spawn in the center of the
    # grove and there shouldnt be enemies there")
    heart = (-0.5, hill_height(-0.5, 4.0), 4.0)
    w1.mark("grove_heart", heart)
    w1.mark("spawn", (1.8, hill_height(1.8, 2.0) + 0.1, 2.0), math.pi)
    w1.mark("check_top", (1.8, hill_height(1.8, 2.0) + 0.1, 2.0))
    w1.mark("check_south", (0.0, 0.17, ROAD[1] + 1.2))
    w1.mark("check_east", (ROAD[1] + 1.2, 0.17, 0.0))
    w1.mark("check_west", (-ROAD[1] - 1.2, 0.17, 0.0))
    # Cars round the ring road; people on the pavements (none up in the grove)
    for i in range(24):
        a = math.tau * i / 24
        w1.mark("road_0_%d" % i, (math.cos(a) * ROAD_MIDDLE, 0.0, math.sin(a) * ROAD_MIDDLE))
    for i in range(13):
        a = math.tau * i / 24
        w1.mark("walk_0_%d" % i, (math.cos(a) * (ROAD[1] + 1.2), 0.0, math.sin(a) * (ROAD[1] + 1.2)))
        a2 = math.pi + math.tau * i / 24
        w1.mark("walk_1_%d" % i, (math.cos(a2) * (ROAD[0] - 1.2), 0.0, math.sin(a2) * (ROAD[0] - 1.2)))
    # The hawk over the houses to the north-west, crows by the shops, the fox's den in a back garden: all out of
    # the grove
    a = math.tau * 6.5 / SECTORS
    w1.mark("hawk_0", (math.cos(a) * 44.0, 0.0, math.sin(a) * 44.0))
    for n, k in enumerate((4, 9)):
        a = math.tau * (k + 0.5) / SECTORS
        w1.mark("crows_%d" % n, (math.cos(a) * (ROAD[1] + 1.8), 0.0, math.sin(a) * (ROAD[1] + 1.8)))
    w1.mark("den_0", frames[8].p(-1.8, 0.05, 15.5))
    # Yard cats about the town, on the outer pavement
    for k, a in enumerate((0.95, 2.6, 4.4, 5.6)):
        r = ROAD[1] + 1.9
        w1.mark("cat_%d" % k, (math.cos(a) * r, 0.17, math.sin(a) * r))
    w1.mark("cap_cats", (0.0, HILL_TOP + 0.6, 0.0))
    # The billboard in the front garden of the house set back from the road: glide to it from the great tree
    frame = Frame(math.tau * 7.5 / SECTORS, 0.0)
    gb = 39.5
    w1.mark("cap_glide", (0.0, 9.5, -gb - 0.0))
    board = w1.Piece("billboard")
    base_y = LOTS[7][1]
    board.box((0.0, 9.3, -gb), (4.0, 0.16, 1.6), "metal")
    for x in (-1.8, 1.8):
        board.box((x, base_y + (9.2 - base_y) / 2, -gb - 0.6), (0.14, 9.2 - base_y, 0.14), "metal")
    board.box((0.0, 9.4 + 1.7, -gb - 0.8), (4.6, 3.4, 0.2), "yellow")
    board.done()
    del frame
    # The race: round the road and up the hill
    w1.mark("race_start", (-2.0, 0.17, ROAD[1] + 1.2))
    for k in range(8):
        a = math.pi * 0.5 + math.tau * (k + 1) / 9
        w1.mark("race_%d" % k, (math.cos(a) * ROAD_MIDDLE, 0.4, math.sin(a) * ROAD_MIDDLE))
    w1.mark("cap_race", (0.0, 0.6, ROAD[0] - 1.0))
    w1.mark("trampoline", (8.0, hill_height(8.0, 12.0) + 0.6, 12.0))
    # Crumbs round the inner pavement
    for k in range(20):
        a = math.tau * k / 20
        w1.crumb((math.cos(a) * (ROAD[0] - 1.2), 0.35, math.sin(a) * (ROAD[0] - 1.2)))
    # Spots round town the wandering raccoons visit (haunt_1, 6, 7 are in the grove: grove())
    w1.mark("haunt_0", frames[4].p(-6.0, 0.0, -1.0))                    # the shop's bins
    w1.mark("haunt_2", frames[3].p(0.0, 0.0, -2.2))                     # the antique shop's plaza
    w1.mark("haunt_3", frames[0].p(-3.0, 0.0, -1.2))                    # the top of the steps to the first house
    w1.mark("haunt_4", frames[5].p(2.0, 0.0, 11.5))                     # a back garden
    w1.mark("haunt_5", frames[9].p(6.6, 0.0, -0.8))                     # the vending machines
    w1.mark("haunt_8", frames[2].p(-2.0, 0.0, 12.5))                    # behind the bath house
    w1.mark("haunt_9", frames[1].p(-13.0, 0.0, 5.0))                    # beside the flats


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    ground()
    lots()
    frames = buildings()
    poles_and_wires(frames)
    grove()
    markers(frames)
    beyond()
    tramp = w1.Piece("nocol_trampoline")
    tx, tz = 8.0, 12.0
    ty = hill_height(tx, tz)
    tramp.cylinder((tx, ty + 0.56, tz), 1.35, 0.08, "metal", 16, top="red")
    tramp.done()
    print("CRUMBS %d WIRES %d CANS %d" % (w1._count["crumb"], w1._count["wire"], w1._count["can"]))
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
    for view, at, target in (("above", (0.01, 170.0, 0.0), (0.0, 0.0, 0.0)), ("south", (-30.0, 30.0, 80.0), (0.0, 4.0, 0.0)),
                             ("north", (20.0, 25.0, -75.0), (0.0, 2.0, 0.0)), ("street", (0.0, 2.0, 35.0), (-20.0, 3.0, 40.0)),
                             ("plaza", (8.0, 2.5, 24.0), (frame_x(3), 3.0, frame_z(3))), ("grove", (2.0, 9.0, 12.0), (0.0, 8.0, -6.0))):
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
