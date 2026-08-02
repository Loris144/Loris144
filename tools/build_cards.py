#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build the card-data layer for the Godot Yu-Gi-Oh! classic fan game.

Reads the curated "classic" card export (JSON, with CSV fallback), the pack
assignment markdown and the deck design markdown, and emits three compact
JSON files that the Godot project loads at runtime:

    game/data/cards.json   full card pool
    game/data/packs.json   36 booster packs with per-rarity card lists
    game/data/decks.json   starter decks, duelist decks, random-trainer decks

Stdlib only. Deterministic: running it twice produces byte-identical output.

Usage:
    python3 tools/build_cards.py [--src DIR] [--out DIR] [-q]

Source lookup order for the four input files:
    1. --src DIR
    2. $YGO_SRC_DIR
    3. <repo>/tools/source
    4. <repo>/data_src
    5. /root/.claude/uploads/62b0ccbb-ffac-5b84-99c7-1f7cbae9e458
"""

from __future__ import annotations

import argparse
import csv
import glob
import json
import os
import re
import sys
import unicodedata
import zlib
from collections import Counter, OrderedDict

# --------------------------------------------------------------------------
# paths
# --------------------------------------------------------------------------

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SRC_CANDIDATES = [
    os.environ.get("YGO_SRC_DIR"),
    os.path.join(REPO, "tools", "source"),
    os.path.join(REPO, "data_src"),
    "/root/.claude/uploads/62b0ccbb-ffac-5b84-99c7-1f7cbae9e458",
]

SRC_PATTERNS = {
    "json": "*classic_yugioh_cards.json",
    "csv": "*classic_yugioh_cards.csv",
    "packs": "*Pack_Zuordnung_Vollstaendig.md",
    "decks": "*Deck_Design_Starter_und_Duellanten.md",
}


def find_sources(extra_dir=None):
    dirs = [extra_dir] + SRC_CANDIDATES
    found = {}
    for d in dirs:
        if not d or not os.path.isdir(d):
            continue
        for key, pat in SRC_PATTERNS.items():
            if key in found:
                continue
            hits = sorted(glob.glob(os.path.join(d, pat)))
            if hits:
                found[key] = hits[0]
    return found


# --------------------------------------------------------------------------
# translation tables (German export -> English game data)
# --------------------------------------------------------------------------

ATTR_DE = {
    "ERDE": "EARTH",
    "WASSER": "WATER",
    "FEUER": "FIRE",
    "WIND": "WIND",
    "LICHT": "LIGHT",
    "FINSTERNIS": "DARK",
    "GOETTLICH": "DIVINE",
}

RACE_DE = {
    "Hexer": "Spellcaster",
    "Drache": "Dragon",
    "Krieger": "Warrior",
    "Ungeheuer": "Beast",
    "Unterweltler": "Fiend",
    "Fee": "Fairy",
    "Maschine": "Machine",
    "Zombie": "Zombie",
    "Aqua": "Aqua",
    "Pyro": "Pyro",
    "Fels": "Rock",
    "Gefluegeltes Ungeheuer": "Winged Beast",
    "Pflanze": "Plant",
    "Insekt": "Insect",
    "Donner": "Thunder",
    "Ungeheuerkrieger": "Beast-Warrior",
    "Dinosaurier": "Dinosaur",
    "Fisch": "Fish",
    "Seeschlange": "Sea Serpent",
    "Reptil": "Reptile",
    "Psi": "Psychic",
    "Goettliches Ungeheuer": "Divine-Beast",
    "Schoepfergott": "Creator God",
    "Wyrm": "Wyrm",
    "Cyberse": "Cyberse",
    "Illusion": "Illusion",
}

MONSTER_KIND = {
    "Normal": "normal",
    "Effekt": "effect",
    "Fusion": "fusion",
    "Ritual": "ritual",
    "Synchro": "synchro",
    "Xyz": "xyz",
    "Link": "link",
    "Pendel": "pendulum",
}

SPELL_KIND = {
    "normal": "normal",
    "quickplay": "quick",
    "quick": "quick",
    "continuous": "continuous",
    "equip": "equip",
    "field": "field",
    "ritual": "ritual",
}

SPELL_KIND_LABEL = {
    "Zauber-Normal": "normal",
    "Zauber-Schnell": "quick",
    "Zauber-Fortlaufend": "continuous",
    "Zauber-Ausruestung": "equip",
    "Zauber-Feld": "field",
    "Zauber-Ritual": "ritual",
}

TRAP_KIND_LABEL = {
    "Falle-Normal": "normal",
    "Falle-Fortlaufend": "continuous",
    "Falle-Counter": "counter",
}

# summoning mechanics the game deliberately does NOT implement
FORBIDDEN_KINDS = {"synchro", "xyz", "link", "pendulum"}

# Egyptian Gods: story rewards, never in packs
GOD_IDS = {10000000, 10000010, 10000020}


# --------------------------------------------------------------------------
# small helpers
# --------------------------------------------------------------------------

def norm_name(s):
    """Normalise a card name so markdown and DB spellings compare equal."""
    if s is None:
        return ""
    s = unicodedata.normalize("NFC", s)
    s = (s.replace("’", "'").replace("‘", "'")
          .replace("“", '"').replace("”", '"')
          .replace("–", "-").replace("—", "-")
          .replace(" ", " "))
    return re.sub(r"\s+", " ", s).strip()


def slugify(s):
    s = unicodedata.normalize("NFC", s)
    for a, b in (("ä", "ae"), ("ö", "oe"), ("ü", "ue"),
                 ("Ä", "Ae"), ("Ö", "Oe"), ("Ü", "Ue"),
                 ("ß", "ss")):
        s = s.replace(a, b)
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = re.sub(r"[^A-Za-z0-9]+", "_", s).strip("_").lower()
    return re.sub(r"_+", "_", s)


def to_int(v, default=0):
    if v is None:
        return default
    if isinstance(v, int):
        return v
    s = str(v).strip()
    if s in ("", "?", "-", "None", "null"):
        return default
    try:
        return int(s)
    except ValueError:
        try:
            return int(float(s))
        except ValueError:
            return default


def stat(v):
    """ATK/DEF: '?' becomes -1, missing becomes 0."""
    if v is None or v == "":
        return 0
    if isinstance(v, int):
        return v
    s = str(v).strip()
    if s == "?":
        return -1
    return to_int(s, 0)


def write_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(obj, fh, ensure_ascii=False, separators=(",", ":"),
                  sort_keys=False)
        fh.write("\n")
    return os.path.getsize(path)


# --------------------------------------------------------------------------
# 1. card pool
# --------------------------------------------------------------------------

def read_source_rows(src):
    """Return raw card dicts from the JSON export, or the CSV as a fallback."""
    if "json" in src:
        try:
            with open(src["json"], encoding="utf-8") as fh:
                blob = json.load(fh)
            rows = blob.get("karten") or blob.get("cards") or []
            if rows:
                return rows, src["json"]
        except (OSError, ValueError) as exc:
            print("  ! JSON source unusable (%s), falling back to CSV" % exc)
    if "csv" in src:
        with open(src["csv"], encoding="utf-8", newline="") as fh:
            rows = list(csv.DictReader(fh))
        return rows, src["csv"]
    raise SystemExit("No card source found. Pass --src DIR.")


def card_kind(row):
    cat = (row.get("kartenart") or "").strip()
    label = (row.get("typ_label") or "").strip()
    sub = (row.get("unterart") or "").strip()
    if cat == "monster":
        return MONSTER_KIND.get(label, "effect")
    if cat == "spell":
        return SPELL_KIND.get(sub) or SPELL_KIND_LABEL.get(label, "normal")
    if cat == "trap":
        return SPELL_KIND.get(sub) or TRAP_KIND_LABEL.get(label, "normal")
    return ""


def build_cards(rows):
    """Convert raw rows into the game's card records, sorted by id."""
    cards = []
    used_ids = set()
    synth = []

    for row in rows:
        cat = (row.get("kartenart") or "").strip()
        if cat not in ("monster", "spell", "trap"):
            continue  # skills and tokens are not playable cards
        name = norm_name(row.get("name"))
        if not name:
            continue

        passcode = (str(row.get("passcode")) if row.get("passcode") else "").strip()
        noimage = False
        if passcode and passcode.lower() not in ("none", "null", ""):
            cid = to_int(passcode, 0)
        else:
            cid = 0
        if cid <= 0:
            # stable synthetic negative id derived from the name
            cid = -(1 + (zlib.crc32(name.encode("utf-8")) % 9_000_000))
            while cid in used_ids:
                cid -= 1
            noimage = True
            synth.append(name)
        if cid in used_ids:
            continue
        used_ids.add(cid)

        kind = card_kind(row)
        attr = ATTR_DE.get((row.get("attribut_de") or "").strip(), "") if cat == "monster" else ""
        race = RACE_DE.get((row.get("monstertyp_de") or "").strip(), "") if cat == "monster" else ""

        if cat == "monster":
            level = to_int(row.get("stufe"), 0) or to_int(row.get("rang"), 0) \
                or to_int(row.get("link_wert"), 0)
            atk = stat(row.get("atk"))
            dfn = 0 if kind == "link" else stat(row.get("def"))
        else:
            level, atk, dfn = 0, 0, 0

        name_de = norm_name(row.get("name_de")) or name
        text = norm_name(row.get("effekt_en")) or ""

        card = OrderedDict((
            ("id", cid),
            ("name", name),
            ("name_de", name_de),
            ("cat", cat),
            ("kind", kind),
            ("attr", attr),
            ("race", race),
            ("level", level),
            ("atk", atk),
            ("def", dfn),
            ("text", text),
            ("year", to_int(row.get("jahr"), 0)),
        ))
        if noimage:
            card["noimage"] = True
        cards.append(card)

    cards.sort(key=lambda c: c["id"])
    return cards, synth


# --------------------------------------------------------------------------
# 2. packs
# --------------------------------------------------------------------------

RARITY_ORDER = ["common", "rare", "super", "ultra"]
RARITY_MIN = {"common": 5, "rare": 2, "super": 2, "ultra": 1}
RARITY_DE = {"Common": "common", "Rare": "rare", "Super": "super", "Ultra": "ultra"}

RE_PACK_HEAD = re.compile(r"^##\s+(\d+)\.\s+(.+?)\s*$")
RE_PACK_DESC = re.compile(r"^\*(.+?)\*\s*$")
RE_RARITY = re.compile(r"^\*\*(Ultra|Super|Rare|Common)\s*\((\d+)\)\*\*")
RE_ENTRY = re.compile(r"^-\s+(.+?)\s+`\[")


def parse_packs_md(path):
    """Parse the pack markdown into [(num, name, desc, {rarity: [names]})]."""
    packs = []
    cur = None
    rarity = None
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.rstrip("\n")
            m = RE_PACK_HEAD.match(line)
            if m:
                cur = {
                    "num": int(m.group(1)),
                    "name": norm_name(m.group(2)),
                    "desc": "",
                    "tiers": OrderedDict((r, []) for r in RARITY_ORDER),
                }
                packs.append(cur)
                rarity = None
                continue
            if cur is None:
                continue
            if not cur["desc"]:
                m = RE_PACK_DESC.match(line.strip())
                if m and not line.strip().startswith("**"):
                    cur["desc"] = norm_name(m.group(1))
                    continue
            m = RE_RARITY.match(line)
            if m:
                rarity = RARITY_DE[m.group(1)]
                continue
            m = RE_ENTRY.match(line)
            if m and rarity:
                cur["tiers"][rarity].append(norm_name(m.group(1)))
    return packs


# Cards in the "Meisterstuecke" pack are the design doc's 84 curated universal
# classics; being one of them is the strongest signal that a card is chase-worthy.
STAPLE_BONUS = 1200
STAPLE_PACK_NUM = 16


def power_score(card, staples=frozenset()):
    """Rough desirability score, used only to shuffle cards between tiers."""
    s = STAPLE_BONUS if card["id"] in staples else 0
    if card["cat"] == "monster":
        s += card["level"] * 120 + max(card["atk"], 0)
        if card["kind"] in ("fusion", "ritual"):
            s += 500
        elif card["kind"] == "effect":
            s += 250
        return s
    s += 1400
    if card["kind"] in ("field", "counter", "continuous"):
        s += 150
    if card["cat"] == "trap":
        s += 50
    # spells/traps have no stat line: use effect complexity as the tie-breaker
    # so an all-spell pack does not promote cards purely alphabetically
    s += min(len(card["text"]), 600) // 3
    return s


def rebalance_tiers(tiers, by_id, pack_label, log, staples=frozenset()):
    """Guarantee >=5 common, >=2 rare, >=2 super, >=1 ultra per pack.

    Thin tiers are filled from the pack's *own* card list: cards are moved in
    from the nearest neighbouring tier -- the weakest cards come down from a
    higher rarity, the strongest go up from a lower one. No card ever enters a
    pack that the markdown did not already put there.
    """
    idx = {r: i for i, r in enumerate(RARITY_ORDER)}
    moved = 0
    for _ in range(64):
        deficits = [r for r in RARITY_ORDER if len(tiers[r]) < RARITY_MIN[r]]
        if not deficits:
            break
        target = deficits[0]
        donors = sorted(
            (r for r in RARITY_ORDER
             if r != target and len(tiers[r]) > RARITY_MIN[r]),
            key=lambda r: (abs(idx[r] - idx[target]), idx[r]),
        )
        if not donors:
            log.append("  ! %s: cannot reach minimum for '%s' (only %d cards)"
                       % (pack_label, target, sum(len(v) for v in tiers.values())))
            break
        donor = donors[0]
        pool = sorted(tiers[donor],
                      key=lambda cid: (power_score(by_id[cid], staples),
                                       by_id[cid]["name"]))
        pick = pool[0] if idx[donor] > idx[target] else pool[-1]
        tiers[donor].remove(pick)
        tiers[target].append(pick)
        moved += 1
    return moved


def build_packs(packs_md, cards, log):
    by_name = {c["name"]: c for c in cards}
    by_id = {c["id"]: c for c in cards}
    out = []
    unknown = Counter()
    dropped_gods = 0
    total_moved = 0

    staples = set()
    for p in packs_md:
        if p["num"] == STAPLE_PACK_NUM:
            for names in p["tiers"].values():
                for name in names:
                    card = by_name.get(name)
                    if card is not None:
                        staples.add(card["id"])

    for p in packs_md:
        tiers = OrderedDict((r, []) for r in RARITY_ORDER)
        seen = set()
        for rarity in RARITY_ORDER:
            for name in p["tiers"][rarity]:
                card = by_name.get(name)
                if card is None:
                    unknown[name] += 1
                    continue
                cid = card["id"]
                if cid in GOD_IDS:
                    dropped_gods += 1
                    continue
                if cid in seen:
                    continue
                seen.add(cid)
                tiers[rarity].append(cid)

        label = "%02d %s" % (p["num"], p["name"])
        total_moved += rebalance_tiers(tiers, by_id, label, log, staples)

        for rarity in RARITY_ORDER:
            tiers[rarity].sort()

        out.append(OrderedDict((
            ("id", "p%02d_%s" % (p["num"], slugify(p["name"]))),
            ("name", p["name"]),
            ("desc", p["desc"]),
            ("cost", 100),
            ("cards", tiers),
        )))

    if unknown:
        log.append("  ! pack entries with no matching card (%d): %s"
                   % (len(unknown), ", ".join(sorted(unknown)[:12])))
    return out, dropped_gods, total_moved


# --------------------------------------------------------------------------
# 3. decks
# --------------------------------------------------------------------------
#
# Notation: every entry is "<count> <exact english card name>".
# `core`  -- always included (the cards the design doc names explicitly)
# `fill`  -- appended in order until the main deck holds exactly 40 cards;
#            these are the thematically matching cards + staples used to
#            expand the doc's "core card" sketches into legal decks.
# `extra` -- Fusion monsters only, max 15.

D = lambda *rows: list(rows)

DECKS = []


def deck(did, name, owner, tier, core, fill=(), extra=()):
    DECKS.append({
        "id": did, "name": name, "owner": owner, "tier": tier,
        "core": list(core), "fill": list(fill), "extra": list(extra),
    })


# ---- starter decks (written out in full in the design doc) ----------------

deck("starter_warrior", "Klinge des Kriegers", "Spieler", 1, D(
    "3 Silent Swordsman LV3", "2 Silent Swordsman LV5", "1 Silent Swordsman LV7",
    "2 Gaia The Fierce Knight", "2 Swift Gaia the Fierce Knight",
    "2 Marauding Captain", "2 Celtic Guardian", "2 Axe Raider", "1 Exiled Force",
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Reinforcement of the Army", "1 Swords of Revealing Light",
    "1 Premature Burial", "1 Fissure", "1 Smashing Ground", "1 Book of Moon",
    "2 Rush Recklessly", "2 United We Stand",
    "1 Mirror Force", "1 Torrential Tribute", "1 Trap Hole",
    "1 Call of the Haunted", "2 Sakuretsu Armor", "2 Waboku", "2 Dust Tornado",
), extra=D("1 Gaia the Dragon Champion"))

deck("starter_spellcaster", "Zirkel des Magiers", "Spieler", 1, D(
    "3 Skilled Dark Magician", "2 Skilled White Magician", "2 Skilled Red Magician",
    "2 Silent Magician LV4", "1 Silent Magician LV8", "2 Berry Magician Girl",
    "1 Apple Magician Girl", "1 Kiwi Magician Girl", "2 Magician of Faith",
    "1 Breaker the Magical Warrior",
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity", "1 Dark Hole",
    "1 Swords of Revealing Light", "1 Book of Moon", "1 Mystical Space Typhoon",
    "2 Magic Formula", "2 Mage Power", "2 Rush Recklessly",
    "1 Mirror Force", "1 Magic Cylinder", "1 Torrential Tribute",
    "1 Call of the Haunted", "2 Sakuretsu Armor", "2 Waboku", "2 Jar of Greed",
))

deck("starter_dragon", "Erbe des Drachen", "Spieler", 1, D(
    "2 Red-Eyes Black Dragon", "3 Red-Eyes Retro Dragon", "2 Red-Eyes Baby Dragon",
    "2 Red-Eyes Wyvern", "3 Curse of Dragon", "2 Curse of Dragonfire",
    "2 Winged Dragon, Guardian of the Fortress #1",
    "1 Gandora the Dragon of Destruction",
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Premature Burial", "1 Dark Hole", "1 Smashing Ground",
    "1 Mystical Space Typhoon", "2 Red-Eyes Insight", "2 Megamorph",
    "1 Red-Eyes Fusion",
    "1 Mirror Force", "1 Torrential Tribute", "1 Call of the Haunted",
    "2 Red-Eyes Spirit", "2 Return of the Red-Eyes", "2 Sakuretsu Armor",
    "2 Waboku",
), extra=D("1 Red-Eyes Black Dragon Sword",
           "1 Curse of Dragon, the Magical Knight Dragon"))

# ---- Yugi / the Pharaoh ---------------------------------------------------

deck("yugi_t2", "Yugi - Duelist Kingdom", "Yugi Muto", 2, D(
    "3 Dark Magician", "2 Celtic Guardian", "2 Feral Imp", "2 Beaver Warrior",
    "2 Curse of Dragon", "2 Gaia The Fierce Knight", "2 Kuriboh",
    "2 Winged Dragon, Guardian of the Fortress #1", "1 Catapult Turtle",
    "1 Monster Reborn", "1 Swords of Revealing Light", "1 Polymerization",
    "2 Multiply", "2 De-Spell",
    "2 Magical Hats", "2 Spellbinding Circle",
), fill=D(
    "1 Dark Magic Attack", "1 Pot of Greed", "1 Graceful Charity",
    "1 Dark Hole", "1 Book of Moon",
    "1 Mirror Force", "1 Trap Hole", "2 Waboku", "2 Sakuretsu Armor",
    "1 Mystical Space Typhoon", "1 Fissure",
), extra=D("1 Gaia the Dragon Champion"))

deck("yugi_t3", "Yugi - Battle City", "Yugi Muto", 3, D(
    "2 Dark Magician", "2 Dark Magician Girl", "1 Buster Blader",
    "1 Big Shield Gardna", "2 Alpha The Magnet Warrior",
    "2 Beta The Magnet Warrior", "2 Gamma The Magnet Warrior",
    "1 Valkyrion the Magna Warrior", "2 Obnoxious Celtic Guard",
    "2 Skilled Dark Magician", "1 Slifer the Sky Dragon", "1 Kuriboh",
    "1 Card of Sanctity", "1 Brain Control", "1 Monster Recovery",
    "1 Dark Magic Curtain", "2 Magic Cylinder",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Dark Magic Attack", "1 Swords of Revealing Light", "1 Polymerization",
    "1 Dark Hole",
    "2 Spellbinding Circle", "1 Magical Hats", "1 Mirror Force",
    "2 Waboku", "2 Sakuretsu Armor", "1 Torrential Tribute",
), extra=D("1 Gaia the Dragon Champion", "1 Dark Paladin"))

deck("yugi_t4", "Yugi - Erinnerungswelt", "Yugi Muto", 4, D(
    "3 Dark Magician", "2 Dark Magician Girl", "3 Magician's Rod",
    "2 Magician's Robe", "2 Apprentice Illusion Magician",
    "1 Magician of Dark Illusion", "1 Dark Magician Knight",
    "2 Skilled Dark Magician", "1 Magikuriboh",
    "3 Dark Magical Circle", "1 Sage's Stone", "1 Illusion Magic",
    "2 Eternal Soul", "2 Magician Navigation",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Dark Magic Attack", "1 Dark Hole", "1 Swords of Revealing Light",
    "1 Mirror Force", "1 Magic Cylinder", "1 Torrential Tribute",
    "1 Spellbinding Circle", "2 Waboku", "1 Dark Magic Curtain",
    "1 Mystical Space Typhoon", "2 Jar of Greed", "1 Book of Moon",
), extra=D("1 Dark Paladin", "1 Dark Cavalry", "1 The Dark Magicians",
           "1 Dark Magician the Dragon Knight", "1 Gaia the Dragon Champion"))

deck("yugi_t5", "Yugi - King of Games", "Yugi Muto", 5, D(
    "3 Dark Magician", "2 Dark Magician Girl", "3 Magician's Rod",
    "2 Magician's Robe", "3 Magicians' Souls",
    "2 Apprentice Illusion Magician", "1 Magician of Dark Illusion",
    "1 Palladium Oracle Mahad", "1 Magikuriboh",
    "3 Dark Magical Circle", "2 Soul Servant", "2 Illusion Magic",
    "1 Sage's Stone", "1 Bond Between Teacher and Student",
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "3 Eternal Soul", "2 Magician Navigation", "1 Magicians' Combination",
    "1 Dark Magic Mirror Force", "1 Mirror Force", "1 Magic Cylinder",
    "1 Torrential Tribute",
), extra=D(
    "1 The Dark Magicians", "1 Dark Paladin", "1 Dark Cavalry",
    "1 Dark Magician the Dragon Knight", "1 Dark Magician Girl the Dragon Knight",
    "1 Red-Eyes Dark Dragoon", "1 Amulet Dragon",
))

# ---- Seto Kaiba -----------------------------------------------------------

deck("kaiba_t2", "Kaiba - Duelist Kingdom", "Seto Kaiba", 2, D(
    "3 Blue-Eyes White Dragon", "2 Battle Ox", "2 Rude Kaiser",
    "2 Mystic Horseman", "2 Judge Man", "2 Saggi the Dark Clown",
    "2 Luster Dragon", "2 Kaiser Sea Horse", "1 Lord of D.",
    "2 Soul Exchange", "1 Polymerization", "1 Monster Reborn",
), fill=D(
    "1 The Flute of Summoning Dragon", "1 Pot of Greed", "1 Graceful Charity",
    "1 Swords of Revealing Light", "1 Dark Hole", "1 Fissure",
    "1 Premature Burial",
    "1 Mirror Force", "1 Trap Hole", "2 Waboku", "2 Sakuretsu Armor",
    "2 Negate Attack", "1 Torrential Tribute", "1 Call of the Haunted",
    "2 Rush Recklessly", "1 Mystical Space Typhoon", "1 Book of Moon",
), extra=D("1 Blue-Eyes Ultimate Dragon"))

deck("kaiba_t3", "Kaiba - Battle City", "Seto Kaiba", 3, D(
    "3 Blue-Eyes White Dragon", "2 Blue-Eyes Alternative White Dragon",
    "2 Maiden with Eyes of Blue", "2 Sage with Eyes of Blue",
    "2 Priestess with Eyes of Blue", "2 The White Stone of Legend",
    "1 The White Stone of Ancients", "1 Kaibaman", "1 Lord of D.",
    "1 Obelisk the Tormentor", "2 Kaiser Sea Horse",
    "2 Enemy Controller", "2 Ring of Destruction", "1 Mirror Force",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "2 Soul Exchange", "1 Polymerization", "1 The Flute of Summoning Dragon",
    "1 Burst Stream of Destruction", "1 Dark Hole",
    "2 Negate Attack", "2 Waboku", "1 Torrential Tribute",
    "1 Call of the Haunted", "1 Solemn Judgment",
), extra=D("1 Blue-Eyes Ultimate Dragon", "1 Blue-Eyes Twin Burst Dragon"))

deck("kaiba_t4", "Kaiba - Battle City Finale", "Seto Kaiba", 4, D(
    "3 Blue-Eyes White Dragon", "2 Blue-Eyes Alternative White Dragon",
    "2 Dragon Spirit of White", "2 Maiden with Eyes of Blue",
    "2 Sage with Eyes of Blue", "2 Priestess with Eyes of Blue",
    "2 The White Stone of Ancients", "1 Master with Eyes of Blue",
    "1 Kaibaman", "1 Obelisk the Tormentor",
    "2 Wishes for Eyes of Blue", "1 Vision with Eyes of Blue",
    "2 Interdimensional Matter Transporter", "2 Negate Attack",
), fill=D(
    "2 Enemy Controller", "1 Monster Reborn", "1 Pot of Greed",
    "1 Graceful Charity", "1 Polymerization", "1 Burst Stream of Destruction",
    "1 Dark Hole",
    "2 Ring of Destruction", "1 Mirror Force", "1 Torrential Tribute",
    "1 Solemn Judgment", "1 Call of the Haunted",
    "2 Waboku", "1 Mystical Space Typhoon", "1 Premature Burial",
), extra=D("1 Blue-Eyes Ultimate Dragon", "1 Neo Blue-Eyes Ultimate Dragon",
           "1 Blue-Eyes Twin Burst Dragon"))

deck("kaiba_t5", "Kaiba - Rematch", "Seto Kaiba", 5, D(
    "3 Blue-Eyes White Dragon", "3 Blue-Eyes Alternative White Dragon",
    "2 Dragon Spirit of White", "1 Deep-Eyes White Dragon",
    "2 Maiden with Eyes of Blue", "2 Sage with Eyes of Blue",
    "2 Priestess with Eyes of Blue", "2 The White Stone of Ancients",
    "1 Master with Eyes of Blue", "1 Protector with Eyes of Blue",
    "1 Kaibaman", "1 Obelisk the Tormentor",
    "2 Wishes for Eyes of Blue", "1 Vision with Eyes of Blue",
    "2 Enemy Controller", "2 Ring of Destruction",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Polymerization", "1 Burst Stream of Destruction", "1 Dark Hole",
    "1 Majesty with Eyes of Blue",
    "2 Interdimensional Matter Transporter", "1 Mirror Force",
    "1 Solemn Judgment", "2 Negate Attack", "1 Torrential Tribute",
), extra=D("1 Blue-Eyes Ultimate Dragon", "1 Neo Blue-Eyes Ultimate Dragon",
           "1 Blue-Eyes Twin Burst Dragon",
           "1 Blue-Eyes Alternative Ultimate Dragon"))

# ---- Joey Wheeler ---------------------------------------------------------

deck("joey_t1", "Joey - Anfaenger", "Joey Wheeler", 1, D(
    "3 Baby Dragon", "3 Swordsman of Landstar", "2 Garoozis", "2 Tiger Axe",
    "2 Masaki the Legendary Swordsman", "2 Battle Footballer",
    "2 Rock Ogre Grotto #1", "2 Axe Raider",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "2 Shield & Sword", "2 Salamandra",
    "1 Fissure", "1 Dark Hole", "1 Swords of Revealing Light",
    "2 Skull Dice", "2 Graceful Dice", "2 Waboku", "2 Trap Hole",
    "2 Sakuretsu Armor", "1 Mirror Force",
    "2 Legendary Sword", "2 Dragon Treasure", "2 Beast Fangs",
))

deck("joey_t2", "Joey - Duelist Kingdom", "Joey Wheeler", 2, D(
    "2 Red-Eyes Black Dragon", "3 Baby Dragon", "2 Time Wizard",
    "2 Garoozis", "2 Swordsman of Landstar", "2 Axe Raider",
    "1 Masaki the Legendary Swordsman", "2 Little-Winguard",
    "2 Skull Dice", "2 Graceful Dice", "1 Shield & Sword",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Polymerization", "2 Salamandra", "1 Question", "1 Dark Hole",
    "1 Premature Burial",
    "1 Mirror Force", "2 Waboku", "2 Sakuretsu Armor", "1 Trap Hole",
    "1 Call of the Haunted", "1 Metalmorph",
    "2 Rush Recklessly", "1 Mystical Space Typhoon", "2 Legendary Sword",
), extra=D("1 Flame Swordsman", "1 Thousand Dragon"))

deck("joey_t3", "Joey - Battle City", "Joey Wheeler", 3, D(
    "2 Red-Eyes Black Dragon", "1 Red-Eyes Black Metal Dragon",
    "2 Gearfried the Iron Knight", "2 Little-Winguard", "1 Jinzo",
    "1 Insect Queen", "2 Baby Dragon", "1 Time Wizard",
    "2 Swordsman of Landstar", "1 The Fiend Megacyber",
    "2 Metalmorph", "2 Red-Eyes Insight", "2 Scapegoat", "1 Mirror Force",
    "2 Skull Dice", "2 Graceful Dice",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Polymerization", "1 Premature Burial", "1 Dark Hole",
    "1 Question", "1 Shield & Sword", "1 Salamandra",
    "2 Sakuretsu Armor", "2 Waboku", "1 Call of the Haunted",
    "1 Torrential Tribute",
), extra=D("1 Flame Swordsman", "1 Thousand Dragon",
           "1 Red-Eyes Black Dragon Sword"))

deck("joey_t4", "Joey - Finale", "Joey Wheeler", 4, D(
    "2 Red-Eyes Black Dragon", "2 Red-Eyes Darkness Metal Dragon",
    "2 Red-Eyes Black Flare Dragon", "1 Red-Eyes Black Metal Dragon",
    "2 Gearfried the Red-Eyes Iron Knight", "2 Gearfried the Iron Knight",
    "2 Red-Eyes Wyvern", "1 Jinzo", "1 Insect Queen", "1 Time Wizard",
    "2 Return of the Red-Eyes", "2 Red-Eyes Insight", "1 Red-Eyes Fusion",
    "2 Metalmorph", "2 Skull Dice", "2 Graceful Dice",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Premature Burial", "1 Dark Hole", "2 Scapegoat",
    "1 Mirror Force", "2 Red-Eyes Spirit", "1 Torrential Tribute",
    "2 Sakuretsu Armor", "1 Call of the Haunted",
), extra=D("1 Red-Eyes Slash Dragon", "1 Red-Eyes Black Dragon Sword",
           "1 Flame Swordsman", "1 Thousand Dragon"))

# ---- Mai Valentine --------------------------------------------------------

deck("mai_t2", "Mai - Duelist Kingdom", "Mai Valentine", 2, D(
    "3 Harpie Lady", "1 Harpie Lady Sisters", "2 Cyber Harpie Lady",
    "2 Harpie Girl", "2 Harpie's Pet Baby Dragon", "1 Harpie's Pet Dragon",
    "2 Amazoness Swords Woman", "2 Amazoness Paladin",
    "2 Harpies' Hunting Ground", "2 Elegant Egotist", "2 Cyber Shield",
    "2 Mirror Wall",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Swords of Revealing Light", "1 Premature Burial",
    "2 Gravity Bind", "2 Waboku", "2 Sakuretsu Armor", "1 Trap Hole",
    "1 Mirror Force", "1 Torrential Tribute",
    "2 Rush Recklessly", "1 Book of Moon", "1 Call of the Haunted",
    "2 Amazoness Fighter",
))

deck("mai_t3", "Mai - Battle City", "Mai Valentine", 3, D(
    "3 Harpie Lady", "2 Harpie Channeler", "2 Harpie Perfumer",
    "2 Harpie Queen", "1 Harpie Lady Sisters", "2 Cyber Harpie Lady",
    "1 Harpie's Pet Dragon", "2 Amazoness Swords Woman",
    "1 Amazoness Queen",
    "2 Harpies' Hunting Ground", "1 Harpie's Feather Duster",
    "2 Elegant Egotist", "2 Cyber Shield", "2 Mirror Wall", "1 Mirror Force",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Premature Burial", "1 Mystical Space Typhoon",
    "2 Gravity Bind", "2 Waboku", "2 Sakuretsu Armor",
    "1 Torrential Tribute", "1 Call of the Haunted",
    "1 Book of Moon", "2 Amazoness Fighter", "1 Dark Hole",
))

deck("mai_t4", "Mai - Finale", "Mai Valentine", 4, D(
    "3 Harpie Lady", "2 Harpie Channeler", "2 Harpie Dancer",
    "2 Harpie Harpist", "2 Harpie Perfumer", "1 Harpie Queen",
    "1 Harpie Lady Sisters", "2 Cyber Harpie Lady",
    "1 Harpie's Pet Dragon", "1 Harpie's Pet Dragon - Fearsome Fire Blast",
    "2 Harpie Lady Phoenix Formation", "2 Harpies' Hunting Ground",
    "1 Harpie's Feather Duster", "2 Elegant Egotist",
    "2 Harpie's Feather Storm", "2 Mirror Wall",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Premature Burial", "2 Cyber Shield",
    "1 Mirror Force", "2 Gravity Bind", "1 Torrential Tribute",
    "2 Sakuretsu Armor", "2 Waboku",
))

# ---- Weevil Underwood -----------------------------------------------------

deck("weevil_t2", "Weevil - Duelist Kingdom", "Weevil Underwood", 2, D(
    "3 Petit Moth", "3 Cocoon of Evolution", "1 Great Moth",
    "2 Killer Needle", "2 Hercules Beetle", "2 Basic Insect",
    "2 Kumootoko", "2 Flying Kamakiri #1", "2 Parasite Paracide",
    "2 Jirai Gumo",
    "2 Forest", "2 Insect Barrier", "2 Laser Cannon Armor",
    "1 Multiplication of Ants", "2 Trap Hole", "2 Waboku",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "2 Sakuretsu Armor",
    "1 Mirror Force", "1 Dark Hole", "1 Premature Burial",
    "2 Kamakiriman", "1 Insect Soldiers of the Sky", "1 Beast Fangs",
))

deck("weevil_t3", "Weevil - Rematch", "Weevil Underwood", 3, D(
    "2 Petit Moth", "2 Cocoon of Evolution", "1 Great Moth",
    "1 Perfectly Ultimate Great Moth", "1 Insect Queen",
    "2 Insect Princess", "2 Pinch Hopper", "2 Howling Insect",
    "2 Ultimate Insect LV1", "2 Ultimate Insect LV3", "1 Ultimate Insect LV5",
    "2 Flying Kamakiri #1", "1 Parasite Paracide",
    "2 Jade Insect Whistle", "2 Insect Barrier", "2 Forest",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Multiplication of Ants", "1 Dark Hole", "1 Premature Burial",
    "1 Mirror Force", "2 Waboku", "2 Sakuretsu Armor", "1 Trap Hole",
    "1 Torrential Tribute",
))

# ---- Rex Raptor -----------------------------------------------------------

deck("rex_t2", "Rex - Duelist Kingdom", "Rex Raptor", 2, D(
    "3 Two-Headed King Rex", "3 Uraby", "2 Mammoth Graveyard",
    "2 Crawling Dragon #2", "2 Mad Sword Beast", "2 Kabazauls",
    "2 Two-Mouth Darkruler", "2 Guardian Grarl",
    "2 Wasteland", "2 Raise Body Heat", "2 Ultra Evolution Pill",
    "2 Trap Hole", "2 Waboku", "2 Sakuretsu Armor",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Premature Burial",
    "1 Dark Hole", "1 Mirror Force", "1 Torrential Tribute",
    "1 Fissure", "1 Call of the Haunted",
    "2 Beast Fangs", "2 Legendary Sword", "1 Smashing Ground",
))

deck("rex_t3", "Rex - Rematch", "Rex Raptor", 3, D(
    "2 Black Tyranno", "2 Dark Driceratops", "2 Hyper Hammerhead",
    "3 Gilasaurus", "2 Element Saurus", "2 Two-Headed King Rex",
    "2 Mad Sword Beast", "2 Uraby", "1 Guardian Grarl",
    "2 Wasteland", "2 Ultra Evolution Pill", "1 Raise Body Heat",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Premature Burial", "1 Dark Hole", "1 Smashing Ground",
    "1 Mirror Force", "2 Sakuretsu Armor", "2 Waboku",
    "1 Torrential Tribute", "1 Call of the Haunted", "1 Trap Hole",
    "1 Fissure", "2 Beast Fangs", "1 Mystical Space Typhoon",
    "2 Kabazauls",
))

# ---- Bandit Keith ---------------------------------------------------------

deck("keith_t2", "Bandit Keith - Maschinen", "Bandit Keith", 2, D(
    "2 Barrel Dragon", "2 Slot Machine", "2 Zoa", "2 Metalzoa",
    "1 Machine King", "2 Launcher Spider", "2 Red Gadget",
    "2 Yellow Gadget", "2 Green Gadget", "2 Robotic Knight",
    "2 Metalmorph", "2 Stronghold the Moving Fortress",
    "2 Limiter Removal", "1 Mirror Force",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Machine Duplication", "1 Premature Burial", "1 Dark Hole",
    "2 Sakuretsu Armor", "2 Waboku", "1 Trap Hole",
    "1 Torrential Tribute", "1 Call of the Haunted",
    "1 Mirror Force", "1 Fissure", "2 Heavy Mech Support Platform",
))

# ---- Maximillion Pegasus (full list in the design doc) --------------------
# "Toon Summoned Skull" is not in the classic pool -> replaced 1:1 by the
# closest available heavy Toon beaters.

deck("pegasus_t5", "Pegasus - Toon & Relinquished", "Maximillion Pegasus", 5, D(
    "1 Toon Black Luster Soldier", "1 Toon Buster Blader",
    "1 Toon Dark Magician", "1 Toon Dark Magician Girl",
    "1 Blue-Eyes Toon Dragon", "2 Toon Mermaid", "2 Toon Alligator",
    "1 Manga Ryu-Ran", "2 Toon Masked Sorcerer", "1 Relinquished",
    "2 Illusionist Faceless Magician", "2 Thousand-Eyes Idol",
    "2 Toon World", "1 Toon Kingdom", "3 Toon Table of Contents",
    "1 Toon Rollback", "2 Shadow Toon", "2 Black Illusion Ritual",
    "1 Mimicat", "1 Monster Reborn",
    "2 Toon Defense", "2 Toon Mask", "1 Toon Briefcase", "1 Mirror Force",
    "2 Sakuretsu Armor", "2 Waboku",
), extra=D("1 Thousand-Eyes Restrict", "1 Millennium-Eyes Restrict",
           "1 Blue-Eyes Toon Ultimate Dragon"))

# ---- Marik / Yami Marik / the Rare Hunters --------------------------------

deck("strings_t3", "Strings - Slifer", "Strings", 3, D(
    "1 Slifer the Sky Dragon", "3 Revival Jam", "3 Jam Defender",
    "2 Metal Reflect Slime", "2 Humanoid Slime", "2 Wall of Illusion",
    "2 Giant Soldier of Stone", "2 Millennium Shield", "1 Millennium Golem",
    "2 Infinite Cards", "2 Card of Sanctity",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Dark Hole", "1 Premature Burial", "1 Swords of Revealing Light",
    "2 Waboku", "2 Sakuretsu Armor", "1 Mirror Force",
    "1 Torrential Tribute", "2 Nightmare Wheel", "1 Trap Hole",
    "1 Call of the Haunted", "2 Revival Jam", "1 Fissure",
    "2 Gravekeeper's Guard",
))

deck("marik_t3", "Marik - Battle City", "Marik Ishtar", 3, D(
    "2 Gravekeeper's Chief", "3 Gravekeeper's Spy",
    "2 Gravekeeper's Curse", "2 Gravekeeper's Guard",
    "2 Gravekeeper's Spear Soldier", "2 Gravekeeper's Assailant",
    "1 Gravekeeper's Commandant", "2 Revival Jam",
    "3 Necrovalley", "2 Gravekeeper's Stele", "1 Royal Tribute",
    "2 Jam Defender", "2 Rite of Spirit",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Dark Hole", "1 Gravekeeper's Servant",
    "1 Mirror Force", "2 Metal Reflect Slime", "1 Torrential Tribute",
    "2 Nightmare Wheel", "1 Waboku", "1 Imperial Tombs of Necrovalley",
    "2 Sakuretsu Armor",
))

deck("marik_t4", "Marik - Finale", "Marik Ishtar", 4, D(
    "2 Gravekeeper's Chief", "3 Gravekeeper's Spy",
    "2 Gravekeeper's Descendant", "2 Gravekeeper's Assailant",
    "2 Gravekeeper's Visionary", "1 Gravekeeper's Commandant",
    "2 Gravekeeper's Recruiter", "1 Gravekeeper's Spear Soldier",
    "1 Guardian Slime",
    "3 Necrovalley", "2 Gravekeeper's Stele", "1 Royal Tribute",
    "1 Millennium Revelation",
    "2 Rite of Spirit", "2 Nightmare Wheel", "1 Coffin Seller",
    "1 Imperial Tombs of Necrovalley",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Dark Hole", "1 Gravekeeper's Servant",
    "1 Mirror Force", "2 Metal Reflect Slime", "1 Torrential Tribute",
    "1 Waboku", "2 Sakuretsu Armor",
))

deck("yami_marik_t4", "Yami Marik - Ra", "Yami Marik", 4, D(
    "2 Gravekeeper's Chief", "3 Gravekeeper's Spy",
    "2 Gravekeeper's Descendant", "2 Gravekeeper's Assailant",
    "1 Gravekeeper's Commandant", "1 Gravekeeper's Spear Soldier",
    "1 Guardian Slime", "2 Lava Golem", "1 Bowganian",
    "1 The Winged Dragon of Ra",
    "3 Necrovalley", "2 Gravekeeper's Stele", "1 Royal Tribute",
    "1 Ancient Chant", "1 Millennium Revelation", "1 Monster Reborn",
    "1 Pot of Greed", "1 Graceful Charity", "1 Dark Hole",
    "2 Metal Reflect Slime", "2 Nightmare Wheel", "2 Rite of Spirit",
    "1 Coffin Seller", "1 Imperial Tombs of Necrovalley",
    "1 Sun God Unification", "1 Mirror Force", "1 Torrential Tribute",
    "1 Waboku",
))

deck("ishizu_t3", "Ishizu - Millennium", "Ishizu Ishtar", 3, D(
    "2 Mystical Knight of Jackal", "3 Agido", "3 Keldo", "2 Zolga",
    "3 Kelbek", "2 Millennium Golem", "2 Millennium Shield",
    "2 Gravekeeper's Guard",
    "2 Necrovalley", "2 Exchange", "2 Blast Held by a Tribute",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Swords of Revealing Light", "1 Dark Hole",
    "1 Mirror Force", "2 Waboku", "2 Sakuretsu Armor",
    "1 Torrential Tribute", "2 Nightmare Wheel", "1 Trap Hole",
    "1 Call of the Haunted",
))

deck("odion_t3", "Odion - Fallenwall", "Odion", 3, D(
    "2 Millennium Shield", "2 Millennium Golem", "2 Giant Soldier of Stone",
    "2 Gravekeeper's Guard", "2 Guardian Sphinx", "2 Mystical Elf",
    "1 Guardian Slime",
    "2 Temple of the Kings", "2 Necrovalley",
    "2 Metal Reflect Slime", "2 Nightmare Wheel", "2 Waboku",
    "2 Sakuretsu Armor", "2 Trap Hole", "1 Mirror Force",
    "2 Blast Held by a Tribute",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Torrential Tribute", "2 Jar of Greed", "1 Call of the Haunted",
    "1 Solemn Judgment", "1 Dark Hole",
    "2 Magic Jammer", "2 Seven Tools of the Bandit", "1 Widespread Ruin",
))

deck("rare_hunter_t2", "Rare Hunter - Exodia", "Rare Hunter", 2, D(
    "1 Exodia the Forbidden One", "1 Left Arm of the Forbidden One",
    "1 Right Arm of the Forbidden One", "1 Left Leg of the Forbidden One",
    "1 Right Leg of the Forbidden One", "2 Contract with Exodia",
    "3 Painful Choice", "1 Pot of Greed", "1 Graceful Charity",
    "3 Waboku", "2 Backup Soldier",
), fill=D(
    "3 Sangan", "2 Magician of Faith", "2 Giant Soldier of Stone",
    "2 Mystical Elf", "2 Gravekeeper's Guard",
    "1 Card Destruction", "2 Reload", "1 Monster Reborn",
    "1 The Shallow Grave", "1 Swords of Revealing Light",
    "2 Sakuretsu Armor", "1 Mirror Force", "2 Jar of Greed",
    "1 Torrential Tribute", "1 Trap Hole",
))

deck("paradox_t2", "Paradox-Brueder - Labyrinth", "Paradox-Brueder", 2, D(
    "2 Sanga of the Thunder", "2 Kazejin", "2 Suijin", "1 Gate Guardian",
    "3 Labyrinth Wall", "2 Wall Shadow", "2 Shadow Ghoul",
    "2 Jirai Gumo", "2 Dungeon Worm", "2 Melchid the Four-Face Beast",
    "2 Magical Labyrinth", "2 Labyrinth Wall Shadow",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Polymerization", "1 Swords of Revealing Light", "1 Dark Hole",
    "1 Mirror Force", "2 Waboku", "2 Sakuretsu Armor", "2 Trap Hole",
    "1 Torrential Tribute", "1 Call of the Haunted",
    "1 Premature Burial", "2 Dark King of the Abyss", "1 Fissure",
), extra=D("1 Labyrinth Tank"))

# ---- Bakura ---------------------------------------------------------------

deck("bakura_t3", "Yami Bakura - Okkult", "Yami Bakura", 3, D(
    "2 Dark Necrofear", "3 Headless Knight", "2 Earthbound Spirit",
    "3 The Portrait's Secret", "2 Skull Servant", "2 The Earl of Demise",
    "1 The Lady in Wight", "2 Dark Ruler Ha Des",
    "1 Destiny Board", "1 Spirit Message \"I\"", "1 Spirit Message \"N\"",
    "1 Spirit Message \"A\"", "1 Spirit Message \"L\"",
    "2 Dark Sanctuary", "2 Sentence of Doom",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Dark Hole", "1 Premature Burial", "1 The Shallow Grave",
    "1 Mirror Force", "2 Waboku", "2 Sakuretsu Armor",
    "1 Torrential Tribute", "1 Call of the Haunted", "2 Nightmare Wheel",
))

deck("bakura_t4", "Yami Bakura - Destiny Board", "Yami Bakura", 4, D(
    "3 Dark Necrofear", "2 Headless Knight", "2 Earthbound Spirit",
    "2 The Portrait's Secret", "2 King of the Skull Servants",
    "3 Skull Servant", "1 The Lady in Wight", "1 Dark Ruler Ha Des",
    "1 Destiny Board", "1 Spirit Message \"I\"", "1 Spirit Message \"N\"",
    "1 Spirit Message \"A\"", "1 Spirit Message \"L\"",
    "3 Dark Sanctuary", "2 Sentence of Doom", "2 Nightmare Wheel",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Dark Hole", "1 Premature Burial", "1 Tri-Wight",
    "1 Mirror Force", "2 Waboku", "1 Torrential Tribute",
    "2 Sakuretsu Armor", "1 Call of the Haunted",
))

deck("thiefking_t4", "Diebeskoenig Bakura - Diabound", "Diebeskoenig Bakura", 4, D(
    "3 Diabound Kernel", "2 Dark Necrofear", "2 Headless Knight",
    "2 Earthbound Spirit", "2 The Portrait's Secret",
    "2 The Earl of Demise", "2 Dark Ruler Ha Des", "2 Skull Servant",
    "3 Dark Sanctuary", "2 Nightmare Wheel", "1 Mirror Force",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Dark Hole", "1 Premature Burial", "1 The Shallow Grave",
    "2 Sentence of Doom", "2 Waboku", "2 Sakuretsu Armor",
    "1 Torrential Tribute", "1 Call of the Haunted", "2 Trap Hole",
    "1 Mystical Space Typhoon", "2 Jar of Greed", "1 Fissure",
))

# ---- Priest Seto ----------------------------------------------------------

deck("priest_seto_t4", "Priester Seto - Weisser Drache", "Priester Seto", 4, D(
    "3 Blue-Eyes White Dragon", "2 Dragon Spirit of White",
    "2 Maiden with Eyes of Blue", "2 Sage with Eyes of Blue",
    "2 Priestess with Eyes of Blue", "2 The White Stone of Ancients",
    "1 Master with Eyes of Blue", "1 Protector with Eyes of Blue",
    "2 Kaibaman", "2 Heart of the Blue-Eyes",
    "2 Wishes for Eyes of Blue", "1 Vision with Eyes of Blue",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Polymerization", "1 Burst Stream of Destruction", "1 Dark Hole",
    "1 Swords of Revealing Light",
    "1 Mirror Force", "2 Waboku", "2 Sakuretsu Armor",
    "1 Torrential Tribute", "1 Call of the Haunted", "2 Negate Attack",
    "1 Solemn Judgment",
    "1 Premature Burial", "1 Fissure", "2 Rush Recklessly",
), extra=D("1 Blue-Eyes Ultimate Dragon", "1 Neo Blue-Eyes Ultimate Dragon"))

# ---- generic random trainers ----------------------------------------------

deck("random_t1", "Zufallsduellant I", "Zufallsduellant", 1, D(
    "3 Battle Ox", "3 Beaver Warrior", "3 Mystical Elf",
    "3 Giant Soldier of Stone", "2 Feral Imp", "2 Celtic Guardian",
    "2 Mystic Horseman", "2 Rude Kaiser", "2 Silver Fang",
    "2 Uraby",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Fissure", "1 Dark Hole",
    "2 Sword of Dark Destruction", "2 Book of Secret Arts",
    "2 Trap Hole", "2 Waboku", "2 Sakuretsu Armor", "1 Mirror Force",
    "1 Premature Burial",
))

deck("random_t2", "Zufallsduellant II", "Zufallsduellant", 2, D(
    "2 Axe Raider", "2 Garoozis", "2 Tiger Axe", "2 Zombyra the Dark",
    "2 Ryu-Kishin Powered", "2 Wall of Illusion", "2 Ancient Elf",
    "2 Dark Blade", "2 Gemini Elf", "2 Sangan", "2 Man-Eater Bug",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Premature Burial", "1 Dark Hole", "1 Fissure",
    "1 Swords of Revealing Light", "2 Rush Recklessly",
    "1 Mirror Force", "2 Waboku", "2 Sakuretsu Armor", "2 Trap Hole",
    "1 Torrential Tribute", "1 Call of the Haunted",
    "1 Book of Moon", "2 Legendary Sword", "1 Smashing Ground",
))

deck("random_t3", "Zufallsduellant III", "Zufallsduellant", 3, D(
    "2 Jinzo", "2 Barrel Dragon", "2 Machine King", "2 Robotic Knight",
    "2 Red Gadget", "2 Yellow Gadget", "2 Green Gadget",
    "2 Dark Scorpion - Chick the Yellow",
    "2 Dark Scorpion - Cliff the Trap Remover",
    "2 Dark Scorpion - Meanae the Thorn",
    "1 Dark Scorpion - Gorg the Strong", "2 Don Zaloog",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Limiter Removal", "1 Premature Burial", "1 Dark Hole",
    "1 Mystical Space Typhoon",
    "1 Mirror Force", "2 Sakuretsu Armor", "2 Waboku",
    "1 Torrential Tribute", "1 Call of the Haunted", "1 Dust Tornado",
    "2 Machine Duplication", "2 Heavy Mech Support Platform", "1 Fissure",
))

deck("random_t4", "Zufallsduellant IV", "Zufallsduellant", 4, D(
    "2 Gravekeeper's Spy", "2 Gravekeeper's Guard",
    "2 Gravekeeper's Curse", "2 Gravekeeper's Assailant",
    "2 Guardian Sphinx", "2 Giant Soldier of Stone",
    "2 Millennium Shield", "2 Zolga", "2 Kelbek", "2 Agido",
    "2 Necrovalley", "2 Gravekeeper's Stele",
), fill=D(
    "1 Monster Reborn", "1 Pot of Greed", "1 Graceful Charity",
    "1 Dark Hole", "1 Premature Burial", "1 Smashing Ground",
    "1 Mirror Force", "2 Rite of Spirit", "2 Waboku",
    "2 Sakuretsu Armor", "1 Torrential Tribute", "2 Nightmare Wheel",
))

MAIN_SIZE = 40
EXTRA_MAX = 15
MAX_COPIES = 3

RE_DECK_ENTRY = re.compile(r"^(\d+)\s+(.+)$")


def parse_entry(entry):
    m = RE_DECK_ENTRY.match(entry.strip())
    if not m:
        return 1, norm_name(entry)
    return int(m.group(1)), norm_name(m.group(2))


def build_decks(cards, log):
    by_name = {c["name"]: c for c in cards}
    by_id = {c["id"]: c for c in cards}
    out = OrderedDict()
    missing = Counter()

    for spec in DECKS:
        main = []
        counts = Counter()

        def add(entry, limit=None):
            n, name = parse_entry(entry)
            card = by_name.get(name)
            if card is None:
                missing[(spec["id"], name)] += 1
                return 0
            cid = card["id"]
            room = MAX_COPIES - counts[cid]
            if limit is not None:
                room = min(room, limit)
            n = min(n, room)
            if n <= 0:
                return 0
            counts[cid] += n
            main.extend([cid] * n)
            return n

        for entry in spec["core"]:
            add(entry)
        if len(main) > MAIN_SIZE:
            log.append("  ! %s: core list is %d cards (>40), trimmed"
                       % (spec["id"], len(main)))
            main = main[:MAIN_SIZE]
            counts = Counter(main)
        for entry in spec["fill"]:
            if len(main) >= MAIN_SIZE:
                break
            add(entry, limit=MAIN_SIZE - len(main))

        extra = []
        ecounts = Counter()
        for entry in spec["extra"]:
            n, name = parse_entry(entry)
            card = by_name.get(name)
            if card is None:
                missing[(spec["id"], name)] += 1
                continue
            cid = card["id"]
            n = min(n, MAX_COPIES - counts[cid] - ecounts[cid], EXTRA_MAX - len(extra))
            if n <= 0:
                continue
            ecounts[cid] += n
            extra.extend([cid] * n)

        main.sort(key=lambda cid: (by_id[cid]["cat"] != "monster",
                                   by_id[cid]["cat"], -by_id[cid]["level"],
                                   by_id[cid]["name"], cid))
        extra.sort(key=lambda cid: (by_id[cid]["name"], cid))

        out[spec["id"]] = OrderedDict((
            ("name", spec["name"]),
            ("owner", spec["owner"]),
            ("tier", spec["tier"]),
            ("main", main),
            ("extra", extra),
        ))

    if missing:
        for (did, name), _ in sorted(missing.items()):
            log.append("  ! deck '%s' references unknown card: %s" % (did, name))
    return out


# --------------------------------------------------------------------------
# validation
# --------------------------------------------------------------------------

def validate(cards, packs, decks, log):
    by_id = {c["id"]: c for c in cards}
    problems = 0

    # packs -------------------------------------------------------------
    for p in packs:
        total = 0
        for rarity in RARITY_ORDER:
            ids = p["cards"][rarity]
            total += len(ids)
            for cid in ids:
                if cid not in by_id:
                    log.append("  X pack %s: unknown card id %d" % (p["id"], cid))
                    problems += 1
                if cid in GOD_IDS:
                    log.append("  X pack %s: Egyptian God %d must not be in packs"
                               % (p["id"], cid))
                    problems += 1
            if len(ids) < RARITY_MIN[rarity]:
                log.append("  X pack %s: only %d %s (need %d)"
                           % (p["id"], len(ids), rarity, RARITY_MIN[rarity]))
                problems += 1
        seen = Counter()
        for rarity in RARITY_ORDER:
            seen.update(p["cards"][rarity])
        dupes = [cid for cid, n in seen.items() if n > 1]
        if dupes:
            log.append("  X pack %s: %d card(s) listed in two rarities"
                       % (p["id"], len(dupes)))
            problems += 1
        if total == 0:
            log.append("  X pack %s: empty" % p["id"])
            problems += 1

    # decks -------------------------------------------------------------
    for did, d in decks.items():
        if len(d["main"]) != MAIN_SIZE:
            log.append("  X deck %s: main deck has %d cards (need %d)"
                       % (did, len(d["main"]), MAIN_SIZE))
            problems += 1
        if len(d["extra"]) > EXTRA_MAX:
            log.append("  X deck %s: extra deck has %d cards (max %d)"
                       % (did, len(d["extra"]), EXTRA_MAX))
            problems += 1
        counts = Counter(d["main"]) + Counter(d["extra"])
        for cid, n in sorted(counts.items()):
            if cid not in by_id:
                log.append("  X deck %s: unknown card id %d" % (did, cid))
                problems += 1
                continue
            card = by_id[cid]
            if n > MAX_COPIES:
                log.append("  X deck %s: %d copies of %s (max %d)"
                           % (did, n, card["name"], MAX_COPIES))
                problems += 1
            if card["cat"] == "monster" and card["kind"] in FORBIDDEN_KINDS:
                log.append("  X deck %s: %s is a %s monster (not implemented)"
                           % (did, card["name"], card["kind"]))
                problems += 1
        for cid in d["main"]:
            card = by_id.get(cid)
            if card and card["cat"] == "monster" and card["kind"] == "fusion":
                log.append("  X deck %s: fusion monster %s in main deck"
                           % (did, card["name"]))
                problems += 1
        for cid in d["extra"]:
            card = by_id.get(cid)
            if card and not (card["cat"] == "monster" and card["kind"] == "fusion"):
                log.append("  X deck %s: %s is not a Fusion monster, cannot be in "
                           "the extra deck" % (did, card["name"]))
                problems += 1

    return problems


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------

def main(argv=None):
    ap = argparse.ArgumentParser(description="Build the game card data layer.")
    ap.add_argument("--src", help="directory holding the four source files")
    ap.add_argument("--out", default=os.path.join(REPO, "game", "data"),
                    help="output directory (default: game/data)")
    ap.add_argument("-q", "--quiet", action="store_true")
    args = ap.parse_args(argv)

    say = (lambda *a: None) if args.quiet else print

    src = find_sources(args.src)
    for key in ("packs", "decks"):
        if key not in src:
            raise SystemExit("Missing source file for '%s'. Pass --src DIR." % key)

    log = []

    rows, used = read_source_rows(src)
    say("source : %s (%d rows)" % (os.path.basename(used), len(rows)))

    cards, synth = build_cards(rows)
    say("cards  : %d playable cards" % len(cards))
    if synth:
        say("         %d without passcode -> synthetic negative id + noimage"
            % len(synth))

    packs_md = parse_packs_md(src["packs"])
    packs, dropped_gods, moved = build_packs(packs_md, cards, log)
    say("packs  : %d packs, %d god entries removed, %d cards re-tiered to meet "
        "the 5/2/2/1 minimum" % (len(packs), dropped_gods, moved))

    decks = build_decks(cards, log)
    say("decks  : %d decks" % len(decks))

    problems = validate(cards, packs, decks, log)

    for line in log:
        say(line)

    n1 = write_json(os.path.join(args.out, "cards.json"), {"cards": cards})
    n2 = write_json(os.path.join(args.out, "packs.json"), {"packs": packs})
    n3 = write_json(os.path.join(args.out, "decks.json"), {"decks": decks})
    say("wrote  : cards.json (%.0f KB), packs.json (%.0f KB), decks.json (%.0f KB)"
        % (n1 / 1024.0, n2 / 1024.0, n3 / 1024.0))

    if problems:
        say("RESULT : %d validation problem(s)" % problems)
        return 1
    say("RESULT : clean - %d cards, %d packs, %d decks"
        % (len(cards), len(packs), len(decks)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
