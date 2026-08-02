"""The cast: every character that appears in the game, as sprite parameters.

Designs follow the Duel Monsters anime as closely as the 32x40 pixel budget
allows — silhouette, hair shape and signature colours are what make a
character readable at this size, so those are what we spend detail on.
"""
from __future__ import annotations

from chars import CharSpec

# --------------------------------------------------------------------
# The player — six designs, matching the reference art the user supplied.
# --------------------------------------------------------------------

PLAYER_SPECS = {
    # male ------------------------------------------------------------
    "m_quiet": CharSpec(
        key="m_quiet", hair="4a3528", hair2="6b4d38", hair_style="short",
        top="2f4d8a", top2="e8e8ee", bottom="2a2f3d", shoes="26262e",
        eyes="3d6ea8", skin="f0c8a0",
    ),
    "m_bold": CharSpec(
        key="m_bold", hair="a8262c", hair2="d4444a", hair_style="spiky",
        top="24242c", top2="8e2028", bottom="2b2f3a", shoes="1e1e24",
        eyes="7a4a22", skin="e8bc90",
    ),
    "m_outsider": CharSpec(
        key="m_outsider", hair="27324f", hair2="3d4d72", hair_style="flat",
        top="1d1d24", top2="3a2c50", bottom="24242c", shoes="18181e",
        eyes="5a4a78", skin="ecc49c", accessory="headphones",
    ),
    # female ----------------------------------------------------------
    "f_quiet": CharSpec(
        key="f_quiet", hair="5a3f2c", hair2="7d5a3e", hair_style="long",
        top="d8c8a8", top2="ffffff", bottom="2b3a68", shoes="3a2f2a",
        eyes="3d6ea8", skin="f4d0aa", skirt=True, scarf="2f5599",
    ),
    "f_bold": CharSpec(
        key="f_bold", hair="6b4526", hair2="8f6236", hair_style="ponytail",
        top="5d6438", top2="f0f0f0", bottom="2f2f38", shoes="3a2a22",
        eyes="7a4a22", skin="e8bc90", skirt=True,
    ),
    "f_outsider": CharSpec(
        key="f_outsider", hair="5b2d63", hair2="7e4189", hair_style="long",
        top="20202a", top2="4a2a58", bottom="3a2a42", shoes="1c1c22",
        eyes="8a5aa0", skin="f0c8a0", skirt=True,
    ),
}

# --------------------------------------------------------------------
# Story cast
# --------------------------------------------------------------------

CAST: dict[str, CharSpec] = {
    # --- Yugi's circle ------------------------------------------------
    "yugi": CharSpec(
        key="yugi", hair="1b1030", hair2="f2d24a", hair_style="star",
        top="2a2f52", top2="ffffff", bottom="2a2f52", shoes="1e1e26",
        eyes="4a3d8a", skin="f4d0aa", accessory="puzzle",
    ),
    "atem": CharSpec(
        key="atem", hair="1b1030", hair2="f2d24a", hair_style="star",
        top="2a2f52", top2="ffffff", bottom="2a2f52", shoes="1e1e26",
        eyes="8a2a3a", skin="e0b083", accessory="puzzle", tall=2,
    ),
    "joey": CharSpec(
        key="joey", hair="e0b93c", hair2="f6d868", hair_style="spiky",
        top="2f5a3a", top2="ffffff", bottom="3a4a6a", shoes="3a2f28",
        eyes="7a5a28", skin="f0c8a0",
    ),
    "tea": CharSpec(
        key="tea", hair="6b4526", hair2="8f6236", hair_style="bob",
        top="f0f0f4", top2="e05a7a", bottom="2f5599", shoes="d0d0d8",
        eyes="3d7ab0", skin="f6d4b0", skirt=True,
    ),
    "tristan": CharSpec(
        key="tristan", hair="4a3528", hair2="6b4d38", hair_style="spiky",
        top="4a5a72", top2="d8d8e0", bottom="3a4050", shoes="2a2a30",
        eyes="6a5a3a", skin="e8bc90", tall=1,
    ),
    "grandpa": CharSpec(
        key="grandpa", hair="c8c8cc", hair2="e4e4e8", hair_style="wild",
        top="2f6a4a", top2="d8c8a8", bottom="4a4030", shoes="3a2f28",
        eyes="4a4a5a", skin="e4c09a", headgear="band", headgear_col="2a4a8a",
    ),
    # --- Kaiba --------------------------------------------------------
    "kaiba": CharSpec(
        key="kaiba", hair="4a3528", hair2="6b4d38", hair_style="flat",
        top="1c1c24", top2="1c1c24", bottom="1c1c24", shoes="18181e",
        coat="e8e8f0", eyes="3d7ab0", skin="f0c8a0", tall=2,
    ),
    "mokuba": CharSpec(
        key="mokuba", hair="1a1a22", hair2="34343f", hair_style="wild",
        top="e8b83c", top2="f0f0f4", bottom="3a4a6a", shoes="2a2a30",
        eyes="4a4a6a", skin="f4d0aa",
    ),
    # --- Duelist Kingdom ---------------------------------------------
    "pegasus": CharSpec(
        key="pegasus", hair="d8d8e0", hair2="f0f0f4", hair_style="long",
        top="8a2028", top2="f0f0f4", bottom="8a2028", shoes="2a2020",
        coat="a02830", eyes="8a7a5a", skin="f6d4b0", tall=2,
    ),
    "weevil": CharSpec(
        key="weevil", hair="4a8a3a", hair2="6aa855", hair_style="bob",
        top="2f5599", top2="d8d8e0", bottom="3a4050", shoes="2a2a30",
        eyes="6a8a3a", skin="f0c8a0",
    ),
    "rex": CharSpec(
        key="rex", hair="6b2a26", hair2="8f3d36", hair_style="short",
        top="6a4a2a", top2="d8c8a8", bottom="3a4050", shoes="4a3020",
        eyes="7a4a22", skin="e8bc90", headgear="cap", headgear_col="a82828",
    ),
    "mai": CharSpec(
        key="mai", hair="e8c84a", hair2="f6e078", hair_style="long",
        top="6a3a8a", top2="f0e0d0", bottom="5a2f78", shoes="4a2a30",
        eyes="6a3a8a", skin="f6d4b0", skirt=True,
    ),
    "keith": CharSpec(
        key="keith", hair="d8c060", hair2="f0dc90", hair_style="long",
        top="3a5a8a", top2="d8d8e0", bottom="2f4a72", shoes="3a2f28",
        eyes="4a4a5a", skin="e8bc90", accessory="shades",
        headgear="band", headgear_col="b02030", tall=2,
    ),
    # --- Battle City --------------------------------------------------
    "marik": CharSpec(
        key="marik", hair="e8dcb0", hair2="f6ecd0", hair_style="long",
        top="3a2a52", top2="c8a860", bottom="2a2038", shoes="6a5a30",
        coat="4a3568", eyes="6a5a9a", skin="c89a6a", accessory="rod", tall=1,
    ),
    "yami_marik": CharSpec(
        key="yami_marik", hair="e8dcb0", hair2="f6ecd0", hair_style="wild",
        top="3a2a52", top2="c8a860", bottom="2a2038", shoes="6a5a30",
        coat="5a2a68", eyes="a83a5a", skin="c89a6a", accessory="rod", tall=2,
    ),
    "ishizu": CharSpec(
        key="ishizu", hair="1a1a22", hair2="34343f", hair_style="long",
        top="f0f0f4", top2="d8c8a8", bottom="e8e8ee", shoes="8a7a50",
        eyes="4a6a9a", skin="d0a878", accessory="necklace", skirt=True,
    ),
    "odion": CharSpec(
        key="odion", hair="1a1a22", hair_style="bald",
        top="3a2a30", top2="6a5a3a", bottom="2a2028", shoes="4a3a28",
        coat="4a3038", eyes="6a5a4a", skin="c89a6a", tall=3,
    ),
    "strings": CharSpec(
        key="strings", hair="3a5a8a", hair2="4d72a8", hair_style="long",
        top="2a2a34", top2="4a4a58", bottom="24242c", shoes="1e1e24",
        eyes="6a6a7a", skin="d8c8b0", tall=4,
    ),
    "rare_hunter": CharSpec(
        key="rare_hunter", hair="2a2a30", hair_style="bald",
        top="3a3040", top2="2a2430", bottom="2a2430", shoes="24242c",
        coat="453a55", eyes="8a7a4a", skin="c89a6a",
        headgear="hood", headgear_col="453a55",
    ),
    # --- Bakura -------------------------------------------------------
    "bakura": CharSpec(
        key="bakura", hair="e0e0e8", hair2="f4f4f8", hair_style="long",
        top="2f5599", top2="f0f0f4", bottom="3a4050", shoes="2a2a30",
        eyes="7a5a6a", skin="f6d4b0", accessory="ring",
    ),
    "yami_bakura": CharSpec(
        key="yami_bakura", hair="e0e0e8", hair2="f4f4f8", hair_style="wild",
        top="2f5599", top2="f0f0f4", bottom="3a4050", shoes="2a2a30",
        eyes="a03a4a", skin="e8c8a8", accessory="ring", tall=1,
    ),
    "thiefking": CharSpec(
        key="thiefking", hair="e0e0e8", hair2="f4f4f8", hair_style="wild",
        top="8a2a2a", top2="d8c8a8", bottom="5a3a2a", shoes="4a3020",
        coat="6a2020", eyes="a03a4a", skin="c89a6a", tall=2,
    ),
    # --- Memory World -------------------------------------------------
    "priest_seto": CharSpec(
        key="priest_seto", hair="4a3528", hair2="6b4d38", hair_style="flat",
        top="dce4f0", top2="3a6ab0", bottom="c8d4e4", shoes="8a7a50",
        coat="3a6ab0", eyes="3d7ab0", skin="d8b088", tall=2,
        headgear="egypt", headgear_col="2a4a8a",
    ),
    "mahad": CharSpec(
        key="mahad", hair="3a2a4a", hair2="55406a", hair_style="short",
        top="3a3a72", top2="c8a860", bottom="2f2f5a", shoes="8a7a50",
        coat="45458a", eyes="5a5a9a", skin="c89a6a", tall=2,
        headgear="egypt", headgear_col="45458a",
    ),
    "mana": CharSpec(
        key="mana", hair="8a6a3a", hair2="ab8850", hair_style="ponytail",
        top="4a9a8a", top2="e8d8b0", bottom="3a7a6a", shoes="8a7a50",
        eyes="5a8a6a", skin="d8b088", skirt=True,
    ),
    "akhenaden": CharSpec(
        key="akhenaden", hair="b8b8c0", hair2="d4d4dc", hair_style="long",
        top="4a3a58", top2="c8a860", bottom="3a2f48", shoes="8a7a50",
        coat="5a4568", eyes="8a7a4a", skin="c09070", tall=2,
        headgear="egypt", headgear_col="5a4568",
    ),
    "announcer": CharSpec(
        key="announcer", hair="3a2a20", hair_style="short",
        top="2a3a5a", top2="f0f0f4", bottom="24303f", shoes="24242c",
        eyes="4a4a5a", skin="e8bc90",
    ),
}

# --------------------------------------------------------------------
# Anonymous townsfolk / random duelists — generated from a palette table
# --------------------------------------------------------------------

NPC_PALETTES = [
    # (hair, style, top, bottom, skin, skirt)
    ("3a2a20", "short", "b04a3a", "2f3550", "f0c8a0", False),
    ("6b4526", "bob", "4a8a6a", "3a4a6a", "f4d0aa", True),
    ("1a1a22", "short", "3a5a9a", "2a2f3d", "d8a878", False),
    ("d8c060", "ponytail", "e07a9a", "4a3a68", "f6d4b0", True),
    ("4a3528", "spiky", "6a4a8a", "2b2f3a", "e8bc90", False),
    ("2a2a30", "long", "d8b83c", "3a3a48", "c89a6a", True),
    ("8a5a3a", "short", "3a8a7a", "4a4030", "f0c8a0", False),
    ("c8c8cc", "flat", "6a6a7a", "3a3a48", "e4c09a", False),
    ("5a3f2c", "bob", "e8945a", "2f4a72", "f4d0aa", True),
    ("1b1030", "spiky", "2f5599", "24242c", "e8bc90", False),
    ("6b2a26", "short", "4a6a3a", "5a4a30", "d0a878", False),
    ("3a5a8a", "long", "f0e0d0", "3a4a6a", "f6d4b0", True),
]


def npc_specs(count: int = 12) -> dict[str, CharSpec]:
    out = {}
    for i in range(min(count, len(NPC_PALETTES))):
        hair, style, top, bottom, skin, skirt = NPC_PALETTES[i]
        out[f"npc{i:02d}"] = CharSpec(
            key=f"npc{i:02d}", hair=hair, hair_style=style, top=top,
            bottom=bottom, skin=skin, skirt=skirt, shoes="35302e",
        )
    return out


def all_specs() -> dict[str, CharSpec]:
    out: dict[str, CharSpec] = {}
    for k, v in PLAYER_SPECS.items():
        out[f"player_{k}"] = v
    out.update(CAST)
    out.update(npc_specs())
    return out
