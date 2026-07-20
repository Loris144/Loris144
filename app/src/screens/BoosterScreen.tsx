import { useState } from 'react'
import { boosterSets } from '../data/boosters'
import { cardDb } from '../data/cardDb'
import { CardFace } from '../components/CardFace'
import { useGameStore } from '../store/useGameStore'
import type { CardDef } from '../data/types'

export function BoosterScreen() {
  const unopened = useGameStore((s) => s.unopenedBoosters)
  const openBooster = useGameStore((s) => s.openBooster)
  const sellBooster = useGameStore((s) => s.sellBooster)
  const [revealed, setRevealed] = useState<CardDef[] | null>(null)
  const [flipped, setFlipped] = useState<Set<number>>(new Set())

  const owned = boosterSets.filter((b) => (unopened[b.id] ?? 0) > 0)

  function handleOpen(boosterId: string) {
    const pulls = openBooster(boosterId)
    const cards = pulls.map((p) => cardDb.byId(p.cardId)).filter((c): c is CardDef => !!c)
    setRevealed(cards)
    setFlipped(new Set())
  }

  function flipCard(idx: number) {
    setFlipped((prev) => new Set(prev).add(idx))
  }

  if (revealed) {
    const allFlipped = flipped.size === revealed.length
    return (
      <div className="flex flex-col items-center px-3 py-4">
        <div className="mb-3 text-sm font-semibold text-duel-gold">Tippe die Karten an, um sie aufzudecken</div>
        <div className="grid grid-cols-3 gap-3">
          {revealed.map((card, idx) => (
            <button key={idx} onClick={() => flipCard(idx)} className="w-24">
              {flipped.has(idx) ? (
                <CardFace card={card} />
              ) : (
                <div className="flex aspect-[59/86] w-full items-center justify-center rounded-md bg-gradient-to-br from-neutral-700 to-neutral-900 text-2xl shadow-lg">
                  🂠
                </div>
              )}
              {flipped.has(idx) && <div className="mt-1 truncate text-[10px] text-neutral-300">{card.name}</div>}
            </button>
          ))}
        </div>
        {allFlipped && (
          <button
            onClick={() => setRevealed(null)}
            className="mt-6 rounded bg-duel-blue px-6 py-2 text-sm font-semibold text-white"
          >
            Weiter
          </button>
        )}
      </div>
    )
  }

  return (
    <div className="px-3 py-3">
      <h2 className="mb-3 text-sm font-semibold text-neutral-300">Meine ungeöffneten Booster</h2>
      {owned.length === 0 && (
        <p className="text-sm text-neutral-500">
          Du hast keine Booster. Kauf welche im Shop, um Karten für deinen Binder zu bekommen.
        </p>
      )}
      <div className="grid grid-cols-2 gap-3">
        {owned.map((b) => (
          <div key={b.id} className="rounded-lg bg-duel-panel p-2">
            <div className="mb-2 flex aspect-[3/4] items-center justify-center rounded bg-gradient-to-br from-neutral-700 to-neutral-900 text-center text-xs font-bold text-duel-gold">
              {b.name}
            </div>
            <div className="mb-2 text-center text-[11px] text-neutral-400">x{unopened[b.id]} vorhanden</div>
            <button
              onClick={() => handleOpen(b.id)}
              className="mb-1 w-full rounded bg-duel-gold py-1.5 text-xs font-bold text-black"
            >
              Öffnen
            </button>
            <button
              onClick={() => sellBooster(b.id)}
              className="w-full rounded bg-neutral-800 py-1.5 text-[11px] text-neutral-300"
            >
              Verkaufen ({Math.floor(b.price * 0.4)} DP)
            </button>
          </div>
        ))}
      </div>
    </div>
  )
}
