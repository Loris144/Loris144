# Card data layer

`tools/build_cards.py` generates the three JSON files the Godot project loads at
runtime. It is stdlib-only (no numpy/pandas), re-runnable and deterministic —
running it twice produces byte-identical files.

```
python3 tools/build_cards.py            # writes game/data/*.json
python3 tools/build_cards.py --src DIR   # point at another source folder
python3 tools/build_cards.py --out DIR   # write elsewhere
```

Exit code is `1` if any validation problem was printed, `0` when clean.

## Sources (read-only)

| File | Used for |
|---|---|
| `*classic_yugioh_cards.json` | the card pool (preferred source) |
| `*classic_yugioh_cards.csv` | identical data, automatic fallback if the JSON is missing/broken |
| `*Pack_Zuordnung_Vollstaendig.md` | the 36 booster packs and their card→rarity assignment |
| `*Deck_Design_Starter_und_Duellanten.md` | starter and duelist deck design (read by hand, encoded in the script) |

Lookup order for the source directory: `--src` → `$YGO_SRC_DIR` →
`tools/source/` → `data_src/` → the original upload folder.
Both source formats yield identical output.

---

## `game/data/cards.json` → `res://data/cards.json`

```json
{"cards":[{"id":4031928,"name":"Change of Heart","name_de":"Sinneswandel",
           "cat":"spell","kind":"normal","attr":"","race":"","level":0,
           "atk":0,"def":0,"text":"Target 1 monster …","year":2002}]}
```

Sorted by `id` ascending. **2400 cards** (skills and tokens from the export are
dropped — they are not playable cards).

| Key | Meaning |
|---|---|
| `id` | passcode as int. 27 cards have no passcode: they get a *stable negative* id derived from a CRC32 of the English name and carry the extra key `"noimage": true` (no artwork exists for them). |
| `name` | English name (the join key against the markdown sources) |
| `name_de` | German name, falls back to the English name |
| `cat` | `monster` \| `spell` \| `trap` |
| `kind` | monster: `normal effect fusion ritual synchro xyz link pendulum`<br>spell: `normal quick continuous equip field ritual`<br>trap: `normal continuous counter` |
| `attr` | `EARTH WATER FIRE WIND LIGHT DARK DIVINE` or `""` (translated from `attribut_de`) |
| `race` | English monster type, e.g. `Spellcaster`, `Winged Beast` (translated from `monstertyp_de`), `""` for spells/traps |
| `level` | Level (Rank/Link rating for those kinds), `0` for spells/traps |
| `atk` / `def` | int; **`-1` means `?`**; `0` for spells/traps |
| `text` | English effect/flavour text, may be `""` |
| `year` | first release year, `0` if unknown |

The pool still *contains* synchro/xyz/link/pendulum cards (13/7/11/5) so the
binder can display them, but no deck may use them — see below.

## `game/data/packs.json` → `res://data/packs.json`

```json
{"packs":[{"id":"p05_weisser_drache","name":"Weißer Drache",
           "desc":"Kaibas Deck: …","cost":100,
           "cards":{"common":[…],"rare":[…],"super":[…],"ultra":[…]}}]}
```

* **36 packs**, ids `p01_…` … `p36_…` (number + slugified German name), 100 DP each.
* Card ids inside each tier are sorted ascending; every id exists in `cards.json`.
* The three Egyptian Gods (`10000000`, `10000010`, `10000020`) are excluded from
  every pack — they are story rewards.
* Guaranteed minimums per pack: **≥5 common, ≥2 rare, ≥2 super, ≥1 ultra**.
  The markdown leaves many tiers empty (e.g. the alphabetical spell packs are
  100 % common). The script then moves cards *within that same pack*: the
  weakest cards drop down from the next higher tier, the strongest rise from the
  next lower one. Ranking uses level + ATK for monsters, and card type +
  effect-text length for spells/traps, with the "Meisterstücke" staples
  weighted up. **No card is ever added to a pack the markdown did not put it in.**
  146 cards get re-tiered this way.

The runtime pull (`CardDB.open_pack`) is 3 common + 1 rare + 1 super (85 %) or
ultra (15 %).

## `game/data/decks.json` → `res://data/decks.json`

```json
{"decks":{"yugi_t5":{"name":"Yugi - King of Games","owner":"Yugi Muto",
                     "tier":5,"main":[…40 ids…],"extra":[…≤15 ids…]}}}
```

**40 decks.** `main` is sorted monsters → spells → traps; `extra` alphabetically.

| id | |
|---|---|
| `starter_warrior`, `starter_spellcaster`, `starter_dragon` | the three starter decks, exactly as written out in the design doc |
| `yugi_t2..t5`, `kaiba_t2..t5`, `joey_t1..t4`, `mai_t2..t4` | |
| `weevil_t2/t3`, `rex_t2/t3`, `keith_t2`, `pegasus_t5` | |
| `marik_t3/t4`, `yami_marik_t4`, `strings_t3`, `ishizu_t3`, `odion_t3` | |
| `bakura_t3/t4`, `thiefking_t4`, `priest_seto_t4` | |
| `rare_hunter_t2`, `paradox_t2` | |
| `random_t1..t4` | generic filler decks for random trainers |

Rules enforced by the validator (the script exits non-zero if any is broken):

* `main` is **exactly 40** cards, `extra` **≤ 15**
* max **3 copies** of a card across main + extra
* every id exists in `cards.json`
* **no synchro, xyz, link or pendulum monsters anywhere** — the duel engine
  deliberately implements only Normal / Effect / Ritual / Fusion
* `extra` holds Fusion monsters only; `main` holds no Fusion monsters

### How the decks are authored

Each deck in `build_cards.py` is a `deck(...)` entry with three lists of
`"<count> <exact English card name>"` strings:

* `core` — the cards the design doc names explicitly. Always included.
* `fill` — thematically matching cards + that character's staples, appended in
  order until the main deck holds exactly 40. Only the decks the doc sketches as
  "core cards" need it; the fully written-out decks (3 starters, Yugi tier 5,
  Pegasus, Yami Marik) reach 40 from `core` alone.
* `extra` — Fusion monsters.

To edit a deck, change those lists and re-run the script; unknown card names are
reported by name and deck id.

### Data that had to be synthesized

* **27 cards without a passcode** get negative ids + `"noimage": true`.
* **Pack rarity minimums**: 146 cards moved between tiers of their own pack.
* **All decks except the six written out in full** were expanded from the doc's
  "core card" sketches to legal 40-card lists.
* Cards the doc names that do not exist in the classic pool were replaced with
  the closest equivalent from the pool: *Toon Summoned Skull* → *Toon Black
  Luster Soldier* / *Toon Buster Blader* (Pegasus), *Embodiment of Apophis* →
  *Temple of the Kings* trap wall (Odion), *Battle Warrior* → *Battle Footballer*
  (Joey tier 1), *Vorse Raider* → *Dark Blade* (random tier 2).
* *Flame Swordsman* and *Humanoid Worm Drake* are Fusion monsters in this pool
  and were moved to the extra deck / replaced accordingly.
