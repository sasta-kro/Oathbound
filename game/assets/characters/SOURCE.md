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
- `character_4.png` - the Elder, used by `res://content/sprites/npc_elder.tres`.
- `character_7.png` - the Merchant, used by
  `res://content/sprites/npc_merchant.tres`.
- `character_29.png` - the Child, used by `res://content/sprites/npc_child.tres`.
- `character_27.png` - the Scout, used by `res://content/sprites/npc_scout.tres`.
- Townsfolk added with the market and inn, each with a matching
  `res://content/sprites/npc_*.tres`: `character_21.png` (Innkeeper),
  `character_3.png` (Scribe), `character_19.png` (Apothecary),
  `character_9.png` (Gate guard), `character_12.png` (Villager),
  `character_10.png` (Farmer), `character_2.png` (Old man),
  `character_30.png` (Fisher), `character_18.png` (Bard),
  `character_28.png` (Kid).
