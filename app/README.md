# Duel Vault

Persönliche Yu-Gi-Oh-App (Shop, Booster, Binder, Deckbuilder, Duell vs. CPU) für den rein privaten Gebrauch auf einem Android-Smartphone.

## Entwicklung

```bash
npm install
npm run dev
```

Öffnet die App im Browser (Portrait-Layout, am besten mit den DevTools im Mobile-Emulationsmodus testen).

## Kartendaten

Die App nutzt zur Laufzeit die öffentliche [YGOPRODeck API](https://ygoprodeck.com/api-guide/) für echte Kartendaten und offizielle Bilder (`src/data/api.ts`). Das funktioniert automatisch, sobald das Gerät normalen Internetzugang hat. Für den Offline-Start ist außerdem ein kleines, handkuratiertes Basis-Kartenset eingebaut (`src/data/fixtureCards.ts`), das nur bei fehlendem Netzwerk als Fallback dient und dessen Karten-Text/Werte als vorläufig zu betrachten sind.

## Als Android-APK bauen

1. `npm run build` – erzeugt `dist/`
2. `npx cap sync android` – kopiert den Build in das Android-Projekt (`android/`)
3. Android-Projekt in [Android Studio](https://developer.android.com/studio) öffnen (`npx cap open android` auf einem Rechner mit installiertem Android Studio) und über *Build → Build APK(s)* eine APK erzeugen, oder per `./gradlew assembleDebug` im `android/`-Ordner bauen.

Schritt 3 benötigt das Android SDK, das in dieser Cloud-Entwicklungsumgebung nicht installiert ist – die APK-Erstellung muss daher auf deinem eigenen Rechner mit Android Studio erfolgen. Das `android/`-Projekt ist bereits vollständig vorbereitet (Portrait-Modus fest eingestellt, App-ID `com.duelvault.app`).

## Umfang dieser Version

- Voll spielbarer Shop/Booster/Binder/Deckbuilder-Kreislauf.
- Vereinfachte, aber authentisch aufgebaute Duell-Engine (Phasen, Tribute-Beschwörung, Kampf, ein Reaktionsfenster bei Angriffen für Fallen/Kuriboh).
- Rund 16 Karten mit vollständig nachgebauter Effektlogik (u. a. Dark Magician-Linie, Blue-Eyes/Red-Eyes-Fusion, Exodia-Sieg, Mirror Force, Magic Cylinder, Time Wizard). Alle anderen Karten sind spielbar, aber ohne besonderen Skript-Effekt (reine Stat-Karte).
