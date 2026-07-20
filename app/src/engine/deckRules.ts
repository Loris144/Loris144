import { cardDb } from '../data/cardDb'
import type { Deck } from '../data/types'

export const EXTRA_DECK_KINDS = new Set(['Fusion', 'Synchro', 'Xyz', 'Link'])

export function isExtraDeckCard(cardId: number): boolean {
  const card = cardDb.byId(cardId)
  return !!card && EXTRA_DECK_KINDS.has(card.kind)
}

export interface DeckValidation {
  valid: boolean
  issues: string[]
}

export function validateDeck(deck: Deck): DeckValidation {
  const issues: string[] = []
  if (deck.main.length < 40) issues.push(`Hauptdeck braucht mindestens 40 Karten (aktuell ${deck.main.length})`)
  if (deck.main.length > 60) issues.push(`Hauptdeck darf maximal 60 Karten haben (aktuell ${deck.main.length})`)
  if (deck.extra.length > 15) issues.push(`Extra Deck darf maximal 15 Karten haben (aktuell ${deck.extra.length})`)

  const counts = new Map<number, number>()
  for (const id of [...deck.main, ...deck.extra]) counts.set(id, (counts.get(id) ?? 0) + 1)
  for (const [id, count] of counts) {
    if (count > 3) {
      const card = cardDb.byId(id)
      issues.push(`Maximal 3 Kopien von "${card?.name ?? id}" erlaubt (aktuell ${count})`)
    }
  }

  return { valid: issues.length === 0, issues }
}
