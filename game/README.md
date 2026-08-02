# Yu-Gi-Oh! Classic — Fangame

Ein Duel-Monsters-Fangame in **Godot 4.3**. Die Geschichte folgt dem klassischen
Anime, aber **du** bist der Hauptcharakter — Yugi läuft als bester Freund und
Rivale neben dir her.

---

## Starten

1. [Godot 4.3](https://godotengine.org/download) herunterladen.
2. Godot öffnen → **Import** → diesen `game/`-Ordner wählen → `project.godot`.
3. Auf **Play** (▶) drücken.

Steuerung: **Pfeiltasten / WASD** laufen, **Enter** bestätigen, **Esc / M** Menü.
Auf dem Handy sind ein Steuerkreuz und ein A-Knopf eingeblendet
(abschaltbar unter Einstellungen → Touch-Steuerung).

## Als Android-App

Godot → **Projekt → Exportieren → Android**. Das Spiel ist auf Querformat
(480×270, hochskaliert) ausgelegt und läuft mit dem GL-Compatibility-Renderer,
also auch auf älteren Geräten.

---

## Kartenbilder

Beim ersten Duell lädt das Spiel die echten Kartenbilder automatisch von
`images.ygoprodeck.com` nach und legt sie unter `user://cardart/` ab — danach
sind sie offline verfügbar. **Ohne Internet** zeigt jede Karte stattdessen ein
prozedural erzeugtes Platzhalter-Artwork (pro Karte deterministisch, gefärbt
nach Attribut). Das Spiel ist in beiden Fällen voll spielbar.

---

## Aufbau

```
game/
  project.godot          Godot-Projekt (Autoloads, Auflösung, Input)
  scenes/Main.tscn       Einstiegspunkt
  data/                  Spieldaten (generiert, siehe ../tools)
    cards.json           2400 klassische Karten
    packs.json           36 Booster-Packs à 100 DP
    decks.json           40 Decks (3 Starter + alle Duellanten, Stufe 1–5)
    story.json           40 Szenen, 873 Schritte, Dialoge wortgetreu
    tiles.json           Tileset-Index
  assets/gen/            Alle Grafiken (prozedural erzeugt)
    chars/               45 Charakter-Spritesheets (4 Richtungen × 4 Frames)
    portraits/           Dialog-Portraits
    tiles/atlas.png      54 Overworld-Tiles
    cards/               Kartenrahmen + Rückseite
    ui/                  Duellfeld, Dialogbox, Buttons, Steuerkreuz
  src/
    autoload/            Game (Spielstand), CardDB, StoryDB, Art, Audio, SceneFlow
    duel/                Duell-Engine: State, Engine, CardScripts, AI
    screens/             Title, CharCreate, World, Story, Duel, Menu,
                         Shop, DeckBuilder, Collection, Settings
    ui/                  UI-Helfer, CardView, DialogBox
    world/               Maps (alle Schauplätze), TileGfx
  tools/                 Test- und Prüfskripte (nicht im Spiel benötigt)
```

Die Grafiken und Daten werden von Python-Skripten in `../tools/` erzeugt:

```bash
python3 tools/gen_assets.py     # alle Sprites, Tiles, UI neu zeichnen
python3 tools/build_cards.py    # cards/packs/decks aus den Quelldaten
python3 tools/preview.py        # Kontaktblätter zum Draufschauen
```

---

## Duell-Regeln

Umgesetzt sind die **klassischen** Regeln der Duel-Monsters-Ära:

* 8000 LP, 5 Karten Starthand, 1 Zug = Draw → Standby → Main 1 → Battle →
  Main 2 → End.
* 5 Monster- und 5 Zauber/Fallen-Zonen, Feldzauber, Friedhof, Verbannt, Extra.
* Normalbeschwörung (1×/Zug), **Tributbeschwörung** (Stufe 5–6 = 1 Tribut,
  7+ = 2), Verdeckt setzen, **Flippbeschwörung**, Positionswechsel.
* **Fusionsbeschwörung** und **Ritualbeschwörung** — die Rezepte werden direkt
  aus den Kartentexten geparst, dadurch funktionieren *alle* Fusions- und
  Ritualmonster im Pool ohne Einzelskript.
* Kampf mit ATK/DEF, Verteidigungsposition, verdeckten Monstern, direktem
  Angriff und Durchbohrschaden.
* Zauber & Fallen inkl. Reaktionsfenster: Wird angegriffen oder beschworen,
  darf der Gegner eine gesetzte Falle aktivieren (Spiegelkraft, Magischer
  Zylinder, Waboku, Sakuretsu-Rüstung …).
* Siegbedingungen: LP auf 0, Deck leer — und **Exodia**.
* Rund 70 Karten haben handgeschriebene Effekte (alle Staples, Bossmonster,
  die drei Ägyptischen Götter); häufige Effektmuster werden zusätzlich aus dem
  Kartentext abgeleitet. Der Rest spielt als Vanilla-Karte, was für den großen
  Normalmonster-Anteil eines klassischen Pools korrekt ist.

**Bewusst weggelassen:** Synchro, Xyz, Link, Pendel — passend zur Ära, und die
Decks enthalten keine solchen Karten.

---

## Tests

Godot muss im `PATH` sein.

```bash
cd game

# Daten, Sprites und Screens vollständig?
godot --headless -- --selftest

# Alle Screens instanziieren + 6 KI-gegen-KI-Duelle
godot --headless -- --smoke

# Nur Duelle simulieren (Balance-Check)
godot --headless -- --simduel

# Screenshots aller Bildschirme rendern (braucht xvfb)
xvfb-run -a godot --rendering-driver opengl3 -- --shots
```
