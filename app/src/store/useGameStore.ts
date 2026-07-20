import { create } from 'zustand'
import { persist } from 'zustand/middleware'
import { boosterSets, CARDS_PER_PACK } from '../data/boosters'
import { cardDb } from '../data/cardDb'
import { COUNTER_CELL, DOOR_CELL, GRID_H, GRID_W, furnitureDefs, type FurnitureType } from '../data/furniture'
import type { CaseSlot, PlacedFurniture } from '../shopsim/types'
import type { Deck, OwnedCard, Rarity } from '../data/types'

const STARTING_DP = 2000
const COUNTER_ID = 'counter-1'

function uid(): string {
  return Math.random().toString(36).slice(2) + Date.now().toString(36)
}

function pickRarity(weights: Record<Rarity, number>): Rarity {
  const entries = Object.entries(weights) as [Rarity, number][]
  const total = entries.reduce((sum, [, w]) => sum + w, 0)
  let roll = Math.random() * total
  for (const [rarity, weight] of entries) {
    if (roll < weight) return rarity
    roll -= weight
  }
  return entries[0][0]
}

function cellsFor(x: number, y: number, w: number, h: number): { x: number; y: number }[] {
  const cells: { x: number; y: number }[] = []
  for (let dx = 0; dx < w; dx++) {
    for (let dy = 0; dy < h; dy++) cells.push({ x: x + dx, y: y + dy })
  }
  return cells
}

function isAreaFree(layout: PlacedFurniture[], x: number, y: number, w: number, h: number): boolean {
  if (x < 0 || y < 0 || x + w > GRID_W || y + h > GRID_H) return false
  const wanted = cellsFor(x, y, w, h)
  if (wanted.some((c) => c.x === DOOR_CELL.x && c.y === DOOR_CELL.y)) return false
  for (const f of layout) {
    const def = furnitureDefs[f.type]
    const occupied = cellsFor(f.x, f.y, def.footprintW, def.footprintH)
    if (occupied.some((oc) => wanted.some((wc) => wc.x === oc.x && wc.y === oc.y))) return false
  }
  return true
}

const defaultShopLayout: PlacedFurniture[] = [
  { id: COUNTER_ID, type: 'counter', x: COUNTER_CELL.x, y: COUNTER_CELL.y },
]

interface GameState {
  duelPoints: number
  ownedCards: OwnedCard[]
  unopenedBoosters: Record<string, number>
  decks: Deck[]
  activeDeckId: string | null
  wins: number
  losses: number

  buyBooster: (boosterId: string) => boolean
  sellBooster: (boosterId: string) => void
  openBooster: (boosterId: string) => OwnedCard[]
  buySingle: (cardId: number) => boolean
  sellCard: (instanceId: string) => void

  createDeck: (name: string) => string
  renameDeck: (deckId: string, name: string) => void
  deleteDeck: (deckId: string) => void
  setDeckCards: (deckId: string, main: number[], extra: number[]) => void
  setActiveDeck: (deckId: string) => void

  recordDuelResult: (won: boolean) => void

  // --- Shop simulation ---
  warehouseBoxes: Record<string, number>
  shopLayout: PlacedFurniture[]
  shopOpen: boolean

  buyBoxWholesale: (boosterId: string, qty: number) => boolean
  breakBoxForPersonalUse: (boosterId: string) => boolean
  buildFurniture: (type: FurnitureType, x: number, y: number) => boolean
  removeFurniture: (furnitureId: string) => void
  setShelfPrice: (furnitureId: string, price: number) => void
  assignShelfSet: (furnitureId: string, boosterId: string) => void
  restockShelf: (furnitureId: string) => boolean
  stockCase: (furnitureId: string, instanceId: string, price?: number) => boolean
  unstockCase: (furnitureId: string, slotIndex: number) => void
  setCasePrice: (furnitureId: string, slotIndex: number, price: number) => void
  toggleShopOpen: () => void
  sellPackFromShelf: (furnitureId: string) => number | null
  sellCardFromCase: (furnitureId: string, slotIndex: number) => number | null
  collectRevenue: (amount: number) => void
}

export const useGameStore = create<GameState>()(
  persist(
    (set, get) => ({
      duelPoints: STARTING_DP,
      ownedCards: [],
      unopenedBoosters: {},
      decks: [],
      activeDeckId: null,
      wins: 0,
      losses: 0,

      warehouseBoxes: {},
      shopLayout: defaultShopLayout,
      shopOpen: true,

      buyBooster: (boosterId) => {
        const set_ = boosterSets.find((b) => b.id === boosterId)
        if (!set_) return false
        if (get().duelPoints < set_.price) return false
        set((s) => ({
          duelPoints: s.duelPoints - set_.price,
          unopenedBoosters: {
            ...s.unopenedBoosters,
            [boosterId]: (s.unopenedBoosters[boosterId] ?? 0) + 1,
          },
        }))
        return true
      },

      sellBooster: (boosterId) => {
        const set_ = boosterSets.find((b) => b.id === boosterId)
        if (!set_) return
        const owned = get().unopenedBoosters[boosterId] ?? 0
        if (owned <= 0) return
        const refund = Math.floor(set_.price * 0.4)
        set((s) => ({
          duelPoints: s.duelPoints + refund,
          unopenedBoosters: { ...s.unopenedBoosters, [boosterId]: owned - 1 },
        }))
      },

      openBooster: (boosterId) => {
        const set_ = boosterSets.find((b) => b.id === boosterId)
        const owned = get().unopenedBoosters[boosterId] ?? 0
        if (!set_ || owned <= 0) return []

        const pulls: OwnedCard[] = []
        for (let i = 0; i < CARDS_PER_PACK; i++) {
          const rarity = pickRarity(set_.rarityWeights)
          const candidates = set_.cardPool
            .map((id) => cardDb.byId(id))
            .filter((c): c is NonNullable<typeof c> => !!c && c.rarity === rarity)
          const pool = candidates.length > 0
            ? candidates
            : set_.cardPool.map((id) => cardDb.byId(id)).filter((c): c is NonNullable<typeof c> => !!c)
          const card = pool[Math.floor(Math.random() * pool.length)]
          if (card) pulls.push({ instanceId: uid(), cardId: card.id })
        }

        set((s) => ({
          unopenedBoosters: { ...s.unopenedBoosters, [boosterId]: owned - 1 },
          ownedCards: [...s.ownedCards, ...pulls],
        }))
        return pulls
      },

      buySingle: (cardId) => {
        const card = cardDb.byId(cardId)
        if (!card) return false
        if (get().duelPoints < card.price) return false
        set((s) => ({
          duelPoints: s.duelPoints - card.price,
          ownedCards: [...s.ownedCards, { instanceId: uid(), cardId }],
        }))
        return true
      },

      sellCard: (instanceId) => {
        const owned = get().ownedCards.find((c) => c.instanceId === instanceId)
        if (!owned) return
        const card = cardDb.byId(owned.cardId)
        const refund = card ? Math.floor(card.price * 0.4) : 0
        set((s) => ({
          duelPoints: s.duelPoints + refund,
          ownedCards: s.ownedCards.filter((c) => c.instanceId !== instanceId),
          decks: s.decks.map((d) => ({
            ...d,
            main: d.main,
            extra: d.extra,
          })),
        }))
      },

      createDeck: (name) => {
        const id = uid()
        const deck: Deck = { id, name, main: [], extra: [] }
        set((s) => ({ decks: [...s.decks, deck], activeDeckId: s.activeDeckId ?? id }))
        return id
      },

      renameDeck: (deckId, name) => {
        set((s) => ({ decks: s.decks.map((d) => (d.id === deckId ? { ...d, name } : d)) }))
      },

      deleteDeck: (deckId) => {
        set((s) => ({
          decks: s.decks.filter((d) => d.id !== deckId),
          activeDeckId: s.activeDeckId === deckId ? (s.decks.find((d) => d.id !== deckId)?.id ?? null) : s.activeDeckId,
        }))
      },

      setDeckCards: (deckId, main, extra) => {
        set((s) => ({ decks: s.decks.map((d) => (d.id === deckId ? { ...d, main, extra } : d)) }))
      },

      setActiveDeck: (deckId) => set({ activeDeckId: deckId }),

      recordDuelResult: (won) => {
        set((s) => ({
          wins: s.wins + (won ? 1 : 0),
          losses: s.losses + (won ? 0 : 1),
          duelPoints: s.duelPoints + (won ? 400 : 100),
        }))
      },

      // --- Shop simulation ---

      buyBoxWholesale: (boosterId, qty) => {
        const set_ = boosterSets.find((b) => b.id === boosterId)
        if (!set_ || qty <= 0) return false
        const cost = set_.wholesalePricePerBox * qty
        if (get().duelPoints < cost) return false
        set((s) => ({
          duelPoints: s.duelPoints - cost,
          warehouseBoxes: { ...s.warehouseBoxes, [boosterId]: (s.warehouseBoxes[boosterId] ?? 0) + qty },
        }))
        return true
      },

      breakBoxForPersonalUse: (boosterId) => {
        const set_ = boosterSets.find((b) => b.id === boosterId)
        const owned = get().warehouseBoxes[boosterId] ?? 0
        if (!set_ || owned <= 0) return false
        set((s) => ({
          warehouseBoxes: { ...s.warehouseBoxes, [boosterId]: owned - 1 },
          unopenedBoosters: { ...s.unopenedBoosters, [boosterId]: (s.unopenedBoosters[boosterId] ?? 0) + set_.packsPerBox },
        }))
        return true
      },

      buildFurniture: (type, x, y) => {
        const def = furnitureDefs[type]
        if (!def || type === 'counter') return false
        if (get().duelPoints < def.cost) return false
        if (!isAreaFree(get().shopLayout, x, y, def.footprintW, def.footprintH)) return false
        const furniture: PlacedFurniture = {
          id: uid(),
          type,
          x,
          y,
          ...(type === 'shelf' ? { stockedPacks: 0, pricePerPack: 0 } : {}),
          ...(type === 'case' ? { caseSlots: [] } : {}),
        }
        set((s) => ({
          duelPoints: s.duelPoints - def.cost,
          shopLayout: [...s.shopLayout, furniture],
        }))
        return true
      },

      removeFurniture: (furnitureId) => {
        const layout = get().shopLayout
        const furniture = layout.find((f) => f.id === furnitureId)
        if (!furniture || furniture.type === 'counter') return
        const def = furnitureDefs[furniture.type]
        const refund = Math.floor(def.cost * 0.5)

        set((s) => {
          let ownedCards = s.ownedCards
          let refundTotal = refund

          if (furniture.type === 'case' && furniture.caseSlots) {
            ownedCards = [...ownedCards, ...furniture.caseSlots.map((slot) => ({ instanceId: slot.instanceId, cardId: slot.cardId }))]
          }
          if (furniture.type === 'shelf' && furniture.stockedPacks && furniture.assignedSetId) {
            const set_ = boosterSets.find((b) => b.id === furniture.assignedSetId)
            if (set_) refundTotal += Math.round((furniture.stockedPacks / set_.packsPerBox) * set_.wholesalePricePerBox)
          }

          return {
            ownedCards,
            duelPoints: s.duelPoints + refundTotal,
            shopLayout: s.shopLayout.filter((f) => f.id !== furnitureId),
          }
        })
      },

      setShelfPrice: (furnitureId, price) => {
        set((s) => ({
          shopLayout: s.shopLayout.map((f) => (f.id === furnitureId && f.type === 'shelf' ? { ...f, pricePerPack: Math.max(0, price) } : f)),
        }))
      },

      assignShelfSet: (furnitureId, boosterId) => {
        const set_ = boosterSets.find((b) => b.id === boosterId)
        if (!set_) return
        set((s) => ({
          shopLayout: s.shopLayout.map((f) =>
            f.id === furnitureId && f.type === 'shelf' && (!f.assignedSetId || f.stockedPacks === 0)
              ? { ...f, assignedSetId: boosterId, pricePerPack: f.pricePerPack || set_.price }
              : f,
          ),
        }))
      },

      restockShelf: (furnitureId) => {
        const layout = get().shopLayout
        const shelf = layout.find((f) => f.id === furnitureId)
        if (!shelf || shelf.type !== 'shelf' || !shelf.assignedSetId) return false
        const set_ = boosterSets.find((b) => b.id === shelf.assignedSetId)
        if (!set_) return false
        const boxesOwned = get().warehouseBoxes[shelf.assignedSetId] ?? 0
        if (boxesOwned <= 0) return false
        const capacityPacks = furnitureDefs.shelf.capacity * set_.packsPerBox
        const current = shelf.stockedPacks ?? 0
        if (current + set_.packsPerBox > capacityPacks) return false

        set((s) => ({
          warehouseBoxes: { ...s.warehouseBoxes, [shelf.assignedSetId!]: boxesOwned - 1 },
          shopLayout: s.shopLayout.map((f) => (f.id === furnitureId ? { ...f, stockedPacks: current + set_.packsPerBox } : f)),
        }))
        return true
      },

      stockCase: (furnitureId, instanceId, price) => {
        const owned = get().ownedCards.find((c) => c.instanceId === instanceId)
        const showcase = get().shopLayout.find((f) => f.id === furnitureId)
        if (!owned || !showcase || showcase.type !== 'case') return false
        const slots = showcase.caseSlots ?? []
        if (slots.length >= furnitureDefs.case.capacity) return false
        const cardDef = cardDb.byId(owned.cardId)
        const finalPrice = price ?? cardDef?.price ?? 0
        const newSlot: CaseSlot = { instanceId, cardId: owned.cardId, price: finalPrice }

        set((s) => ({
          ownedCards: s.ownedCards.filter((c) => c.instanceId !== instanceId),
          shopLayout: s.shopLayout.map((f) => (f.id === furnitureId ? { ...f, caseSlots: [...(f.caseSlots ?? []), newSlot] } : f)),
        }))
        return true
      },

      unstockCase: (furnitureId, slotIndex) => {
        const showcase = get().shopLayout.find((f) => f.id === furnitureId)
        if (!showcase || showcase.type !== 'case' || !showcase.caseSlots) return
        const slot = showcase.caseSlots[slotIndex]
        if (!slot) return
        set((s) => ({
          ownedCards: [...s.ownedCards, { instanceId: slot.instanceId, cardId: slot.cardId }],
          shopLayout: s.shopLayout.map((f) =>
            f.id === furnitureId ? { ...f, caseSlots: f.caseSlots!.filter((_, i) => i !== slotIndex) } : f,
          ),
        }))
      },

      setCasePrice: (furnitureId, slotIndex, price) => {
        set((s) => ({
          shopLayout: s.shopLayout.map((f) =>
            f.id === furnitureId && f.caseSlots
              ? { ...f, caseSlots: f.caseSlots.map((slot, i) => (i === slotIndex ? { ...slot, price: Math.max(0, price) } : slot)) }
              : f,
          ),
        }))
      },

      toggleShopOpen: () => set((s) => ({ shopOpen: !s.shopOpen })),

      sellPackFromShelf: (furnitureId) => {
        const shelf = get().shopLayout.find((f) => f.id === furnitureId)
        if (!shelf || shelf.type !== 'shelf' || !shelf.stockedPacks || shelf.stockedPacks <= 0) return null
        const price = shelf.pricePerPack ?? 0
        set((s) => ({
          shopLayout: s.shopLayout.map((f) => (f.id === furnitureId ? { ...f, stockedPacks: (f.stockedPacks ?? 0) - 1 } : f)),
        }))
        return price
      },

      sellCardFromCase: (furnitureId, slotIndex) => {
        const showcase = get().shopLayout.find((f) => f.id === furnitureId)
        if (!showcase || showcase.type !== 'case' || !showcase.caseSlots?.[slotIndex]) return null
        const price = showcase.caseSlots[slotIndex].price
        set((s) => ({
          shopLayout: s.shopLayout.map((f) =>
            f.id === furnitureId ? { ...f, caseSlots: f.caseSlots!.filter((_, i) => i !== slotIndex) } : f,
          ),
        }))
        return price
      },

      collectRevenue: (amount) => set((s) => ({ duelPoints: s.duelPoints + amount })),
    }),
    { name: 'yugioh-app-save' },
  ),
)
