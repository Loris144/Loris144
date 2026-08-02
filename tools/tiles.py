"""Overworld tileset generator.

Emits one 16x16-tile atlas per region plus a JSON index mapping tile names to
atlas coordinates, so the Godot TileSet can be built from data.
"""
from __future__ import annotations

from pixel import Canvas, Color, Rng, rgb, seed_of, shade, mix

TS = 16  # tile size
ATLAS_COLS = 12

Tile = Canvas


def _noise(c: Canvas, base: Color, seed: str, amount: float = 0.10, n: int = 26):
    r = Rng(seed_of(seed))
    for _ in range(n):
        x, y = r.irange(0, TS - 1), r.irange(0, TS - 1)
        f = 1.0 + (r.rand() - 0.5) * 2 * amount
        c.set(x, y, shade(base, f))


# --------------------------------------------------------------------
# terrain
# --------------------------------------------------------------------


def t_grass(seed="g") -> Tile:
    c = Canvas(TS, TS, rgb("5a9a44"))
    _noise(c, rgb("5a9a44"), seed, 0.12, 40)
    r = Rng(seed_of(seed + "blade"))
    for _ in range(7):
        x, y = r.irange(1, TS - 2), r.irange(1, TS - 2)
        c.set(x, y, rgb("6fb055"))
        c.set(x, y - 1, rgb("6fb055"))
    return c


def t_tall_grass() -> Tile:
    c = t_grass("tall")
    r = Rng(seed_of("tallg"))
    for i in range(6):
        x = 1 + i * 2 + r.irange(0, 1)
        h = r.irange(4, 7)
        for y in range(TS - 1, TS - 1 - h, -1):
            c.set(x, y, rgb("3f7a30"))
        c.set(x, TS - 1 - h, rgb("4f8f3c"))
    return c


def t_flowers() -> Tile:
    c = t_grass("fl")
    r = Rng(seed_of("flow"))
    for col in ("e8d24a", "e05a7a", "f0f0f4"):
        x, y = r.irange(2, TS - 3), r.irange(2, TS - 3)
        c.set(x, y, rgb(col))
        c.set(x + 1, y, rgb(col))
        c.set(x, y + 1, rgb(col))
        c.set(x + 1, y + 1, rgb(col))
    return c


def t_dirt() -> Tile:
    c = Canvas(TS, TS, rgb("b09068"))
    _noise(c, rgb("b09068"), "dirt", 0.10, 44)
    return c


def t_sand() -> Tile:
    c = Canvas(TS, TS, rgb("e0c890"))
    _noise(c, rgb("e0c890"), "sand", 0.07, 50)
    return c


def t_sand_dune() -> Tile:
    c = t_sand()
    for x in range(TS):
        y = 8 + int(2.5 * ((x % 8) - 4) / 4)
        c.set(x, y, rgb("d0b478"))
        c.set(x, y + 1, rgb("d0b478"))
    return c


def t_stone_path() -> Tile:
    c = Canvas(TS, TS, rgb("a8a4a0"))
    _noise(c, rgb("a8a4a0"), "stone", 0.08, 30)
    for y in (0, 8):
        c.hline(0, y, TS, rgb("8c8884"))
    off = 0
    for y0 in (0, 8):
        for x in range(off, TS, 8):
            c.vline(x, y0, 8, rgb("8c8884"))
        off = 4
    return c


def t_road() -> Tile:
    c = Canvas(TS, TS, rgb("55555e"))
    _noise(c, rgb("55555e"), "road", 0.07, 34)
    return c


def t_road_line() -> Tile:
    c = t_road()
    c.rect(7, 2, 2, 5, rgb("d8d060"))
    c.rect(7, 10, 2, 5, rgb("d8d060"))
    return c


def t_sidewalk() -> Tile:
    c = Canvas(TS, TS, rgb("c0bcb4"))
    _noise(c, rgb("c0bcb4"), "sw", 0.05, 22)
    c.hline(0, 0, TS, rgb("a4a09a"))
    c.vline(0, 0, TS, rgb("a4a09a"))
    return c


def t_water(frame=0) -> Tile:
    c = Canvas(TS, TS, rgb("2f6ab0"))
    _noise(c, rgb("2f6ab0"), f"w{frame}", 0.10, 30)
    for i in range(3):
        y = 3 + i * 5
        x0 = (frame * 3 + i * 4) % TS
        for k in range(5):
            c.set((x0 + k) % TS, y, rgb("6aa8e0"))
    return c


def t_water_edge() -> Tile:
    c = t_water()
    c.rect(0, 0, TS, 4, rgb("e0c890"))
    c.hline(0, 4, TS, rgb("c8ac74"))
    return c


def t_cliff() -> Tile:
    c = Canvas(TS, TS, rgb("8a7a64"))
    _noise(c, rgb("8a7a64"), "cliff", 0.12, 30)
    for y in range(0, TS, 5):
        c.hline(0, y, TS, rgb("6e6150"))
    for i, x in enumerate((4, 11, 6)):
        c.vline(x, i * 5, 5, rgb("6e6150"))
    return c


def t_cliff_top() -> Tile:
    c = t_grass("ct")
    c.rect(0, 11, TS, 5, rgb("8a7a64"))
    c.hline(0, 11, TS, rgb("6e6150"))
    return c


# --------------------------------------------------------------------
# scenery
# --------------------------------------------------------------------


def t_tree_top() -> Tile:
    c = Canvas(TS, TS)
    c.ellipse(8, 10, 8, 7, rgb("2f6a34"))
    c.ellipse(6, 8, 5, 4, rgb("3f8442"))
    c.ellipse(11, 11, 4, 3, rgb("276029"))
    return c


def t_tree_bottom() -> Tile:
    c = Canvas(TS, TS)
    c.ellipse(8, 2, 7, 4, rgb("2f6a34"))
    c.rect(6, 3, 4, 11, rgb("6a4a2a"))
    c.vline(6, 3, 11, rgb("523620"))
    c.ellipse(8, 14, 5, 2, (0, 0, 0, 60))
    return c


def t_palm_top() -> Tile:
    c = Canvas(TS, TS)
    for ang in ((-7, 3), (7, 3), (-5, 8), (5, 8), (0, -2)):
        c.tri((8, 11), (8 + ang[0], 11 - ang[1]), (8 + ang[0] // 2, 14), rgb("3f8442"))
    c.circle(8, 11, 2, rgb("6a4a2a"))
    return c


def t_palm_bottom() -> Tile:
    c = Canvas(TS, TS)
    c.rect(7, 0, 3, 13, rgb("8a6a3a"))
    for y in range(0, 13, 3):
        c.hline(7, y, 3, rgb("6a4a28"))
    c.ellipse(8, 14, 4, 2, (0, 0, 0, 60))
    return c


def t_bush() -> Tile:
    c = t_grass("bu")
    c.ellipse(8, 9, 6, 5, rgb("2f6a34"))
    c.ellipse(6, 7, 3, 2, rgb("3f8442"))
    return c


def t_rock() -> Tile:
    c = Canvas(TS, TS)
    c.ellipse(8, 10, 6, 5, rgb("8a8a90"))
    c.ellipse(6, 8, 3, 2, rgb("a8a8b0"))
    c.ellipse(8, 14, 6, 2, (0, 0, 0, 55))
    return c


def t_fence_h() -> Tile:
    c = Canvas(TS, TS)
    c.rect(0, 6, TS, 2, rgb("8a6a3a"))
    c.rect(0, 10, TS, 2, rgb("8a6a3a"))
    c.rect(6, 3, 3, 11, rgb("6a4a28"))
    return c


def t_sign() -> Tile:
    c = Canvas(TS, TS)
    c.rect(7, 7, 2, 8, rgb("6a4a28"))
    c.rect(2, 2, 12, 7, rgb("b08a4a"))
    c.frame(2, 2, 12, 7, rgb("6a4a28"))
    for y in (4, 6):
        c.hline(4, y, 8, rgb("5a4020"))
    return c


def t_lamp() -> Tile:
    c = Canvas(TS, TS)
    c.rect(7, 4, 2, 12, rgb("44444e"))
    c.ellipse(8, 3, 3, 3, rgb("f4e08a"))
    c.ellipse(8, 3, 2, 2, rgb("fff4c0"))
    return c


# --------------------------------------------------------------------
# buildings
# --------------------------------------------------------------------


def t_wall(col="d8ccb8", line="b0a48c") -> Tile:
    c = Canvas(TS, TS, rgb(col))
    _noise(c, rgb(col), "wall" + col, 0.05, 18)
    c.hline(0, 0, TS, rgb(line))
    return c


def t_brick() -> Tile:
    c = Canvas(TS, TS, rgb("b06a56"))
    for y in range(0, TS, 4):
        c.hline(0, y, TS, rgb("8e5142"))
        off = 0 if (y // 4) % 2 == 0 else 4
        for x in range(off, TS, 8):
            c.vline(x, y, 4, rgb("8e5142"))
    return c


def t_roof(col="b8383a") -> Tile:
    c = Canvas(TS, TS, rgb(col))
    dk = shade(rgb(col), 0.78)
    for y in range(0, TS, 4):
        c.hline(0, y, TS, dk)
        off = 0 if (y // 4) % 2 == 0 else 3
        for x in range(off, TS, 6):
            c.vline(x, y, 4, dk)
    return c


def t_roof_edge(col="b8383a") -> Tile:
    c = t_roof(col)
    c.rect(0, 12, TS, 4, shade(rgb(col), 0.6))
    c.hline(0, 12, TS, shade(rgb(col), 0.45))
    return c


def t_window() -> Tile:
    c = t_wall()
    c.rect(2, 3, 12, 10, rgb("3a5a7a"))
    c.frame(2, 3, 12, 10, rgb("8a7a5a"))
    c.rect(3, 4, 4, 4, rgb("7ab0d8"))
    c.vline(8, 3, 10, rgb("8a7a5a"))
    c.hline(2, 8, 12, rgb("8a7a5a"))
    return c


def t_door() -> Tile:
    c = t_wall()
    c.rect(3, 2, 10, 14, rgb("7a4a2a"))
    c.frame(3, 2, 10, 14, rgb("5a3420"))
    c.circle(11, 9, 1, rgb("e8c246"))
    c.hline(4, 6, 8, rgb("5a3420"))
    return c


def t_shop_window() -> Tile:
    c = t_wall("e8dcc4")
    c.rect(1, 2, 14, 11, rgb("8ac0d8"))
    c.frame(1, 2, 14, 11, rgb("7a5a3a"))
    c.rect(3, 5, 4, 5, rgb("d8b83c"))
    c.rect(9, 6, 4, 4, rgb("b03a4a"))
    return c


def t_awning(col="2f6a4a") -> Tile:
    c = Canvas(TS, TS)
    for x in range(TS):
        stripe = rgb(col) if (x // 3) % 2 == 0 else rgb("f0ece0")
        c.vline(x, 0, 9, stripe)
    c.hline(0, 9, TS, shade(rgb(col), 0.6))
    for x in range(0, TS, 3):
        c.tri((x, 9), (x + 3, 9), (x + 1, 12), shade(rgb(col), 0.85))
    return c


# --------------------------------------------------------------------
# interiors
# --------------------------------------------------------------------


def t_wood_floor() -> Tile:
    c = Canvas(TS, TS, rgb("b8905a"))
    for y in range(0, TS, 4):
        c.hline(0, y, TS, rgb("9a7444"))
    _noise(c, rgb("b8905a"), "wf", 0.05, 20)
    return c


def t_carpet(col="8a2a3a") -> Tile:
    c = Canvas(TS, TS, rgb(col))
    _noise(c, rgb(col), "cp", 0.06, 22)
    c.frame(0, 0, TS, TS, shade(rgb(col), 0.8))
    return c


def t_tiles_floor() -> Tile:
    c = Canvas(TS, TS, rgb("d0d0d8"))
    c.hline(0, 0, TS, rgb("a8a8b4"))
    c.vline(0, 0, TS, rgb("a8a8b4"))
    c.rect(8, 0, 8, 8, rgb("c0c0ca"))
    c.rect(0, 8, 8, 8, rgb("c0c0ca"))
    return c


def t_inner_wall() -> Tile:
    c = Canvas(TS, TS, rgb("e4d8c0"))
    c.hline(0, 12, TS, rgb("c0b096"))
    c.rect(0, 13, TS, 3, rgb("8a6a4a"))
    return c


def t_shelf() -> Tile:
    c = Canvas(TS, TS, rgb("8a6a3a"))
    c.frame(0, 0, TS, TS, rgb("5a4020"))
    for y in (4, 9, 14):
        c.hline(1, y, 14, rgb("5a4020"))
    r = Rng(seed_of("shelf"))
    for y in (1, 6, 11):
        for x in range(2, 14, 3):
            c.rect(x, y, 2, 3, rgb(r.pick(["b03a4a", "3a6ab0", "d8b83c", "4a8a5a"])))
    return c


def t_counter() -> Tile:
    c = Canvas(TS, TS, rgb("9a7444"))
    c.rect(0, 0, TS, 4, rgb("c8a068"))
    c.hline(0, 4, TS, rgb("7a5a30"))
    c.frame(0, 0, TS, TS, rgb("6a4a28"))
    return c


def t_table() -> Tile:
    c = Canvas(TS, TS)
    c.rect(1, 3, 14, 10, rgb("b8905a"))
    c.frame(1, 3, 14, 10, rgb("7a5a30"))
    c.rect(2, 4, 12, 2, rgb("cfa670"))
    return c


def t_bed() -> Tile:
    c = Canvas(TS, TS)
    c.rect(1, 1, 14, 14, rgb("d8d8e0"))
    c.frame(1, 1, 14, 14, rgb("7a5a30"))
    c.rect(2, 2, 12, 4, rgb("f0f0f4"))
    c.rect(2, 7, 12, 7, rgb("3a6ab0"))
    return c


def t_plant() -> Tile:
    c = Canvas(TS, TS)
    c.rect(5, 10, 6, 5, rgb("a85a3a"))
    c.hline(5, 10, 6, rgb("8a4428"))
    c.ellipse(8, 6, 5, 5, rgb("2f6a34"))
    c.ellipse(6, 4, 2, 2, rgb("3f8442"))
    return c


# --------------------------------------------------------------------
# egypt
# --------------------------------------------------------------------


def t_sandstone() -> Tile:
    c = Canvas(TS, TS, rgb("d8b878"))
    for y in range(0, TS, 5):
        c.hline(0, y, TS, rgb("b89858"))
        off = 0 if (y // 5) % 2 == 0 else 5
        for x in range(off, TS, 10):
            c.vline(x, y, 5, rgb("b89858"))
    return c


def t_hieroglyph() -> Tile:
    c = t_sandstone()
    r = Rng(seed_of("glyph"))
    ink = rgb("6a4a28")
    for _ in range(5):
        x, y = r.irange(2, 12), r.irange(2, 12)
        k = r.irange(0, 3)
        if k == 0:
            c.rect(x, y, 3, 1, ink); c.rect(x + 1, y, 1, 3, ink)
        elif k == 1:
            c.ellipse(x, y, 2, 1, ink)
        elif k == 2:
            c.rect(x, y, 1, 3, ink); c.rect(x, y + 3, 3, 1, ink)
        else:
            c.tri((x, y + 3), (x + 3, y + 3), (x + 1, y), ink)
    return c


def t_pillar() -> Tile:
    c = Canvas(TS, TS, rgb("e0c890"))
    c.rect(3, 0, 10, TS, rgb("dcc084"))
    c.vline(3, 0, TS, rgb("b89858"))
    c.vline(12, 0, TS, rgb("b89858"))
    for y in range(2, TS, 5):
        c.hline(4, y, 8, rgb("c8a868"))
    return c


def t_pillar_top() -> Tile:
    c = Canvas(TS, TS)
    c.rect(1, 8, 14, 8, rgb("dcc084"))
    c.rect(2, 4, 12, 4, rgb("e8d4a0"))
    c.hline(1, 8, 14, rgb("b89858"))
    c.rect(4, 0, 8, 4, rgb("c8a868"))
    return c


# --------------------------------------------------------------------
# atlas assembly
# --------------------------------------------------------------------

TILE_DEFS: list[tuple[str, callable]] = [
    ("void", lambda: Canvas(TS, TS)),
    ("grass", t_grass),
    ("grass2", lambda: t_grass("g2")),
    ("tall_grass", t_tall_grass),
    ("flowers", t_flowers),
    ("dirt", t_dirt),
    ("sand", t_sand),
    ("sand_dune", t_sand_dune),
    ("stone_path", t_stone_path),
    ("road", t_road),
    ("road_line", t_road_line),
    ("sidewalk", t_sidewalk),
    ("water", lambda: t_water(0)),
    ("water2", lambda: t_water(2)),
    ("water_edge", t_water_edge),
    ("cliff", t_cliff),
    ("cliff_top", t_cliff_top),
    ("tree_top", t_tree_top),
    ("tree_bottom", t_tree_bottom),
    ("palm_top", t_palm_top),
    ("palm_bottom", t_palm_bottom),
    ("bush", t_bush),
    ("rock", t_rock),
    ("fence", t_fence_h),
    ("sign", t_sign),
    ("lamp", t_lamp),
    ("wall", lambda: t_wall()),
    ("wall_blue", lambda: t_wall("c4d0e0", "9aa8bc")),
    ("brick", t_brick),
    ("roof_red", lambda: t_roof("b8383a")),
    ("roof_blue", lambda: t_roof("3a5a9a")),
    ("roof_green", lambda: t_roof("2f6a4a")),
    ("roof_red_edge", lambda: t_roof_edge("b8383a")),
    ("roof_blue_edge", lambda: t_roof_edge("3a5a9a")),
    ("roof_green_edge", lambda: t_roof_edge("2f6a4a")),
    ("window", t_window),
    ("door", t_door),
    ("shop_window", t_shop_window),
    ("awning", lambda: t_awning("2f6a4a")),
    ("awning_red", lambda: t_awning("a83030")),
    ("wood_floor", t_wood_floor),
    ("carpet", lambda: t_carpet("8a2a3a")),
    ("carpet_blue", lambda: t_carpet("2a3a8a")),
    ("tile_floor", t_tiles_floor),
    ("inner_wall", t_inner_wall),
    ("shelf", t_shelf),
    ("counter", t_counter),
    ("table", t_table),
    ("bed", t_bed),
    ("plant", t_plant),
    ("sandstone", t_sandstone),
    ("hieroglyph", t_hieroglyph),
    ("pillar", t_pillar),
    ("pillar_top", t_pillar_top),
]

# tiles the player cannot walk through
SOLID = {
    "void", "water", "water2", "tree_top", "tree_bottom", "palm_top",
    "palm_bottom", "bush", "rock", "fence", "sign", "lamp", "cliff",
    "wall", "wall_blue", "brick", "roof_red", "roof_blue", "roof_green",
    "roof_red_edge", "roof_blue_edge", "roof_green_edge", "window",
    "shop_window", "awning", "awning_red", "inner_wall", "shelf",
    "counter", "table", "bed", "plant", "sandstone", "hieroglyph",
    "pillar", "pillar_top",
}


def build_atlas() -> tuple[Canvas, dict]:
    rows = (len(TILE_DEFS) + ATLAS_COLS - 1) // ATLAS_COLS
    atlas = Canvas(ATLAS_COLS * TS, rows * TS)
    index = {}
    for i, (name, fn) in enumerate(TILE_DEFS):
        cx, cy = i % ATLAS_COLS, i // ATLAS_COLS
        atlas.blit(fn(), cx * TS, cy * TS)
        index[name] = {"id": i, "x": cx, "y": cy, "solid": name in SOLID}
    return atlas, index
