#!/usr/bin/env python3
"""Re-pad the golem sheets onto square frames for Godot.

The source frames are 90x64 with the golem standing on the bottom edge, so its
body centre lands 13 px below the frame centre. CreatureVisual draws creature
art centred on the node, so an off-centre body makes the creature sit low in
the world and in battle. Padding the bottom out to a 90x90 frame puts the body
back in the middle without touching a single pixel of the art.

Usage:
    python3 tools/pack_golem_frames.py assets/sprites/monster/golem_blue \
        game/assets/creatures/golem_blue
"""

import sys
from pathlib import Path

from PIL import Image

FRAME_WIDTH = 90
FRAME_HEIGHT = 90

# Output name -> source file. The names match CreatureVisual's animation states.
SHEETS = {
    "idle": "Golem_1_idle.png",
    "walk": "Golem_1_walk.png",
    "attack_01": "Golem_1_attack.png",
    "hurt": "Golem_1_hurt.png",
    "death": "Golem_1_die.png",
}


def repack(source_dir: Path, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for name, source in SHEETS.items():
        image = Image.open(source_dir / source).convert("RGBA")
        if image.width % FRAME_WIDTH != 0:
            raise SystemExit(f"{source} is {image.width} px wide, not a whole number of frames.")
        if image.height > FRAME_HEIGHT:
            raise SystemExit(f"{source} is {image.height} px tall, taller than the target frame.")
        padded = Image.new("RGBA", (image.width, FRAME_HEIGHT), (0, 0, 0, 0))
        padded.paste(image, (0, 0))
        padded.save(output_dir / f"{name}.png")
        print(f"{name}: {image.width // FRAME_WIDTH} frames -> {output_dir / f'{name}.png'}")


def main(argv: list[str]) -> None:
    if len(argv) != 3:
        raise SystemExit(__doc__)
    repack(Path(argv[1]), Path(argv[2]))


if __name__ == "__main__":
    main(sys.argv)
