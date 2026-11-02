"""The town's vehicles (the user, 2026-11-02: "the roads should be wider, the cars bigger and faster" / "and there
should be different types, buses etc"). Japanese-town kinds in the game's toon look, at real sizes (he is about
0.6 m tall upright; a family car is about 4 m long and 1.5 m high). Which kinds, their looks and colours are
Claude's picks (placeholders):

    hatchback  a rounded family hatchback (its "paint" tinted in the game)
    taxi       a boxy saloon with a lit sign on the roof
    kei_truck  a little cab-over pickup with a flat bed and drop sides
    kei_van    a little tall box van
    bus        a city bus, two-tone, with a window band, doors, a lit route sign

Each is a body and its wheels, its own objects (named <kind>_wheel_<fl|fr|rl|rr...>, their origins at the axle), so
the game can turn them. Godot axes in the code: Y up, +Z ahead, the ground at y 0.

Run from the project root:
    blender -b --factory-startup --python tools/build_vehicles.py [-- <folder>]   # the folder gets five views of each

Writes models/vehicle_<kind>.glb and tools/vehicles.blend.
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PREVIEW_DIR = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1 else None

COLOURS = {
    "paint": (0.85, 0.22, 0.18),
    "paint2": (0.93, 0.9, 0.8),
    # (not "glass": DayNight lights the town's "glass" at night, as house windows)
    "carglass": (0.3, 0.42, 0.52),
    "chrome": (0.78, 0.8, 0.84),
    "trim": (0.16, 0.16, 0.18),
    "tyre": (0.1, 0.1, 0.11),
    "hub": (0.7, 0.72, 0.75),
    "lamp": (1.0, 0.95, 0.7),
    "tail": (0.85, 0.1, 0.1),
    "amber": (0.98, 0.62, 0.12),
    "sign": (0.98, 0.93, 0.55),
    "bed": (0.55, 0.55, 0.57),
    "plate": (0.95, 0.95, 0.9),
    "lining": (0.2, 0.2, 0.22),
    "seat": (0.3, 0.27, 0.25),
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


class Part:
    """One object being made, in Godot axes relative to `origin` (where its joint is)."""

    def __init__(self, name, origin=(0.0, 0.0, 0.0)):
        self.name = name
        self.origin = Vector(origin)
        self.bm = bmesh.new()
        self.mats = []

    def _index(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def _v(self, p):
        return self.bm.verts.new(to_blender(Vector(p) - self.origin))

    def face(self, points, mat):
        f = self.bm.faces.new([self._v(p) for p in points])
        f.material_index = self._index(mat)
        return f

    def box(self, centre, size, mat):
        cx, cy, cz = centre
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        c = [(cx + sx * hx, cy + sy * hy, cz + sz * hz) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
        for q in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
            self.face([c[i] for i in q], mat)

    def shell(self, profile, half_width, belt, top, paint, glass, pillars=()):
        """A side profile [(z, y), ...] (going round, front to back over the top) extruded across ±half_width, as a
        body you can see into (the user, 2026-11-02: "there should be people in the cars"): painted below `belt`,
        glass from there up to `top` (the windows all round: the windscreen, the sides, the back; its nearly level
        faces, the roof, painted), painted again above `top`. No faces where the pieces meet, so it is one shell. A
        painted rail round the glass's edges at each side, and a pillar up through it at each z in `pillars`.
        Returns the pieces' outlines, for the lining."""
        pieces = [(clip(profile, belt, True), False), (clip(clip(profile, belt, False), top, True), True),
                  (clip(profile, top, False), False)]
        for outline, is_glass in pieces:
            if len(outline) < 3:
                continue
            left = [(half_width, y, z) for z, y in outline]
            right = [(-half_width, y, z) for z, y in outline]
            self.face(left, glass if is_glass else paint)
            self.face(right[::-1], glass if is_glass else paint)
            n = len(outline)
            for i in range(n):
                j = (i + 1) % n
                (za, ya), (zb, yb) = outline[i], outline[j]
                # (none along a cut: the pieces join there)
                if any(abs(ya - cut) < 1e-4 and abs(yb - cut) < 1e-4 for cut in (belt, top)):
                    continue
                level = abs(yb - ya) < 0.35 * abs(zb - za)
                self.face([left[i], right[i], right[j], left[j]], paint if (level or not is_glass) else glass)
                if is_glass:
                    for side in (1, -1):
                        self.tube([(side * half_width, ya, za), (side * half_width, yb, zb)], [0.03, 0.03], paint, 5)
            if is_glass:
                for z in pillars:
                    high = band_top(outline, z)
                    for side in (1, -1):
                        self.box((side * half_width, (belt + high) / 2, z), (0.03, high - belt, 0.1), paint)
        return [outline for outline, _ in pieces]

    def tube(self, points, radii, mat, segments=10):
        index = self._index(mat)
        rings = []
        for i, point in enumerate(points):
            point = Vector(point)
            ahead = (Vector(points[min(i + 1, len(points) - 1)]) - Vector(points[max(i - 1, 0)])).normalized()
            u = ahead.cross(Vector((0, 1, 0)) if abs(ahead.y) < 0.9 else Vector((1, 0, 0))).normalized()
            w = ahead.cross(u)
            rings.append([self._v(point + (u * math.cos(a) + w * math.sin(a)) * radii[i])
                          for a in (math.tau * k / segments for k in range(segments))])
        for a, b in zip(rings, rings[1:]):
            for k in range(segments):
                self.bm.faces.new((a[k], a[(k + 1) % segments], b[(k + 1) % segments], b[k])).material_index = index
        for ring in (rings[0], rings[-1][::-1]):
            self.bm.faces.new(ring[::-1]).material_index = index

    def done(self, inward=False):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts[:], dist=0.0002)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces[:])
        if inward:
            bmesh.ops.reverse_faces(self.bm, faces=self.bm.faces[:])
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for name in self.mats:
            mesh.materials.append(material(name))
        obj = bpy.data.objects.new(self.name, mesh)
        obj.location = to_blender(self.origin)
        bpy.context.collection.objects.link(obj)
        return obj


def clip(outline, cut, below):
    """The part of a closed outline [(z, y), ...] below (or above) the height `cut`."""
    out = []
    n = len(outline)
    for i in range(n):
        a, b = outline[i], outline[(i + 1) % n]
        a_in = a[1] <= cut + 1e-6 if below else a[1] >= cut - 1e-6
        b_in = b[1] <= cut + 1e-6 if below else b[1] >= cut - 1e-6
        if a_in:
            out.append(a)
        if a_in != b_in:
            t = (cut - a[1]) / (b[1] - a[1])
            out.append((a[0] + (b[0] - a[0]) * t, cut))
    # (no point twice in a row)
    kept = []
    for p in out:
        if not kept or abs(p[0] - kept[-1][0]) > 1e-5 or abs(p[1] - kept[-1][1]) > 1e-5:
            kept.append(p)
    if len(kept) > 1 and abs(kept[0][0] - kept[-1][0]) < 1e-5 and abs(kept[0][1] - kept[-1][1]) < 1e-5:
        kept.pop()
    return kept


def band_top(outline, z):
    """How high an outline reaches at `z`."""
    best = -1e9
    n = len(outline)
    for i in range(n):
        (za, ya), (zb, yb) = outline[i], outline[(i + 1) % n]
        if min(za, zb) - 1e-6 <= z <= max(za, zb) + 1e-6 and abs(zb - za) > 1e-6:
            best = max(best, ya + (yb - ya) * (z - za) / (zb - za))
    return best


def lining(kind, made, outlines, half_width, belt, top):
    """The inside of the body, seen through its windows: its painted pieces again a little inside it, facing in, in a
    dark lining (the floor, the walls below the windows, the roof)."""
    inside = Part("%s_lining" % kind)
    w = half_width - 0.025
    for k, outline in enumerate(outlines):
        if len(outline) < 3:
            continue
        cz = sum(p[0] for p in outline) / len(outline)
        cy = sum(p[1] for p in outline) / len(outline)
        span_z = max(p[0] for p in outline) - min(p[0] for p in outline)
        span_y = max(p[1] for p in outline) - min(p[1] for p in outline)
        sz = 1.0 - 0.05 / max(span_z, 0.1)
        sy = 1.0 - 0.05 / max(span_y, 0.1)
        shrunk = [(cz + (z - cz) * sz, cy + (y - cy) * sy) for z, y in outline]
        is_band = k == 1
        n = len(shrunk)
        if not is_band:
            inside.face([(w, y, z) for z, y in shrunk], "lining")
            inside.face([(-w, y, z) for z, y in shrunk][::-1], "lining")
        for i in range(n):
            j = (i + 1) % n
            (za, ya), (zb, yb) = outline[i], outline[(i + 1) % n]
            if any(abs(ya - cut) < 1e-4 and abs(yb - cut) < 1e-4 for cut in (belt, top)):
                continue
            if is_band and abs(yb - ya) >= 0.35 * abs(zb - za):
                continue
            (qa, ra), (qb, rb) = shrunk[i], shrunk[j]
            inside.face([(w, ra, qa), (-w, ra, qa), (-w, rb, qb), (w, rb, qb)], "lining")
    made.append(inside.done(inward=True))


def seats(kind, made, seats_at):
    """A seat at each: a cushion under the sitter and a back leant back behind them."""
    chairs = Part("%s_seats" % kind)
    for x, y, z in seats_at:
        chairs.box((x, y - 0.06, z + 0.04), (0.46, 0.12, 0.46), "seat")
        # (the back: from behind the hips, clear of their hair, leant back 0.2 rad, 0.62 high, 0.1 thick)
        lean = 0.2
        up = Vector((0.0, math.cos(lean), -math.sin(lean)))
        back = Vector((0.0, math.sin(lean), math.cos(lean)))
        foot = Vector((x, y - 0.02, z - 0.24))
        corners = []
        for sx in (-0.23, 0.23):
            for h in (0.0, 0.62):
                for d in (0.0, -0.1):
                    corners.append(tuple(foot + Vector((sx, 0.0, 0.0)) + up * h + back * d))
        for q in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
            chairs.face([corners[i] for i in q], "seat")
    made.append(chairs.done())


def wheels(kind, made, places, radius, width):
    """A wheel at each (x, z), its own object turning about its axle (the user, 2026-11-02: "more realistic wheels"):
    a tyre with rounded shoulders and a tread (its outer band darker grooves), a dished rim with five lug nuts and a
    centre cap on the outer face, and the dark inside of the wheel arch on the inner face."""
    for name, x, z in places:
        wheel = Part("%s_wheel_%s" % (kind, name), (x, radius, z))
        side = 1 if x > 0 else -1
        # The tyre: across its width, round at its shoulders
        across = [-0.5, -0.44, -0.3, 0.3, 0.44, 0.5]
        heights = [0.84, 0.96, 1.0, 1.0, 0.96, 0.84]
        wheel.tube([(x + side * width * a, radius, z) for a in across], [radius * h for h in heights], "tyre", 18)
        # Its tread: grooves round it, a little proud of the tyre
        for k in range(3):
            a = -0.22 + 0.22 * k
            wheel.tube([(x + side * width * (a - 0.035), radius, z), (x + side * width * (a + 0.035), radius, z)],
                       [radius * 1.008, radius * 1.008], "trim", 18)
        # The rim, dished in from the tyre's outer wall, and its centre cap
        face = x + side * (width * 0.5 + 0.004)
        wheel.tube([(face - side * 0.03, radius, z), (face, radius, z)], [radius * 0.66, radius * 0.66], "hub", 16)
        wheel.tube([(face, radius, z), (face + side * 0.012, radius, z)], [radius * 0.5, radius * 0.42], "chrome", 16)
        wheel.tube([(face + side * 0.012, radius, z), (face + side * 0.03, radius, z)], [radius * 0.17, radius * 0.12], "chrome", 10)
        # Five lug nuts round the cap
        for n in range(5):
            a = math.tau * n / 5
            ny, nz = math.cos(a) * radius * 0.28, math.sin(a) * radius * 0.28
            wheel.box((face + side * 0.016, radius + ny, z + nz), (0.016, radius * 0.07, radius * 0.07), "trim")
        # The inside: dark
        inner = x - side * (width * 0.5 + 0.002)
        wheel.tube([(inner, radius, z), (inner - side * 0.004, radius, z)], [radius * 0.8, radius * 0.8], "trim", 14)
        made.append(wheel.done())


def lamps(body, half_width, front_z, back_z, y, size=0.13):
    for side in (1, -1):
        body.box((side * (half_width - 0.22), y, front_z + 0.01), (size * 2.2, size, 0.04), "lamp")
        body.box((side * (half_width - 0.18), y, back_z - 0.01), (size * 1.6, size * 1.3, 0.04), "tail")
    body.box((0, y - 0.35, front_z + 0.02), (half_width * 1.7, 0.16, 0.08), "trim")
    body.box((0, y - 0.35, back_z - 0.02), (half_width * 1.7, 0.16, 0.08), "trim")
    body.box((0, y - 0.15, back_z - 0.03), (0.34, 0.16, 0.02), "plate")
    body.box((0, y - 0.15, front_z + 0.03), (0.34, 0.16, 0.02), "plate")


def cabin(kind, made, steer, seats_at):
    """Who sits where (the user, 2026-11-02: "there should be people in the cars"): an empty `<kind>_seat_<n>` at each
    seat, at the seat's surface under the sitter's hips (seat 0 the driver's: on the right, as in Japan), facing ahead;
    a steering wheel before the driver, round `steer`, its rim leant back towards them, and `<kind>_grip_l`/`_r` where
    the hands go on it (at ten to two)."""
    tilt = 0.5
    radius = 0.19 if kind != "bus" else 0.24
    cx, cy, cz = steer
    up = Vector((0.0, math.cos(tilt), -math.sin(tilt)))

    def rim_point(angle, r=radius):
        return (cx + math.cos(angle) * r, cy + up.y * math.sin(angle) * r, cz + up.z * math.sin(angle) * r)

    wheel = Part("%s_steer" % kind, steer)
    wheel.tube([rim_point(math.tau * k / 18) for k in range(19)], [0.017] * 19, "trim", 6)
    wheel.tube([rim_point(0.0, 0.02), rim_point(0.0, radius)], [0.012, 0.012], "trim", 5)
    wheel.tube([rim_point(math.pi, 0.02), rim_point(math.pi, radius)], [0.012, 0.012], "trim", 5)
    # (the column, down and forward into the dash)
    wheel.tube([steer, (cx, cy - 0.16, cz + 0.32)], [0.035, 0.03], "trim", 6)
    made.append(wheel.done())
    for name, angle in (("l", math.radians(30)), ("r", math.radians(150))):
        made.append(empty("%s_grip_%s" % (kind, name), rim_point(angle)))
    for n, at in enumerate(seats_at):
        made.append(empty("%s_seat_%d" % (kind, n), at))
    seats(kind, made, seats_at)


def empty(name, at):
    obj = bpy.data.objects.new(name, None)
    obj.location = to_blender(Vector(at))
    bpy.context.collection.objects.link(obj)
    return obj


def hatchback():
    made = []
    body = Part("hatchback_body")
    w = 0.85
    # From the front bumper, over the bonnet, up the windscreen, over the roof, down the hatch, back under
    profile = [(2.0, 0.3), (2.05, 0.62), (1.9, 0.85), (1.05, 0.95), (0.45, 1.42), (-0.9, 1.48), (-1.75, 1.3),
               (-1.98, 0.9), (-1.98, 0.3)]
    # (glass above the waist, all round; a pillar between the doors)
    outlines = body.shell(profile, w, 0.97, 9.0, "paint", "carglass", (-0.1,))
    lamps(body, w, 2.05, -1.98, 0.72)
    made.append(body.done())
    wheels("hatchback", made, (("fl", 0.78, 1.28), ("fr", -0.78, 1.28), ("rl", 0.78, -1.28), ("rr", -0.78, -1.28)), 0.33, 0.24)
    lining("hatchback", made, outlines, w, 0.97, 9.0)
    cabin("hatchback", made, (-0.36, 0.92, 0.36), [(-0.36, 0.46, -0.08), (0.36, 0.46, -0.08), (0.36, 0.46, -1.0), (-0.36, 0.46, -1.0)])
    return made


def taxi():
    made = []
    body = Part("taxi_body")
    w = 0.85
    profile = [(2.3, 0.3), (2.35, 0.75), (1.25, 0.88), (0.65, 1.42), (-0.85, 1.45), (-1.45, 0.95), (-2.3, 0.88),
               (-2.32, 0.3)]
    outlines = body.shell(profile, w, 0.92, 9.0, "paint", "carglass", (-0.05,))
    # The white band along each side, and the lit sign on the roof
    for side in (1, -1):
        body.box((side * (w + 0.005), 0.66, 0.0), (0.012, 0.1, 4.4), "paint2")
    body.box((0, 1.56, -0.05), (0.42, 0.2, 0.16), "sign")
    lamps(body, w, 2.35, -2.32, 0.7)
    made.append(body.done())
    wheels("taxi", made, (("fl", 0.78, 1.45), ("fr", -0.78, 1.45), ("rl", 0.78, -1.45), ("rr", -0.78, -1.45)), 0.33, 0.24)
    lining("taxi", made, outlines, w, 0.92, 9.0)
    cabin("taxi", made, (-0.36, 0.9, 0.66), [(-0.36, 0.43, 0.2), (0.36, 0.43, 0.2), (0.36, 0.43, -0.68), (-0.36, 0.43, -0.68)])
    return made


def kei_truck():
    made = []
    body = Part("kei_truck_body")
    w = 0.74
    # The cab over the front wheels, flat-fronted
    cab = [(1.7, 0.4), (1.72, 1.15), (1.55, 1.8), (0.6, 1.8), (0.6, 0.4)]
    outlines = body.shell(cab, w, 1.15, 1.72, "paint", "carglass")
    # The flat bed and its low drop sides, a frame under it
    body.box((0, 0.68, -0.55), (w * 2, 0.08, 2.3), "bed")
    for side in (1, -1):
        body.box((side * (w - 0.02), 0.88, -0.55), (0.04, 0.32, 2.3), "paint2")
    body.box((0, 0.88, -1.68), (w * 2, 0.32, 0.04), "paint2")
    body.box((0, 0.88, 0.58), (w * 2, 0.32, 0.04), "paint2")
    body.box((0, 0.45, -0.55), (w * 1.6, 0.4, 2.2), "trim")
    lamps(body, w, 1.72, -1.7, 0.62, 0.1)
    made.append(body.done())
    wheels("kei_truck", made, (("fl", 0.66, 1.15), ("fr", -0.66, 1.15), ("rl", 0.66, -1.05), ("rr", -0.66, -1.05)), 0.29, 0.2)
    lining("kei_truck", made, outlines, w, 1.15, 1.72)
    cabin("kei_truck", made, (-0.33, 1.18, 1.46), [(-0.33, 0.76, 1.0), (0.33, 0.76, 1.0)])
    return made


def kei_van():
    made = []
    body = Part("kei_van_body")
    w = 0.74
    profile = [(1.7, 0.35), (1.72, 1.0), (1.45, 1.85), (-1.68, 1.88), (-1.7, 0.35)]
    outlines = body.shell(profile, w, 1.1, 1.74, "paint", "carglass", (0.48, -0.68))
    # A sliding door's runner, a stripe
    for side in (1, -1):
        body.box((side * (w + 0.006), 0.8, -0.1), (0.012, 0.08, 3.3), "paint2")
    lamps(body, w, 1.72, -1.7, 0.6, 0.1)
    made.append(body.done())
    wheels("kei_van", made, (("fl", 0.66, 1.15), ("fr", -0.66, 1.15), ("rl", 0.66, -1.1), ("rr", -0.66, -1.1)), 0.29, 0.2)
    lining("kei_van", made, outlines, w, 1.1, 1.74)
    cabin("kei_van", made, (-0.33, 1.12, 1.3), [(-0.33, 0.72, 0.85), (0.33, 0.72, 0.85), (0.33, 0.72, -0.25), (-0.33, 0.72, -0.25)])
    return made


def bus():
    made = []
    body = Part("bus_body")
    w = 1.25
    profile = [(5.25, 0.35), (5.3, 2.4), (5.05, 3.05), (-5.1, 3.05), (-5.25, 2.6), (-5.25, 0.35)]
    # (the window band all round; pillars between the side windows)
    outlines = body.shell(profile, w, 1.5, 2.55, "paint2", "carglass", [3.15 - k * 1.25 for k in range(7)])
    # The lower half in the colour, a stripe, the window band
    for side in (1, -1):
        x = side * (w + 0.006)
        quad = [(x, 0.36, 5.2), (x, 1.15, 5.2), (x, 1.15, -5.2), (x, 0.36, -5.2)]
        body.face(quad if side < 0 else quad[::-1], "paint")
    # The doors on the kerb side (left, +X, as Japan drives on the left), and the lit route sign over the screen
    for zf, zb in ((4.95, 4.05), (0.6, -0.3)):
        quad = [(w + 0.012, 0.36, zf), (w + 0.012, 2.5, zf), (w + 0.012, 2.5, zb), (w + 0.012, 0.36, zb)]
        body.face(quad[::-1], "carglass")
    body.box((0, 2.72, 5.22), (1.9, 0.32, 0.12), "sign")
    body.box((w + 0.01, 2.75, 3.0), (0.03, 0.26, 1.6), "sign")
    lamps(body, w, 5.3, -5.25, 0.75, 0.15)
    made.append(body.done())
    wheels("bus", made, (("fl", 1.14, 3.4), ("fr", -1.14, 3.4), ("rl", 1.14, -2.9), ("rr", -1.14, -2.9)), 0.48, 0.3)
    lining("bus", made, outlines, w, 1.5, 2.55)
    # (the riders sit along the windows, clear of the doors on the left)
    riders = [(-0.75, 0.9, 4.25)] + [(side * 0.75, 0.9, z) for z in (2.6, 1.4, -0.9, -2.1, -3.3, -4.3) for side in (1, -1)]
    cabin("bus", made, (-0.75, 1.4, 4.78), riders)
    return made


def export(name, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT, "models", "vehicle_%s.glb" % name), export_format="GLB",
                              export_yup=True, use_selection=True, export_animations=False)
    print("BUILT %s tris=%d" % (name, sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objects if o.type == "MESH")))


def look(folder, name, objects):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.render.resolution_x, scene.render.resolution_y = 500, 500
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.35, 0.42, 0.5)
    camera = scene.camera
    if camera is None:
        camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
        camera.data.type = "ORTHO"
        scene.collection.objects.link(camera)
        scene.camera = camera
    for other in bpy.data.objects:
        if other.type == "MESH":
            other.hide_render = other not in objects
    corners = [o.matrix_world @ Vector(c) for o in objects if o.type == "MESH" for c in o.bound_box]
    lo = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    hi = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    middle = (lo + hi) / 2
    size = max(hi - lo) * 1.2
    # (Blender axes: -Y is ahead)
    for view, direction in (("front", (0, -1, 0.15)), ("side", (1, 0, 0.15)), ("back", (0, 1, 0.15)), ("top", (0.01, 0, 1)),
                            ("quarter", (0.7, -0.7, 0.4))):
        offset = Vector(direction).normalized() * 30.0
        camera.data.ortho_scale = size
        camera.location = middle + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


bpy.ops.wm.read_factory_settings(use_empty=True)
models = {
    "hatchback": hatchback(),
    "taxi": taxi(),
    "kei_truck": kei_truck(),
    "kei_van": kei_van(),
    "bus": bus(),
}
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "tools", "vehicles.blend"))
for name, objects in models.items():
    export(name, objects)
if PREVIEW_DIR:
    for name, objects in models.items():
        look(PREVIEW_DIR, name, objects)
