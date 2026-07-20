import { useMemo, useState } from 'react'
import { cardDb } from '../data/cardDb'
import { CardFace } from '../components/CardFace'
import { useGameStore } from '../store/useGameStore'
import type { CardCategory, CardDef } from '../data/types'

type SortMode = 'name' | 'rarity' | 'price'
type CategoryFilter = 'Alle' | CardCategory

const RARITY_ORDER: Record<string, number> = {
  Common: 0,
  Rare: 1,
  'Super Rare': 2,
  'Ultra Rare': 3,
  'Secret Rare': 4,
}

const RARITY_TEXT_COLOR: Record<string, string> = {
  Common: 'text-neutral-400',
  Rare: 'text-sky-400',
  'Super Rare': 'text-violet-400',
  'Ultra Rare': 'text-amber-400',
  'Secret Rare': 'text-rose-400',
}

export function BinderScreen() {
  const ownedCards = useGameStore((s) => s.ownedCards)
  const sellCard = useGameStore((s) => s.sellCard)
  const [sort, setSort] = useState<SortMode>('rarity')
  const [category, setCategory] = useState<CategoryFilter>('Alle')
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
    let list = Array.from(map.values())
    if (category !== 'Alle') list = list.filter((g) => g.card.category === category)
    list.sort((a, b) => {
      if (sort === 'name') return a.card.name.localeCompare(b.card.name)
      if (sort === 'price') return b.card.price - a.card.price
      return RARITY_ORDER[b.card.rarity] - RARITY_ORDER[a.card.rarity]
    })
    return list
  }, [ownedCards, sort, category])

  return (
    <div className="min-h-full bg-gradient-to-b from-neutral-950 to-duel-dark px-3 py-3">
      <div className="mb-2 flex items-center justify-between">
        <h2 className="text-sm font-bold tracking-wide text-duel-gold">BINDER</h2>
        <span className="text-[11px] text-neutral-400">{ownedCards.length} Karten</span>
      </div>

      <div className="mb-2 flex gap-1.5 overflow-x-auto">
        {(['Alle', 'Monster', 'Spell', 'Trap'] as const).map((c) => (
          <button
            key={c}
            onClick={() => setCategory(c)}
            className={`shrink-0 rounded-full px-3 py-1 text-[11px] font-semibold ${
              category === c ? 'bg-duel-gold text-black' : 'bg-neutral-800/80 text-neutral-300'
            }`}
          >
            {c === 'Alle' ? 'Alle' : c === 'Monster' ? 'Monster' : c === 'Spell' ? 'Zauber' : 'Fallen'}
          </button>
        ))}
        <select
          value={sort}
          onChange={(e) => setSort(e.target.value as SortMode)}
          className="ml-auto shrink-0 rounded-full bg-neutral-800/80 px-2 py-1 text-[11px] text-neutral-200"
        >
          <option value="rarity">Seltenheit</option>
          <option value="name">Name</option>
          <option value="price">Preis</option>
        </select>
      </div>

      {grouped.length === 0 && (
        <p className="mt-6 text-center text-sm text-neutral-500">Dein Binder ist leer. Öffne Booster oder kaufe Einzelkarten im Shop.</p>
      )}

      <div className="grid grid-cols-3 gap-2.5">
        {grouped.map(({ card, instanceIds }) => (
          <button key={card.id} onClick={() => setSelected(card)} className="relative text-left">
            <CardFace card={card} rarityGlow />
            <span className="absolute right-1 top-1 rounded bg-black/80 px-1 text-[10px] font-bold text-white">x{instanceIds.length}</span>
            <div className="mt-1 truncate text-[10px] text-neutral-300">{card.name}</div>
            <div className={`truncate text-[9px] font-semibold ${RARITY_TEXT_COLOR[card.rarity]}`}>{card.rarity}</div>
          </button>
        ))}
      </div>

      {selected && (
        <div className="fixed inset-0 z-20 flex items-center justify-center bg-black/80 px-6" onClick={() => setSelected(null)}>
          <div
            className="w-full max-w-xs overflow-hidden rounded-xl border border-neutral-700 bg-duel-panel shadow-2xl"
            onClick={(e) => e.stopPropagation()}
          >
            <div className={`h-1.5 w-full bg-gradient-to-r ${rarityBar(selected.rarity)}`} />
            <div className="p-4">
              <div className="mx-auto mb-3 w-36">
                <CardFace card={selected} />
              </div>
              <div className="mb-0.5 text-center text-sm font-bold text-neutral-100">{selected.name}</div>
              <div className={`mb-2 text-center text-[11px] font-semibold ${RARITY_TEXT_COLOR[selected.rarity]}`}>{selected.rarity}</div>
              <div className="mb-2 text-center text-[11px] text-neutral-400">
                {selected.category} · {selected.kind}
                {selected.category === 'Monster' && ` · ${selected.attribute} · Level ${selected.level ?? '?'}`}
              </div>
              {selected.category === 'Monster' && (
                <div className="mb-2 text-center text-xs font-bold text-neutral-200">
                  ATK {selected.atk ?? '?'} / DEF {selected.def ?? '?'}
                </div>
              )}
              <div className="mb-3 text-xs leading-snug text-neutral-300">{selected.desc}</div>
              <div className="mb-3 text-center text-[11px] text-neutral-500">
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
        </div>
      )}
    </div>
  )
}

function rarityBar(rarity: string): string {
  switch (rarity) {
    case 'Secret Rare':
      return 'from-rose-500 via-fuchsia-400 to-rose-500'
    case 'Ultra Rare':
      return 'from-amber-400 via-yellow-200 to-amber-400'
    case 'Super Rare':
      return 'from-violet-500 via-purple-300 to-violet-500'
    case 'Rare':
      return 'from-sky-500 via-cyan-300 to-sky-500'
    default:
      return 'from-neutral-600 to-neutral-500'
  }
}
