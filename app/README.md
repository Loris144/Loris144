# Duel Vault

Persönliche Yu-Gi-Oh-App (Shop, Booster, Binder, Deckbuilder, Duell vs. CPU) für den rein privaten Gebrauch auf einem Android-Smartphone.

## Entwicklung

```bash
npm install
npm run dev
```

Öffnet die App im Browser (Portrait-Layout, am besten mit den DevTools im Mobile-Emulationsmodus testen).

## Kartendaten

Beim Start lädt die App live den offiziellen Kartenpool für die wichtigsten klassischen Archetypen (Dark Magician, Blue-Eyes, Red-Eyes, Exodia, Magnet Warrior, Harpie, Toon, Egyptian God, Orichalcos) plus eine Liste einzeln benannter Signaturkarten (Ägyptische Götter, Rex' Dinosaurier, Weevils Insekten, Pegasus' Relinquished, Bakuras Dark Necrofear u. a.) von der öffentlichen [YGOPRODeck API](https://ygoprodeck.com/api-guide/) (`src/data/api.ts`, `src/data/liveCardLoader.ts`, angestoßen in `App.tsx`) und merged sie in die Kartendatenbank (`src/data/cardDb.ts`): bereits vorhandene Karten werden mit echtem Text/Werten und echtem Artwork aktualisiert, komplett neue Support-Karten werden zusätzlich aufgenommen. Ohne Internet (z. B. in dieser Cloud-Entwicklungsumgebung) bleibt es beim handkuratierten Offline-Basisset (`src/data/fixtureCards.ts`, 116 Karten), dessen Kartentexte/-werte als vorläufig zu betrachten sind, bis echte Daten nachgeladen werden konnten.

## Als Android-APK bauen

1. `npm run build` – erzeugt `dist/`
2. `npx cap sync android` – kopiert den Build in das Android-Projekt (`android/`)
3. Android-Projekt in [Android Studio](https://developer.android.com/studio) öffnen (`npx cap open android` auf einem Rechner mit installiertem Android Studio) und über *Build → Build APK(s)* eine APK erzeugen, oder per `./gradlew assembleDebug` im `android/`-Ordner bauen.

Schritt 3 benötigt das Android SDK, das in dieser Cloud-Entwicklungsumgebung nicht installiert ist – die APK-Erstellung muss daher auf deinem eigenen Rechner mit Android Studio erfolgen. Das `android/`-Projekt ist bereits vollständig vorbereitet (Portrait-Modus fest eingestellt, App-ID `com.duelvault.app`).

## Umfang dieser Version

- Voll spielbarer Shop/Booster/Binder/Deckbuilder-Kreislauf.
- Vereinfachte, aber authentisch aufgebaute Duell-Engine (Phasen, Tribute-Beschwörung, Kampf, ein Reaktionsfenster bei Angriffen für Fallen/Kuriboh).
- Rund 16 Karten mit vollständig nachgebauter Effektlogik (u. a. Dark Magician-Linie, Blue-Eyes/Red-Eyes-Fusion, Exodia-Sieg, Mirror Force, Magic Cylinder, Time Wizard). Alle anderen Karten sind spielbar, aber ohne besonderen Skript-Effekt (reine Stat-Karte).
