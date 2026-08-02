"""Hand-drawn body templates.

Procedural shapes never look like real pixel art, so the body is drawn once
by hand as a character map and then recoloured per character. Hair, headgear
and accessories are layered on top afterwards.

Legend
    .  transparent        O  outline
    S  skin               s  skin shadow          L  skin light
    W  eye white          E  iris                 P  pupil
    T  top (base)         u  top light            v  top shadow
    C  secondary top (shirt showing through)
    B  trousers/skirt     n  trousers shadow      m  trousers light
    F  shoe               f  shoe light
    K  hand
    H  hair back (filled by the hair layer, drawn behind the head)
Frames differ only in the leg/arm rows, so each direction lists its rows once
and the walk offsets are applied when rendering.
"""

# ---------------------------------------------------------------- facing down
DOWN = [
    "................................",  # 0
    "................................",  # 1
    "................................",  # 2
    "..........OOOOOOOOOO............",  # 3
    "........OOSSSSSSSSSSOO..........",  # 4
    ".......OSSSSSSSSSSSSSSO.........",  # 5
    "......OSSSSSSSSSSSSSSSSO........",  # 6
    "......OSSSSSSSSSSSSSSSSO........",  # 7
    ".....OSSSSSSSSSSSSSSSSSSO.......",  # 8
    ".....OSSSSSSSSSSSSSSSSSSO.......",  # 9
    ".....OLSSSSSSSSSSSSSSSSsO.......",  # 10
    ".....OLSSOOOOSSSSOOOOSSsO.......",  # 11  brow line
    ".....OLSSWWEESSSSWWEESSsO.......",  # 12  eyes
    ".....OLSSWEPESSSSWEPESSsO.......",  # 13
    ".....OSSSWWEESSSSWWEESSsO.......",  # 14
    "......OSSSSSSSsSSSSSSSsO........",  # 15  nose
    "......OSSSSSSSSSSSSSSSO.........",  # 16
    ".......OSSSSsssssSSSSO..........",  # 17  mouth
    "........OSSSSSSSSSSSO...........",  # 18
    "..........OOsssssOO.............",  # 19  jaw
    "...........OSSSSSO..............",  # 20  neck
    "...........OsssssO..............",  # 21
    "........OOOOTTTTTTOOOO..........",  # 22  shoulders
    "......OOuuuTTTTTTTTuuuOO........",  # 23
    ".....OuuuuTTTCCCCTTTuuuuO.......",  # 24
    "....OKuuuTTTTCCCCTTTTuuuKO......",  # 25  arms start
    "....OKKuuTTTTCCCCTTTTuuKKO......",  # 26
    "....OKKuTTTTTCCCCTTTTTuKKO......",  # 27
    "....OKKuTTTTTCCCCTTTTTuKKO......",  # 28
    "....OKKuTTTTTCCCCTTTTTuKKO......",  # 29
    "....OKKvTTTTTCCCCTTTTTvKKO......",  # 30
    ".....OKvvTTTTCCCCTTTTvvKO.......",  # 31  hands
    "......OOvvvvvvvvvvvvvvOO........",  # 32  hem
    ".......OOOOOOOOOOOOOOOO.........",  # 33
    "........OBBBBOO..OBBBBO.........",  # 34  legs
    "........OBBBBO....OBBBBO........",  # 35
    "........OBBBBO....OBBBBO........",  # 36
    "........OnnnnO....OnnnnO........",  # 37
    "........OFFFFO....OFFFFO........",  # 38
    "........OffffO....OffffO........",  # 39
    "........OOOOOO....OOOOOO........",  # 40
    "................................",  # 41
    "................................",  # 42
    "................................",  # 43
]

# ---------------------------------------------------------------- facing left
LEFT = [
    "................................",
    "................................",
    "................................",
    "..........OOOOOOOOO.............",
    "........OOSSSSSSSSSOO...........",
    ".......OSSSSSSSSSSSSSO..........",
    "......OSSSSSSSSSSSSSSSO.........",
    "......OSSSSSSSSSSSSSSSO.........",
    ".....OSSSSSSSSSSSSSSSSSO........",
    ".....OSSSSSSSSSSSSSSSSSO........",
    ".....OLSSSSSSSSSSSSSSSsO........",
    ".....OLSSSOOOOSSSSSSSSsO........",
    ".....OLSSSWWEESSSSSSSSsO........",
    ".....OLSSSWEPESSSSSSSSsO........",
    ".....OSSSSWWEESSSSSSSSsO........",
    "....OsSSSSSSSSSSSSSSSsO.........",
    "....OsSSSSSSSSSSSSSSSO..........",
    ".....OsSSSSSSSSSSSSSO...........",
    "......OSSSSSSSSSSSSO............",
    "..........OOsssssOO.............",
    "...........OSSSSSO..............",
    "...........OsssssO..............",
    "........OOOOTTTTTTOOO...........",
    "......OOuuuTTTTTTTTuuO..........",
    ".....OuuuuTTTTTTTTTTuuO.........",
    ".....OKuuuTTTTTTTTTTTuO.........",
    ".....OKKuuTTTTTTTTTTTuO.........",
    ".....OKKuTTTTTTTTTTTTuO.........",
    ".....OKKuTTTTTTTTTTTTuO.........",
    ".....OKKuTTTTTTTTTTTTuO.........",
    ".....OKKvTTTTTTTTTTTTvO.........",
    "......OKvvTTTTTTTTTTvvO.........",
    "......OOvvvvvvvvvvvvOO..........",
    ".......OOOOOOOOOOOOOO...........",
    "........OBBBBOO..OBBBO..........",
    "........OBBBBO...OBBBO..........",
    "........OBBBBO...OBBBO..........",
    "........OnnnnO...OnnnO..........",
    "........OFFFFO...OFFFO..........",
    "........OffffO...OfffO..........",
    "........OOOOOO...OOOOO..........",
    "................................",
    "................................",
    "................................",
]

# ------------------------------------------------------------------ facing up
UP = [
    "................................",
    "................................",
    "................................",
    "..........OOOOOOOOOO............",
    "........OOSSSSSSSSSSOO..........",
    ".......OSSSSSSSSSSSSSSO.........",
    "......OSSSSSSSSSSSSSSSSO........",
    "......OSSSSSSSSSSSSSSSSO........",
    ".....OSSSSSSSSSSSSSSSSSSO.......",
    ".....OSSSSSSSSSSSSSSSSSSO.......",
    ".....OSSSSSSSSSSSSSSSSSSO.......",
    ".....OSSSSSSSSSSSSSSSSSSO.......",
    ".....OSSSSSSSSSSSSSSSSSSO.......",
    ".....OSSSSSSSSSSSSSSSSSSO.......",
    ".....OSSSSSSSSSSSSSSSSSSO.......",
    "......OSSSSSSSSSSSSSSSSO........",
    "......OSSSSSSSSSSSSSSSSO........",
    ".......OSSSSSSSSSSSSSSO.........",
    "........OSSSSSSSSSSSO...........",
    "..........OOsssssOO.............",
    "...........OSSSSSO..............",
    "...........OsssssO..............",
    "........OOOOTTTTTTOOOO..........",
    "......OOuuuTTTTTTTTuuuOO........",
    ".....OuuuuTTTTTTTTTTuuuuO.......",
    "....OKuuuTTTTTTTTTTTTuuuKO......",
    "....OKKuuTTTTTTTTTTTTTuKKO......",
    "....OKKuTTTTTTTTTTTTTTTKKO......",
    "....OKKuTTTTTTTTTTTTTTTKKO......",
    "....OKKuTTTTTTTTTTTTTTTKKO......",
    "....OKKvTTTTTTTTTTTTTTTKKO......",
    ".....OKvvTTTTTTTTTTTTTvKO.......",
    "......OOvvvvvvvvvvvvvvOO........",
    ".......OOOOOOOOOOOOOOOO.........",
    "........OBBBBOO..OBBBBO.........",
    "........OBBBBO....OBBBBO........",
    "........OBBBBO....OBBBBO........",
    "........OnnnnO....OnnnnO........",
    "........OFFFFO....OFFFFO........",
    "........OffffO....OffffO........",
    "........OOOOOO....OOOOOO........",
    "................................",
    "................................",
    "................................",
]

TEMPLATES = {"down": DOWN, "left": LEFT, "up": UP}

# rows that belong to the legs — shifted per walk frame
LEG_ROWS = range(34, 41)
# rows that belong to the arms — swing opposite to the legs
ARM_COLS_LEFT = range(4, 8)
ARM_COLS_RIGHT = range(24, 28)
ARM_ROWS = range(25, 32)

HEAD_TOP = 3
HEAD_BOTTOM = 19
BODY_TOP = 22

# =====================================================================
# builds
#
# One doll shape for everybody is exactly what made the first two attempts
# unreadable. The templates above are the child/teen proportion; adults get
# a smaller head and a longer torso, and the frame is re-derived per build
# so hair and gear still land in the right place.
# =====================================================================

W = 32
CX = 16

# head rows that carry no feature and can be dropped to shrink the skull
_HEAD_FILLER = (4, 6, 13)
# columns that are plain skin in every head row, per facing
_HEAD_SEAMS = {"down": (13, 16), "up": (13, 16), "left": (15, 18)}
# torso columns that are plain fabric in every torso row
_TORSO_SEAMS = (11, 21)


def _narrow(row: str, n: int, seam_l: int, seam_r: int) -> str:
    """Remove n columns at each seam and re-pad the edges."""
    if n <= 0:
        return row
    row = row[:seam_r] + row[seam_r + n:]
    row = row[:seam_l] + row[seam_l + n:]
    return "." * n + row + "." * n


def _widen(row: str, n: int, seam_l: int, seam_r: int) -> str:
    """Duplicate n columns at each seam and trim the edges."""
    if n <= 0:
        return row
    row = (row[:seam_r] + row[seam_r] * n + row[seam_r:])
    row = (row[:seam_l] + row[seam_l] * n + row[seam_l:])
    return row[n:len(row) - n]


# head_drop, head_narrow, torso_pad, width  (width: +broad / -slim)
BUILDS = {
    "child":  (0, 0, -2, -1),
    "teen":   (2, 0, 0, 0),
    "adult":  (3, 1, 1, 0),
    "slim":   (3, 1, 2, -1),
    "tall":   (3, 1, 3, 0),
    "broad":  (3, 1, 1, 2),
    "hulk":   (3, 1, 3, 3),
}

_cache: dict = {}


def template(d: str, build: str = "teen"):
    """Return (rows, meta) for a facing and build.

    meta carries head_top / body_top / leg_rows / arm_rows because every
    build moves them somewhere else.
    """
    key = (d, build)
    if key in _cache:
        return _cache[key]

    hdrop, hnar, tpad, wide = BUILDS.get(build, BUILDS["teen"])
    # row 9 of the head block carries the eyes; dropping filler rows above it
    # moves it up, and hair has to be placed relative to it, not to the crown
    eye_idx = 9 - sum(1 for i in _HEAD_FILLER[:hdrop] if i < 9)
    base = TEMPLATES["left" if d == "right" else d]
    head = list(base[3:20])
    neck = list(base[20:22])
    torso = list(base[22:34])
    legs = list(base[34:41])

    # --- head ---------------------------------------------------------
    for i in sorted(_HEAD_FILLER[:hdrop], reverse=True):
        del head[i]
    sl, sr = _HEAD_SEAMS["left" if d == "right" else d]
    head = [_narrow(r, hnar, sl, sr) for r in head]

    # --- torso / legs --------------------------------------------------
    if tpad > 0:
        torso = torso[:6] + [torso[6]] * tpad + torso[6:]
    elif tpad < 0:
        # a child is not just a small adult: the torso is shorter, which also
        # frees the rows above the head that tall hair needs
        del torso[6:6 - tpad]
    tl, tr = _TORSO_SEAMS
    if wide > 0:
        torso = [_widen(r, wide, tl, tr) for r in torso]
        legs = [_widen(r, wide, tl, tr) for r in legs]
        neck = [_widen(r, min(1, wide), 15, 17) for r in neck]
    elif wide < 0:
        torso = [_narrow(r, -wide, tl, tr) for r in torso]
        legs = [_narrow(r, -wide, tl, tr) for r in legs]

    # --- assemble so the feet always end on the same row ----------------
    body = neck + torso + legs
    blank = "." * W
    rows = [blank] * 44
    foot_end = 41                       # exclusive: last drawn body row + 1
    body_top = foot_end - len(body)
    head_bottom = body_top              # the neck sits directly under the jaw
    head_top = head_bottom - len(head)
    for i, r in enumerate(head):
        rows[head_top + i] = r
    for i, r in enumerate(body):
        rows[body_top + i] = r

    # the drawn shapes span columns 5..24, i.e. they are centred on 14.5 —
    # one pixel left of the frame centre. Nudging them right puts the head
    # under the hair instead of beside it.
    rows = ["." + r[:-1] for r in rows]

    meta = {
        "head_top": head_top,
        "head_h": len(head),
        "head_hw": 10 - hnar,
        "eye_row": head_top + eye_idx,
        "body_top": body_top + len(neck),   # shoulder line
        "leg_rows": range(foot_end - len(legs), foot_end),
        "arm_rows": range(body_top + len(neck) + 3, body_top + len(neck) + 3 + 7),
        "half_w": 12 + max(0, wide),
    }
    _cache[key] = (rows, meta)
    return rows, meta
