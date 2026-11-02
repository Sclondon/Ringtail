# Ringtail: notes for Claude

Read README.md first. Started 2026-11-01.

## The user's calls (their words where quoted, all 2026-11-01)

- A Banjo-Kazooie-inspired 3D platformer, a new Godot project. Original content, not a recreation.
- The hero is **a plain raccoon** (no costume). It began as a cowboy frog whose tongue was the lasso; the user
  switched to a raccoon and said not to use Frogulizer's frog.
- His signature is **tail moves**. The tail attack is a **spin** ("the tail attak shiould be a spin"; it was a whip):
  "snappier ... he needs to crouch and animate in to the spin and whip his tail", then "he spins way too fast and his
  tail doesnt even move" (now 0.65 s, eased, the tail swung back by how fast he turns). "The tail attack in the air
  should be like a double jump". The twirl: "the tail helicopter needs a lot of work- some effects, spin faster,
  and he should be hanging from it" (the tail is drawn out 1.9x, up his back, its end whirling over his head).
- On all fours: "needs all 4 animations for duckwalking and sprinting"; "a bounding leap"; "remove the sprint button he
  should just run on all 4s"; "he should only run on all 4s if you stick the joystick all the way" (raccoon.tscn:
  auto_sprint with sprint_delay 0.05, so a full push sprints; the rig bounds only while sprinting; no sprint action);
  "he needs an all 4s jumping animation"; "you should only be able to slide if you are fully running"
  (slide_min_speed 5.0, between run 4.4 and sprint 6.2).
- Look: "arms and legs a little too long, and his head should be bigger" (`reshape`); "tail rings ... spiky cones
  sorata like zizagzoon"; "he shouldnt have a white circly belly"; "wiry" meant **bushy**, not thin; whiskers; the
  user's two raccoon photos (warm grey-brown, sleek darker forearms and shins, fluffy body, tan and black rings);
  "his hair fur spikes should react to physcis (look at the kelp hair as example)" (Gloaming's LockHair);
  "his wiskers should aslo be phsysics spriungs".
- Behaviour: "he stis down on idle way too soon, should be after more than a minute" (sleep_after 75); "he needs to
  look at things, and should also sniff the air occasionally"; "you dont jump nearly high enough in water"
  (WaterLeap); "a mario 64 style long jump" (LongJump); "foot dust particles should be 3d cloud blobs" (CloudDust).
- Gamepad: "slide and duck should be x and attack should be b".
- World: "an alley way with several houses to scurry along, trash cans to knock over"; "the hemlock tower wires to
  walk across and bounce on like mario sunshine" (Wire, after Hemlock's Tower's); "banjo kazooie style textures".
- Enemies "in the same style as the hero" (the cats); "a fox, skunk, badger, rabbit in this style as well" (built;
  their role in the game not yet said).
- **Desktop first**. **N64 retro filter**, then "the filters are too strong" (about 520 lines, 6-bit colour, dither
  0.25, corners snapped to 480 rows). First slice: movement plus one small world.
- "No need for a halloween touch its not halloween anymore."

## Claude's picks (placeholders until the user says otherwise)

- The name "Ringtail"; World 1's layout; "Crumbs" and "Bottlecaps"; the five Bottlecap challenges; three hearts.
- The twirl on jump held; the cats' ginger tabby; the animals' looks and proportions; textures' colours.
- Per-pixel lighting in the world shader (vertex lighting with shadows drew a checkerboard).

## How it is built

- The raccoon is a figure on the GameCommon boy's skeleton plus `tail_0..5`. `RaccoonRig._pose_extra` lays the
  all-fours pose over the boy's (rump up, shoulders down; a lateral walk ducking, a bound sprinting; hands with
  `_solve_arm`/`_lay_hand`, feet with `_solve_leg` in the hips' space). The tail is a spring chain drawn to a shape
  per state; joints carry a stretch along themselves for the rotor (each joint takes off its parent's stretch).
- Fur physics: the builders tag every spike's points in the "Metres" UV layer (glTF UV2) as (region, -flex); other
  points' UV2 is never negative. `_make_fur` gives every surface a copy of `Toon.SHADER` with a vertex stage that
  moves tagged points by their region's lag x flex²; `_spring_fur` springs one lag per region (FUR_REGIONS order =
  build_raccoon.py REGION) against that part's acceleration.
- `key_poses`, `cap_hand` and `dusty` are off on his rig.
- The world model's markers are the one place positions live (`tools/build_world1.py`). `World` reads them; ladder
  heights are in the marker name (`ladder_<name>_<cm>`), the pool's size in `pool_size`'s position.
- Gotchas: in the Blender builders merge vertices **before** `recalc_face_normals`; the world's trimesh shapes are
  `backface_collision`. In perl replacements `@export` is an array: escape it. The Player takes no jump while
  sliding and back-tucks out of a duck, so LongJump catches the jump itself (priority -5, before the Player).
  A Wire catches anything crossing its height between frames, so it ignores a fall of over 1 m in one frame (a teleport).

## State

- Done: the raccoon and his moves, the alley World 1 (all five Bottlecaps placed; routes not yet re-walked in the
  alley), HUD, smoke test passing (20 checks).
- Not done: re-walking the alley's routes (chimney, billboard glide, porch crawl) headless; the animals' role; phone
  layout; sounds; a title; a web build; a GitHub repo; an arcade cart. The trampoline bed doesn't sag.
