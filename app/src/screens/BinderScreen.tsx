import { useMemo, useState } from 'react'
import { cardDb } from '../data/cardDb'
import { CardFace } from '../components/CardFace'
import { useGameStore } from '../store/useGameStore'
import type { CardDef } from '../data/types'

type SortMode = 'name' | 'rarity' | 'price'

const RARITY_ORDER: Record<string, number> = {
  Common: 0,
  Rare: 1,
  'Super Rare': 2,
  'Ultra Rare': 3,
  'Secret Rare': 4,
}

export function BinderScreen() {
  const ownedCards = useGameStore((s) => s.ownedCards)
  const sellCard = useGameStore((s) => s.sellCard)
  const [sort, setSort] = useState<SortMode>('rarity')
  const [selected, setSelected] = useState<CardDef | null>(null)

  const grouped = useMemo(() => {
    const map = new Map<number, { card: CardDef; instanceIds: string[] }>()
    for (const oc of ownedCards) {
      const card = cardDb.byId(oc.cardId)
      if (!card) continue
      const entry = map.get(oc.cardId)
      if (entry) entry.instanceIds.push(oc.instanceId)
      else map.set(oc.cardId, { card, instanceIds: [oc.instanceId] })
    }
    const list = Array.from(map.values())
    list.sort((a, b) => {
      if (sort === 'name') return a.card.name.localeCompare(b.card.name)
      if (sort === 'price') return b.card.price - a.card.price
      return RARITY_ORDER[b.card.rarity] - RARITY_ORDER[a.card.rarity]
    })
    return list
  }, [ownedCards, sort])

  return (
    <div className="px-3 py-3">
      <div className="mb-3 flex items-center justify-between">
        <h2 className="text-sm font-semibold text-neutral-300">Binder · {ownedCards.length} Karten</h2>
        <select
          value={sort}
          onChange={(e) => setSort(e.target.value as SortMode)}
          className="rounded bg-neutral-800 px-2 py-1 text-xs text-neutral-200"
        >
          <option value="rarity">Seltenheit</option>
          <option value="name">Name</option>
          <option value="price">Preis</option>
        </select>
      </div>

      {grouped.length === 0 && (
        <p className="text-sm text-neutral-500">Dein Binder ist leer. Öffne Booster oder kaufe Einzelkarten im Shop.</p>
      )}

      <div className="grid grid-cols-3 gap-2">
        {grouped.map(({ card, instanceIds }) => (
          <button key={card.id} onClick={() => setSelected(card)} className="relative text-left">
            <CardFace card={card} />
            <span className="absolute right-1 top-1 rounded bg-black/70 px-1 text-[10px] font-bold text-white">
              x{instanceIds.length}
            </span>
            <div className="mt-1 truncate text-[10px] text-neutral-300">{card.name}</div>
          </button>
        ))}
      </div>

      {selected && (
        <div
          className="fixed inset-0 z-20 flex items-center justify-center bg-black/70 px-6"
          onClick={() => setSelected(null)}
        >
          <div className="w-full max-w-xs rounded-lg bg-duel-panel p-4" onClick={(e) => e.stopPropagation()}>
            <div className="mx-auto mb-3 w-32">
              <CardFace card={selected} />
            </div>
            <div className="mb-1 text-sm font-bold text-neutral-100">{selected.name}</div>
            <div className="mb-2 text-xs text-neutral-400">{selected.desc}</div>
            <div className="mb-3 text-xs text-neutral-500">
              Marktwert: {selected.price} DP · Verkaufserlös: {Math.floor(selected.price * 0.4)} DP
            </div>
            <div className="flex gap-2">
              <button
                onClick={() => {
                  const owned = grouped.find((g) => g.card.id === selected.id)
                  const instanceId = owned?.instanceIds[0]
                  if (instanceId) sellCard(instanceId)
                  if (owned && owned.instanceIds.length <= 1) setSelected(null)
                }}
                className="flex-1 rounded bg-rose-700 py-2 text-xs font-semibold text-white"
              >
                1x Verkaufen
              </button>
              <button onClick={() => setSelected(null)} className="flex-1 rounded bg-neutral-700 py-2 text-xs font-semibold text-white">
                Schließen
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
