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

## Later on 2026-11-01 (the user's calls, in their words where quoted)

- Fur: "shouldnt all be the same length and not in perfect rings"; tail "a thicker and a little longer", "not as
  different a shade"; "gritty gradients on his body" (baked into a vertex colour layer: build_raccoon.py
  paint_grit; the fur shader multiplies by COLOR when its alpha is 1); "small fur on his head"; "more accurate
  animal legs like Fantastic Mr Fox" (a raised hock behind the ankle, a long paw: HOCK); "fingers need to be
  longer"; whiskers "longer and thinner", "not all the same length"; "his eyes need to be animated and he needs a
  few expressions" (lids, brows, ears on bones of their own; RaccoonRig.FACES, express(), blinks).
- Spin: "the tail should be the focus and it doesnt even spin at the rate he does", "it needs to become stiff when
  spinning" (held straight out, stretched 1.35, a swoosh of puffs). Stick-twirl spin faster (spin_rate 28) and
  "if you jump in this mode you should do a spin jump like in mario sunshine" (SpinJump).
- Twirl: "spin from the base of his tail", no "circular sprite", "pinned by his butt" (the whole tail whirls flat
  from its root; he hangs by his rump below it).
- Run: "higher quality a little bouncier and more raccoonie" (lope: rump thrown high, humped back, waddle, hind feet
  reaching to the fore paws). Dust "exactly on every step ... a few puffs" (RaccoonRig.stepped; CloudDust).
- Controls: Scurry on the left trigger (and Shift; an on-screen paw button): all fours, climbs anything climbable
  (poles: meshes named climb_; the grove's trees). Duck is on all fours too ("why is duck not on all 4s?": I had read the Scurry message as taking all fours off duck). "y remains duck" (duck on X and Y: X was the user's earlier
  call; ask if X should change). Superhero landing "only from tall height" (landing_speeds 15/17/19/21).
- Hanging from ledges: "swing his legs when hanging and shimmying" (_pose_hang_swing).
- World: "a little grove on a hill in the center of town" with "birds and other predators to avoid, and people as
  well and cars" (tools/build_town.py writes models/world1.glb; Hazards.place; markers road_/walk_/hawk_/crows_/
  den_/tree_); "climbable trees with big branches to stand on" (GameCommon tree: TreeGen "Climbing oak"/"Climbing
  maple", tree.body()); wires "identical to Warren" (GameCommon tightrope); pickups as food (apples, acorns, pizza,
  rubbish); "a squad of raccoons that boid around you" (Squad); "clouds like daughter of the wind" (GameCommon
  puff-clouds); "the world vibrates" (vertex snap off; POSITION must still be written: shaders/world.gdshader).
- Built by forked agents this day: cats (build_cat.py, CatRig), fox/skunk/badger/rabbit (build_critters.py,
  CritterRig: built, role not decided), hazards, food, squad, tightrope, trees, clouds. Their reports are in the
  commit messages.

## 2026-11-02: the other raccoons (the user's calls, in their words)

- "There should be other raccons in the center of the grove to talk to", "kits and adults", "And there should be
  other raccons just running around the map doing stuff": `Villagers.place` (scripts/villagers.gd, villager.gd).
  Three grown-ups and three kits at `grove_heart` (fallback: just south of the great tree), the kits playing tag;
  three grown-ups going round `haunt_<n>` (fallback: the ring road's pavements), one with a kit at heel. Kits are
  RaccoonRig at 0.5 with the head and spine bones' rest made bigger (Villagers._kit_shape).
- "The talking should work like in gloaming not like this": TalkBox is Gloaming's Story talk box ported ("Talk to
  <name>" at the bottom; a Breath of the Wild pill with the name over its corner, typed out; the ▶ goes on; he stands
  still). Talk is T or RB on a pad (Y is duck here); in the box T, RB, A, Space or Enter go on.
- "the kits should not teleport to you, and if they die they should just rag doll and stop moving": villagers too
  (Villager.die: a car, a fall over SquadRaccoon.DEADLY_FALL, off the world).
- Claude's placeholders: every villager's name and line (hello-level chatter), their tints and sizes.
