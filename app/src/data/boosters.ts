import type { BoosterSet, Rarity } from './types'

const defaultWeights: Record<Rarity, number> = {
  Common: 60,
  Rare: 25,
  'Super Rare': 10,
  'Ultra Rare': 4,
  'Secret Rare': 1,
}

const PACKS_PER_BOX = 12
const WHOLESALE_MARGIN = 0.55 // wholesale box price = 55% of (packs * suggested retail price)

function withBoxEconomics(set: Omit<BoosterSet, 'packsPerBox' | 'wholesalePricePerBox'>): BoosterSet {
  return {
    ...set,
    packsPerBox: PACKS_PER_BOX,
    wholesalePricePerBox: Math.round(set.price * PACKS_PER_BOX * WHOLESALE_MARGIN),
  }
}

export const boosterSets: BoosterSet[] = [
  withBoxEconomics({
    id: 'legend-of-duelists',
    name: 'Legend of the Duelists',
    price: 300,
    cardPool: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 21, 22, 23, 24, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42],
    rarityWeights: defaultWeights,
  }),
  withBoxEconomics({
    id: 'eyes-of-blue',
    name: 'Eyes of Blue',
    price: 350,
    cardPool: [2, 60, 61, 62, 63, 64, 65, 66, 67, 68, 90],
    rarityWeights: defaultWeights,
  }),
  withBoxEconomics({
    id: 'dragons-roar',
    name: "Dragon's Roar",
    price: 350,
    cardPool: [3, 70, 71, 72, 73, 74, 75, 76, 77, 78],
    rarityWeights: defaultWeights,
  }),
  withBoxEconomics({
    id: 'mystic-mages',
    name: 'Mystic Mages',
    price: 350,
    cardPool: [1, 50, 51, 52, 53, 54, 55, 56, 91],
    rarityWeights: defaultWeights,
  }),
  withBoxEconomics({
    id: 'forbidden-relics',
    name: 'Forbidden Relics',
    price: 500,
    cardPool: [16, 17, 18, 19, 20, 21, 22, 23, 24],
    rarityWeights: { Common: 40, Rare: 30, 'Super Rare': 15, 'Ultra Rare': 10, 'Secret Rare': 5 },
  }),
]

export const CARDS_PER_PACK = 5
