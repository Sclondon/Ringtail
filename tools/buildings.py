"""Buildings as little platforming levels (the user, 2026-11-02: "the houses need more complex shapes that lend themselves
to platforming over just boxes ... a house generator that can function as a mini level generator essentially", then
"same for the apartment complexes and factories etc"). Seeded and parametric, Pacific Northwest (the user: "it takes
place in the PNW not japan"). A library for the Blender town builders (tools/build_town.py), on build_world1.py's
Piece and markers; run tools/build_building_preview.py to see them.

    import buildings
    made = buildings.make("craftsman", "house_3", x, y, z, turn=a, seed=7)
    made["route"]      # [(how, (x, y, z))]: a measured way from the ground to the top (how: start, walk, stairs,
                       # slope, jump, ledge, climb, ladder), checked against the raccoon's moves (check_route)
    made["top"]        # the high spot at the end of it: a reward goes there (a kit, a cap, a pile of Crumbs)
    made["crumbs"]     # where Crumbs were put along the route (crumb_ markers, if marks=True)
    made["bounds"]     # (x0, z0, x1, z1) in its own frame: its footprint with its yard things
    made["problems"]   # route links his moves cannot make (empty when it is good)
    made["objects"]    # the Blender objects

Its own frame: x along its front, y up, z out of its front (the street side); (x, y, z) in Godot's axes is where its
frame's origin goes (the middle of its front wall line at ground level, roughly), `turn` radians about Y (its front then
faces (sin turn, 0, cos turn)). It stands on flat ground at y: the town builder levels a pad for it.

Kinds (KINDS): houses craftsman, box (two storeys), farmhouse, aframe; walkup (apartments), commercial (brick block),
construction (a house being built, scaffolding, a crane), factory, warehouse, substation, culvert (a sewer outfall).

What the objects are called (scripts/world.gd): <name> solid and seen; nocol_<name> seen only (details, rails' spindles);
climb_<name> solid, seen and climbable (scurry up it: stacks, silos, trellises, a crane's mast); climb_<name>_hidden an
unseen climbable column (round a drainpipe or a pylon's leg: fatter than what is seen, so Scurry's probe finds it);
<name>_hidden unseen and solid (a chain-link fence's wall). Markers: crumb_<n> (w1.crumb), ladder_<name>_<cm> (World
stands a Ladder there, rungs facing the marker's +Z).

His moves (scripts/player.gd, raccoon.tscn): a jump is 1.15 m high (so up to RISE_JUMP onto something), a ledge he
catches up to 1.6 m over his feet (RISE_LEDGE, then up), running he clears about GAP across; his collider stands
1.25 m tall (0.62 m scurrying), so nothing he stands on is put under less than HEADROOM; slopes up to 46 degrees are
floor (roofs here are 35 or less unless meant to be scurried up). He is about 0.6 m tall.
"""

import math
import os
import random
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_world1 as w1  # noqa: E402

RISE_JUMP = 1.0
RISE_LEDGE = 1.45
GAP = 2.2
HEADROOM = 1.3

for _key, _colour in {
    "glass": (0.30, 0.42, 0.50), "white": (0.95, 0.94, 0.90), "zinc": (0.66, 0.68, 0.70), "black": (0.14, 0.13, 0.13),
    "rail": (0.66, 0.80, 0.76), "awning": (0.92, 0.88, 0.72),
    # (Pacific Northwest: weathered cedar, moss on the shingles, painted lap siding, red brick, galvanised steel)
    "cedar": (0.56, 0.38, 0.26), "moss": (0.40, 0.48, 0.30), "osb": (0.80, 0.66, 0.42), "lumber": (0.86, 0.74, 0.52),
    "tyvek": (0.93, 0.93, 0.95), "steel": (0.50, 0.53, 0.56), "steel_red": (0.62, 0.22, 0.17),
    "safety": (0.95, 0.72, 0.12), "corrugated": (0.62, 0.66, 0.66), "corrugated2": (0.42, 0.52, 0.56),
    "tar": (0.22, 0.22, 0.24), "cone": (0.98, 0.45, 0.10), "insulator": (0.55, 0.35, 0.25),
    "sign": (0.95, 0.92, 0.80), "sign2": (0.22, 0.38, 0.62), "awning_red": (0.66, 0.20, 0.18),
    "awning_green": (0.20, 0.42, 0.30), "chainlink": (0.55, 0.58, 0.60), "gravel": (0.55, 0.53, 0.50),
    "sewage": (0.26, 0.34, 0.30), "pallet": (0.70, 0.56, 0.36), "crate": (0.62, 0.48, 0.30),
    "siding4": (0.84, 0.82, 0.74), "siding5": (0.36, 0.44, 0.40),
}.items():
    w1.COLOURS.setdefault(_key, _colour)

# Paint they pick from (textured ones where the game has a texture: World.TEXTURES)
SIDINGS = ["siding", "siding2", "siding3", "siding4", "siding5", "cedar"]
ROOFS = ["roof", "roof2", "moss"]


class Site:
    """Where a building's frame goes: its origin (x, y, z) and its turn about Y."""

    def __init__(self, x, y, z, turn=0.0):
        self.x, self.y, self.z, self.turn = x, y, z, turn
        self.c, self.s = math.cos(turn), math.sin(turn)

    def p(self, x, y, z):
        return (self.x + x * self.c + z * self.s, self.y + y, self.z - x * self.s + z * self.c)


class Kit:
    """One building being made: its pieces (by what they are: solid, seen only, climbable, unseen climbable, unseen
    solid), its route, its markers. Every helper takes points in the building's own frame."""

    ROLES = {"solid": "%s", "see": "nocol_%s", "climb": "climb_%s", "feel": "climb_%s_hidden", "block": "%s_hidden"}

    def __init__(self, name, site, seed):
        self.name, self.site = name, site
        self.rng = random.Random(seed)
        self.pieces = {}
        self.route = []
        self.ladders = []
        self.bounds = [1e9, 1e9, -1e9, -1e9]

    # --- drawing ---

    def piece(self, role):
        if role not in self.pieces:
            self.pieces[role] = w1.Piece(self.ROLES[role] % self.name)
        return self.pieces[role]

    def face(self, points, mat, shade=1.0, role="solid"):
        for x, _y, z in points:
            b = self.bounds
            b[0], b[1], b[2], b[3] = min(b[0], x), min(b[1], z), max(b[2], x), max(b[3], z)
        self.piece(role).face([self.site.p(*p) for p in points], mat, shade)

    def box(self, x0, y0, z0, x1, y1, z1, mat, role="solid", top=None, shade=1.0):
        """An upright box from corner to corner (its own frame)."""
        x0, x1 = min(x0, x1), max(x0, x1)
        y0, y1 = min(y0, y1), max(y0, y1)
        z0, z1 = min(z0, z1), max(z0, z1)
        c = [(x, y, z) for x in (x0, x1) for y in (y0, y1) for z in (z0, z1)]
        quads = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        for k, q in enumerate(quads):
            self.face([c[i] for i in q], top if (top and k == 3) else mat, shade * (1.08 if k == 3 else 0.86 if k in (0, 1) else 0.95), role)

    def bar(self, a, b, thick, mat, role="solid", up=(0.0, 1.0, 0.0)):
        """A square beam from a to b."""
        d = [b[i] - a[i] for i in range(3)]
        length = math.sqrt(sum(v * v for v in d)) or 1e-6
        d = [v / length for v in d]
        side = _cross(d, up)
        if _len(side) < 1e-4:
            side = _cross(d, (1.0, 0.0, 0.0))
        side = _norm(side)
        top = _cross(side, d)
        h = thick / 2
        corners = [[a[i] + (side[i] * sx + top[i] * sy) * h for i in range(3)] for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        ends = [[corners[k][i] + d[i] * length for i in range(3)] for k in range(4)]
        for k in range(4):
            self.face([corners[k], corners[(k + 1) % 4], ends[(k + 1) % 4], ends[k]], mat, 0.9 + 0.05 * k, role)
        self.face(corners[::-1], mat, 0.9, role)
        self.face(ends, mat, 0.9, role)

    def cylinder(self, x, y, z, radius, height, mat, sides=8, role="solid", top=None, cap=True):
        ring = [(math.cos(math.tau * i / sides) * radius, math.sin(math.tau * i / sides) * radius) for i in range(sides)]
        for i in range(sides):
            (a, b), (c, d) = ring[i], ring[(i + 1) % sides]
            self.face([(x + a, y, z + b), (x + a, y + height, z + b), (x + c, y + height, z + d), (x + c, y, z + d)], mat, 0.9 + 0.1 * a / radius, role)
        if cap:
            self.face([(x + a, y + height, z + b) for a, b in ring][::-1], top or mat, 1.08, role)
            self.face([(x + a, y, z + b) for a, b in ring], mat, 0.8, role)

    def cone(self, x, y, z, radius, height, mat, sides=8, role="solid"):
        ring = [(x + math.cos(math.tau * i / sides) * radius, y, z + math.sin(math.tau * i / sides) * radius) for i in range(sides)]
        for i in range(sides):
            self.face([ring[i], (x, y + height, z), ring[(i + 1) % sides]], mat, 1.0, role)

    def column(self, centres, radius, role="feel", mat="metal", sides=8):
        """A round column through `centres` (its rings level): what he climbs, round a pipe or a pylon's leg."""
        rings = [[(cx + math.cos(math.tau * i / sides) * radius, cy, cz + math.sin(math.tau * i / sides) * radius) for i in range(sides)]
                 for cx, cy, cz in centres]
        for r0, r1 in zip(rings, rings[1:]):
            for i in range(sides):
                self.face([r0[i], r0[(i + 1) % sides], r1[(i + 1) % sides], r1[i]], mat, 1.0, role)
        self.face(rings[0], mat, 1.0, role)
        self.face(rings[-1][::-1], mat, 1.0, role)

    def slab(self, corners, heights, thick, mat, role="solid", under=None):
        """A sloping slab: four corners (x, z) round it, the top's height at each, `thick` deep (roofs, awnings,
        ramps, porch roofs)."""
        top = [(x, h, z) for (x, z), h in zip(corners, heights)]
        bottom = [(x, h - thick, z) for (x, z), h in zip(corners, heights)]
        self.face(top, mat, 1.05, role)
        self.face(bottom[::-1], under or mat, 0.65, role)
        for k in range(4):
            j = (k + 1) % 4
            self.face([top[k], bottom[k], bottom[j], top[j]], under or mat, 0.8, role)

    def gable(self, a0, a1, b0, b1, eave, rise, mat, along="x", over=0.5, thick=0.18, ends=None, role="solid"):
        """A gable roof over a0..a1 (along its ridge) by b0..b1, the walls' top at `eave`, the ridge `rise` over it,
        overhanging `over` all round; the gable ends' wall triangles in `ends`. Returns (ridge height, eave edge
        height)."""
        def p(a, y, b):
            return (a, y, b) if along == "x" else (b, y, a)
        bm, half = (b0 + b1) / 2, (b1 - b0) / 2
        slope = rise / half
        edge = eave - slope * over
        ridge = eave + rise
        A0, A1 = a0 - over, a1 + over
        for sign in (-1, 1):
            be = bm + sign * (half + over)
            self.slab([(_xz(p(A0, 0, be))), (_xz(p(A1, 0, be))), (_xz(p(A1, 0, bm))), (_xz(p(A0, 0, bm)))], [edge, edge, ridge, ridge], thick, mat, role,
                      under="darkwood")
        if ends:
            for a in (a0, a1):
                self.face([p(a, eave, b0), p(a, eave, b1), p(a, ridge - 0.02, bm)], ends, 0.92, role)
        return ridge, edge

    def shed(self, x0, x1, z0, z1, low, high, rises_to, mat, over=0.3, thick=0.16, role="solid"):
        """A shed (lean-to) roof over x0..x1 by z0..z1 rising from `low` to `high` towards side `rises_to`
        ("x0", "x1", "z0" or "z1"), overhanging `over`. Returns its height at a point (x, z) as a function."""
        X0, X1, Z0, Z1 = x0 - over, x1 + over, z0 - over, z1 + over
        axis = rises_to[0]
        lo_at, hi_at = {"x0": (x1, x0), "x1": (x0, x1), "z0": (z1, z0), "z1": (z0, z1)}[rises_to]

        def height(x, z):
            t = ((x if axis == "x" else z) - lo_at) / (hi_at - lo_at)
            return low + (high - low) * t

        corners = [(X0, Z0), (X1, Z0), (X1, Z1), (X0, Z1)]
        self.slab(corners, [height(x, z) for x, z in corners], thick, mat, role, under="darkwood")
        return height

    def window(self, wall, u, y, w, h, sill=0.0, frame="white", role="see"):
        """A window on a wall: wall = ("z", z, out) for a front or back wall (out +1 or -1), ("x", x, out) for a side.
        A sill `sill` deep (solid: a ledge to stand on if deep enough)."""
        axis, at, out = wall

        def p(uu, yy, oo):
            return (uu, yy, at + out * oo) if axis == "z" else (at + out * oo, yy, uu)

        a0, a1 = p(u - w / 2 - 0.08, y - 0.08, 0.0), p(u + w / 2 + 0.08, y + h + 0.08, 0.05)
        self.box(a0[0], a0[1], a0[2], a1[0], a1[1], a1[2], frame, role)
        g0, g1 = p(u - w / 2, y, 0.05), p(u + w / 2, y + h, 0.07)
        self.box(g0[0], g0[1], g0[2], g1[0], g1[1], g1[2], "glass", role)
        m0, m1 = p(u - 0.03, y, 0.07), p(u + 0.03, y + h, 0.09)
        self.box(m0[0], m0[1], m0[2], m1[0], m1[1], m1[2], frame, role)
        if sill:
            s0, s1 = p(u - w / 2 - 0.15, y - 0.16, 0.0), p(u + w / 2 + 0.15, y - 0.06, sill)
            self.box(s0[0], s0[1], s0[2], s1[0], s1[1], s1[2], frame, "solid")

    def steps(self, x, z, dx, dz, width, rise, mat="concrete", step=0.18, run=0.3, y0=0.0):
        """Steps going up `rise` from (x, y0, z) the way (dx, dz) (a unit along x or z). Returns where they end."""
        n = max(1, int(math.ceil(rise / step)))
        each = rise / n
        side = (dz, dx)
        for k in range(n):
            a = (x + dx * run * k, z + dz * run * k)
            b = (a[0] + dx * run * (n - k) + side[0] * width / 2, a[1] + dz * run * (n - k) + side[1] * width / 2)
            a = (a[0] - side[0] * width / 2, a[1] - side[1] * width / 2)
            self.box(a[0], y0 + each * k, a[1], b[0], y0 + each * (k + 1), b[1], mat)
        return (x + dx * run * n, y0 + rise, z + dz * run * n)

    def stair_flight(self, x, z, dx, dz, width, y0, rise, mat="concrete", run=0.3, step=0.18):
        """A flight of open stairs (treads with a stringer under them, nothing solid beneath): up `rise` from
        (x, y0, z) the way (dx, dz). Returns where it ends."""
        n = max(1, int(math.ceil(rise / step)))
        each = rise / n
        side = (dz, dx)
        for k in range(n):
            cx, cz = x + dx * run * (k + 0.5), z + dz * run * (k + 0.5)
            hx = abs(dx) * run / 2 + abs(side[0]) * width / 2
            hz = abs(dz) * run / 2 + abs(side[1]) * width / 2
            self.box(cx - hx, y0 + each * k, cz - hz, cx + hx, y0 + each * (k + 1), cz + hz, mat)
        for s in (-1, 1):
            a = (x + side[0] * s * width / 2, y0, z + side[1] * s * width / 2)
            b = (a[0] + dx * run * n, y0 + rise, a[2] + dz * run * n)
            self.bar((a[0], a[1] - 0.1, a[2]), (b[0], b[1] - 0.1, b[2]), 0.1, "steel", "see")
        return (x + dx * run * n, y0 + rise, z + dz * run * n)

    def railing(self, a, b, height, mat="white", spindles=True, cap=0.12):
        """A railing from a to b (points on the floor): a cap rail (solid, `cap` wide), and spindles (seen only)."""
        self.bar((a[0], a[1] + height, a[2]), (b[0], b[1] + height, b[2]), cap, mat)
        self.bar((a[0], a[1] + 0.12, a[2]), (b[0], b[1] + 0.12, b[2]), 0.06, mat, "see")
        length = math.dist(a, b)
        n = max(1, int(length / 0.14)) if spindles else max(1, int(length / 1.2))
        for k in range(n + 1):
            t = k / n
            p = [a[i] + (b[i] - a[i]) * t for i in range(3)]
            self.box(p[0] - 0.025, p[1], p[2] - 0.025, p[0] + 0.025, p[1] + height, p[2] + 0.025, mat, "see")
        # (unseen, a wall up to the rail so he does not slip between the spindles)
        self.face([a, b, (b[0], b[1] + height, b[2]), (a[0], a[1] + height, a[2])], "white", 1.0, "block")

    def downpipe(self, x, z, nx, nz, edge, over, y0=0.0):
        """A drainpipe on a wall at (x, z) (the wall's outward normal (nx, nz)) from the ground to a gutter at `edge`
        (`over` out from the wall), and the unseen column he climbs round it, leaning out past the eaves at the top
        so he comes out over them (build_town.py's downpipes, as in tests/pipe_climb.gd)."""
        cx, cz = x + nx * 0.075, z + nz * 0.075
        top = edge - 0.35 - over * 0.6 if over > 0.0 else edge - 0.1
        self.cylinder(cx, y0 + 0.25, cz, 0.045, top - y0 - 0.25, "zinc", 8, "see")
        if over > 0.0:
            ox, oz = x + nx * (over + 0.075), z + nz * (over + 0.075)
            self.bar((cx, top, cz), (ox, edge - 0.16, oz), 0.08, "zinc", "see")
            self.bar((ox, edge - 0.2, oz), (ox, edge - 0.02, oz), 0.08, "zinc", "see")
        y = y0 + 0.7
        while y < top - 0.2:
            self.box(cx - 0.06, y, cz - 0.06, cx + 0.06, y + 0.04, cz + 0.06, "zinc", "see")
            y += 1.0
        self.bar((cx, y0 + 0.3, cz), (cx + nx * 0.16, y0 + 0.1, cz + nz * 0.16), 0.085, "zinc", "see")

        def at(o, y):
            return (x + nx * o, y, z + nz * o)
        if over > 0.2:
            self.column([at(0.17, y0), at(0.17, edge - 2.4), at(over + 0.7, edge - 0.9), at(over + 0.7, edge + 0.05)], 0.16)
        else:
            self.column([at(0.2, y0), at(0.2, edge + 0.05)], 0.16)

    def gutter(self, a, b, out, radius=0.075):
        """A half-round gutter along an eave edge from a to b (points at the edge), its middle `out` (x, z) beyond."""
        ring = [(math.cos(math.pi * i / 6) * radius, -math.sin(math.pi * i / 6) * radius) for i in range(7)]
        for (o0, y0), (o1, y1) in zip(ring, ring[1:]):
            q = [(a[0] + out[0] * (radius + o0), a[1] + y0, a[2] + out[1] * (radius + o0)),
                 (b[0] + out[0] * (radius + o0), b[1] + y0, b[2] + out[1] * (radius + o0)),
                 (b[0] + out[0] * (radius + o1), b[1] + y1, b[2] + out[1] * (radius + o1)),
                 (a[0] + out[0] * (radius + o1), a[1] + y1, a[2] + out[1] * (radius + o1))]
            self.face(q, "zinc", 0.95, "see")

    def ladder(self, x, y, z, height, facing):
        """A ladder (World's Ladder) standing at (x, y, z), `height` high, its rungs facing `facing` radians from +z."""
        self.ladders.append(((x, y, z), height, facing))

    def crate_stack(self, x, z, heights, size=1.0, mat="crate"):
        """Crates stacked into steps along x: `heights` how many high each column is."""
        for k, n in enumerate(heights):
            for j in range(n):
                cx = x + k * size
                self.box(cx - size / 2 + 0.02, j * size, z - size / 2, cx + size / 2 - 0.02, (j + 1) * size - 0.02, z + size / 2, mat)

    # --- the route ---

    def node(self, how, x, y, z):
        """The next standing spot on the way up, and how he gets there from the last."""
        self.route.append((how, (x, y, z)))

    def done(self, marks=True, crumbs=6):
        objects = [piece.done() for piece in self.pieces.values()]
        for (x, y, z), height, facing in self.ladders:
            w1.mark("ladder_%s_%d_%d" % (self.name, len(objects), int(round(height * 100))), self.site.p(x, y, z), self.site.turn + facing)
            objects.append(None)
        objects = [o for o in objects if o is not None]
        route = [(how, self.site.p(*at)) for how, at in self.route]
        top = route[-1][1] if route else self.site.p(0.0, 0.0, 0.0)
        placed = []
        if marks and crumbs > 0 and len(route) > 2:
            # (Crumbs along the way up, the higher spots first: one at every few stops, a hop over where he stands)
            stops = route[1:-1]
            pick = max(1, len(stops) // crumbs)
            for how, at in stops[::pick][:crumbs]:
                p = (at[0], at[1] + 0.4, at[2])
                w1.crumb(p)
                placed.append(p)
        return {"objects": objects, "route": route, "top": top, "crumbs": placed,
                "bounds": tuple(self.bounds), "problems": check_route(self.route), "name": self.name}


def _xz(p):
    return (p[0], p[2])


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _len(a):
    return math.sqrt(sum(v * v for v in a))


def _norm(a):
    n = _len(a) or 1e-6
    return tuple(v / n for v in a)


def check_route(route):
    """The links on a route his moves cannot make: [(index, why)]."""
    problems = []
    for k in range(1, len(route)):
        how, b = route[k]
        a = route[k - 1][1]
        rise = b[1] - a[1]
        across = math.dist((a[0], a[2]), (b[0], b[2]))
        if how == "jump" and (rise > RISE_JUMP or across > GAP):
            problems.append((k, "jump %.2f up %.2f across" % (rise, across)))
        elif how == "ledge" and (rise > RISE_LEDGE or across > GAP):
            problems.append((k, "ledge %.2f up %.2f across" % (rise, across)))
        elif how in ("walk", "stairs") and rise > 0.35 and across < rise * 1.2:
            problems.append((k, "%s too steep (%.2f up in %.2f)" % (how, rise, across)))
        elif how == "slope" and rise > 0.0 and math.degrees(math.atan2(rise, across)) > 40.0:
            problems.append((k, "slope %.0f degrees" % math.degrees(math.atan2(rise, across))))
    return problems


# ======================================================================================================================
# Houses
# ======================================================================================================================

def _porch_posts(kit, x0, x1, z, y0, y1, n, mat="white", pier="stone"):
    """Craftsman posts: a stone pier, a tapered wooden column on it."""
    for k in range(n):
        x = x0 + (x1 - x0) * k / max(n - 1, 1)
        kit.box(x - 0.22, y0, z - 0.22, x + 0.22, y0 + 0.9, z + 0.22, pier)
        kit.bar((x, y0 + 0.9, z), (x, y1, z), 0.22, mat)


def _fence(kit, x0, x1, z, gate=None, height=1.0, mat="fence"):
    """A picket fence along z from x0 to x1, a gap at `gate` (x); its top rail a path to run along."""
    spans = [(x0, x1)] if gate is None else [(x0, gate - 0.6), (gate + 0.6, x1)]
    for a, b in spans:
        kit.box(a, height - 0.1, z - 0.1, b, height, z + 0.1, mat)
        k = a
        while k < b:
            kit.box(k, 0.0, z - 0.03, k + 0.1, height - 0.05, z + 0.03, mat, "see")
            k += 0.18
        kit.face([(a, 0.0, z), (b, 0.0, z), (b, height, z), (a, height, z)], mat, 1.0, "block")
        for post in (a, b):
            kit.box(post - 0.06, 0.0, z - 0.06, post + 0.06, height + 0.12, z + 0.06, mat)


def _chimney(kit, x, z, base, top, w=0.9, mat="brick"):
    kit.box(x - w / 2, base, z - w / 2, x + w / 2, top, z + w / 2, mat)
    kit.box(x - w / 2 - 0.06, top - 0.18, z - w / 2 - 0.06, x + w / 2 + 0.06, top, z + w / 2 + 0.06, "concrete")


def house(kit, style):
    """A Pacific Northwest house as a little level. style: craftsman (a storey and a half, a deep porch on stone piers,
    a low roof, a shed dormer, a chimney up its end), box (two storeys, a porch, an attached garage), farmhouse (two
    storeys, a porch round two sides, a steep roof, a wing behind), aframe (a cabin all roof, scurried up)."""
    rng = kit.rng
    siding = rng.choice(SIDINGS)
    roof = rng.choice(ROOFS)
    trim = "white"
    if style == "aframe":
        return _aframe(kit, siding, roof)
    two = style in ("box", "farmhouse")
    w = rng.uniform(9.0, 11.0) if style != "box" else rng.uniform(8.0, 9.5)
    d = rng.uniform(7.5, 9.0)
    base = 0.6
    eave = 5.6 if two else 3.4
    pitch = {"craftsman": 0.5, "box": 0.55, "farmhouse": 0.72}[style]
    rise = d / 2 * pitch
    over = 0.6 if style == "craftsman" else 0.45
    hw, hd = w / 2, d / 2
    # Foundation, walls, roof
    kit.box(-hw - 0.05, 0.0, -hd - 0.05, hw + 0.05, base, hd + 0.05, "stone" if style == "craftsman" else "concrete")
    kit.box(-hw, base, -hd, hw, eave, hd, siding)
    if two:
        # (a belt of trim between the floors: a narrow ledge)
        kit.box(-hw - 0.12, 3.0, -hd - 0.12, hw + 0.12, 3.14, hd + 0.12, trim)
    ridge, edge = kit.gable(-hw, hw, -hd, hd, eave, rise, roof, "x", over, ends=siding)
    slope = rise / hd
    for s in (-1, 1):
        kit.gutter((-hw - over, edge, s * (hd + over)), (hw + over, edge, s * (hd + over)), (0.0, s))
    # Windows round it, front and back, both floors
    for wall in (("z", hd, 1.0), ("z", -hd, -1.0)):
        for u in (-hw + 1.6, hw - 1.6):
            kit.window(wall, u, base + 0.8, 1.3, 1.3, sill=0.12)
            if two:
                kit.window(wall, u, 3.6, 1.2, 1.2, sill=0.3)
    for wall in (("x", hw, 1.0), ("x", -hw, -1.0)):
        kit.window(wall, rng.uniform(-1.5, 1.5), base + 0.9, 1.0, 1.1, sill=0.12)
    # The front door
    door_x = rng.choice([-1.0, 1.0]) * rng.uniform(0.0, 1.5)
    kit.box(door_x - 0.5, base, hd, door_x + 0.5, base + 2.1, hd + 0.06, "door", "see")
    route_side = rng.choice([-1, 1])        # which end of the porch he climbs at
    if style == "box":
        return _box_house(kit, w, d, base, eave, ridge, edge, slope, over, siding, roof, door_x, route_side)
    # A porch across the front: a deck at floor height, steps to the door, posts, a rail, a shed roof
    pw = w * (0.62 if style == "craftsman" else 1.0)
    px0 = door_x - pw / 2 if style == "craftsman" else -hw
    px0 = max(-hw, min(px0, hw - pw))
    px1 = px0 + pw
    pd = 2.6
    pz0, pz1 = hd, hd + pd
    kit.box(px0, 0.0, pz0, px1, base, pz1, "wood", top="wood")
    kit.steps(door_x, pz1 + 0.9, 0.0, -1.0, 1.6, base, "wood", step=0.2)
    # (a storey and a half: the porch roof a jump under the main eaves; two storeys: under the upper windows)
    porch_low = edge - 0.7 if style == "craftsman" else 2.85
    porch_high = porch_low + 0.25
    posts = 3 if pw < 7.0 else 4
    _porch_posts(kit, px0 + 0.25, px1 - 0.25, pz1 - 0.25, base, porch_low - 0.16, posts)
    porch_at = kit.shed(px0, px1, pz0, pz1, porch_low, porch_high, "z0", roof, over=0.25)
    for a, b in (((px0 + 0.25, base, pz1 - 0.25), (door_x - 0.9, base, pz1 - 0.25)),
                 ((door_x + 0.9, base, pz1 - 0.25), (px1 - 0.25, base, pz1 - 0.25)),
                 ((px0 + 0.25, base, pz0 + 0.1), (px0 + 0.25, base, pz1 - 0.25)),
                 ((px1 - 0.25, base, pz0 + 0.1), (px1 - 0.25, base, pz1 - 0.25))):
        if math.dist(a, b) > 0.3:
            kit.railing(a, b, 0.85, trim)
    # The way up at one end of the porch: a chopping block, a rain barrel if it is high, a woodpile against the
    # porch's end, its roof's edge
    end = px1 if route_side > 0 else px0
    s = route_side
    zm = (pz0 + pz1) / 2 + 0.2
    pile_top = porch_low - 1.25
    kit.box(end + s * 0.35, 0.0, zm - 0.9, end + s * 1.15, pile_top, zm + 0.9, "darkwood", top="wood")
    for k in range(4):
        kit.cylinder(end + s * 0.75, 0.05 + k * pile_top / 4, zm + 0.95, 0.12, 0.05, "wood", 6, "see")
    stones = [(end + s * 2.7, 0.5, 0.5, "wood")]
    if pile_top - 0.5 > 0.85:
        stones.append((end + s * 1.65, (0.5 + pile_top) / 2, 0.4, "bin"))
    kit.node("start", end + s * 4.2, 0.0, zm)
    for x, top, radius, mat in stones:
        kit.cylinder(x, 0.0, zm, radius, top, mat, 10)
        kit.node("jump", x, top, zm)
    kit.node("jump", end + s * 0.75, pile_top, zm)
    kit.node("ledge", end - s * 0.7, porch_at(end - s * 0.7, zm), zm)
    # Along the porch roof to its middle front, then up onto the main roof's eave (a jump, or up a drainpipe from the
    # porch roof on a two-storey house), up its slope to the ridge
    xp = end - s * 2.0
    if style == "craftsman":
        zp = hd + over + 0.75
        kit.node("walk", xp, porch_at(xp, zp), zp)
        z_on = hd + over - 0.35
        kit.node("jump", xp, edge + slope * 0.35, z_on)
    else:
        zp = hd + 0.9
        kit.node("walk", xp, porch_at(xp, zp), zp)
        kit.downpipe(xp, hd, 0.0, 1.0, edge, over, y0=porch_at(xp, hd + 0.1))
        kit.node("climb", xp, edge + slope * 0.6, hd - 0.6)
    kit.node("slope", xp, ridge, 0.0)
    if style == "craftsman":
        # A shed dormer on the front slope (its roof a step), a chimney up the far gable end: the top
        dx = -s * w * 0.15
        dz0, dz1 = 0.6, hd - 0.4
        y_back = ridge - slope * dz0
        kit.box(dx - 1.3, eave + slope * (hd - dz1) - 0.1, dz0, dx + 1.3, y_back - 0.3, dz1, siding)
        kit.window(("z", dz1, 1.0), dx, y_back - 1.3, 1.6, 0.7)
        kit.shed(dx - 1.3, dx + 1.3, dz0, dz1, y_back - 0.45 - (dz1 - dz0) * 0.25, y_back - 0.3, "z0", roof, over=0.2)
        cx = -s * (hw + 0.45)
        _chimney(kit, cx, -0.6, 0.0, ridge + 0.85)
        kit.node("walk", -s * (hw - 0.4), ridge, -0.6 + 0.0)
        kit.node("jump", cx, ridge + 0.85, -0.6)
    else:
        # The farmhouse's brick chimney through the ridge
        cx = -s * hw * 0.4
        _chimney(kit, cx, 0.0, ridge - 1.2, ridge + 0.9, 0.8)
        kit.node("walk", cx + s * 0.9, ridge, 0.0)
        kit.node("jump", cx, ridge + 0.9, 0.0)
    # A lower wing out the back under a cross gable (an L to one side, a T in the middle), always on the farmhouse
    if style == "farmhouse" or rng.random() < 0.6:
        ww, wd = rng.uniform(4.5, 6.0), rng.uniform(4.0, 5.5)
        wx = rng.choice([s * (hw - ww / 2 - 0.4), 0.0])
        wing_eave = 3.2 if two else 2.9
        kit.box(wx - ww / 2, base, -hd - wd, wx + ww / 2, wing_eave, -hd, siding)
        kit.gable(-hd - wd, -hd + 0.1, wx - ww / 2, wx + ww / 2, wing_eave, ww / 2 * 0.7, roof, "z", 0.4, ends=siding)
        for side in (-1, 1):
            kit.window(("x", wx + side * ww / 2, side), -hd - wd / 2, base + 0.8, 1.1, 1.2, sill=0.12)
    # A bay window out of the far end's wall: three faces of glass, a little roof over it (a ledge)
    bz = rng.uniform(-hd + 1.6, hd - 2.0)
    bx = -s * hw
    kit.box(bx, base + 0.3, bz - 1.1, bx - s * 0.7, base + 2.3, bz + 1.1, siding)
    kit.window(("x", bx - s * 0.7, -s), bz, base + 0.8, 1.4, 1.2)
    kit.shed(min(bx, bx - s * 0.7), max(bx, bx - s * 0.7), bz - 1.1, bz + 1.1, base + 2.3, base + 2.6, "x1" if s < 0 else "x0", roof, over=0.12)
    # Downpipes at the back corners (climbable), a picket fence along the front with a gate
    for sx in (-1, 1):
        kit.downpipe(sx * hw, -hd + 0.6, float(sx), 0.0, edge, 0.0)
    _fence(kit, -hw - 2.0, hw + 2.0, pz1 + 3.5, gate=door_x)
    return kit


def _box_house(kit, w, d, base, eave, ridge, edge, slope, over, siding, roof, door_x, s):
    """Two storeys: a porch hood over the door; an attached garage with a lean-to roof against the house's end; on
    the garage roof a flower box and a trellis; the way up: bins, the garage roof's edge, up it, the trellis box, the
    main roof's rake at its corner; a chimney."""
    rng = kit.rng
    hw, hd = w / 2, d / 2
    # The porch hood and steps
    kit.steps(door_x, hd + 1.2, 0.0, -1.0, 1.4, base, "concrete")
    kit.shed(door_x - 1.0, door_x + 1.0, hd, hd + 1.2, 2.9, 3.1, "z0", roof, over=0.1)
    # The garage against one end
    gw = 4.2
    g0, g1 = (hw, hw + gw) if s > 0 else (-hw - gw, -hw)
    gz0, gz1 = -hd + 0.5, hd + 0.8
    wall_side = "x0" if s > 0 else "x1"
    g_low, g_high = 2.3, 4.4
    garage_at = kit.shed(g0, g1, gz0, gz1, g_low, g_high, wall_side, roof, over=0.25)
    outer = g1 if s > 0 else g0
    kit.box(g0, 0.0, gz0, g1, g_low, gz1, siding)
    # (the garage's walls up under its roof, a triangle at each end)
    for z in (gz0, gz1):
        kit.face([(outer, g_low, z), (hw * s, g_high, z), (hw * s, g_low, z)], siding, 0.92)
    kit.box(g0 + 0.4, 0.0, gz1, g1 - 0.4, 2.3, gz1 + 0.05, "white", "see")
    for k in range(4):
        kit.box(g0 + 0.4, 0.4 + k * 0.5, gz1 + 0.05, g1 - 0.4, 0.43 + k * 0.5, gz1 + 0.08, "metal", "see")
    # Bins beside the garage's outer end, the first steps
    zb = gz1 - 1.4
    kit.box(outer + s * 0.3, 0.0, zb - 0.45, outer + s * 1.1, 1.05, zb + 0.45, "bin")
    kit.box(outer + s * 1.2, 0.0, zb - 0.4, outer + s * 1.8, 0.55, zb + 0.4, "concrete")
    kit.node("start", outer + s * 3.5, 0.0, zb)
    kit.node("jump", outer + s * 1.5, 0.55, zb)
    kit.node("jump", outer + s * 0.7, 1.05, zb)
    # (the lean-to's edge overhangs the bin's inner edge: he catches it)
    x_on = outer - s * 0.35
    kit.node("ledge", x_on, garage_at(x_on, zb), zb)
    # Up the garage roof towards the house to a planter box at the rake's front corner, clear of the eaves
    zc = hd + over + 0.15
    xc = s * (hw + over + 0.75)
    planter_top = garage_at(xc, zc) + 0.5
    kit.box(xc - 0.5, garage_at(xc, zc) - 0.3, zc - 0.55, xc + 0.5, planter_top, zc + 0.35, "cedar", top="dirt")
    for k in range(5):
        kit.cone(xc - 0.4 + k * 0.2, planter_top, zc - 0.1, 0.12, 0.35, "moss", 5, "see")
    kit.node("slope", xc + s * 0.9, garage_at(xc + s * 0.9, zc), zc)
    kit.node("jump", xc, planter_top, zc)
    # (from the planter, onto the main roof's corner over the eaves)
    z_on = hd + over - 0.45
    x_on = s * (hw - 0.3)
    kit.node("ledge", x_on, edge + slope * 0.45, z_on)
    kit.node("slope", x_on, ridge, 0.0)
    cx = -s * hw * 0.5
    _chimney(kit, cx, -0.4, ridge - 1.2, ridge + 0.9, 0.8)
    kit.node("walk", cx + s * 0.9, ridge, -0.4)
    kit.node("jump", cx, ridge + 0.9, -0.4)
    # A trellis up the garage's front corner of the house (climbable), downpipes behind, a deck out the back
    kit.box(-s * hw + s * 0.2, base, hd + 0.02, -s * hw + s * 1.5, eave - 0.6, hd + 0.08, "white", "see")
    for sx in (-1, 1):
        kit.downpipe(sx * hw, -hd + 0.6, float(sx), 0.0, edge, 0.0)
    deck_y = 1.2
    kit.box(-hw + 0.5, deck_y - 0.15, -hd - 3.0, hw - 2.5, deck_y, -hd, "wood")
    for x in (-hw + 0.6, hw - 2.6):
        kit.bar((x, 0.0, -hd - 2.9), (x, deck_y - 0.15, -hd - 2.9), 0.16, "wood")
    kit.railing((-hw + 0.5, deck_y, -hd - 3.0), (hw - 3.6, deck_y, -hd - 3.0), 0.9, "white")
    kit.stair_flight(hw - 3.0, -hd - 3.0 - 0.3 * 7, 0.0, 1.0, 1.0, 0.0, deck_y, "wood")
    _fence(kit, -hw - 2.0, hw + 2.0 if s < 0 else hw + gw + 2.0, hd + 4.5, gate=door_x) if rng.random() < 0.6 else None
    return kit


def _aframe(kit, siding, roof):
    """An A-frame cabin: two steep roof slopes down to the ground (climb_: scurried up), a glass gable front, a deck
    on posts in front with stairs, a stovepipe; the way up: the deck, the deck rail, the roof (scurry), the ridge."""
    rng = kit.rng
    w = rng.uniform(7.0, 8.5)      # across (x)
    d = rng.uniform(8.0, 10.0)     # deep (z)
    hw, hd = w / 2, d / 2
    ridge = hw * 1.7
    kit.box(-hw, 0.0, -hd, hw, 0.5, hd, "concrete")
    # The two slopes (steep: climbable), their thickness, the gable walls under them
    for sx in (-1, 1):
        kit.slab([(sx * (hw + 0.4), -hd - 0.5), (sx * (hw + 0.4), hd + 0.5), (sx * 0.5, hd + 0.5), (sx * 0.5, -hd - 0.5)],
                 [0.3, 0.3, ridge, ridge], 0.2, roof, "climb", under="darkwood")
    for z, out in ((hd, 1.0), (-hd, -1.0)):
        kit.face([(-hw, 0.5, z), (hw, 0.5, z), (0.0, ridge - 0.1, z)], "glass" if out > 0 else siding, 0.9)
        kit.bar((-hw * 0.5, 0.5, z + out * 0.05), (-hw * 0.5, ridge * 0.5, z + out * 0.05), 0.08, "white", "see")
        kit.bar((hw * 0.5, 0.5, z + out * 0.05), (hw * 0.5, ridge * 0.5, z + out * 0.05), 0.08, "white", "see")
        kit.bar((-hw * 0.75, ridge * 0.25 + 0.5, z + out * 0.05), (hw * 0.75, ridge * 0.25 + 0.5, z + out * 0.05), 0.08, "white", "see")
    # The deck in front, on posts, stairs up its side
    deck_y = 1.4
    kit.box(-hw - 0.5, deck_y - 0.15, hd + 0.5, hw + 0.5, deck_y, hd + 3.5, "wood")
    for x in (-hw - 0.3, hw + 0.3):
        for z in (hd + 0.7, hd + 3.3):
            kit.bar((x, 0.0, z), (x, deck_y - 0.15, z), 0.18, "wood")
    s = rng.choice([-1, 1])
    kit.railing((-s * (hw + 0.5), deck_y, hd + 3.5), (s * (hw + 0.5), deck_y, hd + 3.5), 0.9, "wood", spindles=False)
    kit.railing((-s * (hw + 0.5), deck_y, hd + 0.5), (-s * (hw + 0.5), deck_y, hd + 3.5), 0.9, "wood", spindles=False)
    end = kit.stair_flight(s * (hw + 1.1), hd + 3.4 - 0.3 * 8, 0.0, 1.0, 1.0, 0.0, deck_y, "wood")
    _ = end
    kit.cylinder(-s * hw * 0.3, ridge - 1.5, -hd * 0.4, 0.12, 2.6, "black", 8)
    # (a cap along the ridge to stand on; the way up: scurry up a slope from its foot, walk along the ridge to the
    # stovepipe)
    kit.box(-0.5, ridge - 0.2, -hd - 0.5, 0.5, ridge, hd + 0.5, "darkwood")
    kit.node("start", s * (hw + 2.4), 0.0, 0.0)
    kit.node("climb", s * 0.2, ridge, 0.0)
    kit.node("walk", 0.0, ridge, -hd * 0.4 + 0.9)
    # A woodshed and a woodpile beside it
    kit.box(-s * (hw + 3.5), 0.0, -1.0, -s * (hw + 1.5), 1.6, 1.0, "cedar")
    kit.shed(-s * (hw + 3.5), -s * (hw + 1.5), -1.0, 1.0, 1.6, 2.0, "x1" if s < 0 else "x0", roof, over=0.2)
    return kit


# ======================================================================================================================
# Apartments, commercial
# ======================================================================================================================

def walkup(kit):
    """A walk-up block of flats: three or four storeys, open walkways along the front on every floor above the ground
    reached by a stair tower at one end (its last flight comes up beside the roof's parapet), balconies stacked up
    the back, a fire escape down the other end, a flat roof with a parapet, the stair house with an AC unit to climb
    it by, a water tank on legs beside it (the top), vents."""
    rng = kit.rng
    floors = rng.choice([3, 3, 4])
    storey = 2.8
    w = rng.uniform(16.0, 22.0)
    d = 9.0
    hw, hd = w / 2, d / 2
    top = floors * storey
    siding = rng.choice(["siding4", "siding5", "siding", "brick"])
    s = rng.choice([-1, 1])
    kit.box(-hw, 0.0, -hd, hw, top, hd, siding)
    roof_y = top + 0.04
    kit.box(-hw + 0.25, top, -hd + 0.25, hw - 0.25, roof_y, hd - 0.25, "tar")
    for x0, z0, x1, z1 in ((-hw, -hd, hw, -hd + 0.25), (-hw, hd - 0.25, hw, hd), (-hw, -hd, -hw + 0.25, hd), (hw - 0.25, -hd, hw, hd)):
        kit.box(x0, top, z0, x1, top + 0.7, z1, "concrete")                    # the parapet
    # Doors and windows; walkways along the front on each floor above the ground; balconies behind
    walk_d = 1.6
    flats = int(w / 4.0)
    for f in range(floors):
        y = f * storey
        for k in range(flats):
            u = -hw + 2.0 + k * 4.0
            kit.box(u - 0.45, y + 0.02, hd, u + 0.45, y + 2.1, hd + 0.05, "door", "see")
            kit.window(("z", hd, 1.0), u + 1.4, y + 1.0, 1.0, 1.0)
            kit.window(("z", -hd, -1.0), u, y + 1.0, 1.4, 1.2)
        if f == 0:
            continue
        kit.box(-hw, y - 0.2, hd, hw, y, hd + walk_d, "concrete")
        kit.railing((-hw, y, hd + walk_d - 0.05), (hw, y, hd + walk_d - 0.05), 1.0, "rail", spindles=False)
        kit.railing((-s * hw, y, hd), (-s * hw, y, hd + walk_d - 0.05), 1.0, "rail", spindles=False)
        for k in range(flats):
            u = -hw + 2.0 + k * 4.0
            kit.box(u - 1.3, y - 0.18, -hd - 1.3, u + 1.3, y, -hd, "concrete")
            kit.railing((u - 1.3, y, -hd - 1.25), (u + 1.3, y, -hd - 1.25), 1.0, "rail", spindles=False)
    # The stair tower at end s: a landing at the walkway's end on each floor, a landing behind, flights between
    lo, hi = (hw, hw + 3.2) if s > 0 else (-hw - 3.2, -hw)
    tz1 = hd + walk_d
    flight = 2.4                       # 8 steps of 0.3 m: half a storey
    tz0 = tz1 - 1.6 - flight - 1.3
    xa, xb = lo + 0.8, hi - 0.8
    if s < 0:
        xa, xb = xb, xa
    for x in (lo + 0.1, hi - 0.1):
        for z in (tz0 + 0.1, tz1 - 0.1):
            kit.bar((x, 0.0, z), (x, top + 1.0, z), 0.16, "steel", "see")
    kit.node("start", (lo + hi) / 2, 0.0, tz1 + 2.5)
    kit.node("walk", xa, 0.0, tz1 - 0.6)
    half = storey / 2
    for k in range(floors * 2):
        y0, y1 = k * half, (k + 1) * half
        if k % 2 == 0:
            kit.stair_flight(xa, tz1 - 1.6, 0.0, -1.0, 1.1, y0, half, "concrete")
            kit.box(lo, y1 - 0.15, tz0, hi, y1, tz0 + 1.3, "concrete")
            if k:
                kit.node("walk", xa, y0, tz1 - 0.8)
            kit.node("stairs", xa, y1, tz0 + 0.65)
        else:
            kit.stair_flight(xb, tz0 + 1.3, 0.0, 1.0, 1.1, y0, half, "concrete")
            kit.node("walk", xb, y0, tz0 + 0.65)
            kit.box(lo, y1 - 0.15, tz1 - 1.6, hi, y1, tz1, "concrete")
            kit.railing((lo, y1, tz1 - 0.05), (hi, y1, tz1 - 0.05), 1.0, "rail", spindles=False)
            kit.node("stairs", xb, y1, tz1 - 0.8)
    # (the top landing is level with the roof: over the parapet (0.7) and down onto it)
    kit.node("walk", s * (hw + 0.45), top, hd + 0.45)
    kit.node("jump", s * (hw - 0.15), top + 0.7, hd - 0.15)
    kit.node("walk", s * (hw - 1.2), roof_y, hd - 1.2)
    # On the roof: the stair house (an AC unit beside it the step up), the water tank on its legs beside that
    hx = s * (hw - 5.0)
    house_top = roof_y + 2.2
    kit.box(hx - 1.6, roof_y, -1.5, hx + 1.6, house_top, 1.5, "concrete")
    kit.box(hx - 1.7, house_top, -1.6, hx + 1.7, house_top + 0.12, 1.6, "tar")
    ac = hx + s * 2.2
    kit.box(ac - 0.5, roof_y, 0.0, ac + 0.5, roof_y + 0.95, 1.0, "white")
    kit.box(ac - 0.4, roof_y + 0.95, 0.1, ac + 0.4, roof_y + 1.0, 0.9, "metal", "see")
    kit.node("walk", ac + s * 1.3, roof_y, 0.5)
    kit.node("jump", ac + s * 0.1, roof_y + 1.0, 0.5)
    kit.node("ledge", hx + s * 1.0, house_top + 0.12, 0.5)
    tx = hx - s * 3.6
    tank_y = house_top + 0.55
    for x in (tx - 1.2, tx + 1.2):
        for z in (-1.2, 1.2):
            kit.bar((x, roof_y, z), (x, tank_y - 0.12, z), 0.14, "steel")
    kit.box(tx - 1.6, tank_y - 0.12, -1.6, tx + 1.6, tank_y, 1.6, "steel")
    kit.cylinder(tx, tank_y, 0.0, 1.0, 1.3, "cedar", 10, top="cedar")
    for y in (0.3, 0.9):
        kit.cylinder(tx, tank_y + y, 0.0, 1.03, 0.06, "black", 10, "see", cap=False)
    kit.cone(tx, tank_y + 1.3, 0.0, 0.25, 0.3, "tar", 6, "see")
    kit.node("walk", hx - s * 1.25, house_top + 0.12, 0.5)
    kit.node("jump", tx + s * 1.3, tank_y, 0.5)
    kit.node("ledge", tx + s * 0.4, tank_y + 1.3, 0.0)
    # A fire escape down the other end (platforms at each floor, ladders off their ends: to look at, and a way down)
    fx = -s * hw
    for f in range(1, floors):
        y = f * storey
        kit.box(fx - s * 1.3, y - 0.1, -2.0, fx, y, 2.0, "steel_red")
        kit.railing((fx - s * 1.25, y, -2.0), (fx - s * 1.25, y, 2.0), 0.9, "steel_red", spindles=False)
        kit.bar((fx - s * 1.0, y - storey + 0.6, 2.1), (fx - s * 1.0, y + 0.9, 2.1), 0.05, "steel_red", "see")
        kit.bar((fx - s * 0.4, y - storey + 0.6, 2.1), (fx - s * 0.4, y + 0.9, 2.1), 0.05, "steel_red", "see")
    for x in (-hw * 0.5, hw * 0.5):
        kit.cylinder(x, roof_y, -2.5, 0.25, 0.9, "zinc", 6)
    return kit


def commercial(kit):
    """A brick commercial block: two or three storeys over shop fronts, canvas awnings over them (sloped: caught by
    their edge and run up), a sign band, deep stone sills on the upper windows, a one-storey shop wing at one end with
    an awning of its own, a drainpipe up the main block's end from the wing's roof (climbable), a fire escape, a
    parapet with a cornice, a billboard on the roof on a catwalk with a ladder (the top), a vent and an AC unit."""
    rng = kit.rng
    floors = rng.choice([2, 3, 3])
    ground_h, storey = 4.0, 3.2
    w = rng.uniform(14.0, 20.0)
    d = 12.0
    hw, hd = w / 2, d / 2
    top = ground_h + (floors - 1) * storey
    brick = rng.choice(["brick", "brick", "stone"])
    s = rng.choice([-1, 1])
    kit.box(-hw, 0.0, -hd, hw, top, hd, brick)
    kit.box(-hw - 0.25, top - 0.35, -hd - 0.25, hw + 0.25, top, hd + 0.25, "concrete")      # cornice
    for x0, z0, x1, z1 in ((-hw, -hd, hw, -hd + 0.3), (-hw, hd - 0.3, hw, hd), (-hw, -hd, -hw + 0.3, hd), (hw - 0.3, -hd, hw, hd)):
        kit.box(x0, top, z0, x1, top + 0.8, z1, brick)                       # parapet
    roof_y = top + 0.04
    kit.box(-hw + 0.3, top, -hd + 0.3, hw - 0.3, roof_y, hd - 0.3, "tar")
    awnings = ["awning_red", "awning_green", "awning", "sign2"]

    def awning(u0, u1, z, colour, high=3.1, low=2.55, out=1.8):
        kit.slab([(u0, z), (u1, z), (u1, z + out), (u0, z + out)], [high, high, low, low], 0.08, colour)
        for u in (u0 + 0.1, u1 - 0.1):
            kit.bar((u, high - 0.6, z), (u, low - 0.04, z + out - 0.05), 0.04, "steel", "see")

    shops = max(2, int(w / 5.0))
    width = w / shops
    for k in range(shops):
        u = -hw + width * (k + 0.5)
        kit.box(u - width / 2 + 0.3, 0.3, hd, u + width / 2 - 0.3, 3.0, hd + 0.05, "glass")
        kit.box(u - 0.5, 0.0, hd + 0.05, u + 0.5, 2.4, hd + 0.08, "door", "see")
        kit.box(u - width / 2 + 0.2, 3.25, hd, u + width / 2 - 0.2, 3.95, hd + 0.15, "sign" if k % 2 else "sign2")
        awning(u - width / 2 + 0.3, u + width / 2 - 0.3, hd, awnings[k % len(awnings)])
        for f in range(1, floors):
            y = ground_h + (f - 1) * storey
            for j in (-1, 1):
                kit.window(("z", hd, 1.0), u + j * width * 0.22, y + 0.9, 1.1, 1.6, sill=0.4)
    for f in range(floors):
        y = ground_h + (f - 1) * storey if f else 0.0
        for k in range(shops):
            kit.window(("z", -hd, -1.0), -hw + width * (k + 0.5), y + 1.0, 1.2, 1.4)
    # The one-storey wing at end s
    wx0, wx1 = (hw, hw + 6.0) if s > 0 else (-hw - 6.0, -hw)
    wing = 3.2
    kit.box(wx0, 0.0, -hd + 2.0, wx1, wing, hd, brick)
    for x0, z0, x1, z1 in ((wx0, hd - 0.25, wx1, hd), (wx0, -hd + 2.0, wx1, -hd + 2.25)):
        kit.box(x0, wing, z0, x1, wing + 0.4, z1, "concrete")
    outer = wx1 if s > 0 else wx0
    kit.box(outer - 0.25 if s > 0 else outer, wing, -hd + 2.0, outer if s > 0 else outer + 0.25, wing + 0.4, hd, "concrete")
    kit.box(wx0 + 0.6, 0.3, hd, wx1 - 0.6, 2.7, hd + 0.05, "glass")
    awning(wx0 + 0.4, wx1 - 0.4, hd, "awning_green" if s > 0 else "awning_red", high=2.95, low=2.5, out=1.6)
    # The way up: a bench, a newspaper box, the wing's awning's edge, up it, over the parapet onto the wing's roof
    xm = (wx0 + wx1) / 2
    zf = hd + 1.6
    kit.box(xm - s * 0.4 - 0.25, 0.0, zf + 0.5, xm - s * 0.4 + 0.25, 0.5, zf + 1.6, "wood")          # bench
    kit.box(xm + s * 0.9 - 0.3, 0.0, zf + 0.45, xm + s * 0.9 + 0.3, 1.15, zf + 1.05, "sign2")          # paper box
    kit.node("start", xm - s * 0.4, 0.0, zf + 2.7)
    kit.node("jump", xm - s * 0.4, 0.5, zf + 1.05)
    kit.node("jump", xm + s * 0.9, 1.15, zf + 0.75)
    kit.node("ledge", xm + s * 0.9, 2.55, hd + 1.3)
    kit.node("slope", xm + s * 0.9, 2.85, hd + 0.5)
    kit.node("jump", xm + s * 0.9, wing, hd - 1.0)
    # A drainpipe up the main block's end from the wing's roof to the parapet (climbable), the fire escape beside it
    pz = -1.0
    kit.downpipe(s * hw, pz, float(s), 0.0, top + 0.8, 0.0, y0=wing)
    kit.node("walk", s * (hw + 0.6), wing, pz)
    kit.node("climb", s * (hw - 0.6), roof_y, pz)
    for f in range(1, floors):
        y = ground_h + (f - 1) * storey + 0.2
        kit.box(s * hw, y - 0.1, 1.0, s * (hw + 1.3), y, 4.0, "steel_red", top="metal")
        kit.railing((s * (hw + 1.25), y, 1.0), (s * (hw + 1.25), y, 4.0), 0.9, "steel_red", spindles=False)
    # The billboard on the roof: legs, the board, the catwalk in front of it, a ladder up to the catwalk
    bx = -s * hw * 0.25
    walk_y = roof_y + 3.0
    bz = -hd + 1.4
    for x in (bx - 2.5, bx + 2.5):
        kit.bar((x, roof_y, bz - 0.1), (x, walk_y + 3.0, bz - 0.1), 0.2, "steel")
    kit.box(bx - 3.5, walk_y + 0.2, bz - 0.1, bx + 3.5, walk_y + 3.2, bz + 0.05, "sign")
    kit.box(bx - 3.6, walk_y - 0.1, bz + 0.05, bx + 3.6, walk_y, bz + 1.0, "metal")
    lx = bx + s * 2.6
    gap = (lx - 0.5, lx + 0.5)
    for a, b in ((bx - 3.6, gap[0]), (gap[1], bx + 3.6)):
        kit.railing((a, walk_y, bz + 0.95), (b, walk_y, bz + 0.95), 0.9, "steel", spindles=False)
    kit.ladder(lx, roof_y, bz + 1.15, walk_y - roof_y, 0.0)
    kit.node("walk", lx, roof_y, bz + 1.6)
    kit.node("ladder", lx, walk_y, bz + 0.45)
    kit.node("walk", bx, walk_y, bz + 0.55)
    kit.box(s * hw * 0.4 - 0.7, roof_y, 1.0, s * hw * 0.4 + 0.7, roof_y + 1.1, 2.4, "white")
    kit.cylinder(0.0, roof_y, 2.5, 0.3, 0.8, "zinc", 6)
    return kit


# ======================================================================================================================
# Under construction
# ======================================================================================================================

def construction(kit):
    """A house going up: a slab, a ground floor of studs, joists with a floor deck of OSB over half of them, house wrap
    and roof trusses over that half; scaffolding along the front with planks staggered up its bays (a staircase of
    jumps) to the deck; stacks of lumber and pipes, cones, a portable toilet; a tower crane beside it (an unseen column
    in its mast scurried up, its jib walked along to the tip: the top)."""
    rng = kit.rng
    w, d = rng.uniform(10.0, 12.0), rng.uniform(8.0, 9.0)
    hw, hd = w / 2, d / 2
    s = rng.choice([-1, 1])
    slab = 0.3
    kit.box(-hw - 0.3, 0.0, -hd - 0.3, hw + 0.3, slab, hd + 0.3, "concrete")
    storey = 2.8
    # Studs round the ground floor (seen), plates (solid)
    for z in (-hd, hd):
        kit.box(-hw, slab, z - 0.07, hw, slab + 0.1, z + 0.07, "lumber")
        x = -hw
        while x <= hw:
            kit.box(x - 0.03, slab + 0.1, z - 0.07, x + 0.03, storey - 0.1, z + 0.07, "lumber", "see")
            x += 0.6
    for x in (-hw, hw):
        z = -hd
        while z <= hd:
            kit.box(x - 0.07, slab + 0.1, z - 0.03, x + 0.07, storey - 0.1, z + 0.03, "lumber", "see")
            z += 0.6
    for x0, z0, x1, z1 in ((-hw, -hd, hw, -hd + 0.14), (-hw, hd - 0.14, hw, hd), (-hw, -hd, -hw + 0.14, hd), (hw - 0.14, -hd, hw, hd)):
        kit.box(x0, storey - 0.1, z0, x1, storey, z1, "lumber")
    # Joists across, the deck over half of them, wrap and trusses over the deck
    deck_y = storey + 0.23
    x = -hw
    while x <= hw:
        kit.box(x - 0.04, storey, -hd, x + 0.04, deck_y - 0.03, hd, "lumber")
        x += 0.6
    d0, d1 = (-hw * 0.2, hw) if s > 0 else (-hw, hw * 0.2)
    kit.box(d0, deck_y - 0.03, -hd, d1, deck_y, hd, "osb")
    kit.box(d0, deck_y, -hd, d1, deck_y + 2.6, -hd + 0.06, "tyvek")
    truss = deck_y + 2.6
    x = d0
    while x <= d1 + 0.01:
        for zz in (-1, 1):
            kit.bar((x, truss, zz * hd), (x, truss + hd * 0.55, 0.0), 0.08, "lumber", "see")
        kit.bar((x, truss, -hd), (x, truss, hd), 0.1, "lumber", "see")
        x += 1.2
    for x in (d0 + 0.1, d1 - 0.1):
        for z in (-hd + 0.1, hd - 0.1):
            kit.box(x - 0.07, deck_y, z - 0.07, x + 0.07, truss, z + 0.07, "lumber")
    # The scaffolding along the front: standards every bay, planks staggered up from the far end towards end s
    sz0, sz1 = hd + 0.4, hd + 1.6
    bays = max(4, int(math.ceil(w / 2.0)))
    bay = w / bays
    for k in range(bays + 1):
        x = -hw + k * bay
        for z in (sz0, sz1):
            kit.bar((x, 0.0, z), (x, deck_y + 3.0, z), 0.06, "steel", "see")
        kit.bar((x, 0.0, sz0), (x, deck_y + 3.0, sz1), 0.04, "steel", "see")
    order = list(range(bays)) if s > 0 else list(range(bays - 1, -1, -1))
    top_plank = deck_y - 0.3
    first = 0.8
    lift = (top_plank - first) / (bays - 1)
    kit.node("start", -s * (hw - bay / 2), 0.0, sz1 + 1.3)
    for step, k in enumerate(order):
        x0 = -hw + k * bay
        y = first + lift * step
        kit.box(x0 + 0.05, y - 0.06, sz0, x0 + bay - 0.05, y, sz1, "lumber")
        kit.node("jump", x0 + bay / 2, y, (sz0 + sz1) / 2)
    # (from the top plank across onto the deck behind it)
    xd = max(d0 + 0.6, min(d1 - 0.6, -hw + order[-1] * bay + bay / 2))
    kit.node("jump", xd, deck_y, hd - 0.8)
    # The crane beside the house at end s: a lattice mast, the unseen column he climbs, the slewing deck, the jib
    cx, cz = s * (hw + 5.0), -1.0
    mast = 16.0
    for x in (cx - 0.8, cx + 0.8):
        for z in (cz - 0.8, cz + 0.8):
            kit.bar((x, 0.0, z), (x, mast, z), 0.12, "safety", "see")
    y = 0.0
    while y < mast - 0.1:
        for a, b in (((cx - 0.8, cz - 0.8), (cx + 0.8, cz - 0.8)), ((cx - 0.8, cz + 0.8), (cx + 0.8, cz + 0.8)),
                     ((cx - 0.8, cz - 0.8), (cx - 0.8, cz + 0.8)), ((cx + 0.8, cz - 0.8), (cx + 0.8, cz + 0.8))):
            kit.bar((a[0], y, a[1]), (b[0], y + 1.6, b[1]), 0.06, "safety", "see")
        y += 1.6
    kit.box(cx - 1.5, 0.0, cz - 1.5, cx + 1.5, 0.6, cz + 2.5, "concrete")
    # (the access ladder up the mast's front face, and round it the column he climbs, clear of the deck and jib)
    for x in (cx - 0.22, cx + 0.22):
        kit.bar((x, 0.6, cz + 0.95), (x, mast + 0.3, cz + 0.95), 0.05, "steel", "see")
    y = 0.9
    while y < mast:
        kit.bar((cx - 0.22, y, cz + 0.95), (cx + 0.22, y, cz + 0.95), 0.035, "steel", "see")
        y += 0.3
    kit.column([(cx, 0.6, cz + 1.0), (cx, mast + 0.45, cz + 1.0)], 0.4)
    kit.box(cx - 1.0, mast, cz - 1.0, cx + 1.0, mast + 0.25, cz + 0.45, "safety")
    kit.box(cx - 0.9, mast + 0.25, cz - 0.9, cx - 0.1, mast + 1.9, cz - 0.1, "white")              # the cab
    jib = 14.0
    j0, j1 = (cx - jib, cx + 4.0) if s > 0 else (cx - 4.0, cx + jib)
    kit.box(j0, mast + 0.25, cz - 0.45, j1, mast + 0.4, cz + 0.45, "safety")
    kit.box(cx + s * 3.0 - 1.0, mast + 0.4, cz - 0.6, cx + s * 3.0 + 1.0, mast + 1.4, cz + 0.6, "concrete")   # counterweight
    tip = j0 if s > 0 else j1
    kit.bar((cx, mast + 4.0, cz), (tip, mast + 0.45, cz), 0.06, "steel", "see")
    kit.bar((cx, mast + 0.25, cz), (cx, mast + 4.0, cz), 0.15, "safety", "see")
    hook = tip + s * 3.0
    kit.bar((hook, mast + 0.25, cz), (hook, deck_y + 4.5, cz), 0.03, "black", "see")
    kit.box(hook - 0.6, deck_y + 3.6, cz - 0.6, hook + 0.6, deck_y + 4.5, cz + 0.6, "concrete")
    # (off the deck's end, across to the crane's base, scurry up the mast, out along the jib to its tip)
    kit.node("walk", s * (hw - 0.4), deck_y, cz)
    kit.node("walk", cx - s * 2.4, 0.0, cz + 1.9)
    kit.node("jump", cx - s * 0.6, 0.6, cz + 1.9)
    kit.node("walk", cx, 0.6, cz + 1.9)
    kit.node("climb", cx, mast + 0.25, cz + 0.2)
    kit.node("walk", tip + s * 0.8, mast + 0.4, cz)
    # Lumber, pipes, cones, a portable toilet
    lx = -s * (hw + 2.5)
    for k in range(4):
        kit.box(lx - 0.6, k * 0.25, -hd, lx + 0.6, k * 0.25 + 0.22, -hd + 4.0, "lumber")
    for k in range(5):
        kit.bar((lx + s * (1.2 + k * 0.32), 0.16, -hd + 4.5), (lx + s * (1.2 + k * 0.32), 0.16, -hd + 8.0), 0.3, "black" if k % 2 else "zinc")
    for k in range(5):
        kit.cone(-hw + 1.0 + k * 2.2, 0.0, hd + 3.4, 0.18, 0.7, "cone", 6, "see")
    px = -s * (hw + 2.2)
    kit.box(px - 0.6, 0.0, hd + 1.0, px + 0.6, 2.3, hd + 2.2, "sign2")
    kit.box(px - 0.65, 2.3, hd + 0.95, px + 0.65, 2.4, hd + 2.25, "white")
    return kit


# ======================================================================================================================
# Industrial
# ======================================================================================================================

def factory(kit):
    """A factory: a long shed under a sawtooth roof (each tooth's slope run up, its glazed face dropped down), a
    conveyor belt sloping up from a hopper on the ground along the end wall to the roof (the way up), a brick stack
    with a catwalk ring and a ladder up it (the top), a pipe rack along the back (big pipes to run along), tanks."""
    rng = kit.rng
    w = rng.uniform(26.0, 34.0)
    d = rng.uniform(18.0, 22.0)
    hw, hd = w / 2, d / 2
    wall = 6.5
    s = rng.choice([-1, 1])
    clad = rng.choice(["corrugated", "corrugated2", "brick"])
    kit.box(-hw, 0.0, -hd, hw, wall, hd, clad)
    for k in range(int(w / 5.0)):
        kit.window(("z", hd, 1.0), -hw + 2.5 + k * 5.0, 3.0, 3.0, 2.2, frame="steel")
    kit.box(-2.5, 0.0, hd, 2.5, 4.5, hd + 0.08, "corrugated2", "see")
    # The teeth: each rising from the wall's top towards +z, its upright glazed face there
    teeth = int(d / 4.0)
    tooth = d / teeth
    rise = 2.2

    def roof_at(z):
        return wall + rise * (((z + hd) % tooth) / tooth)

    for k in range(teeth):
        z0, z1 = -hd + k * tooth, -hd + (k + 1) * tooth
        kit.slab([(-hw - 0.2, z0), (hw + 0.2, z0), (hw + 0.2, z1), (-hw - 0.2, z1)], [wall, wall, wall + rise, wall + rise], 0.15, "corrugated")
        kit.face([(-hw, wall, z1), (hw, wall, z1), (hw, wall + rise, z1), (-hw, wall + rise, z1)], "glass", 0.9)
        for x in (-hw, hw):
            kit.face([(x, wall, z0), (x, wall, z1), (x, wall + rise, z1)], clad, 0.9)
    # The conveyor along the end wall at side s: the hopper at the front, the belt up to the roof at the back tooth
    ex = s * (hw + 1.0)
    zb0 = hd + 5.0
    zb1 = -hd + tooth * 0.5
    low, high = 0.9, roof_at(zb1) + 0.2
    kit.box(ex - 1.2, 0.0, zb0 - 0.2, ex + 1.2, low, zb0 + 2.2, "steel_red")
    kit.slab([(ex - 0.6, zb0), (ex + 0.6, zb0), (ex + 0.6, zb1), (ex - 0.6, zb1)], [low, low, high, high], 0.25, "black")
    for side in (-1, 1):
        kit.bar((ex + side * 0.68, low + 0.12, zb0), (ex + side * 0.68, high + 0.12, zb1), 0.06, "steel", "see")
    for k in range(1, 7):
        t = k / 7
        kit.bar((ex, 0.0, zb0 + (zb1 - zb0) * t), (ex, low + (high - low) * t - 0.25, zb0 + (zb1 - zb0) * t), 0.2, "steel", "see")
    angle = math.degrees(math.atan2(high - low, zb0 - zb1))
    kit.node("start", ex, 0.0, zb0 + 3.0)
    kit.node("jump", ex, low, zb0 + 1.0)
    kit.node("slope", ex, high, zb1 + 0.4)
    kit.node("jump", s * (hw - 0.8), roof_at(zb1 + 0.3), zb1 + 0.3)
    _ = angle
    # Across the roof (along the tooth) to the stack's end, onto its bridge, round the ring, up the ladder
    sx, sz = -s * (hw + 2.6), -hd + tooth * 0.85
    stack_h = 18.0
    ring_y = wall + rise + 0.3
    kit.cylinder(sx, 0.0, sz, 1.1, stack_h, "brick", 10, "climb")
    kit.cylinder(sx, stack_h, sz, 1.3, 0.4, "concrete", 10)
    kit.cylinder(sx, ring_y - 0.15, sz, 2.3, 0.15, "metal", 12)
    kit.box(-s * (hw - 0.2), ring_y - 0.15, sz - 0.6, sx + s * 1.5, ring_y, sz + 0.6, "metal")
    for zz in (sz - 0.6, sz + 0.6):
        kit.railing((-s * hw, ring_y, zz), (sx + s * 1.9, ring_y, zz), 0.9, "steel", spindles=False)
    kit.ladder(sx, ring_y, sz + 1.15, stack_h + 0.4 - ring_y, 0.0)
    kit.node("walk", -s * (hw - 1.4), roof_at(sz - 0.3), sz - 0.3)
    kit.node("jump", -s * (hw - 0.5), ring_y, sz)
    kit.node("walk", sx, ring_y, sz + 1.75)
    kit.node("ladder", sx, stack_h + 0.4, sz + 0.3)
    # The pipe rack along the back: frames, two big pipes on top
    rz = -hd - 2.5
    for k in range(int(w / 5.0) + 1):
        x = -hw + k * 5.0
        for z in (rz - 1.0, rz + 1.0):
            kit.bar((x, 0.0, z), (x, 4.2, z), 0.18, "steel_red")
        kit.bar((x, 4.2, rz - 1.1), (x, 4.2, rz + 1.1), 0.2, "steel_red")
    for z, r in ((rz - 0.45, 0.42), (rz + 0.5, 0.3)):
        sides = 10
        pts = [(math.cos(math.tau * i / sides) * r, math.sin(math.tau * i / sides) * r) for i in range(sides)]
        for i in range(sides):
            (a, b), (c, e) = pts[i], pts[(i + 1) % sides]
            kit.face([(-hw, 4.3 + r + b, z + a), (hw, 4.3 + r + b, z + a), (hw, 4.3 + r + e, z + c), (-hw, 4.3 + r + e, z + c)], "zinc", 0.9 + 0.1 * b / r)
    for k in range(2):
        kit.cylinder(-s * (hw - 3.0 - k * 3.5), 0.0, hd + 3.0, 1.4, 4.0, "white", 10)
    return kit


def warehouse(kit):
    """A warehouse: a big box under a shallow gable, a loading dock along the front (a raised concrete deck, bumpers,
    roll-up doors, steps up), a canopy over it; crates stacked into a stair up the end beside the dock to the canopy's
    edge, a ladder up the wall to the eave, the roof, a vent cap (a step); a silo at the far end (scurried up) joined to
    the ridge by a catwalk; pallets."""
    rng = kit.rng
    w = rng.uniform(22.0, 28.0)
    d = rng.uniform(16.0, 20.0)
    hw, hd = w / 2, d / 2
    wall = 6.4
    s = rng.choice([-1, 1])
    clad = rng.choice(["corrugated", "corrugated2", "siding4"])
    kit.box(-hw, 0.0, -hd, hw, wall, hd, clad)
    over = 0.3
    ridge, edge = kit.gable(-hw, hw, -hd, hd, wall, 1.2, "corrugated", "x", over, ends=clad)
    slope = 1.2 / hd
    # The dock
    dock_y = 1.2
    kit.box(-hw, 0.0, hd, hw, dock_y, hd + 3.0, "concrete")
    doors = int(w / 5.0)
    for k in range(doors):
        u = -hw + 2.5 + k * 5.0
        kit.box(u - 1.6, dock_y, hd, u + 1.6, dock_y + 3.6, hd + 0.06, "metal", "see")
        for j in range(8):
            kit.box(u - 1.6, dock_y + 0.4 + j * 0.42, hd + 0.06, u + 1.6, dock_y + 0.43 + j * 0.42, hd + 0.09, "steel", "see")
        for b in (-0.8, 0.8):
            kit.box(u + b - 0.2, 0.4, hd + 3.0, u + b + 0.2, 1.0, hd + 3.15, "black", "see")
    kit.steps(-s * (hw - 1.0), hd + 3.0 + 0.3 * 7, 0.0, -1.0, 1.4, dock_y, "concrete", step=0.18)
    # The canopy over the dock, on struts
    canopy = 4.7
    kit.slab([(-hw, hd), (hw, hd), (hw, hd + 3.4), (-hw, hd + 3.4)], [canopy + 0.25, canopy + 0.25, canopy, canopy], 0.15, "metal")
    for k in range(doors + 1):
        x = -hw + k * w / doors
        kit.bar((x, wall - 1.0, hd), (x, canopy - 0.1, hd + 3.3), 0.12, "steel", "see")
    # Crates up the end beside the dock: columns one to four high, the top one by the canopy's end
    cx = s * (hw + 0.85)
    size = 0.9
    zs = [hd + 4.3, hd + 3.3, hd + 2.3, hd + 1.3]
    for k, z in enumerate(zs):
        for j in range(k + 1):
            kit.box(cx - size / 2, j * size, z - size / 2 + 0.02, cx + size / 2, (j + 1) * size - 0.02, z + size / 2 - 0.02, "crate")
    kit.box(cx - 0.6, 0.0, hd + 5.6, cx + 0.6, 0.15, hd + 6.8, "pallet")
    kit.node("start", cx, 0.0, hd + 6.2)
    for k, z in enumerate(zs):
        kit.node("jump", cx, (k + 1) * size - 0.02, z)
    canopy_at = canopy + 0.25 - 0.25 * (zs[-1] - hd) / 3.4
    kit.node("ledge", s * (hw - 0.6), canopy_at, zs[-1])
    # The ladder up the wall from the canopy to the eave, onto the roof, up to the ridge
    lx = s * (hw - 2.5)
    kit.ladder(lx, canopy + 0.2, hd + over + 0.12, edge + 0.05 - (canopy + 0.2), 0.0)
    kit.node("walk", lx, canopy + 0.2, hd + 1.3)
    kit.node("ladder", lx, edge + slope * 0.5, hd + over - 0.5)
    kit.node("slope", lx, ridge, 0.0)
    # Vents along the ridge, the silo at the far end, the catwalk from the ridge's end to it
    for k in range(3):
        vx = -hw + w * (k + 1) / 4
        kit.cylinder(vx, ridge - 0.5, -2.2, 0.45, 1.1, "zinc", 8)
        kit.cone(vx, ridge + 0.6, -2.2, 0.6, 0.35, "zinc", 8, "see")
    sx = -s * (hw + 3.2)
    silo_h = 13.0
    kit.cylinder(sx, 0.0, 0.0, 2.4, silo_h, "corrugated", 12, "climb")
    kit.cone(sx, silo_h, 0.0, 2.6, 1.6, "zinc", 12)
    kit.box(-s * (hw - 0.3), ridge - 0.1, -0.6, sx + s * 2.3, ridge, 0.6, "metal")
    for zz in (-0.6, 0.6):
        kit.railing((-s * hw, ridge, zz), (sx + s * 2.3, ridge, zz), 0.9, "steel", spindles=False)
    kit.node("walk", -s * (hw - 1.0), ridge, 0.0)
    kit.node("walk", sx + s * 2.6, ridge, 0.0)
    # (the silo from the catwalk's end: scurried up to its top)
    kit.node("climb", sx, silo_h + 0.3, 0.0)
    for k in range(3):
        kit.box(-s * (hw - 4.0) - 0.6, k * 0.16, hd + 6.0 - 0.6, -s * (hw - 4.0) + 0.6, k * 0.16 + 0.14, hd + 6.0 + 0.6, "pallet")
    return kit


def substation(kit):
    """An electrical substation: a gravel yard inside a chain-link fence (its unseen wall too tall to jump), a control
    hut straddling the front fence (the way in, over its roof: a cable drum and a cabinet to climb it), transformers
    with radiator fins, a steel gantry over them (its posts scurried up; its beam a runway: the top), insulators and
    lines; a lattice pylon outside the back fence (an unseen column in its legs) up to its crossarm."""
    rng = kit.rng
    w, d = rng.uniform(20.0, 26.0), rng.uniform(16.0, 20.0)
    hw, hd = w / 2, d / 2
    s = rng.choice([-1, 1])
    kit.box(-hw, 0.0, -hd, hw, 0.05, hd, "gravel")
    fence = 2.4
    for (ax, az), (bx, bz) in (((-hw, hd), (hw, hd)), ((hw, hd), (hw, -hd)), ((hw, -hd), (-hw, -hd)), ((-hw, -hd), (-hw, hd))):
        n = int(math.dist((ax, az), (bx, bz)) / 2.5)
        for k in range(n + 1):
            t = k / n
            kit.cylinder(ax + (bx - ax) * t, 0.0, az + (bz - az) * t, 0.05, fence, "chainlink", 6, "see")
        kit.bar((ax, fence, az), (bx, fence, bz), 0.05, "chainlink", "see")
        kit.face([(ax, 0.05, az), (bx, 0.05, bz), (bx, fence - 0.05, bz), (ax, fence - 0.05, az)], "chainlink", 0.9, "see")
        kit.face([(ax, 0.0, az), (bx, 0.0, bz), (bx, fence + 0.6, bz), (ax, fence + 0.6, az)], "white", 1.0, "block")
    # The control hut straddling the front fence; a cable drum and a cabinet in front of it
    hx = s * (hw - 4.0)
    hut = 2.7
    kit.box(hx - 2.0, 0.0, hd - 2.5, hx + 2.0, hut, hd + 1.0, "concrete")
    kit.box(hx - 2.1, hut, hd - 2.6, hx + 2.1, hut + 0.12, hd + 1.1, "tar")
    kit.box(hx - 0.5, 0.0, hd + 1.0, hx + 0.5, 2.1, hd + 1.05, "door", "see")
    kit.box(hx - s * 1.0 - 0.45, 0.0, hd + 1.45, hx - s * 1.0 + 0.45, 1.6, hd + 2.25, "steel")
    kit.cylinder(hx - s * 1.0, 0.0, hd + 3.4, 0.6, 0.9, "wood", 10)
    kit.node("start", hx - s * 1.0, 0.0, hd + 5.5)
    kit.node("jump", hx - s * 1.0, 0.9, hd + 3.4)
    kit.node("jump", hx - s * 1.0, 1.6, hd + 1.85)
    kit.node("ledge", hx - s * 1.0, hut + 0.12, hd + 0.4)
    # Transformers, fins and bushings, a row a jump behind the hut
    gz = hd - 4.6
    tops = []
    for k in range(3):
        tx = -hw + 4.0 + k * (w - 8.0) / 2
        kit.box(tx - 1.2, 0.05, gz - 0.9, tx + 1.2, 2.4, gz + 0.9, "corrugated2")
        for j in range(6):
            kit.box(tx - 1.0 + j * 0.4, 0.4, gz + 0.9, tx - 0.95 + j * 0.4, 2.0, gz + 1.4, "corrugated2", "see")
        for j in (-0.6, 0.0, 0.6):
            kit.cylinder(tx + j, 2.4, gz - 0.4, 0.08, 0.9, "insulator", 6, "see")
        tops.append(tx)
    # The gantry: posts at the yard's ends, a beam over the transformers
    beam = 6.0
    for x in (-hw + 1.0, hw - 1.0):
        kit.bar((x, 0.0, gz), (x, beam, gz), 0.35, "steel")
    kit.box(-hw + 0.8, beam, gz - 0.3, hw - 0.8, beam + 0.3, gz + 0.3, "steel")
    for k in range(5):
        x = -hw + 3.0 + k * (w - 6.0) / 4
        kit.cylinder(x, beam - 1.2, gz, 0.07, 1.2, "insulator", 6, "see")
        kit.bar((x, beam - 1.2, gz), (x, 3.3, gz - 0.4), 0.03, "black", "see")
    # (off the hut's back onto the nearest transformer, across to the post at its end, up it, along the beam)
    near = tops[-1] if s > 0 else tops[0]
    kit.node("walk", hx, hut + 0.12, hd - 2.25)
    kit.node("jump", near, 2.4, gz + 0.45)
    post = s * (hw - 1.0)
    kit.column([(post, 0.0, gz), (post, beam + 0.35, gz)], 0.35)
    kit.node("walk", post, 0.05, gz + 1.2)
    kit.node("climb", post - s * 0.5, beam + 0.3, gz)
    kit.node("walk", 0.0, beam + 0.3, gz)
    # The pylon outside the back fence
    px, pz = 0.0, -hd - 6.0
    base, waist, arm = 2.6, 1.0, 20.0
    for sx in (-1, 1):
        for sz in (-1, 1):
            kit.bar((px + sx * base, 0.0, pz + sz * base), (px + sx * waist, arm, pz + sz * waist), 0.16, "steel", "see")
    y = 0.0
    while y < arm - 1.0:
        r0 = base + (waist - base) * y / arm
        r1 = base + (waist - base) * min(1.0, (y + 2.5) / arm)
        for sx in (-1, 1):
            kit.bar((px + sx * r0, y, pz - r0), (px - sx * r1, y + 2.5, pz - r1), 0.06, "steel", "see")
            kit.bar((px + sx * r0, y, pz + r0), (px - sx * r1, y + 2.5, pz + r1), 0.06, "steel", "see")
        y += 2.5
    kit.box(px - 5.0, arm, pz - 0.35, px + 5.0, arm + 0.3, pz + 0.35, "steel")
    for x in (-4.5, 0.0, 4.5):
        kit.cylinder(px + x, arm - 1.4, pz, 0.12, 1.4, "insulator", 6, "see")
    kit.column([(px, 0.0, pz + base + 0.1), (px, arm * 0.5, pz + (base + waist) / 2 + 0.1), (px, arm + 0.3, pz + waist + 0.3)], 0.4)
    return kit


def culvert(kit):
    """A sewer outfall: a concrete headwall in a bank, a big round culvert pipe through it (walked into: a floor along
    its bottom, its tube solid, a grate at its far end), an open concrete channel running away from it between two
    berms (their sloped concrete sides run down into it and up out of it), a side drain's grate, rungs up the headwall
    beside the pipe (a ladder) to the top of the bank, a manhole there. All of it on or over the ground at y."""
    rng = kit.rng
    bank = rng.uniform(4.0, 5.0)
    hw = rng.uniform(5.0, 7.0)
    r = 1.2
    s = rng.choice([-1, 1])
    open_r = r + 0.3
    # The bank behind, built round the tunnel the pipe runs in
    back = -12.0
    kit.box(-hw - 6.0, 0.0, back, -open_r, bank, -0.6, "dirt", top="grass")
    kit.box(open_r, 0.0, back, hw + 6.0, bank, -0.6, "dirt", top="grass")
    kit.box(-open_r, 2 * r + 0.3, back, open_r, bank, -0.6, "dirt", top="grass")
    # The headwall round the pipe's mouth, its cap
    kit.box(-hw, 0.0, -0.6, -open_r, bank + 0.4, 0.0, "concrete")
    kit.box(open_r, 0.0, -0.6, hw, bank + 0.4, 0.0, "concrete")
    kit.box(-open_r, 2 * r + 0.3, -0.6, open_r, bank + 0.4, 0.0, "concrete")
    kit.box(-hw - 0.2, bank + 0.4, -0.7, hw + 0.2, bank + 0.6, 0.1, "concrete")
    # The pipe: a solid tube back into the bank, a floor along its bottom, a grate at the far end
    sides = 12
    ring = [(math.cos(math.tau * i / sides) * r, math.sin(math.tau * i / sides) * r + r) for i in range(sides)]
    length_in = back + 0.5
    for i in range(sides):
        (a, b), (c, e) = ring[i], ring[(i + 1) % sides]
        kit.face([(a, b, 0.3), (c, e, 0.3), (c, e, length_in), (a, b, length_in)], "concrete", 0.85)
    kit.box(-0.7, 0.0, length_in, 0.7, 0.12, 0.3, "concrete")
    for k in range(7):
        x = -r + (k + 0.5) * 2 * r / 7
        kit.bar((x, 0.0, length_in + 0.3), (x, 2 * r, length_in + 0.3), 0.05, "black")
    # The channel: a floor at the ground, sloped sides up to the berms' tops, the berms' backs down to the ground
    length = 14.0
    floor_half, berm_in, berm_top, berm_out, berm_y = 2.5, 4.0, 5.0, 6.2, 1.0
    kit.box(-floor_half, 0.0, 0.0, floor_half, 0.02, length, "concrete")
    kit.box(-0.6, 0.02, 0.3, 0.6, 0.03, length, "sewage", "see")
    for sx in (-1, 1):
        kit.slab([(sx * floor_half, 0.0), (sx * berm_in, 0.0), (sx * berm_in, length), (sx * floor_half, length)], [0.0, berm_y, berm_y, 0.0], 0.3, "concrete")
        kit.slab([(sx * berm_in, 0.0), (sx * berm_top, 0.0), (sx * berm_top, length), (sx * berm_in, length)], [berm_y, berm_y, berm_y, berm_y], 0.3, "grass")
        kit.slab([(sx * berm_top, 0.0), (sx * berm_out, 0.0), (sx * berm_out, length), (sx * berm_top, length)], [berm_y, 0.0, 0.0, berm_y], 0.3, "dirt")
    kit.box(s * 3.2 - 0.4, 0.5, length - 3.0, s * 3.2 + 0.4, 0.55, length - 2.2, "black", "see")
    # Rungs up the headwall beside the pipe, the manhole on the bank
    lx = s * (open_r + 0.6)
    kit.ladder(lx, 0.0, 0.05, bank + 0.6, 0.0)
    kit.cylinder(-s * 3.0, bank, -4.0, 0.45, 0.06, "black", 10)
    kit.node("start", s * (berm_out + 1.5), 0.0, length - 2.0)
    kit.node("slope", s * (berm_top - 0.4), berm_y, length - 2.0)
    kit.node("slope", s * 1.5, 0.0, length - 3.5)
    kit.node("walk", 0.0, 0.12, -1.0)
    kit.node("walk", 0.0, 0.12, length_in + 1.5)
    kit.node("walk", 0.0, 0.12, 0.8)
    kit.node("walk", lx, 0.0, 0.9)
    kit.node("ladder", lx, bank + 0.6, -0.9)
    kit.node("walk", -s * 3.0, bank + 0.06, -4.0)
    return kit


# ======================================================================================================================

KINDS = {
    "craftsman": lambda kit: house(kit, "craftsman"),
    "box": lambda kit: house(kit, "box"),
    "farmhouse": lambda kit: house(kit, "farmhouse"),
    "aframe": lambda kit: house(kit, "aframe"),
    "walkup": walkup,
    "commercial": commercial,
    "construction": construction,
    "factory": factory,
    "warehouse": warehouse,
    "substation": substation,
    "culvert": culvert,
}

# Which kinds suit which zone (the user, 2026-11-02: "one of the zones should be a neighborhood under construction, one
# a more rural suburb vibe, one more commercial and city like, and one zone needs to be sewers substations factories
# and warehouses")
ZONES = {
    "construction": ["construction", "construction", "box", "craftsman"],
    "suburb": ["craftsman", "farmhouse", "aframe", "box"],
    "commercial": ["commercial", "walkup", "commercial", "box"],
    "industrial": ["factory", "warehouse", "substation", "culvert"],
}


def make(kind, name, x, y, z, turn=0.0, seed=0, marks=True, crumbs=6):
    """Builds one `kind` called `name` with its frame's origin at (x, y, z) turned `turn` about Y. Returns the dict
    described at the top."""
    kit = Kit(name, Site(x, y, z, turn), seed)
    KINDS[kind](kit)
    return kit.done(marks, crumbs)


def route_marks(made, prefix="route"):
    """Marks a made building's route as empties (route_<name>_<i>_<how>), for tests/building_routes.gd."""
    for i, (how, at) in enumerate(made["route"]):
        w1.mark("%s_%s_%02d_%s" % (prefix, made["name"], i, how), at)
