# Characters

Source: `assets/sprites/Characters` (superretroworld, *Character pack*,
https://gif-superretroworld.itch.io/character-pack).

Each sheet is the 32x32 frame variant, which lines up with the ARPG pack
animations. Layout is 3 columns x 4 rows of 32x32 cells:

| Row | Facing |
| --- | ------ |
| 0   | down   |
| 1   | left   |
| 2   | right  |
| 3   | up     |

Columns are `step, stand, step`, so a walk cycle is `0, 1, 2, 1` and the idle
pose is column 1.

- `character_13.png` - the player hero, used by
  `res://content/sprites/player_hero.tres`.
- `character_14.png` - the Knight NPC, used by
  `res://content/sprites/npc_knight.tres`.
