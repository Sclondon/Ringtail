"""The raccoon: a figure on the boy's skeleton, with a tail of six bones.

Run from the project root:
    blender -b --factory-startup --python tools/build_raccoon.py
    blender -b --factory-startup --python tools/build_raccoon.py -- <folder>   # also renders him from every side

Writes models/raccoon.glb and models/raccoon_lo.glb (and editable copies in tools/).
Then: godot --headless --path . --import

Built on GameCommon's build_character.py, as build_figure_template.py is (see it
for what scripts/character_rig.gd needs of a figure). He is short in the leg,
round in the body, big in the head, with a masked face, white brows and muzzle,
round ears, dark hand-like paws and long plantigrade feet. The tail (bones
tail_0..tail_5, a chain under hips) is posed by scripts/raccoon_rig.gd.
"""

import math
import os
import random
import sys

import bmesh
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
# The hock: where his shin meets his long paw, raised behind the ankle as an animal's is (Fantastic Mr. Fox)
HOCK = Vector((0.0, 0.135, -0.07))
HEAD_CENTRE = Vector((0.0, 0.985, 0.01))
HEAD_RADII = Vector((0.13, 0.115, 0.12))
EYE_X, EYE_Y, EYE_Z, EYE_R = 0.052, 0.012, 0.094, 0.03

# The tail: from its root low on his back, straight back and a little up when he is made.
TAIL_ROOT = Vector((0.0, 0.50, -0.13))
TAIL_DIR = Vector((0.0, 0.25, -1.0)).normalized()
TAIL_LENGTH = 0.74  # (a little longer: the user, 2026-11-01)
TAIL_BONES = 6

# --- Colours (sRGB) ---

# (after the user's photos, 2026-11-01: warm grey-brown fur, sleek darker forearms and shins, black hands and
# feet, white-rimmed ears, tan and black rings on the tail)
FUR, LIGHT, DARK, PAW, WHITE, BLACK, EAR, LIMB, TAN, RING = range(10)
MATERIALS = [
    ("fur", (0.52, 0.47, 0.43)),
    ("light", (0.90, 0.88, 0.83)),
    ("dark", (0.13, 0.12, 0.13)),
    ("paw", (0.10, 0.09, 0.09)),
    ("eye", (0.97, 0.97, 0.95)),
    ("pupil", (0.03, 0.03, 0.04)),
    ("ear", (0.30, 0.26, 0.24)),
    ("limb", (0.28, 0.25, 0.23)),
    # (the tail nearer his own colour: the user, "his tail shouldnt be as different a shade")
    ("tan", (0.56, 0.50, 0.45)),
    ("ring", (0.22, 0.19, 0.18)),
]


def tail_point(t):
    return TAIL_ROOT + TAIL_DIR * (TAIL_LENGTH * t)


def tail_radius(t):
    # (along it, 0 to 1 -> radius): thin at the root, bushy, then to a blunt tip
    # (thicker than it was: the user, 2026-11-01, "His tail should be a thicker and a little longer")
    profile = [(0.0, 0.055), (0.08, 0.088), (0.3, 0.12), (0.55, 0.122), (0.8, 0.102), (0.95, 0.068), (1.0, 0.045)]
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
        arm = [(-0.05, 0.058), (0.0, 0.058), (0.09, 0.05), (UPPER_ARM + 0.02, 0.043)]
        b.tube([(Vector((side * (SHOULDER.x + d), SHOULDER.y, 0.0)), Y * r, Z * r) for d, r in arm], 12)
        leg = [(HIP_Y + 0.04, 0.084), (HIP_Y - 0.02, 0.094), (0.35, 0.078), (0.30, 0.066), (KNEE_Y - 0.02, 0.055)]
        b.tube([kit.upright(side * HIP_X, y, 0.0, r, r * 1.08) for y, r in leg], 16)


def lower_limbs(b):
    # Forearms and shins: sleeker and darker than the furry upper arms and thighs, from under the fur cuffs
    for side in (1.0, -1.0):
        fore = [(UPPER_ARM - 0.03, 0.04), (UPPER_ARM + 0.02, 0.037), (0.28, 0.034), (0.345, 0.031), (0.375, 0.028)]
        b.tube([(Vector((side * (SHOULDER.x + d), SHOULDER.y, 0.0)), Y * r, Z * r) for d, r in fore], 12)
        # (an animal's leg, after Fantastic Mr. Fox: the shin runs down and back to a hock raised behind the ankle,
        # and the long paw angles forward from it to the toes; the user, 2026-11-01)
        shin = [(KNEE_Y + 0.03, 0.05, 0.0), (KNEE_Y - 0.02, 0.047, -0.008), (0.19, 0.042, -0.032), (0.155, 0.037, -0.055),
                (HOCK.y, 0.034, HOCK.z)]
        b.tube([kit.upright(side * HIP_X, y, z, r, r * 1.08) for y, r, z in shin], 14)


def feet(b):
    for side in (1.0, -1.0):
        x = side * HIP_X
        # The long paw: from the hock, raised behind the ankle, down and forward to the ball of the foot
        b.strand([Vector((x, HOCK.y + 0.01, HOCK.z - 0.004)), Vector((x, 0.095, -0.03)), Vector((x, 0.055, 0.025)),
                  Vector((x, 0.036, 0.07))], [0.034, 0.031, 0.029, 0.031], 12)
        # The heel pad at the back of the hock
        b.ellipsoid(Vector((x, HOCK.y - 0.005, HOCK.z - 0.022)), Vector((0.026, 0.03, 0.02)), None, 8, 5)
        # The ball of the foot, flat on the ground, and four toes ahead of it
        b.ellipsoid(Vector((x, 0.026, 0.085)), Vector((0.042, 0.026, 0.045)), None, 12, 6)
        for k in range(4):
            across = (k - 1.5) / 1.5
            b.ellipsoid(Vector((x + across * 0.028, 0.017, 0.128 - abs(across) * 0.012)), Vector((0.013, 0.017, 0.02)), None, 8, 4)


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
            # (long, as a raccoon's are: the user, 2026-11-01, "his fingers need to be longer")
            tip = root + Vector((side * (0.085 - abs(across) * 0.016), -0.014, across * 0.026))
            b.strand([root, root.lerp(tip, 0.55) + Vector((0.0, 0.002, 0.0)), tip], [0.011, 0.010, 0.008])
        b.strand([wrist + Vector((side * x, y, z)) for x, y, z in ((0.012, -0.004, 0.026), (0.034, -0.009, 0.054), (0.058, -0.012, 0.072))],
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


def whiskers(_b):
    """Three to a side, out from the snout behind the nose, fanned and drooping a little (the user asked for them),
    springy: tagged as spikes of his head from root (still) to tip (the user: "his whiskers should also be physics
    springs"). A finished mesh in Blender's axes."""
    made = bmesh.new()
    tags = {}
    for side in (1.0, -1.0):
        # (longer and thinner, and each its own length: the user, 2026-11-01)
        for k, (rise, droop, reach) in enumerate(((0.012, 0.01, 0.27), (0.004, -0.008, 0.21), (-0.006, -0.03, 0.25), (-0.014, -0.05, 0.18))):
            root = HEAD_CENTRE + Vector((side * 0.034, -0.034 + rise, 0.168 - k * 0.007))
            tip = root + Vector((side * reach, droop, -0.06 * reach / 0.2))
            rings = []
            steps = 5
            for s in range(steps + 1):
                t = s / steps
                at = root.lerp(tip, t) + Vector((0.0, 0.008 * math.sin(math.pi * t), 0.0))
                along = (tip - root).normalized()
                u = along.cross(Y).normalized()
                w = along.cross(u).normalized()
                r = 0.0028 * (1.0 - 0.65 * t)
                ring = []
                for j in range(4):
                    a = math.tau * j / 4
                    vert = made.verts.new(kit.to_blender(reshape(at + (u * math.cos(a) + w * math.sin(a)) * r)))
                    tags[vert] = (REGION["head"], t, None, WHISKERS, 0.0)
                    ring.append(vert)
                rings.append(ring)
            for a, b in zip(rings, rings[1:]):
                for j in range(4):
                    made.faces.new((a[j], a[(j + 1) % 4], b[(j + 1) % 4], b[j]))
            made.faces.new(rings[0][::-1])
            made.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(made, faces=made.faces[:])
    tag_spikes(made, tags)
    mesh = bpy.data.meshes.new("whiskers")
    made.to_mesh(mesh)
    made.free()
    return mesh


def brows(b):
    for side in (1.0, -1.0):
        tilt = Matrix.Rotation(side * 0.25, 3, Z)
        b.ellipsoid(HEAD_CENTRE + Vector((side * 0.052, 0.062, 0.082)), Vector((0.042, 0.017, 0.034)), tilt, 12, 5)


def eyes(b):
    for side in (1.0, -1.0):
        b.ellipsoid(HEAD_CENTRE + Vector((side * EYE_X, EYE_Y, EYE_Z)), Vector((EYE_R, EYE_R * 1.1, EYE_R)), None, 14, 7)


def lids(b):
    """An upper lid over each eye: the top half of a shell a little larger than the eye, the mask'"'"'s colour. At rest it
    covers the top half of the eye; the rig rolls it back to open the eye and down over it to blink (bones lid_l,
    lid_r at each eye'"'"'s middle)."""
    for side in (1.0, -1.0):
        centre = HEAD_CENTRE + Vector((side * EYE_X, EYE_Y, EYE_Z))
        rings = []
        for k in range(7):
            phi = math.pi / 2 * k / 6
            r = EYE_R * 1.16
            rings.append((centre + Y * r * math.sin(phi) * 1.1, X * r * math.cos(phi), Z * r * math.cos(phi)))
        b.tube(rings, 16)


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
    # A slim core for the cones to sit on
    count = 12 if kit.LOW else 24
    rings = [tail_ring(k / count, 0.55) for k in range(count + 1)]
    b.tube(kit.dome(rings[0], -TAIL_DIR, 0.02, 2)[::-1] + rings + kit.dome(rings[-1], TAIL_DIR, 0.02, 2), 12)


# Every spike carries in its second texture coordinates (the "Metres" layer, which nothing else of the fur uses)
# which part of him it grows from, and how far out along it each point is, as (region, -flex - 0.001): the game
# springs each region after its own movement and bends the spikes by it, flex squared (scripts/raccoon_rig.gd,
# FUR_REGIONS; the user: "his hair fur spikes should react to physics"). Points of everything else keep their
# Metres coordinates, which are never negative. (glTF flips V on export: in Godot a tagged point reads 1.001 + flex,
# the rest at most 1.)
REGION = {"hips": 0, "chest": 1, "upper_arm_l": 2, "forearm_l": 3, "upper_arm_r": 4, "forearm_r": 5, "thigh_l": 6,
          "shin_l": 7, "thigh_r": 8, "shin_r": 9, "tail_0": 10, "head": 16}


# What a spike's points also carry, for the fur shader to shape it live (scripts/fur_look.gd; the user, 2026-11-02:
# "I should be able to control the angle of the fur and how dense, and the ring mane as well", "and the fur length"):
# which group of fur it is in (UV2.x's tenths, over the region), how far each point is from the spike's root (UV
# x, y and, through paint_grit, the colour's green), and the colour's blue: at a tip its rank (spikes above the
# density are folded away), at the root which side of the spike it is (across it, for the hair textures).
BODY, MANE, CROWN, TAIL_FUR, WHISKERS = range(5)
SPIKE = "Spike"
_ranks = random.Random(99)


def tag_spikes(made, tags):
    """Writes each point's tag from `tags` (BMVert -> (region, flex[, root as drawn, group, blue])) into the Metres
    coordinates (region and group, flex), the plain ones (its offset from its root, x and y) and the Spike ones (the
    offset's z, the blue: paint_grit moves them into the colour)."""
    layer = made.loops.layers.uv.new(kit.METRES)
    plain = made.loops.layers.uv.get(kit.PLAIN) or made.loops.layers.uv.new(kit.PLAIN)
    spike = made.loops.layers.uv.new(SPIKE)
    for face in made.faces:
        for loop in face.loops:
            tag = tags.get(loop.vert, (0, 0.0))
            region, flex = tag[0], tag[1]
            root, group, blue = tag[2:5] if len(tag) >= 5 else (None, BODY, 0.0)
            loop[layer].uv = (float(region) + 0.1 * group, -flex - 0.001)
            off = kit.from_blender(loop.vert.co) - reshape(root) if root is not None else Vector()
            loop[plain].uv = (off.x, off.y)
            loop[spike].uv = (off.z, blue)


# The rings are spiky cones, one after another down the tail, each flaring out towards the tip in a zigzag of
# spikes (the user, 2026-11-01: "his tail rings should be spiky cones sorta like zigzagoon"), grey and dark by turns.
CONES = 8
SPIKES = 9


def cones(dark):
    """The grey cones (or the dark ones), as a finished mesh in Blender's axes."""
    up = TAIL_DIR.cross(X).normalized()
    made = bmesh.new()
    tags = {}

    def ring(t, radius, spiky=False, region=10):
        loop = []
        count = SPIKES * 2 if spiky else SPIKES
        for j in range(count):
            a = math.tau * j / count
            r = radius * (1.0 if not spiky or j % 2 == 0 else 0.68)
            # (spike tips lean back towards the tip of the tail)
            along = t + (0.035 if spiky and j % 2 == 0 else 0.0)
            p = tail_point(along) + (X * math.cos(a) + up * math.sin(a)) * r
            vert = made.verts.new(kit.to_blender(reshape(p)))
            tags[vert] = (region, (1.0 if j % 2 == 0 else 0.45) if spiky else 0.0, None, TAIL_FUR, (0.0 if j % 2 == 0 else float((j // 2) % 2)) if spiky else float(j % 2))
            loop.append(vert)
        return loop

    def join(a, b):
        # (rings of different counts: each corner of the longer one fans to the nearest of the shorter)
        for j in range(len(b)):
            k0 = j * len(a) // len(b)
            k1 = ((j + 1) * len(a) // len(b)) % len(a)
            j1 = (j + 1) % len(b)
            if k0 == k1:
                made.faces.new((a[k0], b[j], b[j1]))
            else:
                made.faces.new((a[k0], a[k1], b[j1], b[j]))

    step = 0.95 / CONES
    for k in range(CONES):
        # (the last, the tip, is dark whatever its turn)
        if (k % 2 == 1 or k == CONES - 1) != dark:
            continue
        start = 0.05 + k * step - 0.04
        end = 0.05 + (k + 1) * step
        last = k == CONES - 1
        region = REGION["tail_0"] + min(TAIL_BONES - 1, int((start + end) * 0.5 * TAIL_BONES))
        base = ring(start, tail_radius(start) * 0.5, region=region)
        rim = ring(end - 0.01, tail_radius(min(end, 0.97)) * (1.3 if not last else 1.1), True, region)
        join(base, rim)
        if last:
            tip = made.verts.new(kit.to_blender(reshape(tail_point(1.06))))
            tags[tip] = (region, 1.0, None, TAIL_FUR, 0.0)
            for j in range(len(rim)):
                made.faces.new((rim[j], rim[(j + 1) % len(rim)], tip))
        else:
            back = ring(end + 0.005, tail_radius(end) * 0.5, region=region)
            join(back, rim)
        made.faces.new(base[::-1])
        if not last:
            made.faces.new(back)
    bmesh.ops.recalc_face_normals(made, faces=made.faces[:])
    tag_spikes(made, tags)
    mesh = bpy.data.meshes.new("cones")
    made.to_mesh(mesh)
    made.free()
    return mesh


def tail_grey(_b):
    return cones(False)


def tail_dark(_b):
    return cones(True)


# --- Fur types (the user, 2026-11-02: "a model editor where I can switch out the fur with different texture types
# like the hair editor in gloaming"): each a build of its own, models/raccoon_fur_<type>.glb (`-- fur=<type>`), whose
# mesh scripts/fur_look.gd swaps in. "spiky" is the plain build, raccoon.glb, and these multipliers are all 1 for it.
# "cones" gives his body, upper arms and thighs the tail's treatment: rings of spiky cones, banded (the user: "I like
# his tail fur, can we make his body and arms work like that too? — or an option for that in the editor").

FUR_TYPES = {
    "spiky": {},
    "soft": {"length": 0.75, "width": 1.9, "count": 1.3, "flare": 0.75},
    "shaggy": {"length": 1.7, "width": 1.25, "count": 1.25, "flare": 1.35, "droop": 0.6},
    "sleek": {"length": 0.45, "width": 1.2, "count": 0.5, "flare": 0.35},
    "wiry": {"length": 1.35, "width": 0.45, "count": 1.7, "flare": 1.1},
    "cones": {"cones": True},
}
FUR_NOW = {"length": 1.0, "width": 1.0, "count": 1.0, "flare": 1.0, "droop": 0.0, "cones": False}


def use_fur(kind):
    """Sets FUR_NOW for a fur type (FUR_TYPES), before building."""
    FUR_NOW.update({"length": 1.0, "width": 1.0, "count": 1.0, "flare": 1.0, "droop": 0.0, "cones": False})
    FUR_NOW.update(FUR_TYPES[kind])


def _n(count):
    """How many tufts of a kind, for the fur type."""
    return count if FUR_NOW["count"] == 1.0 else max(1, int(round(count * FUR_NOW["count"])))


def _flare(flare):
    return flare if FUR_NOW["flare"] == 1.0 else 1.0 + (flare - 1.0) * FUR_NOW["flare"]


def body_cones(dark):
    """His body, upper arms and thighs in the tail's spiky cones, one after another down each, banded by turns (the
    dark ones, or the others): the "cones" fur type. A finished mesh in Blender's axes."""
    made = bmesh.new()
    tags = {}

    def ring(centre, u, v, radius, spiky=False, region=0, lean=Vector(), base=None):
        # (`base`: the cone's base ring (centre, u, v, radius), where each of the rim's points grows from)
        loop = []
        count = SPIKES * 2 if spiky else SPIKES
        for j in range(count):
            a = math.tau * j / count
            tip = spiky and j % 2 == 0
            r = radius * (1.0 if not spiky or tip else 0.68)
            p = centre + (lean if tip else Vector()) + (u * math.cos(a) + v * math.sin(a)) * r
            vert = made.verts.new(kit.to_blender(reshape(p)))
            if spiky:
                root = base[0] + (base[1] * math.cos(a) + base[2] * math.sin(a)) * base[3]
                tags[vert] = (region, 1.0 if tip else 0.45, root, BODY, _ranks.random() if tip else float((j // 2) % 2))
            else:
                tags[vert] = (region, 0.0, None, BODY, float(j % 2))
            loop.append(vert)
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

    def band(start, end, count, at, size, region_of, first=0):
        """`count` cones from `start` to `end` along a line: at(s) its centre, size(s) its (u, v) there; each cone's
        base at its start, its spiky rim flared at its end, overlapping the next as the tail's do."""
        step = (end - start) / count
        for k in range(count):
            if ((k + first) % 2 == 1) != dark:
                continue
            s0 = start + k * step - step * 0.35
            s1 = start + (k + 1) * step
            u0, v0 = size(s0)
            u1, v1 = size(s1)
            region = region_of((s0 + s1) * 0.5)
            lean = (at(s1) - at(s0)).normalized() * abs(step) * 0.45
            base = ring(at(s0), u0, v0, 0.7, region=region)
            rim = ring(at(s1), u1, v1, 1.6, True, region, lean, (at(s0), u0, v0, 0.7))
            back = ring(at(s1) + (at(s1) - at(s0)).normalized() * 0.006, u1, v1, 0.62, region=region)
            join(base, rim)
            join(back, rim)
            made.faces.new(base[::-1])
            made.faces.new(back)

    # The body, neck to seat, the cones pointing down (its profile as drawn: height, half width, half depth, offset)
    profile = [(0.44, 0.145, 0.125, -0.01), (0.50, 0.178, 0.152, 0.0), (0.58, 0.188, 0.162, 0.012),
               (0.66, 0.178, 0.152, 0.012), (0.73, 0.158, 0.132, 0.004), (0.79, 0.142, 0.112, 0.0), (0.83, 0.10, 0.09, 0.0)]

    def body_at(y):
        for (y0, rx0, rz0, z0), (y1, rx1, rz1, z1) in zip(profile, profile[1:]):
            if y0 <= y <= y1:
                f = (y - y0) / (y1 - y0)
                return rx0 + (rx1 - rx0) * f, rz0 + (rz1 - rz0) * f, z0 + (z1 - z0) * f
        return profile[0][1:] if y < profile[0][0] else profile[-1][1:]

    band(0.82, 0.45, 5, lambda y: Vector((0.0, y, body_at(y)[2])),
         lambda y: (X * body_at(y)[0], Z * body_at(y)[1]), lambda y: REGION["chest" if y > 0.7 else "hips"])
    for side in (1.0, -1.0):
        suffix = "_l" if side > 0 else "_r"
        # Upper arms, out from the shoulder (as drawn: along X), the cones pointing out
        band(0.0, UPPER_ARM + 0.01, 3, lambda d: Vector((side * (SHOULDER.x + d), SHOULDER.y, 0.0)),
             lambda d: (Y * (0.058 - d * 0.08), Z * (0.058 - d * 0.08)), lambda d: REGION["upper_arm" + suffix], 1)
        # Thighs, down from the hip
        band(HIP_Y + 0.02, KNEE_Y - 0.01, 3, lambda y: Vector((side * HIP_X, y, 0.0)),
             lambda y: (X * (0.06 + (y - KNEE_Y) * 0.15), Z * (0.065 + (y - KNEE_Y) * 0.15)),
             lambda y: REGION["thigh" + suffix], 1)
    bmesh.ops.recalc_face_normals(made, faces=made.faces[:])
    tag_spikes(made, tags)
    mesh = bpy.data.meshes.new("body_cones_dark" if dark else "body_cones")
    made.to_mesh(mesh)
    made.free()
    return mesh


def ruffs(_b):
    """Bushy fur: zigzag ruffs of spikes like the tail's, flaring out and pointing down, on his upper arms and thighs,
    as cuffs at the elbows and knees, and as shaggy layers round his body (the user: "bushy", not thin; and their
    photos: a fluffy body, sleek forearms and shins); and loose tufts scattered between them. No two spikes the same
    length, the ruffs tilted and set a little off true, so the fur reads as shaggy and not as rings (the user: "The
    fur shouldnt all be the same length and not in perfect rings on his body either"). A finished mesh in Blender's
    axes."""
    made = bmesh.new()
    tags = {}
    rng = random.Random(11)

    def ring(centre, axis, u, v, radius, lean=0.0, spiky=False, wide=1.0, region=0, base=None):
        # (`base`: the ruff's base ring (centre, radius), where each of the rim's points grows from)
        loop = []
        count = SPIKES * 2 if spiky else SPIKES
        twist = rng.uniform(0.0, math.tau)
        for j in range(count):
            a = math.tau * j / count + twist + (rng.uniform(-0.22, 0.22) * math.tau / count if spiky else 0.0)
            tip = spiky and j % 2 == 0
            r = radius * (rng.uniform(0.72, 1.4) if tip else (0.62 * rng.uniform(0.9, 1.1) if spiky else 1.0))
            p = centre + axis * (lean * rng.uniform(0.4, 1.7) if tip else 0.0) + (u * math.cos(a) * wide + v * math.sin(a)) * r
            vert = made.verts.new(kit.to_blender(reshape(p)))
            if spiky:
                root = base[0] + (u * math.cos(a) * wide + v * math.sin(a)) * base[1]
                tags[vert] = (region, 1.0 if tip else 0.45, root, BODY, _ranks.random() if tip else float((j // 2) % 2))
            else:
                tags[vert] = (region, 0.0, None, BODY, float(j % 2))
            loop.append(vert)
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

    def ruff(centre, axis, radius, flare, region, lean=0.09, wide=1.0):
        # (axis points down the limb: the spikes lean that way; each ruff tipped and nudged a little off true)
        axis = (axis + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * 0.22).normalized()
        centre = centre + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * 0.008
        u = axis.cross(Z if abs(axis.z) < 0.9 else X).normalized()
        v = axis.cross(u).normalized()
        base = ring(centre - axis * 0.035, axis, u, v, radius * 0.7, wide=wide, region=region)
        rim = ring(centre, axis, u, v, radius * _flare(flare), lean, True, wide, region, (centre - axis * 0.035, radius * 0.7))
        back = ring(centre + axis * 0.01, axis, u, v, radius * 0.7, wide=wide, region=region)
        join(base, rim)
        join(back, rim)
        made.faces.new(base[::-1])
        made.faces.new(back)

    for side in (1.0, -1.0):
        out = X * side
        suffix = "_l" if side > 0 else "_r"
        # Arms: along X from the shoulder (as drawn)
        # (laid back along him, not standing straight out, and more of them: the user, "the fur shouldnt stick so
        # straight out and there should be more of it")
        for d, r, flare in ((0.06, 0.052, 1.3), (0.13, 0.047, 1.27), (UPPER_ARM, 0.043, 1.22)):
            ruff(Vector((side * (SHOULDER.x + d), SHOULDER.y, 0.0)), out, r, flare,
                 REGION[("upper_arm" if d < UPPER_ARM else "forearm") + suffix])
        # Legs: down from the hip
        for y, r, flare in ((HIP_Y - 0.03, 0.086, 1.27), (0.33, 0.072, 1.25), (KNEE_Y, 0.056, 1.2)):
            ruff(Vector((side * HIP_X, y, 0.0)), -Y, r, flare, REGION[("thigh" if y > KNEE_Y else "shin") + suffix])
        # Loose tufts between the ruffs of his upper arms and thighs
        for k in range(_n(10)):
            d = rng.uniform(0.02, UPPER_ARM - 0.02)
            a = rng.uniform(0.0, math.tau)
            normal = Vector((0.0, math.cos(a), math.sin(a)))
            root = Vector((side * (SHOULDER.x + d), SHOULDER.y, 0.0)) + normal * 0.045
            tuft(made, tags, root, (normal * 0.45 + out).normalized(), rng.uniform(0.02, 0.045), 0.024,
                 REGION["upper_arm" + suffix], rng)
        for k in range(_n(11)):
            y = rng.uniform(KNEE_Y + 0.02, HIP_Y - 0.02)
            a = rng.uniform(0.0, math.tau)
            normal = Vector((math.cos(a), 0.0, math.sin(a)))
            root = Vector((side * HIP_X, y, 0.0)) + normal * 0.065
            tuft(made, tags, root, (normal * 0.45 - Y).normalized(), rng.uniform(0.02, 0.05), 0.026,
                 REGION["thigh" + suffix], rng)
    # Shaggy layers round his body, widest at the belly
    for y, depth, wide, flare in ((0.47, 0.142, 1.15, 1.24), (0.6, 0.162, 1.16, 1.21),
                                   (0.74, 0.132, 1.2, 1.2)):
        ruff(Vector((0.0, y, 0.006)), -Y, depth, flare, REGION["chest" if y > 0.7 else "hips"], 0.11, wide)
    # ...and loose tufts all over it between them, of every length
    profile = [(0.44, 0.145, 0.125, -0.01), (0.50, 0.178, 0.152, 0.0), (0.58, 0.188, 0.162, 0.012),
               (0.66, 0.178, 0.152, 0.012), (0.73, 0.158, 0.132, 0.004), (0.79, 0.142, 0.112, 0.0)]
    for k in range(_n(80)):
        y = rng.uniform(0.45, 0.79)
        rx, rz, zo = profile[0][1], profile[0][2], profile[0][3]
        for (y0, rx0, rz0, z0), (y1, rx1, rz1, z1) in zip(profile, profile[1:]):
            if y0 <= y <= y1:
                f = (y - y0) / (y1 - y0)
                rx, rz, zo = rx0 + (rx1 - rx0) * f, rz0 + (rz1 - rz0) * f, z0 + (z1 - z0) * f
                break
        a = rng.uniform(0.0, math.tau)
        root = Vector((math.cos(a) * rx * 0.94, y, zo + math.sin(a) * rz * 0.94))
        normal = Vector((math.cos(a) / rx, 0.0, math.sin(a) / rz)).normalized()
        tuft(made, tags, root, (normal * 0.5 - Y).normalized(), rng.uniform(0.022, 0.06), 0.036,
             REGION["chest" if y > 0.7 else "hips"], rng)
    bmesh.ops.recalc_face_normals(made, faces=made.faces[:])
    tag_spikes(made, tags)
    mesh = bpy.data.meshes.new("ruffs")
    made.to_mesh(mesh)
    made.free()
    return mesh


def tuft(made, tags, root, direction, length, width, region, rng, group=BODY):
    """One loose spike of fur: a flat-ish four-sided point from `root` along `direction`, its tip springing."""
    # (the fur type: FUR_TYPES)
    length *= FUR_NOW["length"]
    width *= FUR_NOW["width"]
    if FUR_NOW["droop"] > 0.0:
        direction = (direction - Y * FUR_NOW["droop"]).normalized()
    u = direction.cross(Y if abs(direction.y) < 0.9 else X).normalized()
    v = direction.cross(u).normalized()
    base = []
    for j in range(4):
        a = math.tau * j / 4 + 0.4
        p = root - direction * 0.012 + (u * math.cos(a) * 1.4 + v * math.sin(a) * 0.6) * width * 0.5
        vert = made.verts.new(kit.to_blender(reshape(p)))
        tags[vert] = (region, 0.0, root, group, float(j % 2))
        base.append(vert)
    bend = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * 0.25
    tip = made.verts.new(kit.to_blender(reshape(root + (direction + bend).normalized() * length)))
    tags[tip] = (region, 1.0, root, group, _ranks.random())
    for j in range(4):
        made.faces.new((base[j], base[(j + 1) % 4], tip))
    made.faces.new(base[::-1])


def head_fur(_b):
    """Fur on his head as a mane: a ring of tufts all round his face, just behind it (the user, 2026-11-02: "the head
    fur should be like a mane ring around his head", after "you cant really see the fur on his head"; then "less in
    number and shorter and wider"), and short fur over the rest of the head. Two rows,
    pointing out from the face and swept back; shorter under the jaw. A finished mesh in Blender's axes (Y up, the
    face towards +Z)."""
    made = bmesh.new()
    tags = {}
    rng = random.Random(5)
    for row, (depth, reach) in enumerate([(0.0, 1.0), (-0.16, 0.85)]):
        count = _n(16 - row * 4)
        for k in range(count):
            t = math.tau * (k + rng.uniform(-0.3, 0.3) + row * 0.5) / count
            z = depth + rng.uniform(-0.04, 0.04)
            r = math.sqrt(1.0 - z * z)
            n = Vector((math.cos(t) * r, math.sin(t) * r, z))
            root = HEAD_CENTRE + Vector((n.x * HEAD_RADII.x, n.y * HEAD_RADII.y, n.z * HEAD_RADII.z)) * 0.97
            radial = Vector((math.cos(t), math.sin(t), 0.0))
            # (under the jaw it is short, so it doesn't stick into his chest)
            under = max(0.0, -math.sin(t))
            length = rng.uniform(0.04, 0.062) * reach * (1.0 - 0.55 * under)
            tuft(made, tags, root, (radial - Z * 0.45).normalized(), length, 0.058, REGION["head"], rng, MANE)
    # And short fur over the rest of his head besides: the crown, the back and the sides, laid back (none on the
    # face) (the user, 2026-11-02: "he should have head fur besides the mane ring")
    placed = 0
    while placed < _n(60):
        a = rng.uniform(0.0, math.tau)
        b = rng.uniform(-0.35, 1.25)
        n = Vector((math.cos(b) * math.cos(a), math.sin(b), math.cos(b) * math.sin(a)))
        if n.z > 0.2 and n.y < 0.75:
            continue
        root = HEAD_CENTRE + Vector((n.x * HEAD_RADII.x, n.y * HEAD_RADII.y, n.z * HEAD_RADII.z)) * 0.97
        out = Vector((n.x / HEAD_RADII.x, n.y / HEAD_RADII.y, n.z / HEAD_RADII.z)).normalized()
        tuft(made, tags, root, (out - Z * 0.4 - Y * 0.6).normalized(), rng.uniform(0.03, 0.05), 0.028, REGION["head"], rng, CROWN)
        placed += 1
    bmesh.ops.recalc_face_normals(made, faces=made.faces[:])
    tag_spikes(made, tags)
    mesh = bpy.data.meshes.new("head_fur")
    made.to_mesh(mesh)
    made.free()
    return mesh


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
    if part.startswith("tail"):
        return tail_weights(p)
    if part in ("eyes", "pupils"):
        return {"eye" + suffix: 1.0}
    if part == "lids":
        return {"lid" + suffix: 1.0}
    if part == "brows":
        return {"brow" + suffix: 1.0}
    if part in ("ears", "ear_insides"):
        return {"ear" + suffix: 1.0}
    if part in ("muzzle", "nose", "whiskers", "mask", "cheeks", "head_fur"):
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

    # The body and the ruffs: every share a smooth step across a joint. (A ruff's spikes reach further from the
    # arm than the arm does, and go with it all the same.)
    reach = abs(p.x)
    arm = blend(SHOULDER.x - 0.035, SHOULDER.x + 0.035, reach) if p.y > CHEST.y + 0.02 or (part == "ruffs" and abs(p.y - SHOULDER.y) < 0.13) else 0.0
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
        # (for his expressions: a lid over each eye, a brow over it, and each ear at its root)
        listed.append(("lid" + suffix, HEAD_CENTRE + Vector((side * EYE_X, EYE_Y, EYE_Z)), "head"))
        listed.append(("brow" + suffix, HEAD_CENTRE + Vector((side * 0.052, 0.062, 0.072)), "head"))
        listed.append(("ear" + suffix, HEAD_CENTRE + Vector((side * 0.075, 0.07, -0.02)), "head"))
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
    ("feet", PAW, feet, (0.004, 3, 2400)),
    ("hands", PAW, hands, (0.003, 2, 1800)),
    ("head", FUR, head, (0.005, 4, 3200)),
    ("cheeks", LIGHT, cheeks, None),
    ("mask", DARK, mask, None),
    ("muzzle", LIGHT, muzzle, None),
    ("nose", BLACK, nose, None),
    ("brows", LIGHT, brows, None),
    ("eyes", WHITE, eyes, None),
    ("lids", DARK, lids, None),
    ("pupils", BLACK, pupils, None),
    ("ears", FUR, ears, None),
    ("ear_insides", LIGHT, ear_insides, None),
    ("tail", FUR, tail, (0.006, 3, 3000)),
    ("tail_grey", TAN, tail_grey, None),
    ("tail_dark", RING, tail_dark, None),
    ("whiskers", LIGHT, whiskers, None),
    ("lower_limbs", LIMB, lower_limbs, (0.004, 3, 2400)),
    ("ruffs", FUR, ruffs, None),
    ("head_fur", FUR, head_fur, None),
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


# --- His proportions, laid over the shapes as drawn above ---
# Everything above is drawn at the first proportions. The user (2026-11-01): "his arms and legs are a little too
# long, and his head should be bigger". So every point (and bone) is taken through `reshape` on its way into the
# model: the legs shorter (all of him above the hips comes down with them), the arms shorter from the shoulder
# (the hands as they were), the head bigger about the top of the neck. `weights` is asked about points as drawn.

LEG_SCALE = 0.82
ARM_SCALE = 0.8
HEAD_SCALE = 1.2
HEAD_PIVOT = HEAD.y  # (as drawn)
DROP = (HIP_Y - ANKLE_Y) * (1.0 - LEG_SCALE)
ARM_BAND = (SHOULDER.y - 0.09, SHOULDER.y + 0.09)


def head_grow(y):
    """How much bigger a point at this height (as drawn) is made: none below the neck, all of it at the head."""
    return 1.0 + (HEAD_SCALE - 1.0) * blend(NECK.y, HEAD.y + 0.03, y)


def reshape(p):
    p = Vector(p)
    # The arms: shorter from the shoulder to the wrist; the hand beyond it keeps its size.
    reach = abs(p.x)
    if ARM_BAND[0] < p.y < ARM_BAND[1] and reach > SHOULDER.x:
        if reach < WRIST_X:
            reach = SHOULDER.x + (reach - SHOULDER.x) * ARM_SCALE
        else:
            reach = reach - (WRIST_X - SHOULDER.x) * (1.0 - ARM_SCALE)
        p.x = math.copysign(reach, p.x)
    # The head: bigger about the top of his neck.
    grow = head_grow(p.y)
    if grow > 1.0:
        p = Vector((0.0, HEAD_PIVOT, 0.0)) + (p - Vector((0.0, HEAD_PIVOT, 0.0))) * grow
    # The legs: shorter between the ankle and the hip, and all above coming down by as much.
    if p.y > HIP_Y:
        p.y -= DROP
    elif p.y > ANKLE_Y:
        p.y = ANKLE_Y + (p.y - ANKLE_Y) * LEG_SCALE
    return p


def as_drawn(p):
    """Near enough the inverse of `reshape`, for weighing points."""
    p = Vector(p)
    if p.y > HIP_Y - DROP:
        p.y += DROP
    elif p.y > ANKLE_Y:
        p.y = ANKLE_Y + (p.y - ANKLE_Y) / LEG_SCALE
    # (the head's growth undone with the height it would have had: one step is close enough)
    grow = head_grow(HEAD_PIVOT + (p.y - HEAD_PIVOT) / HEAD_SCALE if p.y > HEAD_PIVOT else p.y)
    if grow > 1.0:
        p = Vector((0.0, HEAD_PIVOT, 0.0)) + (p - Vector((0.0, HEAD_PIVOT, 0.0))) / grow
    reach = abs(p.x)
    if ARM_BAND[0] < p.y < ARM_BAND[1] and reach > SHOULDER.x:
        new_wrist = SHOULDER.x + (WRIST_X - SHOULDER.x) * ARM_SCALE
        reach = SHOULDER.x + (reach - SHOULDER.x) / ARM_SCALE if reach < new_wrist else reach + (WRIST_X - SHOULDER.x) * (1.0 - ARM_SCALE)
        p.x = math.copysign(reach, p.x)
    return p


_made = kit.Builder.__init__


def _reshaping(self):
    _made(self)
    self.place = reshape


def reshaping():
    """Every Builder made from now on puts its points through `reshape`."""
    kit.Builder.__init__ = _reshaping


def reshaped_bones():
    return [(bone, reshape(at), parent) for bone, at, parent in bones()]


def reshaped_weights(part, p):
    return weights(part, as_drawn(p))


# --- Grit: gritty gradients over him, baked into the vertex colours ---
# (the user, 2026-11-01: "there needs to be gritty gradients on his body"). Darker low down and lighter over his
# top, mottled at two sizes, and each spike of fur darker at its root and paler at its tip. Written as a float
# colour layer's red (glTF COLOR_0, linear, at most 1: so the value over GRIT_SCALE), its alpha 1 to say it is there; the
# fur shader multiplies by it (scripts/fur_look.gd). Green and blue shape the spikes (tag_spikes). Eyes and nose are left clean.
GRIT_SCALE = 1.3
CLEAN = ("eye", "pupil")


def grit_at(p, flex):
    from mathutils import noise
    height = min(1.0, max(0.0, (p.y - 0.05) / 1.0))
    shade = 0.68 + 0.42 * height ** 0.7
    shade *= 1.0 + 0.3 * noise.noise(p * 11.0) + 0.18 * noise.noise(p * 40.0 + Vector((3.1, 7.7, 1.3)))
    if flex >= 0.0:
        shade *= 0.84 + 0.3 * flex
    return min(GRIT_SCALE, max(0.0, shade))


def paint_grit(name):
    """Paints the grit onto every mesh of the figure just exported, and writes it out again."""
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        mesh = obj.data
        layer = mesh.color_attributes.new("Grit", "FLOAT_COLOR", "CORNER")
        tags = mesh.uv_layers.get(kit.METRES)
        spike = mesh.uv_layers.get(SPIKE)
        clean = {k for k, m in enumerate(mesh.materials) if m and m.name.split(".")[0] in CLEAN}
        for poly in mesh.polygons:
            for index in poly.loop_indices:
                if poly.material_index in clean:
                    layer.data[index].color = (1.0, 1.0, 1.0, 0.0)
                    continue
                p = kit.from_blender(mesh.vertices[mesh.loops[index].vertex_index].co)
                v = tags.data[index].uv.y if tags else 0.0
                flex = -v - 0.001 if v < -0.0005 else -1.0
                g = grit_at(p, flex) / GRIT_SCALE
                # (red the grit; green and blue what the fur shader shapes a spike by: tag_spikes)
                shaping = spike.data[index].uv if spike else (0.0, 0.0)
                layer.data[index].color = (g, min(1.0, max(0.0, shaping[0] * 2.0 + 0.5)), shaping[1], 1.0)
        if spike:
            mesh.uv_layers.remove(spike)
        mesh.color_attributes.active_color = layer
        mesh.color_attributes.render_color_index = mesh.color_attributes.find("Grit")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(kit.ROOT, "tools", name + ".blend"))
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(kit.ROOT, "models", name + ".glb"),
        export_format="GLB",
        export_yup=True,
        export_animations=False,
        export_skins=True,
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=False,
        export_try_sparse_sk=True,
        export_morph_tangent=False,
    )
    print("GRIT %s" % name)


# (run as a script it builds the raccoon; imported, as tools/build_cat.py does, it only lends its shapes)
def fur_arg():
    """The fur type asked for after `--` (`fur=<type>`), taken out of what the kit reads there; None for the plain build."""
    asked = [arg for arg in sys.argv[sys.argv.index("--") + 1:] if arg.startswith("fur=")] if "--" in sys.argv else []
    if kit.PREVIEW_DIR and kit.PREVIEW_DIR.startswith("fur="):
        kit.PREVIEW_DIR = None
    kit.ONLY = [arg for arg in kit.ONLY if not arg.startswith("fur=")]
    return asked[0][4:] if asked else None


def fur_parts(parts):
    """The parts for the fur type in FUR_NOW: with "cones", the body's ruffs are banded cones, the dark ones a part of
    their own (in the tail's dark ring colour)."""
    if not FUR_NOW["cones"]:
        return parts
    swapped = []
    for part in parts:
        if part[0] == "ruffs":
            swapped.append(("ruffs", part[1], lambda _b: body_cones(False), None))
            swapped.append(("ruffs_band", RING, lambda _b: body_cones(True), None))
        else:
            swapped.append(part)
    return swapped


if __name__ == "__main__":
    reshaping()
    kind = fur_arg()
    folder = kit.PREVIEW_DIR
    kit.PREVIEW_DIR = None
    if kind and kind != "spiky":
        # A fur type of its own: models/raccoon_fur_<type>.glb, the full model only (the editor swaps its mesh in)
        use_fur(kind)
        name = NAME + "_fur_" + kind
        kit.export(name, reshaped_bones(), fur_parts(PARTS), reshaped_weights, MATERIALS)
        paint_grit(name)
        if folder:
            look_at(folder, name)
        sys.exit(0)
    kit.export(NAME, reshaped_bones(), PARTS, reshaped_weights, MATERIALS)
    paint_grit(NAME)
    if folder:
        look_at(folder, NAME)
    kit.LOW = True
    kit.export(NAME + "_lo", reshaped_bones(), [(part, material, shapes, None) for part, material, shapes, _fuse in PARTS], reshaped_weights, MATERIALS)
    paint_grit(NAME + "_lo")
