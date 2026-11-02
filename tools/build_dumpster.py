"""A dumpster to jump into (the user, 2026-11-02: "there should be dumpsters to jump into"): a big green steel bin on
four castors, open-topped with a thick rim, two black plastic lids hinged at the back (the left one thrown open
against the back, the right one shut), handles at the ends and a dent or two. Separate objects so the game can give
them their own collision: dumpster_body (the hollow bin: floor and four walls, open at the top), dumpster_lid_open,
dumpster_lid_shut, dumpster_wheels. About 1.8 m long, 1.1 m deep, 1.15 m to the rim: he jumps in from a wall or a
box, scurries up its side to get out. Standing on y = 0, its front (the lids' free edge) facing +Z.

Run from the project root:
    blender -b --factory-startup --python tools/build_dumpster.py [-- <folder>]   # the folder gets a picture from four sides

Writes models/dumpster.glb and tools/dumpster.blend. Godot axes in the code here: Y up, +Z ahead. Coloured by material
name only (the game's Toon shader shades it).
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
    "bin_green": (0.18, 0.42, 0.27),
    "bin_inside": (0.1, 0.2, 0.13),
    "lid_black": (0.1, 0.1, 0.11),
    "rust": (0.48, 0.27, 0.15),
    "wheel": (0.08, 0.08, 0.08),
    "steel": (0.55, 0.56, 0.58),
}

LONG = 1.8
DEEP = 1.1
RIM = 1.15
FLOOR = 0.2
WALL = 0.05


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
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []

    def _index(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def box(self, centre, size, mat, turn=0.0, pivot=None):
        """A box; `turn` radians about X through `pivot` (for the open lid)."""
        index = self._index(mat)
        c = Vector(centre)
        h = Vector(size) * 0.5
        pv = Vector(pivot) if pivot else c
        corners = []
        for x in (-1, 1):
            for y in (-1, 1):
                for z in (-1, 1):
                    p = c + Vector((x * h.x, y * h.y, z * h.z)) - pv
                    p = Vector((p.x, p.y * math.cos(turn) - p.z * math.sin(turn), p.y * math.sin(turn) + p.z * math.cos(turn))) + pv
                    corners.append(self.bm.verts.new(to_blender(p)))
        for quad in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
            self.bm.faces.new([corners[k] for k in quad]).material_index = index

    def wheel(self, centre, radius, width, mat, segments=10):
        index = self._index(mat)
        c = Vector(centre)
        rings = [[self.bm.verts.new(to_blender(c + Vector((side * width * 0.5, math.cos(a) * radius, math.sin(a) * radius))))
                  for a in (math.tau * k / segments for k in range(segments))] for side in (-1, 1)]
        for k in range(segments):
            j = (k + 1) % segments
            self.bm.faces.new((rings[0][k], rings[0][j], rings[1][j], rings[1][k])).material_index = index
        self.bm.faces.new(rings[0][::-1]).material_index = index
        self.bm.faces.new(rings[1]).material_index = index

    def done(self):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts[:], dist=0.0001)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces[:])
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for name in self.mats:
            mesh.materials.append(material(name))
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.collection.objects.link(obj)
        return obj


def dumpster():
    made = []
    body = Part("dumpster_body")
    hx, hz = LONG * 0.5, DEEP * 0.5
    # Floor, and the four walls, each a box (inside a darker green), the rim a thick lip round the top
    body.box((0.0, FLOOR + 0.03, 0.0), (LONG, 0.06, DEEP), "bin_inside")
    for z in (-hz + WALL * 0.5, hz - WALL * 0.5):
        body.box((0.0, (FLOOR + RIM) * 0.5, z), (LONG, RIM - FLOOR, WALL), "bin_green")
    for x in (-hx + WALL * 0.5, hx - WALL * 0.5):
        body.box((x, (FLOOR + RIM) * 0.5, 0.0), (WALL, RIM - FLOOR, DEEP - 2 * WALL), "bin_green")
    for z in (-hz, hz):
        body.box((0.0, RIM, z), (LONG + 0.06, 0.06, 0.09), "bin_green")
    for x in (-hx, hx):
        body.box((x, RIM, 0.0), (0.09, 0.06, DEEP + 0.06), "bin_green")
    # Ribs down the front and the back, a rusty dent, handles at the ends, the frame under it
    for x in (-0.6, 0.0, 0.6):
        for z in (-hz - 0.02, hz + 0.02):
            body.box((x, (FLOOR + RIM) * 0.5, z), (0.06, RIM - FLOOR - 0.1, 0.03), "bin_green")
    body.box((0.35, 0.55, hz + 0.035), (0.22, 0.14, 0.012), "rust")
    for x in (-hx - 0.06, hx + 0.06):
        body.box((x, 0.8, 0.0), (0.04, 0.04, 0.6), "steel")
    body.box((0.0, FLOOR - 0.04, 0.0), (LONG - 0.1, 0.08, DEEP - 0.1), "steel")
    made.append(body.done())
    # The lids, each half the length: the left flung over, hanging down the back, the right shut
    opened = Part("dumpster_lid_open")
    opened.box((-hx * 0.5, RIM + 0.05, 0.0), (LONG * 0.5 - 0.02, 0.05, DEEP + 0.08), "lid_black",
               turn=-4.6, pivot=(-hx * 0.5, RIM + 0.05, -hz - 0.04))
    made.append(opened.done())
    shut = Part("dumpster_lid_shut")
    shut.box((hx * 0.5, RIM + 0.05, 0.0), (LONG * 0.5 - 0.02, 0.05, DEEP + 0.08), "lid_black")
    made.append(shut.done())
    wheels = Part("dumpster_wheels")
    for x in (-hx + 0.15, hx - 0.15):
        for z in (-hz + 0.15, hz - 0.15):
            wheels.wheel((x, 0.08, z), 0.08, 0.06, "wheel")
            wheels.box((x, 0.15, z), (0.08, 0.06, 0.08), "steel")
    made.append(wheels.done())
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
    camera.data.ortho_scale = 2.6
    scene.collection.objects.link(camera)
    scene.camera = camera
    middle = Vector((0.0, 0.0, 0.7))
    for view, direction in (("front", (0, -1, 0.3)), ("side", (1, 0, 0.3)), ("back", (0, 1, 0.3)), ("top", (0.01, 0, 1))):
        offset = Vector(direction).normalized() * 5.0
        camera.location = middle + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "dumpster_%s.png" % view)
        bpy.ops.render.render(write_still=True)


bpy.ops.wm.read_factory_settings(use_empty=True)
parts = dumpster()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "tools", "dumpster.blend"))
bpy.ops.object.select_all(action="DESELECT")
for obj in parts:
    obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT, "models", "dumpster.glb"), export_format="GLB",
                          export_yup=True, use_selection=True, export_animations=False)
print("BUILT dumpster parts=%d tris=%d" % (len(parts), sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in parts)))
if PREVIEW_DIR:
    look(PREVIEW_DIR, parts)
