import { fixtureCards, fixtureCardsById } from './fixtureCards'
import type { CardDef } from './types'

/**
 * Central card database. Starts from the bundled fixture so the app is
 * immediately playable offline. If the live YGOPRODeck API is reachable
 * (normal case on a real phone/browser), fetched cards are merged in and
 * take priority, giving accurate official data/images automatically.
 */
class CardDatabase {
  private cards: Map<number, CardDef> = new Map(Object.entries(fixtureCardsById).map(([id, c]) => [Number(id), c]))

  all(): CardDef[] {
    return Array.from(this.cards.values())
  }

  byId(id: number): CardDef | undefined {
    return this.cards.get(id)
  }

  byProtagonist(protagonist: CardDef['protagonist']): CardDef[] {
    return this.all().filter((c) => c.protagonist === protagonist)
  }

  merge(cards: CardDef[]): void {
    for (const c of cards) this.cards.set(c.id, c)
  }
}

export const cardDb = new CardDatabase()
export { fixtureCards }
