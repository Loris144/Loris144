#!/usr/bin/env python3
"""Generate every image asset for the game.

Run:  python3 tools/gen_assets.py
Out:  game/assets/gen/**  plus game/data/tiles.json
"""
from __future__ import annotations

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import chars  # noqa: E402
import tiles  # noqa: E402
import ui  # noqa: E402
from pixel import Canvas, rgb  # noqa: E402
from roster import all_specs  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, os.pardir))
GEN = os.path.join(ROOT, "game", "assets", "gen")
DATA = os.path.join(ROOT, "game", "data")


def ensure(*parts) -> str:
    p = os.path.join(*parts)
    os.makedirs(p, exist_ok=True)
    return p


def main() -> None:
    d_char = ensure(GEN, "chars")
    d_port = ensure(GEN, "portraits")
    d_tile = ensure(GEN, "tiles")
    d_ui = ensure(GEN, "ui")
    d_card = ensure(GEN, "cards")
    os.makedirs(DATA, exist_ok=True)

    # ---- characters -------------------------------------------------
    specs = all_specs()
    for key, spec in specs.items():
        chars.render_sheet(spec).save(os.path.join(d_char, f"{key}.png"))
        chars.render_portrait(spec, 96).save(os.path.join(d_port, f"{key}.png"))
    print(f"chars      : {len(specs)} sheets + portraits")

    # ---- tiles ------------------------------------------------------
    atlas, index = tiles.build_atlas()
    atlas.save(os.path.join(d_tile, "atlas.png"))
    with open(os.path.join(DATA, "tiles.json"), "w") as fh:
        json.dump({"tile_size": tiles.TS, "cols": tiles.ATLAS_COLS,
                   "tiles": index}, fh, separators=(",", ":"))
    print(f"tiles      : {len(index)} in atlas {atlas.w}x{atlas.h}")

    # ---- cards ------------------------------------------------------
    for kind in ui.FRAME_COLS:
        ui.card_frame(kind).save(os.path.join(d_card, f"frame_{kind}.png"))
    ui.card_back().save(os.path.join(d_card, "back.png"))
    print(f"cards      : {len(ui.FRAME_COLS)} frames + back")

    # ---- ui ---------------------------------------------------------
    ui.duel_field(480, 270).save(os.path.join(d_ui, "duel_field.png"))
    ui.dialog_box(320, 84).save(os.path.join(d_ui, "dialog.png"))
    ui.panel(200, 150).save(os.path.join(d_ui, "panel.png"))
    ui.panel(320, 40, "14192a", "e8c246", "2a2438").save(
        os.path.join(d_ui, "banner.png"))
    ui.button(96, 24).save(os.path.join(d_ui, "button.png"))
    ui.button(96, 24, "b0407a").save(os.path.join(d_ui, "button_alt.png"))
    ui.lp_bar(160, 14).save(os.path.join(d_ui, "lp_bar.png"))
    ui.dpad(120).save(os.path.join(d_ui, "dpad.png"))
    ui.round_button(64).save(os.path.join(d_ui, "btn_a.png"))
    ui.round_button(64, "b0407a").save(os.path.join(d_ui, "btn_b.png"))
    ui.title_logo(360, 110).save(os.path.join(d_ui, "logo.png"))
    print("ui         : 11 pieces")

    # a 1x1 white pixel is handy for tinted rects in Godot
    px = Canvas(1, 1, rgb("ffffff"))
    px.save(os.path.join(d_ui, "white.png"))


if __name__ == "__main__":
    main()
