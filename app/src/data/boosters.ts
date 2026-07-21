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
    cardPool: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 21, 22, 23, 24, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 130, 131, 132, 260, 261, 280, 281, 282, 283, 284, 292],
    rarityWeights: defaultWeights,
  }),
  withBoxEconomics({
    id: 'eyes-of-blue',
    name: 'Eyes of Blue',
    cardPool: [2, 60, 61, 62, 63, 64, 65, 66, 67, 68, 90, 110, 111, 112, 113, 114, 287, 288],
    rarityWeights: defaultWeights,
  }),
  withBoxEconomics({
    id: 'dragons-roar',
    name: "Dragon's Roar",
    cardPool: [3, 70, 71, 72, 73, 74, 75, 76, 77, 78, 120, 121, 122, 123],
    rarityWeights: defaultWeights,
  }),
  withBoxEconomics({
    id: 'mystic-mages',
    name: 'Mystic Mages',
    cardPool: [1, 50, 51, 52, 53, 54, 55, 56, 91, 100, 101, 102, 103, 104],
    rarityWeights: defaultWeights,
  }),
  withBoxEconomics({
    id: 'forbidden-relics',
    name: 'Forbidden Relics',
    cardPool: [16, 17, 18, 19, 20, 21, 22, 23, 24, 285, 286],
    rarityWeights: { Common: 40, Rare: 30, 'Super Rare': 15, 'Ultra Rare': 10, 'Secret Rare': 5 },
  }),
  withBoxEconomics({
    id: 'jurassic-duel',
    name: 'Jurassic Duel',
    cardPool: [200, 201, 202, 203, 204],
    rarityWeights: defaultWeights,
  }),
  withBoxEconomics({
    id: 'swarm-of-insects',
    name: 'Swarm of Insects',
    cardPool: [15, 24, 210, 211, 212, 213],
    rarityWeights: defaultWeights,
  }),
  withBoxEconomics({
    id: 'harpies-nest',
    name: "Harpie's Nest",
    cardPool: [220, 221, 222, 223, 224, 225, 226, 132],
    rarityWeights: defaultWeights,
  }),
  withBoxEconomics({
    id: 'toon-carnival',
    name: 'Toon Carnival',
    cardPool: [230, 231, 232, 233, 234, 235],
    rarityWeights: defaultWeights,
  }),
  withBoxEconomics({
    id: 'millennium-rare-hunter',
    name: 'Millennium Rare Hunter',
    cardPool: [240, 241, 242, 243, 244, 250, 251, 289, 290, 291],
    rarityWeights: { Common: 20, Rare: 30, 'Super Rare': 25, 'Ultra Rare': 15, 'Secret Rare': 10 },
  }),
  withBoxEconomics({
    id: 'magnet-force',
    name: 'Magnet Force',
    cardPool: [270, 271, 272, 273, 274, 275, 276, 277, 278, 279],
    rarityWeights: defaultWeights,
  }),
]

export const CARDS_PER_PACK = 5
