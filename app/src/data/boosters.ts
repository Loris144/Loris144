import type { BoosterSet, Rarity } from './types'

const defaultWeights: Record<Rarity, number> = {
  Common: 60,
  Rare: 25,
  'Super Rare': 10,
  'Ultra Rare': 4,
  'Secret Rare': 1,
}

const PACKS_PER_BOX = 12
const FLAT_PACK_PRICE = 250
const FLAT_BOX_PRICE = 1500

function withBoxEconomics(set: Omit<BoosterSet, 'price' | 'packsPerBox' | 'wholesalePricePerBox'>): BoosterSet {
  return {
    ...set,
    price: FLAT_PACK_PRICE,
    packsPerBox: PACKS_PER_BOX,
    wholesalePricePerBox: FLAT_BOX_PRICE,
  }
}

export const boosterSets: BoosterSet[] = [
  withBoxEconomics({
    id: 'legend-of-duelists',
    name: 'Legend of the Duelists',
    cardPool: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 21, 22, 23, 24, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42],
    rarityWeights: defaultWeights,
  }),
  withBoxEconomics({
    id: 'eyes-of-blue',
    name: 'Eyes of Blue',
    cardPool: [2, 60, 61, 62, 63, 64, 65, 66, 67, 68, 90],
    rarityWeights: defaultWeights,
  }),
  withBoxEconomics({
    id: 'dragons-roar',
    name: "Dragon's Roar",
    cardPool: [3, 70, 71, 72, 73, 74, 75, 76, 77, 78],
    rarityWeights: defaultWeights,
  }),
  withBoxEconomics({
    id: 'mystic-mages',
    name: 'Mystic Mages',
    cardPool: [1, 50, 51, 52, 53, 54, 55, 56, 91],
    rarityWeights: defaultWeights,
  }),
  withBoxEconomics({
    id: 'forbidden-relics',
    name: 'Forbidden Relics',
    cardPool: [16, 17, 18, 19, 20, 21, 22, 23, 24],
    rarityWeights: { Common: 40, Rare: 30, 'Super Rare': 15, 'Ultra Rare': 10, 'Secret Rare': 5 },
  }),
]

export const CARDS_PER_PACK = 5
