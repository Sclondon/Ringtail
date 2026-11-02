"""The animals' triangle budget (the user, 2026-11-02: "we need to make sure all the animals are decently low poly
twilight princess esque level of detail", "to improve performance"). Smooth, readable forms like Twilight Princess's
creatures: the fused body parts (the voxel-remeshed, decimated ones) share a budget by the animal's size, and every
tube, ellipsoid and strand the builders make has fewer sides. Not for the raccoon (he and the villagers keep his full
build). The builders call `thrifty(parts, animal)` on their parts list before `kit.export`, and `sides(animal)` once.

    TRIANGLES[animal] = (the fused parts' budget together, how many of a tube's sides are kept)
"""

import os

import build_character as kit

TRIANGLES = {
    # big: dogs (their own builder), cats, the fox, badger, beaver, otter, porcupine, opossum, skunk
    "cat": (2200, 0.55), "fox": (2200, 0.55), "badger": (2200, 0.55), "skunk": (2000, 0.55),
    "beaver": (1800, 0.55), "otter": (1700, 0.55), "porcupine": (1800, 0.5), "opossum": (1700, 0.55),
    # middling
    "rabbit": (1400, 0.5), "marten": (1400, 0.5), "weasel": (1200, 0.5), "ringtail": (1400, 0.5),
    "squirrel": (1300, 0.5), "turtle": (1200, 0.5), "prairie_dog": (1300, 0.5), "gopher": (1300, 0.5),
    "rat": (1300, 0.5), "frog": (1300, 0.5),
    # small
    "mouse": (1100, 0.5), "chipmunk": (1100, 0.5),
}
# (no part of a fused budget below this, so a hand or an ear stays round)
LEAST = 60
# (no tube with fewer sides than this; a thin strand, a whisker or a claw, down to three)
FEWEST = 5

_original = {}
# (LOWPOLY=off in the environment builds the full ones, to compare)
OFF = os.environ.get("LOWPOLY") == "off"


def thrifty(parts, animal):
    """`parts` with their fused budgets shared out of the animal's: each keeps its share of the whole."""
    if animal not in TRIANGLES or OFF:
        return parts
    whole = sum(fuse[2] for _, _, _, fuse in parts if fuse)
    scale = TRIANGLES[animal][0] / max(whole, 1)
    return [(part, material, shapes, (fuse[0], fuse[1], max(LEAST, int(fuse[2] * scale))) if fuse else None)
            for part, material, shapes, fuse in parts]


def sides(animal):
    """Every tube from here on with that share of its sides (the strands' and ellipsoids' too, which are tubes)."""
    keep = 1.0 if OFF else TRIANGLES.get(animal, (0, 1.0))[1]
    if not _original:
        _original["tube"] = kit.Builder.tube
    tube = _original["tube"]

    def fewer(self, rings, segments=16, floor=None):
        if not kit.LOW and keep < 1.0:
            segments = max(3 if segments <= 8 else FEWEST, round(segments * keep))
            # (long tubes keep every other ring in between: a smooth body needs few)
            if len(rings) > 9:
                rings = rings[:1] + rings[1:-1][::2] + rings[-1:]
        return tube(self, rings, segments, floor)

    kit.Builder.tube = fewer
