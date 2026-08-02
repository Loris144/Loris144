"""Colour ramps for Gen-5 style shading.

Every material is drawn from a 4-step ramp (shadow / base / light / rim)
with a fixed light direction from the upper left, which is what gives the
Pokemon B/W sprites their readable volume.
"""
from __future__ import annotations

from pixel import Color, rgb, mix


class Ramp:
    """shadow < base < light < rim, plus a matching outline colour."""

    __slots__ = ("shadow", "base", "light", "rim", "line")

    def __init__(self, base, *, warm: bool = False):
        # accepts either a hex string or an already-resolved Color
        b = rgb(base) if isinstance(base, str) else base
        # shadows drift toward blue-violet, lights toward warm yellow —
        # a cheap trick that reads as real lighting instead of grey mixing
        cool = rgb("1c1838")
        hot = rgb("fff6dc")
        self.base = b
        # the spread has to be wide: at 32px a subtle ramp reads as flat colour
        self.shadow = mix(b, cool, 0.52 if not warm else 0.44)
        self.light = mix(b, hot, 0.36)
        self.rim = mix(b, hot, 0.68)
        self.line = mix(b, rgb("120e1c"), 0.66)

    def at(self, level: int) -> Color:
        return (self.shadow, self.base, self.light, self.rim)[max(0, min(3, level))]


# shared ramps
OUTLINE = rgb("17121f")


def skin_ramp(hex_: str) -> Ramp:
    return Ramp(hex_, warm=True)


def shade_column(c, x: int, y: int, h: int, ramp: Ramp, lit: int = 1) -> None:
    """A vertical run with a lit top edge and a shadowed bottom edge."""
    for i in range(h):
        lv = lit
        if i == 0:
            lv = min(3, lit + 1)
        elif i >= h - 1:
            lv = max(0, lit - 1)
        c.set(x, y + i, ramp.at(lv))


def shade_box(c, x: int, y: int, w: int, h: int, ramp: Ramp) -> None:
    """A block with light on the top/left and shadow on the bottom/right."""
    for yy in range(h):
        for xx in range(w):
            lv = 1
            if yy == 0 or xx == 0:
                lv = 2
            if yy == h - 1 or xx == w - 1:
                lv = 0
            if yy == 0 and xx == 0:
                lv = 3
            c.set(x + xx, y + yy, ramp.at(lv))


def shade_ellipse(c, cx: float, cy: float, rx: float, ry: float,
                  ramp: Ramp, light_dx: float = -0.35,
                  light_dy: float = -0.45) -> None:
    """Filled ellipse lit from a direction — used for heads and hair."""
    for yy in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for xx in range(int(cx - rx) - 1, int(cx + rx) + 2):
            dx = (xx - cx) / rx
            dy = (yy - cy) / ry
            d = dx * dx + dy * dy
            if d > 1.0:
                continue
            # dot product with the light direction, plus a rim near the edge
            n = dx * light_dx + dy * light_dy
            if d > 0.82:
                lv = 0 if n < 0 else 2
            elif n > 0.42:
                lv = 3
            elif n > 0.10:
                lv = 2
            elif n > -0.30:
                lv = 1
            else:
                lv = 0
            c.set(xx, yy, ramp.at(lv))
