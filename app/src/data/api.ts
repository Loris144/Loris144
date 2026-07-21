import type { Attribute, CardCategory, CardDef, Rarity } from './types'

/**
 * Live integration with the YGOPRODeck public API (https://ygoprodeck.com/api-guide/).
 * This runs fine on a real device/browser with normal internet access — it is
 * only unreachable inside this sandboxed dev/preview environment, which is why
 * the app falls back to `fixtureCards` when a fetch fails (see useCardDatabase).
 */
const API_BASE = 'https://db.ygoprodeck.com/api/v7'

interface YgoApiCardImage {
  id: number
  image_url: string
  image_url_small: string
}

interface YgoApiCardSet {
  set_name: string
  set_rarity: string
}

interface YgoApiCard {
  id: number
  name: string
  type: string
  frameType: string
  desc: string
  atk?: number
  def?: number
  level?: number
  race?: string
  attribute?: string
  archetype?: string
  linkval?: number
  linkmarkers?: string[]
  scale?: number
  card_images: YgoApiCardImage[]
  card_sets?: YgoApiCardSet[]
}

interface YgoApiResponse {
  data: YgoApiCard[]
}

function categoryFromType(type: string): CardCategory {
  if (type.includes('Spell')) return 'Spell'
  if (type.includes('Trap')) return 'Trap'
  return 'Monster'
}

function kindFromType(type: string, frameType: string): string {
  if (type.includes('Spell') || type.includes('Trap')) {
    const parts = type.split(' ')
    return parts.length > 1 ? parts[0] : 'Normal'
  }
  return frameType.charAt(0).toUpperCase() + frameType.slice(1)
}

function guessRarity(sets: YgoApiCardSet[] | undefined): Rarity {
  const rarities = (sets ?? []).map((s) => s.set_rarity)
  if (rarities.some((r) => r.includes('Secret'))) return 'Secret Rare'
  if (rarities.some((r) => r.includes('Ultra'))) return 'Ultra Rare'
  if (rarities.some((r) => r.includes('Super'))) return 'Super Rare'
  if (rarities.some((r) => r.includes('Rare'))) return 'Rare'
  return 'Common'
}

function priceForRarity(rarity: Rarity): number {
  switch (rarity) {
    case 'Secret Rare': return 2000
    case 'Ultra Rare': return 800
    case 'Super Rare': return 400
    case 'Rare': return 150
    default: return 50
  }
}

function toCardDef(c: YgoApiCard): CardDef {
  const category = categoryFromType(c.type)
  const rarity = guessRarity(c.card_sets)
  return {
    id: c.id,
    name: c.name,
    category,
    kind: kindFromType(c.type, c.frameType),
    desc: c.desc,
    archetype: c.archetype,
    attribute: c.attribute as Attribute | undefined,
    race: c.race,
    level: c.level,
    linkVal: c.linkval,
    linkMarkers: c.linkmarkers,
    atk: c.atk,
    def: c.def,
    scale: c.scale,
    rarity,
    price: priceForRarity(rarity),
  }
}

export async function fetchCardsByArchetype(archetype: string): Promise<CardDef[]> {
  const res = await fetch(`${API_BASE}/cardinfo.php?archetype=${encodeURIComponent(archetype)}`)
  if (!res.ok) throw new Error(`YGOPRODeck request failed: ${res.status}`)
  const json = (await res.json()) as YgoApiResponse
  return json.data.map(toCardDef)
}

/** Runs `fn` over `items` with at most `limit` requests in flight at once, so a large batch (e.g.
 * dozens of archetypes plus a full card-name list at app startup) can't burst past YGOPRODeck's
 * documented ~20 requests/second rate limit. */
export async function runThrottled<T, R>(items: T[], limit: number, fn: (item: T) => Promise<R>): Promise<PromiseSettledResult<R>[]> {
  const results: PromiseSettledResult<R>[] = new Array(items.length)
  let nextIndex = 0

  async function worker() {
    while (nextIndex < items.length) {
      const i = nextIndex++
      try {
        results[i] = { status: 'fulfilled', value: await fn(items[i]) }
      } catch (error) {
        results[i] = { status: 'rejected', reason: error }
      }
    }
  }

  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker))
  return results
}

/** Looks up a curated list of specific card names — used for classic duelists whose signature
 * cards aren't grouped under one named Konami archetype (e.g. Rex Raptor's Dinosaurs, Marik's
 * Egyptian God cards). Each name is looked up individually so one bad/renamed entry can't fail
 * the whole batch, throttled to stay under the API's rate limit. */
export async function fetchCardsByNames(names: string[]): Promise<CardDef[]> {
  const results = await runThrottled(names, 8, (name) => fetchCardByName(name))
  const cards: CardDef[] = []
  for (const r of results) {
    if (r.status === 'fulfilled' && r.value) cards.push(r.value)
  }
  return cards
}

export async function fetchCardByName(name: string): Promise<CardDef | null> {
  const res = await fetch(`${API_BASE}/cardinfo.php?name=${encodeURIComponent(name)}`)
  if (!res.ok) return null
  const json = (await res.json()) as YgoApiResponse
  return json.data[0] ? toCardDef(json.data[0]) : null
}

export async function fetchCardsByIds(ids: number[]): Promise<CardDef[]> {
  const res = await fetch(`${API_BASE}/cardinfo.php?id=${ids.join(',')}`)
  if (!res.ok) throw new Error(`YGOPRODeck request failed: ${res.status}`)
  const json = (await res.json()) as YgoApiResponse
  return json.data.map(toCardDef)
}
