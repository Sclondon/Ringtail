"""Small things for World 1, each its own model:

    crumb      a cookie crumb with chocolate chips (the Crumbs, ~100 to a world)
    cap        a shiny bottle cap with a crimped edge (the Bottlecaps, 5 to a world)
    stopwatch  the race's stopwatch
    cat        a ginger yard cat, crouched to pounce (posed and moved whole in code)

Run from the project root:
    blender -b --factory-startup --python tools/build_props.py [-- <folder>]   # the folder gets a picture of each from four sides

Writes models/<name>.glb and tools/props.blend. Godot axes in the code here: Y up, +Z ahead.
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
random.seed(3)

COLOURS = {
    "cookie": (0.80, 0.58, 0.32),
    "chip": (0.25, 0.14, 0.08),
    "gold": (0.98, 0.78, 0.25),
    "capred": (0.85, 0.16, 0.14),
    "chrome": (0.80, 0.82, 0.86),
    "face": (0.97, 0.96, 0.92),
    "ink": (0.06, 0.06, 0.07),
    "ginger": (0.92, 0.52, 0.20),
    "stripe": (0.68, 0.30, 0.10),
    "cream": (0.98, 0.90, 0.78),
    "pink": (0.95, 0.55, 0.60),
    "eye": (0.70, 0.90, 0.30),
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
            p = Vector((v.co.x, v.co.z, -v.co.y))  # (the sphere is made in Blender's axes)
            p = Vector((p.x * radii[0], p.y * radii[1], p.z * radii[2]))
            if wobble:
                p *= 1.0 + random.uniform(-wobble, wobble)
            if turn:
                p = turn @ p
            v.co = to_blender(Vector(centre) + p)
        for f in {f for v in made["verts"] for f in v.link_faces}:
            f.material_index = index

    def tube(self, points, radii, mat, segments=10):
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
        for ring in (rings[0], rings[-1][::-1]):
            f = self.bm.faces.new(ring[::-1])
            f.material_index = index

    def disc(self, centre, radius, height, mat, segments=24, crimp=0.0):
        index = self._index(mat)
        cx, cy, cz = centre
        top, bottom = [], []
        for k in range(segments):
            a = math.tau * k / segments
            r = radius * (1.0 + (crimp if k % 2 else 0.0))
            top.append(self.bm.verts.new(to_blender((cx + math.cos(a) * r, cy + height, cz + math.sin(a) * r))))
            bottom.append(self.bm.verts.new(to_blender((cx + math.cos(a) * r, cy, cz + math.sin(a) * r))))
        for k in range(segments):
            j = (k + 1) % segments
            self.bm.faces.new((bottom[k], bottom[j], top[j], top[k])).material_index = index
        self.bm.faces.new(top).material_index = index
        self.bm.faces.new(bottom[::-1]).material_index = index

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


def crumb():
    m = Model("crumb")
    m.blob((0, 0, 0), (0.13, 0.08, 0.11), "cookie", segments=8, rings=5, wobble=0.18)
    for k in range(4):
        a = k * 1.7
        m.blob((math.cos(a) * 0.07, 0.05 - 0.02 * (k % 2), math.sin(a) * 0.06), (0.03, 0.025, 0.03), "chip", segments=6, rings=4)
    return m.done(smooth=False)


def cap():
    m = Model("cap")
    # Standing on its edge, face to +Z, so it turns like a coin: a crimped rim, a red face, a gold star
    turn = Matrix.Rotation(math.pi / 2, 3, Vector((1, 0, 0)))
    disc = Model("cap_tmp")
    disc.disc((0, -0.04, 0), 0.24, 0.08, "gold", 28, crimp=0.07)
    disc.disc((0, 0.035, 0), 0.19, 0.015, "capred", 24)
    for k in range(5):
        a = math.tau * k / 5 + math.pi / 2
        disc.blob((math.cos(a) * 0.08, 0.05, math.sin(a) * 0.08), (0.035, 0.012, 0.035), "gold", segments=6, rings=3)
    disc.blob((0, 0.05, 0), (0.06, 0.014, 0.06), "gold", segments=8, rings=3)
    for v in disc.bm.verts:
        p = Vector((v.co.x, v.co.z, -v.co.y))
        v.co = to_blender(turn @ p)
    disc.name = "cap"
    return disc.done(smooth=False)


def stopwatch():
    m = Model("stopwatch")
    turn = Matrix.Rotation(math.pi / 2, 3, Vector((1, 0, 0)))
    m.disc((0, -0.06, 0), 0.26, 0.12, "chrome", 24)
    m.disc((0, 0.055, 0), 0.22, 0.02, "face", 24)
    m.disc((0, 0.07, 0.0), 0.02, 0.02, "ink", 8)
    m.tube([(0, 0.075, 0), (0.0, 0.075, -0.16)], [0.01, 0.008], "capred", 6)
    m.disc((0, 0.26, 0), 0.05, 0.08, "chrome", 10)
    for v in m.bm.verts:
        p = Vector((v.co.x, v.co.z, -v.co.y))
        if p.y < 0.2:
            v.co = to_blender(turn @ p)
    return m.done(smooth=False)


def cat():
    m = Model("cat")
    # Crouched low, ready to pounce: about 0.55 m long, facing +Z
    m.blob((0, 0.24, -0.02), (0.13, 0.12, 0.27), "ginger")
    for z in (-0.18, -0.06, 0.06):
        m.blob((0, 0.33, z), (0.11, 0.035, 0.035), "stripe")
    m.blob((0, 0.2, 0.12), (0.10, 0.09, 0.12), "cream")
    m.blob((0, 0.36, 0.29), (0.115, 0.10, 0.10), "ginger")
    m.blob((0, 0.33, 0.37), (0.055, 0.045, 0.045), "cream")
    m.blob((0, 0.35, 0.405), (0.016, 0.012, 0.01), "pink")
    for side in (1, -1):
        m.blob((side * 0.045, 0.385, 0.375), (0.022, 0.026, 0.014), "eye", segments=8, rings=4)
        m.blob((side * 0.045, 0.385, 0.386), (0.007, 0.02, 0.006), "ink", segments=6, rings=4)
        # Ears: flattened cones made of squashed blobs
        m.blob((side * 0.07, 0.465, 0.27), (0.04, 0.06, 0.02), "ginger", Matrix.Rotation(side * -0.35, 3, Vector((0, 0, 1))), 8, 5)
        m.blob((side * 0.068, 0.46, 0.278), (0.024, 0.04, 0.01), "pink", Matrix.Rotation(side * -0.35, 3, Vector((0, 0, 1))), 8, 5)
        # Legs folded under, paws forward
        m.blob((side * 0.09, 0.07, 0.17), (0.045, 0.07, 0.05), "ginger")
        m.blob((side * 0.08, 0.025, 0.24), (0.04, 0.025, 0.06), "cream")
        m.blob((side * 0.1, 0.11, -0.2), (0.06, 0.1, 0.11), "ginger")
        m.blob((side * 0.09, 0.025, -0.12), (0.04, 0.025, 0.07), "cream")
        # Whiskers
        m.tube([(side * 0.04, 0.33, 0.39), (side * 0.15, 0.345, 0.4)], [0.003, 0.002], "cream", 4)
    # The tail, up and curled at the tip
    tail = [(0, 0.28, -0.27), (0, 0.33, -0.38), (0, 0.45, -0.44), (0, 0.58, -0.42), (0, 0.64, -0.36)]
    m.tube(tail, [0.035, 0.032, 0.03, 0.028, 0.02], "ginger", 8)
    return m.done()


def look(folder, obj):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.render.resolution_x, scene.render.resolution_y = 400, 400
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
    for view, direction in (("front", (0, -1, 0.15)), ("side", (1, 0, 0.15)), ("back", (0, 1, 0.15)), ("top", (0.01, 0, 1))):
        offset = Vector(direction).normalized() * 4.0
        camera.data.ortho_scale = size
        camera.location = middle + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (obj.name, view))
        bpy.ops.render.render(write_still=True)


bpy.ops.wm.read_factory_settings(use_empty=True)
made = [crumb(), cap(), stopwatch(), cat()]
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "tools", "props.blend"))
for obj in made:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT, "models", obj.name + ".glb"), export_format="GLB",
                              export_yup=True, use_selection=True, export_animations=False)
    print("BUILT %s tris=%d" % (obj.name, sum(len(p.vertices) - 2 for p in obj.data.polygons)))
if PREVIEW_DIR:
    for obj in made:
        look(PREVIEW_DIR, obj)
