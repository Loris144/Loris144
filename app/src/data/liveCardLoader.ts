import { fetchCardsByArchetype } from './api'
import { cardDb } from './cardDb'
import { useCardDbStore } from './cardDbStore'

const ARCHETYPES = ['Dark Magician', 'Blue-Eyes', 'Red-Eyes', 'Exodia']

/**
 * Fetches the full official card pool for the archetypes this app cares about and merges it
 * into cardDb. Safe to call once at app startup: if there's no network (e.g. this dev sandbox),
 * every fetch rejects and the app just keeps using the bundled offline fixture — no error is
 * thrown up to the caller.
 */
export async function loadLiveCardData(): Promise<void> {
  useCardDbStore.getState().markLoading()

  const results = await Promise.allSettled(ARCHETYPES.map((archetype) => fetchCardsByArchetype(archetype)))

  let mergedAny = false
  for (const result of results) {
    if (result.status === 'fulfilled' && result.value.length > 0) {
      cardDb.merge(result.value)
      mergedAny = true
    }
  }

  if (mergedAny) {
    useCardDbStore.getState().markUpdated()
  } else {
    useCardDbStore.getState().markError()
  }
}
