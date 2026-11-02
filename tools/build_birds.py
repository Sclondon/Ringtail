"""The crow and the owl (the user, 2026-11-02: "we need to work on a nice owl and crow model as well"), in the
raccoon's style: smooth rounded forms with scattered spiky tufts of feather (as his fur is), heavy lids, cel shaded in
the game (Toon). After photos of a large-billed (jungle) crow and a Eurasian eagle-owl / great horned owl.

    crow  glossy blue-black, a big arched bill and steep brow, a shaggy throat, fingered primaries, a wedge of a tail
    owl   tawny, a streaked chest, a mottled back, a pale facial disc rimmed dark, ear tufts, big orange eyes under heavy
          lids, barred broad wings and tail, feathered legs and black talons

Each bird is a tree of parts, each its own object with its origin at its joint, so the game can move them (BirdBody):

    <bird>_body
      <bird>_head            (neck)        owl: <bird>_lid_l, _lid_r (eye centres; turned down about X to blink)
      <bird>_tail            (rump)
      <bird>_leg_l, _leg_r   (hips)
      <bird>_wing_l          (shoulder) > <bird>_wing_l_fore (elbow) > <bird>_wing_l_hand (wrist) > _p0.._p6 (each
                             primary, at its root); and _r

Wings are built spread flat (the plane of the wing level, the bird's left out along +X), the rest pose of every part
is no turn at all, and BirdBody folds them. Godot axes in the code: Y up, +Z ahead, +X the bird's left.

Run from the project root:
    blender -b --factory-startup --python tools/build_birds.py [-- <folder>]   # the folder gets four sides of each

Writes models/crow.glb, models/owl.glb and tools/birds.blend. (The first, plainer crow was tools/build_hazards.py's.)
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PREVIEW_DIR = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 1 else None

COLOURS = {
    # crow: blue-black, a bluer sheen on some tufts, a deeper black under
    "crow": (0.17, 0.17, 0.22),
    "crowsheen": (0.22, 0.24, 0.34),
    "crowdeep": (0.08, 0.08, 0.11),
    "crowbill": (0.13, 0.13, 0.15),
    "crowleg": (0.2, 0.2, 0.22),
    # owl
    "owl": (0.5, 0.36, 0.22),
    "owldark": (0.2, 0.14, 0.09),
    "owllight": (0.8, 0.66, 0.46),
    "owlchest": (0.72, 0.53, 0.31),
    "owlface": (0.7, 0.6, 0.47),
    "owlrim": (0.16, 0.11, 0.07),
    "owlbib": (0.93, 0.9, 0.82),
    "owlbeak": (0.16, 0.16, 0.18),
    "talon": (0.07, 0.07, 0.08),
    # eyes (Toon.apply gives these three a wet glint)
    "iris": (1.0, 0.52, 0.08),
    "pupil": (0.03, 0.03, 0.04),
    "eyewhite": (0.95, 0.95, 0.92),
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


def pitch(p, angle):
    """Turns `p` about X (Godot axes): a positive angle lifts what is ahead (+Z) up."""
    c, s = math.cos(angle), math.sin(angle)
    return Vector((p[0], p[1] * c + p[2] * s, -p[1] * s + p[2] * c))


class Part:
    """One object being made, in Godot axes in the model's space; `origin` is its joint."""

    def __init__(self, name, origin=(0.0, 0.0, 0.0), parent=None):
        self.name = name
        self.origin = Vector(origin)
        self.parent = parent
        self.bm = bmesh.new()
        self.mats = []
        self.obj = None

    def _index(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def _v(self, p):
        return self.bm.verts.new(to_blender(Vector(p) - self.origin))

    def blob(self, centre, radii, mat, segments=14, rings=9, tilt=0.0):
        """An ellipsoid, pitched by `tilt`."""
        made = bmesh.ops.create_uvsphere(self.bm, u_segments=segments, v_segments=rings, radius=1.0)
        index = self._index(mat)
        for v in made["verts"]:
            p = Vector((v.co.x * radii[0], v.co.z * radii[1], -v.co.y * radii[2]))
            v.co = to_blender(Vector(centre) + pitch(p, tilt) - self.origin)
        for f in {f for v in made["verts"] for f in v.link_faces}:
            f.material_index = index

    def cap(self, centre, radius, pole, reach, mat, segments=12, rings=5):
        """A cap of a sphere about `pole`, from the pole out to `reach` (radians) from it: an eyelid."""
        index = self._index(mat)
        pole = Vector(pole).normalized()
        u = pole.cross(Vector((1, 0, 0)) if abs(pole.x) < 0.9 else Vector((0, 0, 1))).normalized()
        w = pole.cross(u)
        top = self._v(Vector(centre) + pole * radius)
        rows = []
        for r in range(1, rings + 1):
            a = reach * r / rings
            rows.append([self._v(Vector(centre) + (pole * math.cos(a) + (u * math.cos(t) + w * math.sin(t)) * math.sin(a)) * radius)
                         for t in (math.tau * k / segments for k in range(segments))])
        for k in range(segments):
            self.bm.faces.new((top, rows[0][k], rows[0][(k + 1) % segments])).material_index = index
        for a, b in zip(rows, rows[1:]):
            for k in range(segments):
                self.bm.faces.new((a[k], b[k], b[(k + 1) % segments], a[(k + 1) % segments])).material_index = index
        return rows[-1]

    def tube(self, points, radii, mat, segments=8, squash=(1.0, 1.0)):
        """Rings along `points`; `squash` scales each ring across (level) and up and down."""
        index = self._index(mat)
        rings = []
        for i, point in enumerate(points):
            point = Vector(point)
            ahead = (Vector(points[min(i + 1, len(points) - 1)]) - Vector(points[max(i - 1, 0)])).normalized()
            u = ahead.cross(Vector((0, 1, 0)) if abs(ahead.y) < 0.9 else Vector((1, 0, 0))).normalized()
            w = ahead.cross(u).normalized()
            rings.append([self._v(point + (u * math.cos(a) * squash[0] + w * math.sin(a) * squash[1]) * radii[i])
                          for a in (math.tau * k / segments for k in range(segments))])
        for a, b in zip(rings, rings[1:]):
            for k in range(segments):
                self.bm.faces.new((a[k], a[(k + 1) % segments], b[(k + 1) % segments], b[k])).material_index = index
        for ring in (rings[0], rings[-1][::-1]):
            self.bm.faces.new(ring[::-1]).material_index = index

    def spike(self, base, direction, length, width, mat):
        """A thin three-sided spike of feather from `base` along `direction` (as the raccoon's fur is)."""
        index = self._index(mat)
        d = Vector(direction).normalized()
        u = d.cross(Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((1, 0, 0))).normalized()
        w = d.cross(u).normalized()
        base = Vector(base)
        corners = [self._v(base + (u * math.cos(a) + w * math.sin(a) * 0.45) * width) for a in (0.0, math.tau / 3, 2 * math.tau / 3)]
        tip = self._v(base + d * length)
        for k in range(3):
            self.bm.faces.new((corners[k], corners[(k + 1) % 3], tip)).material_index = index
        self.bm.faces.new(corners[::-1]).material_index = index

    def tufts(self, centre, radii, count, mats, length, sweep, keep=None, tilt=0.0, width=0.5, lie=0.55, seed=1):
        """Spikes scattered over an ellipsoid's surface (where `keep(local point)` says), leaning out and along
        `sweep`; `lie` is how flat to it they lie (0 straight out, 1 along `sweep`)."""
        rng = random.Random(seed)
        made = 0
        tries = 0
        while made < count and tries < count * 60:
            tries += 1
            n = Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1))).normalized()
            local = Vector((n.x * radii[0], n.y * radii[1], n.z * radii[2]))
            if keep and not keep(local):
                continue
            normal = pitch(Vector((n.x / radii[0], n.y / radii[1], n.z / radii[2])).normalized(), tilt)
            at = Vector(centre) + pitch(local, tilt)
            along = Vector(sweep)
            along = (along - normal * along.dot(normal))
            along = along.normalized() if along.length > 1e-4 else normal
            direction = (normal * (1.0 - lie) + along * lie).normalized()
            size = rng.uniform(length[0], length[1])
            self.spike(at - normal * size * 0.2, direction, size, size * width, rng.choice(mats))
            made += 1

    def feather(self, root, tip, width, mats, sag=0.0, thick=0.004, up=(0, 1, 0), rounded=False):
        """A feather: a long leaf, thin, from `root` to `tip`, lying across `up`. `mats` are the materials of its bands
        from root to tip (bars). `sag` bows it down along its length."""
        root, tip = Vector(root), Vector(tip)
        d = tip - root
        side = d.cross(Vector(up)).normalized()
        normal = side.cross(d).normalized()
        steps = [0.0, 0.18, 0.42, 0.66, 0.84, 0.95] if not rounded else [0.0, 0.2, 0.45, 0.7, 0.88, 0.97]
        profile = [0.45, 0.85, 1.0, 0.95, 0.72, 0.38] if not rounded else [0.5, 0.9, 1.0, 1.0, 0.85, 0.55]
        spine = [root + d * t + normal * (-sag * math.sin(math.pi * t)) for t in steps]
        left = [self._v(p + side * width * 0.5 * f) for p, f in zip(spine, profile)]
        right = [self._v(p - side * width * 0.5 * f) for p, f in zip(spine, profile)]
        top = [self._v(p + normal * thick) for p in spine]
        bottom = [self._v(p - normal * thick) for p in spine]
        end = self._v(root + d + normal * (-sag * 0.0))
        n = len(steps)
        for i in range(n - 1):
            m = self._index(mats[min(int(steps[i] * len(mats)), len(mats) - 1)])
            for face in ((left[i], left[i + 1], top[i + 1], top[i]), (top[i], top[i + 1], right[i + 1], right[i]),
                         (right[i], right[i + 1], bottom[i + 1], bottom[i]), (bottom[i], bottom[i + 1], left[i + 1], left[i])):
                self.bm.faces.new(face).material_index = m
        m = self._index(mats[-1])
        for a, b in ((left, top), (top, right), (right, bottom), (bottom, left)):
            self.bm.faces.new((a[-1], end, b[-1])).material_index = m
        m = self._index(mats[0])
        self.bm.faces.new((left[0], bottom[0], right[0], top[0])).material_index = m

    def done(self, smooth=True):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts[:], dist=0.00005)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces[:])
        for f in self.bm.faces:
            f.smooth = smooth
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for name in self.mats:
            mesh.materials.append(material(name))
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.collection.objects.link(obj)
        if self.parent is not None:
            obj.parent = self.parent.obj
            obj.location = to_blender(self.origin - self.parent.origin)
        else:
            obj.location = to_blender(self.origin)
        self.obj = obj
        return obj


def mirror(p, side):
    return Vector((p[0] * side, p[1], p[2]))


def wing(name, body, side, shoulder, arm, fore, hand, secondaries, primaries, covert, mats, flight_mats, rounded):
    """One wing, spread: three parts (shoulder > elbow > wrist). `arm`, `fore`, `hand` are lengths out along X;
    `secondaries` (count, length, width), `primaries` (count, shortest, longest, width, fingers spread)."""
    suffix = "_wing_l" if side > 0 else "_wing_r"
    s = Vector(shoulder)
    e = s + Vector((arm * side, 0.0, -arm * 0.06))
    w = e + Vector((fore * side, 0.0, fore * 0.12))
    made = []
    upper = Part(name + suffix, s, body)
    lower = Part(name + suffix + "_fore", e, upper)
    tip = Part(name + suffix + "_hand", w, lower)
    count, length, width = secondaries
    # The arm and forearm: a rounded leading edge, coverts over, secondaries trailing back; each part's feathers
    # reach a little past its joint so no gap opens as they fold
    for part, a, b, lead in ((upper, s, e, (0.03, 0.022)), (lower, e, w, (0.022, 0.015))):
        part.tube([a + Vector((-0.01 * side, 0, 0)), b + Vector((0.008 * side, 0, 0))], [lead[0], lead[1]], mats[0], 8, (1.0, 0.7))
        for k in range(count):
            t = (k + 0.5) / count
            root = a.lerp(b, t) + Vector((0, -0.004, -0.005))
            splay = 0.12 * side * (t - 0.3)
            part.feather(root, root + Vector((splay * length, -0.01, -length * random.uniform(0.95, 1.05))), width,
                         flight_mats, sag=0.012, rounded=rounded)
        for k in range(count + 1):
            t = k / count
            root = a.lerp(b, t) + Vector((0, 0.006, 0.006))
            part.feather(root, root + Vector((0.03 * side * (t - 0.5), 0.0, -length * covert)), width * 1.25,
                         mats, sag=0.006, rounded=True)
    # The hand: primaries fanned from the wrist out to the tip, the outer ones fingered
    count, shortest, longest, pwidth, spread = primaries
    tip.tube([w, w + Vector((hand * side, 0.0, -hand * 0.15))], [0.015, 0.008], mats[0], 8, (1.0, 0.7))
    for k in range(count):
        t = k / max(count - 1, 1)
        root = w + Vector((hand * side * t, 0.0, -0.01 - hand * 0.15 * t))
        angle = math.radians(-12 + spread * t)
        length = shortest + (longest - shortest) * math.sin(t * math.pi * 0.62)
        direction = Vector((math.sin(angle) * side, -0.03, -math.cos(angle)))
        # (each primary its own part, so the fold can lay them all back together)
        primary = Part(name + suffix + "_p%d" % k, root, tip)
        primary.feather(root, root + direction * length, pwidth * (1.0 - 0.25 * t), flight_mats, sag=0.015, rounded=rounded)
        made.append(primary)
        tip.feather(root + Vector((0, 0.006, 0.008)), root + Vector((0, 0.006, 0.008)) + direction * length * covert * 0.8,
                    pwidth * 1.2, mats, sag=0.006, rounded=True)
    return [upper, lower, tip] + made


def crow():
    random.seed(21)
    body = Part("crow_body")
    shade = ["crow", "crow", "crow", "crowdeep", "crowdeep", "crowsheen"]
    # The body, held nose up a little; a full breast
    body.blob((0, 0.23, -0.01), (0.078, 0.082, 0.15), "crow", 16, 10, tilt=0.38)
    body.blob((0, 0.265, 0.06), (0.07, 0.078, 0.07), "crow", 14, 9)
    body.tufts((0, 0.23, -0.01), (0.078, 0.082, 0.15), 70, shade, (0.025, 0.05), (0, -0.4, -1), tilt=0.38, lie=0.75, seed=3)
    body.tufts((0, 0.265, 0.06), (0.07, 0.078, 0.07), 26, shade, (0.02, 0.04), (0, -1, -0.3), lie=0.7, seed=4,
               keep=lambda p: p.z > -0.02)
    made = [body]
    # The head: a steep brow, the big arched bill, a shaggy throat, a scruff on the crown; eyes under a hooded lid
    head = Part("crow_head", (0, 0.32, 0.09), body)
    head.blob((0, 0.365, 0.13), (0.056, 0.056, 0.066), "crow", 14, 9)
    head.blob((0, 0.385, 0.16), (0.045, 0.04, 0.048), "crow", 12, 8)
    head.blob((0, 0.33, 0.115), (0.05, 0.055, 0.05), "crow", 12, 8)
    head.tufts((0, 0.365, 0.13), (0.056, 0.056, 0.066), 30, shade, (0.018, 0.034), (0, 0.2, -1), lie=0.8, seed=5,
               keep=lambda p: p.z < 0.035)
    # (the scruff on the crown: a few longer spikes swept back)
    for k in range(5):
        x = (k - 2) * 0.014
        head.spike((x, 0.405, 0.12 - abs(x) * 0.5), (x * 4, 0.6, -1), random.uniform(0.04, 0.06), 0.012, random.choice(shade))
    # (the shaggy throat hackles, down under the bill)
    for k in range(9):
        x = (k - 4) * 0.011
        head.spike((x, 0.325, 0.14 - abs(x) * 0.3), (x * 3, -1, 0.35), random.uniform(0.035, 0.055), 0.012, random.choice(shade))
    bill = [(0, 0.37, 0.178), (0, 0.376, 0.215), (0, 0.37, 0.25), (0, 0.355, 0.278), (0, 0.338, 0.29)]
    head.tube(bill, [0.024, 0.019, 0.013, 0.007, 0.002], "crowbill", 10, (0.72, 1.15))
    # (the lower mandible, a little below and shorter)
    head.tube([(0, 0.355, 0.178), (0, 0.352, 0.22), (0, 0.348, 0.255)], [0.017, 0.012, 0.003], "crowbill", 8, (0.7, 0.8))
    # (bristles over the nostrils at the bill's base)
    for x in (-0.012, 0.0, 0.012):
        head.spike((x, 0.385, 0.17), (x * 2, 0.15, 1), 0.035, 0.009, "crowdeep")
    for side in (1, -1):
        eye = Vector((side * 0.042, 0.378, 0.163))
        head.blob(eye, (0.016, 0.017, 0.012), "pupil", 10, 7)
        # (a glint of a brown iris rim)
        head.blob(eye + Vector((side * 0.003, 0.0, 0.004)), (0.013, 0.014, 0.008), "eyewhite", 8, 6)
        head.blob(eye + Vector((side * 0.0045, 0.0, 0.006)), (0.011, 0.012, 0.006), "pupil", 8, 6)
        # (the hooded lid over it, its inner corner lower: a sly look)
        head.cap(eye, 0.019, (side * 0.3, 1.0, -0.75), 1.45, "crow", 12, 5)
        head.spike(eye + Vector((side * 0.006, 0.018, -0.004)), (side * 0.6, 0.35, -1), 0.03, 0.01, "crowdeep")
    made.append(head)
    # A wedge of a tail
    tail = Part("crow_tail", (0, 0.2, -0.13), body)
    for k in range(7):
        a = (k - 3) * 0.09
        root = Vector((math.sin(a) * 0.02, 0.2 + abs(k - 3) * 0.002, -0.12))
        length = 0.16 - abs(k - 3) * 0.012
        tail.feather(root, root + Vector((math.sin(a) * length, -0.04, -math.cos(a) * length)), 0.04,
                     ["crowdeep"] if k % 2 else ["crow"], sag=-0.006, rounded=True)
    tail.tufts((0, 0.205, -0.12), (0.04, 0.03, 0.04), 10, shade, (0.025, 0.04), (0, -0.2, -1), lie=0.85, seed=8)
    made.append(tail)
    # Legs: a feathered thigh, a scaled shank, three toes ahead and one behind, with claws
    for side, suffix in ((1, "_leg_l"), (-1, "_leg_r")):
        hip = Vector((side * 0.035, 0.155, 0.0))
        leg = Part("crow" + suffix, hip, body)
        leg.blob(hip + Vector((side * 0.006, 0.0, 0.0)), (0.026, 0.034, 0.03), "crow", 10, 7)
        leg.tufts(hip + Vector((side * 0.006, 0.0, 0.0)), (0.026, 0.034, 0.03), 8, shade, (0.015, 0.025), (0, -1, -0.2),
                  lie=0.8, seed=11 + side)
        foot = Vector((side * 0.04, 0.012, 0.012))
        leg.tube([hip + Vector((0, -0.02, 0.0)), foot], [0.008, 0.006], "crowleg", 6)
        for a, toe in ((-0.45, 0.042), (0.0, 0.048), (0.45, 0.042), (math.pi, 0.032)):
            end = foot + Vector((math.sin(a) * toe, -0.008, math.cos(a) * toe))
            leg.tube([foot, end], [0.005, 0.004], "crowleg", 5)
            leg.tube([end, end + Vector((math.sin(a) * 0.008, -0.004, math.cos(a) * 0.008))], [0.003, 0.0008], "talon", 4)
        made.append(leg)
    for side in (1, -1):
        made += wing("crow", body, side, (side * 0.06, 0.29, 0.04), 0.11, 0.12, 0.07, (4, 0.16, 0.05),
                     (7, 0.17, 0.25, 0.042, 62), 0.45, ["crow", "crowsheen"], ["crowdeep"], False)
    return made


def owl():
    random.seed(33)
    body = Part("owl_body")
    back = ["owl", "owldark", "owldark", "owllight"]
    # A barrel of a body, the chest tawny and streaked dark, the back mottled
    body.blob((0, 0.25, -0.01), (0.135, 0.19, 0.12), "owl", 18, 12, tilt=0.12)
    body.blob((0, 0.24, 0.035), (0.12, 0.17, 0.09), "owlchest", 16, 11)
    body.blob((0, 0.13, 0.02), (0.11, 0.08, 0.09), "owlchest", 14, 9)
    body.tufts((0, 0.24, 0.035), (0.12, 0.17, 0.09), 60, ["owldark", "owldark", "owl"], (0.025, 0.045), (0, -1, 0),
               lie=0.92, width=0.32, seed=3, keep=lambda p: p.z > 0.02)
    body.tufts((0, 0.24, 0.035), (0.12, 0.17, 0.09), 30, ["owllight", "owlchest"], (0.02, 0.035), (0, -1, 0.2),
               lie=0.8, seed=4, keep=lambda p: p.z > 0.0)
    body.tufts((0, 0.25, -0.01), (0.135, 0.19, 0.12), 80, back, (0.025, 0.05), (0, -0.6, -1), tilt=0.12, lie=0.8,
               seed=5, keep=lambda p: p.z < 0.02)
    made = [body]
    # The head: broad and flat topped; a pale disc round each eye, rimmed dark; ear tufts; a little hooked beak sunk in
    # its feathers over a white bib
    head = Part("owl_head", (0, 0.41, 0.0), body)
    head.blob((0, 0.49, 0.0), (0.122, 0.1, 0.105), "owl", 16, 11)
    head.tufts((0, 0.49, 0.0), (0.122, 0.1, 0.105), 46, back, (0.02, 0.04), (0, 0.1, -1), lie=0.85, seed=6,
               keep=lambda p: p.z < 0.05)
    for side in (1, -1):
        disc = Vector((side * 0.046, 0.485, 0.07))
        head.blob(disc, (0.058, 0.068, 0.04), "owlface", 14, 9)
        # (the dark rim, the outer edge of the disc)
        for k in range(11):
            a = math.radians(-100 + 200 * k / 10)
            at = disc + Vector((side * math.cos(a) * 0.06, math.sin(a) * 0.068, -0.006))
            head.spike(at, (side * math.cos(a), math.sin(a), 0.35), random.uniform(0.018, 0.026), 0.01, "owlrim")
        # (fine pale feathers fanned out across the disc from the eye)
        for k in range(8):
            a = math.tau * k / 8 + 0.3
            at = disc + Vector((side * math.cos(a) * 0.03, math.sin(a) * 0.034, 0.03))
            head.spike(at, (side * math.cos(a), math.sin(a), 0.2), 0.024, 0.008, "owllight")
        eye = Vector((side * 0.046, 0.5, 0.098))
        head.blob(eye, (0.03, 0.03, 0.016), "iris", 14, 9)
        head.blob(eye + Vector((0, 0, 0.011)), (0.014, 0.015, 0.008), "pupil", 10, 7)
        # (a pale brow over each eye, sweeping up and out into the ear tuft)
        for k in range(4):
            t = k / 3
            at = Vector((side * (0.015 + 0.05 * t), 0.535 + 0.02 * t, 0.095 - 0.03 * t))
            head.spike(at, (side * 0.7, 0.8, 0.1), 0.03, 0.01, "owllight")
        # Ear tufts: a few long spikes, dark, a pale inner one
        root = Vector((side * 0.07, 0.575, 0.03))
        for k, (out, length, mat) in enumerate(((0.25, 0.1, "owldark"), (0.45, 0.085, "owl"), (0.05, 0.075, "owllight"),
                                                  (0.6, 0.06, "owldark"))):
            head.spike(root + Vector((side * 0.008 * k, 0.0, -0.01 * k)), (side * out, 1.0, -0.3), length, 0.018, mat)
    head.tube([(0, 0.488, 0.125), (0, 0.48, 0.145), (0, 0.462, 0.148), (0, 0.45, 0.14)], [0.012, 0.01, 0.006, 0.001],
              "owlbeak", 8, (0.75, 1.0))
    # (a soft white bib under the face: a pale patch with short tufts lying down over the chest)
    head.blob((0, 0.432, 0.088), (0.055, 0.03, 0.03), "owlbib", 12, 7)
    head.tufts((0, 0.432, 0.088), (0.055, 0.03, 0.03), 14, ["owlbib", "owllight"], (0.014, 0.022), (0, -1, 0.1), lie=0.9,
               seed=17, keep=lambda p: p.z > 0.0)
    made.append(head)
    # The lids: heavy, the inner corners lower (a fierce look); each its own part, turned down about X to blink
    for side, suffix in ((1, "_lid_l"), (-1, "_lid_r")):
        eye = Vector((side * 0.046, 0.5, 0.098))
        lid = Part("owl" + suffix, eye, head)
        rim = lid.cap(eye, 0.033, (side * 0.3, 1.0, -0.62), 1.8, "owlface", 14, 5)
        lid.tube([eye + Vector((side * 0.03, 0.012, 0.012)), eye + Vector((0, 0.019, 0.026)), eye + Vector((-side * 0.03, 0.006, 0.018))],
                 [0.005, 0.006, 0.005], "owlrim", 6)
        made.append(lid)
    # Tail: short and rounded, barred, hanging down behind
    tail = Part("owl_tail", (0, 0.12, -0.09), body)
    for k in range(7):
        a = (k - 3) * 0.13
        root = Vector((math.sin(a) * 0.03, 0.12, -0.09))
        direction = Vector((math.sin(a) * 0.5, -0.75, -0.75)).normalized()
        tail.feather(root, root + direction * (0.15 - abs(k - 3) * 0.008), 0.05, ["owl", "owldark", "owllight", "owldark", "owl"],
                     sag=-0.008, rounded=True)
    made.append(tail)
    # Legs: fluffy feathered legs down to big black talons
    for side, suffix in ((1, "_leg_l"), (-1, "_leg_r")):
        hip = Vector((side * 0.055, 0.1, 0.04))
        leg = Part("owl" + suffix, hip, body)
        leg.blob(hip + Vector((0, -0.04, 0.0)), (0.04, 0.06, 0.042), "owlchest", 12, 8)
        leg.tufts(hip + Vector((0, -0.04, 0.0)), (0.04, 0.06, 0.042), 16, ["owllight", "owlchest", "owl"], (0.015, 0.028),
                  (0, -1, 0.2), lie=0.85, seed=14 + side)
        foot = Vector((side * 0.06, 0.016, 0.07))
        for a in (-0.5, -0.15, 0.25, 2.6):
            end = foot + Vector((math.sin(a) * 0.035 * side, -0.004, math.cos(a) * 0.035))
            leg.tube([foot + Vector((0, 0.01, -0.02)), end], [0.012, 0.008], "owllight", 6)
            leg.tube([end, end + Vector((math.sin(a) * 0.016 * side, -0.004, math.cos(a) * 0.016)),
                      end + Vector((math.sin(a) * 0.02 * side, -0.016, math.cos(a) * 0.02))], [0.006, 0.004, 0.0008], "talon", 5)
        made.append(leg)
    for side in (1, -1):
        made += wing("owl", body, side, (side * 0.115, 0.36, -0.005), 0.13, 0.15, 0.09, (5, 0.23, 0.07),
                     (7, 0.24, 0.31, 0.06, 55), 0.42, ["owl", "owldark"], ["owl", "owldark", "owllight", "owldark", "owl"], True)
    return made


def build(parts):
    objects = [p.done() for p in parts]
    return objects


def export(name, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT, "models", name + ".glb"), export_format="GLB",
                              export_yup=True, use_selection=True, export_animations=False)
    print("BUILT %s tris=%d" % (name, sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objects)))


def look(folder, name, objects):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.render.resolution_x, scene.render.resolution_y = 600, 600
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.55, 0.62, 0.7)
    camera = scene.camera
    if camera is None:
        camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
        camera.data.type = "ORTHO"
        scene.collection.objects.link(camera)
        scene.camera = camera
    for other in bpy.data.objects:
        if other.type == "MESH":
            other.hide_render = other not in objects
    corners = [o.matrix_world @ Vector(c) for o in objects for c in o.bound_box]
    lo = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    hi = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    middle = (lo + hi) / 2
    size = max(hi - lo) * 1.1
    for view, direction in (("front", (0, -1, 0.1)), ("side", (1, 0, 0.1)), ("back", (0, 1, 0.1)), ("top", (0.01, 0, 1)),
                            ("quarter", (0.7, -0.7, 0.35))):
        offset = Vector(direction).normalized() * 10.0
        camera.data.ortho_scale = size
        camera.location = middle + offset
        camera.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(folder, "%s_%s.png" % (name, view))
        bpy.ops.render.render(write_still=True)


bpy.ops.wm.read_factory_settings(use_empty=True)
models = {"crow": build(crow()), "owl": build(owl())}
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "tools", "birds.blend"))
for name, objects in models.items():
    export(name, objects)
if PREVIEW_DIR:
    for name, objects in models.items():
        look(PREVIEW_DIR, name, objects)
