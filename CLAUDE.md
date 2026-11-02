# Ringtail: notes for Claude

Read README.md first. Started 2026-11-01.

## The user's calls (their words where quoted)

- A Banjo-Kazooie-inspired 3D platformer, a new Godot project. Original content, not a recreation.
- The hero is **a plain raccoon** (no costume). It began as a cowboy frog whose tongue was the lasso; the user
  switched to a raccoon and said not to use Frogulizer's frog.
- His signature is **tail moves**. The tail attack is a **spin**: "the tail attak shiould be a spin" (2026-11-01; it was a
  whip on the ground before).
- "mostly upright but he needs all 4 animations for duckwalking and sprinting".
- **Desktop first**. **N64 retro filter** look. Then "the filters are too strong" (2026-11-01): softened to about 520
  lines, 6-bit colour, dither 0.25, world corners snapped to 480 rows (`scripts/n64_filter.gd`, `shaders/world.gdshader`). First slice: movement plus one small world.
- "No need for a halloween touch its not halloween anymore."

## Claude's picks (placeholders until the user says otherwise)

- The name "Ringtail", "World 1" as a back yard and alley at dusk, "Crumbs" (notes) and "Bottlecaps" (jiggies),
  the yard cats as the enemy, the five Bottlecap challenges, three hearts.
- The twirl (jump held while falling), and the lift the spin gives in the air (once a jump).
- Per-pixel lighting in the world shader (vertex lighting with shadows drew a checkerboard on the lawn).
- No partner character: none was asked for.

## How it is built

- The raccoon is a figure on the GameCommon boy's skeleton plus `tail_0..5`. `RaccoonRig._pose_extra` lays the
  all-fours pose over the boy's: rump up and shoulders down (his arms are short), a lateral walk ducking and a
  gallop sprinting, hands planted with `_solve_arm`/`_lay_hand`, feet with `_solve_leg` in the hips' space.
  The tail is a spring chain of points drawn to a shape per state (`TAIL_STAND`/`RUN`/`QUAD`, angles below
  straight back in the hips' space), with the twirl held to a cone leaning up and back so it misses his head.
- `key_poses` and `cap_hand` are off on his rig (the boy's key poses and cap-holding hand are not his).
- The world model's markers are the one place positions live (`tools/build_world1.py`). `World` reads them.
- Gotcha: in the Blender builders, merge vertices **before** `recalc_face_normals` (faces made one by one have
  no outside of their own: the lawn came out with random facing and cats fell through it). The world's
  trimesh shapes are also set to `backface_collision`.
- Route checks done headless (2026-11-01): crawl under the porch to the hidden cap; porch roof, up the trellis,
  over the ridge; catch the chimney top and climb (jump again while hanging); off the crossarm, twirl to the
  billboard. The back wall is 8 m so he can't walk off the back of the roof.

## State

- Done: the raccoon, his moves, World 1 with all five Bottlecaps reachable, HUD, smoke test passing.
- Not done: phone layout (TouchControls are there but unchecked at phone sizes), sounds, a title screen, a web
  build, a GitHub repo, an arcade cart. The trampoline bed doesn't sag (`Trampoline.set_bed` isn't wired).
