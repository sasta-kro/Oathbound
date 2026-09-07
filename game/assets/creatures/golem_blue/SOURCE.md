# Golem_Blue

Source: `assets/sprites/monster/golem_blue`, copied here because Godot can only
import files under the project root. Pack name and licence are not recorded in
the drop; fill them in before release.

The source frames are 90x64 with the golem standing on the bottom edge. They
are re-padded to 90x90 by `tools/pack_golem_frames.py` so the body sits in the
middle of the frame, which is what `CreatureVisual` assumes.

| File | Frames |
|---|---:|
| `idle.png` | 8 |
| `walk.png` | 10 |
| `attack_01.png` | 11 |
| `hurt.png` | 4 |
| `death.png` | 13 |

The golem art is roughly twice the size of the other creature sheets, so
`res://content/creatures/creature_earth_02.tres` sets `sprite_scale` to bring it
back in line.

Used by `res://content/sprites/creature_earth_02_battle.tres`.
