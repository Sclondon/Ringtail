"""A lower-poly boy for crowds, the way Gloaming made its man low (Gloaming's tools/build_man_tp.py): every mesh
of models/boy.glb collapsed to a budget, mirrored left to right, its skin weights, UVs and materials carried through.
Every slot and option keeps its name, so CharacterLook, CharacterRig.restyle and HeadShape (the faceless mask heads,
made at run time from `boy_head__base`) work on it as on him.

    blender -b --factory-startup --python tools/build_boy_tp.py

Writes models/boy_tp.glb (and tools/boy_tp.blend). Ringtail's town people wear it (the user, 2026-11-02: "you should
also make a lower poly version of the people like I did for Gloaming"). models/boy_lo.glb is another thing: the boy
built again with fewer rings (build_boy.py's LOW), coarser than this in the head (200 triangles, too few to reshape
into a mask).
"""

import os

import bpy
from mathutils import kdtree
from mathutils.bvhtree import BVHTree

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

## Triangles each mesh is brought down to, by its name after `boy_`. A body (what shows of him under his clothes is
## part of it) and the heads have their own budgets; anything else keeps PIECE_SHARE of its own, within PIECE_TRIS
## (Gloaming kept 3%, its pieces being much denser: here that left every hair a 120-triangle lump).
BUDGET = {"body": 1300, "boy": 900, "head": 650, "boots": 300, "feet": 240, "skirt": 500, "over": 400}
PIECE_SHARE = 0.2
PIECE_TRIS = (120, 400)
## Kept as they are: the faces (eyes and mouths, a few hundred triangles each) and the knee patch.
KEEP = ("face", "patch")
## How freely each point may be collapsed (the Decimate's vertex group), by the bones it follows: the head, neck and
## hands held closer than the rest, as Gloaming's FREEDOM.
FREEDOM = {"head": 0.34, "neck": 0.32, "hand": 0.3, "finger": 0.3, "thumb": 0.3}
BODY_FREEDOM = 0.3
## The open edges (hems, cuffs, the edges of a bib or a fringe) held as Gloaming held the lids: collapsed freely they
## drew in ragged, and showed what was under them.
HEM_WEIGHT = 0.03
## Edges sharper than this stay hard when it is shaded smooth again (radians).
SMOOTH_ANGLE = 0.9
## What is worn, and what it is worn on (clear_of_body), by slot; how far a worn point is kept out from the low body
## at least (Gloaming's LAYERS: the coarser a piece the further, or the body shows through between its
## points), how near a high body it must have lain to be worn on it, how far inside it may have been hidden, and how
## thick a piece's shell is (all metres).
WORN = ("over", "skirt", "hair", "hairtop", "cap", "boots", "patch")
UNDER = ("body", "boy", "head", "feet", "skirt")
CLEAR = {"over": 0.012, "skirt": 0.008, "hair": 0.008, "hairtop": 0.008, "cap": 0.008, "boots": 0.006, "patch": 0.005}
NEAR = 0.03
INSIDE = 0.01
THICK = 0.02


def triangles(mesh):
    return sum(len(p.vertices) - 2 for p in mesh.polygons)


def slot_of(obj):
    name = obj.name
    if name == "boy":
        return "boy"
    return name[len("boy_"):].split("__")[0]


def target_of(obj, tris):
    slot = slot_of(obj)
    if slot in KEEP:
        return tris
    if slot in BUDGET:
        return min(tris, BUDGET[slot])
    return min(tris, max(PIECE_TRIS[0], min(PIECE_TRIS[1], int(tris * PIECE_SHARE))))


def keep_group(obj):
    group = obj.vertex_groups.new(name="_keep")
    free = {}
    for g in obj.vertex_groups:
        for prefix, f in FREEDOM.items():
            if g.name.startswith(prefix):
                free[g.index] = f
    for v in obj.data.vertices:
        total = sum(e.weight for e in v.groups if e.group != group.index)
        w = sum(e.weight * free.get(e.group, BODY_FREEDOM) for e in v.groups if e.group != group.index)
        group.add([v.index], w / total if total > 0.0 else BODY_FREEDOM, "REPLACE")
    faces = {}
    for p in obj.data.polygons:
        for key in p.edge_keys:
            faces[key] = faces.get(key, 0) + 1
    hems = {i for key, n in faces.items() if n == 1 for i in key}
    if hems:
        group.add(list(hems), HEM_WEIGHT, "REPLACE")
    return group


def lower(obj):
    tris = triangles(obj.data)
    goal = target_of(obj, tris)
    if goal >= tris * 0.9:
        print("TP %s kept (%d tris)" % (obj.name, tris))
        return tris, tris
    armature = [m for m in obj.modifiers if m.type == "ARMATURE"]
    target = armature[0].object if armature else None
    for m in list(obj.modifiers):
        obj.modifiers.remove(m)
    group = keep_group(obj)
    decimate = obj.modifiers.new("Decimate", "DECIMATE")
    decimate.decimate_type = "COLLAPSE"
    decimate.ratio = goal / float(tris)
    decimate.use_symmetry = True
    decimate.symmetry_axis = "X"
    decimate.vertex_group = group.name
    decimate.vertex_group_factor = 1.0
    bpy.context.view_layer.objects.active = obj
    with bpy.context.temp_override(object=obj, active_object=obj):
        bpy.ops.object.modifier_apply(modifier=decimate.name)
    obj.vertex_groups.remove(obj.vertex_groups["_keep"])
    if target:
        obj.modifiers.new("Armature", "ARMATURE").object = target
    # (shaded smooth again by angle: the glTF's normals, carried through the collapse, went to ragged dark facets)
    with bpy.context.temp_override(object=obj, active_object=obj, selected_objects=[obj], selected_editable_objects=[obj]):
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
        bpy.ops.object.shade_smooth_by_angle(angle=SMOOTH_ANGLE)
    made = triangles(obj.data)
    print("TP %s %d -> %d tris" % (obj.name, tris, made))
    return tris, made


def surface(obj, mesh=None):
    """A BVH of `obj`'s surface (or of `mesh` in its place), in world space."""
    mesh = mesh or obj.data
    mesh.calc_loop_triangles()
    points = [obj.matrix_world @ v.co for v in mesh.vertices]
    return BVHTree.FromPolygons(points, [tuple(t.vertices) for t in mesh.loop_triangles], all_triangles=True)


def clear_of_body(highs):
    """Every piece worn kept as clear of the low body under it as it was of the high one (at least CLEAR): each of its
    points that came closer pushed out along the body's normal there, as far as the most any point within THICK of
    it needs (a piece is a shell, and pushed alone its inside came out through its outside). Without it the body
    came through the coarser clothes in blots (Gloaming's _clear_of_body; here the pinafore through the dress). A
    piece is worn on every body or head it lay within NEAR of."""
    unders = [o for o in bpy.data.objects if o.type == "MESH" and slot_of(o) in UNDER]
    trees = {o.name: (surface(o, highs[o.name]), surface(o)) for o in unders}
    for obj in bpy.data.objects:
        if obj.type != "MESH" or slot_of(obj) not in WORN:
            continue
        world = obj.matrix_world
        points = [world @ v.co for v in obj.data.vertices]
        need = {}
        normals = {}
        for name, (high, low) in trees.items():
            if name == obj.name:
                continue
            for i, co in enumerate(points):
                hit, normal, _f, distance = high.find_nearest(co)
                if hit is None or distance > NEAR:
                    continue
                was = (co - hit).dot(normal)
                if was < -INSIDE:
                    continue
                hit, normal, _f, _d = low.find_nearest(co)
                now = (co - hit).dot(normal)
                short = max(was, CLEAR[slot_of(obj)]) - now
                if short > need.get(i, 0.0):
                    need[i] = short
                    normals[i] = normal
        if not need:
            continue
        near = kdtree.KDTree(len(points))
        for i, co in enumerate(points):
            near.insert(co, i)
        near.balance()
        moved = 0
        back = world.inverted().to_3x3()
        for i, co in enumerate(points):
            found = [(need[j], j) for _co, j, _d in near.find_range(co, THICK) if j in need]
            if found:
                most, j = max(found)
                obj.data.vertices[i].co += back @ (normals[j] * most)
                moved += 1
        print("TP %s: %d points pushed clear" % (obj.name, moved))


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # (the glTF's points are split at every seam and hard edge: merged again, so the collapse cannot open the seams;
    # the bones laid along their glTF +Y, so they go out again exactly as they came in: another way they came out
    # turned, and the rig's poses on them wrong)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "models", "boy.glb"), merge_vertices=True,
                              bone_heuristic="BLENDER")
    highs = {o.name: o.data.copy() for o in bpy.data.objects if o.type == "MESH"}
    before = after = 0
    for obj in sorted(bpy.data.objects, key=lambda o: o.name):
        if obj.type == "MESH":
            high, low = lower(obj)
            before += high
            after += low
    clear_of_body(highs)
    for mesh in highs.values():
        bpy.data.meshes.remove(mesh)
    print("TP all %d -> %d tris" % (before, after))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "tools", "boy_tp.blend"))
    for obj in bpy.data.objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(ROOT, "models", "boy_tp.glb"),
        export_format="GLB",
        export_yup=True,
        export_animations=False,
        export_skins=True,
        export_morph=False,
    )
    print("BUILT boy_tp")


main()
