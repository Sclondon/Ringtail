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
- 2026-11-02, gaits: "his all 4s run still needs a lot of work, download reference images ... his back legs seem so
  mirrored and stiff" gave a gallop after Muybridge's plate 744 (raccoon walking into a gallop): low and long, hind
  feet a beat apart, hocks flexing, back arched gathering and flat reaching. Then "I liked when the all 4s run was
  more of basically a jump, the scurry can use this new animation": the full-stick sprint is the bound again
  (BOUND_FEET), the gallop is Scurry's (SCURRY_FEET; `_scurry_gait`). "Instead of taking tiny steps when moving slow
  he should sneak" / "and slowly step": under 0.4 stick he creeps at 0.55 m/s (Player.sneak_speed, is_sneaking),
  upright on tiptoe, hunched, paws up limp (`_pose_sneak`; upright rather than low was Claude's pick, the duck being
  his low creep). "His regular walking stride needs to be bigger steps" / "but slower": WALK_STRIDE 1.35 on the
  boy's strides, walk_speed 1.2. tests/gait_check.gd measures foot slip per gait (all under 2 cm when checked);
  tests/pose_shots.gd films bound, scurry_film, walk_film, sneak_film (it re-presses its input every step and lets go
  of stray input: a gamepad in use elsewhere reaches its window).
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

## 2026-11-02: the town after Pom Poko and Whisper of the Heart

- The user: "Why is there a wall around the town? the town should be inspired by pom poko and whisper of the heart,
  please look up art of that to reference" (references: Studio Ghibli's official stills, ghibli.jp/gallery
  mimi###.jpg and tanuki###.jpg; kept out of the repo). Then "you should spawn in the center of the grove and there
  shouldnt be enemies there", "why is the sky gray", "the camera should be zoomed in more" (FollowCamera distance
  5.5 -> 4.0).
- tools/build_town.py: no wall. Lots on terraces above the road held up by concrete-block retaining walls (texture
  blockwall), concrete steps with handrails up from the pavement; two-storey plaster houses under tiled hip roofs
  (tiles) with a second row behind, two danchi blocks, a bath house whose chimney is `climb_chimney` (the "Up the
  chimney" Bottlecap is on top: scurry up it), two shops with vending machines, the red antique shop with a gambrel
  roof and balcony on a paved plaza; concrete poles with transformers and power lines; in the grove a shrine, a torii
  where the path comes up, stone lanterns, a thatched hut, pampas grass. Past the back of the lots a rail, then the
  land falls away to the rest of the town in the valley (houses, danchi rows, cedars as cones) and low hills: all
  `nocol_`. **`hidden_bound`** (World hides `hidden_` meshes, keeps their collision) is the unseen wall at the brink.
  If it ever shows, it reads as a huge wall round the map (it did once, built before World hid it).
- "...and remember realistic big houses and apartment buildings" (the user): houses about 11 x 9 m, eaves at 6 m,
  framed windows, door canopies, balconies with laundry poles, block garden walls with gate pillars (1.1 m: a jump
  gets him on top); danchi of five 2.8 m storeys, a balcony and divider to every flat, laundry rails, two stairwells
  behind rising to rooftop houses, a tank on legs. The raccoon is about 0.6 m tall.
- Spawn and `check_top` are in the grove beside `grove_heart`; `haunt_<n>` mark spots for wandering raccoons.
  Hazards.safe(): nothing chases, stalks or dives within Hazards.HAVEN_RADIUS (21 m) of grove_heart; no people walk
  up the hill now; the hawk circles over the north-west houses, the fox's den is in a back garden.
- Claude's picks: which building stands on which lot, lot heights, summer daylight (blue sky, pale warm horizon,
  fog matched to it), every colour. Unverified: the five Bottlecap routes re-walked in this layout (the billboard
  glide from the great tree, the race).
- Check it with `tests/town_shots.gd -- --out=<dir>` (start, shrine, street, steps, plaza, bath house, over the rail,
  out to the edge from the grove and the road).

## 2026-11-02: the crow and the owl

- The user: "we need to work on a nice owl and crow model as well", then "the bird wings need joints not just simple
  flaps, make an accurate bird wing flap with reference to the species — like look up images".
- tools/build_birds.py (Blender) writes models/crow.glb (a large-billed crow: big arched bill, steep brow, shaggy
  throat, wedge tail, fingered primaries) and models/owl.glb (an eagle-owl: ear tufts, pale facial disc rimmed dark,
  orange eyes under heavy lids, streaked chest, barred wings and tail, feathered legs, black talons), in the
  raccoon's style (smooth forms, spiky tufts). References (Wikimedia Commons, kept out of the repo): a large-billed
  crow, a pied crow flight composite, crows and a raven in flight, Muybridge's Animal Locomotion plate 762, eagle-owl
  and great horned owl photos, eagle-owls flying.
- Parts are a tree of joints, each with no turn at rest, the wings built spread: body > head (> the owl's lids),
  tail, legs; shoulder > `_fore` (elbow) > `_hand` (wrist) > `_p0.._p6` (each primary). BirdBody (scripts/bird_body.gd)
  poses them: `fold`, `flap`, `flap_rate`, `tuck`, `flare` (landing), `look_at_point`, `peck`, `blink`.
  - Folding is a Z: the arm rolled (trailing edge down, tilted out over the body) and swung back, the forearm hinged
    back over it and the hand out over that, both about the wing's chord (Z), so the feathers still trail; each
    primary laid back along the body. Folding in the wing's own plane (about Y) turned the forearm's feathers up
    over the back.
  - The beat (CROW_STROKE, OWL_STROKE): downstroke straight and bowed down, leading edge down; upstroke elbow and
    wrist flexed, hand swept back, primaries fanned and twisted apart. Crow: rowing, ~2.7 beats a second. Owl: deep
    slow strokes up into a high V, broad wing barely flexed, long flat glides. The body leans level in flight.
- The crows (HazardCrows / HazardBird kind CROW) are on BirdBody: folded on the ground, eyeing him, pecking, a
  flick of the wings on each hop; beating in flight, gliding in to land, half folded diving. The hawk is still
  build_hazards.py's plain model.
- HazardOwl (Claude's picks, placeholders: its role, its numbers): sits on a pole top (or `owl_<n>` markers), head
  following him; near him on the ground outside the grove it stares (no blinking), swoops silently, talons forward,
  beats back and glides in to its perch. `HazardOwl.place(world, markers, player)` goes after Hazards.place.
- Checks: `tests/bird_shots.gd -- --out=<dir>` (each pose from four sides, close up, beat filmstrips side/front/
  above, glide, landing), `tests/bird_clip.gd` (folded wing points no more than 4 mm into the body; each wing's
  shoulder excepted), `tests/owl_test.gd` (owl and crows on a flat yard), `tests/bird_world_shots.gd` (in the town).
- Trees (the user, 2026-11-02: "the trees need bark textures and the branches need work, especially with how the
  leaves connect. The trunks should be bigger, some much bigger and taller trees as well"): GameCommon tree, new
  `bark_style` (painted bark tile, oak/maple/camphor) and `joined` (collars, pointed ends, no bare twigs, leaf clumps
  drawn along their twigs); "Climbing oak"/"Climbing maple" trunks about 1.5x thicker; a new "Great camphor" (my pick
  of species, after the shrine trees in the Ghibli stills). A tree marker of 150% or more grows a Great camphor at its
  own size (world.gd), so its limbs stay a jump apart. tests/tree_climb.gd climbs all three; tree_shots.gd shoots them.
- Cats, pause and the model editor (the user, 2026-11-02: "the cats need color variations, and longer skinnier
  bodies. They should also have different fur types. Give me a pause screen and model editor where I can switch out
  the fur with different texture types like the hair editor in gloaming"; then, on his fur, "I like his tail fur, can
  we make his body and arms work like that too? — or an option for that in the editor"):
  - Cats: tools/build_cat.py lays `cat_reshape` over his (body 1.38x longer from hips to neck, 0.76x as wide and
    deep, thinner arms and legs) and bakes markings into the vertex colours (R grit, G where white goes, B patches, A
    tabby stripe). Fur types `-- fur=all` build cat.glb (spiky), cat_sleek, cat_shaggy, cat_soft. Each town cat
    takes FurLook.CAT_LOOKS[its index] (Claude's picks: ginger tabby, black, grey long-hair tabby, tuxedo, calico,
    cream tabby & white, white with patches) unless the editor changed it.
  - His fur types (`tools/build_raccoon.py -- fur=<type>`, models/raccoon_fur_<type>.glb; FUR_TYPES multiply tuft
    length, width, count, ruff flare and droop, all 1 for the plain build): spiky (raccoon.glb, still the default),
    soft, shaggy, sleek, wiry, and cones (body, upper arms and thighs in banded tail cones). FurLook.swap puts the
    type's mesh on (RaccoonRig.restyle), FurLook.patterned/paint draw the marks (plain, frosted tips, dark tips,
    streaked, stippled) and a cat's markings (solid, tabby, tuxedo, calico, patches, tabby & white) in the fur shader.
  - Pause: the HUD's pause button (top right, always shown), Esc, P or Start: Go on, or Fur & looks (FurEditor, over
    the paused game, after Gloaming's CharacterEditor: turntable, drag/arrows to turn, Face/Whole, a panel of fur
    type, marks, markings and colour sliders; Own look; Done). Looks are kept in user://looks.json (FurLook.FILE) and
    worn from the start. Alone: `godot --path . res://scenes/fur_editor.tscn`.
  - Checks: `tests/look_shots.gd -- --out=<dir> [cats] [furs] [menus]` (window; menus at 1280x720 and 390x844).
- Then "the tree trunks jiggle like jelly because the leaf shader I think" and "you need to work on the ledges on the
  branches, it interrupts your climbing, you get near a branch incorrectly": a climbable or joined tree's wood has no
  sway at all (TreeGen._rigid; its collision never moves), its leaves a third as much. Scurry: no ledge catches while
  held in the air; his collider held to 0.62 m on all fours (Player.height_cap; it was the boy's 1.25 m, which jammed
  him under limbs); a limb over his head he goes round (the other way if stuck, and if both are blocked he steps up
  onto it); a trunk is not let go of while a limb pushes him out. tests/tree_scurry.gd climbs a trunk past its limbs
  (three presets, two seeds, four sides: 23 of 24 pass; oak seed 4 from one side drops off near the trunk's top).
