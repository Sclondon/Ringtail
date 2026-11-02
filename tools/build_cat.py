"""The yard cat (the enemy), built as the raccoon is and in his style: on the boy's skeleton with a six-bone tail,
through the raccoon's `reshape` (short limbs, big head), bushy zigzag fur ruffs, big cartoon eyes and whiskers. A
ginger tabby (Claude's pick, a placeholder): pointed ears with pink insides, green eyes with slit pupils, a pink nose,
a cream muzzle and chest, and a long tail of zigzag cones, ginger and dark orange by turns.

Run from the project root:
    blender -b --factory-startup --python tools/build_cat.py
    blender -b --factory-startup --python tools/build_cat.py -- <folder>   # also renders it from every side

Writes models/cat.glb and models/cat_lo.glb (and editable copies in tools/). Then: godot --headless --path . --import
Posed by scripts/cat_rig.gd (a RaccoonRig, on all fours whenever it is on the ground).
"""

import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_character as kit  # noqa: E402
import build_raccoon as racc  # noqa: E402

X, Y, Z = kit.X, kit.Y, kit.Z
HC = racc.HEAD_CENTRE

NAME = "cat"

# A longer, thinner tail than his, carried up: the raccoon's tail helpers read these as they build.
racc.TAIL_DIR = Vector((0.0, 0.55, -1.0)).normalized()
racc.TAIL_LENGTH = 0.8


def _tail_radius(t):
    profile = [(0.0, 0.034), (0.1, 0.044), (0.5, 0.05), (0.85, 0.046), (1.0, 0.03)]
    for (a, ra), (b, rb) in zip(profile, profile[1:]):
        if t <= b:
            return ra + (rb - ra) * (t - a) / (b - a)
    return profile[-1][1]


racc.tail_radius = _tail_radius

# --- Colours (sRGB): a ginger tabby ---

FUR, CREAM, STRIPE, PAW, IRIS, PUPIL, PINK, LIMB = range(8)
MATERIALS = [
    ("fur", (0.84, 0.43, 0.14)),
    ("light", (0.97, 0.90, 0.78)),
    ("stripe", (0.5, 0.2, 0.07)),
    ("paw", (0.96, 0.88, 0.76)),
    ("eye", (0.62, 0.86, 0.28)),
    ("pupil", (0.03, 0.03, 0.04)),
    ("pink", (0.95, 0.58, 0.62)),
    ("limb", (0.76, 0.38, 0.12)),
]


# --- The head: the raccoon's skull, with a cat's face on it ---

def muzzle(b):
    # Two round whisker pads and a small chin, not a snout
    for side in (1.0, -1.0):
        b.ellipsoid(HC + Vector((side * 0.028, -0.045, 0.108)), Vector((0.036, 0.03, 0.032)), None, 12, 6)
    b.ellipsoid(HC + Vector((0.0, -0.075, 0.095)), Vector((0.03, 0.02, 0.025)), None, 10, 5)


def nose(b):
    # A small pink nose, wider at the top
    b.tube([(HC + Vector((0.0, y, 0.135)), X * rx, Z * 0.012) for y, rx in ((-0.03, 0.006), (-0.022, 0.016), (-0.014, 0.019), (-0.008, 0.012))], 10)


def whiskers(b):
    for side in (1.0, -1.0):
        for k, (rise, droop) in enumerate(((0.01, 0.006), (0.0, -0.006), (-0.01, -0.022))):
            root = HC + Vector((side * 0.05, -0.042 + rise, 0.122 - k * 0.006))
            tip = root + Vector((side * 0.17, droop, -0.03))
            b.strand([root, root.lerp(tip, 0.5) + Vector((0.0, 0.008, 0.0)), tip], [0.004, 0.003, 0.0018], 5)


EYE = Vector((0.05, 0.018, 0.092))
EYE_R = 0.036


def eyes(b):
    # Big green eyes, the whole eye coloured as a cat's is
    for side in (1.0, -1.0):
        b.ellipsoid(HC + Vector((side * EYE.x, EYE.y, EYE.z)), Vector((EYE_R, EYE_R * 1.15, EYE_R * 0.9)), Matrix.Rotation(side * 0.25, 3, Y), 14, 7)


def pupils(b):
    # Slits
    for side in (1.0, -1.0):
        centre = HC + Vector((side * (EYE.x + 0.008), EYE.y, EYE.z + EYE_R * 0.78))
        b.ellipsoid(centre, Vector((0.006, 0.027, 0.008)), Matrix.Rotation(side * 0.25, 3, Y), 8, 6)


def cheeks(b):
    # Cream fluff down the sides of the face and the chin
    for side in (1.0, -1.0):
        tilt = Matrix.Rotation(side * -0.5, 3, Z)
        b.ellipsoid(HC + Vector((side * 0.11, -0.05, 0.03)), Vector((0.05, 0.036, 0.046)), tilt, 12, 6)


def _cone(b, base, tip, half_width, half_depth, segments=10):
    # A flattened cone, its long side up the ear, closed at both ends
    axis = (tip - base).normalized()
    across = axis.cross(Z if abs(axis.z) < 0.9 else X).normalized()
    deep = axis.cross(across).normalized()
    rings = [(base.lerp(tip, t), across * half_width * (1.0 - t), deep * half_depth * (1.0 - t)) for t in (0.0, 0.35, 0.7, 0.96)]
    b.tube(kit.dome(rings[0], -axis, 0.01, 2)[::-1] + rings, segments)


def ears(b):
    for side in (1.0, -1.0):
        base = HC + Vector((side * 0.075, 0.075, -0.02))
        _cone(b, base, base + Vector((side * 0.05, 0.11, 0.0)), 0.055, 0.02)


def ear_insides(b):
    for side in (1.0, -1.0):
        base = HC + Vector((side * 0.074, 0.08, -0.004))
        _cone(b, base, base + Vector((side * 0.042, 0.085, 0.004)), 0.036, 0.008)


def stripes(b):
    # Tabby marks: three short bars on the brow, sunk in so only a sliver stands proud
    for x, y, z, h in ((0.0, 0.088, 0.096, 0.03), (0.034, 0.08, 0.09, 0.024), (-0.034, 0.08, 0.09, 0.024)):
        b.ellipsoid(HC + Vector((x, y, z)), Vector((0.011, h, 0.012)), Matrix.Rotation(-0.6, 3, X), 8, 5)


def weights(part, p):
    if part in ("stripes",):
        return {"head": 1.0}
    return racc.weights(part, p)


def reshaped_weights(part, p):
    return weights(part, racc.as_drawn(p))


PARTS = [
    ("body", FUR, racc.body, (0.006, 4, 6000)),
    ("feet", PAW, racc.feet, (0.004, 3, 2400)),
    ("hands", PAW, racc.hands, (0.003, 2, 1800)),
    ("head", FUR, racc.head, (0.005, 4, 3200)),
    ("cheeks", CREAM, cheeks, None),
    ("muzzle", CREAM, muzzle, None),
    ("nose", PINK, nose, None),
    ("eyes", IRIS, eyes, None),
    ("pupils", PUPIL, pupils, None),
    ("ears", FUR, ears, None),
    ("ear_insides", PINK, ear_insides, None),
    ("stripes", STRIPE, stripes, None),
    ("tail", FUR, racc.tail, (0.006, 3, 3000)),
    ("tail_grey", FUR, racc.tail_grey, None),
    ("tail_dark", STRIPE, racc.tail_dark, None),
    ("whiskers", CREAM, whiskers, None),
    ("lower_limbs", LIMB, racc.lower_limbs, (0.004, 3, 2400)),
    ("ruffs", FUR, racc.ruffs, None),
]

if __name__ == "__main__":
    racc.reshaping()
    folder = kit.PREVIEW_DIR
    kit.PREVIEW_DIR = None
    kit.export(NAME, racc.reshaped_bones(), PARTS, reshaped_weights, MATERIALS)
    if folder:
        racc.look_at(folder, NAME)
    kit.LOW = True
    kit.export(NAME + "_lo", racc.reshaped_bones(), [(part, material, shapes, None) for part, material, shapes, _fuse in PARTS], reshaped_weights, MATERIALS)
