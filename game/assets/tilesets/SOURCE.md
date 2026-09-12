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

## Fan-tasy and Undead sheets

Source: `assets/tilesets/The Fan-tasy Tileset (Free)/` and
`assets/tilesets/Free-Undead-Tileset-Top-Down-Pixel-Art/`, both 16 px art.
`tools/build_overworld_sheets.py` writes these, keeping the pixels as they are:

| File | Contents |
|---|---|
| `ft_ground.png` / `.json` | Meadow grass and dirt terrain; the JSON carries the Tiled wang bits per tile. |
| `ft_road.png` / `.json` | Dirt road terrain. |
| `ft_water.png` / `.json` | Water with a sand shore, four animation frames six columns apart. |
| `ft_buildings.png` / `.json` | Houses, well and gate, packed on the 32 px grid. Each is split into a `_top` (drawn over the player) and a `_base` (blocks). |
| `ft_nature.png` / `.json` | Trees (split the same way), bushes, rocks, flower patches. |
| `ft_props.png` / `.json` | Market and street props; the campfire's eight frames side by side. |
| `ruins.png` / `.json` | Pieces cut from the Undead `Objects.png`: pillars, arch, graves, dead trees, bones. |

The object manifests list `name`, atlas `cell`, `size` in cells and a `kind`
(`solid`, `prop`, `walkable`, `overhead`) that the tileset builder turns into
collision. Regenerate from the repository root:

```
python3 tools/build_overworld_sheets.py
```

## Tilesets

`overworld.tres` (32 px tiles) declares the Cainos sources and the packed
object sheets; `meadow.tres` (16 px tiles) declares the three terrain sheets.
Regenerate both with:

```
godot --headless --path game --script res://scripts/dev/build_overworld_tileset.gd
```

`scripts/dev/overworld_tiles.gd` lists the source and terrain ids.
