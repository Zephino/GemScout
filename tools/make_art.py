#!/usr/bin/env python3
"""Draws GemScout's original pixel art and writes the PNGs the game uses.

Every sprite is a text grid below: one character per pixel, looked up in
PALETTE. Change a grid (or a colour) and run this again:

    python3 tools/make_art.py

It writes:
  assets/sprites/hero.png     16x24 frames: idle, run x4, jump, fall
  assets/sprites/gems.png     12x12 frames: one per gem colour
  assets/sprites/door.png     24x32 frames: locked, open
  assets/sprites/enemies.png  16x16 frames: shellback x2, glowmoth x2,
                              dripjaw x2, spitter x2, glob
  assets/sprites/items.png    12x12 frames: heart, empty heart, ammo crate,
                              ammo, power shot, reverse gravity, freeze,
                              shield, lever up, lever down, switch on, off
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



# --- Enemies (16x16 frames; all original designs) ----------------------------

ENEMY_PALETTE = {
    ".": None,
    "O": (26, 20, 32),
    # Shellback: an armoured cave beetle.
    "A": (104, 150, 66), "a": (62, 96, 42), "h": (170, 210, 110), "L": (48, 36, 36), "E": (240, 70, 60),
    # Glowmoth: pale wings with glowing spots.
    "G": (206, 196, 240), "g": (150, 140, 200), "W": (240, 232, 205), "Y": (255, 240, 140),
    # Dripjaw: a living stalactite.
    "R": (136, 120, 156), "r": (92, 82, 108), "T": (250, 250, 240), "e": (255, 200, 60),
    # Spitter: a wall pod.
    "P": (96, 176, 96), "p": (52, 112, 62), "M": (210, 64, 96), "S": (200, 240, 90),
}

SHELLBACK_TOP = [
    "................",
    "................",
    "................",
    "................",
    "................",
    "......OOOO......",
    "....OOhhAAOO....",
    "...OhhAAAAAAO...",
    "..OhAAAaAAAAAOO.",
    "..OAAAAaAAAAAOEO",
    "..OaAAAaAAAAAOOO",
    "..OOaaaaaaaaaOO.",
    "...OOOOOOOOOOO..",
]
SHELLBACK = [
    SHELLBACK_TOP + ["...L..L..L..L...", "..L..L..L..L....", "................"],
    SHELLBACK_TOP + ["....L..L..L..L..", "...L..L..L..L...", "................"],
]

GLOWMOTH = [
    [
        "................",
        "..OOO......OOO..",
        ".OGGGO....OGGGO.",
        ".OGYGGO..OGGYGO.",
        ".OGGGgGOOGgGGGO.",
        "..OGGGgWWgGGGO..",
        "...OOGGWWGGOO...",
        ".....OOWWOO.....",
        "......OWWO......",
        "......OWWO......",
        ".......OO.......",
        "................",
        "................",
        "................",
        "................",
        "................",
    ],
    [
        "................",
        "................",
        "................",
        "......OOOO......",
        "...OOOOWWOOOO...",
        "..OGGGGWWGGGGO..",
        ".OGGYGgWWgGYGGO.",
        ".OGGGGOWWOGGGGO.",
        "..OGGO.OWO.OGGO.",
        "...OO..OWO..OO..",
        ".......OO.......",
        "................",
        "................",
        "................",
        "................",
        "................",
    ],
]

DRIPJAW_TOP = [
    "..OOOOOOOOOOOO..",
    "..ORRRRRRRRRRO..",
    "...ORRRRRRRRO...",
    "...OrReRReRrO...",
    "....ORRRRRRO....",
    "....OrRRRRrO....",
]
DRIPJAW = [
    DRIPJAW_TOP + [
        ".....ORRRRO.....",
        ".....OrTTrO.....",
        "......ORRO......",
        "......OrrO......",
        ".......OO.......",
        "................",
        "................",
        "................",
        "................",
        "................",
    ],
    DRIPJAW_TOP + [
        "....OTRRRRTO....",
        "....OT....TO....",
        "....OT....TO....",
        ".....OT..TO.....",
        "......O..O......",
        "................",
        "................",
        "................",
        "................",
        "................",
    ],
]

SPITTER_BODY = [
    "................",
    "....OOOO........",
    "...OPPPPOO......",
    "..OPPpPPPPO.....",
    "..OPpPPPPPPO....",
]
SPITTER = [
    SPITTER_BODY + [
        "..OPPPPPPPPPO...",
        "..OPpPPPPPPPO...",
        "..OPPPPPPPPO....",
        "...OPPpPPPO.....",
        "....OOOOOO......",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
    ],
    SPITTER_BODY + [
        "..OPPPPPPPOMMO..",
        "..OPpPPPPPOMMMO.",
        "..OPPPPPPPOMMO..",
        "...OPPpPPPO.....",
        "....OOOOOO......",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
    ],
]

GLOB = [
    "................",
    "................",
    "................",
    "................",
    "................",
    "......OOO.......",
    ".....OSSSO......",
    ".....OSPSO......",
    ".....OSSSO......",
    "......OOO.......",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
]


def make_enemies():
    frames = SHELLBACK + GLOWMOTH + DRIPJAW + SPITTER + [GLOB]
    img = Image.new("RGBA", (16 * len(frames), 16), (0, 0, 0, 0))
    for i, rows in enumerate(frames):
        assert len(rows) == 16 and all(len(r) == 16 for r in rows), f"enemy frame {i} must be 16x16"
        draw_grid(img, rows, i * 16, 0, ENEMY_PALETTE)
    return img


# --- Items (12x12 frames) -----------------------------------------------------

ITEM_PALETTE = {
    ".": None,
    "O": (26, 20, 32),
    "R": (232, 52, 72), "r": (150, 22, 42), "W": (255, 255, 255),
    "E": (64, 54, 76), "e": (44, 36, 56),
    "B": (156, 104, 52), "b": (104, 68, 32), "M": (150, 150, 165), "Y": (250, 210, 70),
    "C": (90, 220, 240), "c": (40, 140, 170),
    "K": (250, 250, 250), "S": (210, 210, 220), "s": (140, 140, 156),
    "L": (255, 170, 60), "l": (90, 70, 60),
}

HEART = [
    "............",
    "..OO....OO..",
    ".ORRO..ORRO.",
    "ORWRROORRRRO",
    "ORRRRRRRRRRO",
    "ORRRRRRRRRrO",
    ".ORRRRRRRrO.",
    "..ORRRRRrO..",
    "...ORRRrO...",
    "....ORrO....",
    ".....OO.....",
    "............",
]
HEART_EMPTY = [row.replace("R", "E").replace("r", "e").replace("W", "E") for row in HEART]

CRATE = [
    "............",
    "............",
    "OOOOOOOOOOOO",
    "OBBBBBBBBBBO",
    "ObMMMMMMMMbO",
    "OBBBYYYYBBBO",
    "OBBBYCCYBBBO",
    "OBBBYYYYBBBO",
    "ObMMMMMMMMbO",
    "OBBBBBBBBBBO",
    "OOOOOOOOOOOO",
    "............",
]

AMMO = [
    "............",
    "....OOOO....",
    "...OCCCCO...",
    "...OCWCCO...",
    "...OCCCCO...",
    "...OCCCCO...",
    "...OCCCcO...",
    "...OCCCcO...",
    "...OCCccO...",
    "...OMMMMO...",
    "....OOOO....",
    "............",
]

ORB = [
    "...OOOOOO...",
    "..OCCCCCCO..",
    ".OCWCCCCCCO.",
    "OCWCCCCCCCCO",
    "OCCCCCCCCCCO",
    "OCCCCCCCCCCO",
    "OCCCCCCCCCCO",
    "OCCCCCCCCCCO",
    "OCCCCCCCCCcO",
    ".OCCCCCCCcO.",
    "..OCCCCCcO..",
    "...OOOOOO...",
]
# Symbols drawn in white over the middle of an orb.
ORB_SYMBOLS = {
    "power_shot": ["..K...", "...K..", "KKKKK.", "...K..", "..K...", "......"],
    "gravity": ["..KK..", ".KKKK.", "..KK..", "..KK..", ".KKKK.", "..KK.."],
    "freeze": ["K.K.K.", ".KKK..", "KKKKK.", ".KKK..", "K.K.K.", "......"],
    "shield": ["KKKKK.", "K...K.", "K...K.", ".K.K..", "..K...", "......"],
}
ORB_COLOURS = {
    "power_shot": ((255, 150, 60), (180, 80, 20)),
    "gravity": ((170, 110, 240), (100, 50, 170)),
    "freeze": ((130, 210, 255), (60, 130, 200)),
    "shield": ((110, 220, 130), (40, 140, 70)),
}

# Levers are drawn in white and grey so the game can tint them red, blue or yellow.
LEVER_UP = [
    "............",
    ".KK.........",
    ".KK.........",
    "...S........",
    "....S.......",
    ".....S......",
    "......S.....",
    "....OOOOO...",
    "...OSSSSSO..",
    "...OSsssSO..",
    "..OOOOOOOOO.",
    "............",
]
LEVER_DOWN = [row[::-1] for row in LEVER_UP]

SWITCH_ON = [
    "............",
    ".OOOOOOOOOO.",
    ".OSSSSSSSSO.",
    ".OSsOOOOsSO.",
    ".OSOLLLLOSO.",
    ".OSOLWLLOSO.",
    ".OSOLLLLOSO.",
    ".OSsOOOOsSO.",
    ".OSSSSSSSSO.",
    ".OOOOOOOOOO.",
    "............",
    "............",
]
SWITCH_OFF = [row.replace("L", "l").replace("W", "l") for row in SWITCH_ON]


def make_items():
    frames = [HEART, HEART_EMPTY, CRATE, AMMO]
    orbs = []
    for name in ("power_shot", "gravity", "freeze", "shield"):
        light, dark = ORB_COLOURS[name]
        rows = [list(r) for r in ORB]
        for y, srow in enumerate(ORB_SYMBOLS[name]):
            for x, ch in enumerate(srow):
                if ch == "K":
                    rows[3 + y][3 + x] = "K"
        orbs.append((["".join(r) for r in rows], light, dark))
    tail = [LEVER_UP, LEVER_DOWN, SWITCH_ON, SWITCH_OFF]
    count = len(frames) + len(orbs) + len(tail)
    img = Image.new("RGBA", (12 * count, 12), (0, 0, 0, 0))
    i = 0
    for rows in frames:
        draw_grid(img, rows, i * 12, 0, ITEM_PALETTE)
        i += 1
    for rows, light, dark in orbs:
        pal = dict(ITEM_PALETTE)
        pal["C"] = light
        pal["c"] = dark
        draw_grid(img, rows, i * 12, 0, pal)
        i += 1
    for rows in tail:
        draw_grid(img, rows, i * 12, 0, ITEM_PALETTE)
        i += 1
    return img


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
    make_enemies().save(sprites / "enemies.png")
    make_items().save(sprites / "items.png")
    icon = make_icon()
    for size in (144, 180, 512):
        icon.resize((size, size), Image.NEAREST).save(icons / f"icon_{size}.png")
    icon.resize((128, 128), Image.NEAREST).save(ROOT / "icon.png")
    print("Art written to", sprites, "and", icons)


if __name__ == "__main__":
    main()
