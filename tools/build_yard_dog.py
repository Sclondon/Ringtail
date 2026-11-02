"""Builds Ringtail's yard dogs and exports them for Godot (the user, 2026-11-02: "the dog needs to look less
hellish", then "should be like a shiba inu and beagle and blood hound and basset hound and wiener dog").

Run from the project root:
    blender --background --python tools/build_yard_dog.py
    blender --background --python tools/build_yard_dog.py -- <preview folder> shiba   # one, with pictures

Writes models/yard_dog_<breed>.glb and a demade `_lo` of each. They are GameCommon's dog (tools/build_dog.py,
Warren's feral hound, imported here as a library: the same bones, so DogRig drives them) made into kept, friendly
neighbourhood dogs in the raccoon's style: a full, rounded body (no ribs, spine or hip bones showing), no scars or
crest, big dark eyes, small teeth hidden under the lips, each breed's own build, ears and tail, and its coat
colours painted into the vertex colours (sRGB as given, alpha 1), which YardDogRig's toon shader draws. The
breeds' looks are Claude's reading of them (placeholders until the user says otherwise).
"""

import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_dog as dogs  # noqa: E402  (Warren's dog builder: its Breed, shapes, weights and export)
import build_character as kit  # noqa: E402

V = dogs.V
X, Y, Z = kit.X, kit.Y, kit.Z
blend = kit.blend
dome = kit.dome
dogs.OUT = os.path.join(kit.ROOT, "models")

# A healthy trunk, the feral one's length: (along, centre height, half width, half height), a deep chest running
# into a full belly, no tuck.
TRUNK = [(-0.36, 0.650, 0.052, 0.062), (-0.31, 0.640, 0.086, 0.100), (-0.22, 0.630, 0.096, 0.116),
         (-0.12, 0.624, 0.097, 0.122), (-0.03, 0.614, 0.099, 0.132), (0.06, 0.600, 0.101, 0.146),
         (0.16, 0.586, 0.099, 0.160), (0.25, 0.590, 0.092, 0.150), (0.31, 0.610, 0.078, 0.115),
         (0.355, 0.638, 0.058, 0.082)]
SHOULDER = 0.565


def yard(name, leg=1.0, length=1.0, girth=1.0, head=1.0, muzzle=1.0, neck_up=0.0, ears="floppy", ear_len=1.0,
         ear_wide=1.0, tail="sickle", jowls=0.0, colours=None):
    """A breed from the feral dog's frame: legs `leg` as long, the body `length` as long and `girth` as round, the
    head `head` as big with the muzzle `muzzle` as long; ears pricked or floppy (`ear_len`, `ear_wide`); a tail
    curled, sickle, or low; `jowls` how loose its lips and throat hang (the bloodhound's)."""
    base = dogs.feral(name, 0.0, 0)
    drop = (SHOULDER - 0.03) * (1.0 - leg)

    def body_point(p):
        # (the body: shorter legs lower it, a longer body stretches it fore and aft)
        return V(p.x, p.y - drop, p.z * length)

    def leg_point(p):
        top = SHOULDER if p.z > 0.0 else 0.585
        return V(p.x * girth, 0.03 + (p.y - 0.03) * leg - (top - 0.03) * (1.0 - leg) * 0.0, p.z * length)

    spec = dict(base.__dict__)
    spec["cropped"] = 0.0
    spec["scars"] = None
    for key in ("body", "chest", "pelvis"):
        spec[key] = body_point(base.__dict__[key])
    spec["trunk"] = [(z * length, y - drop, rx * girth, ry * girth) for z, y, rx, ry in TRUNK]
    # (legs: their joints scaled down to the ground, under the hips and shoulders where the body now is)
    spec["fore"] = [V(p.x * girth, 0.03 + (p.y - 0.03) * leg, p.z * length) for p in base.fore]
    spec["hind"] = [V(p.x * girth, 0.03 + (p.y - 0.03) * leg, p.z * length) for p in base.hind]
    thick = lambda shape: [(s, w * girth * 1.18, d * girth * 1.15, f) for s, w, d, f in shape]  # noqa: E731
    spec["fore_shape"] = thick(base.fore_shape)
    spec["hind_shape"] = thick(base.hind_shape)
    spec["paw"] = (base.paw[0] * girth * 1.1, base.paw[1] * (0.9 + 0.1 * girth))
    spec["muscle"] = 1.0
    spec["neck"] = body_point(base.neck) + V(0.0, neck_up * 0.5, 0.0)
    spec["head"] = body_point(base.head) + V(0.0, neck_up, 0.0)
    spec["neck_shape"] = [(t, r * girth * 1.1, sag * (1.0 + jowls * 3.0)) for t, r, sag in base.neck_shape]
    spec["skull_at"] = base.skull_at * head
    spec["skull_size"] = Vector((base.skull_size.x * head * 1.05, base.skull_size.y * head * 1.1, base.skull_size.z * head))
    spec["muzzle"] = [(z * head * muzzle, y * head, rx * head, ry * head * (1.0 + jowls * 0.3)) for z, y, rx, ry in base.muzzle]
    nose_at, nose_size = base.nose
    spec["nose"] = (V(nose_at.x, nose_at.y * head, nose_at.z * head * muzzle), nose_size * head)
    spec["jaw_at"] = base.jaw_at * head
    spec["jaw_shape"] = [(z * head * muzzle, y * head, rx * head, ry * head) for z, y, rx, ry in base.jaw_shape]
    y_m, length_m, front, back = base.mouth
    spec["mouth"] = (y_m * head, length_m * head * muzzle, front * head, back * head)
    # Big friendly eyes, set out of the skull a little
    spec["eye"] = (V(0.041, 0.019, 0.069) * head, 0.019 * head)
    if ears == "pricked":
        spec["ear_at"] = [V(0.032, 0.044, -0.020) * head, V(0.040, 0.082, -0.028) * head,
                          V(0.044, 0.050 + 0.068 * ear_len, -0.032) * head]
    else:
        # Hanging down beside the face from high on the skull, long for the scent hounds
        spec["ear_at"] = [V(0.050, 0.036, -0.022) * head, V(0.082, 0.000, -0.012) * head,
                          V(0.086, 0.020 - 0.110 * ear_len, 0.006) * head]
    spec["tail_root"] = body_point(base.tail_root)
    spec["tail_at"] = {
        # (up and over the back in a curl)
        "curl": [(0.0, 0.0, 0.0), (0.0, 0.075, -0.035), (0.0, 0.140, 0.0), (0.0, 0.150, 0.065), (0.0, 0.110, 0.110)],
        # (carried up, a gentle curve)
        "sickle": [(0.0, 0.0, 0.0), (0.0, 0.065, -0.055), (0.0, 0.135, -0.080), (0.0, 0.200, -0.085), (0.0, 0.255, -0.070)],
        # (long and low, the hound's)
        "low": [(0.0, 0.0, 0.0), (0.0, 0.010, -0.090), (0.0, -0.030, -0.190), (0.0, -0.090, -0.270), (0.0, -0.150, -0.330)],
    }[tail]
    spec["tail_shape"] = [r * 1.5 * girth for r in base.tail_shape]
    for key in ("skull", "jaw", "ear", "tail", "neck_1", "legs"):
        spec.pop(key, None)
    breed = dogs.Breed(**spec)
    breed.ears_kind = ears
    breed.ear_wide = ear_wide
    breed.jowls = jowls
    breed.leg = leg
    breed.colours = colours
    return breed


# The coat's colours (sRGB) by where: "base" all over, "pale" under it (belly, chest, throat, muzzle, the feet),
# "saddle" over the back, "ears" the ears, "tip" the tail's end; and how far the pale reaches ("legs": how far up
# the legs, of their length).
SHIBA = dict(base=(0.78, 0.50, 0.28), pale=(0.97, 0.90, 0.78), ears=(0.78, 0.50, 0.28), saddle=None, tip=None, legs=0.35, cheeks=True)
BEAGLE = dict(base=(0.70, 0.49, 0.30), pale=(0.97, 0.96, 0.92), ears=(0.60, 0.40, 0.24), saddle=(0.14, 0.11, 0.09), tip=(0.97, 0.96, 0.92), legs=0.6, cheeks=False)
BLOODHOUND = dict(base=(0.58, 0.36, 0.22), pale=(0.66, 0.44, 0.28), ears=(0.46, 0.28, 0.17), saddle=(0.20, 0.13, 0.09), tip=None, legs=0.0, cheeks=False)
BASSET = dict(base=(0.72, 0.51, 0.31), pale=(0.97, 0.96, 0.92), ears=(0.62, 0.42, 0.25), saddle=(0.15, 0.12, 0.10), tip=(0.97, 0.96, 0.92), legs=0.85, cheeks=False)
DACHSHUND = dict(base=(0.56, 0.33, 0.18), pale=(0.66, 0.42, 0.25), ears=(0.46, 0.26, 0.14), saddle=None, tip=None, legs=0.0, cheeks=False)

DOGS = [
    yard("shiba", leg=0.8, length=0.78, girth=1.2, head=1.1, muzzle=0.8, neck_up=0.02, ears="pricked", ear_len=1.0, ear_wide=1.6, tail="curl", colours=SHIBA),
    yard("beagle", leg=0.72, length=0.85, girth=1.05, head=1.05, muzzle=0.9, neck_up=0.02, ears="floppy", ear_len=1.0, tail="sickle", colours=BEAGLE),
    yard("bloodhound", leg=0.88, length=1.0, girth=1.18, head=1.25, muzzle=1.1, neck_up=-0.02, ears="floppy", ear_len=1.8, ear_wide=1.3, tail="sickle", jowls=0.5, colours=BLOODHOUND),
    yard("basset", leg=0.42, length=1.05, girth=1.18, head=1.15, muzzle=1.05, neck_up=0.0, ears="floppy", ear_len=1.9, ear_wide=1.25, tail="sickle", jowls=0.3, colours=BASSET),
    yard("dachshund", leg=0.38, length=1.0, girth=0.85, head=0.9, muzzle=1.2, neck_up=0.03, ears="floppy", ear_len=1.1, tail="low", colours=DACHSHUND),
]


# --- What changes from the feral dog's shapes ---

def coat(breed):
    """The feral coat's shapes, without the hunger (ribs, hip bones, shoulder blades, spine), the heavy brow, the
    scars; with soft brows, and for the hounds loose jowls, a dewlap and folds over the brow."""
    def shapes(b):
        low = kit.LOW
        m = breed.muscle
        rings = [kit.lengthwise(*ring) for ring in breed.trunk]
        b.tube(dome(rings[0], -Z, 0.05)[::-1] + rings + dome(rings[-1], Z, 0.05), 18)
        top = breed.trunk[6][1] + breed.trunk[6][3]
        b.ellipsoid(V(0.0, top - 0.026, breed.chest.z), V(0.046 * m, 0.030, 0.100))
        b.ellipsoid(V(0.0, breed.fore[0].y + 0.01, breed.fore[0].z + 0.06), V(0.060 * m, 0.072, 0.056))
        for side in (1.0, -1.0):
            arm = breed.fore[0].lerp(breed.fore[1], 0.3)
            b.ellipsoid(V(side * (arm.x + 0.004), arm.y + 0.03, arm.z - 0.01), V(0.034 * m, 0.100, 0.068 * m), Matrix.Rotation(0.40, 3, "X"))
            thigh = breed.hind[0].lerp(breed.hind[1], 0.3)
            b.ellipsoid(V(side * thigh.x, thigh.y + 0.02, thigh.z + 0.01), V(0.046 * m, 0.110, 0.094 * m), Matrix.Rotation(-0.45, 3, "X"))

        base, crown = breed.neck, breed.head + V(0.0, -0.01, -0.01)
        along = (crown - base).normalized()
        across = along.cross(X).normalized()
        b.tube([(base.lerp(crown, t) - across * sag, X * r, across * (r * 1.2)) for t, r, sag in breed.neck_shape], 14)
        if breed.jowls > 0.0:
            # A dewlap: loose skin hanging under the throat
            b.ellipsoid(base.lerp(crown, 0.75) - across * 0.06 * (1.0 + breed.jowls * 0.4), V(0.040, 0.034 * (1.0 + breed.jowls), 0.050))

        skull = breed.skull
        size = breed.skull_size
        b.ellipsoid(skull, size, None, 16, 9)
        # (a soft rounded forehead, not a mastiff's heavy brow)
        b.ellipsoid(skull + V(0.0, size.y * 0.45, size.z * 0.40), V(size.x * 0.78, size.y * 0.42, size.z * 0.45))
        for side in (1.0, -1.0):
            b.ellipsoid(skull + V(side * 0.036, -0.010, 0.012), V(0.020, 0.026, 0.032), Matrix.Rotation(0.3, 3, "X"))  # cheek
        if breed.jowls > 0.0 and not low:
            # Folds of skin over the brow and down the face
            for k in range(3):
                y = size.y * (0.55 - k * 0.22)
                b.strand([skull + V(-0.050, y, 0.040 + k * 0.012), skull + V(0.0, y + 0.010, 0.062 + k * 0.012), skull + V(0.050, y, 0.040 + k * 0.012)],
                         [0.006, 0.008, 0.006], 6)
        muzzle = [(skull + V(0.0, y, z), X * rx, Y * ry) for z, y, rx, ry in breed.muzzle]
        b.tube([(skull, X * size.x * 0.8, Y * size.y * 0.8)] + muzzle + dome(muzzle[-1], Z, muzzle[-1][1].x * 0.6, 3), 14)
        reach = breed.muzzle[-1][0]
        for side in (1.0, -1.0):
            # The upper lips, down over the teeth (long and hanging on the hounds)
            # (the hounds' hang lower and fuller, as one soft flew along the jaw, not points)
            hang = 1.0 + breed.jowls * 0.35
            full = 1.0 + breed.jowls * 0.45
            b.ellipsoid(skull + V(side * 0.033 * full, -0.050 * hang, reach * 0.55), V(0.014 * full, 0.024 * full, reach * 0.48), None, 10, 6)

        b.strand([breed.tail_root + V(0.0, 0.03, 0.05)] + breed.tail, breed.tail_shape, 10)

        for suffix, joints in breed.legs.items():
            fore = suffix[1] == "f"
            dogs.limb(b, joints, breed.fore_shape if fore else breed.hind_shape)
            width, length = breed.paw
            paw = joints[3]
            b.ellipsoid(paw + V(0.0, -0.006, length * 0.5), V(width, 0.026, length), None, 10, 6)
            for toe in (() if low else (-1.5, -0.5, 0.5, 1.5)):
                b.ellipsoid(paw + V(toe * width * 0.42, -0.012, length * 1.2 - abs(toe) * length * 0.16), V(width * 0.28, 0.018, 0.022), None, 8, 5)
        return dogs.furred(breed, b, (0.0038, 4, 13000))
    return shapes


EAR_RINGS = dogs.EAR_RINGS


def ears(breed):
    """Ears without a cut one: pricked triangles (the shiba's) or soft hanging flaps, wider for the hounds."""
    def shapes(b):
        for side in (1.0, -1.0):
            if breed.ears_kind == "pricked":
                wide = V(side * 0.95, 0.0, -0.30).normalized()
                face = V(side * 0.30, 0.0, 0.95).normalized()
                table = ((0.0, 0.026, 0.010), (0.25, 0.024, 0.008), (0.55, 0.016, 0.006), (0.80, 0.008, 0.004), (1.0, 0.002, 0.002))
            else:
                # (the flat of a hanging ear faces out from the head)
                wide = V(0.0, 0.0, 1.0)
                face = V(side, 0.0, 0.0)
                table = ((0.0, 0.020, 0.008), (0.15, 0.030, 0.007), (0.45, 0.034, 0.006), (0.75, 0.032, 0.006),
                         (0.92, 0.024, 0.005), (1.0, 0.010, 0.004))
            rings = [(dogs.ear_curve(breed, t, side), wide * half * breed.ear_wide, face * thick) for t, half, thick in table]
            b.tube(dome(rings[0], -Y, 0.008, 2)[::-1] + rings + dome(rings[-1], (rings[-1][0] - rings[-2][0]).normalized(), 0.006, 2), 10)
        dogs.lay_fur(breed, b.bm, True)
    return shapes


def ear_linings(breed):
    def shapes(b):
        if breed.ears_kind != "pricked":
            return None
        for side in (1.0, -1.0):
            wide = V(side * 0.95, 0.0, -0.30).normalized()
            face = V(side * 0.30, 0.0, 0.95).normalized()
            rings = [(dogs.ear_curve(breed, t, side) + face * 0.006, wide * half, face * 0.003) for t, half in ((0.10, 0.012), (0.40, 0.012), (0.75, 0.005))]
            b.tube(rings, 8)
    return shapes


def fangs(breed):
    """Small, even upper teeth (no long fangs, no lower ones): they show only when it is angry."""
    def shapes(b):
        y, length, front, back = breed.mouth
        for side in (1.0, -1.0):
            for k in (0.25, 0.55, 0.85):
                base = breed.skull + V(side * front * 0.55 * k, y + 0.006, length * (1.0 - 0.02 * k))
                kit.spike(b, base, base - Y * 0.004, 0.0024, 5)
            for share in (0.86, 0.6):
                x = back + (front - back) * share
                base = breed.skull + V(side * x, y + 0.006, length * share)
                kit.spike(b, base, base - Y * 0.006, 0.003, 5)
    return shapes



def parts(breed):
    # (no crest of hackles; the rest as the feral dog's)
    made = [
        ("coat", 0, coat(breed), None), ("jaw", 0, dogs.jaw(breed), None), ("ears", 0, ears(breed), None),
        ("palate", 2, dogs.palate(breed), None), ("tongue", 2, dogs.tongue(breed), None),
        ("gums", 2, dogs.gums(breed), None), ("fangs", 2, fangs(breed), None),
        ("eyes", 2, dogs.eyes(breed), None), ("nose", 2, dogs.nose(breed), None),
    ]
    if breed.ears_kind == "pricked":
        made.append(("linings", 2, ear_linings(breed), None))
    return made


# Dark brown eyes (alpha 1: wet, they catch the light), a black nose, white teeth
dogs.PART_COLOURS = dict(dogs.PART_COLOURS)
dogs.PART_COLOURS["eyes"] = (0.30, 0.17, 0.08, 1.0)
dogs.PART_COLOURS["fangs"] = (0.95, 0.93, 0.86, 0.4)
dogs.PART_COLOURS["teeth"] = (0.95, 0.93, 0.86, 0.4)
dogs.PART_COLOURS["linings"] = (0.85, 0.62, 0.55, 0.0)
dogs.PART_COLOURS["tongue"] = (0.85, 0.38, 0.42, 0.6)


def paint(breed, whole, part_of):
    """The feral paint (how open each point is in red, the eyes' places), then the coat's own colours over it: the
    breed's base, its pale underside, muzzle and feet, a dark saddle, its ears and tail tip; shaded a little by how
    open the surface is. sRGB colours, alpha 1."""
    painted_paint(breed, whole, part_of + ["crest"])  # (it looks the crest up; these dogs have none)
    layer = whole.verts.layers.float_color["Color"]
    c = breed.colours
    lin = lambda srgb: tuple(srgb)  # noqa: E731  (as given: the glTF export makes the float colours linear itself)
    base, pale = Vector(lin(c["base"])), Vector(lin(c["pale"]))
    saddle = Vector(lin(c["saddle"])) if c["saddle"] else None
    ear_c = Vector(lin(c["ears"]))
    tip = Vector(lin(c["tip"])) if c["tip"] else None
    shoulder = breed.fore[0].y
    for vert in whole.verts:
        part = part_of[vert.index]
        if part not in ("coat", "jaw", "ears"):
            continue
        p = kit.from_blender(vert.co)
        open_ = vert[layer][0]
        colour = Vector(base)
        if part == "ears":
            colour = Vector(ear_c)
        else:
            y, rx, ry = dogs.trunk_at(breed, p.z)
            on_trunk = blend(breed.trunk[0][0] - 0.02, breed.trunk[0][0] + 0.04, p.z) * blend(breed.trunk[-1][0] + 0.02, breed.trunk[-1][0] - 0.04, p.z)
            belly = blend(y - ry * 0.15, y - ry * 0.75, p.y) * on_trunk
            q = p - breed.skull
            muzzle = blend(0.05, 0.10, q.z) * blend(0.005, -0.015, q.y) if part != "coat" or q.z > 0.0 and q.length < 0.4 else 0.0
            if part == "jaw":
                muzzle = 1.0
            cheeks = blend(0.0, 0.03, q.z) * blend(0.0, -0.02, q.y) * blend(0.25, 0.15, q.length) if c["cheeks"] else 0.0
            throat = blend(breed.neck.z - 0.04, breed.neck.z + 0.08, p.z) * blend(breed.neck.y + 0.02, breed.neck.y - 0.08, p.y) \
                * blend(0.30, 0.20, (p - breed.neck).length)
            legs = blend(shoulder * c["legs"] + 0.02, shoulder * c["legs"] - 0.02, p.y) if c["legs"] > 0.0 else 0.0
            amount = max(belly, muzzle, cheeks, throat, legs)
            colour = base.lerp(pale, min(amount, 1.0))
            if saddle is not None:
                back = blend(y + ry * 0.20, y + ry * 0.55, p.y) * blend(breed.trunk[1][0], breed.trunk[2][0], p.z) \
                    * blend(breed.trunk[-2][0], breed.trunk[-4][0], p.z)
                colour = colour.lerp(saddle, back * (1.0 - amount))
            off, along = dogs.chain_param(p, breed.tail)
            if p.z < breed.tail[0].z and off < 0.06:
                if tip is not None:
                    colour = colour.lerp(tip, blend(2.6, 3.4, along))
                elif saddle is None and c["cheeks"]:
                    colour = colour.lerp(pale, 0.5 * blend(0.0, 1.0, along))
        shade = 0.82 + 0.18 * min(max(open_, 0.0), 1.0)
        vert[layer] = (colour.x * shade, colour.y * shade, colour.z * shade, 1.0)


painted_paint = dogs.paint
dogs.coat = coat
dogs.ears = ears
dogs.parts = parts
dogs.paint = paint
dogs.scar_lines = lambda breed: []
dogs.DOGS = DOGS


def export(breed, preview):
    # (named yard_dog_<breed>)
    real = breed.name
    breed.name = "yard_dog_" + real
    try:
        dogs.export(breed, preview)
    finally:
        breed.name = real


if __name__ == "__main__":
    preview = kit.PREVIEW_DIR or None
    only = set(kit.ONLY) if kit.ONLY else None
    kit.ONLY = None
    for low in (False, True):
        kit.LOW = low
        for breed in DOGS:
            if only and breed.name not in only:
                continue
            export(breed, preview)
