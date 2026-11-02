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

import bpy

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

FUR, CREAM, STRIPE, PAW, IRIS, PUPIL, PINK, LIMB, SHINE = range(9)
MATERIALS = [
    ("fur", (0.84, 0.43, 0.14)),
    ("light", (0.97, 0.90, 0.78)),
    ("stripe", (0.5, 0.2, 0.07)),
    ("paw", (0.96, 0.88, 0.76)),
    ("eye", (0.62, 0.86, 0.28)),
    ("pupil", (0.03, 0.03, 0.04)),
    ("pink", (0.95, 0.58, 0.62)),
    ("limb", (0.76, 0.38, 0.12)),
    ("shine", (1.0, 1.0, 1.0)),
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


# The eyes (the user, 2026-11-02: "the cat eyes need work they look creepy"): big and round, set into the face (most
# of each eye inside the head, so they do not bulge), the whole eye its iris colour (the look's "eye") as a cat's
# is, in a thin dark rim; a soft oval pupil, not a slit; a white glint up and out; and an upper lid of fur over
# each, on the raccoon's lid bones, so CatRig lets it rest a little lowered and the rig blinks it.
EYE = Vector((0.05, 0.014, 0.082))
EYE_R = 0.04
TURN = 0.3
# (his lids, eye bones and lid bones are built at these: racc.lids, racc.bones)
racc.EYE_X, racc.EYE_Y, racc.EYE_Z, racc.EYE_R = EYE.x, EYE.y, EYE.z, EYE_R


def _eye(side):
    """An eye's centre, its turn out to the side, and the way it looks."""
    turn = Matrix.Rotation(side * TURN, 3, Y)
    return HC + Vector((side * EYE.x, EYE.y, EYE.z)), turn, turn @ Z


def eyes(b):
    for side in (1.0, -1.0):
        centre, turn, _ = _eye(side)
        b.ellipsoid(centre, Vector((EYE_R, EYE_R * 0.96, EYE_R * 0.86)), turn, 16, 8)


def rims(b):
    # A thin dark rim round each eye, as a cat's has
    for side in (1.0, -1.0):
        centre, turn, ahead = _eye(side)
        b.ellipsoid(centre - ahead * 0.005, Vector((EYE_R * 1.1, EYE_R * 1.06, EYE_R * 0.86)), turn, 16, 8)


def pupils(b):
    # Soft upright ovals, a little wider than tall is round
    for side in (1.0, -1.0):
        centre, turn, ahead = _eye(side)
        b.ellipsoid(centre + ahead * EYE_R * 0.78, Vector((0.0125, 0.02, 0.008)), turn, 12, 6)


def glints(b):
    # A small white catch-light, up and to his left on both (one light)
    for side in (1.0, -1.0):
        centre, turn, ahead = _eye(side)
        b.ellipsoid(centre + ahead * EYE_R * 0.84 + Vector((0.011, 0.013, 0.0)), Vector((0.0062, 0.0062, 0.003)), turn, 8, 4)


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
    if part in ("rims", "glints"):
        return {("eye_l" if p.x >= 0.0 else "eye_r"): 1.0}
    return racc.weights(part, p)


def reshaped_weights(part, p):
    return weights(part, racc.as_drawn(p))


# --- A cat's build: longer and skinnier than him (the user, 2026-11-02: "the cats need ... longer skinnier bodies")
# Laid over the raccoon's own `reshape`: the body from the hips to the neck drawn out LONG times (all above it carried
# up), and the body and legs made SLIM times as wide and deep; the arms brought in to the narrower shoulders, and as
# thin; the tail carried up with the hips, not stretched; the head as it was.

LONG = 1.38
SLIM = 0.76
_RACCOON_RESHAPE = racc.reshape
_RACCOON_AS_DRAWN = racc.as_drawn
_HIPS = racc.HIP_Y - racc.DROP
_NECK = racc.NECK.y - racc.DROP
_SHIFT = (_NECK - _HIPS) * (LONG - 1.0)
_ARM_Y = racc.SHOULDER.y - racc.DROP
_SHOULDER = racc.SHOULDER.x
_BEHIND = 0.17
_TAIL_Y = racc.TAIL_ROOT.y - racc.DROP


def _stretch(y):
    if y <= _HIPS:
        return y
    if y <= _NECK:
        return _HIPS + (y - _HIPS) * LONG
    return y + _SHIFT


def _unstretch(y):
    if y <= _HIPS:
        return y
    if y <= _HIPS + (_NECK - _HIPS) * LONG:
        return _HIPS + (y - _HIPS) / LONG
    return y - _SHIFT


def _slim_at(y):
    """How much narrower at this height (after stretching): SLIM up to the neck, none in the head."""
    return SLIM + (1.0 - SLIM) * kit.blend(_NECK + _SHIFT - 0.05, _NECK + _SHIFT + 0.04, y)


def _squeeze(v, edge, slim):
    """Narrower about the middle: within `edge`, scaled; beyond it (the arms, the tail), moved in by as much."""
    if abs(v) <= edge:
        return v * slim
    return math.copysign(abs(v) - edge * (1.0 - slim), v)


def cat_reshape(p):
    p = _RACCOON_RESHAPE(p)
    y = _stretch(p.y)
    slim = _slim_at(y)
    body = Vector((_squeeze(p.x, _SHOULDER, slim), y, _squeeze(p.z, _BEHIND, slim)))
    # (the arms: brought in with the shoulders, as thin, not drawn out)
    arm = Vector((_squeeze(p.x, _SHOULDER, SLIM), _stretch(_ARM_Y) + (p.y - _ARM_Y) * SLIM, p.z * SLIM))
    # (the tail: carried up with its root, not drawn out)
    tail = Vector((p.x * SLIM, p.y + _stretch(_TAIL_Y) - _TAIL_Y, _squeeze(p.z, _BEHIND, SLIM)))
    in_arm = kit.blend(_SHOULDER - 0.03, _SHOULDER + 0.02, abs(p.x)) * kit.blend(_ARM_Y + 0.13, _ARM_Y + 0.09, p.y) \
        * kit.blend(_ARM_Y - 0.13, _ARM_Y - 0.09, p.y)
    in_tail = kit.blend(-_BEHIND + 0.03, -_BEHIND - 0.03, p.z) * kit.blend(_HIPS - 0.05, _HIPS + 0.02, p.y)
    return body.lerp(arm, in_arm).lerp(tail, in_tail * (1.0 - in_arm))


def cat_as_drawn(p):
    """Near enough the inverse of `cat_reshape`, for weighing points."""
    p = Vector(p)
    if abs(p.x) > _SHOULDER * SLIM + 0.01 and abs(p.y - _stretch(_ARM_Y)) < 0.1:
        q = Vector((math.copysign(abs(p.x) + _SHOULDER * (1.0 - SLIM), p.x), _ARM_Y + (p.y - _stretch(_ARM_Y)) / SLIM, p.z / SLIM))
    elif p.z < -_BEHIND * SLIM and p.y > _HIPS - 0.05:
        q = Vector((p.x / SLIM, p.y - (_stretch(_TAIL_Y) - _TAIL_Y), math.copysign(abs(p.z) + _BEHIND * (1.0 - SLIM), p.z)))
    else:
        slim = _slim_at(p.y)
        q = Vector((p.x / slim if abs(p.x) <= _SHOULDER * slim else math.copysign(abs(p.x) + _SHOULDER * (1.0 - slim), p.x),
                    _unstretch(p.y), p.z / slim if abs(p.z) <= _BEHIND * slim else math.copysign(abs(p.z) + _BEHIND * (1.0 - slim), p.z)))
    return _RACCOON_AS_DRAWN(q)


# --- Its markings, baked into the vertex colours for the shader (scripts/fur_look.gd) to draw patterns with ---
# (the user: "the cats need color variations"; "different fur types"). Red: grit, as his (over GRIT_SCALE). Green:
# where a cat's white goes (bib and belly, muzzle and chin, paws and socks). Blue: patches (a slow mottle, 0..1, for
# calico and white patches). Alpha: the tabby's stripe (across the body, round the legs and tail). Drawn as the
# points lie as built (in the rest pose), so they stay put on it as it moves.

def _markings(p, flex):
    from mathutils import noise
    grit = racc.grit_at(p, flex) / racc.GRIT_SCALE
    # (white: the front of the chest and belly, the muzzle and chin, the paws and lower legs)
    chest = kit.blend(0.02, 0.09, p.z) * kit.blend(_HIPS + 0.05, _HIPS + 0.12, p.y) * kit.blend(_NECK + _SHIFT + 0.12, _NECK + _SHIFT + 0.02, p.y)
    face = kit.blend(0.05, 0.11, p.z) * kit.blend(racc.HEAD_CENTRE.y + _SHIFT - 0.02, racc.HEAD_CENTRE.y + _SHIFT - 0.1, p.y)
    feet = kit.blend(0.13, 0.08, p.y)
    hands = kit.blend(racc.WRIST_X - 0.1, racc.WRIST_X - 0.04, abs(p.x)) * kit.blend(0.14, 0.2, p.y)
    wobble = 0.08 * noise.noise(p * 14.0)
    white = min(1.0, max(0.0, max(chest, face, feet, hands) + wobble))
    patches = min(1.0, max(0.0, 0.5 + 0.9 * noise.noise(p * 5.5 + Vector((2.3, 0.7, 5.1)))))
    # (stripes run round each part: across the body and legs by height, round the arms by reach, round the tail
    # along it)
    if p.z < -_BEHIND:
        along = -p.z * 1.2 + p.y * 0.4
    elif abs(p.x) > _SHOULDER * SLIM + 0.02 and abs(p.y - _stretch(_ARM_Y)) < 0.1:
        along = abs(p.x)
    else:
        along = p.y
    stripe = 0.5 + 0.5 * math.sin(along * 52.0 + 2.2 * noise.noise(p * 7.0))
    return (grit, white, patches, stripe)


def paint_markings(name):
    """Paints the markings onto the figure just exported, and writes it out again (as paint_grit does his grit)."""
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        mesh = obj.data
        layer = mesh.color_attributes.new("Markings", "FLOAT_COLOR", "CORNER")
        # (its colour is all markings: a spike's side across it, for the hair textures, goes in the plain UV's x)
        spike = mesh.uv_layers.get(racc.SPIKE)
        plain = mesh.uv_layers.get(kit.PLAIN)
        if spike and plain:
            for index in range(len(mesh.loops)):
                plain.data[index].uv = (spike.data[index].uv.y, 0.0)
        if spike:
            mesh.uv_layers.remove(spike)
        tags = mesh.uv_layers.get(kit.METRES)
        clean = {k for k, m in enumerate(mesh.materials) if m and m.name.split(".")[0] in ("eye", "pupil", "pink", "shine")}
        for poly in mesh.polygons:
            for index in poly.loop_indices:
                if poly.material_index in clean:
                    layer.data[index].color = (1.0 / racc.GRIT_SCALE, 0.0, 0.0, 0.0)
                    continue
                p = kit.from_blender(mesh.vertices[mesh.loops[index].vertex_index].co)
                v = tags.data[index].uv.y if tags else 0.0
                flex = -v - 0.001 if v < -0.0005 else -1.0
                layer.data[index].color = _markings(p, flex)
        mesh.color_attributes.active_color = layer
        mesh.color_attributes.render_color_index = mesh.color_attributes.find("Markings")
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
    print("MARKINGS %s" % name)


PARTS = [
    ("body", FUR, racc.body, (0.006, 4, 6000)),
    ("feet", PAW, racc.feet, (0.004, 3, 2400)),
    ("hands", PAW, racc.hands, (0.003, 2, 1800)),
    ("head", FUR, racc.head, (0.005, 4, 3200)),
    ("cheeks", CREAM, cheeks, None),
    ("muzzle", CREAM, muzzle, None),
    ("nose", PINK, nose, None),
    ("rims", PUPIL, rims, None),
    ("eyes", IRIS, eyes, None),
    ("pupils", PUPIL, pupils, None),
    ("glints", SHINE, glints, None),
    ("lids", FUR, racc.lids, None),
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

# Its fur types (racc.FUR_TYPES; the user: "They should also have different fur types"): models/cat.glb is "spiky",
# and `-- fur=<type>` builds models/cat_<type>.glb. `-- fur=all` builds every one of CAT_FURS.
CAT_FURS = ["spiky", "sleek", "shaggy", "soft"]

if __name__ == "__main__":
    racc.reshaping()
    racc.reshape = cat_reshape
    racc.as_drawn = cat_as_drawn
    kind = racc.fur_arg()
    folder = kit.PREVIEW_DIR
    kit.PREVIEW_DIR = None
    for fur in (CAT_FURS if kind == "all" else [kind or "spiky"]):
        racc.use_fur(fur)
        name = NAME if fur == "spiky" else NAME + "_" + fur
        kit.export(name, racc.reshaped_bones(), PARTS, reshaped_weights, MATERIALS)
        paint_markings(name)
        if folder:
            racc.look_at(folder, name)
    if not kind or kind in ("spiky", "all"):
        kit.LOW = True
        racc.use_fur("spiky")
        kit.export(NAME + "_lo", racc.reshaped_bones(), [(part, material, shapes, None) for part, material, shapes, _fuse in PARTS], reshaped_weights, MATERIALS)
        paint_markings(NAME + "_lo")
