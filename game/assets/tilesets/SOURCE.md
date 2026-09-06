# Area tilesets

Source: `assets/tilesets/` (Cainos, *Pixel Art Top Down - Basic*), copied here
because Godot can only import files under the project root.

All sheets are 32x32 tiles.

| File | Sheet | Notes |
|---|---|---|
| `grass.png` | `TX Tileset Grass.png` | Rows 0-3 grass variants, rows 4-7 the stone-path edge pieces. |
| `wall.png` | `TX Tileset Wall.png` | Only the brick body (columns 1-4, rows 6-7) and the two narrow pieces are used. |
| `plant.png` | `Extra/TX Plant with Shadow.png` | Repacked onto the grid, see below. Shadowed variant, so bushes and tufts need no separate shadow layer. |
| `props.png` | `Extra/TX Props with Shadow.png` | Repacked onto the grid. Crates, pots, rocks, signposts, statues. |

The original prop and plant sheets place sprites freely, so a 32 px grid cut
them apart. `tools/pack_sprite_sheet.py` rebuilds `plant.png` / `props.png`
with every sprite centered in its own whole-cell block and writes
`plant.json` / `props.json` (name, atlas cell, size in cells). Regenerate
from the repository root:

```
python3 tools/pack_sprite_sheet.py prop "assets/tilesets/Extra/TX Props with Shadow.png" game/assets/tilesets/props.png
python3 tools/pack_sprite_sheet.py plant "assets/tilesets/Extra/TX Plant with Shadow.png" game/assets/tilesets/plant.png
```

`area_one.tres` declares the atlas sources over these sheets. Regenerate it with:

```
godot --headless --path game --script res://scripts/dev/build_area_tileset.gd
```

`res://scripts/area_one_room.gd` paints the tiles.
