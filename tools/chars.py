"""Overworld character sprites in the Pokemon Gen-5 idiom.

Three things decide whether a 32px character is recognisable, and none of
them is colour:

  1. the build — a child, a lanky teen and a broad adult must not share one
     doll shape (see body_template.BUILDS),
  2. the silhouette — hair volume, coats and robes have to break the body
     outline, because that outline is all you see while walking,
  3. contrast — the ramp in shade.py is deliberately wide so the shading
     still reads after the sprite is scaled down.

Yu-Gi-Oh signifiers ride on the same system: Duel Disks on the forearm,
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
    outfit: str = ""          # "", "coat", "robe", "cape"
    accessory: str = ""
    eyes: str = "3a2a55"
    tall: int = 0
    build: str = "teen"
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


def _paint(c: Canvas, spec: CharSpec, d: str, step: int, R: dict, M: dict,
           rows: list) -> None:
    pal = _palette(spec, R)
    lift = min(spec.tall, 3)
    swing = (0, 1, 0, -1)[step]
    arm = (0, -1, 0, 1)[step]
    leg_rows = M["leg_rows"]
    arm_rows = M["arm_rows"]

    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "." or ch not in pal:
                continue
            dy = 0
            if y in leg_rows:
                dy = swing if x < CX else -swing
            elif y in arm_rows and ch == "K":
                dy = arm if x < CX else -arm
            c.set(x, y + dy - lift, pal[ch])

    if spec.skirt:
        bot: Ramp = R["bottom"]
        sy = M["leg_rows"].start - 2
        for i in range(7):
            w = 5 + i
            for k in range(w * 2):
                x = CX - w + k
                lv = 2 if k < 3 else (0 if k > w * 2 - 4 else 1)
                c.set(x, sy + i - lift, bot.at(lv))
        sk: Ramp = R["skin"]
        shr: Ramp = R["shoes"]
        base = sy + 7
        for i, dxx in enumerate((-5, 2)):
            o = swing if i == 0 else -swing
            legh = max(1, 2 + o)
            for k in range(legh):
                for w in range(3):
                    c.set(CX + dxx + w, base + k - lift, sk.at(1 if w else 2))
            for w in range(3):
                c.set(CX + dxx + w, base + legh - lift, shr.at(1))
                c.set(CX + dxx + w, base + legh + 1 - lift, shr.at(0))


# =====================================================================
# hair
# =====================================================================

def _geom(M: dict, lift: int) -> tuple:
    """(crown row, eye row, half width, head height) for the current build."""
    return (M["head_top"] - lift, M["eye_row"] - lift,
            M["head_hw"], M["head_h"])


def _skull(c: Canvas, r: Ramp, d: str, M: dict, lift: int, hl: int) -> None:
    """Hair cap hugging the drawn skull, cut off at the hairline row `hl`.

    The hairline is not a flat cut — it sits high over the forehead and drops
    down past the temples, which is what stops it reading as a helmet. `hl` is
    an absolute row so every build keeps the same amount of visible face.
    """
    top, eye, hw, hh = _geom(M, lift)
    cy = top + hh * 0.42
    for x in range(CX - hw - 1, CX + hw + 1):
        t = abs(x - CX + 0.5) / float(hw)
        limit = hl + int(t * t * (hh * 0.55))
        if d == "up":
            limit = top + hh
        for y in range(top - 4, limit + 1):
            dx = (x - CX + 0.5) / (hw + 0.7)
            dy = (y - cy) / (hh * 0.56)
            if dx * dx + dy * dy > 1.0:
                continue
            lv = 1
            if dy < -0.45:
                lv = 2
            if dx < -0.3 and dy < -0.1:
                lv = 3
            if dx > 0.45:
                lv = 0
            c.set(x, y, r.at(lv))


def _spike(c: Canvas, r: Ramp, bx: int, by: int, tipx: int, tipy: int,
           width: int) -> None:
    """A tapering lock of hair. Kept mostly in the base tone — a bright rim
    on every spike turns a head of hair into a silver crown."""
    steps = max(abs(tipy - by), abs(tipx - bx), 1)
    for i in range(steps + 1):
        t = i / steps
        x = bx + (tipx - bx) * t
        y = by + (tipy - by) * t
        w = max(1, int(width * (1.0 - t) + 0.5))
        for k in range(w):
            lv = 2 if (k == 0 and w > 2) else 1
            c.set(int(x - w * 0.5 + k), int(y), r.at(lv))
            c.set(int(x - w * 0.5 + k), int(y) + 1, r.at(0 if k == w - 1 else lv))


def _fringe(c: Canvas, r: Ramp, M: dict, lift: int, hl: int,
            teeth: tuple = (), depth: int = 2) -> None:
    """Two rows of hair on the hairline plus optional pointed strands."""
    _, eye, hw, _ = _geom(M, lift)
    for x in range(CX - hw, CX + hw):
        c.set(x, hl, r.at(2))
        c.set(x, hl + 1, r.at(1))
    for xo in teeth:
        for k in range(depth):
            for w in range(3 - k):
                c.set(CX + xo + w, hl + 2 + k, r.at(1 if k == 0 else 0))


def _side_locks(c: Canvas, r: Ramp, M: dict, lift: int, hl: int, length: int,
                width: int = 2, flare: int = 0) -> None:
    """Hair falling past the temples — the cheapest way to widen a head."""
    _, _, hw, _ = _geom(M, lift)
    for side in (-1, 1):
        for i in range(length):
            spread = int(i * flare / max(1, length))
            for k in range(width):
                x = CX + side * (hw - k + spread) - (1 if side < 0 else 0)
                lv = 2 if side < 0 else 0
                if k == width - 1:
                    lv = max(0, lv - 1)
                c.set(x, hl + i, r.at(lv))


def _jag_cap(c: Canvas, r: Ramp, ra: Ramp, M: dict, lift: int, hl: int,
             amp: int, spread: int, seed: str, step: int = 3) -> None:
    """A connected mass of spiky hair.

    Drawing separate spikes and outlining them turns a head of hair into a
    comb, because every gap gets its own keyline. So the spikes are generated
    as one jagged upper profile and the whole area below it is filled.
    """
    top, eye, hw, hh = _geom(M, lift)
    rng = Rng(seed_of(seed))
    xs = list(range(CX - hw - spread, CX + hw + spread + 1))
    peaks = [rng.irange(0, amp) for _ in range(len(xs) // step + 2)]
    for i, x in enumerate(xs):
        g, f = divmod(i, step)
        h = peaks[g] + (peaks[g + 1] - peaks[g]) * f / float(step)
        t = (x - CX + 0.5) / float(hw + spread)
        crown = top + 1 + int(abs(t) * 5) - int(h)
        limit = hl + int(t * t * (hh * 0.7))
        for y in range(crown, limit + 1):
            lv = 1
            if y < crown + 2:
                lv = 2
            if t < -0.3 and y < crown + 4:
                lv = 3
            elif t > 0.4:
                lv = 0
            c.set(x, y, (r if (g % 2 == 0) else ra).at(lv))


def draw_hair_back(c: Canvas, spec: CharSpec, d: str, M: dict, lift: int,
                   R: dict) -> None:
    style = spec.hair_style
    r: Ramp = R["hair"]
    top, eye, hw, hh = _geom(M, lift)
    if style in ("long", "veil", "sidelong"):
        length = 22 if style != "veil" else 24
        for y in range(top + 4, top + 4 + length):
            t = (y - top - 4) / float(length)
            w = int(hw + 2 - t * (2 if style == "veil" else 4))
            for x in range(CX - w, CX + w + 1):
                lv = 1
                if x < CX - w + 2:
                    lv = 2
                elif x > CX + w - 3:
                    lv = 0
                c.set(x, y, r.at(lv))
        for x in range(CX - hw + 1, CX + hw):
            c.set(x, top + 4 + length, r.at(0))
    elif style == "wave":
        # big volume that reaches well past the shoulders on both sides
        length = 24
        for y in range(top + 3, top + 3 + length):
            t = (y - top - 3) / float(length)
            w = int(hw + 1 + t * 4 - (t * t) * 3)
            for x in range(CX - w, CX + w + 1):
                lv = 1
                if x < CX - w + 3:
                    lv = 2
                elif x > CX + w - 3:
                    lv = 0
                c.set(x, y, r.at(lv))
        for i, x in enumerate(range(CX - hw - 4, CX + hw + 5)):
            c.set(x, top + 3 + length + (i % 2), r.at(0))
    elif style == "mane":
        shade_ellipse(c, CX - 0.5, top + 8, hw + 4.0, hw + 3.0, r)
        for i in range(12):
            t = i / 11.0
            sx = CX - hw - 3 + int(t * (hw * 2 + 6))
            _spike(c, r, sx, eye + 2, sx + int((t - 0.5) * 10),
                   eye + 8 + int(abs(t - 0.5) * 8), 3)
    elif style == "ponytail":
        tx = CX + (hw + 2 if d != "left" else -hw - 2)
        for i in range(16):
            w = 4 if i < 11 else 3
            for k in range(w):
                c.set(tx - w // 2 + k, top + 6 + i, r.at(2 if k == 0 else 1))
        c.set(tx, top + 22, r.at(0))
    elif style in ("wild", "shag"):
        shade_ellipse(c, CX - 0.5, top + 8, hw + 2.0, hw + 1.5, r)
    elif style == "star":
        shade_ellipse(c, CX - 0.5, top + 6, hw + 1.0, hw - 1.0, r)


def draw_hair_front(c: Canvas, spec: CharSpec, d: str, M: dict, lift: int,
                    R: dict) -> None:
    style = spec.hair_style
    if style == "bald":
        return
    r: Ramp = R["hair"]
    ra: Ramp = R["hair2"]
    top, eye, hw, hh = _geom(M, lift)
    hl = eye - 3          # hairline: two rows of hair, one row of forehead

    if style == "star":
        edge = Ramp(mix(rgb(spec.hair), rgb("7c2c70"), 0.55))
        _skull(c, r, d, M, lift, hl)
        # five big black points — the single most recognisable outline in the
        # whole franchise, so they get to leave the head by a long way
        spikes = [(-15, -1), (-13, -5), (-7, -7), (1, -7), (8, -5), (14, -1)]
        for tx, ty in spikes:
            _spike(c, r, CX + tx // 2, top + 4, CX + tx, top + 4 + ty, 7)
        for tx, ty in spikes[1:5]:
            _spike(c, edge, CX + tx - (1 if tx < 0 else -1), top + 6 + ty,
                   CX + tx, top + 4 + ty, 3)
        if d != "up":
            blond = ra if spec.hair2 else Ramp("f2d24a")
            # the bangs hang DOWN over the forehead — they are not spikes,
            # and they stop at the brow so the eyes stay visible
            for bx, ln in ((-9, 3), (-6, 4), (-2, 4), (2, 3)):
                for i in range(ln):
                    for k in range(3):
                        lv = 2 if k == 0 else (0 if i == ln - 1 else 1)
                        c.set(CX + bx + k, hl - 1 + i, blond.at(lv))
            for sx in (-hw, hw - 2):
                for i in range(9):
                    c.set(CX + sx, hl - 1 + i, blond.at(2 if sx < 0 else 1))
                    c.set(CX + sx + 1, hl - 1 + i, blond.at(1 if sx < 0 else 0))
    elif style == "spiky":
        _skull(c, r, d, M, lift, hl)
        _jag_cap(c, r, ra, M, lift, hl, 6, 1, spec.key, step=2)
        if d != "up":
            _fringe(c, r, M, lift, hl, teeth=(-7, -1, 4))
    elif style == "shag":
        _skull(c, r, d, M, lift, hl)
        _jag_cap(c, r, ra, M, lift, hl, 3, 2, spec.key, step=4)
        _side_locks(c, r, M, lift, hl, 11, 3, flare=2)
        if d != "up":
            _fringe(c, ra, M, lift, hl, teeth=(-8, -4, 1, 5), depth=3)
    elif style == "wild":
        _skull(c, r, d, M, lift, hl + 1)
        _jag_cap(c, r, ra, M, lift, hl + 1, 5, 2, spec.key)
        if d != "up":
            _side_locks(c, r, M, lift, hl + 2, 7, 2, flare=2)
    elif style == "mane":
        _skull(c, r, d, M, lift, hl)
        _jag_cap(c, r, ra, M, lift, hl, 4, 5, spec.key, step=4)
        if d != "up":
            _side_locks(c, r, M, lift, hl, 14, 3, flare=4)
            _fringe(c, r, M, lift, hl, teeth=(-6, 0, 4))
    elif style == "wave":
        _skull(c, r, d, M, lift, hl)
        if d != "up":
            _fringe(c, r, M, lift, hl, teeth=(-7, 3))
            for i in range(4):
                c.set(CX - hw + 1 + i, hl + 2 + i, r.at(1))
                c.set(CX + hw - 2 - i, hl + 2 + i, r.at(0))
        _side_locks(c, r, M, lift, hl, 14, 3, flare=4)
    elif style == "bowl":
        _skull(c, r, d, M, lift, hl + 1)
        if d != "up":
            for x in range(CX - hw - 1, CX + hw + 1):
                c.set(x, hl + 1, r.at(2))
                c.set(x, hl + 2, r.at(1))
                c.set(x, hl + 3, r.at(0))
    elif style == "bob":
        _skull(c, r, d, M, lift, hl)
        _side_locks(c, r, M, lift, hl, 12, 2, flare=1)
        if d != "up":
            _fringe(c, r, M, lift, hl, teeth=(-6, 2))
    elif style == "veil":
        _skull(c, r, d, M, lift, hl)
        _side_locks(c, r, M, lift, hl, 18, 3)
        if d != "up":
            _fringe(c, r, M, lift, hl)
    elif style == "sidelong":
        _skull(c, r, d, M, lift, hl)
        _side_locks(c, r, M, lift, hl, 16, 3, flare=1)
        if d != "up":
            # a curtain of hair over one eye — Pegasus in one gesture
            for i in range(7):
                for k in range(3):
                    c.set(CX - hw + 1 + i, hl + i + k, r.at(2 - k))
            for x in range(CX - 1, CX + hw):
                c.set(x, hl, r.at(1))
                c.set(x, hl + 1, r.at(0))
    elif style == "long":
        _skull(c, r, d, M, lift, hl)
        _side_locks(c, r, M, lift, hl, 12, 2, flare=2)
        if d != "up":
            for x in range(CX - hw, CX - 1):
                c.set(x, hl, r.at(2))
                c.set(x, hl + 1, r.at(1))
            for x in range(CX + 1, CX + hw):
                c.set(x, hl, r.at(1))
                c.set(x, hl + 1, r.at(0))
    elif style == "flat":
        _skull(c, r, d, M, lift, hl)
        if d != "up":
            _fringe(c, r, M, lift, hl, teeth=(-7, -2, 3), depth=2)
            _side_locks(c, r, M, lift, hl, 8, 2)
    else:  # short
        _skull(c, r, d, M, lift, hl)
        if d != "up":
            for x in range(CX - hw, CX + hw):
                c.set(x, hl, r.at(2))
            _side_locks(c, r, M, lift, hl, 5, 2)


def draw_headgear(c: Canvas, spec: CharSpec, d: str, M: dict, lift: int,
                  R: dict) -> None:
    if not spec.headgear:
        return
    g = R["gear"]
    k = spec.headgear
    top, eye, hw, hh = _geom(M, lift)
    hl = eye - 3
    if k == "cap":
        shade_ellipse(c, CX - 0.5, top + 3, hw + 0.5, 5.0, g)
        for x in range(CX - hw, CX + hw):
            c.set(x, top + 2, g.at(2))
            c.set(x, top + 3, g.at(1))
        brim = hl
        if d == "down":
            for x in range(CX - hw - 2, CX + hw + 2):
                c.set(x, brim, g.at(0))
                c.set(x, brim + 1, g.at(0))
        elif d == "up":
            for x in range(CX - hw, CX + hw):
                c.set(x, top, g.at(0))
        else:
            for x in range(CX + 2, CX + hw + 5):
                c.set(x, brim, g.at(0))
                c.set(x, brim + 1, g.at(0))
    elif k == "band":
        for x in range(CX - hw - 1, CX + hw + 1):
            c.set(x, hl, g.at(2))
            c.set(x, hl + 1, g.at(1))
        for x in range(CX - hw + 1, CX + hw, 3):
            c.set(x, hl + 1, rgb("f4f4f8"))
        for i in range(10):
            c.set(CX - hw - 2, hl + 2 + i, g.at(1))
            c.set(CX - hw - 1, hl + 2 + i, g.at(0))
    elif k == "hood":
        shade_ellipse(c, CX - 0.5, top + 7, hw + 3.0, hw + 2.5, g)
        for y in range(top + 2, eye + 5):
            for x in range(CX - hw, CX + hw):
                dx = (x - CX + 0.5) / float(hw - 1)
                dy = (y - top - hh * 0.5) / (hh * 0.46)
                if dx * dx + dy * dy <= 1.0:
                    c.set(x, y, rgb("140f1c"))
        by = M["body_top"] - lift
        for x in range(CX - hw - 4, CX + hw + 4):
            c.set(x, by - 2, g.at(1))
            c.set(x, by - 1, g.at(0))
    elif k == "egypt":
        for x in range(CX - hw, CX + hw):
            c.set(x, hl - 2, g.at(2))
            c.set(x, hl - 1, g.at(1))
            c.set(x, hl, rgb("f0d060"))
            c.set(x, hl + 1, rgb("b89830"))
        for sx in (-hw - 1, hw):
            for i in range(13):
                c.set(CX + sx, hl + 2 + i, g.at(2 if sx < 0 else 0))
                c.set(CX + sx + (1 if sx < 0 else -1), hl + 2 + i, g.at(1))
        if d == "down":
            _spike(c, Ramp("f0d060"), CX, hl - 1, CX, top - 3, 5)
    elif k == "crown":
        for x in range(CX - hw + 1, CX + hw):
            c.set(x, top + 1, rgb("f0d060"))
            c.set(x, top + 2, rgb("c8a020"))
        for i in range(4):
            _spike(c, Ramp("f0d060"), CX - 7 + i * 5, top + 1,
                   CX - 7 + i * 5, top - 4, 4)


def draw_face_extras(c: Canvas, spec: CharSpec, d: str, M: dict,
                     lift: int) -> None:
    """Shades, glasses and headphones sit over the template's eyes."""
    top, eye, hw, hh = _geom(M, lift)
    if d == "up":
        return
    if spec.accessory == "shades":
        for x in range(CX - hw, CX + hw):
            c.set(x, eye - 1, rgb("14141c"))
            c.set(x, eye, rgb("1e1e2a"))
            c.set(x, eye + 1, rgb("14141c"))
            c.set(x, eye + 2, rgb("101018"))
        for x in range(CX - hw + 1, CX - hw + 5):
            c.set(x, eye, rgb("6a6a8c"))
    elif spec.accessory == "glasses":
        rim = rgb("2a2a34")
        for x in range(CX - hw, CX + hw):
            c.set(x, eye - 2, rim)
            c.set(x, eye + 3, rim)
        for x in (CX - hw, CX - hw + 5, CX - 1, CX + 1, CX + hw - 6, CX + hw - 1):
            for i in range(6):
                c.set(x, eye - 2 + i, rim)
        # a flash of white across the lenses hides the eyes entirely
        for x in range(CX - hw + 1, CX - hw + 5):
            for i in range(3):
                c.set(x, eye - 1 + i, rgb("cfe4f4"))
        for x in range(CX + hw - 5, CX + hw - 1):
            for i in range(3):
                c.set(x, eye - 1 + i, rgb("aac6dc"))
    elif spec.accessory == "headphones":
        for sx in (-hw - 2, hw):
            for i in range(9):
                c.set(CX + sx, eye - 4 + i, rgb("24242e"))
                c.set(CX + sx + 1, eye - 4 + i, rgb("34343f"))
            c.set(CX + sx + 1, eye - 1, rgb("58a8e0"))
        for x in range(CX - hw - 1, CX + hw + 1):
            c.set(x, top + 1, rgb("24242e"))


def draw_chest_item(c: Canvas, spec: CharSpec, d: str, M: dict,
                    lift: int) -> None:
    a = spec.accessory
    if d == "up" or a in ("", "shades", "glasses", "headphones"):
        return
    gold = Ramp("e8c246")
    by = M["body_top"] - lift
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


def draw_outfit(c: Canvas, spec: CharSpec, d: str, M: dict, lift: int,
                R: dict) -> None:
    """Clothing that changes the outline, not just the fill colour."""
    kind = spec.outfit or ("coat" if spec.coat else "")
    if not kind:
        return
    co: Ramp = R["coat"]
    by = M["body_top"] - lift
    hw = M["half_w"]
    foot = M["leg_rows"].stop - lift

    if kind == "robe":
        # a wide trapezoid that swallows the legs — reads instantly as
        # "not a schoolkid"
        h = foot - by - 1
        for yy in range(h):
            t = yy / float(h)
            w = int(8 + t * (hw - 1))
            for k in range(w * 2):
                x = CX - w + k
                lv = 2 if k < 3 else (0 if k > w * 2 - 4 else 1)
                if yy == h - 1:
                    lv = 0
                c.set(x, by + yy, co.at(lv))
        for x in range(CX - 2, CX + 3):
            for yy in range(h - 2):
                c.set(x, by + yy, co.at(0))
        return

    if kind == "cape":
        h = foot - by - 6
        for yy in range(h):
            t = yy / float(h)
            w = int(hw - 2 + t * 4)
            for k in range(w * 2):
                x = CX - w + k
                if 6 < k < w * 2 - 7 and yy < h - 2:
                    continue
                lv = 2 if k < 3 else (0 if k > w * 2 - 4 else 1)
                c.set(x, by + yy, co.at(lv))
        return

    # coat: long panels that flare well outside the body silhouette
    tail = foot - by - 5
    if d == "up":
        for yy in range(tail):
            t = yy / float(tail)
            w = int(hw - 1 + t * 3)
            for k in range(w * 2):
                x = CX - w + k
                lv = 2 if k < 3 else (0 if k > w * 2 - 4 else 1)
                if yy == tail - 1:
                    lv = 0
                c.set(x, by + yy, co.at(lv))
    else:
        for side in (-1, 1):
            for yy in range(tail):
                t = yy / float(tail)
                flare = int(t * t * 4)
                base = hw - 1 + flare
                for xx in range(3):
                    x = CX + side * (base - xx) - (1 if side < 0 else 0)
                    lv = 2 if side < 0 else 0
                    if xx == 0 and side < 0:
                        lv = 3
                    if yy == tail - 1:
                        lv = 0
                    c.set(x, by + yy, co.at(lv))
        for xx in range(hw * 2 - 3):
            x = CX - hw + 1 + xx
            c.set(x, by - 1, co.at(2))
            if xx < 6 or xx > hw * 2 - 10:
                c.set(x, by, co.at(2 if xx < hw else 1))
                c.set(x, by + 1, co.at(1 if xx < hw else 0))


def draw_duel_disk(c: Canvas, spec: CharSpec, d: str, M: dict, lift: int,
                   step: int, R: dict) -> None:
    if not spec.duel_disk or d == "up":
        return
    disk = R["disk"]
    arm = (0, -1, 0, 1)[step]
    by = M["body_top"] - lift
    hw = M["half_w"]
    ax = CX - hw if d != "right" else CX + hw - 5
    ay = by + 8 + arm
    for yy in range(5):
        for xx in range(5):
            lv = 2 if yy == 0 else (0 if yy == 4 else 1)
            c.set(ax + xx, ay + yy, disk.at(lv))
    blade_dir = -1 if d != "right" else 1
    bx = ax + (0 if blade_dir < 0 else 4)
    for i in range(5):
        x = bx + blade_dir * i
        for k in range(2):
            c.set(x, ay - 1 - k, disk.at(2 if k else 1))
        if i < 4:
            c.set(x, ay - 3, rgb("8ad8ff"))
            c.set(x, ay - 4, rgb("3a7ab0"))


def draw_extras(c: Canvas, spec: CharSpec, d: str, M: dict, lift: int,
                R: dict) -> None:
    by = M["body_top"] - lift
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
        wy = M["leg_rows"].start - lift - 3
        for xx in range(15):
            c.set(CX - 7 + xx, wy, bl.at(2 if xx < 7 else 1))
            c.set(CX - 7 + xx, wy + 1, bl.at(0))
        c.set(CX, wy, rgb("e8c246"))
        c.set(CX + 1, wy, rgb("b8902a"))


# =====================================================================
# assembly
# =====================================================================

def draw_body(c: Canvas, spec: CharSpec, d: str, step: int) -> None:
    R = spec.ramps()
    lift = min(spec.tall, 3)
    rows, M = BT.template(d, spec.build)

    # ground contact shadow
    for yy in range(2):
        for xx in range(-7, 8):
            dx = xx / 7.0
            dy = (yy - 0.5) / 1.6
            if dx * dx + dy * dy <= 1.0:
                c.set(CX + xx, 41 + yy, (12, 10, 22, 90))

    # Everything that leaves the body outline is drawn on its own layer and
    # outlined before it is composited. Without that dark keyline hair and
    # coats dissolve into the map, which is exactly what a Gen-5 sprite
    # never does.
    def layered(fn, *a):
        lay = Canvas(FW, FH)
        fn(lay, spec, d, M, lift, *a)
        lay.outline(OUTLINE)
        c.blit(lay, 0, 0)

    layered(draw_hair_back, R)
    _paint(c, spec, d, step, R, M, rows)
    layered(draw_outfit, R)
    draw_extras(c, spec, d, M, lift, R)
    draw_face_extras(c, spec, d, M, lift)
    layered(draw_hair_front, R)
    layered(draw_headgear, R)
    draw_chest_item(c, spec, d, M, lift)

    disk = Canvas(FW, FH)
    draw_duel_disk(disk, spec, d, M, lift, step, R)
    disk.outline(OUTLINE)
    c.blit(disk, 0, 0)


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
    _, M = BT.template("down", spec.build)
    lift = min(spec.tall, 3)
    crop = small.sub(1, max(0, M["head_top"] - lift - 6), 30, 28)
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
