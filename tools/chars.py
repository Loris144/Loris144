"""Overworld character sprites in the Pokemon Gen-5 idiom.

The body is a hand-drawn pixel template (see body_template.py) that gets
recoloured per character; hair, headgear and accessories are layered on top.
That combination is what makes the cast readable at 32px: a real drawn
silhouette with proper shading, not procedural rectangles.

Yu-Gi-Oh signifiers ride on the same system — Duel Disks on the forearm,
Millennium items on the chest, the blue Domino school jacket.

Sheet layout: 32x44 frames, 4 columns (walk cycle), 4 rows (down/left/right/up).
"""
from __future__ import annotations

from dataclasses import dataclass

import body_template as BT
from pixel import Canvas, Color, Rng, rgb, seed_of, shade, mix
from shade import Ramp, skin_ramp, shade_ellipse, OUTLINE

FW, FH = 32, 44
DIRS = ("down", "left", "right", "up")
CX = 16

EYE_WHITE = rgb("fbfbff")


@dataclass
class CharSpec:
    key: str
    skin: str = "f0c8a0"
    hair: str = "3a2a20"
    hair2: str = ""
    hair_style: str = "short"
    top: str = "3c6fb5"
    top2: str = ""
    bottom: str = "2b3550"
    shoes: str = "35302e"
    coat: str = ""
    accessory: str = ""
    eyes: str = "3a2a55"
    tall: int = 0
    skirt: bool = False
    scarf: str = ""
    headgear: str = ""
    headgear_col: str = "c02020"
    duel_disk: str = ""
    belt: str = ""

    def ramps(self) -> dict:
        return {
            "skin": skin_ramp(self.skin),
            "hair": Ramp(self.hair),
            "hair2": Ramp(self.hair2 or self.hair),
            "top": Ramp(self.top),
            "top2": Ramp(self.top2 or self.top),
            "bottom": Ramp(self.bottom),
            "shoes": Ramp(self.shoes),
            "coat": Ramp(self.coat or self.top),
            "gear": Ramp(self.headgear_col),
            "disk": Ramp(self.duel_disk or "5a7ab0"),
            "belt": Ramp(self.belt or "3a2f28"),
        }


# =====================================================================
# template painting
# =====================================================================

def _palette(spec: CharSpec, R: dict) -> dict:
    sk: Ramp = R["skin"]
    top: Ramp = R["top"]
    top2: Ramp = R["top2"]
    bot: Ramp = R["bottom"]
    sh: Ramp = R["shoes"]
    iris = rgb(spec.eyes)
    return {
        "O": OUTLINE,
        "S": sk.at(1), "s": sk.at(0), "L": sk.at(2), "K": sk.at(1),
        "W": EYE_WHITE, "E": iris, "P": mix(iris, rgb("0a0812"), 0.6),
        "T": top.at(1), "u": top.at(2), "v": top.at(0),
        "C": top2.at(1),
        "B": bot.at(1), "n": bot.at(0), "m": bot.at(2),
        "F": sh.at(1), "f": sh.at(2),
    }


def _paint(c: Canvas, spec: CharSpec, d: str, step: int, R: dict) -> None:
    rows = BT.TEMPLATES["left" if d == "right" else d]
    pal = _palette(spec, R)
    lift = min(spec.tall, 3)          # taller characters sit higher
    swing = (0, 1, 0, -1)[step]
    arm = (0, -1, 0, 1)[step]

    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "." or ch not in pal:
                continue
            dy = 0
            dx = 0
            if y in BT.LEG_ROWS:
                # left leg forward on frame 1, right leg on frame 3
                dy = swing if x < CX else -swing
            elif y in BT.ARM_ROWS and ch in ("K",):
                dy = arm if x < CX else -arm
            c.set(x + dx, y + dy - lift, pal[ch])

    # skirt replaces the trouser block
    if spec.skirt:
        bot: Ramp = R["bottom"]
        for i in range(7):
            w = 6 + i
            for k in range(w * 2):
                x = CX - w + k
                lv = 2 if k < 3 else (0 if k > w * 2 - 4 else 1)
                c.set(x, 32 + i - lift, bot.at(lv))
        # legs peeking out below
        sk: Ramp = R["skin"]
        shr: Ramp = R["shoes"]
        for i, dxx in enumerate((-5, 2)):
            o = swing if i == 0 else -swing
            for k in range(max(1, 3 + o)):
                for w in range(3):
                    c.set(CX + dxx + w, 39 + k - lift, sk.at(1 if w else 2))
            for w in range(3):
                c.set(CX + dxx + w, 39 + max(1, 3 + o) - lift, shr.at(1))


# =====================================================================
# hair
# =====================================================================

def _skull(c: Canvas, r: Ramp, d: str, lift: int, depth: int) -> None:
    """Hair cap hugging the drawn skull.

    The hairline is not a flat cut — it sits high over the forehead and drops
    down past the temples, which is what stops it reading as a helmet.
    """
    top = BT.HEAD_TOP - lift
    for x in range(CX - 10, CX + 11):
        t = abs(x - CX) / 10.0
        # deeper at the sides, shallower in the middle
        limit = top + depth + int(t * t * 7)
        if d == "up":
            limit = top + 15
        for y in range(top - 3, limit + 1):
            dx = (x - CX) / 9.2
            dy = (y - (top + 8)) / 9.0
            if dx * dx + dy * dy > 1.0:
                continue
            lv = 1
            if dy < -0.5:
                lv = 2
            if dx < -0.3 and dy < -0.1:
                lv = 3
            if dx > 0.45:
                lv = 0
            c.set(x, y, r.at(lv))


def _spike(c: Canvas, r: Ramp, bx: int, by: int, tipx: int, tipy: int,
           width: int) -> None:
    steps = max(abs(tipy - by), 1)
    for i in range(steps + 1):
        t = i / steps
        x = bx + (tipx - bx) * t
        y = by + (tipy - by) * t
        w = max(1, int(width * (1.0 - t) + 0.5))
        for k in range(w):
            c.set(int(x - w * 0.5 + k), int(y), r.at(3 if k == 0 else 1))


def draw_hair_back(c: Canvas, spec: CharSpec, d: str, lift: int, R: dict) -> None:
    style = spec.hair_style
    r: Ramp = R["hair"]
    top = BT.HEAD_TOP - lift
    if style == "long":
        length = 20
        for y in range(top + 6, top + 6 + length):
            t = (y - top - 6) / float(length)
            w = int(11 - t * 3)
            for x in range(CX - w, CX + w + 1):
                lv = 1
                if x < CX - w + 2:
                    lv = 2
                elif x > CX + w - 3:
                    lv = 0
                c.set(x, y, r.at(lv))
        for x in range(CX - 8, CX + 9):
            c.set(x, top + 6 + length, r.at(0))
    elif style == "ponytail":
        tx = CX + (11 if d != "left" else -11)
        for i in range(15):
            w = 4 if i < 10 else 3
            for k in range(w):
                c.set(tx - w // 2 + k, top + 10 + i, r.at(2 if k == 0 else 1))
        c.set(tx, top + 25, r.at(0))
    elif style == "wild":
        shade_ellipse(c, CX, top + 13, 11.0, 11.0, r)
    elif style == "star":
        shade_ellipse(c, CX, top + 8, 10.5, 9.0, r)


def draw_hair_front(c: Canvas, spec: CharSpec, d: str, lift: int, R: dict) -> None:
    style = spec.hair_style
    if style == "bald":
        return
    r: Ramp = R["hair"]
    ra: Ramp = R["hair2"]
    top = BT.HEAD_TOP - lift

    if style == "star":
        edge = Ramp(mix(rgb(spec.hair), rgb("7c2c70"), 0.6))
        _skull(c, r, d, lift, 7)
        spikes = [(-14, -6), (-10, -13), (-5, -17), (1, -17), (7, -13), (12, -6)]
        for i, (tx, ty) in enumerate(spikes):
            _spike(c, r if i % 2 == 0 else edge,
                   CX + tx // 2, top + 7, CX + tx, top + 7 + ty, 5)
        if d != "up":
            blond = ra if spec.hair2 else Ramp("f2d24a")
            for bx, ty in ((-8, -9), (-3, -12), (2, -10), (7, -7)):
                _spike(c, blond, CX + bx, top + 10, CX + bx - 1, top + 10 + ty, 4)
            for sx in (-10, 8):
                for i in range(8):
                    c.set(CX + sx, top + 6 + i, blond.at(2 if i < 2 else 1))
                    c.set(CX + sx + 1, top + 6 + i, blond.at(1))
    elif style == "spiky":
        _skull(c, r, d, lift, 6)
        for i in range(8):
            bx = CX - 10 + i * 3
            h = 6 + (i % 3) * 3
            _spike(c, r if i % 2 == 0 else ra, bx, top + 4, bx + 1, top + 4 - h, 4)
    elif style == "wild":
        _skull(c, r, d, lift, 8)
        rng = Rng(seed_of(spec.key))
        for i in range(10):
            t = i / 9.0
            bx = CX - 10 + int(t * 20)
            base = top + 3 + int(abs(t - 0.5) * 5)
            h = rng.irange(4, 8)
            lean = int((t - 0.5) * 8)
            _spike(c, r if i % 2 else ra, bx, base, bx + lean, base - h, 4)
        if d != "up":
            for sx in (-10, 9):
                for i in range(rng.irange(6, 10)):
                    c.set(CX + sx, top + 8 + i, r.at(2 if sx < 0 else 1))
                    c.set(CX + sx + (1 if sx < 0 else -1), top + 8 + i, r.at(0))
    elif style == "bob":
        _skull(c, r, d, lift, 6)
        for sx in (-10, 9):
            for i in range(12):
                c.set(CX + sx, top + 5 + i, r.at(2 if sx < 0 else 0))
                c.set(CX + sx + (1 if sx < 0 else -1), top + 5 + i, r.at(1))
        if d != "up":
            for x in range(CX - 9, CX + 10):
                c.set(x, top + 6, r.at(2)); c.set(x, top + 7, r.at(1))
    elif style == "long":
        _skull(c, r, d, lift, 6)
        if d != "up":
            for x in range(CX - 9, CX - 1):
                c.set(x, top + 6, r.at(2)); c.set(x, top + 7, r.at(1))
            for x in range(CX + 2, CX + 10):
                c.set(x, top + 6, r.at(1)); c.set(x, top + 7, r.at(0))
            for sx in (-10, 9):
                for i in range(10):
                    c.set(CX + sx, top + 6 + i, r.at(2 if sx < 0 else 0))
    elif style == "flat":
        _skull(c, r, d, lift, 6)
        if d != "up":
            for x in range(CX - 9, CX + 10):
                c.set(x, top + 5, r.at(2)); c.set(x, top + 6, r.at(1))
            for i in range(5):
                c.set(CX - 10, top + 6 + i, r.at(1))
                c.set(CX + 9, top + 6 + i, r.at(0))
    else:  # short
        _skull(c, r, d, lift, 6)
        if d != "up":
            for x in range(CX - 9, CX + 10):
                c.set(x, top + 6, r.at(2))
            for i in range(4):
                c.set(CX - 10, top + 6 + i, r.at(1))
                c.set(CX + 9, top + 6 + i, r.at(0))


def draw_headgear(c: Canvas, spec: CharSpec, d: str, lift: int, R: dict) -> None:
    if not spec.headgear:
        return
    g = R["gear"]
    k = spec.headgear
    top = BT.HEAD_TOP - lift
    if k == "cap":
        shade_ellipse(c, CX, top + 5, 10.0, 6.0, g)
        for x in range(CX - 10, CX + 11):
            c.set(x, top + 4, g.at(2)); c.set(x, top + 5, g.at(1))
        brim = top + 9
        if d == "down":
            for x in range(CX - 11, CX + 12):
                c.set(x, brim, g.at(0)); c.set(x, brim + 1, g.at(0))
        elif d == "up":
            for x in range(CX - 10, CX + 11):
                c.set(x, top + 1, g.at(0))
        else:
            for x in range(CX + 2, CX + 13):
                c.set(x, brim, g.at(0)); c.set(x, brim + 1, g.at(0))
    elif k == "band":
        for x in range(CX - 10, CX + 11):
            c.set(x, top + 6, g.at(2)); c.set(x, top + 7, g.at(1))
            c.set(x, top + 8, g.at(0))
        for x in range(CX - 8, CX + 9, 3):
            c.set(x, top + 7, rgb("f4f4f8"))
        for i in range(10):
            c.set(CX - 11, top + 9 + i, g.at(1))
            c.set(CX - 10, top + 9 + i, g.at(0))
    elif k == "hood":
        shade_ellipse(c, CX, top + 9, 12.0, 11.5, g)
        for y in range(top + 4, top + 18):
            for x in range(CX - 8, CX + 9):
                dx, dy = (x - CX) / 8.0, (y - top - 11) / 7.5
                if dx * dx + dy * dy <= 1.0:
                    c.set(x, y, rgb("140f1c"))
        for x in range(CX - 12, CX + 13):
            c.set(x, top + 18, g.at(1)); c.set(x, top + 19, g.at(0))
    elif k == "egypt":
        for x in range(CX - 10, CX + 11):
            c.set(x, top + 3, g.at(2)); c.set(x, top + 4, g.at(1))
            c.set(x, top + 5, rgb("f0d060")); c.set(x, top + 6, rgb("b89830"))
        for sx in (-11, 10):
            for i in range(13):
                c.set(CX + sx, top + 7 + i, g.at(2 if sx < 0 else 0))
                c.set(CX + sx + (1 if sx < 0 else -1), top + 7 + i, g.at(1))
        if d == "down":
            _spike(c, Ramp("f0d060"), CX, top + 4, CX, top - 2, 5)
    elif k == "crown":
        for x in range(CX - 9, CX + 10):
            c.set(x, top + 2, rgb("f0d060")); c.set(x, top + 3, rgb("c8a020"))
        for i in range(4):
            _spike(c, Ramp("f0d060"), CX - 7 + i * 5, top + 2,
                   CX - 7 + i * 5, top - 3, 4)


def draw_face_extras(c: Canvas, spec: CharSpec, d: str, lift: int) -> None:
    """Shades and headphones sit over the template's eyes."""
    top = BT.HEAD_TOP - lift
    ey = top + 9
    if d == "up":
        return
    if spec.accessory == "shades":
        for x in range(CX - 10, CX + 11):
            c.set(x, ey, rgb("14141c")); c.set(x, ey + 1, rgb("1e1e2a"))
            c.set(x, ey + 2, rgb("14141c")); c.set(x, ey + 3, rgb("101018"))
        for x in range(CX - 9, CX - 4):
            c.set(x, ey + 1, rgb("6a6a8c"))
    elif spec.accessory == "headphones":
        for sx in (-12, 10):
            for i in range(9):
                c.set(CX + sx, ey - 3 + i, rgb("24242e"))
                c.set(CX + sx + 1, ey - 3 + i, rgb("34343f"))
            c.set(CX + sx + 1, ey, rgb("58a8e0"))
        for x in range(CX - 11, CX + 12):
            c.set(x, top + 2, rgb("24242e"))


def draw_chest_item(c: Canvas, spec: CharSpec, d: str, lift: int) -> None:
    a = spec.accessory
    if d == "up" or a in ("", "shades", "headphones"):
        return
    gold = Ramp("e8c246")
    by = BT.BODY_TOP - lift
    if a == "puzzle":
        for x in range(CX - 6, CX + 7):
            c.set(x, by + 1, rgb("9a7c28"))
        for i in range(9):
            w = 11 - i
            for k in range(w):
                x = CX - w // 2 + k
                lv = 3 if k == 0 else (2 if k < w // 3 else 1)
                c.set(x, by + 3 + i, gold.at(lv))
        c.set(CX - 1, by + 6, gold.at(0))
        c.set(CX, by + 6, rgb("fff0b0"))
        c.set(CX + 1, by + 6, gold.at(0))
    elif a == "ring":
        for x in range(CX - 5, CX + 6):
            c.set(x, by + 1, rgb("9a7c28"))
        for y in range(by + 3, by + 12):
            for x in range(CX - 5, CX + 6):
                dx, dy = (x - CX) / 5.0, (y - by - 7) / 4.5
                dd = dx * dx + dy * dy
                if 0.35 <= dd <= 1.0:
                    c.set(x, y, gold.at(2 if dx < 0 else 1))
        for i in range(5):
            c.set(CX - 4 + i * 2, by + 12, gold.at(1))
            c.set(CX - 4 + i * 2, by + 13, gold.at(0))
    elif a == "necklace":
        for x in range(CX - 6, CX + 7):
            c.set(x, by + 1, rgb("9a7c28"))
        for i in range(6):
            for k in range(9):
                c.set(CX - 4 + k, by + 3 + i, gold.at(2 if k < 3 else 1))
        for i in range(3):
            for k in range(3):
                c.set(CX - 1 + k, by + 5 + i, rgb("2a3a80"))
    elif a == "rod":
        hx = CX + (12 if d != "left" else -12)
        for i in range(16):
            c.set(hx, by + 2 + i, gold.at(2))
            c.set(hx + 1, by + 2 + i, gold.at(0))
        shade_ellipse(c, hx, by, 3.0, 3.0, gold)


def draw_coat(c: Canvas, spec: CharSpec, d: str, lift: int, R: dict) -> None:
    if not spec.coat:
        return
    co: Ramp = R["coat"]
    by = BT.BODY_TOP - lift
    tail = 20
    if d == "up":
        for yy in range(tail):
            for xx in range(22):
                x = CX - 11 + xx
                lv = 2 if xx < 3 else (0 if xx > 18 else 1)
                if yy == tail - 1:
                    lv = 0
                c.set(x, by + yy, co.at(lv))
    else:
        # an open coat: two narrow panels that flare outward, framing the
        # torso rather than covering it
        for side, x0 in ((-1, CX - 11), (1, CX + 8)):
            for yy in range(tail):
                flare = 1 if yy > tail - 7 else 0
                for xx in range(3 + flare):
                    x = x0 + xx - (flare if side < 0 else 0)
                    lv = 2 if side < 0 else 0
                    if xx == 0 and side < 0:
                        lv = 3
                    if yy == tail - 1:
                        lv = 0
                    c.set(x, by + yy, co.at(lv))
        # collar only, so the chest and any Millennium item stay visible
        for xx in range(21):
            x = CX - 10 + xx
            c.set(x, by, co.at(2))
            if xx < 5 or xx > 15:
                c.set(x, by + 1, co.at(1))
                c.set(x, by + 2, co.at(1 if xx < 10 else 0))


def draw_duel_disk(c: Canvas, spec: CharSpec, d: str, lift: int, step: int,
                   R: dict) -> None:
    if not spec.duel_disk or d == "up":
        return
    disk = R["disk"]
    arm = (0, -1, 0, 1)[step]
    by = BT.BODY_TOP - lift
    ax = CX - 12 if d != "right" else CX + 9
    ay = by + 9 + arm
    for yy in range(4):
        for xx in range(4):
            lv = 2 if yy == 0 else (0 if yy == 3 else 1)
            c.set(ax + xx, ay + yy, disk.at(lv))
    blade_dir = -1 if d != "right" else 1
    bx = ax + (0 if blade_dir < 0 else 3)
    for i in range(4):
        x = bx + blade_dir * i
        for k in range(2):
            c.set(x, ay - 1 - k, disk.at(2 if k else 1))
        if i < 3:
            c.set(x, ay - 3, rgb("8ad8ff"))


def draw_extras(c: Canvas, spec: CharSpec, d: str, lift: int, R: dict) -> None:
    by = BT.BODY_TOP - lift
    if spec.scarf:
        sc = Ramp(spec.scarf)
        for xx in range(16):
            c.set(CX - 8 + xx, by - 1, sc.at(2 if xx < 8 else 1))
            c.set(CX - 8 + xx, by, sc.at(1 if xx < 8 else 0))
        if d != "up":
            for i in range(8):
                c.set(CX + 4, by + 2 + i, sc.at(1))
                c.set(CX + 5, by + 2 + i, sc.at(0))
    if spec.belt:
        bl: Ramp = R["belt"]
        for xx in range(15):
            c.set(CX - 7 + xx, by + 8, bl.at(2 if xx < 7 else 1))
            c.set(CX - 7 + xx, by + 9, bl.at(0))
        c.set(CX, by + 8, rgb("e8c246"))
        c.set(CX + 1, by + 8, rgb("b8902a"))


# =====================================================================
# assembly
# =====================================================================

def draw_body(c: Canvas, spec: CharSpec, d: str, step: int) -> None:
    R = spec.ramps()
    lift = min(spec.tall, 3)

    # ground contact shadow
    for yy in range(2):
        for xx in range(-7, 8):
            dx = xx / 7.0
            dy = (yy - 0.5) / 1.6
            if dx * dx + dy * dy <= 1.0:
                c.set(CX + xx, 41 + yy, (12, 10, 22, 90))

    draw_hair_back(c, spec, d, lift, R)
    _paint(c, spec, d, step, R)
    draw_coat(c, spec, d, lift, R)
    draw_extras(c, spec, d, lift, R)
    draw_face_extras(c, spec, d, lift)
    draw_hair_front(c, spec, d, lift, R)
    draw_headgear(c, spec, d, lift, R)
    draw_chest_item(c, spec, d, lift)
    draw_duel_disk(c, spec, d, lift, step, R)


def render_sheet(spec: CharSpec) -> Canvas:
    sheet = Canvas(FW * 4, FH * 4)
    for row, d in enumerate(DIRS):
        for step in range(4):
            f = Canvas(FW, FH)
            if d == "right":
                g = Canvas(FW, FH)
                draw_body(g, spec, "left", step)
                f = g.flip_h()
            else:
                draw_body(f, spec, d, step)
            sheet.blit(f, step * FW, row * FH)
    return sheet


def render_portrait(spec: CharSpec, size: int = 96) -> Canvas:
    c = Canvas(size, size)
    small = Canvas(FW, FH)
    draw_body(small, spec, "down", 0)
    lift = min(spec.tall, 3)
    crop = small.sub(1, max(0, BT.HEAD_TOP - lift - 4), 30, 28)
    scale = max(1, size // 30)
    ox = (size - crop.w * scale) // 2
    for y in range(crop.h):
        for x in range(crop.w):
            col = crop.px[y][x]
            if col[3] == 0:
                continue
            for dy in range(scale):
                for dx in range(scale):
                    c.set(ox + x * scale + dx, 3 + y * scale + dy, col)
    return c
