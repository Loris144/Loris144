#!/usr/bin/env python3
"""
fetch_classic_support.py
------------------------
Zieht ueber die YGOPRODeck-API alle Mitglieder + Support-Karten fuer die in
classic_archetypes.json gelisteten klassischen Yu-Gi-Oh-Archetypen.

Ausgabe:
  - classic_yugioh_cards.json  (nach Archetyp gruppiert, volle Kartendaten)
  - classic_yugioh_cards.csv   (flache Liste, dedupliziert)

Nur Standardbibliothek noetig (urllib). Python 3.8+.

Nutzung:
  python3 fetch_classic_support.py
  python3 fetch_classic_support.py --include-optional        # deep cuts dazu
  python3 fetch_classic_support.py --include-broad           # breite Umbrella-Tags dazu
  python3 fetch_classic_support.py --lang de                 # deutsche Kartennamen/-texte
  python3 fetch_classic_support.py --config meine_liste.json

API-Doku: https://ygoprodeck.com/api-guide/   (Rate-Limit: 20 req/s)
"""

import argparse
import csv
import json
import sys
import time
import urllib.parse
import urllib.request

API = "https://db.ygoprodeck.com/api/v7/cardinfo.php"
USER_AGENT = "classic-ygo-collector/1.0 (personal script)"
SLEEP = 0.15  # ~7 req/s, gut unter dem 20/s-Limit


def http_get_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8")), None
    except urllib.error.HTTPError as e:
        # 400 = "No card matching your query" -> kein Fehler, nur leer
        if e.code == 400:
            return {"data": []}, None
        return None, f"HTTP {e.code}"
    except Exception as e:  # noqa: BLE001
        return None, str(e)


def fetch_archetype(name, lang=None):
    params = {"archetype": name}
    if lang:
        params["language"] = lang
    url = API + "?" + urllib.parse.urlencode(params)
    data, err = http_get_json(url)
    if err:
        print(f"  ! Fehler bei '{name}': {err}", file=sys.stderr)
        return []
    return data.get("data", []) or []


def load_config(path):
    with open(path, encoding="utf-8") as f:
        cfg = json.load(f)
    return cfg


def collect_targets(cfg, include_optional, include_broad):
    targets = list(cfg.get("core", []))
    if include_optional:
        targets += cfg.get("optional_deep_cuts", [])
    if include_broad:
        targets += cfg.get("breit_mit_vorsicht", [])
    # nur Eintraege mit gueltigem api_archetype
    return [t for t in targets if t.get("api_archetype")]


def slim(card):
    """Reduziert einen API-Kartensatz auf die wichtigsten Felder."""
    return {
        "id": card.get("id"),
        "name": card.get("name"),
        "type": card.get("type"),
        "frameType": card.get("frameType"),
        "race": card.get("race"),
        "attribute": card.get("attribute"),
        "level": card.get("level"),
        "linkval": card.get("linkval"),
        "atk": card.get("atk"),
        "def": card.get("def"),
        "archetype_api": card.get("archetype"),
        "desc": card.get("desc"),
        "sets": [s.get("set_name") for s in card.get("card_sets", [])] if card.get("card_sets") else [],
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", default="classic_archetypes.json")
    ap.add_argument("--include-optional", action="store_true")
    ap.add_argument("--include-broad", action="store_true")
    ap.add_argument("--lang", default=None, help="z.B. 'de' fuer deutsche Namen")
    ap.add_argument("--out-json", default="classic_yugioh_cards.json")
    ap.add_argument("--out-csv", default="classic_yugioh_cards.csv")
    args = ap.parse_args()

    cfg = load_config(args.config)
    targets = collect_targets(cfg, args.include_optional, args.include_broad)
    print(f"Ziehe {len(targets)} Archetypen von YGOPRODeck ...")

    grouped = {}          # api_archetype -> [slim cards]
    unique = {}           # card id -> slim card (dedupliziert)
    empty = []            # Archetypen ohne Treffer (Namens-Mismatch pruefen)

    for i, t in enumerate(targets, 1):
        name = t["api_archetype"]
        cards = fetch_archetype(name, args.lang)
        grouped[name] = [slim(c) for c in cards]
        for c in cards:
            unique[c.get("id")] = slim(c)
        if not cards:
            empty.append(name)
        print(f"  [{i:>2}/{len(targets)}] {name:<30} {len(cards):>4} Karten")
        time.sleep(SLEEP)

    # JSON gruppiert schreiben
    out = {
        "_generated": time.strftime("%Y-%m-%d %H:%M:%S"),
        "_language": args.lang or "en",
        "_archetype_count": len(grouped),
        "_unique_card_count": len(unique),
        "by_archetype": grouped,
    }
    with open(args.out_json, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    # CSV flach schreiben
    fields = ["id", "name", "type", "race", "attribute", "level", "linkval",
              "atk", "def", "archetype_api", "sets", "desc"]
    with open(args.out_csv, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        for c in unique.values():
            row = dict(c)
            row["sets"] = "; ".join(row.get("sets") or [])
            w.writerow(row)

    print("\nFertig.")
    print(f"  {len(unique)} eindeutige Karten -> {args.out_json} / {args.out_csv}")
    if empty:
        print("\n  ! Kein Treffer (API-String pruefen gegen archetypes.php):")
        for n in empty:
            print(f"    - {n}")


if __name__ == "__main__":
    main()
