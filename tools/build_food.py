"""The food he picks up (the Crumbs in the code): the user, 2026-11-01, "the items to pick up should be different food
items - apples, acorns, pizza slices, garbage, etc". Each its own small model, made at the size it is shown in the
game (about a quarter to a third of a metre: big, chunky, N64-cartoon), standing on y = 0, facing +Z:

    food_apple       a red apple with its stem and a leaf
    food_acorn       an acorn in its rough cap
    food_pizza       a slice of pizza: cheese, pepperoni, a crust along the back
    food_core        an apple core, bitten to the pips
    food_banana      a banana skin, flopped open
    food_fishbone    a fish skeleton: head, spine, ribs and tail
    food_cheese      a wedge of cheese with holes
    food_donut       half a pink-iced donut with sprinkles

Run from the project root:
    blender -b --factory-startup --python tools/build_food.py [-- <folder>]   # the folder gets a picture of each from four sides

Writes models/food_<name>.glb and tools/food.blend. Godot axes in the code here: Y up, +Z ahead. Coloured by
material name only (the game's Toon shader shades them).
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PREVIEW_DIR = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1 else None
random.seed(8)

COLOURS = {
    "apple": (0.88, 0.14, 0.11),
    "leaf": (0.36, 0.72, 0.20),
    "stem": (0.42, 0.26, 0.12),
    "nut": (0.76, 0.50, 0.22),
    "nutcap": (0.44, 0.29, 0.14),
    "cheese": (0.99, 0.80, 0.24),
    "cheesehole": (0.86, 0.64, 0.14),
    "crust": (0.86, 0.56, 0.25),
    "pepperoni": (0.76, 0.15, 0.12),
    "flesh": (0.98, 0.94, 0.76),
    "pip": (0.26, 0.14, 0.07),
    "banana": (0.99, 0.86, 0.25),
    "bruise": (0.45, 0.30, 0.12),
    "bone": (0.93, 0.91, 0.85),
    "dough": (0.87, 0.62, 0.34),
    "icing": (0.98, 0.56, 0.72),
    "sprinkle1": (0.30, 0.65, 0.95),
    "sprinkle2": (0.98, 0.95, 0.40),
    "sprinkle3": (0.45, 0.85, 0.45),
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


class Model:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []

    def _index(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def blob(self, centre, radii, mat, turn=None, segments=12, rings=8, wobble=0.0):
        """An ellipsoid (optionally turned by a 3x3 Matrix in Godot axes, and made lumpy)."""
        made = bmesh.ops.create_uvsphere(self.bm, u_segments=segments, v_segments=rings, radius=1.0)
        index = self._index(mat)
        for v in made["verts"]:
            p = Vector((v.co.x, v.co.z, -v.co.y))
            p = Vector((p.x * radii[0], p.y * radii[1], p.z * radii[2]))
            if wobble:
                p *= 1.0 + random.uniform(-wobble, wobble)
            if turn:
                p = turn @ p
            v.co = to_blender(Vector(centre) + p)
        for f in {f for v in made["verts"] for f in v.link_faces}:
            f.material_index = index

    def tube(self, points, radii, mat, segments=10, caps=True):
        index = self._index(mat)
        rings = []
        for i, point in enumerate(points):
            point = Vector(point)
            ahead = Vector(points[min(i + 1, len(points) - 1)]) - Vector(points[max(i - 1, 0)])
            ahead.normalize()
            u = ahead.cross(Vector((0, 0, 1)) if abs(ahead.z) < 0.9 else Vector((1, 0, 0))).normalized()
            w = ahead.cross(u)
            rings.append([self.bm.verts.new(to_blender(point + (u * math.cos(a) + w * math.sin(a)) * radii[i]))
                          for a in (math.tau * k / segments for k in range(segments))])
        for a, b in zip(rings, rings[1:]):
            for k in range(segments):
                f = self.bm.faces.new((a[k], a[(k + 1) % segments], b[(k + 1) % segments], b[k]))
                f.material_index = index
        if caps:
            for ring in (rings[0], rings[-1][::-1]):
                f = self.bm.faces.new(ring[::-1])
                f.material_index = index

    def disc(self, centre, radius, height, mat, segments=16, axis=None):
        """A flat round disc, lying level (or square to `axis`)."""
        index = self._index(mat)
        axis = Vector(axis).normalized() if axis else Vector((0, 1, 0))
        u = axis.cross(Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))).normalized()
        w = axis.cross(u)
        c = Vector(centre)
        top, bottom = [], []
        for k in range(segments):
            a = math.tau * k / segments
            r = (u * math.cos(a) + w * math.sin(a)) * radius
            top.append(self.bm.verts.new(to_blender(c + r + axis * height)))
            bottom.append(self.bm.verts.new(to_blender(c + r)))
        for k in range(segments):
            j = (k + 1) % segments
            self.bm.faces.new((bottom[k], bottom[j], top[j], top[k])).material_index = index
        self.bm.faces.new(top).material_index = index
        self.bm.faces.new(bottom[::-1]).material_index = index

    def prism(self, outline, y0, y1, mat):
        """A flat shape: the outline (x, z points, anticlockwise from above) from height y0 up to y1."""
        index = self._index(mat)
        low = [self.bm.verts.new(to_blender((x, y0, z))) for x, z in outline]
        high = [self.bm.verts.new(to_blender((x, y1, z))) for x, z in outline]
        n = len(outline)
        for k in range(n):
            j = (k + 1) % n
            self.bm.faces.new((low[k], low[j], high[j], high[k])).material_index = index
        self.bm.faces.new(high).material_index = index
        self.bm.faces.new(low[::-1]).material_index = index

    def done(self, smooth=True):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces[:])
        for f in self.bm.faces:
            f.smooth = smooth
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for name in self.mats:
            mesh.materials.append(material(name))
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.collection.objects.link(obj)
        return obj


def apple():
    m = Model("food_apple")
    m.blob((0, 0.13, 0), (0.135, 0.12, 0.135), "apple", segments=16, rings=10)
    # (a dimple at the top: a squat darker cap would show as a seam, so the stem just stands in it)
    m.tube([(0, 0.22, 0), (0.01, 0.27, 0), (0.025, 0.3, 0)], [0.012, 0.011, 0.009], "stem", 6)
    turn = Matrix.Rotation(-0.5, 3, Vector((0, 0, 1))) @ Matrix.Rotation(0.3, 3, Vector((1, 0, 0)))
    m.blob((0.06, 0.27, 0.0), (0.055, 0.012, 0.028), "leaf", turn, 10, 5)
    return m.done()


def acorn():
    m = Model("food_acorn")
    rings = [(0.0, 0.0), (0.012, 0.05), (0.05, 0.072), (0.11, 0.08), (0.17, 0.072), (0.2, 0.06)]
    m.tube([(0, y, 0) for y, _ in rings], [max(r, 0.004) for _, r in rings], "nut", 14)
    # The cap: rough and scaly, wider than the nut
    m.blob((0, 0.205, 0), (0.092, 0.05, 0.092), "nutcap", segments=14, rings=8, wobble=0.06)
    m.tube([(0, 0.24, 0), (0.005, 0.28, 0)], [0.013, 0.01], "nutcap", 6)
    return m.done()


def pizza():
    m = Model("food_pizza")
    # A slice lying flat, its point ahead (+Z), crust along the back
    outline = [(0.0, 0.2), (-0.13, -0.11), (0.13, -0.11)][::-1]
    m.prism(outline, 0.0, 0.03, "crust")
    inner = [(0.0, 0.17), (-0.105, -0.09), (0.105, -0.09)][::-1]
    m.prism(inner, 0.03, 0.045, "cheese")
    m.tube([(-0.14, 0.04, -0.115), (0.0, 0.05, -0.125), (0.14, 0.04, -0.115)], [0.03, 0.034, 0.03], "crust", 10)
    for x, z in ((-0.04, -0.04), (0.045, -0.05), (0.0, 0.06)):
        m.disc((x, 0.045, z), 0.03, 0.008, "pepperoni", 12)
    return m.done(smooth=False)


def core():
    m = Model("food_core")
    profile = [(0.0, 0.07), (0.03, 0.085), (0.07, 0.045), (0.12, 0.035), (0.17, 0.05), (0.21, 0.085), (0.235, 0.07)]
    m.tube([(0, y, 0) for y, _ in profile], [r for _, r in profile], "flesh", 14)
    # The red skin left at top and bottom, the pips, the stem
    m.disc((0, 0.0, 0), 0.075, 0.03, "apple", 14)
    m.disc((0, 0.21, 0), 0.08, 0.03, "apple", 14)
    for k in range(3):
        a = k * 2.1
        m.blob((math.cos(a) * 0.034, 0.12 + 0.02 * (k % 2), math.sin(a) * 0.034), (0.012, 0.018, 0.009), "pip", segments=8, rings=4)
    m.tube([(0, 0.24, 0), (0.008, 0.29, 0)], [0.01, 0.008], "stem", 6)
    return m.done()


def banana():
    m = Model("food_banana")
    # The middle, and four strips of skin flopped out round it
    m.blob((0, 0.07, 0), (0.05, 0.08, 0.05), "banana", segments=12, rings=8)
    m.disc((0, 0.14, 0), 0.03, 0.02, "bruise", 8)
    for k in range(4):
        a = math.tau * k / 4 + 0.4
        out = Vector((math.cos(a), 0.0, math.sin(a)))
        pts = [Vector((0, 0.1, 0)) + out * 0.03, Vector((0, 0.06, 0)) + out * 0.11, Vector((0, 0.025, 0)) + out * 0.18]
        m.tube(pts, [0.03, 0.028, 0.02], "banana", 8)
        m.blob(pts[-1] + out * 0.015 + Vector((0, -0.005, 0)), (0.02, 0.014, 0.02), "bruise", segments=8, rings=4)
    return m.done()


def fishbone():
    m = Model("food_fishbone")
    # Lying on its side along X: a head at +X, the spine, ribs above and below, the tail at -X
    y = 0.1
    m.tube([(0.1, y, 0), (-0.14, y, 0)], [0.012, 0.01], "bone", 8)
    turn = Matrix.Rotation(0.0, 3, Vector((0, 1, 0)))
    m.blob((0.15, y, 0), (0.06, 0.055, 0.022), "bone", turn, 12, 6)
    m.blob((0.18, y + 0.012, 0.02), (0.012, 0.012, 0.006), "pip", segments=8, rings=4)
    for k in range(5):
        x = 0.07 - k * 0.045
        h = 0.07 - k * 0.008
        for up in (1, -1):
            m.tube([(x, y, 0), (x - 0.02, y + up * h * 0.6, 0), (x - 0.035, y + up * h, 0)], [0.007, 0.006, 0.004], "bone", 6)
    # The tail: two flat fins
    for up in (1, -1):
        turn = Matrix.Rotation(up * 0.6, 3, Vector((0, 0, 1)))
        m.blob((-0.17, y + up * 0.025, 0), (0.045, 0.014, 0.012), "bone", turn, 10, 5)
    return m.done()


def cheese():
    m = Model("food_cheese")
    # A wedge: its point ahead (+Z), rind at the back, standing 0.13 tall
    outline = [(0.0, 0.17), (-0.13, -0.1), (0.13, -0.1)][::-1]
    m.prism(outline, 0.0, 0.13, "cheese")
    # Holes: shallow darker rounds on the top and the sides
    for x, y, z, axis in ((0.03, 0.13, 0.0, (0, 1, 0)), (-0.04, 0.13, -0.05, (0, 1, 0)), (0.0, 0.07, -0.1, (0, 0, -1)),
                          (-0.07, 0.05, 0.02, (-0.9, 0, 0.45)), (0.07, 0.08, -0.01, (0.9, 0, 0.45))):
        m.disc((x, y - 0.002 if axis == (0, 1, 0) else y, z), 0.022 + 0.008 * random.random(), 0.004, "cheesehole", 10, axis)
    return m.done(smooth=False)


def donut():
    m = Model("food_donut")
    # Half a donut lying flat, the bite at the front
    ring = [(math.cos(a) * 0.1, 0.045, -math.sin(a) * 0.1) for a in (math.pi * k / 10 for k in range(11))]
    m.tube(ring, [0.045] * len(ring), "dough", 12)
    icing = [(x, y + 0.012, z) for x, y, z in ring[1:-1]]
    m.tube(icing, [0.04] * len(icing), "icing", 12)
    for k in range(10):
        a = math.pi * random.uniform(0.12, 0.88)
        p = Vector((math.cos(a) * 0.1, 0.098, -math.sin(a) * 0.1)) + Vector((random.uniform(-0.02, 0.02), 0, random.uniform(-0.02, 0.02)))
        turn = Matrix.Rotation(random.uniform(0, math.tau), 3, Vector((0, 1, 0)))
        m.blob(p, (0.012, 0.005, 0.004), "sprinkle%d" % (1 + k % 3), turn, 6, 3)
    return m.done()


def look(folder, obj):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.render.resolution_x, scene.render.resolution_y = 300, 300
    scene.world = bpy.data.worlds.new("World") if scene.world is None else scene.world
    scene.world.color = (0.35, 0.42, 0.5)
    camera = scene.camera
    if camera is None:
        camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
        camera.data.type = "ORTHO"
        scene.collection.objects.link(camera)
        scene.camera = camera
    for other in bpy.data.objects:
        if other.type == "MESH":
            other.hide_render = other != obj
    size = max(obj.dimensions) * 1.4
    middle = sum((Vector(c) for c in obj.bound_box), Vector()) / 8.0
    for view, direction in (("front", (0, -1, 0.3)), ("side", (1, 0, 0.3)), ("back", (0, 1, 0.3)), ("top", (0.01, 0, 1))):
        offset = Vector(direction).normalized() * 4.0
        camera.data.ortho_scale = size
        camera.location = middle + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (obj.name, view))
        bpy.ops.render.render(write_still=True)


bpy.ops.wm.read_factory_settings(use_empty=True)
made = [apple(), acorn(), pizza(), core(), banana(), fishbone(), cheese(), donut()]
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "tools", "food.blend"))
for obj in made:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT, "models", obj.name + ".glb"), export_format="GLB",
                              export_yup=True, use_selection=True, export_animations=False)
    print("BUILT %s tris=%d" % (obj.name, sum(len(p.vertices) - 2 for p in obj.data.polygons)))
if PREVIEW_DIR:
    for obj in made:
        look(PREVIEW_DIR, obj)
