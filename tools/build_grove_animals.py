"""The grove's other animals (the user, 2026-11-02: "there should be the other animals in the grove too for me to see -
skunk and beavers and rats and mice and rabbits and weasels and martens and otters", "gophers, prairie dogs", then
"opossums", "squirrels", "porcupine", "chipmunk"), built as the fox, skunk, badger and rabbit are (tools/
build_critters.py): on the boy's skeleton with a six-bone tail, through the raccoon's `reshape` with each animal's
own proportions, in the raccoon's cartoon style. Every look here (colours, proportions, ears, tails) is Claude's pick
after reference photos. scripts/critter_rig.gd poses them; scripts/grove_animals.gd puts them in the grove.

Run from the project root, one animal a run:
    blender -b --factory-startup --python tools/build_grove_animals.py -- <picture folder or -> <animal>
animals: beaver rat mouse weasel marten otter gopher prairie_dog opossum squirrel porcupine chipmunk

Writes models/<animal>.glb and models/<animal>_lo.glb (and editable copies in tools/). Then: godot --headless --path . --import
"""

import math
import os
import random
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_critters as cr  # noqa: E402

kit, racc = cr.kit, cr.racc
X, Y, Z = kit.X, kit.Y, kit.Z
HC = racc.HEAD_CENTRE
HEAD_FRONT = cr.HEAD_FRONT

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
FOLDER = ARGS[0] if ARGS and ARGS[0] != "-" else None
ANIMAL = ARGS[1] if len(ARGS) > 1 else "beaver"

# The body's half depth (front to back, as drawn) at a height, for laying things along its back.
BODY_DEPTH = [(0.40, 0.08), (0.44, 0.125), (0.50, 0.152), (0.58, 0.162), (0.66, 0.152), (0.73, 0.132), (0.79, 0.112),
              (0.83, 0.09), (0.88, 0.072)]
BODY_WIDTH = [(0.40, 0.08), (0.44, 0.145), (0.50, 0.178), (0.58, 0.188), (0.66, 0.178), (0.73, 0.158), (0.79, 0.142),
              (0.83, 0.10), (0.88, 0.072)]


def along(table, y):
    for (a, ra), (b, rb) in zip(table, table[1:]):
        if y <= b:
            return ra + (rb - ra) * max(0.0, (y - a)) / (b - a)
    return table[-1][1]


# What each animal is (Claude's picks after photos): proportions; colours; its muzzle, ears, cheeks, teeth, tail.
SPECIES = {
    "beaver": dict(leg=0.6, arm=0.65, head=1.12, wide=1.35, long=1.12,
                   colours=dict(fur=(0.45, 0.29, 0.17), light=(0.62, 0.45, 0.3), dark=(0.16, 0.11, 0.08), limb=(0.2, 0.14, 0.1),
                                pink=(0.25, 0.17, 0.12), teeth=(0.95, 0.55, 0.18)),
                   muzzle=(0.07, 0.065, 0.05, 0.04), nose=(0.026, "dark"), ears=("round", 0.022, "fur"), cheeks=(0.9, "light"),
                   teeth=1.6, tail=dict(style="paddle", dir=(0.0, -0.1, -1.0), length=0.42, colour="dark")),
    "rat": dict(leg=0.72, arm=0.72, head=1.0, wide=0.85, long=1.12,
                colours=dict(fur=(0.42, 0.38, 0.35), light=(0.68, 0.63, 0.58), dark=(0.15, 0.12, 0.12), limb=(0.86, 0.6, 0.6),
                             pink=(0.92, 0.62, 0.64), teeth=(0.95, 0.85, 0.55)),
                muzzle=(0.13, 0.045, 0.04, 0.03), nose=(0.016, "pink"), ears=("round", 0.04, "pink"), teeth=0.8,
                tail=dict(style="bare", dir=(0.0, 0.05, -1.0), length=0.75, profile=[(0.0, 0.035), (1.0, 0.01)], colour="pink")),
    "mouse": dict(leg=0.72, arm=0.72, head=1.28, wide=0.9, long=1.0,
                  colours=dict(fur=(0.6, 0.47, 0.34), light=(0.92, 0.86, 0.76), dark=(0.15, 0.1, 0.08), limb=(0.92, 0.7, 0.68),
                               pink=(0.95, 0.66, 0.7), teeth=(0.95, 0.9, 0.7)),
                  muzzle=(0.09, 0.04, 0.036, 0.03), nose=(0.014, "pink"), ears=("round", 0.065, "pink"), bib="light",
                  tail=dict(style="bare", dir=(0.0, 0.1, -1.0), length=0.7, profile=[(0.0, 0.04), (1.0, 0.01)], colour="pink")),
    "weasel": dict(leg=0.55, arm=0.6, head=0.95, wide=0.72, long=1.6,
                   colours=dict(fur=(0.52, 0.33, 0.18), light=(0.96, 0.92, 0.8), dark=(0.12, 0.09, 0.07), limb=(0.45, 0.28, 0.15)),
                   muzzle=(0.07, 0.045, 0.04, 0.035), nose=(0.016, "dark"), ears=("round", 0.025, "fur"), bib="light",
                   tail=dict(style="bushy", dir=(0.0, 0.1, -1.0), length=0.38, profile=[(0.0, 0.05), (0.5, 0.07), (1.0, 0.05)],
                             pattern=["fur"] * 6 + ["dark", "dark"])),
    "marten": dict(leg=0.65, arm=0.7, head=1.0, wide=0.85, long=1.4,
                   colours=dict(fur=(0.33, 0.21, 0.13), light=(0.98, 0.8, 0.45), dark=(0.18, 0.11, 0.07), limb=(0.2, 0.13, 0.09)),
                   muzzle=(0.08, 0.05, 0.042, 0.035), nose=(0.017, "dark"), ears=("round", 0.04, "fur"), bib="light",
                   tail=dict(style="bushy", dir=(0.0, 0.15, -1.0), length=0.62, profile=[(0.0, 0.06), (0.4, 0.11), (1.0, 0.07)],
                             pattern=["fur"] * 4 + ["dark"] * 4), ruffs=True),
    "otter": dict(leg=0.55, arm=0.6, head=1.05, wide=1.0, long=1.45,
                  colours=dict(fur=(0.36, 0.25, 0.17), light=(0.72, 0.6, 0.47), dark=(0.12, 0.08, 0.06), limb=(0.3, 0.2, 0.14)),
                  muzzle=(0.06, 0.07, 0.05, 0.04), nose=(0.024, "dark"), ears=("round", 0.018, "fur"), bib="light",
                  cheeks=(0.8, "light"),
                  tail=dict(style="bare", dir=(0.0, -0.05, -1.0), length=0.6, profile=[(0.0, 0.085), (0.5, 0.06), (1.0, 0.02)],
                            colour="fur")),
    "gopher": dict(leg=0.55, arm=0.65, head=1.22, wide=1.25, long=0.95,
                   colours=dict(fur=(0.55, 0.4, 0.24), light=(0.8, 0.66, 0.46), dark=(0.15, 0.1, 0.07), limb=(0.75, 0.55, 0.45),
                                pink=(0.85, 0.6, 0.55), teeth=(0.96, 0.8, 0.45)),
                   muzzle=(0.05, 0.05, 0.045, 0.035), nose=(0.018, "pink"), ears=("round", 0.016, "fur"), cheeks=(1.35, "fur"),
                   teeth=1.3, small_eyes=True,
                   tail=dict(style="bare", dir=(0.0, 0.0, -1.0), length=0.16, profile=[(0.0, 0.05), (1.0, 0.02)], colour="pink")),
    "prairie_dog": dict(leg=0.7, arm=0.65, head=1.1, wide=1.15, long=1.0,
                        colours=dict(fur=(0.72, 0.56, 0.36), light=(0.9, 0.78, 0.6), dark=(0.18, 0.12, 0.08), limb=(0.6, 0.45, 0.3),
                                     teeth=(0.96, 0.88, 0.6)),
                        muzzle=(0.05, 0.05, 0.042, 0.035), nose=(0.017, "dark"), ears=("round", 0.018, "fur"), bib="light",
                        teeth=0.9,
                        tail=dict(style="bushy", dir=(0.0, 0.2, -1.0), length=0.16, profile=[(0.0, 0.04), (1.0, 0.04)],
                                  pattern=["fur", "fur", "dark"], count=3)),
    "opossum": dict(leg=0.68, arm=0.72, head=1.08, wide=1.0, long=1.1,
                    colours=dict(fur=(0.58, 0.58, 0.6), light=(0.97, 0.96, 0.95), dark=(0.1, 0.09, 0.1), limb=(0.12, 0.11, 0.12),
                                 pink=(0.95, 0.68, 0.72)),
                    muzzle=(0.14, 0.045, 0.04, 0.03), nose=(0.018, "pink"), ears=("round", 0.04, "dark"), head_colour="light",
                    tail=dict(style="bare", dir=(0.0, 0.0, -1.0), length=0.6, profile=[(0.0, 0.055), (1.0, 0.012)], colour="pink"),
                    ruffs=True),
    "squirrel": dict(leg=0.8, arm=0.72, head=1.15, wide=0.9, long=1.05,
                     colours=dict(fur=(0.66, 0.36, 0.18), light=(0.95, 0.88, 0.76), dark=(0.3, 0.16, 0.08), limb=(0.55, 0.3, 0.15),
                                  teeth=(0.96, 0.88, 0.6)),
                     muzzle=(0.05, 0.045, 0.04, 0.03), nose=(0.015, "dark"), ears=("pointed", 0.08, "fur"), bib="light", teeth=0.8,
                     tail=dict(style="bushy", dir=(0.0, 1.0, -0.45), length=0.66, profile=[(0.0, 0.07), (0.3, 0.13), (1.0, 0.1)],
                               pattern=["fur"] * 8, flare=1.45)),
    "porcupine": dict(leg=0.55, arm=0.62, head=1.0, wide=1.3, long=1.05,
                      colours=dict(fur=(0.3, 0.24, 0.19), light=(0.92, 0.88, 0.78), dark=(0.12, 0.1, 0.08), limb=(0.15, 0.12, 0.1),
                                   quill=(0.88, 0.84, 0.74)),
                      muzzle=(0.06, 0.05, 0.045, 0.035), nose=(0.022, "dark"), ears=("round", 0.016, "fur"), quills=True,
                      tail=dict(style="bushy", dir=(0.0, -0.1, -1.0), length=0.22, profile=[(0.0, 0.06), (1.0, 0.05)],
                                pattern=["fur", "fur", "fur"], count=3)),
    "chipmunk": dict(leg=0.75, arm=0.7, head=1.2, wide=0.95, long=1.0,
                     colours=dict(fur=(0.7, 0.47, 0.27), light=(0.96, 0.9, 0.78), dark=(0.18, 0.11, 0.07), limb=(0.6, 0.4, 0.24),
                                  teeth=(0.96, 0.88, 0.6)),
                     muzzle=(0.045, 0.04, 0.036, 0.03), nose=(0.014, "dark"), ears=("round", 0.03, "fur"), cheeks=(1.25, "fur"),
                     bib="light", stripes=True, teeth=0.7,
                     tail=dict(style="bushy", dir=(0.0, 0.7, -0.7), length=0.42, profile=[(0.0, 0.04), (0.5, 0.07), (1.0, 0.05)],
                               pattern=["fur"] * 8)),
}

# How big each is drawn beside the raccoon (the skeleton is his): scripts/critter.gd's SIZES carries the same.
SIZES = {"beaver": 1.0, "rat": 0.5, "mouse": 0.28, "weasel": 0.6, "marten": 0.75, "otter": 1.0, "gopher": 0.5,
         "prairie_dog": 0.58, "opossum": 0.85, "squirrel": 0.5, "porcupine": 0.9, "chipmunk": 0.38}


def build(name):
    spec = SPECIES[name]
    tail = spec["tail"]
    racc.TAIL_DIR = Vector(tail["dir"]).normalized()
    racc.TAIL_LENGTH = tail["length"]
    profile = tail.get("profile", [(0.0, 0.05), (1.0, 0.04)])
    racc.tail_radius = cr.tail_profile(profile)
    cr.make_reshape(leg=spec["leg"], arm=spec["arm"], head=spec["head"], wide=spec["wide"], long=spec["long"])
    if spec.get("quills"):
        cr.QUILL_BONE[0] = Vector((0.0, 0.62, -0.08))
    names = list(spec["colours"].keys()) + ["eye", "pupil"]
    colours = dict(spec["colours"])
    colours["eye"] = (0.97, 0.97, 0.95)
    colours["pupil"] = (0.03, 0.03, 0.04)
    materials = [(n, colours[n]) for n in names]
    index = {n: k for k, n in enumerate(names)}
    FUR, LIMB = index["fur"], index["limb"]
    m_len, m_wide, m_high, m_drop = spec["muzzle"]

    def muzzle(b):
        cr.snout(b, m_len, m_wide, m_high, m_drop)

    def nose(b):
        r = spec["nose"][0]
        cr.nose_ball(b, Vector((0.0, -m_drop - 0.002, HEAD_FRONT + m_len)), Vector((r * 1.15, r * 0.9, r * 0.9)))

    kind, size, _colour = spec["ears"]

    def ears(b):
        for side in (1.0, -1.0):
            if kind == "pointed":
                base = HC + Vector((side * 0.065, 0.085, -0.03))
                cr.pointed(b, base, base + Vector((side * 0.03, size, -0.01)), 0.035, 0.016)
            else:
                b.ellipsoid(HC + Vector((side * 0.085, 0.085, -0.03)), Vector((size, size * 1.05, size * 0.45)),
                            Matrix.Rotation(side * -0.4, 3, Z), 12, 5)

    def teeth(b):
        big = spec.get("teeth", 1.0)
        for side in (1.0, -1.0):
            b.ellipsoid(HC + Vector((side * 0.011 * big, -m_drop - m_high * 0.75 - 0.01 * big, HEAD_FRONT + m_len * 0.85)),
                        Vector((0.01 * big, 0.02 * big, 0.006 * big)), None, 8, 4)

    def cheeks(b):
        grow = spec["cheeks"][0]
        for side in (1.0, -1.0):
            b.ellipsoid(HC + Vector((side * 0.09, -0.05, 0.04)), Vector((0.06, 0.05, 0.055)) * grow, Matrix.Rotation(side * -0.4, 3, Z), 12, 6)

    def bib(b):
        b.ellipsoid(Vector((0.0, 0.64, 0.115)), Vector((0.1, 0.14, 0.05)), None, 14, 7)

    def stripes(dark):
        def shapes(b):
            # Stripes down its back from the shoulders to the rump, dark and pale by turns
            for k, x in enumerate((-0.07, -0.035, 0.0, 0.035, 0.07)):
                if (k % 2 == 0) != dark:
                    continue
                points = []
                for y in (0.46, 0.55, 0.64, 0.73, 0.8):
                    w = along(BODY_WIDTH, y) * spec["wide"]
                    d = along(BODY_DEPTH, y)
                    z = -d * math.sqrt(max(0.0, 1.0 - (x / max(w, 0.01)) ** 2)) - 0.004
                    points.append(Vector((x, y, z)))
                b.strand(points, [0.014] * len(points), 6)
        return shapes

    def quills(b):
        # A coat of long quills over its back, sides and the back of its head, laid back towards its tail
        rng = random.Random(17)
        for _k in range(140):
            y = rng.uniform(0.42, 0.86)
            a = rng.uniform(0.08, math.pi - 0.08)
            w = along(BODY_WIDTH, y) * spec["wide"]
            d = along(BODY_DEPTH, y)
            root = Vector((w * math.cos(a), y, -d * math.sin(a)))
            out = Vector((math.cos(a) / max(w, 0.01), 0.0, -math.sin(a) / max(d, 0.01))).normalized()
            way = (out * 0.75 - Y * 0.65).normalized()
            length = rng.uniform(0.14, 0.24)
            b.strand([root, root + way * length * 0.5, root + way * length], [0.009, 0.006, 0.0015], 5)

    tail_parts = []
    style = tail["style"]
    if style == "bushy":
        count = tail.get("count", 8)
        pattern = tail["pattern"]
        tail_parts.append(("tail", FUR, racc.tail, (0.006, 3, 3000)))
        for colour in sorted(set(pattern)):
            tail_parts.append(("tail_" + colour, index[colour], cr.cone_part(pattern, colour, count=count, flare=tail.get("flare", 1.3)), None))
    elif style == "paddle":
        def paddle(b):
            # A flat scaly paddle on a short stem
            centre = racc.tail_point(0.55)
            turn = Matrix.Rotation(math.atan2(racc.TAIL_DIR.y, -racc.TAIL_DIR.z), 3, X)
            b.ellipsoid(centre, Vector((0.12, 0.022, 0.19)), turn, 16, 8)
        racc.tail_radius = cr.tail_profile([(0.0, 0.08), (1.0, 0.05)])
        tail_parts.append(("tail", index[tail["colour"]], racc.tail, (0.006, 3, 1500)))
        tail_parts.append(("tail_paddle", index[tail["colour"]], paddle, None))
    else:
        # (bare: the core itself, at the profile's full width: the core is drawn at 0.55 of the radius it is given)
        doubled = [(t, r / 0.55) for t, r in profile]
        racc.tail_radius = cr.tail_profile(doubled)
        tail_parts.append(("tail", index[tail["colour"]], racc.tail, (0.006, 3, 2400)))

    head_colour = index[spec.get("head_colour", "fur")]
    parts = [
        ("body", FUR, racc.body, (0.006, 4, 6000)),
        ("feet", LIMB, racc.feet, (0.004, 3, 2400)),
        ("hands", LIMB, racc.hands, (0.003, 2, 1800)),
        ("head", head_colour, racc.head, (0.005, 4, 3200)),
        ("muzzle", head_colour if spec.get("head_colour") else index["light"], muzzle, None),
        ("nose", index[spec["nose"][1]], nose, None),
        ("eyes", index["eye"], cr.eye_whites, None),
        ("pupils", index["pupil"], cr.eye_pupils, None),
        ("ears", index[spec["ears"][2]], ears, None),
        ("whiskers", index["light"] if name not in ("opossum", "mouse") else index["dark"], cr.whiskers_at(HEAD_FRONT + m_len * 0.7, 0.12), None),
        ("lower_limbs", LIMB, racc.lower_limbs, (0.004, 3, 2400)),
    ] + tail_parts
    if spec.get("teeth"):
        parts.append(("teeth", index.get("teeth", index["light"]), teeth, None))
    if spec.get("cheeks"):
        parts.append(("cheeks", index[spec["cheeks"][1]], cheeks, None))
    if spec.get("bib"):
        parts.append(("bib", index[spec["bib"]], bib, None))
    if spec.get("stripes"):
        parts.append(("stripes_dark", index["dark"], stripes(True), None))
        parts.append(("stripes_light", index["light"], stripes(False), None))
    if spec.get("quills"):
        parts.append(("quills", index["quill"], quills, None))
    if spec.get("ruffs"):
        parts.append(("ruffs", FUR, racc.ruffs, None))
    return materials, parts


def burrow():
    """A burrow's mound: a low heap of dug earth with a dark hole in its top, for the gophers and prairie dogs
    (scripts/grove_animals.gd). About 0.7 m across. Writes models/burrow.glb and tools/burrow.blend."""
    import bmesh
    import bpy
    bpy.ops.wm.read_factory_settings(use_empty=True)

    def material(name, colour):
        made = bpy.data.materials.new(name)
        made.use_nodes = True
        shader = next(n for n in made.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        shader.inputs["Base Color"].default_value = colour + (1.0,)
        made.diffuse_color = colour + (1.0,)
        return made

    made = bmesh.new()
    rng = random.Random(4)
    rings = []
    for k, (r, h) in enumerate(((0.36, 0.0), (0.3, 0.08), (0.2, 0.14), (0.11, 0.15))):
        rings.append([made.verts.new((math.cos(a) * r * rng.uniform(0.9, 1.1), math.sin(a) * r * rng.uniform(0.9, 1.1), h))
                      for a in (math.tau * j / 14 for j in range(14))])
    for a, b in zip(rings, rings[1:]):
        for j in range(14):
            made.faces.new((a[j], a[(j + 1) % 14], b[(j + 1) % 14], b[j]))
    hole = made.verts.new((0.0, 0.0, 0.06))
    for j in range(14):
        face = made.faces.new((rings[-1][j], rings[-1][(j + 1) % 14], hole))
        face.material_index = 1
    bmesh.ops.recalc_face_normals(made, faces=made.faces[:])
    mesh = bpy.data.meshes.new("burrow")
    made.to_mesh(mesh)
    made.free()
    mesh.materials.append(material("dirt", (0.32, 0.2, 0.11)))
    mesh.materials.append(material("dark", (0.04, 0.03, 0.02)))
    obj = bpy.data.objects.new("burrow", mesh)
    bpy.context.collection.objects.link(obj)
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(root, "tools", "burrow.blend"))
    bpy.ops.export_scene.gltf(filepath=os.path.join(root, "models", "burrow.glb"), export_format="GLB", export_yup=True)
    print("BUILT burrow tris=%d" % sum(len(p.vertices) - 2 for p in mesh.polygons))


if __name__ == "__main__":
    if ANIMAL == "burrow":
        burrow()
        sys.exit(0)
    materials, parts = build(ANIMAL)
    racc.reshaping()
    kit.export(ANIMAL, cr.reshaped_bones(), parts, cr.reshaped_weights, materials)
    racc.paint_grit(ANIMAL)
    if FOLDER:
        racc.look_at(FOLDER, ANIMAL)
    kit.LOW = True
    kit.export(ANIMAL + "_lo", cr.reshaped_bones(), [(part, material, shapes, None) for part, material, shapes, _fuse in parts], cr.reshaped_weights, materials)
    racc.paint_grit(ANIMAL + "_lo")
