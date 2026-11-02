"""The fox, the skunk, the badger and the rabbit (the user, 2026-11-01: "We'll need a fox, skunk, badger, rabbit in this
style as well"), built as the raccoon and the cat are: on the boy's skeleton with a six-bone tail, through the
raccoon's `reshape`, bushy zigzag fur ruffs, cartoon eyes and whiskers. Their proportions and colours are Claude's
picks (placeholders). Their part in the game is not decided: scripts/critter_rig.gd poses them.

Run from the project root, one animal a run (the raccoon builder's settings are changed for each):
    blender -b --factory-startup --python tools/build_critters.py -- <picture folder or -> <fox|skunk|badger|rabbit>

Writes models/<animal>.glb and models/<animal>_lo.glb (and editable copies in tools/). Then: godot --headless --path . --import
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_character as kit  # noqa: E402
import build_raccoon as racc  # noqa: E402

X, Y, Z = kit.X, kit.Y, kit.Z
HC = racc.HEAD_CENTRE

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
FOLDER = ARGS[0] if ARGS and ARGS[0] != "-" else None
ANIMAL = ARGS[1] if len(ARGS) > 1 else "fox"
# (build_character reads the arguments after the folder as names to build only: not ours)
kit.ONLY = []
kit.PREVIEW_DIR = None


# --- What every animal shares, made over from the raccoon's ---

def tail_profile(points):
    """A tail's radius along it (0..1) from (along, radius) pairs."""
    def radius(t):
        for (a, ra), (b, rb) in zip(points, points[1:]):
            if t <= b:
                return ra + (rb - ra) * (t - a) / (b - a)
        return points[-1][1]
    return radius


def cones(pattern, which, count=8, flare=1.3, tip_flare=1.1):
    """The raccoon's tail of zigzag cones, coloured by `pattern` (a part name for each cone): the cones whose name is
    `which`, as a finished mesh in Blender's axes."""
    up = racc.TAIL_DIR.cross(X).normalized()
    made = bmesh.new()

    def ring(t, radius, spiky=False):
        loop = []
        n = racc.SPIKES * 2 if spiky else racc.SPIKES
        for j in range(n):
            a = math.tau * j / n
            r = radius * (1.0 if not spiky or j % 2 == 0 else 0.68)
            along = t + (0.035 if spiky and j % 2 == 0 else 0.0)
            p = racc.tail_point(along) + (X * math.cos(a) + up * math.sin(a)) * r
            loop.append(made.verts.new(kit.to_blender(racc.reshape(p))))
        return loop

    def join(a, b):
        for j in range(len(b)):
            k0 = j * len(a) // len(b)
            k1 = ((j + 1) * len(a) // len(b)) % len(a)
            j1 = (j + 1) % len(b)
            if k0 == k1:
                made.faces.new((a[k0], b[j], b[j1]))
            else:
                made.faces.new((a[k0], a[k1], b[j1], b[j]))

    step = 0.95 / count
    for k in range(count):
        if pattern[k] != which:
            continue
        start = 0.05 + k * step - 0.04
        end = 0.05 + (k + 1) * step
        last = k == count - 1
        base = ring(start, racc.tail_radius(start) * 0.5)
        rim = ring(end - 0.01, racc.tail_radius(min(end, 0.97)) * (flare if not last else tip_flare), True)
        join(base, rim)
        made.faces.new(base[::-1])
        if last:
            tip = made.verts.new(kit.to_blender(racc.reshape(racc.tail_point(1.06))))
            for j in range(len(rim)):
                made.faces.new((rim[j], rim[(j + 1) % len(rim)], tip))
        else:
            back = ring(end + 0.005, racc.tail_radius(end) * 0.5)
            join(back, rim)
            made.faces.new(back)
    if not made.faces:
        made.free()
        return None
    bmesh.ops.recalc_face_normals(made, faces=made.faces[:])
    mesh = bpy.data.meshes.new("cones")
    made.to_mesh(mesh)
    made.free()
    return mesh


def cone_part(pattern, which, **kw):
    def shapes(_b):
        return cones(pattern, which, **kw)
    return shapes


def pointed(b, base, tip, half_width, half_depth, segments=10, bend=None):
    """A flattened cone (an ear), closed at both ends."""
    axis = (tip - base).normalized()
    across = axis.cross(Z if abs(axis.z) < 0.9 else X).normalized()
    deep = axis.cross(across).normalized()
    rings = [(base.lerp(tip, t), across * half_width * (1.0 - t * 0.98), deep * half_depth * (1.0 - t * 0.98)) for t in (0.0, 0.3, 0.6, 0.85, 0.97)]
    b.tube(kit.dome(rings[0], -axis, 0.01, 2)[::-1] + rings, segments)


def snout(b, length, width, height, drop=0.035):
    """A muzzle reaching forward from the face: `length` past the skull's front."""
    rings = []
    for t, s in ((0.0, 1.0), (0.35, 0.9), (0.7, 0.7), (1.0, 0.42)):
        z = 0.04 + (HEAD_FRONT + length - 0.04) * t
        rings.append((HC + Vector((0.0, -drop - 0.004 * t, z)), X * width * s, Y * height * s))
    b.tube(kit.dome(rings[0], -Z, 0.03, 2)[::-1] + rings + kit.dome(rings[-1], Z, width * 0.4, 3), 16)


HEAD_FRONT = racc.HEAD_RADII.z


def skull_band(region):
    """Markings that lie on the skull: the skull, a little larger, cut to the shapes `region(builder)` adds (the
    raccoon's mask is made so). A finished mesh in Blender's axes."""
    shell = kit.Builder()
    rings = []
    hr = racc.HEAD_RADII
    for k in range(1, 20):
        phi = -math.pi / 2 + math.pi * k / 20
        c, s = math.cos(phi), math.sin(phi)
        jaw = max(0.0, -s)
        rings.append(kit.upright(0.0, HC.y + hr.y * s * 1.03, HC.z, hr.x * c * (1.0 - 0.10 * jaw ** 1.5) * 1.035, hr.z * c * 1.04))
    shell.tube(rings, 32)
    band = kit.Builder()
    region(band)
    objects = []
    for builder in (shell, band):
        thing = bpy.data.objects.new("band_part", kit.fused(builder, None))
        bpy.context.collection.objects.link(thing)
        objects.append(thing)
    # (the band's shapes overlap: join them into one solid first)
    weld = objects[1].modifiers.new("weld", "REMESH")
    weld.mode = "VOXEL"
    weld.voxel_size = 0.006
    bpy.context.view_layer.update()
    solid = bpy.data.meshes.new_from_object(objects[1].evaluated_get(bpy.context.evaluated_depsgraph_get()))
    objects[1].modifiers.clear()
    objects[1].data = solid
    cut = objects[0].modifiers.new("cut", "BOOLEAN")
    cut.operation = "INTERSECT"
    cut.solver = "EXACT"
    cut.object = objects[1]
    bpy.context.view_layer.update()
    result = bpy.data.meshes.new_from_object(objects[0].evaluated_get(bpy.context.evaluated_depsgraph_get()))
    for thing in objects:
        bpy.data.objects.remove(thing)
    return result


def nose_ball(b, at, radii):
    b.ellipsoid(HC + at, radii, None, 12, 6)


def eye_whites(b):
    racc.eyes(b)


def eye_pupils(b):
    racc.pupils(b)


def whiskers_at(z, spread=0.15):
    def shapes(b):
        for side in (1.0, -1.0):
            for k, (rise, droop) in enumerate(((0.012, 0.004), (0.0, -0.012), (-0.012, -0.03))):
                root = HC + Vector((side * 0.03, -0.036 + rise, z - k * 0.008))
                tip = root + Vector((side * spread, droop, -0.045))
                b.strand([root, root.lerp(tip, 0.5) + Vector((0.0, 0.008, 0.0)), tip], [0.0045, 0.0035, 0.002], 5)
    return shapes


HEAD_PARTS = {"muzzle", "nose", "whiskers", "brows", "mask", "cheeks", "ears", "ear_insides", "ear_backs", "blaze",
              "face_bands", "teeth", "crest"}


def weights(part, p):
    if part == "nose" and NOSE_BONE[0]:
        return {"nose": 1.0}
    if part == "quills" and QUILL_BONE[0]:
        return {"quills": 1.0}
    if part in HEAD_PARTS:
        return {"head": 1.0}
    if part == "spine_stripe":
        # (along his back: with whatever of the trunk it lies over)
        return racc.weights("body", p)
    return racc.weights(part, p)


NOSE_BONE = [None]
## A porcupine's quills: a bone of their own on its back, to raise them (CritterRig scales it up when alarmed).
QUILL_BONE = [None]


def bones():
    listed = racc.bones()
    if NOSE_BONE[0] is not None:
        listed.append(("nose", NOSE_BONE[0], "head"))
    if QUILL_BONE[0] is not None:
        listed.append(("quills", QUILL_BONE[0], "spine"))
    return listed


# --- Proportions: the raccoon's reshape, with each animal's own changes after it ---

WIDE = [1.0]   # (a badger is broader in the body)
LONG = [1.0]   # (a weasel or an otter is longer in it)


def make_reshape(leg, arm, head, wide=1.0, long=1.0):
    racc.LEG_SCALE = leg
    racc.ARM_SCALE = arm
    racc.HEAD_SCALE = head
    racc.DROP = (racc.HIP_Y - racc.ANKLE_Y) * (1.0 - leg)
    WIDE[0] = wide
    LONG[0] = long
    base_reshape = RACC_RESHAPE
    base_drawn = RACC_DRAWN

    def body_wide(y):
        # (the trunk and legs widened, fading out up the neck so the head keeps its shape)
        return 1.0 + (WIDE[0] - 1.0) * (1.0 - kit.blend(racc.NECK.y - 0.06, racc.NECK.y + 0.02, y))

    def reshape(p):
        drawn_y = p[1]
        p = base_reshape(p)
        if WIDE[0] != 1.0 and not (racc.ARM_BAND[0] < drawn_y < racc.ARM_BAND[1] and abs(p.x) > racc.SHOULDER.x * WIDE[0]):
            p.x *= body_wide(drawn_y)
        if LONG[0] != 1.0:
            # (the trunk drawn out between the hips and the neck, all above it carried up by as much)
            hip, neck = trunk_span()
            if p.y > hip:
                p.y += (min(p.y, neck) - hip) * (LONG[0] - 1.0)
        return p

    def trunk_span():
        return base_reshape(Vector((0.0, racc.HIP_Y, 0.0))).y, base_reshape(Vector((0.0, racc.NECK.y, 0.0))).y

    def as_drawn(p):
        p = Vector(p)
        if LONG[0] != 1.0:
            hip, neck = trunk_span()
            top = neck + (neck - hip) * (LONG[0] - 1.0)
            if p.y > top:
                p.y -= (neck - hip) * (LONG[0] - 1.0)
            elif p.y > hip:
                p.y = hip + (p.y - hip) / LONG[0]
        if WIDE[0] != 1.0:
            guess = base_drawn(p)
            p.x /= body_wide(guess.y)
        return base_drawn(p)

    racc.reshape = reshape
    racc.as_drawn = as_drawn


RACC_RESHAPE = racc.reshape
RACC_DRAWN = racc.as_drawn


def reshaped_bones():
    return [(bone, racc.reshape(at), parent) for bone, at, parent in bones()]


def reshaped_weights(part, p):
    return weights(part, racc.as_drawn(p))


# --- The fox ---

def fox():
    racc.TAIL_DIR = Vector((0.0, 0.18, -1.0)).normalized()
    racc.TAIL_LENGTH = 0.78
    racc.tail_radius = tail_profile([(0.0, 0.05), (0.1, 0.08), (0.45, 0.115), (0.8, 0.105), (0.95, 0.07), (1.0, 0.04)])
    make_reshape(leg=0.9, arm=0.85, head=1.1)
    FUR, WHITE, BLACK, EYE, PUPIL, LIMB = range(6)
    materials = [("fur", (0.88, 0.42, 0.13)), ("light", (0.98, 0.95, 0.9)), ("dark", (0.1, 0.08, 0.08)),
                 ("eye", (0.97, 0.97, 0.95)), ("pupil", (0.03, 0.03, 0.04)), ("limb", (0.16, 0.12, 0.1))]

    def muzzle(b):
        snout(b, 0.13, 0.05, 0.042)

    def cheeks(b):
        # White cheeks and throat, down to the chest
        for side in (1.0, -1.0):
            b.ellipsoid(HC + Vector((side * 0.085, -0.06, 0.05)), Vector((0.06, 0.05, 0.05)), Matrix.Rotation(side * -0.4, 3, Z), 12, 6)
        b.ellipsoid(HC + Vector((0.0, -0.11, 0.04)), Vector((0.075, 0.06, 0.06)), None, 12, 6)

    def nose(b):
        nose_ball(b, Vector((0.0, -0.034, HEAD_FRONT + 0.13)), Vector((0.02, 0.016, 0.016)))

    def ears(b):
        for side in (1.0, -1.0):
            base = HC + Vector((side * 0.07, 0.08, -0.03))
            pointed(b, base, base + Vector((side * 0.06, 0.17, 0.0)), 0.06, 0.022)

    def ear_insides(b):
        for side in (1.0, -1.0):
            base = HC + Vector((side * 0.069, 0.086, -0.012))
            pointed(b, base, base + Vector((side * 0.05, 0.135, 0.004)), 0.038, 0.008)

    def ear_backs(b):
        # Black backs to the ears
        for side in (1.0, -1.0):
            base = HC + Vector((side * 0.072, 0.09, -0.04))
            pointed(b, base, base + Vector((side * 0.061, 0.165, -0.002)), 0.058, 0.012)

    pattern = ["fur"] * 7 + ["white"]
    parts = [
        ("body", FUR, racc.body, (0.006, 4, 6000)),
        ("feet", BLACK, racc.feet, (0.004, 3, 2400)),
        ("hands", BLACK, racc.hands, (0.003, 2, 1800)),
        ("head", FUR, racc.head, (0.005, 4, 3200)),
        ("cheeks", WHITE, cheeks, None),
        ("muzzle", WHITE, muzzle, None),
        ("nose", BLACK, nose, None),
        ("eyes", EYE, eye_whites, None),
        ("pupils", PUPIL, eye_pupils, None),
        ("ears", FUR, ears, None),
        ("ear_insides", WHITE, ear_insides, None),
        ("ear_backs", BLACK, ear_backs, None),
        ("tail", FUR, racc.tail, (0.006, 3, 3000)),
        ("tail_fur", FUR, cone_part(pattern, "fur", flare=1.25), None),
        ("tail_tip", WHITE, cone_part(pattern, "white", tip_flare=1.15), None),
        ("whiskers", BLACK, whiskers_at(HEAD_FRONT + 0.1), None),
        ("lower_limbs", LIMB, racc.lower_limbs, (0.004, 3, 2400)),
        ("ruffs", FUR, racc.ruffs, None),
    ]
    return materials, parts


# --- The skunk ---

def skunk():
    # A big plume of a tail raised up over its back
    racc.TAIL_DIR = Vector((0.0, 1.0, -0.55)).normalized()
    racc.TAIL_LENGTH = 0.72
    racc.tail_radius = tail_profile([(0.0, 0.055), (0.12, 0.09), (0.5, 0.12), (0.8, 0.11), (1.0, 0.05)])
    make_reshape(leg=0.72, arm=0.75, head=1.12, wide=1.1)
    BLACK, WHITE, EYE, PUPIL, PINK = range(5)
    materials = [("fur", (0.11, 0.1, 0.12)), ("light", (0.96, 0.96, 0.94)), ("eye", (0.97, 0.97, 0.95)),
                 ("pupil", (0.03, 0.03, 0.04)), ("pink", (0.9, 0.55, 0.6))]

    def muzzle(b):
        snout(b, 0.07, 0.055, 0.045)

    def nose(b):
        nose_ball(b, Vector((0.0, -0.036, HEAD_FRONT + 0.075)), Vector((0.02, 0.016, 0.015)))

    def blaze(b):
        # A thin white stripe from the brow down the nose
        b.strand([HC + Vector((0.0, 0.07, 0.1)), HC + Vector((0.0, 0.02, 0.12)), HC + Vector((0.0, -0.01, HEAD_FRONT + 0.04))],
                 [0.016, 0.015, 0.012], 8)

    def crest(b):
        # The white stripe: a ridge of spikes from the crown of its head over the back of it
        for k in range(6):
            t = k / 5.0
            at = HC + Vector((0.0, 0.1 - 0.02 * t, -0.03 - 0.1 * t))
            b.ellipsoid(at, Vector((0.05, 0.022, 0.05)), None, 10, 5)

    def spine_stripe(b):
        # ...and on down its back to the root of its tail (as drawn: the back of the body is at its half depth)
        profile = [(0.86, 0.075), (0.8, 0.112), (0.73, 0.132), (0.66, 0.152), (0.58, 0.162), (0.5, 0.152)]
        for y, depth in profile:
            b.ellipsoid(Vector((0.0, y, -depth + 0.006)), Vector((0.06, 0.05, 0.03)), None, 10, 5)

    def ears(b):
        for side in (1.0, -1.0):
            b.ellipsoid(HC + Vector((side * 0.085, 0.09, -0.03)), Vector((0.032, 0.034, 0.014)), Matrix.Rotation(side * -0.4, 3, Z), 12, 5)

    def ear_insides(b):
        for side in (1.0, -1.0):
            b.ellipsoid(HC + Vector((side * 0.085, 0.088, -0.02)), Vector((0.02, 0.022, 0.008)), Matrix.Rotation(side * -0.4, 3, Z), 10, 5)

    pattern = ["black", "white", "white", "black", "white", "white", "white", "white"]
    parts = [
        ("body", BLACK, racc.body, (0.006, 4, 6000)),
        ("feet", BLACK, racc.feet, (0.004, 3, 2400)),
        ("hands", BLACK, racc.hands, (0.003, 2, 1800)),
        ("head", BLACK, racc.head, (0.005, 4, 3200)),
        ("muzzle", BLACK, muzzle, None),
        ("blaze", WHITE, blaze, None),
        ("crest", WHITE, crest, None),
        ("spine_stripe", WHITE, spine_stripe, None),
        ("nose", PINK, nose, None),
        ("eyes", EYE, eye_whites, None),
        ("pupils", PUPIL, eye_pupils, None),
        ("ears", BLACK, ears, None),
        ("ear_insides", PINK, ear_insides, None),
        ("tail", BLACK, racc.tail, (0.006, 3, 3000)),
        ("tail_black", BLACK, cone_part(pattern, "black", flare=1.35), None),
        ("tail_white", WHITE, cone_part(pattern, "white", flare=1.35, tip_flare=1.2), None),
        ("whiskers", WHITE, whiskers_at(HEAD_FRONT + 0.05, 0.12), None),
        ("lower_limbs", BLACK, racc.lower_limbs, (0.004, 3, 2400)),
        ("ruffs", BLACK, racc.ruffs, None),
    ]
    return materials, parts


# --- The badger ---

def badger():
    racc.TAIL_DIR = Vector((0.0, 0.1, -1.0)).normalized()
    racc.TAIL_LENGTH = 0.24
    racc.tail_radius = tail_profile([(0.0, 0.05), (0.3, 0.07), (0.8, 0.06), (1.0, 0.03)])
    make_reshape(leg=0.62, arm=0.68, head=1.08, wide=1.28)
    GREY, WHITE, BLACK, EYE, PUPIL, LIMB = range(6)
    materials = [("fur", (0.56, 0.55, 0.53)), ("light", (0.96, 0.95, 0.92)), ("dark", (0.08, 0.07, 0.07)),
                 ("eye", (0.97, 0.97, 0.95)), ("pupil", (0.03, 0.03, 0.04)), ("limb", (0.14, 0.12, 0.11))]

    def muzzle(b):
        snout(b, 0.1, 0.06, 0.048, 0.04)

    def nose(b):
        nose_ball(b, Vector((0.0, -0.042, HEAD_FRONT + 0.1)), Vector((0.026, 0.02, 0.018)))

    def face_bands(_b):
        # A black band each side from the front of the face through the eye and back over the ear, the white left
        # between them: the skull, a little larger, cut to the two bands (as the raccoon's mask is made)
        def region(band):
            for side in (1.0, -1.0):
                points = [HC + Vector((side * 0.03, -0.03, 0.16)), HC + Vector((side * 0.06, 0.015, 0.11)),
                          HC + Vector((side * 0.09, 0.05, 0.02)), HC + Vector((side * 0.1, 0.06, -0.08))]
                band.strand(points, [0.03, 0.04, 0.045, 0.04], 10)
        return skull_band(region)

    def ears(b):
        for side in (1.0, -1.0):
            b.ellipsoid(HC + Vector((side * 0.11, 0.06, -0.04)), Vector((0.03, 0.026, 0.014)), Matrix.Rotation(side * -0.7, 3, Z), 12, 5)

    def ear_insides(b):
        for side in (1.0, -1.0):
            b.ellipsoid(HC + Vector((side * 0.11, 0.058, -0.03)), Vector((0.018, 0.016, 0.008)), Matrix.Rotation(side * -0.7, 3, Z), 10, 5)

    pattern = ["grey", "grey", "grey", "grey", "grey", "grey", "grey", "grey"]
    parts = [
        ("body", GREY, racc.body, (0.006, 4, 6000)),
        ("feet", BLACK, racc.feet, (0.004, 3, 2400)),
        ("hands", BLACK, racc.hands, (0.003, 2, 1800)),
        ("head", WHITE, racc.head, (0.005, 4, 3200)),
        ("muzzle", WHITE, muzzle, None),
        ("face_bands", BLACK, face_bands, None),
        ("nose", BLACK, nose, None),
        ("eyes", EYE, eye_whites, None),
        ("pupils", PUPIL, eye_pupils, None),
        ("ears", WHITE, ears, None),
        ("ear_insides", GREY, ear_insides, None),
        ("tail", GREY, racc.tail, (0.006, 3, 3000)),
        ("tail_grey", GREY, cone_part(pattern, "grey", count=3, flare=1.4, tip_flare=1.3), None),
        ("whiskers", WHITE, whiskers_at(HEAD_FRONT + 0.08, 0.12), None),
        ("lower_limbs", LIMB, racc.lower_limbs, (0.004, 3, 2400)),
        ("ruffs", GREY, racc.ruffs, None),
    ]
    return materials, parts


# --- The rabbit ---

def rabbit():
    racc.TAIL_DIR = Vector((0.0, 0.45, -1.0)).normalized()
    racc.TAIL_LENGTH = 0.1
    racc.tail_radius = tail_profile([(0.0, 0.035), (1.0, 0.03)])
    make_reshape(leg=0.9, arm=0.7, head=1.15)
    NOSE_BONE[0] = HC + Vector((0.0, -0.025, HEAD_FRONT + 0.05))
    FUR, CREAM, WHITE, EYE, PUPIL, PINK, LIMB = range(7)
    materials = [("fur", (0.66, 0.55, 0.44)), ("light", (0.95, 0.9, 0.8)), ("white", (0.99, 0.99, 0.97)),
                 ("eye", (0.97, 0.97, 0.95)), ("pupil", (0.05, 0.03, 0.03)), ("pink", (0.95, 0.6, 0.66)),
                 ("limb", (0.6, 0.5, 0.4))]

    def muzzle(b):
        # Two puffed whisker pads and a short muzzle
        for side in (1.0, -1.0):
            b.ellipsoid(HC + Vector((side * 0.03, -0.045, HEAD_FRONT - 0.01)), Vector((0.04, 0.034, 0.034)), None, 12, 6)

    def nose(b):
        # (on its own bone, to twitch)
        b.tube([(HC + Vector((0.0, y, HEAD_FRONT + 0.03)), X * rx, Z * 0.012) for y, rx in ((-0.032, 0.006), (-0.024, 0.016), (-0.016, 0.018), (-0.01, 0.01))], 10)

    def teeth(b):
        for side in (1.0, -1.0):
            b.ellipsoid(HC + Vector((side * 0.009, -0.088, HEAD_FRONT + 0.0)), Vector((0.009, 0.016, 0.005)), None, 8, 4)

    def cheeks(b):
        for side in (1.0, -1.0):
            b.ellipsoid(HC + Vector((side * 0.1, -0.05, 0.03)), Vector((0.05, 0.04, 0.045)), Matrix.Rotation(side * -0.4, 3, Z), 12, 6)

    def ears(b):
        for side in (1.0, -1.0):
            base = HC + Vector((side * 0.045, 0.09, -0.03))
            pointed(b, base, base + Vector((side * 0.05, 0.3, -0.03)), 0.05, 0.02, 12)

    def ear_insides(b):
        for side in (1.0, -1.0):
            base = HC + Vector((side * 0.045, 0.1, -0.012))
            pointed(b, base, base + Vector((side * 0.046, 0.26, -0.022)), 0.032, 0.008, 10)

    def big_feet(b):
        # Long hind feet: the raccoon's, half as long again
        for side in (1.0, -1.0):
            ankle = Vector((side * racc.HIP_X, racc.ANKLE_Y, 0.0))
            foot = [(-0.060, -0.022, 0.034, 0.030), (-0.020, -0.012, 0.042, 0.04), (0.05, -0.022, 0.048, 0.032),
                    (0.12, -0.03, 0.05, 0.022), (0.18, -0.032, 0.046, 0.018), (0.21, -0.034, 0.04, 0.015)]
            rings = [(ankle + Vector((0.0, y, z)), X * rx, Y * ry) for z, y, rx, ry in foot]
            b.tube(kit.dome(rings[0], -Z, 0.016, 3)[::-1] + rings + kit.dome(rings[-1], Z, 0.014, 3), 16, 0.0)
            b.tube([kit.upright(ankle.x, y, z, r, r * 1.08) for y, r, z in ((0.02, 0.037, 0.0), (0.06, 0.038, 0.0), (0.10, 0.04, 0.0))], 12)

    def cotton(b):
        # The cotton tail: a puffball on the stub of tail bones
        b.ellipsoid(racc.tail_point(0.7), Vector((0.075, 0.075, 0.07)), None, 14, 8)
        for k in range(10):
            a = math.tau * k / 10
            b.ellipsoid(racc.tail_point(0.7) + Vector((math.cos(a) * 0.055, math.sin(a) * 0.055, -0.02)), Vector((0.035, 0.035, 0.035)), None, 8, 4)

    parts = [
        ("body", FUR, racc.body, (0.006, 4, 6000)),
        ("feet", FUR, big_feet, (0.004, 3, 2400)),
        ("hands", FUR, racc.hands, (0.003, 2, 1800)),
        ("head", FUR, racc.head, (0.005, 4, 3200)),
        ("cheeks", CREAM, cheeks, None),
        ("muzzle", CREAM, muzzle, None),
        ("nose", PINK, nose, None),
        ("teeth", WHITE, teeth, None),
        ("eyes", EYE, eye_whites, None),
        ("pupils", PUPIL, eye_pupils, None),
        ("ears", FUR, ears, None),
        ("ear_insides", PINK, ear_insides, None),
        ("tail", WHITE, cotton, (0.005, 3, 1500)),
        ("whiskers", WHITE, whiskers_at(HEAD_FRONT + 0.0, 0.14), None),
        ("lower_limbs", LIMB, racc.lower_limbs, (0.004, 3, 2400)),
        ("ruffs", FUR, racc.ruffs, None),
    ]
    return materials, parts


ANIMALS = {"fox": fox, "skunk": skunk, "badger": badger, "rabbit": rabbit}

if __name__ == "__main__":
    materials, parts = ANIMALS[ANIMAL]()
    racc.reshaping()
    kit.export(ANIMAL, reshaped_bones(), parts, reshaped_weights, materials)
    racc.paint_grit(ANIMAL)
    if FOLDER:
        racc.look_at(FOLDER, ANIMAL)
    kit.LOW = True
    kit.export(ANIMAL + "_lo", reshaped_bones(), [(part, material, shapes, None) for part, material, shapes, _fuse in parts], reshaped_weights, materials)
    racc.paint_grit(ANIMAL + "_lo")
