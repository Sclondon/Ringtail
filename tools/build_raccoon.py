"""The raccoon: a figure on the boy's skeleton, with a tail of six bones.

Run from the project root:
    blender -b --factory-startup --python tools/build_raccoon.py
    blender -b --factory-startup --python tools/build_raccoon.py -- <folder>   # also renders him from every side

Writes models/raccoon.glb and models/raccoon_lo.glb (and editable copies in tools/).
Then: godot --headless --path . --import

Built on GameCommon's build_character.py, as build_figure_template.py is (see it
for what scripts/character_rig.gd needs of a figure). He is short in the leg,
round in the belly, big in the head, with a masked face, white brows and muzzle,
round ears, dark hand-like paws and long plantigrade feet. The tail (bones
tail_0..tail_5, a chain under hips) is posed by scripts/raccoon_rig.gd.
"""

import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_character as kit  # noqa: E402

X, Y, Z = kit.X, kit.Y, kit.Z
blend = kit.blend

NAME = "raccoon"

# --- Joints (Godot space: metres, Y up, he faces +Z, +X is his left) ---

ANKLE_Y = 0.05
THIGH = 0.20
SHIN = 0.19
HIP_X = 0.086
HIP_Y = ANKLE_Y + SHIN + THIGH
KNEE_Y = HIP_Y - THIGH
HIPS = Vector((0.0, HIP_Y + 0.03, 0.0))
SPINE = Vector((0.0, 0.58, 0.0))
CHEST = Vector((0.0, 0.70, 0.0))
NECK = Vector((0.0, 0.83, 0.0))
HEAD = Vector((0.0, 0.875, 0.0))
SHOULDER = Vector((0.15, 0.785, 0.0))
UPPER_ARM = 0.19
FOREARM = 0.18
ELBOW_X = SHOULDER.x + UPPER_ARM
WRIST_X = ELBOW_X + FOREARM
TOE = Vector((0.0, -0.035, 0.085))
HEAD_CENTRE = Vector((0.0, 0.985, 0.01))
HEAD_RADII = Vector((0.13, 0.115, 0.12))
EYE_X, EYE_Y, EYE_Z, EYE_R = 0.052, 0.012, 0.094, 0.03

# The tail: from its root low on his back, straight back and a little up when he is made.
TAIL_ROOT = Vector((0.0, 0.50, -0.13))
TAIL_DIR = Vector((0.0, 0.25, -1.0)).normalized()
TAIL_LENGTH = 0.64
TAIL_BONES = 6

# --- Colours (sRGB) ---

FUR, LIGHT, DARK, PAW, WHITE, BLACK, EAR = range(7)
MATERIALS = [
    ("fur", (0.50, 0.48, 0.47)),
    ("light", (0.90, 0.88, 0.83)),
    ("dark", (0.13, 0.12, 0.13)),
    ("paw", (0.21, 0.19, 0.19)),
    ("eye", (0.97, 0.97, 0.95)),
    ("pupil", (0.03, 0.03, 0.04)),
    ("ear", (0.27, 0.22, 0.22)),
]


def tail_point(t):
    return TAIL_ROOT + TAIL_DIR * (TAIL_LENGTH * t)


def tail_radius(t):
    # (along it, 0 to 1 -> radius): thin at the root, bushy, then to a blunt tip
    profile = [(0.0, 0.045), (0.08, 0.068), (0.3, 0.092), (0.55, 0.094), (0.8, 0.078), (0.95, 0.052), (1.0, 0.035)]
    for (a, ra), (b, rb) in zip(profile, profile[1:]):
        if t <= b:
            return ra + (rb - ra) * (t - a) / (b - a)
    return profile[-1][1]


def tail_ring(t, grow=1.0):
    # Rings square to the tail: u across (his X), v the tail's own up
    up = TAIL_DIR.cross(X).normalized()
    r = tail_radius(t) * grow
    return (tail_point(t), X * r, up * r)


# --- Shapes ---

def body(b):
    # (height, half width, half depth, forward offset), seat to neck: a pear of a raccoon
    profile = [(0.40, 0.08, 0.08, 0.0), (0.44, 0.145, 0.125, -0.01), (0.50, 0.178, 0.152, 0.0), (0.58, 0.188, 0.162, 0.012),
               (0.66, 0.178, 0.152, 0.012), (0.73, 0.158, 0.132, 0.004), (0.79, 0.142, 0.112, 0.0), (0.83, 0.10, 0.09, 0.0),
               (0.88, 0.072, 0.072, 0.0)]
    b.tube([kit.upright(0.0, y, z, rx, rz) for y, rx, rz, z in profile], 20)
    for side in (1.0, -1.0):
        # Arms straight out (a T-pose): (distance from the shoulder, radius)
        arm = [(-0.05, 0.062), (0.0, 0.064), (0.09, 0.054), (UPPER_ARM, 0.046), (0.28, 0.041), (0.345, 0.036), (0.375, 0.032)]
        b.tube([(Vector((side * (SHOULDER.x + d), SHOULDER.y, 0.0)), Y * r, Z * r) for d, r in arm], 12)
        leg = [(HIP_Y + 0.04, 0.086), (HIP_Y - 0.02, 0.098), (0.35, 0.078), (0.30, 0.068), (KNEE_Y, 0.058), (0.17, 0.052), (0.10, 0.044), (0.07, 0.040)]
        b.tube([kit.upright(side * HIP_X, y, 0.0, r, r * 1.08) for y, r in leg], 16)


def belly(b):
    b.ellipsoid(Vector((0.0, 0.585, 0.085)), Vector((0.128, 0.165, 0.098)), None, 16, 9)


def feet(b):
    for side in (1.0, -1.0):
        ankle = Vector((side * HIP_X, ANKLE_Y, 0.0))
        # Long and flat, heel down: (how far forward, centre height above the ankle, half width, half height)
        foot = [(-0.060, -0.022, 0.034, 0.030), (-0.030, -0.012, 0.042, 0.042), (0.020, -0.018, 0.048, 0.036),
                (0.070, -0.028, 0.054, 0.024), (0.110, -0.032, 0.056, 0.020), (0.135, -0.034, 0.050, 0.016)]
        rings = [(ankle + Vector((0.0, y, z)), X * rx, Y * ry) for z, y, rx, ry in foot]
        b.tube(kit.dome(rings[0], -Z, 0.016, 3)[::-1] + rings + kit.dome(rings[-1], Z, 0.012, 3), 16, 0.0)
        # Five toes along the front
        for k in range(5):
            across = (k - 2) / 2.0
            b.ellipsoid(ankle + Vector((across * 0.040, -0.036, 0.142 - abs(across) * 0.018)), Vector((0.013, 0.012, 0.020)), None, 8, 4)
        # ...and the ankle, up into the leg
        b.tube([kit.upright(ankle.x, y, z, r, r * 1.08) for y, r, z in ((0.02, 0.040, 0.0), (0.06, 0.043, 0.0), (0.10, 0.045, 0.0))], 12)


def hands(b):
    for side in (1.0, -1.0):
        wrist = Vector((side * WRIST_X, SHOULDER.y, 0.0))
        # A small palm, starting up inside the fur of the forearm
        palm = [(-0.045, 0.028, 0.030), (0.0, 0.024, 0.032), (0.030, 0.020, 0.040), (0.055, 0.016, 0.040)]
        rings = [(wrist + X * side * d, Y * ry, Z * rz) for d, ry, rz in palm]
        b.tube(rings + kit.dome(rings[-1], X * side, 0.010, 2), 12)
        # Four long fingers, spread a little, and a thumb forward
        for k in range(4):
            across = (k - 1.5) / 1.5
            root = wrist + Vector((side * 0.050, -0.002, across * 0.026))
            tip = root + Vector((side * (0.052 - abs(across) * 0.010), -0.010, across * 0.016))
            b.strand([root, root.lerp(tip, 0.55) + Vector((0.0, 0.002, 0.0)), tip], [0.011, 0.010, 0.008])
        b.strand([wrist + Vector((side * x, y, z)) for x, y, z in ((0.012, -0.004, 0.026), (0.030, -0.008, 0.046), (0.046, -0.010, 0.056))],
                 [0.011, 0.010, 0.008])


def head(b):
    b.tube([kit.upright(0.0, y, 0.0, 0.07, 0.072) for y in (0.82, 0.86, 0.90)], 12)
    # A broad skull narrowing a little to the jaw
    rings = []
    for k in range(1, 14):
        phi = -math.pi / 2 + math.pi * k / 14
        c, s = math.cos(phi), math.sin(phi)
        jaw = max(0.0, -s)
        rings.append(kit.upright(0.0, HEAD_CENTRE.y + HEAD_RADII.y * s, HEAD_CENTRE.z,
                                 HEAD_RADII.x * c * (1.0 - 0.10 * jaw ** 1.5), HEAD_RADII.z * c))
    b.tube(rings, 24)
    # The ruff of the cheeks, out and down to either side (grey here; the white of them is `cheeks`)
    for side in (1.0, -1.0):
        b.ellipsoid(HEAD_CENTRE + Vector((side * 0.100, -0.040, -0.005)), Vector((0.060, 0.058, 0.070)), None, 12, 6)


def cheeks(b):
    for side in (1.0, -1.0):
        tilt = Matrix.Rotation(side * -0.5, 3, Z)
        b.ellipsoid(HEAD_CENTRE + Vector((side * 0.118, -0.055, 0.035)), Vector((0.048, 0.034, 0.042)), tilt, 12, 6)


def muzzle(b):
    # A pointed white snout
    rings = []
    for z, y, rx, ry in ((0.04, -0.030, 0.070, 0.058), (0.10, -0.034, 0.064, 0.050), (0.16, -0.038, 0.044, 0.034), (0.205, -0.034, 0.024, 0.020)):
        rings.append((HEAD_CENTRE + Vector((0.0, y, z)), X * rx, Y * ry))
    b.tube(kit.dome(rings[0], -Z, 0.03, 2)[::-1] + rings + kit.dome(rings[-1], Z, 0.014, 3), 16)


def nose(b):
    b.ellipsoid(HEAD_CENTRE + Vector((0.0, -0.024, 0.218)), Vector((0.024, 0.018, 0.016)), None, 12, 6)


def brows(b):
    for side in (1.0, -1.0):
        tilt = Matrix.Rotation(side * 0.25, 3, Z)
        b.ellipsoid(HEAD_CENTRE + Vector((side * 0.052, 0.062, 0.082)), Vector((0.042, 0.017, 0.034)), tilt, 12, 5)


def eyes(b):
    for side in (1.0, -1.0):
        b.ellipsoid(HEAD_CENTRE + Vector((side * EYE_X, EYE_Y, EYE_Z)), Vector((EYE_R, EYE_R * 1.1, EYE_R)), None, 14, 7)


def pupils(b):
    for side in (1.0, -1.0):
        centre = HEAD_CENTRE + Vector((side * (EYE_X + 0.002), EYE_Y + 0.002, EYE_Z + EYE_R * 0.72))
        b.ellipsoid(centre, Vector((0.014, 0.018, 0.011)), None, 10, 5)


def ears(b):
    for side in (1.0, -1.0):
        tilt = Matrix.Rotation(side * -0.42, 3, Z)
        b.ellipsoid(HEAD_CENTRE + Vector((side * 0.088, 0.100, -0.020)), Vector((0.046, 0.050, 0.017)), tilt, 14, 6)


def ear_insides(b):
    for side in (1.0, -1.0):
        tilt = Matrix.Rotation(side * -0.42, 3, Z)
        b.ellipsoid(HEAD_CENTRE + Vector((side * 0.088, 0.097, -0.008)), Vector((0.030, 0.034, 0.010)), tilt, 12, 5)


def mask(b):
    """The dark band across his eyes: the skull, a little larger, cut to a band
    across the face. Made by intersecting the two in Blender, so it hands back a
    finished mesh (in Blender's axes, as `export` wants)."""
    shell = kit.Builder()
    rings = []
    for k in range(1, 20):
        phi = -math.pi / 2 + math.pi * k / 20
        c, s = math.cos(phi), math.sin(phi)
        jaw = max(0.0, -s)
        rings.append(kit.upright(0.0, HEAD_CENTRE.y + HEAD_RADII.y * s * 1.03, HEAD_CENTRE.z,
                                 HEAD_RADII.x * c * (1.0 - 0.10 * jaw ** 1.5) * 1.035, HEAD_RADII.z * c * 1.04))
    shell.tube(rings, 32)
    band = kit.Builder()
    # (wide and low across the eyes, sweeping down a little at the cheeks)
    band.ellipsoid(HEAD_CENTRE + Vector((0.0, 0.004, 0.11)), Vector((0.155, 0.046, 0.115)), Matrix.Rotation(0.0, 3, X), 20, 9)
    for side in (1.0, -1.0):
        band.ellipsoid(HEAD_CENTRE + Vector((side * 0.085, -0.022, 0.085)), Vector((0.06, 0.036, 0.06)), None, 12, 6)
    objects = []
    for builder in (shell, band):
        made = kit.fused(builder, None)
        thing = bpy.data.objects.new("mask_part", made)
        bpy.context.collection.objects.link(thing)
        objects.append(thing)
    # (the two band shapes overlap: join them into one solid first)
    joined = objects[1].modifiers.new("weld", "REMESH")
    joined.mode = "VOXEL"
    joined.voxel_size = 0.006
    bpy.context.view_layer.update()
    region = bpy.data.meshes.new_from_object(objects[1].evaluated_get(bpy.context.evaluated_depsgraph_get()))
    objects[1].modifiers.clear()
    objects[1].data = region
    cut = objects[0].modifiers.new("cut", "BOOLEAN")
    cut.operation = "INTERSECT"
    cut.solver = "EXACT"
    cut.object = objects[1]
    bpy.context.view_layer.update()
    result = bpy.data.meshes.new_from_object(objects[0].evaluated_get(bpy.context.evaluated_depsgraph_get()))
    for thing in objects:
        bpy.data.objects.remove(thing)
    return result


def tail(b):
    count = 12 if kit.LOW else 24
    rings = [tail_ring(k / count) for k in range(count + 1)]
    b.tube(kit.dome(rings[0], -TAIL_DIR, 0.02, 2)[::-1] + rings + kit.dome(rings[-1], TAIL_DIR, 0.03, 3), 16)


def tail_rings(b):
    # Five dark rings and a dark tip, standing a little proud of the fur
    for middle in (0.22, 0.38, 0.54, 0.70, 0.84):
        b.tube([tail_ring(middle + d, g) for d, g in ((-0.035, 1.0), (-0.025, 1.045), (0.025, 1.045), (0.035, 1.0))], 16)
    rings = [tail_ring(t, 1.045) for t in (0.93, 0.96, 1.0)]
    b.tube([tail_ring(0.92, 1.0)] + rings + kit.dome(rings[-1], TAIL_DIR, 0.034, 3), 16)


# --- Skin weights ---

def tail_weights(p):
    along = (p - TAIL_ROOT).dot(TAIL_DIR) / TAIL_LENGTH
    step = 1.0 / TAIL_BONES
    past = [blend(-0.03, 0.04, along)]
    for k in range(1, TAIL_BONES):
        past.append(blend(k * step - 0.035, k * step + 0.035, along))
    past.append(0.0)
    result = {"hips": 1.0 - past[0]}
    for k in range(TAIL_BONES):
        result["tail_%d" % k] = past[k] - past[k + 1]
    return result


def weights(part, p):
    suffix = "_l" if p.x >= 0.0 else "_r"
    if part in ("tail", "tail_rings"):
        return tail_weights(p)
    if part in ("eyes", "pupils"):
        return {"eye" + suffix: 1.0}
    if part in ("muzzle", "nose", "brows", "mask", "cheeks", "ears", "ear_insides"):
        return {"head": 1.0}
    if part == "head":
        skull = blend(HEAD.y - 0.03, HEAD.y + 0.03, p.y)
        return {"neck": 1.0 - skull, "head": skull}
    if part == "hands":
        hand = blend(WRIST_X - 0.02, WRIST_X + 0.012, abs(p.x))
        return {"forearm" + suffix: 1.0 - hand, "hand" + suffix: hand}
    if part == "feet":
        shin = blend(0.055, 0.095, p.y)
        toe = blend(TOE.z - 0.022, TOE.z + 0.022, p.z) * (1.0 - shin)
        return {"shin" + suffix: shin, "foot" + suffix: 1.0 - shin - toe, "toe" + suffix: toe}

    # The body and belly: every share a smooth step across a joint.
    reach = abs(p.x)
    arm = blend(SHOULDER.x - 0.035, SHOULDER.x + 0.035, reach) if p.y > CHEST.y + 0.02 else 0.0
    fore = blend(ELBOW_X - 0.035, ELBOW_X + 0.035, reach)
    leg = blend(HIP_Y + 0.03, HIP_Y - 0.045, p.y) if reach > 0.025 or p.y < HIP_Y - 0.02 else 0.0
    left = blend(-0.012, 0.012, p.x)
    shin = blend(KNEE_Y + 0.035, KNEE_Y - 0.035, p.y)
    low = blend(SPINE.y + 0.05, SPINE.y - 0.05, p.y)
    high = blend(CHEST.y - 0.06, CHEST.y + 0.05, p.y)
    neck = blend(NECK.y - 0.03, NECK.y + 0.015, p.y) if reach < 0.09 else 0.0
    trunk = (1.0 - arm) * (1.0 - leg)
    result = {
        "hips": trunk * low,
        "spine": trunk * (1.0 - low) * (1.0 - high),
        "chest": trunk * (1.0 - low) * high * (1.0 - neck),
        "neck": trunk * (1.0 - low) * high * neck,
        "upper_arm" + suffix: arm * (1.0 - fore),
        "forearm" + suffix: arm * fore,
    }
    for name, share in (("_l", left), ("_r", 1.0 - left)):
        result["thigh" + name] = leg * share * (1.0 - shin)
        result["shin" + name] = leg * share * shin
    return result


# --- The skeleton ---

def bones():
    listed = [("hips", HIPS, None), ("spine", SPINE, "hips"), ("chest", CHEST, "spine"), ("neck", NECK, "chest"), ("head", HEAD, "neck")]
    for side, suffix in ((1.0, "_l"), (-1.0, "_r")):
        listed.append(("eye" + suffix, HEAD_CENTRE + Vector((side * EYE_X, EYE_Y, EYE_Z)), "head"))
        shoulder = Vector((side * SHOULDER.x, SHOULDER.y, 0.0))
        listed.append(("upper_arm" + suffix, shoulder, "chest"))
        listed.append(("forearm" + suffix, shoulder + X * side * UPPER_ARM, "upper_arm" + suffix))
        listed.append(("hand" + suffix, shoulder + X * side * (UPPER_ARM + FOREARM), "forearm" + suffix))
        hip = Vector((side * HIP_X, HIP_Y, 0.0))
        listed.append(("thigh" + suffix, hip, "hips"))
        listed.append(("shin" + suffix, hip - Y * THIGH, "hips"))
        listed.append(("foot" + suffix, hip - Y * (THIGH + SHIN), "hips"))
        listed.append(("toe" + suffix, hip - Y * (THIGH + SHIN) + TOE, "foot" + suffix))
    parent = "hips"
    for k in range(TAIL_BONES):
        listed.append(("tail_%d" % k, tail_point(k / TAIL_BONES), parent))
        parent = "tail_%d" % k
    return listed


PARTS = [
    ("body", FUR, body, (0.006, 4, 6000)),
    ("belly", LIGHT, belly, None),
    ("feet", PAW, feet, (0.004, 3, 2400)),
    ("hands", PAW, hands, (0.003, 2, 1800)),
    ("head", FUR, head, (0.005, 4, 3200)),
    ("cheeks", LIGHT, cheeks, None),
    ("mask", DARK, mask, None),
    ("muzzle", LIGHT, muzzle, None),
    ("nose", BLACK, nose, None),
    ("brows", LIGHT, brows, None),
    ("eyes", WHITE, eyes, None),
    ("pupils", BLACK, pupils, None),
    ("ears", FUR, ears, None),
    ("ear_insides", EAR, ear_insides, None),
    ("tail", FUR, tail, (0.006, 3, 3000)),
    ("tail_rings", DARK, tail_rings, None),
]


def look_at(folder, name):
    """Renders him from the front, back, both sides, above, a quarter and his face up close."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = 700, 700
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.35, 0.42, 0.5)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.type = "ORTHO"
    scene.collection.objects.link(camera)
    scene.camera = camera
    # (Blender axes: he faces -Y, his left is +X... in Blender, Godot +Z is -Y)
    middle = (0.0, 0.1, 0.62)
    views = [("front", (0, -1, 0.08), middle, 1.45), ("back", (0, 1, 0.1), middle, 1.45),
             ("left", (1, 0, 0.05), middle, 1.45), ("right", (-1, 0, 0.05), middle, 1.45),
             ("top", (0.01, 0.0, 1.0), middle, 1.45), ("quarter", (0.7, -0.7, 0.25), middle, 1.45),
             ("face", (0.35, -0.94, 0.12), (0.0, -0.05, 0.98), 0.45)]
    for view, direction, target, frame in views:
        offset = Vector(direction).normalized() * 4.0
        camera.data.ortho_scale = frame
        camera.location = Vector(target) + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


folder = kit.PREVIEW_DIR
kit.PREVIEW_DIR = None
kit.export(NAME, bones(), PARTS, weights, MATERIALS)
if folder:
    look_at(folder, NAME)
kit.LOW = True
kit.export(NAME + "_lo", bones(), [(part, material, shapes, None) for part, material, shapes, _fuse in PARTS], weights, MATERIALS)
