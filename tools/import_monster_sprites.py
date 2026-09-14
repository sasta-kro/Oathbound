#!/usr/bin/env python3
"""Copy the monster sprite drops into the game and build their SpriteFrames.

The monster packs under `assets/sprites/monster/<Name>/<Name>/` are horizontal
strips of 100x100 frames, one file per animation. Godot can only import files
under `game/`, so each sheet is copied to `game/assets/creatures/<folder>/`
with the names `CreatureVisual` expects, a `SOURCE.md` is written next to
them, and `game/content/sprites/<species id>_battle.tres` is generated.

Flying monsters have no idle or walk strip; their flying loop stands in for
both.

A monster can also be imported in an element palette instead of its own: the
red and orange pixels of every sheet are rotated towards the element's hue
(blue for Water, green for Wind, brown for Earth), leaving dark armour, bone
and outlines alone. That is how one pack fills in for several elements. The
`druid` variant is a hand-tuned recolour with leaves added, see `druid()`.

Usage, from the repository root:
    python3 tools/import_monster_sprites.py

Re-running overwrites the copied sheets and the generated SpriteFrames. Run
`Godot --headless --path game --import` afterwards so the PNGs get imported.
"""

import colorsys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIR = ROOT / "assets" / "sprites" / "monster"
CREATURE_DIR = ROOT / "game" / "assets" / "creatures"
SPRITES_DIR = ROOT / "game" / "content" / "sprites"
FRAME = 100

# Animation name, copied file name, sheet suffixes, loops, frames per second. The first suffix
# that exists wins, which is how flying monsters get an idle and a walk.
ANIMATIONS = [
    ("attack", "attack_01.png", ["Attack01"], False, 18.0),
    ("attack_heavy", "attack_02.png", ["Attack02"], False, 18.0),
    ("death", "death.png", ["Death"], False, 6.0),
    ("hurt", "hurt.png", ["Hurt"], False, 12.0),
    ("idle", "idle.png", ["Idle", "Flying"], True, 8.0),
    ("walk", "walk.png", ["Walk", "Flying"], True, 10.0),
]

# Element palettes: the hue red becomes, in degrees, and how saturation and
# brightness scale. Only pixels that are saturated and within the red-orange
# band are touched; the band's spread is kept, compressed, so shading survives.
PALETTES = {
    "water": {"hue": 210.0, "saturation": 1.0, "value": 1.05},
    "wind": {"hue": 150.0, "saturation": 1.0, "value": 1.05},
    "earth": {"hue": 35.0, "saturation": 0.85, "value": 0.9},
}
RED_BAND = (-40.0, 60.0)
MIN_SATURATION = 0.18
HUE_SPREAD = 0.35

# The druid variant of Blood Monster_A is hand-tuned rather than hue-rotated:
# its eight body colours map to moss and bark, the bone ribs on its head turn
# to bark (the attack slash, the same grey, stays white), a leaf tuft with twig
# antlers is drawn on top of the head in every frame, and anything left red,
# the hurt splatter, is rotated to sap green.
DRUID_BODY = {
    (162, 43, 75): (96, 118, 52),
    (110, 20, 56): (66, 84, 38),
    (49, 19, 57): (74, 52, 34),
    (207, 69, 84): (140, 166, 72),
    (31, 26, 26): (40, 30, 22),
}
DRUID_RIBS = {(217, 216, 216): (176, 140, 92), (192, 191, 191): (132, 100, 64)}
# The head's dark colour; its box anchors the tuft and bounds the rib recolour.
DRUID_HEAD = (49, 19, 57)
DRUID_SAP = {"hue": 95.0, "saturation": 0.8, "value": 0.9}
LEAF_LIGHT = (96, 160, 56)
LEAF_MID = (58, 112, 42)
LEAF_DARK = (40, 78, 34)
TWIG = (74, 52, 34)
OUTLINE = (0, 0, 0)
# (dx, dy) from the head's top centre, one pixel above the head.
DRUID_TUFT = {
    (-1, -1): LEAF_MID, (0, -1): LEAF_LIGHT, (1, -1): LEAF_MID,
    (-2, -2): LEAF_MID, (-1, -2): LEAF_LIGHT, (0, -2): LEAF_LIGHT, (1, -2): LEAF_MID, (2, -2): LEAF_DARK,
    (-2, -3): LEAF_DARK, (-1, -3): LEAF_LIGHT, (0, -3): LEAF_MID, (1, -3): LEAF_LIGHT, (2, -3): LEAF_DARK,
    (-1, -4): LEAF_MID, (0, -4): LEAF_LIGHT, (1, -4): LEAF_MID,
    (-3, -1): TWIG, (-4, -2): TWIG, (-5, -3): LEAF_LIGHT,
    (3, -1): TWIG, (4, -2): TWIG, (5, -3): LEAF_LIGHT,
}

# (sprite pack, palette or None, species id). The asset folder is the pack
# name in snake case, with the palette appended for a recolour.
MONSTERS = [
    ("Black Knight_A", None, "creature_earth_03"),
    ("Black Knight_B", None, "creature_earth_04"),
    ("Black Knight_C", None, "creature_earth_05"),
    ("Minotaur", None, "creature_earth_06"),
    ("Demon_E", None, "creature_fire_02"),
    ("Lava Slime", None, "creature_fire_03"),
    ("Flame Golem", None, "creature_fire_04"),
    ("Hellhound", None, "creature_fire_05"),
    ("Ghostfire", None, "creature_fire_06"),
    ("Demon_D", None, "creature_fire_07"),
    ("Lava Slime", "water", "creature_water_01"),
    ("Blood Monster_B", "water", "creature_water_02"),
    ("Demoness_B", "water", "creature_water_03"),
    ("Demoness_A", "water", "creature_water_04"),
    ("Hellhound", "water", "creature_water_05"),
    ("Ghostfire", "water", "creature_water_06"),
    ("Flame Golem", "water", "creature_water_07"),
    ("Hellbat", "wind", "creature_wind_01"),
    ("Hellbat", None, "creature_wind_02"),
    ("Demon_B", None, "creature_wind_03"),
    ("Demon_C", None, "creature_wind_04"),
    ("Eyeball Monster", None, "creature_wind_05"),
    ("Warlock", "wind", "creature_wind_06"),
    ("Blood Monster_A", "druid", "creature_earth_01"),
]


def find_sheet(pack: str, suffixes: list[str]) -> Path | None:
    for suffix in suffixes:
        path = SOURCE_DIR / pack / pack / f"{pack}_{suffix}.png"
        if path.exists():
            return path
    return None


def shift_red(rgb: tuple[int, int, int], palette: dict) -> tuple[int, int, int]:
    r, g, b = rgb
    h, sat, val = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    offset = (h * 360.0 + 180.0) % 360.0 - 180.0
    if sat < MIN_SATURATION or not RED_BAND[0] <= offset <= RED_BAND[1]:
        return rgb
    hue = ((palette["hue"] + offset * HUE_SPREAD) % 360.0) / 360.0
    nr, ng, nb = colorsys.hsv_to_rgb(hue, min(1.0, sat * palette["saturation"]), min(1.0, val * palette["value"]))
    return (round(nr * 255), round(ng * 255), round(nb * 255))


def recolor(image: Image.Image, palette: dict) -> Image.Image:
    image = image.convert("RGBA")
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if a:
                pixels[x, y] = shift_red((r, g, b), palette) + (a,)
    return image


def druid(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    pixels = image.load()
    head = None
    for left in range(0, image.width, FRAME):
        dark = [
            (x, y)
            for x in range(left, left + FRAME)
            for y in range(image.height)
            if pixels[x, y][3] and pixels[x, y][:3] == DRUID_HEAD
        ]
        # A frame hidden by the hurt flash keeps the previous frame's head.
        if dark:
            head = (
                min(x for x, _ in dark) - left,
                max(x for x, _ in dark) - left,
                min(y for _, y in dark),
                max(y for _, y in dark),
            )
        if head is None:
            raise SystemExit("Blood Monster_A: first frame has no head colour to anchor the tuft")
        x0, x1, y0, y1 = head
        for x in range(left, left + FRAME):
            for y in range(image.height):
                r, g, b, a = pixels[x, y]
                if not a:
                    continue
                if (r, g, b) in DRUID_BODY:
                    pixels[x, y] = DRUID_BODY[(r, g, b)] + (a,)
                elif (r, g, b) in DRUID_RIBS and x0 - 1 <= x - left <= x1 + 1 and y0 - 1 <= y <= y1 + 1:
                    pixels[x, y] = DRUID_RIBS[(r, g, b)] + (a,)
                else:
                    pixels[x, y] = shift_red((r, g, b), DRUID_SAP) + (a,)
        centre = left + (x0 + x1) // 2
        tuft = {(centre + dx, y0 - 1 + dy): colour for (dx, dy), colour in DRUID_TUFT.items()}
        for x, y in tuft:
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if (nx, ny) not in tuft and pixels[nx, ny][3] == 0:
                    pixels[nx, ny] = OUTLINE + (255,)
        for point, colour in tuft.items():
            pixels[point] = colour + (255,)
    return image


def asset_folder(pack: str, palette: str | None) -> str:
    folder = pack.lower().replace(" ", "_")
    return f"{folder}_{palette}" if palette else folder


def import_monster(pack: str, palette: str | None, species_id: str) -> None:
    folder = asset_folder(pack, palette)
    target = CREATURE_DIR / folder
    target.mkdir(parents=True, exist_ok=True)
    ext_ids: dict[str, str] = {}
    ext_resources = []
    rows = []
    sub_resources = []
    animations = []
    for anim, file_name, suffixes, loops, fps in ANIMATIONS:
        sheet = find_sheet(pack, suffixes)
        if sheet is None:
            raise SystemExit(f"{pack}: no sheet for {anim} ({', '.join(suffixes)})")
        if not sheet.stem.endswith(suffixes[0]):
            # A stand-in strip, such as flying for idle and walk, is copied
            # once under its own name and shared.
            file_name = f"{sheet.stem.rsplit('_', 1)[1].lower()}.png"
        width, height = Image.open(sheet).size
        if height != FRAME or width % FRAME != 0:
            raise SystemExit(f"{sheet} is {width}x{height}, not a strip of {FRAME}px frames")
        count = width // FRAME
        if file_name not in ext_ids:
            image = Image.open(sheet)
            if palette == "druid":
                image = druid(image)
            elif palette:
                image = recolor(image, PALETTES[palette])
            image.save(target / file_name)
            ext_ids[file_name] = f"{len(ext_ids) + 1}_{Path(file_name).stem}"
            ext_resources.append(
                f'[ext_resource type="Texture2D" path="res://assets/creatures/{folder}/{file_name}" id="{ext_ids[file_name]}"]'
            )
            rows.append((file_name, count))
        frames = []
        for index in range(count):
            sub_id = f"{anim}_{index}"
            sub_resources.append(
                f'[sub_resource type="AtlasTexture" id="{sub_id}"]\n'
                f'atlas = ExtResource("{ext_ids[file_name]}")\n'
                f"region = Rect2({index * FRAME}, 0, {FRAME}, {FRAME})\n"
            )
            frames.append(f'{{\n"duration": 1.0,\n"texture": SubResource("{sub_id}")\n}}')
        animations.append(
            "{\n"
            f'"frames": [{", ".join(frames)}],\n'
            f'"loop": {"true" if loops else "false"},\n'
            f'"name": &"{anim}",\n'
            f'"speed": {fps}\n'
            "}"
        )

    output = SPRITES_DIR / f"{species_id}_battle.tres"
    # Keep a uid the editor already gave the file, so species referring to it by uid still resolve.
    uid = ""
    if output.exists():
        header = output.read_text().split("\n", 1)[0]
        if ' uid="' in header:
            uid = " uid=" + header.split(' uid=', 1)[1].split(" ", 1)[0].rstrip("]")
    tres = [f'[gd_resource type="SpriteFrames" format=3{uid}]', ""]
    tres.extend(ext_resources)
    tres.append("")
    tres.extend(sub_resources)
    tres.append("[resource]")
    tres.append(f"animations = [{', '.join(animations)}]")
    output.write_text("\n".join(tres) + "\n")

    table = "\n".join(f"| `{name}` | {count} |" for name, count in rows)
    if palette == "druid":
        recolor_note = "Recoloured to moss and bark, with a leaf tuft drawn on the head, by the importer.\n"
    elif palette:
        recolor_note = f"Recoloured to the {palette} palette by the importer; the original pack is red.\n"
    else:
        recolor_note = ""
    (target / "SOURCE.md").write_text(
        f"# {pack}{f' ({palette})' if palette else ''}\n\n"
        f"Source: `assets/sprites/monster/{pack}`, copied here because Godot can only\n"
        "import files under the project root. Pack name and licence are not recorded in\n"
        "the drop; fill them in before release.\n\n"
        "Sheets are horizontal strips of 100x100 frames, no shadow variant. The art faces right.\n"
        "Generated by `tools/import_monster_sprites.py`.\n"
        f"{recolor_note}\n"
        "| File | Frames |\n|---|---:|\n"
        f"{table}\n\n"
        f"Used by `res://content/sprites/{species_id}_battle.tres`.\n"
    )
    print(f"{pack:18} -> {folder:24} {species_id}")


def main() -> None:
    for pack, palette, species_id in MONSTERS:
        import_monster(pack, palette, species_id)


if __name__ == "__main__":
    main()
