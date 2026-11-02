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
