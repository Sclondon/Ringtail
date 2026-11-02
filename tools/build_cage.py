"""The cage a lost raccoon is shut in (the user, 2026-11-02: "they should be in cages you have to break like in
rayman"): a square wooden base and a peaked wooden lid on four corner posts, iron bars between them on every side,
and a padlock on the front. Each part is its own object (cage_base, cage_lid, cage_post_<n>, cage_bar_<n>, cage_lock)
so the game can throw them apart when it breaks. About 1.0 m square and 1.15 m to the lid's peak: a grown raccoon
stands up inside it. Standing on y = 0, the lock facing +Z.

Run from the project root:
    blender -b --factory-startup --python tools/build_cage.py [-- <folder>]   # the folder gets a picture from four sides

Writes models/cage.glb and tools/cage.blend. Godot axes in the code here: Y up, +Z ahead. Coloured by material name
only (the game's Toon shader shades it).
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
    "cagewood": (0.55, 0.36, 0.2),
    "cagewood_dark": (0.38, 0.24, 0.13),
    "iron": (0.32, 0.33, 0.36),
    "brass": (0.86, 0.66, 0.24),
}

HALF = 0.5
BASE = 0.12
POST_TOP = 1.0
BARS_PER_SIDE = 4


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
    """One piece of the cage: its own mesh, about its own middle (so it can be thrown and turned about it)."""

    def __init__(self, name, middle):
        self.name = name
        self.middle = Vector(middle)
        self.bm = bmesh.new()
        self.mats = []

    def _index(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def box(self, centre, size, mat):
        index = self._index(mat)
        c = Vector(centre) - self.middle
        h = Vector(size) * 0.5
        corners = [self.bm.verts.new(to_blender(c + Vector((x * h.x, y * h.y, z * h.z))))
                   for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
        for quad in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
            self.bm.faces.new([corners[k] for k in quad]).material_index = index

    def rod(self, a, b, radius, mat, segments=8):
        index = self._index(mat)
        a = Vector(a) - self.middle
        b = Vector(b) - self.middle
        ahead = (b - a).normalized()
        u = ahead.cross(Vector((0, 0, 1)) if abs(ahead.z) < 0.9 else Vector((1, 0, 0))).normalized()
        w = ahead.cross(u)
        rings = [[self.bm.verts.new(to_blender(end + (u * math.cos(t) + w * math.sin(t)) * radius))
                  for t in (math.tau * k / segments for k in range(segments))] for end in (a, b)]
        for k in range(segments):
            j = (k + 1) % segments
            self.bm.faces.new((rings[0][k], rings[0][j], rings[1][j], rings[1][k])).material_index = index
        self.bm.faces.new(rings[0][::-1]).material_index = index
        self.bm.faces.new(rings[1]).material_index = index

    def pyramid(self, base_y, half, peak_y, mat):
        """The lid's peaked roof: four sloping faces from a square at base_y up to a point."""
        index = self._index(mat)
        m = self.middle
        corners = [self.bm.verts.new(to_blender(Vector((x * half, base_y, z * half)) - m)) for x, z in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        peak = self.bm.verts.new(to_blender(Vector((0.0, peak_y, 0.0)) - m))
        for k in range(4):
            self.bm.faces.new((corners[k], corners[(k + 1) % 4], peak)).material_index = index
        self.bm.faces.new(corners[::-1]).material_index = index

    def done(self):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts[:], dist=0.0001)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces[:])
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for name in self.mats:
            mesh.materials.append(material(name))
        obj = bpy.data.objects.new(self.name, mesh)
        obj.location = to_blender(self.middle)
        bpy.context.collection.objects.link(obj)
        return obj


def cage():
    made = []
    base = Part("cage_base", (0.0, BASE * 0.5, 0.0))
    base.box((0.0, BASE * 0.5, 0.0), (HALF * 2.0 + 0.08, BASE, HALF * 2.0 + 0.08), "cagewood")
    # (planks across it)
    for k in range(5):
        z = -HALF + (k + 0.5) * (HALF * 2.0 / 5)
        base.box((0.0, BASE + 0.005, z), (HALF * 2.0, 0.012, HALF * 2.0 / 5 - 0.02), "cagewood_dark" if k % 2 else "cagewood")
    made.append(base.done())
    lid = Part("cage_lid", (0.0, POST_TOP + 0.06, 0.0))
    lid.box((0.0, POST_TOP + 0.04, 0.0), (HALF * 2.0 + 0.12, 0.08, HALF * 2.0 + 0.12), "cagewood")
    lid.pyramid(POST_TOP + 0.08, HALF + 0.06, POST_TOP + 0.24, "cagewood_dark")
    lid.rod((0.0, POST_TOP + 0.22, 0.0), (0.0, POST_TOP + 0.34, 0.0), 0.03, "iron")
    made.append(lid.done())
    for n, (x, z) in enumerate(((-HALF, -HALF), (HALF, -HALF), (HALF, HALF), (-HALF, HALF))):
        post = Part("cage_post_%d" % n, (x, (BASE + POST_TOP) * 0.5, z))
        post.box((x, (BASE + POST_TOP) * 0.5, z), (0.08, POST_TOP - BASE, 0.08), "cagewood_dark")
        made.append(post.done())
    n = 0
    for side in range(4):
        a = Vector(((-HALF, -HALF), (HALF, -HALF), (HALF, HALF), (-HALF, HALF))[side] + (0.0,))
        b = Vector(((HALF, -HALF), (HALF, HALF), (-HALF, HALF), (-HALF, -HALF))[side] + (0.0,))
        for k in range(1, BARS_PER_SIDE + 1):
            t = k / (BARS_PER_SIDE + 1)
            x = a.x + (b.x - a.x) * t
            z = a.y + (b.y - a.y) * t
            bar = Part("cage_bar_%d" % n, (x, (BASE + POST_TOP) * 0.5, z))
            bar.rod((x, BASE, z), (x, POST_TOP, z), 0.017, "iron")
            made.append(bar.done())
            n += 1
    lock = Part("cage_lock", (0.1, 0.55, HALF + 0.04))
    # (hung on a bar)
    lock.box((0.1, 0.52, HALF + 0.04), (0.14, 0.12, 0.05), "brass")
    lock.rod((0.1, 0.58, HALF + 0.07), (0.1, 0.66, HALF + 0.07), 0.012, "iron")
    lock.rod((0.1, 0.58, HALF - 0.02), (0.1, 0.66, HALF - 0.02), 0.012, "iron")
    lock.rod((0.1, 0.66, HALF - 0.02), (0.1, 0.66, HALF + 0.07), 0.012, "iron")
    made.append(lock.done())
    return made


def look(folder, objs):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.render.resolution_x, scene.render.resolution_y = 400, 400
    scene.world = bpy.data.worlds.new("World") if scene.world is None else scene.world
    scene.world.color = (0.35, 0.42, 0.5)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 1.8
    scene.collection.objects.link(camera)
    scene.camera = camera
    middle = Vector((0.0, 0.0, 0.62))
    for view, direction in (("front", (0, -1, 0.3)), ("side", (1, 0, 0.3)), ("back", (0, 1, 0.3)), ("top", (0.01, 0, 1))):
        offset = Vector(direction).normalized() * 4.0
        camera.location = middle + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "cage_%s.png" % view)
        bpy.ops.render.render(write_still=True)


bpy.ops.wm.read_factory_settings(use_empty=True)
parts = cage()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "tools", "cage.blend"))
bpy.ops.object.select_all(action="DESELECT")
for obj in parts:
    obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT, "models", "cage.glb"), export_format="GLB",
                          export_yup=True, use_selection=True, export_animations=False)
print("BUILT cage parts=%d tris=%d" % (len(parts), sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in parts)))
if PREVIEW_DIR:
    look(PREVIEW_DIR, parts)
