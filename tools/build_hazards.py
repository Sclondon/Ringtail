"""The hazards' models (the user, 2026-11-01: "there should be birds and other predators to avoid, and people as
well and cars"; enemies "in the same style as the hero"). Looks and sizes are Claude's (placeholders):

    (the crow was here too: it is tools/build_birds.py's now, models/crow.glb, with the owl)
    hawk   a brown hawk with a cream chest ruff, hooked yellow beak, fierce brow, banded tail, broad zigzag wings
    car    a rounded cartoon car (its body paint is tinted in the game), four wheels to turn

Each is several objects (a bird's wings, a car's wheels, are their own, with their origin at the joint) exported
together, so the game can move the parts. Godot axes in the code: Y up, +Z ahead.

Run from the project root:
    blender -b --factory-startup --python tools/build_hazards.py [-- <folder>]   # the folder gets four sides of each

Writes models/<name>.glb and tools/hazards.blend.
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
random.seed(9)

COLOURS = {
    "crow": (0.13, 0.13, 0.17),
    "crowdeep": (0.07, 0.07, 0.1),
    "beak": (0.32, 0.31, 0.33),
    "eye": (0.97, 0.97, 0.95),
    "pupil": (0.03, 0.03, 0.04),
    "hawk": (0.48, 0.31, 0.18),
    "hawkdark": (0.3, 0.19, 0.11),
    "cream": (0.93, 0.86, 0.7),
    "yellow": (0.96, 0.76, 0.2),
    "iris": (0.98, 0.78, 0.15),
    "paint": (0.85, 0.22, 0.18),
    "glass": (0.45, 0.62, 0.78),
    "chrome": (0.78, 0.8, 0.84),
    "tyre": (0.1, 0.1, 0.11),
    "lamp": (1.0, 0.95, 0.7),
    "tail": (0.85, 0.1, 0.1),
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

    def blob(self, centre, radii, mat, segments=12, rings=7):
        made = bmesh.ops.create_uvsphere(self.bm, u_segments=segments, v_segments=rings, radius=1.0)
        index = self._index(mat)
        for v in made["verts"]:
            p = Vector((v.co.x * radii[0], v.co.z * radii[1], -v.co.y * radii[2]))
            v.co = to_blender(Vector(centre) + p - self.origin)
        for f in {f for v in made["verts"] for f in v.link_faces}:
            f.material_index = index

    def tube(self, points, radii, mat, segments=8):
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

    def box(self, centre, size, mat):
        cx, cy, cz = centre
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        c = [(cx + sx * hx, cy + sy * hy, cz + sz * hz) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
        for q in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
            self.face([c[i] for i in q], mat)

    def ruff(self, centre, axis, radius, flare, mat, lean=0.04, spikes=9, wide=1.0):
        """A zigzag ring of feather spikes, as the raccoon's fur is: lengths uneven, leaning along `axis`."""
        index = self._index(mat)
        axis = Vector(axis).normalized()
        u = axis.cross(Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))).normalized()
        v = axis.cross(u).normalized()
        centre = Vector(centre)

        def ring(at, r, spiky):
            out = []
            count = spikes * 2 if spiky else spikes
            for j in range(count):
                a = math.tau * j / count
                tip = spiky and j % 2 == 0
                rr = r * (random.uniform(0.75, 1.3) if tip else (0.6 if spiky else 1.0))
                p = at + axis * (lean * random.uniform(0.5, 1.6) if tip else 0.0) + (u * math.cos(a) * wide + v * math.sin(a)) * rr
                out.append(self._v(p))
            return out

        base = ring(centre - axis * 0.02, radius * 0.7, False)
        rim = ring(centre, radius * flare, True)
        back = ring(centre + axis * 0.006, radius * 0.7, False)
        for a, b in ((base, rim), (back, rim)):
            for j in range(len(b)):
                k0 = j * len(a) // len(b)
                k1 = ((j + 1) * len(a) // len(b)) % len(a)
                j1 = (j + 1) % len(b)
                f = self.bm.faces.new((a[k0], b[j], b[j1])) if k0 == k1 else self.bm.faces.new((a[k0], a[k1], b[j1], b[j]))
                f.material_index = index
        self.bm.faces.new(base[::-1]).material_index = index
        self.bm.faces.new(back).material_index = index

    def plate(self, outline, mat, thick=0.012):
        """A flat shape from a closed outline, given a little thickness so it shows from both sides."""
        index = self._index(mat)
        top = [self._v(Vector(p) + Vector((0, thick / 2, 0))) for p in outline]
        bottom = [self._v(Vector(p) - Vector((0, thick / 2, 0))) for p in outline]
        self.bm.faces.new(top).material_index = index
        self.bm.faces.new(bottom[::-1]).material_index = index
        n = len(outline)
        for k in range(n):
            j = (k + 1) % n
            self.bm.faces.new((bottom[k], bottom[j], top[j], top[k])).material_index = index

    def done(self, smooth=False):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts[:], dist=0.0002)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces[:])
        for f in self.bm.faces:
            f.smooth = smooth
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for name in self.mats:
            mesh.materials.append(material(name))
        obj = bpy.data.objects.new(self.name, mesh)
        obj.location = to_blender(self.origin)
        bpy.context.collection.objects.link(obj)
        return obj


def wing_outline(span, chord, feathers, side):
    """A wing's outline from its shoulder at the origin out along X (`side` +1 left, -1 right), its leading edge ahead
    (+Z), its trailing edge a zigzag of feathers."""
    lead = [(0.0, 0.0, chord * 0.35), (span * 0.35, 0.01, chord * 0.42), (span * 0.75, 0.0, chord * 0.25), (span, -0.01, 0.0)]
    trail = []
    for k in range(feathers, -1, -1):
        t = k / feathers
        x = span * t
        back = -chord * (0.55 + 0.35 * math.sin(math.pi * t * 0.8)) * (1.0 - 0.45 * t)
        trail.append((x, 0.0, back))
        if k > 0:
            xm = span * (k - 0.5) / feathers
            trail.append((xm, 0.0, back * 0.72 + -chord * 0.08))
    outline = lead + trail
    return [(p[0] * side, p[1], p[2]) for p in outline] if side > 0 else [(p[0] * side, p[1], p[2]) for p in outline][::-1]


def bird(name, size, body_mat, deep_mat, chest_mat, beak_mat, iris, hooked):
    s = size
    made = []
    body = Part(name + "_body")
    body.blob((0, 0.25 * s, 0), (0.11 * s, 0.11 * s, 0.18 * s), body_mat, 12, 8)
    body.blob((0, 0.36 * s, 0.15 * s), (0.08 * s, 0.08 * s, 0.085 * s), body_mat, 12, 8)
    # Shaggy feather ruffs round the neck and the body, the chest a ruff of its own colour
    body.ruff((0, 0.31 * s, 0.1 * s), (0, -0.2, -1), 0.075 * s, 1.55, chest_mat, 0.04 * s)
    body.ruff((0, 0.26 * s, 0.0), (0, -0.1, -1), 0.1 * s, 1.65, body_mat, 0.06 * s)
    body.ruff((0, 0.25 * s, -0.09 * s), (0, -0.1, -1), 0.09 * s, 1.65, deep_mat, 0.06 * s)
    body.ruff((0, 0.42 * s, 0.13 * s), (0, 0.5, -1), 0.04 * s, 1.7, deep_mat, 0.03 * s, 7)
    # Big cartoon eyes, and a brow over them
    for side in (1, -1):
        body.blob((side * 0.045 * s, 0.385 * s, 0.205 * s), (0.032 * s, 0.035 * s, 0.022 * s), "eye", 10, 6)
        if iris:
            body.blob((side * 0.05 * s, 0.385 * s, 0.222 * s), (0.02 * s, 0.022 * s, 0.01 * s), "iris", 8, 5)
        body.blob((side * 0.052 * s, 0.385 * s, 0.229 * s), (0.011 * s, 0.014 * s, 0.006 * s), "pupil", 8, 5)
        brow = [(side * 0.02 * s, 0.43 * s, 0.215 * s), (side * 0.085 * s, 0.415 * s if hooked else 0.43 * s, 0.2 * s)]
        body.tube(brow, [0.01 * s, 0.008 * s], deep_mat, 6)
    # The beak: hooked down at the tip for the hawk
    beak = [(0, 0.355 * s, 0.215 * s), (0, 0.35 * s, 0.27 * s), (0, 0.335 * s, 0.31 * s)]
    if hooked:
        beak.append((0, 0.305 * s, 0.32 * s))
    body.tube(beak, [0.026 * s, 0.018 * s, 0.009 * s] + ([0.004 * s] if hooked else []), beak_mat, 8)
    # A fan of tail feathers, zigzag
    for k in range(5):
        a = (k - 2) * 0.22
        root = Vector((0, 0.24 * s, -0.16 * s))
        tip = root + Vector((math.sin(a) * 0.17 * s, -0.02 * s, -math.cos(a) * 0.17 * s))
        side = Vector((math.cos(a), 0, math.sin(a))) * 0.028 * s
        body.plate([root + side, tip + side * 0.6, tip + Vector((0, 0, -0.03 * s)), tip - side * 0.6, root - side],
                   deep_mat if k % 2 else body_mat, 0.01 * s)
    # Legs and feet
    for side in (1, -1):
        hip = Vector((side * 0.04 * s, 0.17 * s, 0.02 * s))
        foot = Vector((side * 0.045 * s, 0.01 * s, 0.03 * s))
        body.tube([hip, foot], [0.011 * s, 0.009 * s], beak_mat if not hooked else "yellow", 6)
        for k in range(3):
            a = (k - 1) * 0.45
            body.tube([foot, foot + Vector((math.sin(a) * 0.045 * s, -0.005 * s, math.cos(a) * 0.045 * s))], [0.007 * s, 0.004 * s],
                      "pupil" if hooked else beak_mat, 5)
    made.append(body.done())
    for side, called in ((1, "_wing_l"), (-1, "_wing_r")):
        shoulder = (side * 0.085 * s, 0.31 * s, 0.03 * s)
        wing = Part(name + called, shoulder)
        outline = wing_outline(0.42 * s, 0.24 * s, 6, side)
        wing.plate([Vector(shoulder) + Vector(p) for p in outline], body_mat, 0.014 * s)
        # (a darker band of flight feathers along the trailing edge)
        inner = [Vector(shoulder) + Vector((p[0] * 0.98, 0.009 * s, p[2] * 0.98)) for p in outline if p[2] < -0.05 * s]
        if len(inner) > 2:
            wing.plate(inner, deep_mat, 0.004 * s)
        made.append(wing.done())
    return made


def car():
    made = []
    body = Part("car_body")
    # The body: a fat rounded slab, a lower nose and tail, a cabin on top
    body.box((0, 0.62, 0.0), (1.6, 0.6, 3.3), "paint")
    body.blob((0, 0.62, 1.55), (0.8, 0.3, 0.22), "paint", 12, 6)
    body.blob((0, 0.62, -1.55), (0.8, 0.3, 0.2), "paint", 12, 6)
    body.blob((0, 0.9, 0.75), (0.78, 0.06, 0.8), "paint", 12, 6)
    cabin = [(-0.72, 0.9, 0.55), (0.72, 0.9, 0.55), (0.72, 0.9, -1.2), (-0.72, 0.9, -1.2)]
    top = [(-0.6, 1.45, 0.15), (0.6, 1.45, 0.15), (0.6, 1.45, -1.0), (-0.6, 1.45, -1.0)]
    body.face(top, "paint")
    body.face([cabin[0], cabin[1], top[1], top[0]], "glass")
    body.face([cabin[3], top[3], top[2], cabin[2]], "glass")
    for i, j in ((1, 2), (3, 0)):
        body.face([cabin[i], cabin[j], top[j], top[i]], "glass")
    body.box((0, 1.47, -0.42), (1.22, 0.06, 1.2), "paint")
    # (door lines on the glass: a post down the middle of each side)
    for side in (1, -1):
        body.box((side * 0.66, 1.17, -0.3), (0.06, 0.56, 0.1), "paint")
    # Bumpers, lamps
    body.box((0, 0.42, 1.78), (1.5, 0.16, 0.12), "chrome")
    body.box((0, 0.42, -1.76), (1.5, 0.16, 0.12), "chrome")
    for side in (1, -1):
        body.blob((side * 0.52, 0.7, 1.72), (0.13, 0.11, 0.05), "lamp", 10, 5)
        body.blob((side * 0.58, 0.7, -1.72), (0.1, 0.08, 0.04), "tail", 8, 5)
    made.append(body.done())
    for name, x, z in (("car_wheel_fl", 0.78, 1.05), ("car_wheel_fr", -0.78, 1.05), ("car_wheel_rl", 0.78, -1.05), ("car_wheel_rr", -0.78, -1.05)):
        wheel = Part(name, (x, 0.38, z))
        side = 1 if x > 0 else -1
        wheel.tube([(x - side * 0.14, 0.38, z), (x + side * 0.14, 0.38, z)], [0.38, 0.38], "tyre", 14)
        wheel.tube([(x + side * 0.12, 0.38, z), (x + side * 0.16, 0.38, z)], [0.2, 0.2], "chrome", 10)
        made.append(wheel.done())
    return made


def export(name, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT, "models", name + ".glb"), export_format="GLB",
                              export_yup=True, use_selection=True, export_animations=False)
    print("BUILT %s tris=%d" % (name, sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objects)))


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
    corners = [o.matrix_world @ Vector(c) for o in objects for c in o.bound_box]
    lo = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    hi = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    middle = (lo + hi) / 2
    size = max(hi - lo) * 1.25
    for view, direction in (("front", (0, -1, 0.15)), ("side", (1, 0, 0.15)), ("back", (0, 1, 0.15)), ("top", (0.01, 0, 1)),
                            ("quarter", (0.7, -0.7, 0.4))):
        offset = Vector(direction).normalized() * 10.0
        camera.data.ortho_scale = size
        camera.location = middle + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


bpy.ops.wm.read_factory_settings(use_empty=True)
models = {
    "hawk": bird("hawk", 1.7, "hawk", "hawkdark", "cream", "yellow", True, True),
    "car": car(),
}
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "tools", "hazards.blend"))
for name, objects in models.items():
    export(name, objects)
if PREVIEW_DIR:
    for name, objects in models.items():
        look(PREVIEW_DIR, name, objects)
