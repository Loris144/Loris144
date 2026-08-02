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
