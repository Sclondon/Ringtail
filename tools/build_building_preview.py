"""A row of generated buildings (tools/buildings.py) on a lawn, to look at and to run tests/building_routes.gd on.

Run from the project root:
    blender -b --factory-startup --python tools/build_building_preview.py -- <folder|-> [kind|all] [seed[,seed...]] [turn]

Writes models/buildings_preview.glb (each building with its route marked: route_<name>_<i>_<how>, its ladders) and
tools/buildings_preview.blend, prints each route's problems, and with a folder puts in it each building from four sides
and above (<name>_<view>.png) and a strip of all four (<name>.png).
"""

import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_world1 as w1  # noqa: E402
import buildings  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
FOLDER = args[0] if args and args[0] != "-" else None
KIND = args[1] if len(args) > 1 else "all"
SEEDS = [int(v) for v in args[2].split(",")] if len(args) > 2 else [1]
TURN = float(args[3]) if len(args) > 3 else 0.0
SPACING = 80.0


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kinds = list(buildings.KINDS) if KIND == "all" else KIND.split(",")
    made = []
    for row, seed in enumerate(SEEDS):
        for col, kind in enumerate(kinds):
            name = "b_%s_%d" % (kind, seed)
            x, z = col * SPACING, row * SPACING
            one = buildings.make(kind, name, x, 0.0, z, TURN, seed, marks=False, crumbs=0)
            buildings.route_marks(one)
            made.append((one, (x, z)))
            print("ROUTE %s links %d top %.1f %s" % (name, len(one["route"]) - 1, one["top"][1],
                                                     "ok" if not one["problems"] else "PROBLEMS " + "; ".join("%d: %s" % p for p in one["problems"])))
    ground = w1.Piece("ground")
    width = len(kinds) * SPACING
    depth = len(SEEDS) * SPACING
    ground.box((width / 2 - SPACING / 2, -0.25, depth / 2 - SPACING / 2), (width + 40.0, 0.5, depth + 40.0), "grass")
    ground.done()
    w1.mark("spawn", (0.0, 0.0, 30.0))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(w1.ROOT, "tools", "buildings_preview.blend"))
    bpy.ops.export_scene.gltf(filepath=os.path.join(w1.ROOT, "models", "buildings_preview.glb"), export_format="GLB",
                              export_yup=True, export_animations=False, export_vertex_color="ACTIVE", export_extras=False)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == "MESH")
    print("BUILT preview buildings=%d tris=%d" % (len(made), tris))
    return made


def look(folder, made):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.render.resolution_x, scene.render.resolution_y = 520, 520
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.75, 0.85, 0.95)
    scene.display.shading.studio_light = "outdoor.sl" if "outdoor.sl" in [l.name for l in bpy.context.preferences.studio_lights] else scene.display.shading.studio_light
    for obj in bpy.data.objects:
        if obj.name.endswith("_hidden") or obj.name.startswith("hidden_"):
            obj.hide_render = True
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.type = "ORTHO"
    camera.data.clip_end = 600.0
    scene.collection.objects.link(camera)
    scene.camera = camera
    for one, (x, z) in made:
        b = one["bounds"]
        cx, cz = x + (b[0] + b[2]) / 2, z + (b[1] + b[3]) / 2
        size = max(b[2] - b[0], b[3] - b[1], one["top"][1] + 2.0) * 1.1
        camera.data.ortho_scale = size
        middle = Vector((cx, -cz, size * 0.3))
        files = []
        for view, direction in (("front", (0, 1, 0.35)), ("side", (1, 0, 0.35)), ("back", (0, -1, 0.35)), ("other", (-1, 0, 0.35)),
                                ("above", (0.3, 0.6, 1.0))):
            # (Blender's axes: its -Y is Godot's +Z, the buildings' fronts)
            offset = Vector((direction[0], -direction[1], direction[2])).normalized() * 200.0
            camera.location = middle + offset
            camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
            path = os.path.join(folder, "%s_%s.png" % (one["name"], view))
            scene.render.filepath = path
            bpy.ops.render.render(write_still=True)
            files.append(path)


made = build()
if FOLDER:
    os.makedirs(FOLDER, exist_ok=True)
    look(FOLDER, made)
