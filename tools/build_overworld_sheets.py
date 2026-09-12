#!/usr/bin/env python3
"""Prepare the Fan-tasy and Undead art for the overworld tileset.

Both packs are drawn on a 16 px grid while the Cainos sheets already in
`game/assets/tilesets/` are 32 px. The art is kept at its own pixel size so
everything shares one pixel density on screen: the terrain sheets stay 16 px
tiles for their own TileSet (drawn as 24 px sub-cells, two per map cell), and
the free-form objects are packed onto the 32 px grid of the Cainos TileSet.

What this writes into `game/assets/tilesets/`:

  ft_ground.png / .json   Grass and dirt terrain, Tiled wang bits per tile.
  ft_road.png / .json     Dirt road terrain.
  ft_water.png / .json    Animated water with a sand shore (4 frames).
  ft_buildings.png/.json  Houses, well and gate, each split into a roof half
                          drawn over the player and a wall half that blocks.
  ft_nature.png / .json   Trees (split the same way), bushes, rocks.
  ft_props.png / .json    Market and street dressing, campfire frames.
  ruins.png / .json       Ruined pillars, dead trees, graves, bones.

Every object manifest is a JSON array of
  {"name", "cell": [x, y], "size": [w, h], "pixels": [w, h], "kind", ...}
where `kind` is one of
  solid     blocks over its whole footprint
  prop      blocks over the middle of its footprint (walkable edges)
  walkable  never blocks
  overhead  drawn above the player, never blocks
and an optional "collision" list of [x, y, w, h] cell rectangles overrides
the footprint used for blocking.

Run from the repository root:
    python3 tools/build_overworld_sheets.py
"""

from __future__ import annotations

import json
import math
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
FANTASY = ROOT / "assets/tilesets/The Fan-tasy Tileset (Free)"
FANTASY_ART = FANTASY / "Art"
FANTASY_TILED = FANTASY / "Tiled/Tilesets"
UNDEAD = ROOT / "assets/tilesets/Free-Undead-Tileset-Top-Down-Pixel-Art/PNG"
OUTPUT = ROOT / "game/assets/tilesets"

## Grid the object sheets are packed on: the Cainos tile size.
CELL = 32
SHEET_WIDTH_CELLS = 16

# Water frames sit side by side in the sheet, six columns apart.
WATER_FRAME_COLUMNS = 6
WATER_FRAMES = 4
WATER_FRAME_SECONDS = 0.3

# Sprites whose collision box is the full footprint, or a narrow strip.
TRUNK_COLLISION = "trunk"


# ---------------------------------------------------------------------------
# Terrain sheets: Tiled wang sets become Godot peering bits.
# ---------------------------------------------------------------------------


def convert_terrain(tsx_name: str, png: Path, out_name: str, animated: bool = False) -> None:
    tree = ET.parse(FANTASY_TILED / tsx_name)
    tileset = tree.getroot()
    columns = int(tileset.get("columns"))
    probabilities: dict[int, float] = {}
    for tile in tileset.findall("tile"):
        if tile.get("probability") is not None:
            probabilities[int(tile.get("id"))] = float(tile.get("probability"))

    colors: list[str] = []
    tiles = []
    for wangset in tileset.iter("wangset"):
        colors = [color.get("name") for color in wangset.findall("wangcolor")]
        for wangtile in wangset.findall("wangtile"):
            tile_id = int(wangtile.get("tileid"))
            column, row = tile_id % columns, tile_id // columns
            if animated and column >= WATER_FRAME_COLUMNS:
                continue
            wang = [int(value) for value in wangtile.get("wangid").split(",")]
            entry = {"cell": [column, row], "wang": wang}
            if tile_id in probabilities:
                entry["probability"] = probabilities[tile_id]
            tiles.append(entry)

    manifest = {"colors": colors, "tiles": tiles}
    if animated:
        manifest["animation"] = {
            "frames": WATER_FRAMES,
            "separation": WATER_FRAME_COLUMNS - 1,
            "seconds": WATER_FRAME_SECONDS,
        }
    Image.open(png).convert("RGBA").save(OUTPUT / f"{out_name}.png")
    (OUTPUT / f"{out_name}.json").write_text(json.dumps(manifest, indent=1) + "\n")
    print(f"{out_name}: {len(tiles)} terrain tiles, colours {colors}")


# ---------------------------------------------------------------------------
# Object sheets: free-form sprites packed onto the grid.
# ---------------------------------------------------------------------------


class Sprite:
    def __init__(self, name: str, image: Image.Image, kind: str, **extra):
        self.name = name
        self.image = image
        self.kind = kind
        self.extra = extra
        self.size = (math.ceil(image.width / CELL), math.ceil(image.height / CELL))
        self.cell = (0, 0)


def load_fantasy(relative: str) -> Image.Image:
    return Image.open(FANTASY_ART / relative).convert("RGBA")


def split_sprite(name: str, image: Image.Image, base_cells: int, base_kind: str, **base_extra) -> list[Sprite]:
    """Top part drawn over the player, bottom `base_cells` rows blocking.

    The base is cut to whole cells from the bottom so the two halves meet
    exactly when painted one above the other; the roof half is bottom-aligned
    in its own block, so any slack ends up as transparent rows above it.
    """
    split_row = image.height - base_cells * CELL
    if split_row <= 0:
        raise ValueError(f"{name}: base of {base_cells} cells is taller than the sprite")
    top = image.crop((0, 0, image.width, split_row))
    base = image.crop((0, split_row, image.width, image.height))
    return [
        Sprite(f"{name}_top", top, "overhead"),
        Sprite(f"{name}_base", base, base_kind, **base_extra),
    ]


def buildings() -> list[Sprite]:
    sprites: list[Sprite] = []
    # Wall rows counted from the bottom, read off the art. Generous is safe:
    # a roof row kept in the base is simply one the player cannot walk behind.
    for name, file, base_cells in [
        ("house_hay_1", "Buildings/House_Hay_1.png", 2),
        ("house_hay_2", "Buildings/House_Hay_2.png", 2),
        ("house_hay_3", "Buildings/House_Hay_3.png", 3),
        ("house_hay_4", "Buildings/House_Hay_4_Purple.png", 3),
        ("well", "Buildings/Well_Hay_1.png", 2),
    ]:
        sprites += split_sprite(name, load_fantasy(file), base_cells, "solid")
    # The 80 px arch sits centered in three cells; only its two pillars
    # block, so the road runs through the middle.
    sprites += split_sprite(
        "gate",
        load_fantasy("Buildings/CityWall_Gate_1.png"),
        2,
        "solid",
        collision=[[0.25, 0, 0.5, 2], [2.25, 0, 0.5, 2]],
    )
    return sprites


def nature() -> list[Sprite]:
    sprites: list[Sprite] = []
    for index, base_cells in [(1, 1), (2, 1), (3, 1), (4, 1)]:
        sprites += split_sprite(
            f"tree_{index}",
            load_fantasy(f"Trees and Bushes/Tree_Emerald_{index}.png"),
            base_cells,
            "solid",
            collision=TRUNK_COLLISION,
        )
    for index in range(1, 8):
        sprites.append(Sprite(f"bush_{index}", load_fantasy(f"Trees and Bushes/Bush_Emerald_{index}.png"), "prop"))
    for index in [1, 2, 4, 6, 9]:
        sprites.append(Sprite(f"rock_{index}", load_fantasy(f"Rocks/Rock_Brown_{index}.png"), "prop"))
    flowers_red = load_fantasy("Props/Animation/Flowers_Red.png")
    flowers_white = load_fantasy("Props/Animation/Flowers_White.png")
    for index in range(2):
        box = (index * 32, 0, index * 32 + 32, 32)
        sprites.append(Sprite(f"flowers_red_{index + 1}", flowers_red.crop(box), "walkable"))
        sprites.append(Sprite(f"flowers_white_{index + 1}", flowers_white.crop(box), "walkable"))
    return sprites


def props() -> list[Sprite]:
    sprites: list[Sprite] = []
    for name, file, kind in [
        ("banner", "Props/Banner_Stick_1_Purple.png", "prop"),
        ("barrel", "Props/Barrel_Small_Empty.png", "prop"),
        ("basket", "Props/Basket_Empty.png", "walkable"),
        ("bench_long", "Props/Bench_1.png", "prop"),
        ("bench_short", "Props/Bench_3.png", "walkable"),
        ("bulletin_board", "Props/BulletinBoard_1.png", "prop"),
        ("stump", "Props/Chopped_Tree_1.png", "prop"),
        ("crate_large", "Props/Crate_Large_Empty.png", "prop"),
        ("crate_medium", "Props/Crate_Medium_Closed.png", "prop"),
        ("water_trough", "Props/Crate_Water_1.png", "prop"),
        ("fireplace", "Props/Fireplace_1.png", "prop"),
        ("haystack", "Props/HayStack_2.png", "prop"),
        ("lamp_post", "Props/LampPost_3.png", "prop"),
        ("potted_plant", "Props/Plant_2.png", "walkable"),
        ("sack", "Props/Sack_3.png", "walkable"),
        ("sign_1", "Props/Sign_1.png", "prop"),
        ("sign_2", "Props/Sign_2.png", "prop"),
        ("table", "Props/Table_Medium_1.png", "prop"),
    ]:
        sprites.append(Sprite(name, load_fantasy(file), kind))
    campfire = load_fantasy("Props/Animation/Animation_Campfire.png")
    frames = campfire.width // 32
    sprites.append(
        Sprite(
            "campfire",
            campfire,
            "prop",
            animation={"frames": frames, "seconds": 0.12, "frame_pixels": [32, 32]},
        )
    )
    return sprites


# Pixel boxes inside the Undead `Objects.png` sheet, chosen by eye from the
# sprite boxes `pack_sprite_sheet.find_sprites` reports for it.
UNDEAD_BOXES = {
    "ruin_pillars": ((80, 128, 160, 223), "prop"),
    "ruin_arch": ((0, 305, 80, 367), "prop"),
    "ruin_rubble": ((245, 307, 300, 361), "prop"),
    "dead_tree": ((305, 131, 368, 220), "prop"),
    "gnarled_tree": ((3, 229, 62, 303), "prop"),
    "dead_shrub": ((533, 228, 592, 297), "prop"),
    "dead_tree_thin": ((502, 304, 551, 367), "prop"),
    "boulder_pale": ((2, 373, 59, 429), "prop"),
    "skull_pile": ((199, 375, 270, 426), "prop"),
    "dry_bramble": ((432, 372, 496, 430), "walkable"),
    "skull_maw": ((633, 376, 664, 423), "prop"),
    "ghost_grass": ((193, 438, 239, 488), "walkable"),
    "skull_small": ((339, 469, 365, 491), "walkable"),
    "rocks_pale": ((2, 498, 47, 542), "prop"),
    "rock_pale": ((54, 505, 88, 538), "prop"),
    "dark_rubble": ((289, 497, 336, 543), "prop"),
    "crystal_shard": ((580, 500, 619, 536), "prop"),
    "bone_long": ((104, 550, 136, 584), "walkable"),
    "dead_stump": ((212, 593, 253, 624), "prop"),
    "graves_row": ((96, 630, 192, 649), "prop"),
    "grave_pair": ((193, 630, 238, 649), "prop"),
    "tombstone_1": ((294, 660, 315, 683), "prop"),
    "tombstone_2": ((324, 660, 348, 683), "prop"),
    "tombstone_3": ((359, 660, 376, 684), "prop"),
    "graves_cluster": ((672, 662, 720, 683), "prop"),
}


def ruins() -> list[Sprite]:
    sheet = Image.open(UNDEAD / "Objects.png").convert("RGBA")
    return [Sprite(name, sheet.crop(box), kind) for name, (box, kind) in UNDEAD_BOXES.items()]


def pack(name: str, sprites: list[Sprite]) -> None:
    # Shelf packing, tallest first, so the sheet stays compact.
    order = sorted(sprites, key=lambda s: (-s.size[1], -s.size[0]))
    cursor_x = cursor_y = shelf_height = 0
    for sprite in order:
        width, height = sprite.size
        if cursor_x + width > SHEET_WIDTH_CELLS:
            cursor_x = 0
            cursor_y += shelf_height
            shelf_height = 0
        sprite.cell = (cursor_x, cursor_y)
        cursor_x += width
        shelf_height = max(shelf_height, height)
    sheet_height_cells = cursor_y + shelf_height

    sheet = Image.new("RGBA", (SHEET_WIDTH_CELLS * CELL, sheet_height_cells * CELL), (0, 0, 0, 0))
    entries = []
    for sprite in sprites:
        image = sprite.image
        width, height = sprite.size
        cell_x, cell_y = sprite.cell
        animation = sprite.extra.get("animation")
        if animation:
            # Frames stay side by side on the sheet, each in its own block.
            frame_w, frame_h = animation["frame_pixels"]
            frame_cells = (math.ceil(frame_w / CELL), math.ceil(frame_h / CELL))
            for index in range(animation["frames"]):
                frame = image.crop((index * frame_w, 0, (index + 1) * frame_w, frame_h))
                offset = (
                    (cell_x + index * frame_cells[0]) * CELL,
                    cell_y * CELL,
                )
                sheet.alpha_composite(frame, offset)
            entry_size = list(frame_cells)
            entry_pixels = [frame_w, frame_h]
        else:
            offset = (
                cell_x * CELL + (width * CELL - image.width) // 2,
                # Bottom-aligned so a base half meets its roof half without a gap
                # and a sprite's feet sit on the cell row it is painted on.
                cell_y * CELL + (height * CELL - image.height),
            )
            sheet.alpha_composite(image, offset)
            entry_size = list(sprite.size)
            entry_pixels = [image.width, image.height]
        entry = {
            "name": sprite.name,
            "cell": list(sprite.cell),
            "size": entry_size,
            "pixels": entry_pixels,
            "kind": sprite.kind,
        }
        entry.update(sprite.extra)
        entries.append(entry)

    entries.sort(key=lambda e: e["name"])
    sheet.save(OUTPUT / f"{name}.png")
    (OUTPUT / f"{name}.json").write_text(json.dumps(entries, indent=1) + "\n")
    print(f"{name}: {len(entries)} sprites on a {SHEET_WIDTH_CELLS}x{sheet_height_cells} cell sheet")


def main() -> int:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    convert_terrain("Tileset_Ground.tsx", FANTASY_ART / "Ground Tileset/Tileset_Ground.png", "ft_ground")
    convert_terrain("Tilesets_Road.tsx", FANTASY_ART / "Ground Tileset/Tileset_Road.png", "ft_road")
    convert_terrain(
        "Tileset_Water.tsx", FANTASY_ART / "Water and Sand/Tileset_Water.png", "ft_water", animated=True
    )
    pack("ft_buildings", buildings())
    pack("ft_nature", nature())
    pack("ft_props", props())
    pack("ruins", ruins())
    return 0


if __name__ == "__main__":
    sys.exit(main())
