"""UI + card art generator: card frames, duel field, panels, HUD bits."""
from __future__ import annotations

from pixel import Canvas, Color, Rng, rgb, seed_of, shade, mix

CARD_W, CARD_H = 100, 146

FRAME_COLS = {
    "normal":   ("c9a44c", "e8cf86", "8a6c28"),
    "effect":   ("bf7a3a", "e0a468", "8a5220"),
    "ritual":   ("4a72b8", "7fa2dc", "2d4a80"),
    "fusion":   ("8a5aa8", "b48ccc", "5c3a74"),
    "spell":    ("2f9a86", "62c4b0", "1c6a5c"),
    "trap":     ("b0407a", "d878a8", "78264f"),
    "token":    ("8a8a92", "b4b4bc", "5a5a62"),
    "divine":   ("c8a020", "f0d868", "8a6c10"),
}


def card_frame(kind: str) -> Canvas:
    base, hi, dk = (rgb(x) for x in FRAME_COLS.get(kind, FRAME_COLS["normal"]))
    c = Canvas(CARD_W, CARD_H)
    # outer border
    c.rect(0, 0, CARD_W, CARD_H, dk)
    c.rect(1, 1, CARD_W - 2, CARD_H - 2, base)
    # subtle vertical sheen
    for y in range(1, CARD_H - 1):
        f = 1.0 + 0.13 * (1 - abs(y - CARD_H * 0.35) / (CARD_H * 0.7))
        for x in range(1, CARD_W - 1):
            c.px[y][x] = shade(base, f)
    c.frame(1, 1, CARD_W - 2, CARD_H - 2, hi)
    # name plate
    c.rect(6, 5, CARD_W - 12, 13, shade(base, 0.86))
    c.frame(6, 5, CARD_W - 12, 13, dk)
    # art window
    c.rect(8, 21, CARD_W - 16, 62, rgb("241f2c"))
    c.frame(8, 21, CARD_W - 16, 62, dk)
    c.frame(7, 20, CARD_W - 14, 64, hi)
    # text box
    c.rect(6, 88, CARD_W - 12, CARD_H - 100, shade(base, 1.12))
    c.frame(6, 88, CARD_W - 12, CARD_H - 100, dk)
    # stat bar for monsters
    if kind in ("normal", "effect", "ritual", "fusion", "divine"):
        c.rect(6, CARD_H - 20, CARD_W - 12, 13, shade(base, 0.8))
        c.frame(6, CARD_H - 20, CARD_W - 12, 13, dk)
    return c


def card_back() -> Canvas:
    c = Canvas(CARD_W, CARD_H)
    base = rgb("8a4a2a")
    c.rect(0, 0, CARD_W, CARD_H, rgb("4a2414"))
    c.rect(2, 2, CARD_W - 4, CARD_H - 4, base)
    for y in range(2, CARD_H - 2):
        for x in range(2, CARD_W - 2):
            f = 1.0 + 0.10 * ((x * 7 + y * 3) % 11 - 5) / 10.0
            c.px[y][x] = shade(base, f)
    c.frame(5, 5, CARD_W - 10, CARD_H - 10, rgb("d8a860"))
    c.frame(6, 6, CARD_W - 12, CARD_H - 12, rgb("6a3418"))
    # centre emblem: stylised Millennium eye
    cx, cy = CARD_W // 2, CARD_H // 2
    c.ellipse(cx, cy, 26, 18, rgb("c89a4a"))
    c.ellipse(cx, cy, 22, 14, rgb("6a3418"))
    c.ellipse(cx, cy, 13, 11, rgb("e8c874"))
    c.circle(cx, cy, 7, rgb("4a2414"))
    c.circle(cx, cy, 4, rgb("e8c874"))
    c.tri((cx - 20, cy + 16), (cx + 20, cy + 16), (cx, cy + 30), rgb("c89a4a"))
    for i in range(3):
        c.vline(cx - 10 + i * 10, cy + 18, 8, rgb("c89a4a"))
    return c


def card_art_placeholder(name: str, attr: str = "") -> Canvas:
    """Deterministic abstract art used until the real card image is cached."""
    w, h = CARD_W - 16, 62
    pal = {
        "DARK":  ("2a2038", "5a3a78", "8a5aa8", "c8a0e0"),
        "LIGHT": ("4a4230", "8a7a40", "d8c060", "f6ecb0"),
        "FIRE":  ("3a1a18", "8a2a20", "d05a28", "f0a850"),
        "WATER": ("152a40", "1f5580", "3a9ac8", "8ad8f0"),
        "EARTH": ("2a2418", "5a4a28", "8a7040", "c0a870"),
        "WIND":  ("1a2a20", "2f6a4a", "4faa78", "a0e0b8"),
        "DIVINE": ("3a2a10", "8a6a10", "e0b830", "fff0a0"),
    }.get(attr, ("22222c", "3a3a50", "5a5a78", "9a9ab8"))
    cols = [rgb(x) for x in pal]
    c = Canvas(w, h, cols[0])
    r = Rng(seed_of(name))
    # layered silhouette shapes
    for i in range(1, 4):
        for _ in range(3 + i):
            cx = r.irange(4, w - 4)
            cy = r.irange(6, h - 4)
            rx = r.irange(5, 16 - i * 2)
            ry = r.irange(5, 14 - i * 2)
            c.ellipse(cx, cy, rx, ry, cols[i])
    # scanline texture
    for y in range(0, h, 3):
        for x in range(w):
            c.px[y][x] = shade(c.px[y][x], 0.9)
    return c


def duel_field(w: int = 480, h: int = 270) -> Canvas:
    """GX Tag Force styled playmat.

    Only the arena backdrop and the centre divider live in the texture; the
    zone outlines are drawn by the duel screen so they always line up with
    the real card positions.
    """
    c = Canvas(w, h)
    for y in range(h):
        t = y / h
        c.rect(0, y, w, 1, mix(rgb("1b2440"), rgb("3a2850"), t))
    # arena light pooling around the middle of the mat
    c.ellipse(w // 2, 92, int(w * 0.62), 84, rgb("27406a"))
    c.ellipse(w // 2, 94, int(w * 0.52), 68, rgb("2f5183"))
    c.ellipse(w // 2, 96, int(w * 0.40), 50, rgb("39619c"))
    c.ellipse(w // 2, 96, int(w * 0.26), 32, rgb("4272b4"))
    # faint horizon lines for depth
    for i, y in enumerate(range(26, 160, 11)):
        a = 70 - i * 5
        if a > 0:
            c.hline(int(w * 0.08), y, int(w * 0.84), (150, 200, 255, a))
    # side pillars framing the arena
    for sx in (0, w - 34):
        for y in range(0, 172):
            t = y / 172.0
            c.rect(sx, y, 34, 1, mix(rgb("141c30"), rgb("232a48"), t))
        c.vline(sx if sx == 0 else w - 1, 0, 172, rgb("46648e"))
    c.vline(34, 0, 172, rgb("3a5580"))
    c.vline(w - 35, 0, 172, rgb("3a5580"))
    # centre divider
    for x in range(40, w - 40, 8):
        c.hline(x, 90, 5, rgb("7ea8d8"))
        c.hline(x, 91, 5, rgb("42679a"))
    # hand shelf at the bottom
    c.rect(0, 172, w, h - 172, (12, 17, 32, 235))
    c.hline(0, 172, w, rgb("5d84bc"))
    c.hline(0, 173, w, rgb("2c4166"))
    return c


def panel(w: int, h: int, base="1d2436", edge="5a7ab0", inner="2b3550") -> Canvas:
    c = Canvas(w, h)
    c.rect(0, 0, w, h, rgb(base))
    c.rect(2, 2, w - 4, h - 4, rgb(inner))
    for y in range(2, h - 2):
        f = 1.0 + 0.08 * (1 - y / h)
        for x in range(2, w - 2):
            c.px[y][x] = shade(rgb(inner), f)
    c.frame(0, 0, w, h, rgb(edge))
    c.frame(2, 2, w - 4, h - 4, shade(rgb(edge), 0.65))
    # corner studs
    for cx, cy in ((3, 3), (w - 6, 3), (3, h - 6), (w - 6, h - 6)):
        c.rect(cx, cy, 3, 3, rgb(edge))
    return c


def dialog_box(w: int = 320, h: int = 84) -> Canvas:
    c = panel(w, h, "14192a", "8aa8e0", "1e2740")
    c.hline(6, 6, w - 12, rgb("4a6a9a"))
    return c


def button(w: int = 96, h: int = 24, col="3a6ab0") -> Canvas:
    c = Canvas(w, h)
    base = rgb(col)
    c.rect(0, 0, w, h, shade(base, 0.5))
    c.rect(1, 1, w - 2, h - 2, base)
    for y in range(1, h - 1):
        c.rect(1, y, w - 2, 1, shade(base, 1.18 - 0.36 * y / h))
    c.frame(0, 0, w, h, shade(base, 1.5))
    return c


def lp_bar(w: int = 120, h: int = 12) -> Canvas:
    c = Canvas(w, h)
    c.rect(0, 0, w, h, rgb("14192a"))
    c.frame(0, 0, w, h, rgb("6a8ac0"))
    c.rect(2, 2, w - 4, h - 4, rgb("22304a"))
    return c


def dpad(size: int = 96) -> Canvas:
    c = Canvas(size, size)
    s = size // 3
    col = (200, 210, 235, 110)
    edge = (240, 245, 255, 170)
    c.rect(s, 0, s, size, col)
    c.rect(0, s, size, s, col)
    c.frame(s, 0, s, size, edge)
    c.frame(0, s, size, s, edge)
    c.rect(s + 1, s + 1, s - 2, s - 2, (150, 165, 200, 90))
    m = s // 2
    for (ax, ay, dx, dy) in ((size // 2, m, 0, -1), (size // 2, size - m, 0, 1),
                             (m, size // 2, -1, 0), (size - m, size // 2, 1, 0)):
        c.tri((ax + dy * 6 - dx * 3, ay + dx * 6 - dy * 3),
              (ax - dy * 6 - dx * 3, ay - dx * 6 - dy * 3),
              (ax + dx * 5, ay + dy * 5), edge)
    return c


def round_button(size: int = 56, col="3a6ab0") -> Canvas:
    c = Canvas(size, size)
    base = rgb(col)
    c.circle(size / 2, size / 2, size / 2 - 1, shade(base, 0.5))
    c.circle(size / 2, size / 2, size / 2 - 3, base)
    c.ellipse(size / 2, size / 2 - size * 0.18, size / 2 - 7, size / 5,
              shade(base, 1.3))
    return c


def title_logo(w: int = 320, h: int = 96) -> Canvas:
    """Stylised YU-GI-OH wordmark built from blocks (no font dependency)."""
    c = Canvas(w, h)
    gold = rgb("e8c246")
    gold_d = rgb("8a6c18")
    # Millennium puzzle silhouette behind the text
    cx = w // 2
    c.tri((cx - 46, 68), (cx + 46, 68), (cx, 8), rgb("3a2f10"))
    c.tri((cx - 40, 64), (cx + 40, 64), (cx, 16), rgb("6a5418"))
    c.ellipse(cx, 46, 12, 9, gold)
    c.ellipse(cx, 46, 7, 5, rgb("2a2210"))
    c.circle(cx, 46, 3, gold)
    # baseline bar
    c.rect(20, 74, w - 40, 5, gold_d)
    c.rect(20, 74, w - 40, 2, gold)
    return c
