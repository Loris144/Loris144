import { fetchCardsByArchetype, fetchCardsByNames, runThrottled } from './api'
import { cardDb } from './cardDb'
import { useCardDbStore } from './cardDbStore'
import { fixtureCards } from './fixtureCards'

/**
 * Real Konami archetypes covering the classic cast's card lines and their modern support.
 * Pulled in addition to the exact-name lookup below so related official cards not yet in the
 * offline fixture (e.g. brand-new support) can still be discovered automatically.
 *
 * The bulk of this list (from "Magician Girl" down) comes from a curated
 * `classic_archetypes.json` the user supplied — every `api_archetype` string from its `core` and
 * `optional_deep_cuts` sections, verified against https://db.ygoprodeck.com/api/v7/archetypes.php.
 * Its `breit_mit_vorsicht` section (Magician / Magnet / Chaos) is deliberately left out: those are
 * umbrella tags the file itself flags as pulling in non-classic cards (e.g. ARC-V Pendulum
 * magicians), so they're opt-in rather than automatic.
 */
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
  'Archfiend', // Summoned Skull's real archetype tag (Yugi)
  'Gaia The Fierce Knight', // Gaia's real archetype (Yugi)
  'Magician Girl',
  'Skilled Magician',
  'Silent Magician',
  'Silent Swordsman',
  'Kuriboh',
  'Magna Warrior',
  'Black Luster Soldier',
  'Gaia Knight',
  'Gandora',
  'Curse of Dragon',
  'Mokey Mokey',
  'Exodd',
  'Ra',
  'Wicked God',
  'Timaeus',
  'Legendary Knight',
  'with Eyes of Blue',
  'Flame Swordsman',
  'Dark Time Wizard',
  'Amazoness',
  'Relinquished',
  'Eyes Restrict',
  'Millennium',
  "Gravekeeper's",
  'Slime',
  'Gate Guardian',
  'Sangen',
  'Labyrinth Wall',
  'Spirit Message',
  'Dark Scorpion',
  'Jinzo',
  'Gadget',
  'Skull Servant',
  'Wight',
  'Sphinx',
  // optional_deep_cuts
  'Umi',
  'Atlantis, the Dragon City',
  'The Sanctuary in the Sky',
  'Temple of the Kings',
  'Daedalus',
  'Doriado',
  'Man-Eater Bug',
  'Parasite',
  'Guardian',
  'Horus the Black Flame Dragon',
]

/**
 * Fetches official data — including each card's real artwork — for EVERY card in the offline
 * fixture, by exact name, plus a handful of whole archetypes for extra coverage. Merges the
 * result into cardDb so each card gets its own correct `officialId`, instead of only a curated
 * subset. Safe to call once at app startup: if there's no network (e.g. this dev sandbox), every
 * fetch rejects and the app just keeps using the bundled offline fixture — no error is thrown up
 * to the caller.
 */
export async function loadLiveCardData(): Promise<void> {
  useCardDbStore.getState().markLoading()

  const allNames = fixtureCards.map((c) => c.name)

  const [archetypeResults, namedCards] = await Promise.all([
    runThrottled(ARCHETYPES, 8, (archetype) => fetchCardsByArchetype(archetype)),
    fetchCardsByNames(allNames).catch(() => []),
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
