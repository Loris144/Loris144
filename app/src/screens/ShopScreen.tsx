import { useMemo, useState } from 'react'
import { boosterSets } from '../data/boosters'
import { cardDb } from '../data/cardDb'
import { CardTile } from '../components/CardTile'
import { useGameStore } from '../store/useGameStore'

type SubTab = 'boosters' | 'singles'

export function ShopScreen() {
  const [tab, setTab] = useState<SubTab>('boosters')
  const [filter, setFilter] = useState<'Alle' | 'Yugi' | 'Kaiba' | 'Joey' | 'Classic'>('Alle')
  const dp = useGameStore((s) => s.duelPoints)
  const buyBooster = useGameStore((s) => s.buyBooster)
  const buySingle = useGameStore((s) => s.buySingle)

  const singles = useMemo(() => {
    const all = cardDb.all().sort((a, b) => a.price - b.price)
    if (filter === 'Alle') return all
    return all.filter((c) => c.protagonist === filter || (filter === 'Classic' && !c.protagonist))
  }, [filter])

  return (
    <div className="px-3 py-3">
      <div className="mb-3 flex gap-2">
        <button
          onClick={() => setTab('boosters')}
          className={`flex-1 rounded-lg py-2 text-sm font-semibold ${tab === 'boosters' ? 'bg-duel-blue text-white' : 'bg-neutral-800 text-neutral-300'}`}
        >
          Booster
        </button>
        <button
          onClick={() => setTab('singles')}
          className={`flex-1 rounded-lg py-2 text-sm font-semibold ${tab === 'singles' ? 'bg-duel-blue text-white' : 'bg-neutral-800 text-neutral-300'}`}
        >
          Einzelkarten
        </button>
      </div>

      {tab === 'boosters' && (
        <div className="grid grid-cols-2 gap-3">
          {boosterSets.map((b) => (
            <div key={b.id} className="rounded-lg bg-duel-panel p-2">
              <div className="mb-2 flex aspect-[3/4] items-center justify-center rounded bg-gradient-to-br from-neutral-700 to-neutral-900 text-center text-xs font-bold text-duel-gold">
                {b.name}
              </div>
              <div className="mb-2 text-center text-[11px] text-neutral-400">{b.cardPool.length} Karten im Pool</div>
              <button
                onClick={() => buyBooster(b.id)}
                disabled={dp < b.price}
                className="w-full rounded bg-duel-blue py-1.5 text-xs font-semibold text-white disabled:opacity-40"
              >
                Kaufen · {b.price} DP
              </button>
            </div>
          ))}
        </div>
      )}

      {tab === 'singles' && (
        <div>
          <div className="mb-3 flex gap-1 overflow-x-auto">
            {(['Alle', 'Yugi', 'Kaiba', 'Joey', 'Classic'] as const).map((f) => (
              <button
                key={f}
                onClick={() => setFilter(f)}
                className={`shrink-0 rounded-full px-3 py-1 text-[11px] font-medium ${
                  filter === f ? 'bg-duel-gold text-black' : 'bg-neutral-800 text-neutral-300'
                }`}
              >
                {f}
              </button>
            ))}
          </div>
          <div className="grid grid-cols-3 gap-2">
            {singles.map((card) => (
              <CardTile
                key={card.id}
                card={card}
                actionLabel={`${card.price} DP`}
                disabled={dp < card.price}
                onAction={() => buySingle(card.id)}
              />
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
