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
    "zinc": (0.66, 0.68, 0.70),
    "sky_ridge1": (0.44, 0.60, 0.58),
    "sky_ridge2": (0.56, 0.68, 0.74),
    "sky_ridge3": (0.66, 0.76, 0.86),
    "sky_rock": (0.58, 0.66, 0.80),
    "sky_snow": (0.94, 0.96, 1.0),
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
PLATEAU = 13.0          # its radius: the open clearing on top (the user, 2026-11-02: "the spawning area is too small and cramped")
HILL_FOOT = 24.0        # where the hill meets the flat
ROAD = (26.0, 33.0)     # the ring road, inner and outer edge
ROAD_MIDDLE = 29.5
PAVE = 2.4              # the pavements either side of it
LOT = (36.5, 56.0)      # the terraced lots, from the retaining wall by the road to the brink at the back
FRONT = 38.5            # where the buildings' fronts stand
BOUND = 55.6            # the unseen wall that keeps him in (the rail stands just inside it)
POOL = (9.5, 2.5)       # a pond at the clearing's east edge
POOL_RADII = (2.4, 1.8)
SECTORS = 10

# Each lot round the road (sector k spans angles k..k+1 tenths of a turn): what stands on it, and how high it is
# held above the road. (Claude's picks.)
LOTS = [
    ("sento", 0.12, None),
    ("danchi", 2.4, None),
    ("road", 0.0, None),          # the street leaves the ring here, down the hill
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
    lumps = 0.35 * noise.noise(Vector((x * 0.13, z * 0.13, 0.5))) * min(1.0, r / PLATEAU) ** 2
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
    edge = 60.0
    span = int(edge * 2 / step)
    heights = {}

    def h(i, j):
        if (i, j) not in heights:
            x, z = -edge + i * step, -edge + j * step
            heights[(i, j)] = hill_height(x, z) if math.hypot(x, z) < HILL_FOOT + 0.5 else ground_y(x, z)
        return heights[(i, j)]

    for i in range(span):
        for j in range(span):
            xa, za = -edge + i * step, -edge + j * step
            xb, zb = xa + step, za + step
            xm, zm = xa + step / 2, za + step / 2
            r = math.hypot(xm, zm)
            # (the hilltop's own squares: those whose 2 m square (hill_grid's) has its middle within 58 m; under
            # the lots only by the road, where the street leaves, and behind them)
            parent = (math.floor(xm / 2.0) * 2.0 + 1.0, math.floor(zm / 2.0) * 2.0 + 1.0)
            if math.hypot(*parent) >= 58.0 or not (r <= LOT[0] + 1.0 or in_gap(xm, zm) or r >= LOT[1] - 1.5):
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
            if r0 == ROAD[1] and abs((a0 + a1) / 2 - math.pi / 2) < 0.17:
                continue  # (the pavement opens where the street goes down the hill)
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


def house(k, a, height, roof, set_back=0.0):
    return house_at("house_%d" % k, Frame(a, FRONT + set_back, height), roof, 40 + k)


def house_at(name, frame, roof, seed, crumbs=True, w=11.0, d=9.0, garden=True, front_pipes=False):
    """A two-storey house as in Whisper of the Heart's streets (the user, 2026-11-02: "realistic big houses"): about
    11 m by 9, plaster walls, a tiled hip roof with deep eaves, a strip of roof over the ground-floor windows (a ledge),
    framed windows, a canopy over the door, a balcony with a laundry pole, an air conditioner, and a block wall round
    the front garden with its gate."""
    piece = w1.Piece(name)
    line = w1.Piece("nocol_laundry_" + name)
    rng = random.Random(seed)
    eave = 6.0
    v = d / 2
    frame.box(piece, 0.0, v, w, eave, d, "plaster")
    ridge = frame.hip_roof(piece, 0.0, v, w, d, eave, 2.4, roof, over=0.7)
    edge = gutters(piece, frame, 0.0, v, w, d, eave, 2.4, 0.7)
    downpipes(name, frame, [(-w / 2, 0.4 if front_pipes else d - 0.8, -1.0, 0.0, edge, 0.7), (w / 2, 0.4, 1.0, 0.0, edge, 0.7)])
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
    if garden:
        garden_wall(frame, piece, -1.85, w / 2 + 1.2, 1.0)
    piece.done()
    line.done()
    # crumbs along the ridge
    inset = max(w / 2 + 0.7 - (d / 2 + 0.7), 0.2)
    if crumbs:
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
    edge = gutters(piece, frame, u, v, w, d, eave, 2.1, 0.6)
    downpipes(name, frame, [(u + w / 2, v0 + d - 0.8, 1.0, 0.0, edge, 0.6)])
    for wu in (-2.2, 2.2):
        window(frame, piece, u + wu, v0, 1.5, 1.1, 0.9)
        window(frame, piece, u + wu, v0, 1.4, 1.0, 3.6)
    frame.box(piece, u, v0 - 0.45, w + 0.3, 0.12, 0.9, roof, base=2.75)
    frame.box(piece, u, v0 - 0.05, 1.0, 2.1, 0.12, "door")
    frame.box(piece, u + w / 2 - 0.6, v0 - 0.3, 0.8, 0.6, 0.35, "white")
    piece.done()


def danchi(k, a, height):
    return danchi_at("danchi_%d" % k, Frame(a, FRONT + 1.0, height), 70 + k)


def danchi_at(name, frame, seed):
    """A white apartment block (the user, 2026-11-02: "apartment buildings"), five storeys of four flats each: along
    the road side a balcony to every flat with its dividers, solid white parapets and laundry rails; behind, two
    stairwells with open landings rising to little rooftop houses; a flat roof with a parapet and a water tank on
    legs."""
    piece = w1.Piece(name)
    line = w1.Piece("nocol_laundry_" + name)
    rng = random.Random(seed)
    w, d, floors, storey = 21.0, 9.0, 5, 2.8
    tall = floors * storey
    v = d / 2
    flat = w / 4
    downpipes(name, frame, [(-w / 2, d - 0.8, -1.0, 0.0, tall + 0.7, 0.0), (w / 2, d - 0.8, 1.0, 0.0, tall + 0.7, 0.0)])
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
    tank = w1.Piece(name + "_tank")
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
    edge = gutters(piece, frame, 0.0, v, w, d, eave, 3.0, 0.7)
    downpipes("sento_%d" % k, frame, [(-w / 2, 5.0, -1.0, 0.0, edge, 0.7), (w / 2, 0.6, 1.0, 0.0, edge, 0.7)])
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
    return shop_at("shop_%d" % k, Frame(a, FRONT, height))


def shop_at(name, frame):
    """A corner shop: two storeys, a flat roof, an awning, a big shop window, vending machines by the door."""
    piece = w1.Piece(name)
    w, d, eave = 11.0, 9.0, 5.5
    v = d / 2
    frame.box(piece, 0.0, v, w, eave, d, "plaster2")
    frame.box(piece, 0.0, v, w + 0.3, 0.5, d + 0.3, "concrete", base=eave)
    frame.box(piece, 0.0, v, w - 0.6, 0.12, d - 0.6, "concrete", base=eave + 0.42)
    downpipes(name, frame, [(-w / 2, d - 0.8, -1.0, 0.0, eave + 0.5, 0.15), (w / 2, d - 0.8, 1.0, 0.0, eave + 0.5, 0.15)])
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
    vend = w1.Piece(name + "_vending")
    for i, (vu, mat) in enumerate(((w / 2 + 1.0, "vend_red"), (w / 2 + 2.05, "vend_blue"))):
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
        if kind == "road":
            continue
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
                w1.can(frame.p(-du if kind != "shop" else -3.0 - du * 0.5, 0.0, -0.9 if kind != "house_back" else -0.9))
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
    """The grove: an open clearing on the hilltop (its middle kept clear: the raccoons gather there, he starts beside
    them), the great tree, the shrine, the torii, the thatched hut and the pond round its edge; climbable trees on the
    slopes below; the hollow log; reeds."""
    # (a ring of trees round the clearing (the user, 2026-11-02: "the grove should be surrounded by a ring of trees"),
    # the great camphor on the north-west side, gaps for the pond, the path and torii and the view down the hill, the
    # hut and the shrine; then a few on the slopes below)
    ring = [(0, 105), (165, 110), (195, 100), (227, 160), (255, 105), (290, 100), (320, 110), (345, 95)]
    trees = [(math.cos(math.radians(deg)) * 12.3, math.sin(math.radians(deg)) * 12.3, size) for deg, size in ring]
    trees += [(17.5, 6.5, 95), (-17.0, -3.0, 100), (-3.0, 18.5, 95), (-12.0, 16.0, 90), (18.0, -9.5, 100)]
    for x, z, _size in trees:
        if path_distance(x, z) < 2.5:
            print("TREE ON THE PATH at", x, z)
    # (climbing trees, tree_<n>_<seed>_<size%>: the great camphor and two more round the ring, for the glide and
    # the routes; the rest plain, treep_<n>_<seed>_<size%>_<kind>: World)
    climbing = {(round(math.cos(math.radians(deg)) * 12.3, 3), round(math.sin(math.radians(deg)) * 12.3, 3)) for deg in (165, 227, 320)}
    for k, (x, z, size) in enumerate(trees):
        at = (x, hill_height(x, z) - 0.05, z)
        if (round(x, 3), round(z, 3)) in climbing:
            w1.mark("tree_%d_%d_%d" % (k, 101 + k * 7, size), at)
        else:
            w1.mark("treep_%d_%d_%d_%s" % (k, 101 + k * 7, size, "cedar" if k % 3 == 2 else "oak"), at)
    # garden trees behind the houses
    for n, (k, u, v, size) in enumerate(((0, -2.0, 13.0, 80), (5, 0.0, 12.5, 85), (8, 0.0, 12.0, 75), (7, 8.0, 12.0, 70))):
        frame = Frame(math.tau * (k + 0.5) / SECTORS, FRONT, LOTS[k][1])
        p = frame.p(u, -0.05, v)
        w1.mark("treep_%d_%d_%d_%s" % (len(trees) + n, 211 + n * 13, size, "oak" if n % 2 == 0 else "cedar"), p)
    # The shrine, at the back of the plateau, facing the clearing (+Z)
    sx, sz = 0.5, -11.0
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
    # The thatched hut at the edge of the top
    hx, hz = -9.0, 8.5
    hy = min(hill_height(hx + dx, hz + dz) for dx in (-1.8, 1.8) for dz in (-1.6, 1.6)) - 0.1
    hut_frame = Frame(math.atan2(hz, hx), math.hypot(hx, hz), hy)
    hut = w1.Piece("hut")
    hut_frame.box(hut, 0.0, 0.0, 4.4, 2.2, 3.0, "darkwood")
    hut_frame.box(hut, 0.0, -1.62, 1.0, 1.7, 0.06, "black")
    hut_frame.hip_roof(hut, 0.0, 0.0, 4.4, 3.0, 2.2, 2.2, "thatch", over=0.7)
    hut.done()
    w1.mark("haunt_6", hut_frame.p(1.0, 0.1, -2.4))
    # Reeds on the grove's slopes and round the pond (markers only: World grows Warren's reeds there; the user,
    # 2026-11-02: "please dont make new reeds check the ones we already have")
    rng = random.Random(5)
    placed = 0
    while placed < 6:
        a = rng.uniform(0.0, math.tau)
        r = rng.uniform(PLATEAU + 2.0, HILL_FOOT - 3.0)
        x, z = math.cos(a) * r, math.sin(a) * r
        if path_distance(x, z) < 3.5 or any(math.hypot(x - tx_, z - tz_) < 4.0 for tx_, tz_, _s in trees):
            continue
        empty = w1.mark("reeds_%d" % placed, (x, hill_height(x, z) - 0.05, z))
        size = rng.uniform(2.0, 3.5)
        empty.scale = (size, size, size)
        placed += 1
    empty = w1.mark("reeds_pond", (POOL[0] + 2.8, hill_height(POOL[0] + 2.8, POOL[1] + 1.8), POOL[1] + 1.8))
    empty.scale = (1.8, 1.8, 1.8)
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
    land = w1.Piece("nocol_far_land")
    rings = [172.0, 195.0, 225.0, 260.0, 300.0, 360.0]
    segs = 64
    for i in range(len(rings) - 1):
        for s in range(segs):
            b0, b1 = math.tau * s / segs, math.tau * (s + 1) / segs
            r0, r1 = rings[i], rings[i + 1]
            mat = "far_green" if r1 <= 195.0 else ("far_forest" if r1 <= 260.0 else "far_hill")
            # (a little under the hill's own squares where they overlap)
            sink0, sink1 = (-0.4 if r0 < 180.0 else 0.0), (-0.4 if r1 < 180.0 else 0.0)
            land.face([_ring_point(b0, r0, far_height(r0, b0) + sink0), _ring_point(b1, r0, far_height(r0, b1) + sink0),
                       _ring_point(b1, r1, far_height(r1, b1) + sink1), _ring_point(b0, r1, far_height(r1, b0) + sink1)], mat)
    land.done()
    # The town below: little houses, streets of them, white blocks of flats in rows
    town = w1.Piece("nocol_far_town")
    rng = random.Random(11)
    for n in range(520):
        a = rng.uniform(0.0, math.tau)
        r = rng.uniform(60.0, 185.0) if n % 4 else rng.uniform(60.0, 90.0)
        x, z = math.cos(a) * r, math.sin(a) * r
        if abs(x) < CORRIDOR + 8.0 and z > 10.0:
            continue
        y = _cone(x, z) - 0.3
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
        r = rng.uniform(60.0, 230.0)
        x, z = math.cos(a) * r, math.sin(a) * r
        if abs(x) < CORRIDOR + 8.0 and z > 10.0:
            continue
        y = _cone(x, z) - 0.2
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
                if abs(x) < CORRIDOR + 25.0 and z > 0.0:
                    continue
                y = _cone(x, z) - 0.5
                along = (math.cos(facing), math.sin(facing))
                out = (-along[1], along[0])
                w, d, tall = 30.0, 9.0, rng.choice((13.5, 13.5, 16.2))
                c = [(x + iu * w / 2 * along[0] + iv * d / 2 * out[0], y + iy * tall, z + iu * w / 2 * along[1] + iv * d / 2 * out[1])
                     for iu in (-1, 1) for iy in (0, 1) for iv in (-1, 1)]
                for q in [(0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3), (4, 6, 7, 5)]:
                    town.face([c[i] for i in q], "far_wall", 1.08 if q == (4, 6, 7, 5) else 0.95)
    town.done()
    # Rolling hills in the distance, ridge behind ridge, paler and bluer the further off, and a great snow-capped
    # volcano on the horizon to the south, framed from the grove and down the street (the user, 2026-11-02: "there
    # should be rolling hills in the distance for the skybox, and a volcano like Rainier or Fuji"). Their colours
    # are already hazed (sky_ materials: World draws them unshaded and out of the fog).
    for layer, (r, base, amp, mat, seed) in enumerate(((430.0, 4.0, 22.0, "sky_ridge1", 1.3), (620.0, 18.0, 34.0, "sky_ridge2", 4.7),
                                                         (860.0, 30.0, 44.0, "sky_ridge3", 9.1))):
        ridge = w1.Piece("nocol_ridges_%d" % layer)
        segs = 160
        tops = []
        for k in range(segs + 1):
            a = math.tau * k / segs
            roll = noise.noise(Vector((math.cos(a) * 2.2, math.sin(a) * 2.2, seed))) * 0.7 + noise.noise(Vector((math.cos(a) * 5.0, math.sin(a) * 5.0, seed + 3.0))) * 0.3
            tops.append(base + amp * (0.5 + roll))
        for k in range(segs):
            a0, a1 = math.tau * k / segs, math.tau * (k + 1) / segs
            ridge.face([_ring_point(a0, r + 60.0, -80.0), _ring_point(a1, r + 60.0, -80.0), _ring_point(a1, r, tops[k + 1]), _ring_point(a0, r, tops[k])], mat)
            ridge.face([_ring_point(a0, r, tops[k]), _ring_point(a1, r, tops[k + 1]), _ring_point(a1, r - 70.0, -80.0), _ring_point(a0, r - 70.0, -80.0)], mat, 1.12)
        ridge.done()
    # The volcano: a broad gentle foot steepening to a flat top, snow on its upper half running down the ravines in
    # streaks
    vx, vz, foot_y, height, foot_r, top_r = -330.0, 1050.0, -90.0, 420.0, 760.0, 34.0
    volcano = w1.Piece("nocol_volcano")
    segs, rows = 64, 16
    rng = random.Random(3)
    streak = [rng.uniform(0.38, 0.6) for _ in range(segs)]
    ring_pts = []
    # (cut off at `top_cut` of its height, flat: above that the cone ran up nearly straight, a chimney; the user,
    # 2026-11-02, "the volcano goes too high lol cut it about there")
    top_cut = 0.78
    for j in range(rows + 1):
        s = top_cut * j / rows
        radius = top_r + (foot_r - top_r) * (1.0 - s) ** 2.4
        ring_pts.append([(vx + math.cos(math.tau * k / segs) * radius, foot_y + height * s, vz + math.sin(math.tau * k / segs) * radius) for k in range(segs)])
    for j in range(rows):
        s = top_cut * (j + 0.5) / rows
        for k in range(segs):
            snow = s > 0.6 or s > streak[k] and k % 3 != 1
            q = [ring_pts[j][k], ring_pts[j][(k + 1) % segs], ring_pts[j + 1][(k + 1) % segs], ring_pts[j + 1][k]]
            light = 0.86 + 0.22 * math.cos(math.tau * (k + 0.5) / segs - 2.4)
            volcano.face(q, "sky_snow" if snow else "sky_rock", light)
    volcano.face([p for p in ring_pts[-1]][::-1], "sky_snow", 1.1)
    volcano.done()


# --- The hill. The whole level is one hill (the user, 2026-11-02: "the road shouldnt just be a ring it should be a
# winding road down a hill. The level should be this whole hill"; "it's the hill grove at the top and ringed area"):
# the grove and the ring of lots on its top, and down its south face a street switchbacking to the station square at
# its foot (after Whisper of the Heart's hillside streets: block retaining walls, houses on plinths, long stairways
# cutting between the bends, poles and wires). The station at the foot is Claude's pick.

HILL_EDGE = 57.0      # the hilltop (the ring and its lots) is level out to here
HILL_SLOPE = 0.36     # how steeply the hill falls away round its other sides (beyond the play area)
FOOT_Y = -34.0        # the foot of the hill: the station square
LEGS = [64.0, 90.0, 116.0, 142.0]   # the winding road's straight runs across the hill (z), top to bottom
LEG_X = 24.0          # how far each run goes either way before it bends back
BEND = 13.0           # the hairpins' radius (half the runs' spacing)
CORRIDOR = 48.0       # the play area down the hill: |x| within this
BOTTOM = 193.0        # its far end (z), past the station
ROAD_HALF, PAVE_OUT = 3.5, 5.0
BENCH = 7.6           # the road's level shelf, half across: the hill is cut or built up to it, block walls at its edges
PLAZA = (0.0, 163.0)  # the turning circle in the station square
# The long stairways straight down the hill between the bends: (x, from the run above)
STAIRS = [(14.0, 0), (-12.0, 1), (12.0, 2)]

_path = []            # the road's centre: (x, z, y), a point about every metre
_legs = []            # each run's points (x, y), by x


def _smooth(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3.0 - 2.0 * t)


def _make_path():
    pts = []

    def line(a, b):
        n = max(1, int(math.dist(a, b)))
        for i in range(n):
            t = i / n
            pts.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))

    def arc(c, r, t0, t1):
        n = max(2, int(abs(t1 - t0) * r))
        for i in range(n):
            t = t0 + (t1 - t0) * i / n
            pts.append((c[0] + math.cos(t) * r, c[1] + math.sin(t) * r))

    line((0.0, 32.5), (0.0, 58.0))
    arc((6.0, 58.0), 6.0, math.pi, math.pi / 2)
    line((6.0, LEGS[0]), (LEG_X, LEGS[0]))
    arc((LEG_X, (LEGS[0] + LEGS[1]) / 2), BEND, -math.pi / 2, math.pi / 2)
    line((LEG_X, LEGS[1]), (-LEG_X, LEGS[1]))
    arc((-LEG_X, (LEGS[1] + LEGS[2]) / 2), BEND, -math.pi / 2, -3 * math.pi / 2)
    line((-LEG_X, LEGS[2]), (LEG_X, LEGS[2]))
    arc((LEG_X, (LEGS[2] + LEGS[3]) / 2), BEND, -math.pi / 2, math.pi / 2)
    line((LEG_X, LEGS[3]), (6.0, LEGS[3]))
    arc((6.0, LEGS[3] + 6.0), 6.0, -math.pi / 2, -math.pi)
    line((0.0, LEGS[3] + 6.0), (0.0, 158.0))
    pts.append((0.0, 158.0))
    # Heights: level to the hill's edge, then down at an even grade to the square
    start = next(i for i, p in enumerate(pts) if p[1] >= 57.5)
    run = [0.0]
    for i in range(1, len(pts)):
        run.append(run[-1] + math.dist(pts[i - 1], pts[i]))
    total = run[-1] - run[start]
    _path.clear()
    for i, (x, z) in enumerate(pts):
        y = 0.0 if i <= start else FOOT_Y * (run[i] - run[start]) / total
        _path.append((x, z, y))
    _legs.clear()
    for zl in LEGS:
        on = sorted((x, y) for x, z, y in _path if abs(z - zl) < 0.01)
        _legs.append(on)


def leg_y(i, x):
    """The road's height on run i at x (held at the run's ends beyond them)."""
    on = _legs[i]
    if x <= on[0][0]:
        return on[0][1]
    if x >= on[-1][0]:
        return on[-1][1]
    for (x0, y0), (x1, y1) in zip(on, on[1:]):
        if x <= x1:
            return y0 + (y1 - y0) * (x - x0) / max(x1 - x0, 1e-6)
    return on[-1][1]


def _cone(x, z):
    """The hill's sides away from the street: falling evenly, then out into the valley's own lie."""
    r = math.hypot(x, z)
    if r <= HILL_EDGE:
        return 0.0
    if r <= 150.0:
        return -HILL_SLOPE * (r - HILL_EDGE)
    edge = -HILL_SLOPE * (150.0 - HILL_EDGE)
    return edge + (far_height(r, math.atan2(z, x)) - edge) * _smooth(150.0, 178.0, r)


def hill_ground(x, z):
    """The hill's own ground (before the road's shelf and the stairs are cut): level on top; down the south face from
    each run of the road to the next; the plain sides elsewhere."""
    r = math.hypot(x, z)
    if r <= HILL_EDGE:
        return 0.0
    outside = _cone(x, z)
    if z < 15.0 or abs(x) > CORRIDOR + 16.0:
        return outside
    top = math.sqrt(max(HILL_EDGE * HILL_EDGE - x * x, 0.0))
    zs = [top] + LEGS + [LEGS[-1] + 12.0]
    ys = [0.0] + [leg_y(i, x) for i in range(len(LEGS))] + [FOOT_Y]
    inner = FOOT_Y
    for k in range(len(zs) - 1):
        if z < zs[k + 1]:
            t = (z - zs[k]) / max(zs[k + 1] - zs[k], 1e-6)
            inner = ys[k] + (ys[k + 1] - ys[k]) * max(0.0, t)
            break
    return inner + (outside - inner) * _smooth(CORRIDOR - 4.0, CORRIDOR + 14.0, abs(x))


def road_near(x, z):
    """How far (x, z) is from the road's centre, and the road's height there."""
    best, height = 1e9, 0.0
    for (x0, z0, y0), (x1, z1, y1) in zip(_path, _path[1:]):
        dx, dz = x1 - x0, z1 - z0
        length = dx * dx + dz * dz
        t = 0.0 if length < 1e-9 else min(1.0, max(0.0, ((x - x0) * dx + (z - z0) * dz) / length))
        d = math.hypot(x - x0 - dx * t, z - z0 - dz * t)
        if d < best:
            best, height = d, y0 + (y1 - y0) * t
    return best, height


def _stair(k):
    x, i = STAIRS[k]
    return x, LEGS[i] + BENCH, leg_y(i, x) - 0.05, LEGS[i + 1] - BENCH, leg_y(i + 1, x) - 0.05


def ground_y(x, z):
    """The ground as built: the hill, with the road's shelf and the stairways cut into it, the square level."""
    if abs(x) < 26.0 and z > 152.0:
        return FOOT_Y
    h = hill_ground(x, z)
    if abs(x) < CORRIDOR + 2.0 and 25.0 < z < 165.0:
        d, ry = road_near(x, z)
        if d < BENCH:
            return ry - 0.05
        for k in range(len(STAIRS)):
            sx, z0, y0, z1, y1 = _stair(k)
            if abs(x - sx) <= 2.2 and z0 - 0.5 <= z <= z1 + 0.5:
                t = min(1.0, max(0.0, (z - z0) / (z1 - z0)))
                return y0 + (y1 - y0) * t - 0.35
    return h


def in_gap(x, z):
    """Whether (x, z) is in the lot where the road leaves the ring (no lot there)."""
    a = math.atan2(z, x) % math.tau
    k = LOTS.index(next(lot for lot in LOTS if lot[0] == "road"))
    return math.tau * k / SECTORS <= a <= math.tau * (k + 1) / SECTORS


def hill_grid():
    """The hill's ground in 2 m squares out to the valley: solid down the street's face, only to look at elsewhere.
    The hilltop's own ground (ground()) has every 2 m square whose middle is within 58 m of the top."""
    solid = w1.Piece("hill")
    view = w1.Piece("nocol_hill")
    step = 2.0
    reach = 176.0
    n = int(reach * 2 / step)
    heights = {}

    def h(i, j):
        if (i, j) not in heights:
            heights[(i, j)] = ground_y(-reach + i * step, -reach + j * step)
        return heights[(i, j)]

    for i in range(n):
        for j in range(n):
            xa, za = -reach + i * step, -reach + j * step
            xm, zm = xa + step / 2, za + step / 2
            r = math.hypot(xm, zm)
            if r > reach or r < 58.0:
                continue
            pts = [(xa, h(i, j), za), (xa, h(i, j + 1), za + step), (xa + step, h(i + 1, j + 1), za + step), (xa + step, h(i + 1, j), za)]
            near = abs(xm) < CORRIDOR + 4.0 and zm > 20.0 and zm < BOTTOM + 2.0
            if near:
                d, _ry = road_near(xm, zm) if abs(xm) < CORRIDOR + 2.0 and zm < 165.0 else (99.0, 0.0)
                mat = "dirt" if d < ROAD_HALF + 1.0 else "grass"
                solid.face(pts, mat)
            else:
                view.face(pts, "far_green" if r < 120.0 else "far_forest")
    solid.done()
    view.done()


def _side(i, sign):
    """The point beside path point i, `sign` metres to its right (of the way down), and its heading."""
    x0, z0, _y = _path[max(i - 1, 0)]
    x1, z1, _y = _path[min(i + 1, len(_path) - 1)]
    dx, dz = x1 - x0, z1 - z0
    length = math.hypot(dx, dz) or 1.0
    rx, rz = -dz / length, dx / length
    x, z, y = _path[i]
    return x + rx * sign, z + rz * sign, y


def street(plinths):
    """The road down the hill and its pavements, its retaining walls where the shelf is cut or built up (not where a
    house's plinth already stands), the stairways."""
    road = w1.Piece("road_hill")
    for i in range(len(_path) - 1):
        if _path[i][1] < 32.5:
            continue
        for s0, s1, lift, mat in ((-ROAD_HALF, ROAD_HALF, 0.03, "asphalt"), (-PAVE_OUT, -ROAD_HALF, 0.12, "concrete"), (ROAD_HALF, PAVE_OUT, 0.12, "concrete")):
            a0, a1 = _side(i, s0), _side(i, s1)
            b0, b1 = _side(i + 1, s0), _side(i + 1, s1)
            road.face([(a0[0], a0[2] + lift, a0[1]), (a1[0], a1[2] + lift, a1[1]), (b1[0], b1[2] + lift, b1[1]), (b0[0], b0[2] + lift, b0[1])], mat)
            if lift > 0.05:
                for s in (s0, s1):
                    p, q = _side(i, s), _side(i + 1, s)
                    road.face([(p[0], p[2] - 0.05, p[1]), (q[0], q[2] - 0.05, q[1]), (q[0], q[2] + lift, q[1]), (p[0], p[2] + lift, p[1])], "concrete", 0.85)
    road.done()
    drains = w1.Piece("nocol_street_drains")
    for i in range(30, len(_path) - 1, 18):
        for sign in (-1.0, 1.0):
            x, z, y = _side(i, sign * (ROAD_HALF - 0.3))
            drains.box((x, y + 0.035, z), (0.5, 0.02, 0.5), "black")
    drains.done()
    walls = w1.Piece("street_walls")
    for sign in (-1.0, 1.0):
        prev = None
        for i in range(0, len(_path), 2):
            x, z, y = _path[i]
            px, pz, _py = _side(i, sign * (BENCH + 0.3))
            nx, nz, _ny = _side(i, sign * (BENCH + 2.4))
            if z < 58.0 or z > 152.0 or abs(px) > CORRIDOR + 1.0:
                prev = None
                continue
            # (where a house's plinth stands at the shelf's edge, it is the wall)
            if any(x0 <= px <= x1 and abs(pz - zf) < 2.6 for x0, x1, zf in plinths):
                prev = None
                continue
            # (and not across a stairway: it goes on down through)
            if any(abs(px - sx) < 1.3 for sx, _i in STAIRS) and any(abs(pz - z0) < 1.5 or abs(pz - z1) < 1.5 for z0, z1 in [(_stair(k)[1], _stair(k)[3]) for k in range(len(STAIRS))]):
                prev = None
                continue
            lie = hill_ground(nx, nz)
            if abs(lie - y) < 0.4:
                prev = None
                continue
            here = (px, pz, min(lie, y) - 0.3, max(lie, y))
            if prev:
                walls.face([(prev[0], prev[2], prev[1]), (here[0], here[2], here[1]), (here[0], here[3], here[1]), (prev[0], prev[3], prev[1])], "blockwall", 0.92)
            prev = here
    walls.done()
    for k in range(len(STAIRS)):
        _stairway(k)


def _stairway(k):
    """A long stairway straight down the hill from one run of the road to the next, handrails both sides, crumbs."""
    sx, z0, y0, z1, y1 = _stair(k)
    count = max(2, math.ceil((y0 - y1) / 0.2))
    rise = (y0 - y1) / count
    run = (z1 - z0) / count
    steps = w1.Piece("stairway_%d" % k)
    rail = w1.Piece("nocol_stair_rail_%d" % k)
    for s in range(count):
        tread = y0 - (s + 1) * rise
        steps.box((sx, tread - 0.75, z0 + (s + 0.5) * run), (2.0, 1.5, run + 0.02), "concrete")
        if s % 7 == 3:
            w1.crumb((sx, tread + 0.35, z0 + (s + 0.5) * run))
    for side in (-1.05, 1.05):
        _bar(rail, (sx + side, y0 + 0.9, z0), (sx + side, y1 + 0.9, z1), 0.06, "metal")
        for t in (0.0, 0.25, 0.5, 0.75, 1.0):
            py = y0 + (y1 - y0) * t
            pz = z0 + (z1 - z0) * t
            _bar(rail, (sx + side, py - 0.2, pz), (sx + side, py + 0.9, pz), 0.06, "metal")
    steps.done()
    rail.done()


def _plinth(name, frame, u0, u1, v0, v1, low):
    """A block-walled plinth under a building on the hill, from below the ground up to its floor."""
    piece = w1.Piece(name)
    frame.box(piece, (u0 + u1) / 2, (v0 + v1) / 2, u1 - u0, -(low - 0.6), v1 - v0, "blockwall", base=low - 0.6, top="concrete")
    piece.done()


def hill_house(name, x, z_front, out_a, roof, seed, plinths):
    """A house on the hillside facing the road below it: on a block plinth level with the ground at its front, the
    hill rising behind it into its back; steps along the plinth's face up from the road."""
    w, d = 10.0, 7.5
    probe = Frame.at(x, z_front, out_a)
    half = w / 2 + 1.2
    pad = max(hill_ground(probe.p(u, 0.0, 0.0)[0], probe.p(u, 0.0, 0.0)[2]) for u in (-half, 0.0, half)) + 0.05
    low = min(hill_ground(probe.p(u, 0.0, v)[0], probe.p(u, 0.0, v)[2]) for u in (-half, half) for v in (-2.0, 0.0))
    _d, road_y = road_near(*_xz(probe.p(0.0, 0.0, -3.0)))
    low = min(low, road_y)
    frame = Frame.at(x, z_front, out_a, pad)
    _plinth(name + "_plinth", frame, -half, half, -2.0, 1.0, low - pad)
    house_at(name, frame, roof, seed, crumbs=False, w=w, d=d, garden=False, front_pipes=True)
    # the steps up its face from the road's shelf
    rise_all = pad - road_y
    if rise_all > 0.3:
        count = math.ceil(rise_all / 0.2)
        rise = rise_all / count
        run = min(0.3, (2 * half - 0.5) / count)
        steps = w1.Piece(name + "_steps")
        for s in range(count):
            frame.box(steps, -half + (s + 0.5) * run, -2.5, run + 0.02, (s + 1) * rise + 0.4, 1.0, "concrete", base=road_y - pad - 0.4)
        steps.done()
    corner_a, corner_b = probe.p(-half, 0.0, -2.0), probe.p(half, 0.0, -2.0)
    plinths.append((min(corner_a[0], corner_b[0]), max(corner_a[0], corner_b[0]), corner_a[2]))
    return frame


def hill_danchi(name, x, z_front, out_a, seed):
    """A block of flats on a plinth near the foot of the hill."""
    probe = Frame.at(x, z_front, out_a)
    half = 11.0
    pad = max(hill_ground(probe.p(u, 0.0, v)[0], probe.p(u, 0.0, v)[2]) for u in (-half, 0.0, half) for v in (0.0, 9.0)) + 0.05
    low = min(hill_ground(probe.p(u, 0.0, v)[0], probe.p(u, 0.0, v)[2]) for u in (-half, half) for v in (-2.0, 9.0))
    frame = Frame.at(x, z_front, out_a, pad)
    _plinth(name + "_plinth", frame, -half - 0.5, half + 0.5, -2.0, 11.5, low - pad)
    danchi_at(name, frame, seed)
    return frame


def station():
    """At the foot: the station square (a turning circle round a little lawn), the station, its platform and a
    train waiting, shops either side (Claude's picks)."""
    y = FOOT_Y
    square = w1.Piece("square")
    segs = 32
    cx, cz = PLAZA
    for s in range(segs):
        t0, t1 = math.tau * s / segs, math.tau * (s + 1) / segs
        for r0, r1, lift, mat in ((0.0, 3.0, 0.15, "grass"), (3.0, 7.5, 0.03, "asphalt"), (7.5, 11.5, 0.12, "concrete")):
            q = [(cx + math.cos(t0) * r0, y + lift, cz + math.sin(t0) * r0), (cx + math.cos(t0) * r1, y + lift, cz + math.sin(t0) * r1),
                 (cx + math.cos(t1) * r1, y + lift, cz + math.sin(t1) * r1), (cx + math.cos(t1) * r0, y + lift, cz + math.sin(t1) * r0)]
            square.face(q, mat)
        for r, lift in ((3.0, 0.15), (7.5, 0.12)):
            square.face([(cx + math.cos(t0) * r, y, cz + math.sin(t0) * r), (cx + math.cos(t1) * r, y, cz + math.sin(t1) * r),
                         (cx + math.cos(t1) * r, y + lift, cz + math.sin(t1) * r), (cx + math.cos(t0) * r, y + lift, cz + math.sin(t0) * r)], "concrete", 0.85)
    square.done()
    # the station, its front to the square
    frame = Frame.at(0.0, 175.0, math.pi / 2, y + 0.12)
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
    shop_at("foot_shop_0", Frame.at(-14.5, 168.0, math.pi, y + 0.12))
    shop_at("foot_shop_1", Frame.at(14.5, 160.0, 0.0, y + 0.12))
    return frame


def hill_wires():
    """Poles down the downhill side of each run of the road, a phone line from each to the next (wires he walks),
    power lines above (only to look at)."""
    poles = w1.Piece("climb_hill_poles")
    things = w1.Piece("hill_pole_things")
    lines = w1.Piece("nocol_hill_lines")
    spots = {0: (8.0, 20.0), 1: (-20.0, -6.0, 6.0, 18.0), 2: (-18.0, -4.0, 4.0, 18.0), 3: (8.0, 20.0)}
    for i, xs in spots.items():
        tops, arms = [], []
        for x in xs:
            y = leg_y(i, x) + 0.12
            z = LEGS[i] + 4.3
            poles.cylinder((x, y, z), 0.18, 8.2, "pole", 8)
            poles.cylinder((x, y, z), 0.21, 1.6, "sleeve", 8, cap=False)
            things.box((x, y + 7.67, z), (0.14, 0.14, 1.8), "pole")
            tops.append((x, y + 6.48, z))
            arms.append(((x, y + 7.78, z - 0.8), (x, y + 7.78, z + 0.8)))
        for k in range(len(tops) - 1):
            w1.wire(tops[k], tops[k + 1], 3)
            for side in (0, 1):
                a_end, b_end = arms[k][side], arms[k + 1][side]
                prev = a_end
                for s in range(1, 7):
                    p = w1.wire_point(a_end, b_end, s / 6)
                    _bar(lines, prev, p, 0.035, "wire_dark")
                    prev = p
    poles.done()
    things.done()
    lines.done()


def hill_bound():
    """The unseen wall that keeps him in: round the hilltop's brink, but open down the street's face, round which it
    runs instead."""
    bound = w1.Piece("hidden_bound")
    meet = math.sqrt(BOUND * BOUND - CORRIDOR * CORRIDOR)
    a_start = math.atan2(meet, CORRIDOR)
    a_end = math.pi - a_start - math.tau
    pts = []
    segs = 64
    for s in range(segs + 1):
        a = a_start + (a_end - a_start) * s / segs
        pts.append((math.cos(a) * BOUND, math.sin(a) * BOUND))
    pts += [(-CORRIDOR, BOTTOM), (CORRIDOR, BOTTOM), (CORRIDOR, meet)]
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        bound.face([(x0, -60.0, z0), (x1, -60.0, z1), (x1, 45.0, z1), (x0, 45.0, z0)], "concrete")
    bound.done()


def hill():
    """Everything down the hill, and its markers."""
    plinths = []
    yards = []
    houses = [(1, -18.0, "kawara"), (1, -4.0, "kawara2"), (1, -32.0, "kawara3"), (2, 4.0, "kawara3"), (2, 18.0, "kawara"),
              (2, 31.0, "kawara2"), (3, -4.0, "kawara2"), (3, -18.0, "kawara"), (3, -32.0, "kawara3")]
    for n, (i, x, roof) in enumerate(houses):
        yards.append(hill_house("hill_house_%d" % n, x, LEGS[i] - 10.0, -math.pi / 2, roof, 100 + n, plinths))
    for n, x in enumerate((-26.0, 27.0)):
        hill_danchi("hill_danchi_%d" % n, x, LEGS[3] + 9.5, math.pi / 2, 120 + n)
    hill_grid()
    street(plinths)
    station()
    hill_wires()
    hill_bound()
    # Crumbs along the uphill pavement, a few metres apart
    for i in range(0, len(_path), 6):
        if _path[i][1] < 60.0:
            continue
        x, z, y = _side(i, -4.3)
        w1.crumb((x, y + 0.47, z))
    # Cars down the road and back up it, round the square at the foot; people on its pavement
    down = [(x, y, z) for x, z, y in _path[::4] if z >= 32.5]
    cx, cz = PLAZA
    round_square = [(cx + math.cos(-math.pi / 2 + math.tau * s / 16) * 5.2, FOOT_Y + 0.03, cz + math.sin(-math.pi / 2 + math.tau * s / 16) * 5.2) for s in range(1, 16)]
    loop = down + round_square + down[::-1][1:-1]
    for i, p in enumerate(loop):
        w1.mark("road_1_%d" % i, p)
    walk = [_side(i, 4.3) for i in range(0, len(_path), 8) if _path[i][1] >= 58.0]
    for i, (x, z, y) in enumerate(walk):
        w1.mark("walk_2_%d" % i, (x, y + 0.12, z))
    # Checkpoints on each run and at the foot
    for i, x in enumerate((15.0, 0.0, 0.0, 15.0)):
        w1.mark("check_hill_%d" % i, (x, leg_y(i, x) + 0.3, LEGS[i] - 4.3))
    w1.mark("check_station", (0.0, FOOT_Y + 0.3, 172.0))
    # Places the wandering raccoons visit down the hill
    sx, z0, y0, _z1, _y1 = _stair(1)
    w1.mark("haunt_3", (sx, y0 + 0.1, z0 - 0.6))
    w1.mark("haunt_9", (8.0, FOOT_Y + 0.15, 171.0))
    w1.mark("haunt_10", (-LEG_X - BEND - 5.5, leg_y(1, -LEG_X) - 6.0, (LEGS[1] + LEGS[2]) / 2))
    sx, _z0, _y0, z1, y1 = _stair(2)
    w1.mark("haunt_11", (sx, y1 + 0.1, z1 + 0.6))
    # The crows about the square, the hawk over the hillside
    w1.mark("crows_2", (-6.0, FOOT_Y + 0.12, 171.0))
    w1.mark("hawk_1", (0.0, -18.0, 105.0))
    # Tall grass to hide in (the user, 2026-11-02: "tall grass to hide in in spots"; World grows it): beside the
    # street where it leaves the ring, inside the hairpins, on the slopes between the runs, by the flats at the foot
    for n, (x, z, size) in enumerate(((9.0, 46.0, 3.0), (-9.0, 48.0, 3.0), (-10.0, 77.0, 4.0), (-30.0, 77.0, 3.5), (LEG_X, (LEGS[0] + LEGS[1]) / 2, 3.5),
                                      (-LEG_X, (LEGS[1] + LEGS[2]) / 2, 3.5), (LEG_X, (LEGS[2] + LEGS[3]) / 2, 3.5), (-42.0, 140.0, 3.0))):
        empty = w1.mark("tallgrass_%d" % n, (x, ground_y(x, z), z))
        empty.scale = (size, size, size)
    # Dogs' yards on the hill: the terraces in front of two hillside houses (the ring's are in markers())
    for n, frame in enumerate(yards[:2]):
        w1.mark("dog_%d" % (n + 3), frame.p(3.0, 0.05, -1.0))
    # Reeds on the banks by the bends (Warren's reeds grow there: World)
    for n, (x, z, size) in enumerate(((LEG_X + BEND + 5.0, (LEGS[0] + LEGS[1]) / 2, 3.0), (-LEG_X - BEND - 5.0, (LEGS[1] + LEGS[2]) / 2 + 3.0, 3.0),
                                      (LEG_X + BEND + 5.0, (LEGS[2] + LEGS[3]) / 2, 3.5), (-30.0, LEGS[0] + 4.0, 3.0), (-36.0, 150.0, 4.0))):
        empty = w1.mark("reeds_h%d" % n, (x, ground_y(x, z), z))
        empty.scale = (size, size, size)


def _xz(p):
    return (p[0], p[2])


def markers(frames):
    # He starts in the grove, a step from its heart (the user, 2026-11-02: "you should spawn in the center of the
    # grove and there shouldnt be enemies there")
    heart = (0.0, hill_height(0.0, 0.0), 0.0)
    w1.mark("grove_heart", heart)
    # (facing south, down the hill: the spawn's turn is his facing_yaw)
    w1.mark("spawn", (0.0, hill_height(0.0, 3.0) + 0.1, 3.0), 0.0)
    w1.mark("check_top", (0.0, hill_height(0.0, 3.0) + 0.1, 3.0))
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
    # Dogs' yards on the ring: inside the garden walls, behind the gates
    for n, k in enumerate((5, 8, 7)):
        w1.mark("dog_%d" % n, frames[k].p(-3.0, 0.05, -1.0))
    w1.mark("tallgrass_ring", frames[5].p(-10.0, 0.0, 3.0)).scale = (2.0, 2.0, 2.0)
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
    w1.mark("haunt_4", frames[5].p(2.0, 0.0, 11.5))                     # a back garden
    w1.mark("haunt_5", frames[9].p(6.6, 0.0, -0.8))                     # the vending machines
    w1.mark("haunt_8", frames[0].p(-2.0, 0.0, 12.5))                    # behind the bath house
    w1.mark("haunt_12", frames[1].p(-13.0, 0.0, 5.0))                   # beside the flats


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _make_path()
    ground()
    lots()
    frames = buildings()
    poles_and_wires(frames)
    grove()
    hill()
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
