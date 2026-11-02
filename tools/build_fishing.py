"""Fishing's things (GameCommon godot/fishing): a rod that bends (shape key "bent"), its crank, a bobber, a fish's
shadow on the water, and the fish: lake fish (trout, perch, pike), sea fish (mackerel, red snapper, cod) and pond fish
(koi, golden koi, carp, bluegill, catfish). From Gloaming's tools/build_minigames.py (its fishing pieces, 2026-10-29);
the pond fish added for Ringtail's grove pond (2026-11-02).

Run from the game's root (where it is installed: tools/build_fishing.py):
    blender -b --factory-startup --python tools/build_fishing.py

Writes tools/fishing.blend and fishing/fishing.glb, each piece its own root under "fishing", back at the origin.
Each faces -y (in the game +z). Materials are plain colours by name (the game shades them: Toon.apply).
"""
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

COLOURS = {
    "wood": (0.36, 0.24, 0.15),
    "timber": (0.2, 0.14, 0.1),
    "planks": (0.48, 0.36, 0.24),
    "iron": (0.18, 0.18, 0.2),
    "cork": (0.62, 0.48, 0.3),
    "line": (0.85, 0.85, 0.8),
    "red": (0.62, 0.1, 0.08),
    "white": (0.9, 0.88, 0.82),
    "black": (0.08, 0.08, 0.09),
    "gold": (0.85, 0.66, 0.2),
    "blue": (0.15, 0.25, 0.5),
    "straw": (0.78, 0.66, 0.36),
    "sacking": (0.55, 0.45, 0.3),
    "canvas": (0.78, 0.72, 0.6),
    "stripe": (0.62, 0.12, 0.1),
    "shadow": (0.02, 0.04, 0.05),
    "trout": (0.45, 0.5, 0.38),
    "trout_belly": (0.86, 0.72, 0.6),
    "perch": (0.55, 0.58, 0.22),
    "perch_belly": (0.88, 0.85, 0.65),
    "pike": (0.32, 0.4, 0.22),
    "pike_belly": (0.85, 0.85, 0.7),
    "mackerel": (0.18, 0.38, 0.4),
    "mackerel_belly": (0.88, 0.9, 0.9),
    "snapper": (0.8, 0.28, 0.2),
    "snapper_belly": (0.95, 0.75, 0.65),
    "cod": (0.5, 0.45, 0.35),
    "cod_belly": (0.9, 0.88, 0.8),
    "fin": (0.3, 0.3, 0.28),
    "eye": (0.05, 0.05, 0.05),
    "koi": (0.92, 0.42, 0.12),
    "koi_belly": (0.95, 0.93, 0.88),
    "goldkoi": (0.95, 0.74, 0.18),
    "goldkoi_belly": (0.99, 0.9, 0.55),
    "carp": (0.46, 0.4, 0.22),
    "carp_belly": (0.85, 0.74, 0.45),
    "bluegill": (0.28, 0.38, 0.4),
    "bluegill_belly": (0.95, 0.62, 0.25),
    "catfish": (0.24, 0.23, 0.22),
    "catfish_belly": (0.78, 0.76, 0.7),
}


def material(name):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    c = COLOURS[name]
    bsdf.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1.0)
    bsdf.inputs["Roughness"].default_value = 1.0
    m.diffuse_color = (c[0], c[1], c[2], 1.0)
    return m


def to_object(bm, name, mat, parent=None):
    mesh = bpy.data.meshes.new(name)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(material(mat))
    if parent:
        obj.parent = parent
    return obj


def box(bm, centre, size, rot_z=0.0, rot_y=0.0, rot_x=0.0):
    m = (Matrix.Translation(Vector(centre)) @ Matrix.Rotation(rot_z, 4, "Z") @ Matrix.Rotation(rot_y, 4, "Y")
         @ Matrix.Rotation(rot_x, 4, "X") @ Matrix.Diagonal((size[0], size[1], size[2], 1.0)))
    bmesh.ops.create_cube(bm, size=1.0, matrix=m)


def hull(bm, points):
    verts = [bm.verts.new(p) for p in points]
    made = bmesh.ops.convex_hull(bm, input=verts, use_existing_faces=False)
    left = list({v for v in made["geom_interior"] + made["geom_unused"] if isinstance(v, bmesh.types.BMVert)})
    if left:
        bmesh.ops.delete(bm, geom=left, context="VERTS")


def tube(bm, points, radii, sides=6):
    points = [Vector(p) for p in points]
    rings = []
    u = None
    for i, p in enumerate(points):
        d = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        if u is None:
            up = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
            u = d.cross(up).normalized()
        else:
            u = (u - d * u.dot(d)).normalized()
        v = d.cross(u).normalized()
        r = radii[i]
        if r <= 0.001:
            rings.append([bm.verts.new(p)])
        else:
            rings.append([bm.verts.new(p + (u * math.cos(math.tau * k / sides) + v * math.sin(math.tau * k / sides)) * r)
                          for k in range(sides)])
    for a, b in zip(rings, rings[1:]):
        if len(b) == 1:
            for k in range(sides):
                bm.faces.new((a[k], a[(k + 1) % sides], b[0]))
        elif len(a) == 1:
            for k in range(sides):
                bm.faces.new((a[0], b[(k + 1) % sides], b[k]))
        else:
            for k in range(sides):
                n = (k + 1) % sides
                bm.faces.new((a[k], a[n], b[n], b[k]))
    if len(rings[0]) > 1:
        bm.faces.new(tuple(reversed(rings[0])))
    if len(rings[-1]) > 1:
        bm.faces.new(tuple(rings[-1]))


def cylinder(bm, r0, r1, z0, z1, segs, at=(0.0, 0.0)):
    m = Matrix.Translation((at[0], at[1], (z0 + z1) * 0.5))
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r0, radius2=r1, depth=z1 - z0, matrix=m)


def disc(bm, centre, radius, thick, segs, facing_y=True):
    """A flat round disc, its faces towards -y and +y (or up, facing_y False)."""
    m = Matrix.Translation(Vector(centre))
    if facing_y:
        m = m @ Matrix.Rotation(math.pi * 0.5, 4, "X")
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=radius, radius2=radius, depth=thick, matrix=m)


class Parts:
    def __init__(self, name):
        self.name = name
        self.root = bpy.data.objects.new(name, None)
        bpy.context.scene.collection.objects.link(self.root)
        self.meshes = {}

    def __call__(self, mat):
        if mat not in self.meshes:
            self.meshes[mat] = bmesh.new()
        return self.meshes[mat]

    def done(self, smooth=()):
        for mat, bm in self.meshes.items():
            obj = to_object(bm, "%s_%s" % (self.name, mat), mat, self.root)
            for f in obj.data.polygons:
                f.use_smooth = mat in smooth
        return self.root


# --- Fishing ---

## The rod: how long it runs ahead of the hand, and how far its tip is pulled down (and back) with
## the shape key "bent" all the way on (the game's FishingRod.TIP and BEND have the same numbers).
ROD_LONG = 3.0
ROD_BEND = 1.0


def rod():
    """A fishing rod held by its grip at the origin (his right hand), running ahead along +y (the game
    turns it): a cork handle back to the butt behind the hand (to his hip), the reel hanging under the
    grip with its spool across, line guides under the blank, the tip at (0, ROD_LONG, 0). Every part has
    the shape key "bent": the blank curving down towards its guides, more and more towards the tip, as
    a fish pulling on the line bends it. The crank is its own piece (rod_crank), turned by the game."""
    P = Parts("rod")
    tube(P("timber"), [(0, -0.42, 0), (0, 0.0, 0), (0, 1.2, 0), (0, ROD_LONG, 0)], [0.02, 0.017, 0.011, 0.003], 6)
    tube(P("cork"), [(0, -0.45, 0), (0, -0.05, 0)], [0.026, 0.024], 8)
    tube(P("cork"), [(0, 0.12, 0), (0, 0.3, 0)], [0.024, 0.022], 8)
    box(P("iron"), (0.0, 0.06, -0.035), (0.012, 0.05, 0.05))
    bmesh.ops.create_cone(P("wood"), cap_ends=True, segments=12, radius1=0.045, radius2=0.045, depth=0.045,
                          matrix=Matrix.Translation((0.0, 0.06, -0.085)) @ Matrix.Rotation(math.pi * 0.5, 4, "Y"))
    bmesh.ops.create_cone(P("iron"), cap_ends=True, segments=8, radius1=0.012, radius2=0.012, depth=0.03,
                          matrix=Matrix.Translation((-0.035, 0.06, -0.085)) @ Matrix.Rotation(math.pi * 0.5, 4, "Y"))
    for k, y in enumerate((0.55, 1.15, 1.75, 2.3, 2.75)):
        r = 0.018 - k * 0.0025
        tube(P("iron"), [(0, y, 0), (0, y, -0.022 - r), (0, y + 0.01, -0.026 - r)], [0.0025, 0.0025, 0.0025], 4)
    root = P.done(smooth=("timber", "cork"))
    for obj in root.children:
        bend(obj)
    return root


def bend(obj):
    """Gives `obj` (a part of the rod) the shape key "bent"."""
    obj.shape_key_add(name="Basis")
    key = obj.shape_key_add(name="bent")
    for i, v in enumerate(obj.data.vertices):
        x, y, z = v.co
        t = max(y, 0.0) / ROD_LONG
        key.data[i].co = (x, y - ROD_BEND * 0.38 * t ** 3, z - ROD_BEND * t * t)


def rod_crank():
    """The reel's crank: its axle at the origin, along x (out of the reel's side, to his left), an arm
    down to the knob his left hand turns, 0.07 m from the axle."""
    P = Parts("rod_crank")
    box(P("iron"), (-0.01, 0.0, -0.035), (0.008, 0.012, 0.08))
    bmesh.ops.create_cone(P("wood"), cap_ends=True, segments=8, radius1=0.011, radius2=0.011, depth=0.035,
                          matrix=Matrix.Translation((-0.028, 0.0, -0.07)) @ Matrix.Rotation(math.pi * 0.5, 4, "Y"))
    return P.done()


def bobber():
    """A float: red over white, a little stalk on top; its waterline at z = 0."""
    P = Parts("bobber")
    bmesh.ops.create_uvsphere(P("red"), u_segments=10, v_segments=5, radius=0.06,
                              matrix=Matrix.Translation((0, 0, 0.0)) @ Matrix.Diagonal((1, 1, 0.9, 1)))
    # (the white lower half: a slightly smaller ball below)
    bmesh.ops.create_uvsphere(P("white"), u_segments=10, v_segments=5, radius=0.058,
                              matrix=Matrix.Translation((0, 0, -0.012)) @ Matrix.Diagonal((1.02, 1.02, 0.95, 1)))
    cylinder(P("red"), 0.008, 0.006, 0.04, 0.12, 6)
    return P.done(smooth=("red", "white"))


def fish(name, length, tall, wide, tail, fins=1.0, spiky=False):
    """A fish lying along y (head at -y), its middle at the origin: a body of hull sections, a tail,
    a dorsal fin (spiny on a perch), eyes. Coloured `name` above and `name_belly` below."""
    P = Parts("fish_" + name)
    stations = [(-0.5, 0.25), (-0.42, 0.62), (-0.25, 0.92), (0.0, 1.0), (0.2, 0.86), (0.36, 0.55), (0.46, 0.25)]
    back_pts, belly_pts = [], []
    for s, r in stations:
        y = s * length
        for k in range(8):
            a = math.tau * k / 8
            x = math.cos(a) * wide * 0.5 * r
            z = math.sin(a) * tall * 0.5 * r
            (back_pts if z >= -0.001 else belly_pts).append((x, y, z))
            if abs(z) < 0.002:
                belly_pts.append((x, y, z))
    hull(P(name), back_pts)
    hull(P(name + "_belly"), belly_pts + [(p[0], p[1], 0.0) for p in back_pts if abs(p[2]) < 0.002])
    ty = 0.46 * length
    hull(P("fin"), [(0, ty - 0.02, 0), (0.004, ty, 0), (-0.004, ty, 0),
                    (0, ty + tail, tall * 0.5), (0, ty + tail, -tall * 0.5),
                    (0, ty + tail * 0.8, 0)])
    # the dorsal fin
    d0, d1 = -0.18 * length, 0.18 * length
    top = tall * 0.5
    pts = [(0, d0, top * 0.9), (0, d1, top * 0.7)]
    pts += [(0, (d0 + d1) * 0.5 + (d1 - d0) * 0.2 * (k - 1), top + tall * 0.35 * fins * (1.2 if spiky and k % 2 == 0 else 0.9)) for k in range(3)]
    pts += [(0.003, d0, top * 0.9), (-0.003, d1, top * 0.7)]
    hull(P("fin"), pts)
    for s in (-1, 1):
        bmesh.ops.create_uvsphere(P("eye"), u_segments=6, v_segments=4, radius=tall * 0.07,
                                  matrix=Matrix.Translation((s * wide * 0.33, -0.4 * length, tall * 0.12)))
        hull(P("fin"), [(s * wide * 0.4, -0.25 * length, -tall * 0.15), (s * wide * 0.4, -0.2 * length, -tall * 0.2),
                        (s * wide * 0.75, -0.08 * length, -tall * 0.3), (s * wide * 0.42, -0.22 * length, -tall * 0.17)])
    return P.done(smooth=(name, name + "_belly"))


def fish_shadow():
    """A fish's dark shape seen in the water: a flat lens with a tail, lying on z = 0, head at -y."""
    P = Parts("fish_shadow")
    pts = []
    for k in range(16):
        a = math.tau * k / 16
        pts.append((math.cos(a) * 0.14, math.sin(a) * 0.38 - 0.05, 0.0))
        pts.append((math.cos(a) * 0.14, math.sin(a) * 0.38 - 0.05, 0.01))
    hull(P("shadow"), pts)
    hull(P("shadow"), [(0, 0.3, 0), (0, 0.3, 0.01), (0.12, 0.5, 0), (-0.12, 0.5, 0), (0.12, 0.5, 0.01), (-0.12, 0.5, 0.01)])
    return P.done()


def catfish_whiskers(root, length, tall, wide):
    """The catfish's barbels: two long and two short from round its mouth, drooping."""
    P = Parts("fish_catfish_barbels")
    for s in (-1, 1):
        mouth = (s * wide * 0.25, -0.5 * length, -tall * 0.05)
        tube(P("catfish"), [mouth, (s * wide * 0.9, -0.55 * length, -tall * 0.2), (s * wide * 1.6, -0.45 * length, -tall * 0.55)],
             [0.004, 0.003, 0.0015], 4)
        tube(P("catfish"), [mouth, (s * wide * 0.45, -0.56 * length, -tall * 0.35)], [0.003, 0.0015], 4)
    made = P.done()
    for child in list(made.children):
        child.parent = root
    bpy.data.objects.remove(made)


def fishing():
    root = bpy.data.objects.new("fishing", None)
    bpy.context.scene.collection.objects.link(root)
    pieces = [rod(), rod_crank(), bobber(), fish_shadow(),
              fish("trout", 0.5, 0.12, 0.07, 0.12), fish("perch", 0.32, 0.12, 0.06, 0.08, 1.4, True),
              fish("pike", 0.9, 0.13, 0.09, 0.16, 0.7), fish("mackerel", 0.4, 0.09, 0.06, 0.12),
              fish("snapper", 0.55, 0.2, 0.08, 0.13, 1.3, True), fish("cod", 0.8, 0.18, 0.12, 0.16),
              fish("koi", 0.5, 0.13, 0.09, 0.14, 0.8), fish("goldkoi", 0.55, 0.14, 0.1, 0.15, 0.8),
              fish("carp", 0.6, 0.17, 0.1, 0.14, 1.0), fish("bluegill", 0.22, 0.14, 0.05, 0.06, 1.2, True)]
    cat = fish("catfish", 0.7, 0.12, 0.13, 0.13, 0.5)
    catfish_whiskers(cat, 0.7, 0.12, 0.13)
    pieces.append(cat)
    for i, p in enumerate(pieces):
        p.parent = root
        p.location = ((i % 8) * 4.0 - 14.0, (i // 8) * 6.0, 0.0)
    return root


bpy.ops.wm.read_factory_settings(use_empty=True)
made = fishing()
bpy.context.view_layer.update()
os.makedirs(os.path.join(ROOT, "tools"), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "tools", "fishing.blend"))
# (exported with each piece back at the origin, so the game places it by its own position)
for p in made.children:
    p.location = (0, 0, 0)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action="DESELECT")
made.select_set(True)
for child in made.children_recursive:
    child.select_set(True)
os.makedirs(os.path.join(ROOT, "fishing"), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT, "fishing", "fishing.glb"), use_selection=True,
                          export_apply=True, export_yup=True)
tris = sum(sum(len(p.vertices) - 2 for p in c.data.polygons) for c in made.children_recursive if c.type == "MESH")
print("BUILT fishing, triangles", tris)
