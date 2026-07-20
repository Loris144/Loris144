import { useMemo, useState } from 'react'
import { boosterSets } from '../data/boosters'
import { cardDb } from '../data/cardDb'
import { useCardDbStore } from '../data/cardDbStore'
import { CardTile } from '../components/CardTile'
import { cpuPresets } from '../engine/cpuDecks'
import { STARTER_DECK_PRICE, useGameStore } from '../store/useGameStore'

type Tab = 'boxes' | 'warehouse' | 'singles' | 'starters'

export function MarketPanel({ onClose }: { onClose: () => void }) {
  const [tab, setTab] = useState<Tab>('boxes')
  const [qty, setQty] = useState<Record<string, number>>({})
  const dp = useGameStore((s) => s.duelPoints)
  const warehouseBoxes = useGameStore((s) => s.warehouseBoxes)
  const buyBoxWholesale = useGameStore((s) => s.buyBoxWholesale)
  const breakBoxForPersonalUse = useGameStore((s) => s.breakBoxForPersonalUse)
  const buySingle = useGameStore((s) => s.buySingle)
  const buyStarterDeck = useGameStore((s) => s.buyStarterDeck)
  const cardDbVersion = useCardDbStore((s) => s.version)
  const [filter, setFilter] = useState<'Alle' | 'Yugi' | 'Kaiba' | 'Joey' | 'Classic'>('Alle')

  const singles = useMemo(() => {
    void cardDbVersion // recompute once live card data merges in
    const all = cardDb.all().sort((a, b) => a.price - b.price)
    if (filter === 'Alle') return all
    return all.filter((c) => c.protagonist === filter || (filter === 'Classic' && !c.protagonist))
  }, [filter, cardDbVersion])

  return (
    <div className="fixed inset-0 z-30 flex items-end justify-center bg-black/70" onClick={onClose}>
      <div className="max-h-[85vh] w-full max-w-md overflow-y-auto rounded-t-xl bg-duel-panel p-4" onClick={(e) => e.stopPropagation()}>
        <div className="mb-3 flex items-center justify-between">
          <div className="text-sm font-bold text-duel-gold">Großhandel & Markt</div>
          <button onClick={onClose} className="text-xs text-neutral-400">
            Schließen
          </button>
        </div>

        <div className="mb-3 flex gap-1.5 overflow-x-auto">
          <button onClick={() => setTab('boxes')} className={`shrink-0 rounded-lg px-3 py-2 text-xs font-semibold ${tab === 'boxes' ? 'bg-duel-blue text-white' : 'bg-neutral-800 text-neutral-300'}`}>
            Boxen kaufen
          </button>
          <button onClick={() => setTab('warehouse')} className={`shrink-0 rounded-lg px-3 py-2 text-xs font-semibold ${tab === 'warehouse' ? 'bg-duel-blue text-white' : 'bg-neutral-800 text-neutral-300'}`}>
            Mein Lager
          </button>
          <button onClick={() => setTab('starters')} className={`shrink-0 rounded-lg px-3 py-2 text-xs font-semibold ${tab === 'starters' ? 'bg-duel-blue text-white' : 'bg-neutral-800 text-neutral-300'}`}>
            Starterdecks
          </button>
          <button onClick={() => setTab('singles')} className={`shrink-0 rounded-lg px-3 py-2 text-xs font-semibold ${tab === 'singles' ? 'bg-duel-blue text-white' : 'bg-neutral-800 text-neutral-300'}`}>
            Einzelkarten
          </button>
        </div>

        {tab === 'boxes' && (
          <div className="flex flex-col gap-2">
            <p className="mb-1 text-[11px] text-neutral-500">Boxen haben einen festen Großhandelspreis. Verkaufspreise in deinem Laden bestimmst du selbst an den Regalen.</p>
            {boosterSets.map((b) => (
              <div key={b.id} className="rounded bg-neutral-800/60 p-2">
                <div className="mb-1 flex items-center justify-between text-xs font-semibold text-neutral-100">
                  <span>{b.name}</span>
                  <span className="text-neutral-400">{b.packsPerBox} Packs/Box</span>
                </div>
                <div className="mb-2 text-[11px] text-neutral-400">
                  Großhandel: {b.wholesalePricePerBox} DP/Box · Empf. Verkauf: {b.price} DP/Pack
                </div>
                <div className="flex items-center gap-2">
                  <input
                    type="number"
                    min={1}
                    value={qty[b.id] ?? 1}
                    onChange={(e) => setQty((q) => ({ ...q, [b.id]: Math.max(1, Number(e.target.value) || 1) }))}
                    className="w-16 rounded bg-neutral-900 px-2 py-1 text-xs text-neutral-100"
                  />
                  <button
                    onClick={() => buyBoxWholesale(b.id, qty[b.id] ?? 1)}
                    disabled={dp < b.wholesalePricePerBox * (qty[b.id] ?? 1)}
                    className="flex-1 rounded bg-duel-gold py-1.5 text-xs font-bold text-black disabled:opacity-40"
                  >
                    Kaufen · {b.wholesalePricePerBox * (qty[b.id] ?? 1)} DP
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}

        {tab === 'warehouse' && (
          <div className="flex flex-col gap-2">
            <p className="mb-1 text-[11px] text-neutral-500">Boxen aus deinem Lager kannst du in Regale stellen (an einem Regal antippen) oder für dich selbst öffnen.</p>
            {boosterSets.filter((b) => (warehouseBoxes[b.id] ?? 0) > 0).map((b) => (
              <div key={b.id} className="flex items-center justify-between rounded bg-neutral-800/60 p-2">
                <div>
                  <div className="text-xs font-semibold text-neutral-100">{b.name}</div>
                  <div className="text-[11px] text-neutral-400">{warehouseBoxes[b.id]} Box(en) im Lager</div>
                </div>
                <button onClick={() => breakBoxForPersonalUse(b.id)} className="rounded bg-neutral-700 px-2 py-1 text-[11px] font-semibold text-white">
                  Für dich öffnen
                </button>
              </div>
            ))}
            {boosterSets.every((b) => (warehouseBoxes[b.id] ?? 0) === 0) && <p className="text-xs text-neutral-500">Lager ist leer.</p>}
          </div>
        )}

        {tab === 'starters' && (
          <div className="flex flex-col gap-2">
            <p className="mb-1 text-[11px] text-neutral-500">
              Ein Starterdeck legt dir sofort ein fertiges 40-Karten-Deck (plus Extra Deck) in Binder und Deckbuilder.
            </p>
            {cpuPresets.map((preset) => (
              <div key={preset.id} className="flex items-center justify-between rounded bg-neutral-800/60 p-2">
                <div>
                  <div className="text-xs font-semibold text-neutral-100">Starterdeck: {preset.name}</div>
                  <div className="text-[11px] text-neutral-400">40 Hauptdeck-Karten{preset.extra.length > 0 ? ` + ${preset.extra.length} Extra Deck` : ''}</div>
                </div>
                <button
                  onClick={() => buyStarterDeck(preset.id)}
                  disabled={dp < STARTER_DECK_PRICE}
                  className="shrink-0 rounded bg-duel-gold px-3 py-1.5 text-xs font-bold text-black disabled:opacity-40"
                >
                  Kaufen · {STARTER_DECK_PRICE} DP
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
                  className={`shrink-0 rounded-full px-3 py-1 text-[11px] font-medium ${filter === f ? 'bg-duel-gold text-black' : 'bg-neutral-800 text-neutral-300'}`}
                >
                  {f}
                </button>
              ))}
            </div>
            <div className="grid grid-cols-3 gap-2">
              {singles.map((card) => (
                <CardTile key={card.id} card={card} actionLabel={`${card.price} DP`} disabled={dp < card.price} onAction={() => buySingle(card.id)} />
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
