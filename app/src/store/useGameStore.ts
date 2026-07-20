import { create } from 'zustand'
import { persist } from 'zustand/middleware'
import { boosterSets, CARDS_PER_PACK } from '../data/boosters'
import { cardDb } from '../data/cardDb'
import type { Deck, OwnedCard, Rarity } from '../data/types'

const STARTING_DP = 2000

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
    }),
    { name: 'yugioh-app-save' },
  ),
)
