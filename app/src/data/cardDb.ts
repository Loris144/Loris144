import { fixtureCards, fixtureCardsById } from './fixtureCards'
import type { CardDef } from './types'

function normalizeName(name: string): string {
  return name.trim().toLowerCase()
}

const ARCHETYPE_PROTAGONIST: Record<string, CardDef['protagonist']> = {
  'Dark Magician': 'Yugi',
  'Blue-Eyes': 'Kaiba',
  'Red-Eyes': 'Joey',
  Exodia: 'Yugi',
  'Magnet Warrior': 'Yugi',
  Harpie: 'Mai',
  Toon: 'Pegasus',
  'Egyptian God': 'Marik',
  Orichalcos: 'Classic',
  Archfiend: 'Yugi',
  'Gaia The Fierce Knight': 'Yugi',
}

/**
 * Central card database. Starts from the bundled fixture so the app is
 * immediately playable offline. If the live YGOPRODeck API is reachable
 * (normal case on a real phone/browser), fetched cards are merged in and
 * take priority, giving accurate official data/images automatically.
 */
class CardDatabase {
  private cards: Map<number, CardDef> = new Map(Object.entries(fixtureCardsById).map(([id, c]) => [Number(id), c]))
  private byNameIndex: Map<string, number> = new Map(fixtureCards.map((c) => [normalizeName(c.name), c.id]))

  all(): CardDef[] {
    return Array.from(this.cards.values())
  }

  byId(id: number): CardDef | undefined {
    return this.cards.get(id)
  }

  byProtagonist(protagonist: CardDef['protagonist']): CardDef[] {
    return this.all().filter((c) => c.protagonist === protagonist)
  }

  /**
   * Merges live API results into the database, matched by card name. A card that already
   * exists (from the curated fixture) is upgraded in place — its game data (desc, ATK/DEF,
   * level, attribute, etc.) becomes accurate and it gets `officialId` set so its real artwork
   * loads — while keeping its original local id (and our own price/rarity tuning) stable, since
   * booster pools, decks, and fusion recipes reference that id. A card with no existing match
   * (real archetype support we hadn't curated) is added fresh under its real id.
   */
  merge(liveCards: CardDef[]): void {
    for (const live of liveCards) {
      const key = normalizeName(live.name)
      const existingId = this.byNameIndex.get(key)

      if (existingId !== undefined) {
        const existing = this.cards.get(existingId)
        if (!existing) continue
        this.cards.set(existingId, {
          ...existing,
          officialId: live.id,
          desc: live.desc,
          category: live.category,
          kind: live.kind,
          attribute: live.attribute,
          race: live.race,
          level: live.level,
          rank: live.rank,
          linkVal: live.linkVal,
          linkMarkers: live.linkMarkers,
          atk: live.atk,
          def: live.def,
          scale: live.scale,
          archetype: live.archetype ?? existing.archetype,
        })
      } else {
        const protagonist = live.archetype ? ARCHETYPE_PROTAGONIST[live.archetype] : undefined
        this.cards.set(live.id, { ...live, protagonist })
        this.byNameIndex.set(key, live.id)
      }
    }
  }
}

export const cardDb = new CardDatabase()
export { fixtureCards }
