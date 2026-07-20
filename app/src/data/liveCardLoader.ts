import { fetchCardsByArchetype, fetchCardsByNames } from './api'
import { cardDb } from './cardDb'
import { useCardDbStore } from './cardDbStore'

/** Real Konami archetypes covering the classic cast's card lines and their modern support. */
const ARCHETYPES = [
  'Dark Magician', // Yugi
  'Blue-Eyes', // Kaiba
  'Red-Eyes', // Joey
  'Exodia', // Yugi
  'Magnet Warrior', // Yugi (late-series / movie)
  'Harpie', // Mai Valentine
  'Toon', // Maximillion Pegasus
  'Egyptian God', // Marik / the Pharaoh's rivals
  'Orichalcos', // Seal of Orichalcos arc
]

/**
 * Specific signature cards for classic duelists whose deck isn't one named Konami archetype —
 * looked up by exact name instead.
 */
const NAMED_CARDS = [
  // Egyptian Gods
  'Slifer the Sky Dragon',
  'Obelisk the Tormentor',
  'The Winged Dragon of Ra',
  'The Winged Dragon of Ra - Sphere Mode',
  'The Winged Dragon of Ra - Immortal Phoenix',
  // Rex Raptor (Dinosaur deck)
  'Serpent Night Dragon',
  'Black Tyranno',
  'Two-Headed King Rex',
  'Uraby',
  // Weevil Underwood (Insect deck)
  'Insect Queen',
  'Man-Eater Bug',
  'Basic Insect',
  'Great Moth',
  'Cocoon of Evolution',
  // Maximillion Pegasus
  'Relinquished',
  'Toon World',
  'Toon Alligator',
  // Yami Bakura
  'Dark Necrofear',
  'Diabound Kernel',
  // The Seal of Orichalcos arc
  'The Seal of Orichalcos',
]

/**
 * Fetches the full official card pool for the archetypes/cards this app cares about and merges
 * it into cardDb. Safe to call once at app startup: if there's no network (e.g. this dev
 * sandbox), every fetch rejects and the app just keeps using the bundled offline fixture — no
 * error is thrown up to the caller.
 */
export async function loadLiveCardData(): Promise<void> {
  useCardDbStore.getState().markLoading()

  const [archetypeResults, namedCards] = await Promise.all([
    Promise.allSettled(ARCHETYPES.map((archetype) => fetchCardsByArchetype(archetype))),
    fetchCardsByNames(NAMED_CARDS).catch(() => []),
  ])

  let mergedAny = false
  for (const result of archetypeResults) {
    if (result.status === 'fulfilled' && result.value.length > 0) {
      cardDb.merge(result.value)
      mergedAny = true
    }
  }
  if (namedCards.length > 0) {
    cardDb.merge(namedCards)
    mergedAny = true
  }

  if (mergedAny) {
    useCardDbStore.getState().markUpdated()
  } else {
    useCardDbStore.getState().markError()
  }
}
