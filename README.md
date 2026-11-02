# Ringtail (working title)

A 3D collect-a-thon platformer in the spirit of Banjo-Kazooie, played as a raccoon. Godot 4.7, GL Compatibility,
Jolt physics, with an N64 look (Liquid Metal's screen filter, plus world corners snapped to a coarse grid). Desktop
first. Local repo only for now.

## Playing

| Do | Keys | Pad | On screen |
| --- | --- | --- | --- |
| Move | WASD / arrows | left stick | (touch: stick on the left) |
| Camera | right mouse drag | right stick | (touch: drag on the right) |
| Jump; **hold on the way down to twirl the tail and fall slowly** | Space | A | ⤒ |
| Duck: **duck-walk on all fours**, crawl under low things | C / Ctrl | B | ⤓ |
| Sprint (only on the button): **on all fours, bounding leaps** | Shift | LB / LT | » |
| Tail: a **spin**, hitting all round him (in the air it lifts him a little, once a jump) | E / K | X | spiral |

Everything else the GameCommon character controller does works too: ledge catching (jump again to climb up),
wall kicks, dives and rolls, ladders, swimming, picking up and throwing.

**World 1** (a placeholder setting): a back yard and the alley behind it at dusk. 99 Crumbs and 5 Bottlecaps
(placeholder names). The Bottlecaps:

- **Up the chimney**: crates to the porch roof, the trellis up to the house roof, catch the chimney top from the ridge.
- **The billboard**: dumpster, pallets, catch the power pole's crossarm, then glide 6 m along the alley to the catwalk.
- **Cat scrap**: beat all three yard cats (tail spin); the cap appears on the porch.
- **Alley dash**: run into the stopwatch by the gate and take the 8 glowing crumbs in 25 s.
- **Under the porch**: duck-walk into the crawlspace at the front of the porch.

Three hearts; a cat's pounce takes one; out of hearts, or off the world, back to the last checkpoint. A Bottlecap
fills the hearts.

## Layout

- `raccoon.tscn`: the Player (GameCommon's `player.tscn`) with `RaccoonRig` (`scripts/raccoon_rig.gd`) and `TailMoves`.
- `scripts/raccoon_rig.gd`: his poses laid over the boy's rig: on all fours for duck-walk and sprint, the tail as
  a chain on springs, the tail moves.
- `scripts/tail_moves.gd`: spin, twirl; hits anything in the group `tail_hittable`.
- `scripts/world.gd` (`World`): loads `models/world1.glb`, makes its materials N64 ones and its meshes solid
  (not those named `nocol_`), places things at the model's markers, keeps score and hearts.
- `scripts/pickup.gd`, `yard_cat.gd`, `trampoline.gd`, `race.gd`, `hud.gd`, `icon.gd`, `n64_filter.gd`.
- `scenes/world1.tscn` (= `main.tscn`), `scenes/playground.tscn` (a bare test yard).
- Models, each from a Blender script in `tools/` (the .blend files are kept beside them):
  `build_raccoon.py` (raccoon, on GameCommon's `build_character.py`), `build_world1.py` (the level and its
  markers), `build_props.py` (crumb, cap, stopwatch, cat). Run with
  `blender -b --factory-startup --python tools/build_x.py [-- <picture folder>]`, then `godot --headless --path . --import`.
- GameCommon `godot/character-controller` is installed as it is (`scripts/player.gd`, `character_rig.gd`,
  `follow_camera.gd`, `touch_controls.gd`, `toon.gd`, `pool.gd`, `ladder.gd`, ...). Don't edit those here;
  improve them in GameCommon.

## Tests

```sh
G="/c/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
"$G" --headless --path . --audio-driver Dummy --fixed-fps 60 -s res://tests/smoke.gd            # PASSED / FAILED
"$G" --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 -s res://tests/shots.gd -- --out=<dir>
"$G" --path . --audio-driver Dummy --fixed-fps 60 --resolution 960x540 -s res://tests/pose_shots.gd -- --out=<dir> [moves]
```

`pose_shots` photographs each move (stand, walk, run, sprint, duckwalk, duck, jump, glide, spin, air_spin) from four
sides, and `bound` is eight pictures through one bound from the side. A dev panel (in the editor, with `--dev`, or `?dev` on the web) toggles the N64 filter and jumps to each
Bottlecap.
