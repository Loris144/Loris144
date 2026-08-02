"""Minimal PNG writer + pixel canvas.

No third-party imaging library is available in this environment, so we emit
PNGs by hand (zlib + struct). Everything downstream draws into a Canvas of
RGBA tuples and calls save().
"""
from __future__ import annotations

import struct
import zlib

Color = tuple[int, int, int, int]

TRANSPARENT: Color = (0, 0, 0, 0)


def _chunk(tag: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


class Canvas:
    """A mutable RGBA raster."""

    def __init__(self, w: int, h: int, fill: Color = TRANSPARENT):
        self.w = w
        self.h = h
        self.px: list[list[Color]] = [[fill for _ in range(w)] for _ in range(h)]

    # ---- primitives -------------------------------------------------

    def set(self, x: int, y: int, c: Color) -> None:
        if c[3] == 0:
            return
        if 0 <= x < self.w and 0 <= y < self.h:
            if c[3] == 255:
                self.px[y][x] = c
            else:
                self.px[y][x] = _blend(self.px[y][x], c)

    def get(self, x: int, y: int) -> Color:
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return TRANSPARENT

    def rect(self, x: int, y: int, w: int, h: int, c: Color) -> None:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.set(xx, yy, c)

    def frame(self, x: int, y: int, w: int, h: int, c: Color) -> None:
        for xx in range(x, x + w):
            self.set(xx, y, c)
            self.set(xx, y + h - 1, c)
        for yy in range(y, y + h):
            self.set(x, yy, c)
            self.set(x + w - 1, yy, c)

    def hline(self, x: int, y: int, w: int, c: Color) -> None:
        for xx in range(x, x + w):
            self.set(xx, y, c)

    def vline(self, x: int, y: int, h: int, c: Color) -> None:
        for yy in range(y, y + h):
            self.set(x, yy, c)

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, c: Color) -> None:
        if rx <= 0 or ry <= 0:
            return
        for yy in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for xx in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx = (xx - cx) / rx
                dy = (yy - cy) / ry
                if dx * dx + dy * dy <= 1.0:
                    self.set(xx, yy, c)

    def circle(self, cx: float, cy: float, r: float, c: Color) -> None:
        self.ellipse(cx, cy, r, r, c)

    def line(self, x0: int, y0: int, x1: int, y1: int, c: Color) -> None:
        dx = abs(x1 - x0)
        dy = -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            self.set(x0, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def tri(self, p0, p1, p2, c: Color) -> None:
        xs = [p0[0], p1[0], p2[0]]
        ys = [p0[1], p1[1], p2[1]]
        for yy in range(min(ys), max(ys) + 1):
            for xx in range(min(xs), max(xs) + 1):
                if _in_tri(xx, yy, p0, p1, p2):
                    self.set(xx, yy, c)

    # ---- composition ------------------------------------------------

    def blit(self, other: "Canvas", x: int, y: int) -> None:
        for yy in range(other.h):
            for xx in range(other.w):
                self.set(x + xx, y + yy, other.px[yy][xx])

    def sub(self, x: int, y: int, w: int, h: int) -> "Canvas":
        out = Canvas(w, h)
        for yy in range(h):
            for xx in range(w):
                out.px[yy][xx] = self.get(x + xx, y + yy)
        return out

    def flip_h(self) -> "Canvas":
        out = Canvas(self.w, self.h)
        for y in range(self.h):
            for x in range(self.w):
                out.px[y][self.w - 1 - x] = self.px[y][x]
        return out

    def copy(self) -> "Canvas":
        out = Canvas(self.w, self.h)
        out.px = [row[:] for row in self.px]
        return out

    def shift(self, dx: int, dy: int) -> "Canvas":
        out = Canvas(self.w, self.h)
        for y in range(self.h):
            for x in range(self.w):
                out.set(x + dx, y + dy, self.px[y][x])
        return out

    def replace(self, src: Color, dst: Color) -> None:
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] == src:
                    self.px[y][x] = dst

    def outline(self, c: Color) -> None:
        """Add a 1px outline around every opaque cluster."""
        marks = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x][3] != 0:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if self.get(x + dx, y + dy)[3] > 128:
                        marks.append((x, y))
                        break
        for x, y in marks:
            self.px[y][x] = c

    # ---- output -----------------------------------------------------

    def to_png(self) -> bytes:
        raw = bytearray()
        for y in range(self.h):
            raw.append(0)  # filter type: none
            for x in range(self.w):
                r, g, b, a = self.px[y][x]
                raw += bytes((r & 255, g & 255, b & 255, a & 255))
        ihdr = struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0)
        return (
            b"\x89PNG\r\n\x1a\n"
            + _chunk(b"IHDR", ihdr)
            + _chunk(b"IDAT", zlib.compress(bytes(raw), 9))
            + _chunk(b"IEND", b"")
        )

    def save(self, path: str) -> None:
        with open(path, "wb") as fh:
            fh.write(self.to_png())


def _blend(dst: Color, src: Color) -> Color:
    a = src[3] / 255.0
    return (
        int(src[0] * a + dst[0] * (1 - a)),
        int(src[1] * a + dst[1] * (1 - a)),
        int(src[2] * a + dst[2] * (1 - a)),
        max(dst[3], src[3]),
    )


def _in_tri(px, py, p0, p1, p2) -> bool:
    d1 = (px - p1[0]) * (p0[1] - p1[1]) - (p0[0] - p1[0]) * (py - p1[1])
    d2 = (px - p2[0]) * (p1[1] - p2[1]) - (p1[0] - p2[0]) * (py - p2[1])
    d3 = (px - p0[0]) * (p2[1] - p0[1]) - (p2[0] - p0[0]) * (py - p0[1])
    neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
    pos = (d1 > 0) or (d2 > 0) or (d3 > 0)
    return not (neg and pos)


# ---- colour helpers -------------------------------------------------


def rgb(h: str, a: int = 255) -> Color:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def shade(c: Color, f: float) -> Color:
    """Multiply brightness by f, keeping alpha."""
    return (
        max(0, min(255, int(c[0] * f))),
        max(0, min(255, int(c[1] * f))),
        max(0, min(255, int(c[2] * f))),
        c[3],
    )


def mix(a: Color, b: Color, t: float) -> Color:
    return (
        int(a[0] + (b[0] - a[0]) * t),
        int(a[1] + (b[1] - a[1]) * t),
        int(a[2] + (b[2] - a[2]) * t),
        int(a[3] + (b[3] - a[3]) * t),
    )


class Rng:
    """Small deterministic PRNG so assets regenerate identically."""

    def __init__(self, seed: int):
        self.s = (seed ^ 0x9E3779B9) & 0xFFFFFFFF or 1

    def next(self) -> int:
        x = self.s
        x ^= (x << 13) & 0xFFFFFFFF
        x ^= x >> 17
        x ^= (x << 5) & 0xFFFFFFFF
        self.s = x & 0xFFFFFFFF
        return self.s

    def rand(self) -> float:
        return self.next() / 0xFFFFFFFF

    def irange(self, lo: int, hi: int) -> int:
        return lo + self.next() % (hi - lo + 1)

    def pick(self, seq):
        return seq[self.next() % len(seq)]


def seed_of(text: str) -> int:
    h = 2166136261
    for ch in text:
        h = ((h ^ ord(ch)) * 16777619) & 0xFFFFFFFF
    return h
