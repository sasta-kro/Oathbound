# Area tilesets

Source: `assets/tilesets/` (Cainos, *Pixel Art Top Down - Basic*), copied here
because Godot can only import files under the project root.

All sheets are 32x32 tiles.

| File | Sheet | Notes |
|---|---|---|
| `grass.png` | `TX Tileset Grass.png` | Rows 0-3 grass variants, rows 4-7 the stone-path edge pieces. |
| `wall.png` | `TX Tileset Wall.png` | Only the brick body (columns 1-4, rows 6-7) and the two narrow pieces are used. |
| `plant.png` | `Extra/TX Plant with Shadow.png` | Shadowed variant, so bushes and tufts need no separate shadow layer. |
| `props.png` | `Extra/TX Props with Shadow.png` | Same, for crates, pots, rocks and signposts. |

`area_one.tres` declares the atlas sources over these sheets. Regenerate it with:

```
godot --headless --path game --script res://scripts/dev/build_area_tileset.gd
```

`res://scripts/area_one_room.gd` paints the tiles.
