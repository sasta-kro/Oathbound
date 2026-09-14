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
and outlines alone. That is how one pack fills in for several elements.

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
]


def find_sheet(pack: str, suffixes: list[str]) -> Path | None:
    for suffix in suffixes:
        path = SOURCE_DIR / pack / pack / f"{pack}_{suffix}.png"
        if path.exists():
            return path
    return None


def recolor(image: Image.Image, palette: dict) -> Image.Image:
    image = image.convert("RGBA")
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            h, sat, val = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            offset = (h * 360.0 + 180.0) % 360.0 - 180.0
            if sat < MIN_SATURATION or not RED_BAND[0] <= offset <= RED_BAND[1]:
                continue
            hue = ((palette["hue"] + offset * HUE_SPREAD) % 360.0) / 360.0
            nr, ng, nb = colorsys.hsv_to_rgb(
                hue, min(1.0, sat * palette["saturation"]), min(1.0, val * palette["value"])
            )
            pixels[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
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
            if palette:
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

    tres = [f'[gd_resource type="SpriteFrames" format=3]', ""]
    tres.extend(ext_resources)
    tres.append("")
    tres.extend(sub_resources)
    tres.append("[resource]")
    tres.append(f"animations = [{', '.join(animations)}]")
    (SPRITES_DIR / f"{species_id}_battle.tres").write_text("\n".join(tres) + "\n")

    table = "\n".join(f"| `{name}` | {count} |" for name, count in rows)
    recolor_note = (
        f"Recoloured to the {palette} palette by the importer; the original pack is red.\n"
        if palette
        else ""
    )
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
