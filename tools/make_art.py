#!/usr/bin/env python3
"""Draws GemScout's original pixel art and writes the PNGs the game uses.

Every sprite is a text grid below: one character per pixel, looked up in
PALETTE. Change a grid (or a colour) and run this again:

    python3 tools/make_art.py

It writes:
  assets/sprites/hero.png   16x24 frames: idle, run x4, jump, fall
  assets/sprites/gems.png   12x12 frames: one per gem colour
  assets/sprites/door.png   24x32 frames: locked, open
  assets/icons/icon_*.png   app icons (web install, Godot)
  icon.png                  the Godot project icon
Needs Pillow (pip install pillow).
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent

PALETTE = {
    ".": None,
    "K": (26, 20, 32),  # outline
    "H": (242, 194, 48),  # helmet
    "h": (184, 134, 27),  # helmet shade
    "L": (255, 246, 176),  # head lamp
    "S": (240, 180, 138),  # skin
    "s": (196, 126, 90),  # skin shade
    "W": (255, 255, 255),  # eye white
    "E": (26, 20, 32),  # eye
    "J": (47, 163, 154),  # jacket
    "j": (29, 111, 105),  # jacket shade
    "G": (217, 164, 65),  # belt
    "P": (107, 74, 47),  # trousers
    "p": (74, 50, 31),  # trousers shade
    "B": (58, 42, 34),  # boots
}

# The scout's head and body (rows 0-15), shared by every frame. Faces right.
HERO_TOP = [
    "................",
    ".....KKKKKK.....",
    "....KHHHHHHKK...",
    "...KHHHHHHHHLK..",
    "...KhhhhhhhhhK..",
    "..KKKKKKKKKKKK..",
    "....KSSSSSWEK...",
    "....KSSSSSSSK...",
    "....KsSSSSSsK...",
    ".....KKssssK....",
    "....KJJJJJJJK...",
    "...KJJJJJJJJJK..",
    "...KJjJJJJJjJK..",
    "...KJjJJJJJjJK..",
    "...KSKJJJJJKSK..",
    "....KKGGGGGKK...",
]

# Legs (rows 16-23), one set per pose.
LEGS = {
    "stand": [
        "....KPPPPPPK....",
        "....KPPPPPPK....",
        "....KPPKKPPK....",
        "....KPPKKPPK....",
        "....KPPKKPPK....",
        "....KBBKKBBK....",
        "...KBBBKKBBBK...",
        "...KKKKKKKKKK...",
    ],
    "stride": [
        "....KPPPPPPK....",
        "...KPPPPPPPPK...",
        "..KPPKK..KPPK...",
        ".KPPK.....KPPK..",
        ".KBBK.....KPPK..",
        "KBBK.......KBBK.",
        "KKK........KBBBK",
        "............KKKK",
    ],
    "pass": [
        "....KPPPPPPK....",
        "....KPPPPPPK....",
        "....KPPKPPK.....",
        ".....KPPPPK.....",
        ".....KPPBBK.....",
        ".....KBBBBK.....",
        "....KBBBBBK.....",
        "....KKKKKKK.....",
    ],
    "tuck": [
        "....KPPPPPPK....",
        "...KPPPPPPPPK...",
        "...KPPKKKKPPK...",
        "..KBBK....KBBK..",
        "..KBBK....KBBK..",
        "..KKKK....KKKK..",
        "................",
        "................",
    ],
    "dangle": [
        "....KPPPPPPK....",
        "....KPPPPPPK....",
        "...KPPK..KPPK...",
        "...KPPK..KPPK...",
        "..KPPK....KPPK..",
        "..KBBK....KBBK..",
        ".KBBBK....KBBBK.",
        ".KKKKK....KKKKK.",
    ],
}


def mirror(rows):
    return [r[::-1] for r in rows]


# Frame order matters: scripts/game/hero.gd uses these indexes.
HERO_FRAMES = [
    HERO_TOP + LEGS["stand"],  # 0 idle
    HERO_TOP + LEGS["stride"],  # 1 run
    HERO_TOP + LEGS["pass"],  # 2 run
    HERO_TOP + mirror(LEGS["stride"]),  # 3 run
    HERO_TOP + mirror(LEGS["pass"]),  # 4 run
    HERO_TOP + LEGS["tuck"],  # 5 jump (going up)
    HERO_TOP + LEGS["dangle"],  # 6 fall
]

GEM = [
    "............",
    "...KKKKKK...",
    "..KWLLCCDK..",
    ".KWLCCCCDDK.",
    "KLLCCCCCCDDK",
    "KCCCCCCCCDDK",
    ".KCCCCCCDDK.",
    "..KCCCCCDK..",
    "...KCCCDK...",
    "....KCDK....",
    ".....KK.....",
    "............",
]

# Gem colours: (light, base, dark). Order = gem frame index.
GEM_COLOURS = [
    ((255, 150, 160), (230, 40, 70), (140, 16, 46)),  # ruby
    ((150, 255, 170), (40, 200, 90), (16, 110, 60)),  # emerald
    ((150, 200, 255), (50, 120, 240), (24, 56, 150)),  # sapphire
    ((255, 240, 150), (245, 190, 30), (160, 110, 10)),  # topaz
    ((230, 170, 255), (160, 70, 220), (90, 30, 140)),  # amethyst
]


def draw_grid(img, rows, ox, oy, palette):
    for y, row in enumerate(rows):
        assert len(row) == len(rows[0]), f"row {y} is {len(row)} wide: {row!r}"
        for x, ch in enumerate(row):
            colour = palette[ch]
            if colour is not None:
                img.putpixel((ox + x, oy + y), colour + (255,))


def make_hero():
    img = Image.new("RGBA", (16 * len(HERO_FRAMES), 24), (0, 0, 0, 0))
    for i, rows in enumerate(HERO_FRAMES):
        assert len(rows) == 24 and all(len(r) == 16 for r in rows), f"hero frame {i} must be 16x24"
        draw_grid(img, rows, i * 16, 0, PALETTE)
    return img


def make_gems():
    img = Image.new("RGBA", (12 * len(GEM_COLOURS), 12), (0, 0, 0, 0))
    for i, (light, base, dark) in enumerate(GEM_COLOURS):
        pal = {".": None, "K": PALETTE["K"], "W": (255, 255, 255), "L": light, "C": base, "D": dark}
        draw_grid(img, GEM, i * 12, 0, pal)
    return img


def make_door():
    """Two 24x32 frames: a stone arch, sealed by glowing bars (locked) or open and shining."""
    w, h = 24, 32
    img = Image.new("RGBA", (w * 2, h), (0, 0, 0, 0))
    stone, stone_dark, outline = (122, 108, 132), (84, 72, 96), PALETTE["K"]
    for frame in range(2):
        ox = frame * w
        for y in range(h):
            for x in range(w):
                # Arch: a rectangle with a round top (radius 12 around (11.5, 12)).
                dx, dy = x - 11.5, y - 12
                inside_outer = y >= 12 or dx * dx + dy * dy <= 12 * 12
                inside_inner = (y >= 12 and 4 <= x <= 19) or (y < 12 and dx * dx + dy * dy <= 8 * 8)
                if not inside_outer:
                    continue
                if not inside_inner:
                    edge = (dx * dx + dy * dy > 11 * 11 and y < 12) or x in (0, 23) or y == h - 1
                    shade = stone_dark if (x + y) % 5 == 0 else stone
                    img.putpixel((ox + x, y), (outline if edge else shade) + (255,))
                    continue
                if frame == 0:
                    bar = x in (7, 11, 12, 16)
                    colour = (180, 90, 255) if bar else (30, 22, 44)
                else:
                    glow = max(0.0, 1.0 - abs(x - 11.5) / 8.0)
                    colour = (int(40 + 120 * glow), int(120 + 135 * glow), int(80 + 100 * glow))
                img.putpixel((ox + x, y), colour + (255,))
        if frame == 0:
            # The lock: a gem shape in the middle of the bars.
            for y, row in enumerate(GEM[1:11]):
                for x, ch in enumerate(row):
                    if ch != ".":
                        c = {"K": outline, "W": (255, 255, 255), "L": (230, 170, 255), "C": (160, 70, 220), "D": (90, 30, 140)}[ch]
                        img.putpixel((ox + 6 + x, 14 + y), c + (255,))
    return img


def make_icon():
    """32x32 icon: a big gem on a dark cave background."""
    img = Image.new("RGBA", (32, 32), (27, 22, 34, 255))
    for y in range(32):
        for x in range(32):
            if (x * 7 + y * 13) % 23 == 0:
                img.putpixel((x, y), (44, 36, 56, 255))
    gems = make_gems()
    big = gems.crop((24, 0, 36, 12)).resize((24, 24), Image.NEAREST)  # sapphire, doubled
    img.alpha_composite(big, (4, 5))
    return img


def main():
    sprites = ROOT / "assets" / "sprites"
    icons = ROOT / "assets" / "icons"
    sprites.mkdir(parents=True, exist_ok=True)
    icons.mkdir(parents=True, exist_ok=True)
    make_hero().save(sprites / "hero.png")
    make_gems().save(sprites / "gems.png")
    make_door().save(sprites / "door.png")
    icon = make_icon()
    for size in (144, 180, 512):
        icon.resize((size, size), Image.NEAREST).save(icons / f"icon_{size}.png")
    icon.resize((128, 128), Image.NEAREST).save(ROOT / "icon.png")
    print("Art written to", sprites, "and", icons)


if __name__ == "__main__":
    main()
