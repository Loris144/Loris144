# Duel Vault

Persönliche Yu-Gi-Oh-App (Shop, Booster, Binder, Deckbuilder, Duell vs. CPU) für den rein privaten Gebrauch auf einem Android-Smartphone.

## Entwicklung

```bash
npm install
npm run dev
```

Öffnet die App im Browser (Portrait-Layout, am besten mit den DevTools im Mobile-Emulationsmodus testen).

## Kartendaten

Beim Start fragt die App für **jede einzelne Karte** im Offline-Basisset (`src/data/fixtureCards.ts`, 158 Karten) den exakten Namen bei der öffentlichen [YGOPRODeck API](https://ygoprodeck.com/api-guide/) ab (`src/data/api.ts`, `src/data/liveCardLoader.ts`, angestoßen in `App.tsx`), zusätzlich zu **56 klassischen Archetypen** für weitere, noch nicht kuratierte Support-Karten. Die Archetyp-Liste basiert auf einer vom Nutzer bereitgestellten kuratierten Liste (`classic_archetypes.json`, Menschen-Urteil über was als "klassisch" zählt) — jeder Eintrag ist ein exakter `api_archetype`-String, verifiziert gegen `archetypes.php`. Beide Fetch-Batches (Archetypen und Kartennamen) laufen gedrosselt (max. 8 gleichzeitig, `runThrottled` in `src/data/api.ts`), um nicht in die von YGOPRODeck dokumentierte Rate-Grenze (~20 Anfragen/Sekunde) zu laufen. Die Treffer werden in die Kartendatenbank gemerged (`src/data/cardDb.ts`): jede vorhandene Karte bekommt dadurch ihre **eigene, korrekte `officialId`** (den echten Konami-Passcode) und damit ihr **eigenes echtes Artwork** statt eines generischen Platzhalters — Kartentext/-werte werden ebenfalls aktualisiert, Preis/Seltenheit/Zuordnung zum Protagonisten bleiben unsere eigene Kuratierung. Komplett neue Support-Karten (aus den Archetyp-Suchen) werden zusätzlich aufgenommen. Ohne Internet (z. B. in dieser Cloud-Entwicklungsumgebung) schlägt jeder Abruf fehl und es bleibt beim handkuratierten Offline-Basisset ohne `officialId` — dann zeigt jede Karte ihr prozedural generiertes Pixel-Sprite (pro Kartenname deterministisch, aber kein echtes Bild) als Platzhalter, bis die App auf einem Gerät mit Internetzugriff läuft.

Manuell recherchiert und mit echten Anker-Karten im Offline-Set vertreten sind u. a.: Summoned Skulls echter Archetyp "Archfiend" (Terrorking Archfiend, Skull Archfiend of Lightning, Black Skull Dragon), Gaia the Fierce Knights Archetyp (Gaia the Dragon Champion, Gaia the Polar Knight), die "Electromagnet Warrior"-Welle für die Magnet Warriors, Exodia Necross, Kaibaman, die neuen Slifer/Obelisk-Structure-Deck-Karten, Gravekeeper's, Amazoness, Black Luster Soldier, Dark Scorpion, Gate Guardian (3-Material-Fusion aus Sanga of the Thunder + Kazejin + Suijin), Flame Swordsman, Skull Servant/King of the Skull Servants, Silent Magician/Silent Swordsman und Timaeus/Legendary Knight. Alle anderen 45 Archetypen aus der kuratierten Liste sind zumindest über die Live-API-Suche eingebunden, auch ohne eigene Anker-Karte im Offline-Set.

## Als Android-APK bauen

1. `npm run build` – erzeugt `dist/`
2. `npx cap sync android` – kopiert den Build in das Android-Projekt (`android/`)
3. Android-Projekt in [Android Studio](https://developer.android.com/studio) öffnen (`npx cap open android` auf einem Rechner mit installiertem Android Studio) und über *Build → Build APK(s)* eine APK erzeugen, oder per `./gradlew assembleDebug` im `android/`-Ordner bauen.

Schritt 3 benötigt das Android SDK, das in dieser Cloud-Entwicklungsumgebung nicht installiert ist – die APK-Erstellung muss daher auf deinem eigenen Rechner mit Android Studio erfolgen. Das `android/`-Projekt ist bereits vollständig vorbereitet (Portrait-Modus fest eingestellt, App-ID `com.duelvault.app`).

## Umfang dieser Version

- Voll spielbarer Shop/Booster/Binder/Deckbuilder-Kreislauf.
- Duell-Engine mit echten Master-Rule-5-Zonen: 5 Hauptmonsterzonen pro Spieler + 2 gemeinsame Extra-Monsterzonen (`src/engine/types.ts`: `extraMonsterZones`), die nur Fusions-/Synchro-/Xyz-/Link-Monster nutzen dürfen (`src/engine/helpers.ts`: `EXTRA_DECK_KINDS`, `monstersControlledBy`, `placeInExtraZone`/`placeInMainZone`). Es gibt noch keine Link-Monster im Kartenpool, daher ist die Regel "ein Link-Monster schaltet eine Hauptzone frei" bewusst nicht implementiert.
- Echte Beschwörungs-Prozeduren: Tribut-Beschwörung (Level 5–6 = 1 Tribut, 7+ = 2), Fusionsbeschwörung (Polymerization), **Ritualbeschwörung** (Tribut-Summe ≥ Level des Ritualmonsters, z. B. "Return of the Dragon Lords" → "Blue-Eyes Spirit Dragon") und **Synchrobeschwörung** (1 Tuner + Nicht-Tuner, deren Level exakt die Stufe des Synchromonsters ergeben, z. B. "Apprentice Illusion Magician" + "Curse of Dragon" → "Red-Eyes Slash Dragon") — alle in `src/engine/duelEngine.ts`.
- Verallgemeinertes Prioritätsfenster (`pendingPriority` in `src/engine/types.ts`, Logik in `src/engine/priority.ts`): nach einer Normalbeschwörung oder Zauberkarten-Aktivierung bekommt der jeweils andere Spieler eine Gelegenheit, mit einer verdeckten Falle oder einem Quick-Play-Zauber zu reagieren, bevor es weitergeht — vereinfacht gegenüber dem echten Spell-Speed-System (1/2/3), aber genau auf das bewegt, was der aktuelle Kartenpool braucht (keine Konter-Fallen, kein beliebig tiefer Kettenaufbau). Das bisherige Reaktionsfenster während eines Angriffs (Fallen/Kuriboh) bleibt zusätzlich bestehen.
- Rund 16 Karten mit vollständig nachgebauter Effektlogik (u. a. Dark Magician-Linie, Blue-Eyes/Red-Eyes-Fusion, Exodia-Sieg, Mirror Force, Magic Cylinder, Time Wizard). Alle anderen Karten sind spielbar, aber ohne besonderen Skript-Effekt (reine Stat-Karte).
