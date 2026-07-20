import { useMemo, useState } from 'react'
import { cardDb } from '../data/cardDb'
import { CardFace } from '../components/CardFace'
import { isExtraDeckCard, validateDeck } from '../engine/deckRules'
import { useGameStore } from '../store/useGameStore'
import type { CardDef } from '../data/types'

export function DeckBuilderScreen() {
  const decks = useGameStore((s) => s.decks)
  const activeDeckId = useGameStore((s) => s.activeDeckId)
  const ownedCards = useGameStore((s) => s.ownedCards)
  const createDeck = useGameStore((s) => s.createDeck)
  const deleteDeck = useGameStore((s) => s.deleteDeck)
  const setActiveDeck = useGameStore((s) => s.setActiveDeck)
  const setDeckCards = useGameStore((s) => s.setDeckCards)

  const [newDeckName, setNewDeckName] = useState('')

  const deck = decks.find((d) => d.id === activeDeckId) ?? null

  const ownedCounts = useMemo(() => {
    const map = new Map<number, number>()
    for (const oc of ownedCards) map.set(oc.cardId, (map.get(oc.cardId) ?? 0) + 1)
    return map
  }, [ownedCards])

  const usedCounts = useMemo(() => {
    const map = new Map<number, number>()
    if (!deck) return map
    for (const id of [...deck.main, ...deck.extra]) map.set(id, (map.get(id) ?? 0) + 1)
    return map
  }, [deck])

  const ownedUniqueCards = useMemo(() => {
    return Array.from(ownedCounts.keys())
      .map((id) => cardDb.byId(id))
      .filter((c): c is CardDef => !!c)
      .sort((a, b) => a.name.localeCompare(b.name))
  }, [ownedCounts])

  function addToDeck(card: CardDef) {
    if (!deck) return
    const owned = ownedCounts.get(card.id) ?? 0
    const used = usedCounts.get(card.id) ?? 0
    if (used >= owned || used >= 3) return
    if (isExtraDeckCard(card.id)) {
      setDeckCards(deck.id, deck.main, [...deck.extra, card.id])
    } else {
      setDeckCards(deck.id, [...deck.main, card.id], deck.extra)
    }
  }

  function removeFromDeck(cardId: number, zone: 'main' | 'extra') {
    if (!deck) return
    if (zone === 'main') {
      const idx = deck.main.lastIndexOf(cardId)
      const next = [...deck.main]
      if (idx >= 0) next.splice(idx, 1)
      setDeckCards(deck.id, next, deck.extra)
    } else {
      const idx = deck.extra.lastIndexOf(cardId)
      const next = [...deck.extra]
      if (idx >= 0) next.splice(idx, 1)
      setDeckCards(deck.id, deck.main, next)
    }
  }

  if (!deck) {
    return (
      <div className="px-3 py-4">
        <h2 className="mb-3 text-sm font-semibold text-neutral-300">Deine Decks</h2>
        {decks.length === 0 && <p className="mb-3 text-sm text-neutral-500">Du hast noch kein Deck. Erstelle eines.</p>}
        <div className="mb-3 flex flex-col gap-2">
          {decks.map((d) => (
            <button
              key={d.id}
              onClick={() => setActiveDeck(d.id)}
              className="rounded bg-duel-panel px-3 py-2 text-left text-sm text-neutral-200"
            >
              {d.name} ({d.main.length} / {d.extra.length})
            </button>
          ))}
        </div>
        <div className="flex gap-2">
          <input
            value={newDeckName}
            onChange={(e) => setNewDeckName(e.target.value)}
            placeholder="Neues Deck..."
            className="flex-1 rounded bg-neutral-800 px-3 py-2 text-sm text-neutral-100"
          />
          <button
            onClick={() => {
              if (!newDeckName.trim()) return
              createDeck(newDeckName.trim())
              setNewDeckName('')
            }}
            className="rounded bg-duel-blue px-4 py-2 text-sm font-semibold text-white"
          >
            Erstellen
          </button>
        </div>
      </div>
    )
  }

  const validation = validateDeck(deck)
  const mainGrouped = groupByCard(deck.main)
  const extraGrouped = groupByCard(deck.extra)

  return (
    <div className="px-3 py-3">
      <div className="mb-3 flex items-center justify-between">
        <button onClick={() => setActiveDeck('')} className="text-xs text-neutral-400">
          ← Decks
        </button>
        <div className="text-sm font-semibold text-neutral-200">{deck.name}</div>
        <button onClick={() => deleteDeck(deck.id)} className="text-xs text-rose-400">
          Löschen
        </button>
      </div>

      <div className={`mb-3 rounded p-2 text-[11px] ${validation.valid ? 'bg-emerald-900/50 text-emerald-300' : 'bg-rose-950/50 text-rose-300'}`}>
        {validation.valid ? 'Deck ist spielbereit ✓' : validation.issues.join(' · ')}
      </div>

      <h3 className="mb-1 text-xs font-semibold text-neutral-400">Hauptdeck ({deck.main.length})</h3>
      <div className="mb-3 grid grid-cols-5 gap-1.5">
        {mainGrouped.map(({ card, count }) => (
          <button key={card.id} onClick={() => removeFromDeck(card.id, 'main')} className="relative">
            <CardFace card={card} />
            {count > 1 && <span className="absolute right-0.5 top-0.5 rounded bg-black/70 px-1 text-[9px] text-white">x{count}</span>}
          </button>
        ))}
      </div>

      <h3 className="mb-1 text-xs font-semibold text-neutral-400">Extra Deck ({deck.extra.length})</h3>
      <div className="mb-4 grid grid-cols-5 gap-1.5">
        {extraGrouped.map(({ card, count }) => (
          <button key={card.id} onClick={() => removeFromDeck(card.id, 'extra')} className="relative">
            <CardFace card={card} />
            {count > 1 && <span className="absolute right-0.5 top-0.5 rounded bg-black/70 px-1 text-[9px] text-white">x{count}</span>}
          </button>
        ))}
      </div>

      <h3 className="mb-1 text-xs font-semibold text-neutral-400">Deine Sammlung</h3>
      <div className="grid grid-cols-5 gap-1.5">
        {ownedUniqueCards.map((card) => {
          const owned = ownedCounts.get(card.id) ?? 0
          const used = usedCounts.get(card.id) ?? 0
          const remaining = owned - used
          return (
            <button
              key={card.id}
              onClick={() => addToDeck(card)}
              disabled={remaining <= 0 || used >= 3}
              className="relative disabled:opacity-30"
            >
              <CardFace card={card} />
              <span className="absolute right-0.5 top-0.5 rounded bg-black/70 px-1 text-[9px] text-white">{remaining}</span>
            </button>
          )
        })}
      </div>
    </div>
  )

  function groupByCard(ids: number[]) {
    const map = new Map<number, number>()
    for (const id of ids) map.set(id, (map.get(id) ?? 0) + 1)
    return Array.from(map.entries())
      .map(([id, count]) => ({ card: cardDb.byId(id)!, count }))
      .filter((e) => e.card)
  }
}
