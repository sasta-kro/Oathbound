#!/usr/bin/env python3
"""Repack a free-form sprite sheet onto a 32 px grid for Godot's tile atlas.

The Cainos "with shadow" prop and plant sheets place sprites wherever they
fit, so slicing them on a 32 px grid cuts sprites in half. This script finds
each sprite by its alpha, gives it a whole-cell block, centers it in that
block and writes a new sheet plus a JSON manifest the tileset builder reads:

    [{"name": "prop_03", "cell": [x, y], "size": [w, h], "pixels": [w, h]}, ...]

Usage:
    python3 tools/pack_sprite_sheet.py props assets/tilesets/props.png game/assets/tilesets/props.png
    python3 tools/pack_sprite_sheet.py plant "assets/tilesets/plant.png" game/assets/tilesets/plant.png

The manifest lands next to the output as <name>.json.
"""

import json
import math
import sys
from pathlib import Path

from PIL import Image

CELL = 32
SHEET_WIDTH_CELLS = 16
# Pixels closer than this are one sprite, so a sprite and its soft shadow stay
# together.
MERGE_GAP = 2
# Anything smaller is sheet clutter (label text, stray pixels), not a sprite.
MIN_PIXELS = 8


def find_sprites(image: Image.Image):
    width, height = image.size
    alpha = image.getchannel("A").load()
    seen = [[False] * width for _ in range(height)]
    boxes = []
    for y in range(height):
        for x in range(width):
            if alpha[x, y] == 0 or seen[y][x]:
                continue
            stack = [(x, y)]
            seen[y][x] = True
            xs, ys = [], []
            while stack:
                cx, cy = stack.pop()
                xs.append(cx)
                ys.append(cy)
                for dy in range(-MERGE_GAP, MERGE_GAP + 1):
                    for dx in range(-MERGE_GAP, MERGE_GAP + 1):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < width and 0 <= ny < height and alpha[nx, ny] and not seen[ny][nx]:
                            seen[ny][nx] = True
                            stack.append((nx, ny))
            box = (min(xs), min(ys), max(xs) + 1, max(ys) + 1)
            if box[2] - box[0] >= MIN_PIXELS and box[3] - box[1] >= MIN_PIXELS:
                boxes.append(box)
    # Reading order of the source sheet keeps names stable between runs.
    boxes.sort(key=lambda b: (b[1] // CELL, b[0]))
    return boxes


def pack(prefix: str, source: Path, output: Path) -> None:
    image = Image.open(source).convert("RGBA")
    boxes = find_sprites(image)

    entries = []
    blocks = []
    for index, (x0, y0, x1, y1) in enumerate(boxes):
        w, h = x1 - x0, y1 - y0
        blocks.append(
            {
                "name": f"{prefix}_{index:02d}",
                "box": (x0, y0, x1, y1),
                "pixels": (w, h),
                "size": (math.ceil(w / CELL), math.ceil(h / CELL)),
            }
        )

    # Shelf packing, tallest first, so the sheet stays compact.
    blocks.sort(key=lambda b: (-b["size"][1], -b["size"][0]))
    cursor_x = cursor_y = shelf_height = 0
    for block in blocks:
        bw, bh = block["size"]
        if cursor_x + bw > SHEET_WIDTH_CELLS:
            cursor_x = 0
            cursor_y += shelf_height
            shelf_height = 0
        block["cell"] = (cursor_x, cursor_y)
        cursor_x += bw
        shelf_height = max(shelf_height, bh)
    sheet_height_cells = cursor_y + shelf_height

    sheet = Image.new("RGBA", (SHEET_WIDTH_CELLS * CELL, sheet_height_cells * CELL), (0, 0, 0, 0))
    for block in blocks:
        sprite = image.crop(block["box"])
        bw, bh = block["size"]
        pw, ph = block["pixels"]
        cx, cy = block["cell"]
        offset = (cx * CELL + (bw * CELL - pw) // 2, cy * CELL + (bh * CELL - ph) // 2)
        sheet.alpha_composite(sprite, offset)
        entries.append(
            {"name": block["name"], "cell": list(block["cell"]), "size": [bw, bh], "pixels": [pw, ph]}
        )

    entries.sort(key=lambda e: e["name"])
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output)
    output.with_suffix(".json").write_text(json.dumps(entries, indent=1) + "\n")
    print(f"{source} -> {output}: {len(entries)} sprites on a {SHEET_WIDTH_CELLS}x{sheet_height_cells} cell sheet")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    pack(sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3]))
