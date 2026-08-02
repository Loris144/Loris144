#!/usr/bin/env python3
"""Build contact sheets so the generated art can be eyeballed."""
from __future__ import annotations

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import chars  # noqa: E402
import tiles  # noqa: E402
import ui  # noqa: E402
from pixel import Canvas, rgb  # noqa: E402
from roster import all_specs, CAST, PLAYER_SPECS  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, os.pardir))
OUT = os.path.join(ROOT, "preview")
os.makedirs(OUT, exist_ok=True)

SCALE = 3


def upscale(c: Canvas, s: int) -> Canvas:
    out = Canvas(c.w * s, c.h * s)
    for y in range(c.h):
        for x in range(c.w):
            col = c.px[y][x]
            if col[3] == 0:
                continue
            for dy in range(s):
                for dx in range(s):
                    out.px[y * s + dy][x * s + dx] = col
    return out


def cast_sheet() -> None:
    """Every character, facing down, idle frame — 3x upscaled."""
    specs = {**{f"player_{k}": v for k, v in PLAYER_SPECS.items()}, **CAST}
    cols = 8
    cw, ch = chars.FW * SCALE + 6, chars.FH * SCALE + 16
    rows = (len(specs) + cols - 1) // cols
    sheet = Canvas(cols * cw, rows * ch, rgb("20263a"))
    for i, (name, spec) in enumerate(specs.items()):
        cx, cy = (i % cols) * cw, (i // cols) * ch
        f = Canvas(chars.FW, chars.FH)
        chars.draw_body(f, spec, "down", 0)
        f.outline(chars.OUTLINE)
        sheet.blit(upscale(f, SCALE), cx + 3, cy + 3)
        # name ribbon so we can tell who is who
        sheet.rect(cx + 1, cy + ch - 12, cw - 2, 10, rgb("101420"))
        for k, ch_ in enumerate(name[:14]):
            sheet.rect(cx + 3 + k * 6, cy + ch - 9, 4,
                       4 if ord(ch_) % 2 else 3, rgb("8ab0e0"))
    sheet.save(os.path.join(OUT, "cast.png"))
    print("preview/cast.png", sheet.w, "x", sheet.h)


def walk_sheet() -> None:
    """One character's full 4x4 sheet, upscaled, to verify animation."""
    for key in ("player_m_bold", "yugi", "kaiba", "mai"):
        spec = all_specs()[key]
        s = chars.render_sheet(spec)
        up = upscale(s, SCALE)
        bg = Canvas(up.w, up.h, rgb("20263a"))
        bg.blit(up, 0, 0)
        bg.save(os.path.join(OUT, f"walk_{key}.png"))
    print("preview/walk_*.png")


def tile_sheet() -> None:
    atlas, index = tiles.build_atlas()
    up = upscale(atlas, 4)
    bg = Canvas(up.w, up.h, rgb("20263a"))
    bg.blit(up, 0, 0)
    bg.save(os.path.join(OUT, "tiles.png"))
    print("preview/tiles.png", bg.w, "x", bg.h)


def ui_sheet() -> None:
    field = ui.duel_field(480, 270)
    bg = Canvas(500, 470, rgb("20263a"))
    bg.blit(field, 10, 10)
    for i, kind in enumerate(("normal", "effect", "fusion", "spell", "trap")):
        fr = ui.card_frame(kind)
        art = ui.card_art_placeholder(f"Demo {kind}", "DARK")
        fr.blit(art, 8, 21)
        bg.blit(fr, 10 + i * 104, 300)
    bg.blit(ui.card_back(), 10 + 5 * 104 - 100, 300) if False else None
    bg.save(os.path.join(OUT, "ui.png"))
    back = Canvas(340, 170, rgb("20263a"))
    back.blit(ui.card_back(), 10, 12)
    back.blit(ui.dialog_box(200, 70), 120, 12)
    back.blit(ui.dpad(90), 122, 90)
    back.blit(ui.logo_stub() if hasattr(ui, "logo_stub") else ui.title_logo(200, 62), 120, 90) if False else None
    back.save(os.path.join(OUT, "ui2.png"))
    print("preview/ui.png, preview/ui2.png")


if __name__ == "__main__":
    cast_sheet()
    walk_sheet()
    tile_sheet()
    ui_sheet()
