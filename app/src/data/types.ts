export type CardCategory = 'Monster' | 'Spell' | 'Trap'

export type MonsterKind =
  | 'Normal'
  | 'Effect'
  | 'Ritual'
  | 'Fusion'
  | 'Synchro'
  | 'Xyz'
  | 'Link'
  | 'Pendulum'
  | 'Toon'
  | 'Spirit'
  | 'Union'
  | 'Gemini'
  | 'Tuner'

export type Attribute =
  | 'DARK'
  | 'LIGHT'
  | 'EARTH'
  | 'WATER'
  | 'FIRE'
  | 'WIND'
  | 'DIVINE'

export type SpellTrapKind =
  | 'Normal'
  | 'Continuous'
  | 'Quick-Play'
  | 'Equip'
  | 'Field'
  | 'Ritual'
  | 'Counter'

export type Rarity =
  | 'Common'
  | 'Rare'
  | 'Super Rare'
  | 'Ultra Rare'
  | 'Secret Rare'

export interface CardDef {
  id: number
  name: string
  category: CardCategory
  /** For monsters: Effect/Fusion/Synchro/etc. For spell/trap: Normal/Continuous/etc. */
  kind: string
  desc: string
  archetype?: string
  protagonist?: 'Yugi' | 'Kaiba' | 'Joey' | 'Classic'

  // Monster-only fields
  attribute?: Attribute
  race?: string
  level?: number
  rank?: number
  linkVal?: number
  linkMarkers?: string[]
  atk?: number
  def?: number
  scale?: number

  rarity: Rarity
  price: number
}

/** A physical copy owned by the player. Multiple copies share the same cardId. */
export interface OwnedCard {
  instanceId: string
  cardId: number
}

export interface BoosterSet {
  id: string
  name: string
  /** suggested retail price per pack; players can override this in their own shop */
  price: number
  cardPool: number[]
  /** relative pull weights by rarity within this set */
  rarityWeights: Record<Rarity, number>
  packsPerBox: number
  wholesalePricePerBox: number
}

export interface Deck {
  id: string
  name: string
  main: number[]
  extra: number[]
}

export function cardImageUrl(cardId: number): string {
  return `https://images.ygoprodeck.com/images/cards/${cardId}.jpg`
}

export function cardImageUrlSmall(cardId: number): string {
  return `https://images.ygoprodeck.com/images/cards_small/${cardId}.jpg`
}
