"""Overworld character sprite generator (Pokemon Gen-5 flavoured).

Every character is described by a small parameter set (hair shape + palette,
outfit colours, accessories). From that we render a 4-direction x 4-frame
walk sheet, so all cast members stay stylistically consistent.

Frame layout: 32x40 px, 4 columns (walk cycle), 4 rows (down/left/right/up).

Anatomy (y coordinates, HY = head top):
    HY+0 .. HY+14   head (ellipse r=6x7 around cx, HY+7)
    HY+14.. HY+16   neck
    HY+16.. HY+27   torso
    HY+27.. HY+35   legs
    ~38             ground shadow
Hair only ever covers the TOP half of the skull plus the sides, so the face
always stays readable.
"""
from __future__ import annotations

from dataclasses import dataclass

from pixel import Canvas, Color, Rng, rgb, seed_of, shade, mix

FW, FH = 32, 40
DIRS = ("down", "left", "right", "up")
CX = 16

OUTLINE = rgb("14101c")
EYE_WHITE = rgb("f6f6fa")


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
    cape: bool = False
    tall: int = 0
    skirt: bool = False
    scarf: str = ""
    headgear: str = ""
    headgear_col: str = "c02020"

    def col(self, name: str) -> Color:
        return rgb(getattr(self, name))


def head_top(spec: CharSpec) -> int:
    return 4 - min(spec.tall, 3) // 2


# --------------------------------------------------------------------
# hair
# --------------------------------------------------------------------


def draw_hair_back(c: Canvas, spec: CharSpec, d: str, hy: int) -> None:
    """Hair that sits BEHIND the head (long hair falling down the back)."""
    if spec.hair_style not in ("long", "ponytail", "wild", "star"):
        return
    hair = spec.col("hair")
    dk = shade(hair, 0.7)
    if spec.hair_style == "long":
        length = 16 + spec.tall
        c.rect(CX - 8, hy + 4, 16, length, hair)
        c.ellipse(CX, hy + 4 + length, 8, 4, hair)
        c.vline(CX - 8, hy + 6, length - 2, dk)
        c.vline(CX + 7, hy + 6, length - 2, dk)
    elif spec.hair_style == "ponytail":
        tx = CX + (8 if d != "left" else -9)
        c.ellipse(tx, hy + 12, 3, 9, hair)
        c.ellipse(tx, hy + 19, 3, 4, dk)
    elif spec.hair_style == "wild":
        c.ellipse(CX, hy + 12, 9, 10, hair)
    elif spec.hair_style == "star":
        c.ellipse(CX, hy + 5, 9, 7, hair)


def _cap(c: Canvas, hy: int, col: Color, limit: int) -> None:
    """Half-ellipse skull cap clipped so it never reaches the eyes."""
    for y in range(hy - 2, hy + limit + 1):
        for x in range(CX - 8, CX + 9):
            dx = (x - CX) / 7.2
            dy = (y - (hy + 6)) / 6.6
            if dx * dx + dy * dy <= 1.0:
                c.set(x, y, col)


def draw_hair_front(c: Canvas, spec: CharSpec, d: str, hy: int) -> None:
    """Skull cap + fringe, drawn AFTER the face so it frames it."""
    style = spec.hair_style
    if style == "bald":
        return
    hair = spec.col("hair")
    hi = rgb(spec.hair2) if spec.hair2 else shade(hair, 1.32)
    dk = shade(hair, 0.66)

    # --- skull cap: strictly the upper half of the head (eyes sit at hy+8)
    _cap(c, hy, hair, 6 if d != "up" else 13)
    # highlight along the crown
    c.ellipse(CX - 2, hy + 2, 4, 2, hi)

    # --- sides (framing the cheeks), skipped when seen from behind
    if d != "up":
        side_len = {"long": 11, "bob": 8, "ponytail": 6}.get(style, 4)
        c.rect(CX - 8, hy + 5, 2, side_len, hair)
        c.rect(CX + 7, hy + 5, 2, side_len, hair)
        c.vline(CX - 8, hy + 5, side_len, dk)
        c.vline(CX + 8, hy + 5, side_len, dk)
    else:
        c.ellipse(CX, hy + 8, 7, 7, hair)

    # --- style specific silhouette on top
    if style == "star":
        # Yugi / Atem: black star-shaped crown radiating outward,
        # with the signature blond bangs falling over the forehead.
        # crown spikes stay black with magenta edges; only the bangs are blond
        edge = mix(hair, rgb("7a2a6a"), 0.55)
        spikes = [(-13, 2), (-10, 8), (-5, 12), (0, 14), (5, 12), (10, 8), (13, 2)]
        for i, (sx, hgt) in enumerate(spikes):
            bx = CX + int(sx * 0.5)
            c.tri((bx - 3, hy + 4), (bx + 3, hy + 4),
                  (CX + sx, hy + 3 - hgt), hair if i % 2 == 0 else edge)
        _cap(c, hy, hair, 5)
        if d != "up":
            blond = rgb(spec.hair2) if spec.hair2 else rgb("f2d24a")
            # bangs: prongs falling over the forehead, plus temple locks
            for bx, hgt in ((-6, 6), (-2, 8), (3, 6)):
                c.tri((CX + bx - 2, hy + 7), (CX + bx + 3, hy + 7),
                      (CX + bx, hy + 7 - hgt), blond)
            c.rect(CX - 9, hy + 4, 3, 5, blond)
            c.rect(CX + 7, hy + 4, 3, 5, blond)
    elif style == "spiky":
        for i in range(7):
            bx = CX - 9 + i * 3
            h = 4 + (i % 3) * 3
            c.tri((bx - 1, hy + 3), (bx + 3, hy + 3), (bx + 1, hy + 3 - h),
                  hair if i % 2 == 0 else hi)
    elif style == "wild":
        # unruly mane: thin strands of differing length fanning outward
        r = Rng(seed_of(spec.key))
        for i in range(11):
            t = i / 10.0
            bx = CX - 9 + int(t * 18)
            base_y = hy + 4 + int(abs(t - 0.5) * 5)      # follows the skull
            h = r.irange(5, 13)
            lean = int((t - 0.5) * 11) + r.irange(-1, 1)
            c.tri((bx - 1, base_y + 1), (bx + 2, base_y + 1),
                  (bx + lean, base_y - h), hair if i % 2 else hi)
        # a couple of strands hanging past the jaw on each side
        if d != "up":
            for sx in (-9, 9):
                c.rect(CX + sx, hy + 5, 2, r.irange(6, 11), hair)
    elif style == "bob":
        c.rect(CX - 9, hy + 4, 3, 9, hair)
        c.rect(CX + 6, hy + 4, 3, 9, hair)
        if d != "up":
            c.rect(CX - 7, hy + 3, 15, 3, hair)   # straight fringe
            c.hline(CX - 6, hy + 2, 13, hi)
    elif style == "long":
        if d != "up":
            c.rect(CX - 7, hy + 3, 6, 4, hair)    # parted fringe
            c.rect(CX + 2, hy + 3, 6, 4, hair)
            c.hline(CX - 6, hy + 2, 13, hi)
    elif style == "flat":
        c.rect(CX - 7, hy + 3, 15, 3, hair)
        c.hline(CX - 6, hy + 2, 13, hi)
        if d != "up":
            c.rect(CX - 7, hy + 6, 3, 3, hair)
    else:  # short / ponytail
        c.hline(CX - 6, hy + 2, 13, hi)
        if d != "up":
            c.rect(CX - 7, hy + 4, 4, 3, hair)


def draw_headgear(c: Canvas, spec: CharSpec, d: str, hy: int) -> None:
    if not spec.headgear:
        return
    col = rgb(spec.headgear_col)
    dk = shade(col, 0.68)
    hi = shade(col, 1.25)
    g = spec.headgear
    if g == "cap":
        c.ellipse(CX, hy + 4, 8, 5, col)
        c.rect(CX - 8, hy + 3, 17, 3, col)
        c.ellipse(CX - 2, hy + 2, 3, 2, hi)
        if d == "down":
            c.rect(CX - 9, hy + 6, 19, 2, dk)      # brim toward viewer
        elif d == "up":
            c.rect(CX - 8, hy + 1, 17, 2, dk)
        else:
            c.rect(CX + (1 if d == "right" else -9), hy + 6, 9, 2, dk)
    elif g == "band":
        c.rect(CX - 8, hy + 3, 17, 4, col)
        c.hline(CX - 8, hy + 4, 17, rgb("f0f0f4"))
        c.rect(CX - 9, hy + 7, 3, 8, col)
    elif g == "hood":
        c.ellipse(CX, hy + 7, 10, 10, col)
        c.ellipse(CX, hy + 9, 7, 7, (0, 0, 0, 0))
        for y in range(hy + 3, hy + 15):
            for x in range(CX - 7, CX + 8):
                dx, dy = (x - CX) / 7.0, (y - hy - 9) / 7.0
                if dx * dx + dy * dy <= 1.0:
                    c.px[y][x] = (18, 14, 26, 235)
        c.rect(CX - 10, hy + 12, 21, 5, col)
        c.ellipse(CX - 3, hy + 1, 4, 2, hi)
    elif g == "egypt":
        # nemes-style headcloth
        c.rect(CX - 8, hy + 2, 17, 4, col)
        c.hline(CX - 8, hy + 3, 17, rgb("f0d060"))
        c.rect(CX - 10, hy + 6, 3, 11, col)
        c.rect(CX + 8, hy + 6, 3, 11, col)
        if d == "down":
            c.tri((CX - 2, hy + 2), (CX + 3, hy + 2), (CX, hy - 2), rgb("f0d060"))
    elif g == "crown":
        c.rect(CX - 7, hy + 1, 15, 3, rgb("f0d060"))
        for i in range(4):
            c.tri((CX - 6 + i * 4, hy + 1), (CX - 2 + i * 4, hy + 1),
                  (CX - 4 + i * 4, hy - 3), rgb("f0d060"))


def draw_face(c: Canvas, spec: CharSpec, d: str, hy: int) -> None:
    if d == "up":
        return
    eye = spec.col("eyes")
    skin_dk = shade(spec.col("skin"), 0.78)
    ey = hy + 8
    dark = shade(eye, 0.45)
    if d == "down":
        for ex in (CX - 5, CX + 2):
            c.rect(ex, ey, 4, 3, EYE_WHITE)        # sclera
            c.rect(ex + 1, ey, 2, 3, eye)          # iris
            c.set(ex + 1, ey + 1, dark)            # pupil
            c.set(ex + 2, ey, (255, 255, 255, 255))  # catchlight
            c.hline(ex, ey - 1, 4, dark)           # lash line
        c.hline(CX - 1, ey + 5, 3, skin_dk)        # mouth
        c.set(CX, ey + 3, skin_dk)                 # nose
    else:
        mir = 1 if d == "right" else -1
        ex = CX + (2 if d == "right" else -5)
        c.rect(ex, ey, 4, 3, EYE_WHITE)
        ix = ex + (2 if d == "right" else 0)
        c.rect(ix, ey, 2, 3, eye)
        c.set(ix, ey + 1, dark)
        c.hline(ex, ey - 1, 4, dark)
        c.set(CX + mir * 6, ey + 2, skin_dk)       # nose in profile
        c.hline(CX + mir * 3, ey + 5, 2, skin_dk)

    if spec.accessory == "shades":
        c.rect(CX - 7, ey - 1, 15, 4, rgb("12121a"))
        c.hline(CX - 7, ey, 15, rgb("4a4a66"))
    elif spec.accessory == "headphones":
        c.rect(CX - 10, ey - 3, 3, 7, rgb("26262f"))
        c.rect(CX + 8, ey - 3, 3, 7, rgb("26262f"))
        c.set(CX - 9, ey - 1, rgb("58a8e0"))
        c.set(CX + 9, ey - 1, rgb("58a8e0"))


def draw_chest_item(c: Canvas, spec: CharSpec, d: str, by: int) -> None:
    a = spec.accessory
    if d == "up" or a in ("", "shades", "headphones"):
        return
    gold = rgb("e8c246")
    gold_dk = rgb("a8862a")
    if a == "puzzle":
        c.hline(CX - 5, by, 11, gold_dk)
        c.tri((CX - 5, by + 2), (CX + 5, by + 2), (CX, by + 10), gold)
        c.tri((CX - 2, by + 4), (CX + 3, by + 4), (CX, by + 8), gold_dk)
        c.set(CX, by + 5, gold)
    elif a == "ring":
        c.hline(CX - 4, by, 9, gold_dk)
        c.circle(CX, by + 5, 4, gold)
        c.circle(CX, by + 5, 2, shade(gold, 0.4))
        for i in range(5):
            c.vline(CX - 4 + i * 2, by + 8, 3, gold_dk)
    elif a == "necklace":
        c.hline(CX - 5, by, 11, gold_dk)
        c.rect(CX - 3, by + 1, 7, 5, gold)
        c.rect(CX - 1, by + 2, 3, 3, rgb("2a3a80"))
    elif a == "rod":
        hx = CX + (9 if d != "left" else -10)
        c.vline(hx, by + 1, 13, gold)
        c.circle(hx, by, 2, gold)
        c.set(hx, by, rgb("f6e08a"))


# --------------------------------------------------------------------
# body
# --------------------------------------------------------------------


def draw_body(c: Canvas, spec: CharSpec, d: str, step: int) -> None:
    skin = spec.col("skin")
    skin_dk = shade(skin, 0.8)
    top = spec.col("top")
    top_dk = shade(top, 0.74)
    top_hi = shade(top, 1.16)
    bottom = spec.col("bottom")
    shoes = spec.col("shoes")

    hy = head_top(spec)
    by = hy + 16                      # torso top
    torso_h = 11 + spec.tall
    ly = by + torso_h                 # leg top
    leg_h = 7

    # ---- ground shadow
    c.ellipse(CX, FH - 3, 7, 2, (0, 0, 0, 75))

    # ---- hair behind the head (long hair, ponytail)
    draw_hair_back(c, spec, d, hy)

    # ---- legs, walk cycle: 0 idle, 1 left forward, 2 idle, 3 right forward
    swing = (0, 2, 0, -2)[step]
    if spec.skirt:
        c.tri((CX - 8, ly + 5), (CX + 9, ly + 5), (CX, ly - 3), bottom)
        c.rect(CX - 8, ly + 3, 17, 3, shade(bottom, 0.82))
        c.hline(CX - 8, ly + 5, 17, shade(bottom, 0.66))
        for i, dx in enumerate((-4, 1)):
            o = swing if i == 0 else -swing
            h = max(2, leg_h - 3 + o)
            c.rect(CX + dx, ly + 6, 3, h, skin)
            c.rect(CX + dx, ly + 6 + h, 3, 2, shoes)
    else:
        for i, dx in enumerate((-5, 1)):
            o = swing if i == 0 else -swing
            h = max(3, leg_h + o)
            c.rect(CX + dx, ly, 4, h, bottom)
            c.hline(CX + dx, ly, 4, shade(bottom, 1.15))
            c.rect(CX + dx, ly + h, 4, 3, shoes)

    # ---- torso
    c.rect(CX - 6, by, 13, torso_h, top)
    c.rect(CX - 6, by, 13, 2, top_hi)
    c.hline(CX - 6, by + torso_h - 1, 13, top_dk)
    c.vline(CX - 6, by, torso_h, top_dk)
    c.vline(CX + 6, by, torso_h, top_dk)
    if spec.top2:
        t2 = rgb(spec.top2)
        if d == "down":
            c.rect(CX - 2, by + 1, 5, torso_h - 1, t2)
            c.vline(CX - 2, by + 1, torso_h - 1, shade(t2, 0.8))
        elif d != "up":
            c.rect(CX - 1, by + 2, 3, torso_h - 4, t2)

    # ---- long coat (Kaiba, Marik, Pegasus...)
    if spec.coat:
        co = rgb(spec.coat)
        co_dk = shade(co, 0.7)
        co_hi = shade(co, 1.15)
        tail = torso_h + 7
        if d == "up":
            c.rect(CX - 8, by, 17, tail, co)
            c.hline(CX - 8, by + 1, 17, co_hi)
        else:
            c.rect(CX - 9, by, 4, tail, co)
            c.rect(CX + 6, by, 4, tail, co)
            c.rect(CX - 9, by, 19, 3, co)          # collar / shoulders
            c.hline(CX - 9, by, 19, co_hi)
        c.hline(CX - 9, by + tail - 1, 4, co_dk)
        c.hline(CX + 6, by + tail - 1, 4, co_dk)

    if spec.scarf:
        sc = rgb(spec.scarf)
        c.rect(CX - 6, by - 1, 13, 3, sc)
        if d != "up":
            c.rect(CX + 3, by + 2, 3, 6, shade(sc, 0.85))

    # ---- arms
    arm_c = rgb(spec.coat) if spec.coat else top
    a = (0, -1, 0, 1)[step]
    c.rect(CX - 9, by + 2 + a, 3, 7, arm_c)
    c.rect(CX + 7, by + 2 - a, 3, 7, arm_c)
    c.rect(CX - 9, by + 9 + a, 3, 3, skin)
    c.rect(CX + 7, by + 9 - a, 3, 3, skin)

    # ---- neck
    c.rect(CX - 2, hy + 13, 5, 4, skin_dk)

    # ---- head
    c.ellipse(CX, hy + 7, 6.6, 7.2, skin)
    c.ellipse(CX - 2, hy + 5, 3, 3, shade(skin, 1.07))     # light from up-left
    c.hline(CX - 4, hy + 13, 9, skin_dk)                    # chin shade

    draw_face(c, spec, d, hy)
    draw_hair_front(c, spec, d, hy)
    draw_headgear(c, spec, d, hy)
    draw_chest_item(c, spec, d, by)


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
            f.outline(OUTLINE)
            sheet.blit(f, step * FW, row * FH)
    return sheet


def render_portrait(spec: CharSpec, size: int = 96) -> Canvas:
    """Head-and-shoulders bust for dialogue boxes."""
    c = Canvas(size, size)
    small = Canvas(FW, FH)
    draw_body(small, spec, "down", 0)
    small.outline(OUTLINE)
    hy = head_top(spec)
    crop = small.sub(2, max(0, hy - 4), 28, 26)
    scale = max(1, size // 28)
    ox = (size - crop.w * scale) // 2
    for y in range(crop.h):
        for x in range(crop.w):
            col = crop.px[y][x]
            if col[3] == 0:
                continue
            for dy in range(scale):
                for dx in range(scale):
                    c.set(ox + x * scale + dx, 4 + y * scale + dy, col)
    return c
