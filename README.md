# Ringtail (working title)

A 3D collect-a-thon platformer in the spirit of Banjo-Kazooie, played as a raccoon. Godot 4.7, GL Compatibility,
Jolt physics, with an N64 look (Liquid Metal's screen filter, softened; world corners snapped to a grid) and
Banjo-style painted textures. Desktop first. Local repo only for now.

## Playing

| Do | Keys | Pad | On screen |
| --- | --- | --- | --- |
| Move; **stick all the way: run on all fours, bounding** (partway: walk or run upright) | WASD / arrows (Alt: walk) | left stick | (touch: stick) |
| Camera | right mouse drag | right stick | (touch: drag on the right) |
| Jump; **hold on the way down: he hangs from his tail whirled as a rotor and comes down slowly** | Space | A | ⤒ |
| Duck: **duck-walk on all fours**, crawl under low things; at a full run, **slide** | C / Ctrl | X | ⤓ |
| **Long jump** (Mario 64): sliding (or ducking at a run), jump | duck, then Space | X, then A | ⤓ then ⤒ |
| Tail: a **spin** (crouch, wind up, whip round), hitting all round him; **in the air, a second jump** | E / K | B | spiral |
| **Pause**: go on, or **Fur & looks**, the model editor (his and each cat's fur type, Gloaming's hair textures, marks, markings, fur and mane length/angle/density, tail length/thickness, colours) | Esc / P | Start | ⏸ top right |

Also: leap on all fours when jumping from a bound; a big leap out of water; **wires to walk along and bounce on**
(jump at the bottom of a bounce to go higher); everything GameCommon's character controller does (ledge catching,
jump again to climb up; wall kicks; ladders; swimming; picking up and throwing). Left alone over a minute he sits.
He looks at things near him and now and then sniffs the air. His fur and whiskers spring as he moves.

**World 1** (a placeholder): an alley between the backs of two rows of houses, with yards behind fences, back
porches, rooftops to run along (wires across the gaps), power poles with phone lines, trash cans to knock over
(Crumbs spill out), a pool, a trampoline, yard cats. 218 Crumbs and 5 Bottlecaps (placeholder names):

- **Up the chimney**: on the tallest house (east, second from the south).
- **The billboard**: on the north wall; glide to its catwalk from the roofs.
- **Cat scrap**: beat every cat (tail spin); the cap appears mid-alley.
- **Alley dash**: run into the stopwatch at the south end and take the 8 glowing crumbs in 25 s.
- **Under the porch**: crawl under the back porch of the east house second from the south.

Three hearts; a cat's pounce takes one; out of hearts, or off the world, back to the last checkpoint.

## Layout

- `raccoon.tscn`: GameCommon's `player.tscn` with `RaccoonRig`, `TailMoves`, `WaterLeap`, `LongJump`, `CloudDust`.
- `scripts/raccoon_rig.gd`: his poses over the boy's rig (all fours, bound, leap, spin, rotor), the tail spring
  chain, sniffing, and the springing fur (spikes tagged in the model; `_spring_fur`, a fur version of Toon's shader).
- `scripts/tail_moves.gd` (spin, air spin, twirl), `long_jump.gd`, `water_leap.gd`, `cloud_dust.gd`, `wire.gd`.
- `scripts/world.gd` (`World`): loads `models/world1.glb`, paints it (`TEXTURES`, `shaders/world.gdshader`), makes
  its meshes solid (not `nocol_`), places things at the model's markers, keeps score and hearts.
- `scripts/pickup.gd`, `trash_can.gd`, `yard_cat.gd` + `cat_rig.gd`, `trampoline.gd`, `race.gd`, `hud.gd`, `icon.gd`,
  `n64_filter.gd`; `critter_rig.gd` + `critter.gd` (fox, skunk, badger, rabbit: built, not yet in the game).
- Models, each from a Blender script in `tools/` (the .blend files are kept beside them): `build_raccoon.py`,
  `build_cat.py`, `build_critters.py`, `build_world1.py` (the level and its markers), `build_props.py` (crumb, cap,
  stopwatch, trash can). `blender -b --factory-startup --python tools/build_x.py [-- <picture folder>]`, then
  `godot --headless --path . --import`. Textures: `godot --headless --path . -s res://tools/make_textures.gd`.
- GameCommon `godot/character-controller` is installed as it is. Don't edit those files here; improve them in GameCommon.

## Tests

```sh
G="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$G" --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/smoke.gd            # PASSED / FAILED
"$G" --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 -s res://tests/shots.gd -- --out=<dir>
"$G" --path . --audio-driver Dummy --fixed-fps 60 --resolution 960x540 -s res://tests/pose_shots.gd -- --out=<dir> [moves]
"$G" --path . --audio-driver Dummy --fixed-fps 60 --resolution 960x540 -s res://tests/cat_shots.gd -- --out=<dir>
"$G" --path . --audio-driver Dummy --fixed-fps 60 --resolution 960x540 -s res://tests/critter_shots.gd -- --out=<dir>
```

`pose_shots` moves: stand, walk, run, sprint, duckwalk, duck, jump, glide, spin, air_spin, and filmstrips bound,
leap, spin_film, heli, long_jump. A dev panel (in the editor, `--dev`, or `?dev` on the web) toggles the N64 filter
and jumps to each Bottlecap.

## Credits

- Font: Pixelify Sans (The Pixelify Sans Project Authors, github.com/eifetx/Pixelify-Sans; SIL Open Font License 1.1;
  `fonts/OFL.txt`), from Google Fonts. The game's
  default font (project setting `gui/theme/custom_font`), imported without antialiasing so it stays crisp. The
  user, 2026-11-02: "find a cuter font", "a pixelated one maybe".
