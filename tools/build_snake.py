"""A garter snake for the grove (the user, 2026-11-02: "and snakes": a couple of harmless grass/garter snakes,
striped and slender, slithering, sunning coiled on a warm rock, tongue flicking, sliding off into the grass or the
pond). Built straight, in the raccoon's smooth cartoon style: a tube 0.9 m long from the tail's tip (z = 0) to the
front of its head (z = LENGTH), a pale stripe down its back and one down each side on dark olive, a pale belly, a
rounded head a little wider than its neck, black eyes, and a forked red tongue reaching out past its head (z >
LENGTH). It has no bones: scripts/grove_snake.gd bends it in a vertex shader along a travelling S-wave or into a coil,
and flicks the tongue (every point past LENGTH is the tongue's). Also a flat warm rock for it to sun on.

Run from the project root:
    blender -b --factory-startup --python tools/build_snake.py [-- <folder>]   # the folder gets pictures of it

Writes models/snake.glb, models/snake_rock.glb and tools/snake.blend. Godot axes in the code here: Y up, +Z ahead.
Every colour is Claude's pick after photos of common garter snakes.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOLDER = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1 else None

LENGTH = 0.9
RINGS = 72
ROUND = 16

COLOURS = {
    "snake": (0.16, 0.17, 0.1),
    "stripe": (0.86, 0.78, 0.36),
    "belly": (0.78, 0.8, 0.6),
    "eye": (0.03, 0.03, 0.03),
    "tongue": (0.75, 0.12, 0.12),
    "rock": (0.55, 0.5, 0.44),
    "rock_dark": (0.42, 0.38, 0.33),
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


def radius(t):
    """Half its width at t (0 the tail's tip, 1 the front of its head) and how much flatter it is than round."""
    if t < 0.75:
        r = 0.003 + 0.019 * math.sin(min(1.0, t / 0.6) * math.pi / 2) ** 0.8
    elif t < 0.93:
        # (the neck)
        r = 0.022 - 0.005 * math.sin((t - 0.75) / 0.18 * math.pi / 2)
    else:
        # (the head: wider behind the eyes, rounding off at the snout)
        u = (t - 0.93) / 0.07
        r = (0.017 + 0.009 * math.sin(min(1.0, u / 0.45) * math.pi / 2)) * math.sqrt(max(0.0, 1.0 - max(0.0, u - 0.45) ** 2 / 0.55 ** 2))
    return max(r, 0.0015)


def colour_at(angle):
    """Which colour round the body: angle 0 the top of its back, pi its belly."""
    a = abs((angle + math.pi) % math.tau - math.pi)
    if a < 0.2:
        return "stripe"
    if 1.22 < a < 1.4:
        return "stripe"
    if a > 2.2:
        return "belly"
    return "snake"


def snake():
    bm = bmesh.new()
    names = ["snake", "stripe", "belly", "eye", "tongue"]
    rings = []
    for k in range(RINGS + 1):
        t = k / RINGS
        r = radius(t)
        flat = 0.78 if t > 0.92 else 0.88
        z = t * LENGTH
        ring = []
        for j in range(ROUND):
            a = math.tau * j / ROUND
            # (angle 0 on top)
            ring.append(bm.verts.new(to_blender((math.sin(a) * r, math.cos(a) * r * flat, z))))
        rings.append(ring)
    for k in range(RINGS):
        for j in range(ROUND):
            a = math.tau * (j + 0.5) / ROUND
            face = bm.faces.new((rings[k][j], rings[k][(j + 1) % ROUND], rings[k + 1][(j + 1) % ROUND], rings[k + 1][j]))
            # (the head is all dark above, pale below)
            name = colour_at(a) if k / RINGS < 0.93 else ("belly" if abs(math.pi - a) < 0.9 else "snake")
            face.material_index = names.index(name)
    tail = bm.verts.new(to_blender((0.0, 0.0, -0.004)))
    nose = bm.verts.new(to_blender((0.0, 0.0, LENGTH + 0.002)))
    for j in range(ROUND):
        bm.faces.new((rings[0][(j + 1) % ROUND], rings[0][j], tail)).material_index = 0
        bm.faces.new((rings[-1][j], rings[-1][(j + 1) % ROUND], nose)).material_index = 0

    def ball(centre, radii, mat, segs=8):
        made = bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=segs // 2 + 1, radius=1.0)
        for v in made["verts"]:
            p = Vector((v.co.x * radii[0], v.co.z * radii[1], v.co.y * radii[2])) + Vector(centre)
            v.co = to_blender(p)
        for f in {f for v in made["verts"] for f in v.link_faces}:
            f.material_index = names.index(mat)

    # Eyes, either side of the head behind the snout
    for side in (1.0, -1.0):
        ball((side * 0.019, 0.006, LENGTH - 0.03), (0.006, 0.007, 0.007), "eye")
    # The tongue: a thin red stem out past the snout, forked at its end (every point of it past LENGTH)
    for side in (1.0, -1.0):
        pts = [(0.0, -0.004, LENGTH + 0.001), (0.0, -0.004, LENGTH + 0.03), (side * 0.008, -0.002, LENGTH + 0.045)]
        for a, b in zip(pts, pts[1:]):
            ra, rb = 0.0016, 0.0011
            ahead = (Vector(b) - Vector(a)).normalized()
            u = ahead.cross(Vector((0, 1, 0))).normalized()
            w = ahead.cross(u)
            loops = [[bm.verts.new(to_blender(Vector(end) + (u * math.cos(s) + w * math.sin(s)) * rr))
                      for s in (math.tau * q / 5 for q in range(5))] for end, rr in ((a, ra), (b, rb))]
            for q in range(5):
                bm.faces.new((loops[0][q], loops[0][(q + 1) % 5], loops[1][(q + 1) % 5], loops[1][q])).material_index = names.index("tongue")
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.00005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new("snake")
    bm.to_mesh(mesh)
    bm.free()
    for name in names:
        mesh.materials.append(material(name))
    for poly in mesh.polygons:
        poly.use_smooth = True
    obj = bpy.data.objects.new("snake", mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def rock():
    """A low flat boulder, warm in the sun, about 0.7 m across and 0.25 m high, its top at ROCK_TOP."""
    bm = bmesh.new()
    rng = random.Random(9)
    made = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    for v in made["verts"]:
        p = Vector((v.co.x, v.co.z, v.co.y))
        squash = Vector((0.38 * rng.uniform(0.92, 1.08), 0.16 if p.y > 0 else 0.1, 0.32 * rng.uniform(0.92, 1.08)))
        q = Vector((p.x * squash.x, p.y * squash.y + 0.1, p.z * squash.z))
        if p.y > 0.55:
            # (a flattish top)
            q.y = 0.1 + 0.16 * 0.6 + (p.y - 0.55) * 0.12
        v.co = to_blender(q)
    for f in bm.faces:
        f.material_index = 0 if f.calc_center_median().z > 0.12 else 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new("snake_rock")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(material("rock"))
    mesh.materials.append(material("rock_dark"))
    obj = bpy.data.objects.new("snake_rock", mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def export(obj, name):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT, "models", name + ".glb"), export_format="GLB",
                              export_yup=True, use_selection=True, export_animations=False)
    print("BUILT %s tris=%d" % (name, sum(len(p.vertices) - 2 for p in obj.data.polygons)))


def look(folder, objs):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.render.resolution_x, scene.render.resolution_y = 500, 500
    scene.world = bpy.data.worlds.new("World") if scene.world is None else scene.world
    scene.world.color = (0.35, 0.42, 0.5)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.type = "ORTHO"
    scene.collection.objects.link(camera)
    scene.camera = camera
    for name, middle, scale, views in (
            ("snake", Vector((0.0, -0.45, 0.02)), 1.0, (("top", (0.001, 0, 1)), ("side", (1, 0, 0.1)), ("quarter", (1, -1, 0.6)))),
            ("snake_head", Vector((0.0, -0.86, 0.01)), 0.14, (("top", (0.001, 0, 1)), ("side", (1, 0, 0.05)), ("front", (0, -1, 0.3)))),
            ("snake_rock", Vector((1.5, 0.0, 0.12)), 1.0, (("side", (1, 0.3, 0.3)), ("top", (0.001, 0, 1))))):
        camera.data.ortho_scale = scale
        for view, direction in views:
            offset = Vector(direction).normalized() * 4.0
            camera.location = middle + offset
            camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
            bpy.ops.render.render(write_still=True)


bpy.ops.wm.read_factory_settings(use_empty=True)
body = snake()
stone = rock()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "tools", "snake.blend"))
export(body, "snake")
export(stone, "snake_rock")
if FOLDER:
    stone.location.x = 1.5
    look(FOLDER, [body, stone])
