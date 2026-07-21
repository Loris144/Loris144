# Classic Yu-Gi-Oh — Archetypen & Support-Sammler

Paket, um alle Archetypen des **klassischen Yu-Gi-Oh** (Original-Serie „Duel Monsters" /
frühe TCG-Ära) samt **allen zugehörigen Support-Karten** (inkl. moderner
Xyz/Fusion/Synchro/Link-Retrains) automatisch aus der YGOPRODeck-API zu ziehen.

## Dateien
- `classic_archetypes.json` — kuratierte Liste der klassischen Archetypen mit **exakten
  API-Strings**. Das ist der kuratierte Teil (menschliches Urteil: was zählt als „klassisch").
  - `core` — die klassischen Kern-Archetypen
  - `optional_deep_cuts` — Randfälle/Felder/Deep Cuts (per `--include-optional`)
  - `breit_mit_vorsicht` — breite Umbrella-Tags mit Nicht-Klassik-Anteil (per `--include-broad`)
  - Status je Eintrag: `classic_group` (war schon ein Set) vs. `retro_archetype`
    (erst später zum Archetyp gemacht).
- `fetch_classic_support.py` — zieht per API alle Mitglieder + Support-Karten.

## Ausführen
```bash
python3 fetch_classic_support.py                 # Kern-Archetypen
python3 fetch_classic_support.py --include-optional
python3 fetch_classic_support.py --include-broad
python3 fetch_classic_support.py --lang de       # deutsche Kartennamen/-texte
```
Nur Python-Standardbibliothek nötig. Ausgabe:
- `classic_yugioh_cards.json` — nach Archetyp gruppiert, volle Kartendaten
- `classic_yugioh_cards.csv` — flache, deduplizierte Liste

## Wichtige Hinweise
- **Rate-Limit** der API: 20 Requests/Sekunde. Das Skript drosselt automatisch (~7/s).
- Der `archetype=`-Endpoint liefert **Mitglieder + designierten Support** eines Archetyps.
  Karten, die einen klassischen Archetyp nur im Effekttext beiläufig erwähnen, ohne zum
  Support gezählt zu werden, sind nicht enthalten — das ist Absicht (sonst Rauschen).
  Die v7-API hat keinen öffentlichen „Kartentext durchsuchen"-Parameter.
- `Horus` in der DB = **neuer** Archetyp (2023), NICHT der klassische
  „Horus the Black Flame Dragon". Für die klassische Linie den langen String nutzen.
- Der Tag `Magician` enthält auch ARC-V-Pendulum-Magier — deshalb in `breit_mit_vorsicht`.
- Findet das Skript zu einem Namen 0 Karten, wird er am Ende gelistet → gegen
  `https://db.ygoprodeck.com/api/v7/archetypes.php` prüfen.

## Liste erweitern
Neuen Eintrag in `classic_archetypes.json` unter `core` ergänzen; `api_archetype` muss
exakt einem Wert aus `archetypes.php` entsprechen.
