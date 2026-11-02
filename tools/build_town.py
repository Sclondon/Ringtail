"""World 1, the town: a little grove on a hill in the middle of a town (the user, 2026-11-01: "The map should be a
little grove on a hill in the center of town"), with a road round it that cars drive, pavements people walk,
houses and shops round that, power poles with wires, trash cans. The layout and what goes where are Claude's.

Run from the project root:
    blender -b --factory-startup --python tools/build_town.py [-- <folder>]   # the folder gets pictures of it

Writes models/world1.glb (the game's World 1) and tools/town.blend. Built on tools/build_world1.py's Piece and
markers (textures by material name, texture coordinates in metres, vertex shading), and its marker names
(see its docstring), plus:

    tree_<n>_<seed>_<size%>     a climbable tree of the grove (scripts/world.gd grows it)
    road_<loop>_<i>             a road loop's centre line, in order (cars: scripts/hazards.gd)
    walk_<route>_<i>            a path people walk there and back
    hawk_<n>, crows_<n>, den_<n> where the hawk circles, a band of crows hangs about, the fox lives

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

HILL_TOP = 7.0          # the plateau's height
PLATEAU = 9.0           # its radius
HILL_FOOT = 24.0        # where the hill meets the flat
ROAD = (26.0, 33.0)     # the ring road, inner and outer edge
ROAD_MIDDLE = 29.5
PAVE = 2.4              # the pavements either side of it
TOWN = (37.5, 52.0)     # where the buildings stand
EDGE = 60.0             # the walls round it all
POOL = (3.5, -2.5)      # a pond on top of the hill
POOL_RADII = (2.6, 2.0)


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


def path_distance(x, z):
    """How far (x, z) is from the path that winds up the hill (a spiral from the south foot to the top)."""
    best = 99.0
    for k in range(80):
        t = k / 79.0
        a = math.pi * 0.5 + t * math.tau * 0.95
        r = HILL_FOOT - (HILL_FOOT - PLATEAU + 1.0) * t
        best = min(best, math.hypot(x - math.cos(a) * r, z - math.sin(a) * r))
    return best


def ground():
    piece = w1.Piece("ground")
    step = 1.0
    span = int(EDGE * 2 / step)
    heights = {}

    def h(i, j):
        if (i, j) not in heights:
            heights[(i, j)] = hill_height(-EDGE + i * step, -EDGE + j * step)
        return heights[(i, j)]

    for i in range(span):
        for j in range(span):
            xa, za = -EDGE + i * step, -EDGE + j * step
            xb, zb = xa + step, za + step
            xm, zm = xa + step / 2, za + step / 2
            r = math.hypot(xm, zm)
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
    # Walls round the town, too high to get over
    for k in range(24):
        a0, a1 = math.tau * k / 24, math.tau * (k + 1) / 24
        p0 = (math.cos(a0) * EDGE * 0.98, math.sin(a0) * EDGE * 0.98)
        p1 = (math.cos(a1) * EDGE * 0.98, math.sin(a1) * EDGE * 0.98)
        mid = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2)
        length = math.dist(p0, p1) + 0.6
        turn = math.atan2(p1[1] - p0[1], p1[0] - p0[0])
        building = w1.Piece("wall_%d" % k)
        _block(building, mid, turn, (length, 9.0, 1.0), "brick")
        building.done()
    return piece.done()


def _rot(local, at, turn):
    """A point in a thing's own space (x along it, z out from it) put in the world at `at` turned by `turn`."""
    c, s = math.cos(turn), math.sin(turn)
    return (at[0] + local[0] * c - local[2] * s, local[1], at[1] + local[0] * s + local[2] * c)


def _block(piece, at, turn, size, mat, top=None, base=0.0):
    hx, hy, hz = size[0] / 2, size[1], size[2] / 2
    c = [_rot((sx * hx, base + (hy if sy > 0 else 0.0), sz * hz), at, turn) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    quads = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    for k, q in enumerate(quads):
        piece.face([c[i] for i in q], top if (top and k == 3) else mat, 1.08 if k == 3 else 0.86 if k in (0, 1) else 0.95)


def buildings():
    """Houses and shops round the road, facing it, with gaps between them to slip through, roofs to run over."""
    kinds = [
        # (width, depth, eave, ridge or 0 for flat, siding, roof)
        (10.0, 8.0, 4.2, 6.2, "siding", "roof"), (12.0, 9.0, 5.5, 0.0, "brick", "roof2"), (9.0, 8.0, 3.8, 5.8, "siding3", "roof"),
        (11.0, 9.0, 6.5, 8.6, "siding2", "roof2"), (8.0, 8.0, 4.0, 0.0, "brick", "roof"), (10.0, 8.0, 5.0, 7.0, "siding", "roof2"),
        (13.0, 10.0, 4.6, 0.0, "siding2", "roof"), (9.0, 8.0, 4.4, 6.4, "brick", "roof2"), (11.0, 8.0, 5.2, 7.4, "siding3", "roof"),
        (10.0, 9.0, 4.0, 0.0, "siding", "roof2"),
    ]
    count = len(kinds)
    tallest = max(range(count), key=lambda k: kinds[k][2])
    for k, (width, depth, eave, ridge, siding, roof) in enumerate(kinds):
        a = math.tau * (k + 0.5) / count
        r = TOWN[0] + depth / 2
        at = (math.cos(a) * r, math.sin(a) * r)
        turn = a + math.pi / 2   # its x along the road, its z out from the town's middle
        piece = w1.Piece("building_%d" % k)
        _block(piece, at, turn, (width, eave, depth), siding)
        if ridge > 0.0:
            # a gable roof, ridge along the road
            over = 0.4
            for zs in (-1, 1):
                lo, hi = (-width / 2 - over, eave - 0.2, zs * (depth / 2 + over)), (width / 2 + over, eave - 0.2, zs * (depth / 2 + over))
                rl, rh = (-width / 2 - over, ridge, 0.0), (width / 2 + over, ridge, 0.0)
                quad = [lo, hi, rh, rl] if zs > 0 else [hi, lo, rl, rh]
                piece.face([_rot(p, at, turn) for p in quad], roof, 1.05)
            for xs in (-1, 1):
                tri = [(xs * width / 2, eave, -depth / 2), (xs * width / 2, eave, depth / 2), (xs * width / 2, ridge, 0.0)]
                piece.face([_rot(p, at, turn) for p in (tri if xs > 0 else tri[::-1])], siding)
            w1.crumb_line(_rot((-width / 2 + 1.0, ridge + 0.45, 0.0), at, turn), _rot((width / 2 - 1.0, ridge + 0.45, 0.0), at, turn), 4)
        else:
            # a flat roof with a low wall round it, and an awning over the shop window
            _block(piece, at, turn, (width + 0.3, 0.5, depth + 0.3), "concrete", base=eave)
            _block(piece, (at[0], at[1]), turn, (width - 0.6, 0.12, depth - 0.6), "roof", base=eave + 0.42)
            w1.crumb_line(_rot((-width / 2 + 1.5, eave + 1.0, 0.0), at, turn), _rot((width / 2 - 1.5, eave + 1.0, 0.0), at, turn), 4)
        # Windows lit from inside, a door, on the side to the road (its -z)
        for wx in (-width * 0.3, width * 0.3):
            for wy in ([1.6] + ([eave - 1.4] if eave > 4.5 else [])):
                _block(piece, _xz(_rot((wx, 0.0, -depth / 2 - 0.05), at, turn)), turn, (1.3, 1.1, 0.12), "window", base=wy - 0.55)
        _block(piece, _xz(_rot((0.0, 0.0, -depth / 2 - 0.06), at, turn)), turn, (1.1, 2.1, 0.14), "door")
        if ridge <= 0.0:
            _block(piece, _xz(_rot((0.0, 0.0, -depth / 2 - 0.9), at, turn)), turn, (width * 0.8, 0.12, 1.8), "red", base=2.7)
        # Crates by the side to get up
        _block(piece, _xz(_rot((width / 2 + 0.7, 0.0, -depth / 2 + 1.0), at, turn)), turn, (1.0, 1.0, 1.0), "wood")
        _block(piece, _xz(_rot((width / 2 + 0.7, 0.0, -depth / 2 + 2.1), at, turn)), turn, (1.0, 1.9, 1.0), "wood")
        if k == tallest:
            # The chimney on the tallest house, with its Bottlecap
            top = ridge + 1.5
            _block(piece, _xz(_rot((width * 0.25, 0.0, 0.0), at, turn)), turn, (1.2, 2.7, 1.2), "brick", base=top - 2.7)
            _block(piece, _xz(_rot((width * 0.25, 0.0, 0.0), at, turn)), turn, (1.4, 0.2, 1.4), "concrete", base=top)
            w1.mark("cap_roof", _rot((width * 0.25, top + 0.45, 0.0), at, turn))
        # Trash cans by the shop doors and at the gaps
        for dx in (width / 2 - 0.8, width / 2 - 1.6):
            w1.can(_rot((dx, 0.0, -depth / 2 - 0.8), at, turn))
        piece.done()
    return tallest


def _xz(p):
    return (p[0], p[2])


def poles_and_wires():
    """Power poles round the outer pavement, the phone line strung from each to the next (wires he walks)."""
    poles = w1.Piece("climb_poles")
    things = w1.Piece("pole_things")
    count = 10
    r = ROAD[1] + 1.2
    tops = []
    for k in range(count):
        a = math.tau * k / count
        x, z = math.cos(a) * r, math.sin(a) * r
        poles.cylinder((x, 0.0, z), 0.18, 6.8, "pole", 8)
        _block(things, (x, z), a + math.pi / 2, (1.6, 0.14, 0.14), "darkwood", base=6.3)
        tops.append((x, 6.48, z))
    for k in range(count):
        w1.wire(tops[k], tops[(k + 1) % count], 4)
    poles.done()
    things.done()


def grove():
    """The climbable trees of the grove: one great tree on the top, others round the plateau and down the slope."""
    trees = [(-1.5, -1.0, 160), (6.0, 4.5, 110), (-6.5, 4.0, 115), (-4.0, -7.0, 120), (5.0, -7.5, 105),
             (13.0, 6.0, 95), (-14.0, -3.0, 100), (2.0, 15.5, 95), (-9.0, 13.0, 90), (16.0, -9.0, 100)]
    for k, (x, z, size) in enumerate(trees):
        w1.mark("tree_%d_%d_%d" % (k, 101 + k * 7, size), (x, hill_height(x, z) - 0.05, z))
    # The hollow log on the slope: crawl in for the hidden Bottlecap
    lx, lz = -12.0, 9.5
    ly = hill_height(lx, lz)
    log = w1.Piece("log")
    segs = 12
    turn = 0.6
    for i in range(segs):
        a0, a1 = math.tau * i / segs, math.tau * (i + 1) / segs
        for r0, r1 in ((0.62, 0.62), (0.5, 0.5)):
            pass
        outer = [(-1.6, ly + 0.62 + math.sin(a0) * 0.62, math.cos(a0) * 0.62), (1.6, ly + 0.62 + math.sin(a0) * 0.62, math.cos(a0) * 0.62),
                 (1.6, ly + 0.62 + math.sin(a1) * 0.62, math.cos(a1) * 0.62), (-1.6, ly + 0.62 + math.sin(a1) * 0.62, math.cos(a1) * 0.62)]
        inner = [(px, ly + 0.62 + (py - ly - 0.62) * 0.78, pz * 0.78) for px, py, pz in outer][::-1]
        log.face([_rot(p, (lx, lz), turn) for p in outer], "darkwood")
        log.face([_rot(p, (lx, lz), turn) for p in inner], "wood")
    log.done()
    w1.mark("cap_hidden", _rot((0.0, ly + 0.25, 0.0), (lx, lz), turn))
    # The pond on top
    w1.mark("pool", (POOL[0], HILL_TOP - 0.25, POOL[1]))
    w1.mark("pool_size", (POOL_RADII[0] * 2.0, 1.2, POOL_RADII[1] * 2.0))
    # Crumbs up the winding path
    for k in range(18):
        t = (k + 0.5) / 18
        a = math.pi * 0.5 + t * math.tau * 0.95
        r = HILL_FOOT - (HILL_FOOT - PLATEAU + 1.0) * t
        x, z = math.cos(a) * r, math.sin(a) * r
        w1.crumb((x, hill_height(x, z) + 0.35, z))


def markers(tallest):
    w1.mark("spawn", (0.0, 0.05, ROAD[1] + 1.2), math.pi)
    w1.mark("check_south", (0.0, 0.05, ROAD[1] + 1.2))
    w1.mark("check_top", (0.0, HILL_TOP + 0.1, 3.0))
    w1.mark("check_east", (ROAD[1] + 1.2, 0.05, 0.0))
    w1.mark("check_west", (-ROAD[1] - 1.2, 0.05, 0.0))
    # Cars round the ring road; people on the pavements, and up the path
    for i in range(24):
        a = math.tau * i / 24
        w1.mark("road_0_%d" % i, (math.cos(a) * ROAD_MIDDLE, 0.0, math.sin(a) * ROAD_MIDDLE))
    for i in range(13):
        a = math.tau * i / 24
        w1.mark("walk_0_%d" % i, (math.cos(a) * (ROAD[1] + 1.2), 0.0, math.sin(a) * (ROAD[1] + 1.2)))
        a2 = math.pi + math.tau * i / 24
        w1.mark("walk_1_%d" % i, (math.cos(a2) * (ROAD[0] - 1.2), 0.0, math.sin(a2) * (ROAD[0] - 1.2)))
    for i in range(10):
        t = i / 9 * 0.6
        a = math.pi * 0.5 + t * math.tau * 0.95
        r = HILL_FOOT - (HILL_FOOT - PLATEAU + 1.0) * t
        x, z = math.cos(a) * r, math.sin(a) * r
        w1.mark("walk_2_%d" % i, (x, hill_height(x, z), z))
    # The hawk over the hill, crows by the shops, the fox's den at the grove's edge
    w1.mark("hawk_0", (0.0, 0.0, 0.0))
    a = math.tau * 3.5 / 10
    w1.mark("crows_0", (math.cos(a) * (ROAD[1] + 2.5), 0.0, math.sin(a) * (ROAD[1] + 2.5)))
    a = math.tau * 8.5 / 10
    w1.mark("crows_1", (math.cos(a) * (ROAD[1] + 2.5), 0.0, math.sin(a) * (ROAD[1] + 2.5)))
    w1.mark("den_0", (17.0, hill_height(17.0, 4.0), 4.0))
    # Yard cats about the town
    for k, a in enumerate((0.7, 2.6, 4.4, 5.6)):
        r = ROAD[1] + 2.8
        w1.mark("cat_%d" % k, (math.cos(a) * r, 0.05, math.sin(a) * r))
    w1.mark("cap_cats", (0.0, HILL_TOP + 0.6, 0.0))
    # The billboard on a flat roof across from the great tree: glide to it from the tree top
    w1.mark("cap_glide", (0.0, 9.5, -TOWN[0] - 2.0))
    board = w1.Piece("billboard")
    _block(board, (0.0, -TOWN[0] - 2.0), 0.0, (4.0, 0.16, 1.6), "metal", base=9.2)
    for x in (-1.8, 1.8):
        _block(board, (x, -TOWN[0] - 2.6), 0.0, (0.14, 9.2, 0.14), "metal")
    _block(board, (0.0, -TOWN[0] - 2.8), 0.0, (4.6, 3.4, 0.2), "yellow", base=9.4)
    board.done()
    # The race: round the road and up the hill
    w1.mark("race_start", (-2.0, 0.05, ROAD[1] + 1.2))
    for k in range(8):
        a = math.pi * 0.5 + math.tau * (k + 1) / 9
        w1.mark("race_%d" % k, (math.cos(a) * ROAD_MIDDLE, 0.4, math.sin(a) * ROAD_MIDDLE))
    w1.mark("cap_race", (0.0, 0.6, ROAD[0] - 1.0))
    w1.mark("trampoline", (8.0, hill_height(8.0, 12.0) + 0.6, 12.0))
    # Crumbs round the road
    for k in range(20):
        a = math.tau * k / 20
        w1.crumb((math.cos(a) * (ROAD[0] - 1.2), 0.35, math.sin(a) * (ROAD[0] - 1.2)))


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    ground()
    tallest = buildings()
    poles_and_wires()
    grove()
    markers(tallest)
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
    scene.world.color = (0.35, 0.42, 0.5)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.clip_end = 500.0
    scene.collection.objects.link(camera)
    scene.camera = camera
    for view, at, target in (("above", (0.01, 150.0, 0.0), (0.0, 0.0, 0.0)), ("south", (-30.0, 30.0, 80.0), (0.0, 4.0, 0.0)),
                             ("street", (0.0, 3.0, 36.0), (0.0, 5.0, 0.0))):
        camera.location = w1.to_blender(at)
        direction = w1.to_blender(target) - w1.to_blender(at)
        camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "town_%s.png" % view)
        bpy.ops.render.render(write_still=True)


build()
if PREVIEW_DIR:
    look(PREVIEW_DIR)
