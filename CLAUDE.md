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
    length, width, count, ruff flare and droop, all 1 for the plain build): rings (raccoon.glb, the default: below),
    spiky (the shaggy fur that was his default), soft, shaggy, sleek, wiry, and cones (body, upper arms and thighs in banded tail cones). FurLook.swap puts the
    type's mesh on (RaccoonRig.restyle), FurLook.patterned/paint draw the marks (plain, frosted tips, dark tips,
    streaked, stippled) and a cat's markings (solid, tabby, tuxedo, calico, patches, tabby & white) in the fur shader.
  - Pause: the HUD's pause button (top right, always shown), Esc, P or Start: Go on, or Fur & looks (FurEditor, over
    the paused game, after Gloaming's CharacterEditor: turntable, drag/arrows to turn, Face/Whole, a panel of fur
    type, marks, markings and colour sliders; Own look; Done). Looks are kept in user://looks.json (FurLook.FILE) and
    worn from the start. Alone: `godot --path . res://scenes/fur_editor.tscn`.
  - Then "I should be able to control the angle of the fur and how dense, and the ring mane as well — and why aren't
    there the different textures from Gloaming?", "and the fur length", "I should be able to control tail length and
    thickness as well". Live, no rebuild: tag_spikes bakes each spike point's offset from its root (UV x, y and the
    colour's green, his grit now in red only), a rank at the tip (blue; above the density it folds away), which side
    of the spike a root point is (blue, for the textures; a cat's in UV x) and its group (UV2.x tenths: body, mane,
    crown, tail, whiskers). The fur shader (FurLook._SHAPED) re-lays body and crown spikes by look "body" [length,
    angle, density] and mane ones by "mane" [length, angle, count, width], each offset turned with its region's bone
    (FurLook.shape, per frame, only while shaped); "angle" tips them towards or away from the way the region's fur
    lies (FurLook.REGION_AXES). Gloaming's hair textures (solid, straight, wavy, curly, soft, thick: its strands(),
    ported as FurLook._STRANDED) are the look's "texture". The tail: RaccoonRig.tail_length (on the spring chain's
    segment lengths and the joints' stretch) and tail_thickness (the joints scaled across), from look "tail".
  - Checks: `tests/look_shots.gd -- --out=<dir> [cats] [furs] [shapes] [eyes] [menus]` (window; menus at 1280x720 and 390x844).
- Then "the tree trunks jiggle like jelly because the leaf shader I think" and "you need to work on the ledges on the
  branches, it interrupts your climbing, you get near a branch incorrectly": a climbable or joined tree's wood has no
  sway at all (TreeGen._rigid; its collision never moves), its leaves a third as much. Scurry: no ledge catches while
  held in the air; his collider held to 0.62 m on all fours (Player.height_cap; it was the boy's 1.25 m, which jammed
  him under limbs); a limb over his head he goes round (the other way if stuck, and if both are blocked he steps up
  onto it); a trunk is not let go of while a limb pushes him out. tests/tree_scurry.gd climbs a trunk past its limbs
  (three presets, two seeds, four sides: 23 of 24 pass; oak seed 4 from one side drops off near the trunk's top).
- Cats' eyes (the user, 2026-11-02: "the cat eyes need work they look creepy"): build_cat.py gives them big round
  eyes set into the face (most of each inside the head), the whole eye its iris colour in a thin dark rim, a soft
  upright oval pupil (no slit), a white glint, and upper lids of fur on his lid bones; CatRig.LID_REST lets them rest
  a little lowered (0.6 rad past his), so they blink with his rig and do not stare. `look_shots.gd ... eyes` films
  each cat's head front, quarter and side.

## Dogs and hiding (2026-11-02)

- The user: "there should be dogs as well (we already have the assets) and tall grass to hide in in spots as well".
- Then "the dog needs to look less hellish" and "should be like a shiba inu and beagle and blood hound and basset
  hound and wiener dog": the dogs are GameCommon's `godot/dog` (installed under `creatures/dog/`: its moves and rig)
  on Ringtail's own models, `tools/build_yard_dog.py` (Blender; Warren's tools/build_dog.py imported as a library,
  same bones; writes models/yard_dog_<breed>.glb and _lo, .blends in tools/): a full healthy body (no ribs, spine,
  hip bones, scars or crest), big dark eyes, small upper teeth only, each breed's build, ears and tail, and its coat
  colours painted in the vertex colours (sRGB as given: the glTF export makes float colours linear itself; converting
  first came out dark and over-red). `YardDog`/`YardDogRig` (scripts/yard_dog*.gd) draw the coat with Toon by those
  colours and the eyes and mouth with the component's parts shader (no eyeshine). Glad and wagging at rest
  (`friendly`), snarling only chasing. The breeds' looks, sizes (about 1.3x the model, bigger than him) and chase
  speeds (basset 3.6 to shiba 5.4 m/s) are Claude's picks (`HazardDog.BREEDS`). Each lives at a `dog_<n>` marker (else the haunts
  furthest from the grove): potters, sits, sleeps; seeing him it barks, gallops after him and springs (a bite
  hurts once a spring); gives up after 7 s, past 16 m from its yard, when he goes up out of reach, or when it loses
  him, then casts about nose down and trots home. His tail spin sends it yelping home. It is in `hazards`, so the
  band and the villagers run from it.
- Hiding: `Hazards.unseen(target)` is the one check every hunter asks (dogs, cats, fox, hawk, crows, owl, people):
  in the grove (`safe`) or `Hazards.hidden` = his feet down inside a tall-grass patch (`TownGrass.hidden`, main's
  `tallgrass_<n>` markers) and not bounding flat out (Claude's pick: standing, walking, ducking or scurrying there
  all hide him; sprinting through it does not).
- Tests: `tests/dog_test.gd` (a dog sees, chases and bites him; hidden, it loses him and does not find him again; a
  cat by him hidden does not stalk), `tests/dog_shots.gd -- --out=<dir>` (the breeds beside him from four sides, each
  face close, one snarling, a gallop). Rebuild: `blender -b --factory-startup --python tools/build_yard_dog.py [-- <dir> [breed]]`.
- More of the model editor (the user, 2026-11-02): "why is there not any fur shape options beside triangle" (Shape:
  triangle, teardrop, ribbon, wavy, curl, blunt, forked; each but the triangle a build of its own, `build_raccoon.py
  -- shape=<shape>` writes models/raccoon_shape_<shape>.glb at the plain fur type: every tuft a lock of rings along a
  centre line to the shape's profile, and the ruffs rings of locks; a shape and a fur type other than spiky do not
  combine, picking one sets the other back); "I should be able to control the width and size of each fur blade, and
  the density on different body parts" (Fur shape part picker: All (length, angle, density), Back, Chest, Arms,
  Legs, Crown (size, width, density each: look "parts", FurLook.PARTS by region), Mane (count, length, width,
  angle)); "the width changed the fur in the wrong dimension on the mane" (the mane's tufts lie flat round its ring:
  head_fur passes the ring's tangent as each tuft's flat side); "the tail length and thickness do not work correctly
  — both change both aspects and the tail angle" (a skeleton keeps a bone's scale only along its own axes, so the
  stretch along the tail and the fattening across it came out skewed: now Length is one uniform scale on tail_0
  and the spring chain's lengths, and Thickness is the fur shader's, every tail point (its cones and its skin, tagged
  from the tail's line in tag_spikes and paint_grit) pushed out by tail_girth = thickness / length;
  tests/tail_check.gd: Length 1.5 gives 1.50x, the tail's way within 1 degree, Thickness moves no bone; the cats get
  no Thickness: their colours are their markings); "also they clip into the body a lot" (on every raccoon, `kept`:
  each blade's tip held at least 15% of its length out from the surface at its root, out from the limb's line or
  the head's middle, FurLook.shape sending each region's bone place and limb way per frame; laid back the Angle stops
  short of flat (0.95); the elbows' and knees' fur springs half as far). Shots: `look_shots.gd ... spikes parts clip
  mane` (single figures front/side/quarter).
- Then "the climbable trees are too sparse with leaves": fuller crowns (more crown branches and twigs, leafy sprays
  from half way along each limb, many more clumps; a narrower clear space over the walks). Oak about 33k triangles,
  maple 28k, great camphor 52k. Their sprays draw on a generator of their own, so leaf settings never move the limbs;
  the maple's limbs are turned 1.0 rad apart (0.23 m thick) so all seven seeds climb. A joined tree's leaves clear a
  tunnel from the camera to the middle of the view (1.3 m round, 4.5 m deep), so up in a crown he is seen.

## 2026-11-02: World 1 is one hill (the user's calls, in their words)

- "the road shouldnt just be a ring it should be a winding road down a hill. The level should be this whole hill";
  "it's the hill grove at the top and ringed area". tools/build_town.py: the grove and the ring of lots stay on top
  (level out to HILL_EDGE 57 m); the street leaves the ring through the lot that was the bath house's (LOTS "road";
  the bath house moved to lot 0) and switchbacks down the hill's south face (four runs LEGS across the hill, hairpins
  of BEND 13 m, an even grade to FOOT_Y -34 m) to a station square at the foot: a turning circle, the station, a
  platform and a train, two shops (the station is Claude's pick). The road's level shelf (BENCH) is cut into or built
  up from the hill, block retaining walls at its edges; long stairways (STAIRS) straight down between the bends; houses
  on block plinths between the runs (steps up their faces), two blocks of flats near the foot; poles and wires on
  the downhill side; drain grates at the kerbs. The hill's ground is hill_grid() (2 m squares; solid down the
  street's face, nocol_ elsewhere) joined to the hilltop's (ground(), by 2 m square: each square belongs to one).
  hidden_bound runs round the hilltop's brink and down round the street's face (CORRIDOR 48 m, BOTTOM 193 m).
  Cars drive road_1 down and back up round the square; people walk walk_2. World.KILL_Y -55 m (he, the band and the
  town's raccoons were dying at -15/-20 m).
- "please dont make new reeds check the ones we already have": no modelled reeds; `reeds_<n>` markers (scale.x the
  patch radius) where World grows Warren's reeds. "tall grass to hide in in spots": `tallgrass_<n>` markers; dogs'
  yards `dog_<n>` (the DOGS work places the dogs).
- "there needs to be drains and gutter pipes to scurry up", then "the gutters dont look like gutters, and should be
  up against the side of the buildings, and need to be easier to climb": half-round zinc gutters round every hipped
  roof; downpipes flush on the side walls (clear of crates and roof strips; the hillside houses' by their fronts,
  their backs being in the hill), brackets every metre, a swan neck to the gutter, a shoe over a grate. He climbs an
  unseen column round each (`climb_pipes_<building>_hidden`: World hides meshes named `_hidden` but keeps them solid
  and climbable) that leans out past the eaves at the top: a straight one left him stuck under the eaves.
  tests/pipe_climb.gd climbs six buildings' pipes from three angles each (all 18 pass).
- "the spawning area is too small and cramped full of shit" / "the grove should be surrounded by a ring of trees" /
  "not all trees need a bunch of climbable branches": the plateau is 13 m across the radius, its middle open lawn
  (grove_heart at the middle, the spawn 3 m south facing down the hill: World turns him by the spawn marker and the
  camera with him); a ring of trees round its rim with gaps (path and torii, the view, hut, shrine, pond); the shrine,
  hut and pond at the edge; no lanterns. Only the great camphor and two ring trees are climbing trees (`tree_`);
  the rest are plain (`treep_<n>_<seed>_<size%>_<oak|cedar>`: TreeGen Oak or Fir with the oak bark, joined).
- "rolling hills in the distance for the skybox, and a volcano like Rainier or Fuji": three rings of ridgelines and a
  snow-capped stratovolcano to the south-south-west (framed from the grove and down the street), material `sky_`
  (World: unshaded, out of the fog, colours already hazed).
- Unverified: the five Bottlecap routes re-walked on the new hilltop (the billboard glide from the great camphor, now
  north-west of the clearing); cars and people on the long route in play; the sky_ colours against the N64 filter in
  play (shots were dimmed by the pause menu, which opens when the shot window loses focus).
- "I turned down the density but there's still a bunch of little spiky fur — that isn't controlled by the length or
  angle either" (2026-11-02): only a ruff's tips carried a rank, so its zigzag stayed, and a tuft's base was left as a
  fleck. Now every point of a spike carries its spike's rank (colour blue) and the side bit moved to UV2.x's
  twentieths (group in tenths; a cat's side still in UV x), and above the density the whole spike folds into its root
  (inside him) and takes no spring. tests/fur_bare.gd checks every one of his models: every body-fur point out from
  its root has its offset (0 that cannot fold). `look_shots.gd ... bare` shoots density 0, short, laid flat, stood out.
- "the grove hill is way too steep": the mound is HILL_TOP 2 m over 13 m of clearing to HILL_FOOT 23.5 m (smaller
  lumps); build_town.py prints its steepest slope (17.5 degrees, the pond's banks aside); slope trees standing on
  the winding path are moved along their radius till clear. "there's a random red disk that bounces you": the
  trampoline marker and bed are gone (no route used it; World skips a missing marker).
- "pine trees need collision and should be climbable": every plain tree (treep_) gets a trunk cylinder (80% of a
  cedar's height, 55% of an oak's) and a hidden flare out into the crown at its top, and is in `climbable`: he
  scurries up, is eased out round the trunk and hops on top (holding the stick at the tree, as with the
  drainpipes). tests/plain_tree.gd: walking into a cedar and an oak stops him; he climbs both and stands on top.
- 2026-11-02: "Honestly I kind of liked the earliest iteration of the rings around his body": fur type "rings" (the
  ruffs as at 593c2d7: even rings round his upper arms and thighs, cuffs at elbows and knees, three layers round his
  body, no loose tufts; FUR_NOW "rings"), now his own (models/raccoon.glb, FurLook.TYPES first, the editor's own);
  the shaggy fur that was his is "spiky" (models/raccoon_fur_spiky.glb); the shapes are built on the rings. "the fur
  strands are too skinny in general": a ruff ring has RUFF_SPIKES 6 (was 9, so each is half again as broad) and a
  loose tuft on his body or crown is BLADE 1.8x as broad (the mane as it was). "the angle still doesn't seem to move
  the ones hanging on his belly": Back and Chest (every part) have an Angle of their own (look "parts" [size, width,
  density, angle]); tests/fur_angle.gd works the shader's angle step over the body ruffs' tips (rings: out 0.18 /
  0.14 / 0.06 m at -0.9 / 0 / 0.9); `look_shots.gd ... belly` shoots the belly from the side.

## Legs (2026-11-02)

- The user: "lots of the poses break his legs it looks like". `tests/leg_check.gd` measures every move headless (knee bent
  back against his front, leg stretched or crushed, foot under the ground, foot turned back, knee flipping across).
  Found and fixed: the spin lowered and turned his hips with the legs riding along (feet sank 7.5 cm and swung round:
  now planted and re-solved, pivoting under him); the helicopter hang let go slowly on landing, so his dangling legs
  went into the ground (now it lets go the frame he lands, and the legs dangle higher); every pose that solves the
  legs itself (all fours, sneak, spin, hang, helicopter) snapped the knee into the solver's plane as it blended in and
  could cave it inward (now `RaccoonRig._set_leg` turns the knee from where it points towards KNEE_OUT, a little
  bow-legged, by the pose's weight). Climbing, ledge hanging and tightropes are not covered by the playground test yet.

## 2026-11-02: the main session's round (the user's calls, in their words)

- Moves: all fours only past a full push ("he still starts running on all 4s before I press all the way": Player
  `sprint_push` 0.985); "the backflip needs to launch you higher" and "a snappier spin" (flip_lift 2.2, flip_time
  0.45); "the helicopter tail should only happen if you press A again"; "spin jump needs to be higher and you should
  keep spinning and slow fall until you land", then "too fast", "spin the stick longer to get him up to speed"
  (`spin_spinup` 16) and "shouldn't be able to spin faster [or slower] in the air" (SpinJump holds the turn);
  "spin around once when you start helicoptering"; "his head doesn't hang low enough when helicoptering" (head and
  body); "hang at the top of your jump a little longer" and "snaps you down a little too strongly" (Player
  `apex_gravity_scale` 0.35, fall_gravity_scale 1.3); "scurrying should be slower than running" (Player `speed_cap`,
  3.2 m/s); "a cleaner arc through the air between bounds" and "the all 4s running stride needs to be longer"
  (BOUND_STRIDE 2.6, one parabola from hind push-off to fore landing); idle and walk "slightly hunched", idle
  "rubbing his hands together" with hands "pointed down not up"; fingers "shouldn't be splayed" (they are modelled,
  he has no finger bones: build_raccoon.py hands()).
- Tail and fur: "his tail is all droopy now" (the fur's downward hang is off for the tail and head); "the tail should
  spin ... stuck in one direction" (the tail is carried round with his heading, read from the hips' forward); "the fur
  is too much like springs ... too bouncy" (FUR_DAMPING 17). Head fur: a mane ring plus crown tufts.
- Effects: dust "a few puffs" became little cloud clusters "in little rings where you step", on the ground; jumping
  puffs too; the tail spin and helicopter "use the stepping dust" (bigger: "really tiny"). Food "a faint rim light and
  sparkle" and "burst" when taken (Pickup). Scurry: "little blue sparkles" on climbables, "from farther away and a
  darker blue" (ClimbGlints, 14 m), and "black bars ... top and bottom" (ScurryBars). Climbing left/right follows the
  screen ("reversed").
- Wires "bounce ... time your jumps to jump higher and higher" (Tightrope kick/spring_at, WireBounce); the power lines
  are wires too ("you phase through half the wires").
- Look: "a cuter font", "a pixelated one" (Pixelify Sans, README credit); "the pixel filter should be more like close
  encounters" and then "in the pause screen with a dial" (N64Filter.strength, the Pixels dial; user://settings.cfg).
- World: "add the gloaming grass" (TownGrass on "grass" faces), "dont make new reeds check the ones we already have"
  (Warren's reed field at reeds_ markers), "tall grass to hide in" "denser clusters" (tallgrass_ markers,
  TownGrass.hidden); the skunks, badgers and rabbits on the lawns (Wildlife; their role is still a placeholder); the
  volcano "cut it about there" (top_cut 0.78); crows "sit on roofs and wires" and "not necessarily be hostile" (every
  third band dives: Claude's pick).
- Talk: "like hemlocks tower where they say things rather than a popup", then Gloaming's see-through, typed look;
  "spamming" (only the nearest talks, 3 lines a visit); "more things to say" (lines are Claude's placeholders).

## Vehicles (2026-11-02, the user's words)

- "the roads should be wider, the cars bigger and faster" / "and there should be different types, busses etc".
  `tools/build_vehicles.py` (Blender, `tools/vehicles.blend`) writes `models/vehicle_<kind>.glb`: hatchback, taxi
  (roof sign), kei_truck (flat bed), kei_van, bus (two-tone, doors on the left, route sign); real sizes (a car about
  4 m long and 1.5 m high, the bus 10.5 m). Kinds, looks, colours and speeds are Claude's picks.
- `HazardCar` (scripts/hazard_car.gd): `kind` picks the model and `KINDS` its size, cruise (cars 9.5-11.5 m/s, the
  bus 7.5) and wheels; one collision box to the roof (stand on it and ride); `half_size` is what Villager and
  SquadRaccoon read to be run over (below the roof only). It keeps back from the vehicle ahead on its road (`road`),
  closing to its speed at `GAP`; a bus stops at `bus_stop_<n>` markers near its road (else every so often).
- `Hazards.place`: three a road (`CARS_PER_LOOP`), kinds in turn from `KIND_MIX` (a bus on every other road),
  `KIND_PAINTS` for the bus, taxi and kei truck; they drive on the left now, as in Japan (`_lane`, LANE 1.9 m: widen
  it if the town's roads widen). The road widths are the TOWN fork's.
- Checks: `tests/vehicle_test.gd` (all up to speed, none runs into another, one pulls up behind a stopped one),
  `tests/vehicle_shots.gd` (each beside him from four sides). `models/car.glb` (tools/build_hazards.py) is unused now.
- Then "the cars need a lot of work — need to be scaled to the human models and actually work on the slopes, with more
  realistic wheels and such", and "need bright headlights at night". Scale: the town's people are the boy at size
  1.4 (about 1.75 m); a hatchback's roof comes to a person's head, the bus is near twice their height
  (vehicle_shots.gd stands one of them and him by each). Slopes (HazardCar._place): each wheel rays down for its road
  (past the cars and him); the body goes to its wheels' height, pitched and rolled to the plane under them (smoothed,
  22/s); each wheel follows its own road at once within TRAVEL 0.12 m (the springs); front wheels steer by the turn
  (atan of wheelbase x yaw rate / speed); the body mesh leans out in turns and dips braking (the box does not); it
  climbs up to 35% slower and takes a steep downhill bend up to 30% slower. `contact_error` is the worst wheel's gap to
  its road. Wheels (build_vehicles.py wheels()): a round-shouldered tyre with tread grooves, a dished rim, a centre cap,
  five lug nuts, a dark inner face. Lights: lamp, tail and sign faces unshaded (always lit); at night (DayNight
  .current.night > 0.5, or `HazardCar.lights` 0/1 forcing it) every vehicle shows a soft cone of light ahead and the
  LIT 3 nearest him real SpotLight3D beams and a red tail light. The vehicles' glass is "carglass": DayNight lights
  anything named "glass" at night as house windows. Checks: vehicle_test.gd (every wheel within 5 cm of its road:
  about 1 mm), vehicle_hill_shots.gd -- --out=<dir> [night] (the sharpest sloped hairpin from the side; ZoneStreaming
  is freed and the hour held there).
- Then "the cars need to be way faster like hard to dodge": cruise 20 (hatchback), 21 (taxi), 17 (keis), 13 (bus)
  m/s, up from 11/11.5/9.5/7.5. Each brakes at BRAKE 14 m/s² (bus 0.7x, keis 0.85x) planned over the 44 m ahead, so it
  comes into every bend at that bend's speed (`bend_at`: the turn between the 4 m chords either side, not the road's
  segments, which aliased); it holds that speed till its rear bumper is out, then pulls away at PULL 7 m/s². It
  follows no faster than it could brake to the one in front's speed by GAP. vehicle_test: each kind past 70% of its
  cruise, no bend entered over 1 m/s too fast (bend_speed/bend_sharp), the pull-up from its braking distance. Warning
  cues: headlights only (the vehicles have no sound).
- Then "there should be people in the cars": CarRider (scripts/car_rider.gd), one of the town's people (boy_tp.glb,
  CharacterLook, a HeadShape mask head) at RIDER_SIZE 1.25 (about 1.56 m: the walkers' 1.4 did not fit under a
  hatchback's roof), no body of its own; HazardCar seats a driver always and each other seat at RIDING 0.35 (a bus's
  BUS_RIDING 0.5; `seat_chance` overrides). Its SeatedRig lays the pose over the rig standing still: hips SEAT_HIP over
  the seat leant back SEAT_LEAN, feet down to the kind's "floor" and forward within the seat in front's `legroom`,
  driver's hands on the wheel's grips, others' in their lap, a glance out now and then. Seats, grips and the steering
  wheel are in the models (build_vehicles.py cabin(): empties `<kind>_seat_<n>`, seat 0 the driver's on the right,
  `<kind>_grip_l/_r`; seats() cushions and leant backs). Bodies are now see-through: Part.shell paints below the
  waist (`belt`), glass up to `top` (level faces, the roof, painted), a rail round the glass and pillars; lining()
  is the inside, dark, facing in. HazardCar draws "carglass" see-through (both faces). Far from the camera riders are
  posed every 2nd/3rd frame (RIDER_FAR 14/26 m), held still past 40 m, hidden past 70 m; they go with their vehicle
  (paused by ZoneStreaming, put away at night). Cost (perf_zones.gd, A/B with RINGTAIL_NO_RIDERS=1): +6.7k nodes,
  about 1-3 ms a frame on the sides, within the test's noise in the grove.
- Checks: `tests/rider_fit.gd` (headless: every seat filled; every rider's skinned points, and their bone-held pieces,
  have the shell over, under and beside them with at least 1 cm to the roof and sides, and none is through a seat's
  back); vehicle_shots.gd adds "window" and "windscreen" views (every seat filled).
- Seen while doing this (the TOWN fork's working world, not committed): the face roads have steps of up to 2.8 m
  under the road_<n> routes (the routes and the road surface disagree), so vehicle_test's wheel check fails there;
  on the last committed world the wheels were within 1 mm at the new speeds.

## The one-hand handstand on points (2026-11-02)

- The user: "you need to be able to handstand on one hand on the top of pointy things like trees and telephone poles".
- PointPerches.find (from World._grow_lawn, once the physics has the world) collects the points: the tops of the
  climb_ meshes named for poles or a chimney (each top's middle, from the mesh's highest ring of points) and every tree
  body's tip (over its trunk, at the top of its drawn bounds).
- PointStand (a child of the Player, priority -5): coming down within 0.6 m of a point, from above it, he catches it;
  scurrying up a pole to within 1.8 m of its top (under the crossarm) he springs up onto it. On it the Player takes no
  input of its own (`takes_input` off): the stick turns him, jump throws him up (`lift` 1.3), duck or scurry drops him
  off. Hazards.unseen counts him out of reach there (PointStand.perched).
- The pose (RaccoonRig._pose_handstand): turned over end to end, his left shoulder over the paw on the tip. That arm is
  drawn out 1.6x along itself (HS_ARM), cartoon-fashion: his arms are short (0.26 m), and at their own length his head
  came down onto the tip. The other arm is out, the legs together pointing up, a wobble, and the tail curled over.
- Checks: tests/point_stand_test.gd (drop onto a pole top, out of reach, the pose, jump off, scurry up a pole to the
  top), tests/handstand_shots.gd (four sides and above).
- Not checked in play: a tree tip (in its leaves), the chimney, turning on the point with the stick.

## Playing as the crow or the owl (2026-11-02)

- The user: "and add a mode where you can be the crow or owl". The pause screen's "Play as" row (raccoon, crow, owl
  faces) swaps who is played (`BirdPlayer.play_as(world, &"crow" | &"owl" | &"raccoon")`).
- `scripts/bird_player.gd` (BirdPlayer): the bird as a controller of its own, on the BIRDS fork's model and BirdBody
  poser, with `scripts/bird_camera.gd` (BirdCamera) following it. The raccoon is put away meanwhile (hidden, still, no
  collision, his FollowCamera off) and comes back on the ground under the bird (Claude's pick: under the bird, not
  where he was). Hops on the ground; jump takes off and each press in the air flaps (held: glides); the stick steers
  (banking); duck dives (the owl swoops faster); scurry settles on the nearest wire or pole/tree top (PointPerches)
  within 5 m; tail pecks (knocks what his tail knocks, never a cage: cages are his). Lands on anything it comes down on.
- Claude's picks: both birds take Crumbs (they count as his; not Bottlecaps); the hunters leave a bird be and nothing
  hurts the put-away raccoon (World.hurt, Hazards.unseen); the crow agile with quick flaps, the owl slow deep flaps,
  long glides, a faster swoop, its head following the camera; a ceiling 40 m over where it took over.
- The HUD's Scurry and Tail buttons show Perch and Peck while a bird is played (same buttons, same keys).
- Unchecked: the HUD's zone/counts still follow the put-away raccoon's place, not the bird's; touch flying on a phone.
- Tests: `tests/bird_mode_test.gd` (flap up, glide, settle on a wire, land on a roof, take a Crumb, owl, back),
  `tests/bird_mode_shots.gd -- --out=<dir>`.

## The grove's animals (2026-11-02)

- The user: "there should be the other animals in the grove too for me to see - skunk and beavers and rats and mice
  and rabbits and weasels and martens and otters", "gophers, prairie dogs", then "opossums" and "squirrels",
  "porcupine", "chipmunk" (with what each does: the opossum hangs by its tail or plays dead startled; the squirrel
  climbs the trees and sits nibbling; the porcupine waddles, raises its quills when he comes too close and climbs
  slowly; the chipmunk darts about the food pile and up the trees).
- Models: `tools/build_grove_animals.py` (Blender, on build_critters.py's pipeline; `-- <dir|-> <animal>`, or
  `burrow` for models/burrow.glb) writes models/<animal>.glb and _lo for beaver, rat, mouse, weasel, marten, otter,
  gopher, prairie_dog, opossum, squirrel, porcupine, chipmunk (.blends in tools/). The critter builders now paint the
  raccoon's grit (racc.paint_grit) after export: without it the kit's Paint colours made every body draw black.
  Porcupine quills ride a `quills` bone the rig grows (CritterRig.bristle). Sizes: Critter.SIZES.
- `GroveAnimals.place(world, markers, player)` (scripts/grove_animals.gd, from World._grow_lawn): 28 animals round
  the clearing (beyond 7 m of grove_heart): otters and the beaver swim in the pond and come out on its bank; prairie
  dogs and gophers by four burrow mounds, the prairie dogs sitting up as sentries; mice, rats and chipmunks nibbling
  round the FoodPile; skunks, rabbits, weasel, opossum on the rim; squirrels, chipmunks, the marten and the porcupine
  go up a nearby trunk, sit, and come down. Near him (3.5 m) they turn to look, within 1.6 m back off; prairie dogs
  and gophers sit up and stare; the porcupine turns its back, quills up; the opossum may flop (ragdoll) and lie still
  till he goes. Past 38 m they stand still, their rigs off. Counts, places and every look are Claude's picks.
  Not done: the opossum hanging by its tail, a chirp sound for the prairie dog.
- Then "and ringtails", "and turtles and frogs", "and snakes" (the user, 2026-11-02; not Frogulizer's frog). Ringtail,
  frog and turtle are build_grove_animals.py kinds too: the ringtail with big eyes in pale rings, round ears and a
  black-and-white ringed brush ending black (2, up the trees); the frog squat and wide, eyes on top, no snout or tail,
  dark spots, a throat on a `throat` bone it puffs croaking (CritterRig.puff); the turtle a slider: domed shell with
  plates, yellow plastron, a red streak behind each eye. Frogs (4) sit at the pond's edge and on lily pads
  (GroveAnimals makes five pads), croak, hop (Critter.hop), and leap in when he comes; turtles (2) bask on the bank and
  walk in slowly, swimming low. Nothing is put within 2.2 m of the fishing spot (`fishing_spot`, else PondFishing's
  west bank).
- Snakes: `tools/build_snake.py` writes models/snake.glb (a straight striped garter snake, no bones, its tongue every
  point past z 0.9) and snake_rock.glb. `GroveSnake` (scripts/grove_snake.gd) bends it in a vertex shader (Toon's
  with a vertex stage): a travelling S-wave whose phase follows the distance gone, so the body follows its head's
  track; or a flat coil, head on top in the middle; the tongue flicks. Two sun coiled on rocks on the rim, slither
  about and home, and when he comes near slide off into the grass, or into the pond and across it.
- Checks: `tests/grove_animal_shots.gd -- --out=<dir> [lineup] [grove]` (every kind beside him front and side, a
  slithering and a coiled snake; the grove from above and close by; prints counts, what each is doing, any that fell
  through, and a snake fleeing him).

## 2026-11-02: four faces, four zones (the user's calls; this supersedes the one-street layout above)

- "the grove needs to be bigger and surrounded by trees": the clearing is PLATEAU 20 m across the radius on a mound
  HILL_TOP 2.3 m to HILL_FOOT 32.5 m (steepest 17 degrees: build_town.py prints it), the pond (deeper: 1.7 m, so he
  swims) at its east edge; a wood two rows deep round it on the mound's slope (radii 23.5 and 28 m), mostly cedars
  (a plain cedar is about 4.5k triangles, an oak 17k), oaks in the inner row, the great camphor (north-west) and two
  climbing oaks; gaps only for the path and torii and the view down the south street. About 40 trees, ~340k
  triangles in all (build_town.py prints it). Hazards.HAVEN_RADIUS 31 m covers the clearing and the wood.
- "instead of just one side of the hill having a road down, it should be a 4 sided hill with windy roads down each
  side, thus breaking the map up into 4 zones. Each zone should be themed a little different and have different kit
  and food trackers": FACES in build_town.py, each built in its own frame (as if it were the south face) and turned
  into place (the Blender objects rotated about Z; World reads their global transforms). Zones and themes are
  Claude's picks: 0 Station (south: houses between the runs, flats and the station at the foot, the race down its
  first runs), 1 Estate (east: blocks of flats between the runs, more at the foot, the bath house chimney with the
  "Up the chimney" Bottlecap), 2 Stairs (north: old houses, six long stairways, the billboard with the glide
  Bottlecap: glide from the hilltop flats, lot 10), 3 Shrine (west: rice paddies stepped down between the runs,
  bamboo, a thatched farmhouse, a torii and shrine at the foot, cedars, the hollow log with the hidden Bottlecap). The
  cats' Bottlecap appears in the grove. `zone_<n>_<Name>` marks each face's middle (main's HUD counts by the nearest).
  The faces meet on plain grass ridges (the cone, walkable); the whole hill to PLAY (about 250 m) is solid ground,
  hidden_bound a circle round it. ground_global() gives the ground anywhere (the face it lies furthest down).
- "the roads should be wider": the ring road is 12 m (ROAD 35.6..47.6, pavements PAVE 3), the face roads ROAD_HALF 6
  with pavements to 8.5, the shelf BENCH 10.5, hairpins BEND 17 m and the top and foot turns TURN 10 m (a 10 m bus
  turns them), the runs 34 m apart. The ring has 12 lots (SECTORS 12, centred on their angles), four of them `road`
  where the streets leave (east, south, west, north). Cars: road_0 the ring, road_1..4 each face's down-and-back
  loop round its foot's turning circle; walk_2..5 each face's pavement.
- Lost kits (the user: "50 kits to rescue, and they should end up back in the grove after you find them", then "or
  maybe lets start with 20"): kit_0..19, five a face: in the tall grass between the first runs (easy), on a roof or
  ridge (up its drainpipe, or the farmhouse's corner post), on the bottom step of the second stairway, at the foot (the
  station's platform, by the flats, a shop's roof up its pipe, the torii's top beam up its post), out by the third
  hairpin. tests/kit_spots.gd checks each sits on a surface with room over it, out of the clearing.
- The trampoline and the ring's race are gone; the ring bath house keeps a chimney (`climb_chimney_ring`, no cap).
- tests/cap_routes.gd walks the chimney, the glide and the log; tests/pipe_climb.gd names the new buildings.

## The one-hand handstand on points (2026-11-02)

- The user: "you need to be able to handstand on one hand on the top of pointy things like trees and telephone poles".
- PointPerches.find (from World._grow_lawn, once the physics has the world) collects the points: the tops of the
  climb_ meshes named for poles or a chimney (each top's middle, from the mesh's highest ring of points) and every tree
  body's tip (over its trunk, at the top of its drawn bounds).
- PointStand (a child of the Player, priority -5): coming down within 0.6 m of a point, from above it, he catches it;
  scurrying up a pole to within 1.8 m of its top (under the crossarm) he springs up onto it. On it the Player takes no
  input of its own (`takes_input` off): the stick turns him, jump throws him up (`lift` 1.3), duck or scurry drops him
  off. Hazards.unseen counts him out of reach there (PointStand.perched).
- The pose (RaccoonRig._pose_handstand): turned over end to end, his left shoulder over the paw on the tip. That arm is
  drawn out 1.6x along itself (HS_ARM), cartoon-fashion: his arms are short (0.26 m), and at their own length his head
  came down onto the tip. The other arm is out, the legs together pointing up, a wobble, and the tail curled over.
- Checks: tests/point_stand_test.gd (drop onto a pole top, out of reach, the pose, jump off, scurry up a pole to the
  top), tests/handstand_shots.gd (four sides and above).
- Not checked in play: a tree tip (in its leaves), the chimney, turning on the point with the stick.

## Playing as the crow or the owl (2026-11-02)

- The user: "and add a mode where you can be the crow or owl". The pause screen's "Play as" row (raccoon, crow, owl
  faces) swaps who is played (`BirdPlayer.play_as(world, &"crow" | &"owl" | &"raccoon")`).
- `scripts/bird_player.gd` (BirdPlayer): the bird as a controller of its own, on the BIRDS fork's model and BirdBody
  poser, with `scripts/bird_camera.gd` (BirdCamera) following it. The raccoon is put away meanwhile (hidden, still, no
  collision, his FollowCamera off) and comes back on the ground under the bird (Claude's pick: under the bird, not
  where he was). Hops on the ground; jump takes off and each press in the air flaps (held: glides); the stick steers
  (banking); duck dives (the owl swoops faster); scurry settles on the nearest wire or pole/tree top (PointPerches)
  within 5 m; tail pecks (knocks what his tail knocks, never a cage: cages are his). Lands on anything it comes down on.
- Claude's picks: both birds take Crumbs (they count as his; not Bottlecaps); the hunters leave a bird be and nothing
  hurts the put-away raccoon (World.hurt, Hazards.unseen); the crow agile with quick flaps, the owl slow deep flaps,
  long glides, a faster swoop, its head following the camera; a ceiling 40 m over where it took over.
- The HUD's Scurry and Tail buttons show Perch and Peck while a bird is played (same buttons, same keys).
- Unchecked: the HUD's zone/counts still follow the put-away raccoon's place, not the bird's; touch flying on a phone.
- Tests: `tests/bird_mode_test.gd` (flap up, glide, settle on a wire, land on a roof, take a Crumb, owl, back),
  `tests/bird_mode_shots.gd -- --out=<dir>`.

## The grove's animals (2026-11-02)

- The user: "there should be the other animals in the grove too for me to see - skunk and beavers and rats and mice
  and rabbits and weasels and martens and otters", "gophers, prairie dogs", then "opossums" and "squirrels",
  "porcupine", "chipmunk" (with what each does: the opossum hangs by its tail or plays dead startled; the squirrel
  climbs the trees and sits nibbling; the porcupine waddles, raises its quills when he comes too close and climbs
  slowly; the chipmunk darts about the food pile and up the trees).
- Models: `tools/build_grove_animals.py` (Blender, on build_critters.py's pipeline; `-- <dir|-> <animal>`, or
  `burrow` for models/burrow.glb) writes models/<animal>.glb and _lo for beaver, rat, mouse, weasel, marten, otter,
  gopher, prairie_dog, opossum, squirrel, porcupine, chipmunk (.blends in tools/). The critter builders now paint the
  raccoon's grit (racc.paint_grit) after export: without it the kit's Paint colours made every body draw black.
  Porcupine quills ride a `quills` bone the rig grows (CritterRig.bristle). Sizes: Critter.SIZES.
- `GroveAnimals.place(world, markers, player)` (scripts/grove_animals.gd, from World._grow_lawn): 28 animals round
  the clearing (beyond 7 m of grove_heart): otters and the beaver swim in the pond and come out on its bank; prairie
  dogs and gophers by four burrow mounds, the prairie dogs sitting up as sentries; mice, rats and chipmunks nibbling
  round the FoodPile; skunks, rabbits, weasel, opossum on the rim; squirrels, chipmunks, the marten and the porcupine
  go up a nearby trunk, sit, and come down. Near him (3.5 m) they turn to look, within 1.6 m back off; prairie dogs
  and gophers sit up and stare; the porcupine turns its back, quills up; the opossum may flop (ragdoll) and lie still
  till he goes. Past 38 m they stand still, their rigs off. Counts, places and every look are Claude's picks.
  Not done: the opossum hanging by its tail, a chirp sound for the prairie dog.
- Checks: `tests/grove_animal_shots.gd -- --out=<dir> [lineup] [grove]` (every kind beside him front and side; the
  grove from above and close by; prints counts, what each is doing, and any that fell through).

## Fishing in the grove pond (2026-11-02)

- The user: "there should be a pond in the grove and a fishing minigame (we have assets for that)". The assets were
  Gloaming's Fishing; they are now GameCommon's `godot/fishing` (FishingSpot, FishingRod, FishingHud, FishingButton,
  fishing.glb from tools/build_fishing.py), installed here with kit.sh under `fishing/`. Gloaming keeps its own copy.
- `scripts/pond_fishing.gd` (PondFishing.place(world), after the HUD): the spot is the `fishing_spot` marker facing
  `fishing_water` if they exist, else the pond's west bank facing east. Walking up to it (1.6 m) a round button comes
  up at the bottom middle (F, or LB on a pad); then the fishing panel and buttons (hold to cast, hook, reel; the cross,
  or duck, puts the rod away; F/LB/Space/A press the main button). The HUD's own buttons hide while fishing.
- Claude's picks: the pond's fish (koi, carp, bluegill, catfish, a rare golden koi), the button rather than a raccoon
  to talk to, the west bank, a rod about 1 m (rod_size 0.32), hands at 0.55 of the boy's reach, the catch held out at
  his eyes (land_point). Bests are kept in user://fishing.cfg ("grove_pond").
- Check: `tests/fishing_test.gd` (walks up, button, rod, cast into the pond, a forced bite, reels, lands, the best
  kept, puts it away; measures the rod's gap to his head in each move); with `-- --out=<dir>` in a window it shoots
  the cast, fight and catch, and him with the rod from four sides, above and close.

## Day and night (2026-11-02)

- The user: "there needs to be a day and night cycle", then "day is more dangerous — more cars, and hawks can easily
  see you, and more people".
- `DayNight` (scripts/day_night.gd, `DayNight.place(world)` after the clouds) runs the hour round: 14 real minutes a
  day (DAY_SECONDS), starting at 10:00. GameCommon's weather (installed under `weather/`) gives the sun's and moon's
  paths (Daylight.at: sunrise 6:00, sunset 18:00) and the sky shader (stars and moon at night); DayNight's own KEYS
  give the colours: dawn, the summer midday the town was built in, golden evening, a blue moonlit night. It sets the
  world's sun (the moon by night), ambient, fog, the far hills' `sky_` materials, the puff clouds' light, and lights
  the windows: the far town's "window" material, and the houses' "glass" in about two houses in three (a lit copy,
  warm by night). Lamps on the poles at night (one emissive head per pole, under its lowest wire; the real lights
  moved to the ones nearest him), fireflies over the grove. The HUD dial (top right, under the pause button): the sun
  or a crescent moon over a day/night disc turning with the hour. No shrine lanterns exist to light (removed earlier).
- Danger is one value, `DayNight.current.danger` (1 by day, 0 at night, between at dawn and dusk; `night` is the
  opposite, for lights). Hunters read `DayNight.by_day(day_value, night_value)` (1.0 with no DayNight, so the yard
  tests keep the old behaviour), `is_night()`, `is_day()`. By day the hawk sees him from 1.8x further and comes down
  sooner; at night it cannot see him (it still circles). The owl hunts only at night; hostile crows dive only by day.
  People notice him from 1.5x by day, 0.6x at night. Cars: Hazards.CARS_PER_LOOP 4 by day, 1 a road at night; people:
  every second one at night. What is parked is put away only out of his sight (40 m), with meta `put_away_by_night`
  (hidden, not processing, its collision layer kept in meta `night_layer`). HazardCar's headlights read
  `DayNight.current.night`. Tall grass and the grove still hide him at any hour.
- Claude's picks: the 14 minutes, the 10:00 start, every colour, the numbers above, which houses are lit.
- Checks: `tests/day_night_test.gd` (headless: the clock runs; noon, midnight, dawn and dusk values; windows, lamps,
  fireflies), `tests/day_night_shots.gd -- --out=<dir>` (dawn, noon, evening, night from the grove, the ring road and
  facing a house).
- Street lights (the user, 2026-11-02: "there needs to be street lights"; the town work models them): DayNight
  `find_street_lamps()` takes every `streetlamp_<n>` marker (under a lens) and every surface of material `streetlamp`.
  At night the heads glow sodium orange (SODIUM), a pool of light (shaders/light_pool.gdshader, one MultiMesh of
  additive discs laid on the ground by raycast, POOL_RADIUS 3.4 m) lies under each, and the LIT_LAMPS 5 real lights
  (SpotLights shining down, 9 m, shared with the pole lamps) go to whichever lamps are nearest him. None found: none
  made. Not in ZoneStreaming (lights and the MultiMesh are not kept by it). `tests/street_light_test.gd` (headless; it
  makes three lamps up if the town has none; `-- --out=<dir>` in a window takes a night picture).

## The town's people brought low (2026-11-02)

- The user: "you should also make a lower poly version of the people like I did for gloaming". HazardPerson wears
  models/boy_tp.glb (GameCommon character-controller `tools/build_boy_tp.py`, Gloaming's build_man_tp.py way): every
  mesh of boy.glb collapsed, mirrored, held at the head, hands and open edges (hems), budgets body 1300, the arms and
  hands 900, heads 650, boots 300, skirts 500, over pieces 400, other pieces 20% within 120-400 (faces and the knee
  patch kept); then every worn piece pushed as clear of the low body as it was of the high (at least 5-12 mm) and the
  whole shaded smooth by angle. Every slot and option keeps its name, so CharacterLook and the HeadShape mask heads
  (made from its 650-triangle `boy_head__base`) work as on the boy. Its bone rests match boy.glb's exactly (imported
  with the glTF's own bone axes). The numbers are Claude's picks.
- A dressed person: about 3.8-4.8k triangles (the boy's 15-20k). models/boy_lo.glb is another thing (build_boy.py's
  LOW, a 200-triangle head). Check: `tests/people_lo_shots.gd -- --out=<dir>` (four people high beside low from four
  sides, their heads close, a crowd of 30; prints the triangles and the rests' difference).

## 2026-11-02: the grove's pond, wood and great oak; the far hills; road paint (the user's calls)

- "there should be a pond in the grove and a fishing minigame": POOL (14, 6), about 7 x 6 m, its banks uneven
  (`_pond_d`, `pond_edge`), 1.7 m deep; a wooden jetty out from the clearing's side; lily pads, four koi, reeds on the
  far bank. Markers for the fishing work: `fishing_spot` (the jetty's end; its -Z points out over the water) and
  `fishing_water` (the middle of the water's surface); `pool`/`pool_size` as before.
- "the grove needs to be surrounded with a denser woods ring": four staggered rows (radii 22.5, 25, 27.5, 30 m, 4.4 to
  5.4 m apart); the inner rows full cedars and plain oaks, the outer two TreeGen.simple() (`treep_..._cedarlo` /
  `_oaklo`: World makes them simple). The path spirals round the mound and runs along each row a long way: a tree
  within 1.8 m of it is moved along its radius or left out. About 112 trees, ~500k triangles (build_town.py prints
  it). Undergrowth: ferns, three bamboo clumps, five fallen logs (solid), three tall-grass patches.
- "the main base should be at the base of a great big oak tree with gnarled roots, where the giant raccoon sits and
  snoozes": the great tree (the Great camphor's build, oak bark: World) stands at OAK (-11, -11), the clearing's
  north-west edge, the wood cleared round it; eight gnarled roots snake out from its foot (`oak_roots`, solid);
  `great_oak` marks its trunk's foot. `grove_heart` (the band's base) is just in front of it, the spawn 3 m off;
  `haven` marks the hill's middle (Hazards.safe measures from it when present).
- "the hills in the distance need a little more work, and some 2D anime style trees": four ridgelines painted in
  their vertex colours (PaintPiece; `sky_paint`), dark forest green along the tops fading to a pale mist band at each
  foot, bluer and paler with distance; fields and little buildings on the nearer two; flat painted trees (`sky_tree`:
  textures/anime_tree.png from tools/make_textures.gd, a clumpy crown lit along its top and shadowed below right, a
  thin trunk; World draws it alpha-scissored, unshaded, no fog) along the ridgelines and in copses, tinted per ridge.
- "the road needs lines painted on it and less repetitive texture": dashed white centre lines, white edge lines, zebra
  crossings where each street leaves the ring and where each stairway meets a run (`nocol_..._paint`); the ring's
  outer edge line open at the four junctions. A new asphalt texture (patches, cracks, an oil stain, worn tracks; 5 m
  tile) and the world shader's `variation` (World sets 1 on asphalt): the texture again at another scale and turned,
  blended in, and patches of lighter and darker tarmac, by a slow noise in world space.
- "there should be dumpsters to jump into and trash cans to knock over": `dumpster_<n>` markers (-Z the lid's front;
  four round the ring, three a face) and more `can_<n>` beside them.
- **Gotcha:** Blender's bmesh colour layer has no render colour, so the glTF export writes a white COLOR_0 and the real
  colours as COLOR_1, which Godot does not read: the world's vertex shading (darker low down, uneven face to face)
  has never reached the game. PaintPiece sets `render_color_index` so the painted sky's colours arrive; turning it on
  for every Piece (build_world1.py) would darken the whole town: not done, the user's call.
- `tests/zone_shots.gd -- --out=<dir>` (start, the jetty, the clearing, a street with the filter and without, the
  ring road, the views from the grove and a street; it shuts the pause screen first: a pad elsewhere can press Start).

## Low-poly animals (2026-11-02)

- The user: "we need to make sure all the animals are decently low poly twilight princess esque level of detail", "to
  improve performance". Every animal but the raccoon (he and the villagers keep his full build) is built to a budget:
  `tools/lowpoly.py` TRIANGLES gives each critter, grove animal and the cat a budget for its fused (remeshed) parts,
  shared out by each part's old share, and a fraction of every tube's sides (thin strands down to three). The birds
  have THRIFT in build_birds.py (fewer sides and rings, feathers in four steps), the dogs a coat of 2800 in
  build_yard_dog.py, the porcupine's quills are three-sided cones, the badger's face bands are thinned. Smooth shaded
  (the `_lo` builds stay flat-shaded demakes); the grove now uses the full models (they cost no more than `_lo`).
- Triangles, before -> after: cats ~24.5k -> 6-6.5k, fox/skunk/badger 23-29k -> 5.7-5.9k, rabbit 21k -> 4k, grove
  animals 18-30k -> 2-5.4k (mouse 2.1k, porcupine 5.4k), dogs 15k -> 4.9k, crow 6.6k -> 4.2k, owl 8.7k -> 5.2k. What is
  left on most is the fur (ruffs ~1.4k, whiskers). `LOWPOLY=off` in the environment builds the old full ones.
  `tests/tri_count.gd` prints every animal's count (and its `_lo`).

## The UI's look (2026-11-02)

- The user: "give the UI a pass, the basic shapes are ugly", and "what are the go buttons?" (the testing panel's jumps
  to each Bottlecap: now folded away behind a small spanner button at the bottom left, shown only in the editor or
  with --dev / ?dev).
- `UiStyle` (scripts/ui_style.gd) builds the project theme, saved as `ui/theme.tres` (project.godot gui/theme/custom)
  by `tools/make_theme.gd`: run it after changing UiStyle. A Pacific Northwest wood (Claude's picks, every colour):
  deep fir-green tiles in a dark bark rim with a thick lower lip that sinks when pressed, amber when picked or held,
  cream lettering outlined in bark; variations "Badge" (the HUD's counts and the zone's name, pills in a wooden
  rim, bouncing when a count changes), "Card" (the pause screen's middle) and "Small" (testing buttons).
- `Icon` draws every symbol as a sticker: outlined in bark over a soft drop shadow, a touch of shine; the scurry
  button is a raccoon's five-fingered fore paw print, the tail button his ringed tail curled; new TOOLS (spanner).
  The day/night dial has a wooden rim to match. The speech bubbles keep Gloaming's see-through look (the user's call).
- Check: `tests/ui_shots.gd -- --out=<dir>` (window; every symbol, HUD by day and night, a bounce, the testing panel,
  the fishing button, as the crow, pause, the fur editor; also at --resolution 390x844).
- Not done: on a tall phone screen the HUD's counts are drawn at desktop size (the canvas is 1280 wide), so small;
  the pause screen zooms itself, the HUD does not.

## Performance: only the zone he is in runs (2026-11-02)

- The user: "Let's work on performance too, make sure to only load stuff in the zone you're in (the grove and surround
  ring is its own zone as well so 5 zones total)". Zones (scripts/zones.gd) has a fifth, "Grove": within GROVE_RADIUS
  48 m of grove_heart (the clearing, the wood and the ring road out to its edge, 47.6 m); the HUD shows its own food
  there and the kits for the whole hill (they come home to it).
- `ZoneStreaming` (scripts/zone_streaming.gd, started at the end of World._grow_lawn) gives everything set out a zone
  by where it is (a wire by its middle, a band of crows by its home): live (in his zone, home there, or within
  LIVE_REACH 30 m of him), frozen (a still thing in a zone next to his: shown, not running), hidden (not running, not
  shown, out of the physics). The grove is next to every side. Changes go 120 a frame, looked at every 0.3 s; a jump
  of over 8 m (a respawn, a test) is set at once. Paused things only pause: nothing is moved. Not kept, so never
  paused: him, the camera, his band, a villager following him. A car or walker DayNight put away stays away. Freed
  things are let go. Far meshes of still things are not drawn past 125 m (trees) / 55 m (small things). A live
  figure far from the camera is posed every 2nd/3rd/4th frame past 12/22/35 m (CharacterRig.lod_every, also in
  GameCommon's character_rig.gd). A test that switches a node off for good sets its meta `stream_mode` to
  PROCESS_MODE_DISABLED too, or a zone waking up turns it back on (smoke does).
- Numbers (tests/perf_zones.gd, 1280x720 window, frame ms / process ms / physics ms), streaming off -> on:
  Grove 97 / 52 / 13.1 -> 37 / 34 / 3.8; Station 71 / 43 / 11.5 -> 19 / 23 / 3.0; Estate 64 / 44 / 9.9 -> 19 / 23 / 3.3;
  Stairs 62 / 39 / 11.6 -> 17 / 21 / 3.0; Shrine 63 / 42 / 12.1 -> 15 / 21 / 2.8. The grove is still the heaviest: 31
  villagers, ~45 animals and ~3M primitives of dense trees in view.
- Measure: `godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tests/perf_zones.gd [-- --no-stream]`
  (it shuts the pause screen each frame: it opens when the window loses focus and would stop everything). Any run with
  `RINGTAIL_NO_STREAM=1` in the environment has streaming off. `tests/zone_streaming_test.gd` (headless) walks grove,
  each side and back: live, frozen and hidden as above, the band running, the HUD's zone and counts.

## Buildings as mini levels (2026-11-02)

- The user: "the houses need more complex shapes that lend themselves to platforming over just boxes spin up an agent
  to make a house generator that can function as a mini level generator essentially", then "same for the apartment
  complexes and factories etc". The setting is the Pacific Northwest ("it takes place in the PNW not japan").
- `tools/buildings.py` (a Blender library; build_town.py imports it): `buildings.make(kind, name, x, y, z, turn, seed)`
  builds one seeded building with a measured route from the ground to its top, and returns the route, the `top` (a
  spot for a reward), the Crumbs it put along the way, its `bounds` and any `problems` (check_route against his moves:
  RISE_JUMP 1.0, RISE_LEDGE 1.45, GAP 2.2, HEADROOM 1.3). Kinds: craftsman, box, farmhouse, aframe, walkup,
  commercial, construction, factory, warehouse, substation, culvert. `ZONES` maps the user's four zone themes to kinds.
  The kinds, their parts, the routes and every size are Claude's picks.
- Rules the routes taught (each found by tests/building_routes.gd): approach eaves from outside their line (his
  collider is 1.3 m tall, so nothing he stands on may be under an overhang); a climbable must end flush with or
  lean out past what is over it (the A-frame's flat ridge top, the crane's column clear of its deck, the drainpipes'
  lean); a route never crosses an open gap between stair flights (walk along the landing first); vents are not on a
  ridge he walks along.
- Check: `blender -b --factory-startup --python tools/build_building_preview.py -- <dir|-> [kinds|all] [seeds] [turn]`
  (models/buildings_preview.glb, pictures from four sides and above), then `tests/building_routes.gd [-- <name prefix>]`
  (headless: he is put at each link's start and walks, jumps, catches, scurries or climbs to its end). All 11 kinds
  passed for seeds 1 to 5, and turned 1 rad.
- Rooftops (the user, 2026-11-02: "the rooftops need chimneys, antennas, satellite dishes, signs, AC units, vents
  etc"): every kind gets seeded clutter after its route is laid, each thing put only where `_clear` finds it off every
  route link (0.9 m plus his headroom) and every other thing. Houses: chimneys (now climbable, `climb_<name>_chimney`,
  a second stone one on some), plumbing vents, roof vents, a skylight, solar panels on the back slope, a TV mast near
  the ridge, a dish on a gable end. Flats and shops: AC units (steps), a duct, mushroom vents, dishes, a mast with a
  red light, red lights on the parapet corners; shops also a stair hut, a sign on the front edge, a water tank.
  Factory and warehouse: extractor fans, steel flues, a pipe, skylight strips, a sign over the door; substation an AC
  unit and mast on the hut; the culvert a vent stack; the site a floodlight mast. Masts and flues have an unseen
  climbable column named `climb_<name>_pole_hidden`, so PointPerches finds their tips (and the chimneys') for the
  handstand (building_routes.gd counts them). Routes all pass for seeds 1 to 6.

## Cats that climb and walk wires (2026-11-02)

- The user: "the cats should have more complex behaviour, stalking around climbing houses and walking along wires (so
  they are better at chasing)". YardCat (scripts/yard_cat.gd) now: about its patch it wanders, sits and washes
  (CatRig.groom: head round to its flank), and leaps up onto a wall or low roof by home to sit there; seeing him it
  stalks low with stops, crouches, wiggles and pounces; missed, or when he runs or goes up, it chases (run 3.3 m/s,
  slower than his run): leaps up anything up to CAT_JUMP 2.3 m, leaps gaps between roofs (CAT_GAP 3.6 m), climbs
  whatever is `climbable` (drainpipes, trees, poles; rig.climbing_npc), over the top onto a roof, or onto a wire strung
  there, and walks wires (Tightrope; it jumps onto one from a roof, the rig balancing on `tightrope`) to get at him.
  It gives up after CHASE_FOR 14 s, past TERRITORY 20 m from home, or once it has lost him LOST_FOR 2.5 s (it goes
  to where it saw him last first), then goes home and ignores him COOL_FOR 6 s. Unseen (grove, tall grass, perched)
  ends a chase; his tail spin still sends it flying, off a pipe or a wire too. All the numbers are Claude's picks.
- Pathing is simple on purpose: rays for ledges and gaps ahead, a fan of rays for the nearest climbable (scored by how
  near it is to him), the wire he is on (Player.tightrope_on). No navmesh.
- Check: `tests/cat_chase_test.gd` (headless: stalk and pounce, leap a 2.1 m wall, climb a drainpipe onto a 3.2 m
  roof, climb a pole and walk the wire to him, give up and go home; `-- --out=<dir>` in a window shoots the stalk,
  the climb, the wire and a cat washing). The playground needs `Hazards.haven` moved off: its default sits under the
  playground's middle and makes the whole yard the grove (cat_shots.gd does the same now).

## Playing as every animal (2026-11-02)

- The user: "do most of the animals share a rig? there should be an option to play as all the animals", then "or at
  least just to run around the grove as them". (Yes: the critters, grove animals and cats are CritterRig < CatRig <
  RaccoonRig on his skeleton; the dogs are GameCommon's DogRig; the snake bends in a shader.)
- `AnimalPlayer` (scripts/animal_player.gd) is a BirdPlayer, so `BirdPlayer.play_as(world, &"fox")` plays any of
  `AnimalPlayer.ANIMALS` (19 critters, three of the town's cats by their looks, the five dog breeds, the snake) and
  everything that follows the bird (zones, streaming, HUD buttons, Crumbs, the put-away raccoon) follows it. Mammals
  and cats: a CritterRig reading this body as a Critter's; dogs: a YardDog carried along; the snake: a GroveSnake.
  Walk at a light push, run at a full one, jump, paddle at the top of deep water; rabbits and frogs hop along. Camera:
  BirdCamera (`lift`), closer for small ones, swinging round behind as it runs.
- Claude's picks: every animal's speeds and jump (AnimalPlayer.FEEL, else from its size); the tail button's thing (skunk
  spray, porcupine quills, opossum plays dead till the stick or jump, frog croaks, dogs bark, the snake rears and
  coils); Crumbs count as his, cages are his alone; the hunters leave a played animal be (as a bird). Not done:
  swimming poses.
- Climbing (the user: "add climbing for climbers"): AnimalPlayer.CLIMBERS (squirrel, chipmunk, marten, ringtail,
  opossum, porcupine slowly, weasel, the cats; which and how fast are Claude's picks) go up anything `climbable` as
  his Scurry does: pushed into it (scurry held, or a firm push), up the screen climbs, down comes down, across goes
  round to the screen's side, round a limb overhead (on to it if stuck), over the top on to it, jump off backwards;
  the rig takes its climbing pose (`climbing_npc`). play_as_test climbs a trunk and a pole (squirrel) and a drainpipe
  on to a roof (cat) in a yard of its own; play_as_shots `climb` shoots a squirrel and a marten up the grove's tree.
- The pause screen's Play as row has an Animals button: a page of their pictures (ui/faces/<animal>.png, made by
  `godot --path . --audio-driver Dummy -s res://tools/make_animal_faces.gd`), seven across, four on a tall screen.
- Checks: `tests/play_as_test.gd` (headless: each walks, runs, jumps, its tail button, back to the raccoon),
  `tests/play_as_shots.gd -- --out=<dir> [animals]` (the page, and some in the grove standing, running, tail button).

## Ferns, brambles and flowers (2026-11-02)

- The user: "we should bring in the ferns from warren" and "and make blackberry bushes and flower generator".
- GameCommon's new `godot/undergrowth` (installed here under `scripts/`): Warren's `Undergrowth` (ferns, bushes, moss;
  lifted unchanged with `plant_push.gdshaderinc`), `FlowerGen` (eleven PNW presets: lupine, foxglove, fireweed,
  trillium, oxeye daisy, Oregon iris, columbine, salal blossom, camas, garden rose, hydrangea) and `BrambleGen`
  (Himalayan blackberry mounds: arching thorny canes, leaf-spray cards, flowers, berries by ripeness), drawn with
  `PlantLook`. See its README.
- `GrovePlants` (scripts/grove_plants.gd, from World._grow_lawn; Claude's picks of where): ferns, moss and bushes thick
  under the grove's trees and through its woods, a few under trees elsewhere; brambles outside the grove's outermost
  trees, on the banks beside every road (more in the industrial zone) and over the building site's lots; drifts of
  wildflowers on the grove's lawns, trilliums and salal in its shade, flowers on the road verges, roses, hydrangeas and
  foxgloves in the suburb's (Rural) front gardens. Read from tree_/treep_/great_oak and road_<loop>_<i> markers and the
  zones by name, only on grass (TownGrass.mask), brambles only where the ground round them is all grass at about their
  height. Flowers 1.4x real. Patches of 24 m, shown by zone as GroveMushrooms are; ferns drawn to 38 m, flowers 38,
  brambles 60. In a bramble thicket he is hidden as in tall grass (`GrovePlants.in_thicket`, from Hazards.hidden:
  Claude's pick). `RINGTAIL_NO_PLANTS=1` leaves them out, to measure against.
- Checks: `tests/plant_shots.gd -- --out=<dir>` (every preset, three seeds, close from four sides, triangle counts),
  `tests/plants_world.gd` (headless: counts, every zone, none off the grass, hidden in a thicket; `-- --out=<dir>` in a
  window shoots the grove's woods, a lawn, a bramble, a road).

## The grove's spring and waterfall (2026-11-02)

- The user: "the pond needs to be much bigger, same with clearing, and the spring and waterfall need a ton of work, not
  just flat texture, it needs to be a small bubbling pond with a real waterfall". (The bigger pond and clearing are the
  town's: build_town.py.)
- `GroveWater` (scripts/grove_water.gd, from World._grow_lawn) draws the water; the town only shapes the rock. A small
  spring pool (GameCommon `Water`) at `spring_pool` (scale x its radius, y its depth) with a `WaterSpring` on its
  bottom (a boil of white water, a ring every moment, bubbles rising and popping, froth drifting); a `Waterfall` from
  `waterfall_top` to `waterfall_bottom` (a curved streaky sheet running from the pool's edge over the lip, white water,
  spray, mist and a churning `FoamPatch` at its foot, rings and small splashes on the pond); the pond's Water given a
  livelier look (green-blue shallows to deep fir-green, more lines and glints, a wider ragged foam rim). Without the
  falls markers it steps out from the pool towards the pond till the rock falls away. The town's old flat
  `nocol_spring_water` is hidden. Waterfall, WaterSpring and FoamPatch are new in GameCommon's `godot/water`.
- Colours and sizes are Claude's picks. Check: `tests/water_shots.gd -- --out=<dir>` (window: the spawn, the falls from
  the side and the front, the spring pool from above, the foot, the falls at night).

## 2026-11-02: the Pacific Northwest town (the user's calls; supersedes the Japanese town above)

- "it takes place in the PNW not japan the mountain should look more rainier like and there should be other mountains
  as well": no torii, shrine, tiled roofs, danchi, vending machines, paddies or bamboo. The Ghibli mood stays. Every
  building is `tools/buildings.py`'s (the BUILDINGS work: craftsman, box, farmhouse, aframe, walkup, commercial,
  construction, factory, warehouse, substation), made at the origin and set on a levelled lot (`made_at_origin`,
  `set_made`, `line_up`). Ring lots: LOTS kinds; the walk-up on lot 10 is `flats_10` (the glide starts from its roof).
  Mountains (`cascades()`): Rainier south-east (a broad glaciated dome), St Helens south (a crater), Adams, Baker and
  the jagged Olympics to the west. Their places and sizes are Claude's picks.
- The zones: "one of the zones should be a neighborhood under construction, one a more rural suburb vibe, one more
  commercial and city like, and one zone needs to be sewers, substations, factories and warehouses", then "and the
  zones need different road layouts". Claude's picks: S City, a grid on the slope (boulevard with a planted median,
  three cross streets with traffic lights, two avenues; streets `follow` the slope so crossings meet with no step);
  E Industrial, a trunk road with level gravel yard roads off it to terraced yards and an open sewer channel; N
  Construction, three runs and hairpins; W Rural, a winding lane with three cul-de-sacs, a barn, a pasture, an orchard
  and the hollow log. Faces are `zone_<n>_City/Industrial/Construction/Rural`.
- "the hill slope doesn't need to be so severe in the zones", "or not all of them at least": FOOTS (City -16,
  Industrial -14, Construction -34, Rural -13; Claude's picks). The ridges and the valley follow `foot_at(angle)`.
  graded() eases each road's grade in and out. Industrial was -24, then -17: at about 12% on a long straight the
  vehicles' wheel check failed (vehicle_test).
- "each zone should have a different view in the distance", "so the city zone sees more city in the distance, suburbs
  more suburb, ...": beyond() fills the valley by the nearest face. City: towers rising to a downtown with a needle
  tower. Industrial: sheds, stacks, tanks, a rail yard and a bay with container cranes. Construction: half-built
  streets, tower cranes and dirt. Rural: fields, barns and tree rows. The hills and mountains are behind.
  `far_height` keeps the valley at the foot's height out to PLAY + 30 m: it used to rise from 190 m, so past the
  bigger hill's foot the far land and its trees floated over the faces (the user's "floating ring of trees").
- The grove: "the grove needs to be bigger, and have 2 rings of trees, in between we need a couple big trees for npcs
  to be in", then "the pond needs to be much bigger, same with clearing", "the grove still needs a denser surround
  woods". PLATEAU 34 m, INNER rows 37/40 m, three `giantfir_<n>_<seed>` markers at r 44.4 m (main grows the Giant
  firs and their perches in world.gd), OUTER rows 48.5/50.5/52.3 m. Kinds: fir, redcedar, maple, alder (`treep_` kind,
  `lo` the plainer build; world.gd maps fir/cedar->Fir, redcedar->Spruce, maple->Maple in summer green,
  alder->Birch). Understory: ferns, salal, huckleberry, nurse logs with seedlings. About 273 trees, ~800k triangles
  (build_town.py prints it).
- "there should be a stone fence surround the grove next to the sidewalk", then "the stone wall surrounding the grove
  should be taller than a person": `climb_grove_wall` at WALL_R 54.3 m, 2.2 m high and climbable, with a mossy walkable
  top and ivy. It has four gaps with stone-pillar arches (the path's and the quarters').
- "there should be a little hill in the grove": KNOLL (13, -16), 11 m across the radius, 3 m high.
- The pond: POOL (19, 7), radii 10 x 7.5, 1.9 m deep; jetty, `fishing_spot`, `fishing_water`. The spring (the WATER
  work draws the water): `spring_rocks` is a solid outcrop with a round basin and a notch whose lip overhangs the
  rock face. Markers: `spring_pool` (the pool's surface middle; scale.x its radius 1.4, scale.y its depth 0.6),
  `waterfall_top`, `waterfall_bottom`, `spring`.
- The great oak is main's ("Great oak" preset at OAK (-20, -20)). Here only its marker, the wood cleared 14 m round
  it, and `oak_roots`.
- Street furniture ("there needs to be street lights", "stop signs, street lights", "telephone booths", "covered bus
  stops", "benches"). Styles by zone are Claude's picks: cobra heads in the suburbs, the industrial zone and the ring;
  ornamental posts in the City; work lights at the construction site; lanterns up the grove's path. Each post is
  climbable and named for a pole (PointPerches). Markers: `streetlamp_<n>` (lens material "streetlamp"),
  `signal_<n>` (lenses signal_red/amber/green), `busstop_<n>`, `bench_<n>`. Stop signs have painted stop lines.
  Booths and shelters can be climbed onto: a newspaper box or bin to jump from.
- "each of the 4 zones should have 10 raccoons to save and 50 pieces of food": kit_0..39, ten a face, easy to hard
  (pavement, beside a building, building tops, specials), set down on their surface (`snap_kits`). `zone_food()`
  counts each side's food (a Crumb 1, a can 3, a dumpster 4) in the zone Zones would give it, trims the loose
  pavement Crumbs to 50, and prints `ZONE FOOD`. Zones and Hazards measure the grove from `haven` (GROVE_RADIUS 72,
  HAVEN_RADIUS 55).
- Tests: kit_spots (40), cap_routes (the factory's stack cap; the glide from flats_10 to the billboard at HILL_EDGE +
  6 m on the Construction face; the log), plain_tree (a fir clear of the giant firs, a maple), zones_test, smoke (ring
  spots 63.6 m, the `smoke_pole` marker, the shortest wire, the goner kept running), vehicle_test, `zone_shots.gd --
  --out=<dir>`. tests/pipe_climb.gd tests the old hand-made downpipes, which are gone; tests/building_routes.gd covers
  the generated buildings.
