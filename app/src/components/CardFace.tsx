import { useState } from 'react'
import { cardImageUrl } from '../data/types'
import type { CardDef } from '../data/types'

const FRAME_COLORS: Record<string, string> = {
  Monster: 'from-amber-700 via-amber-500 to-amber-700',
  Spell: 'from-emerald-700 via-emerald-500 to-emerald-700',
  Trap: 'from-fuchsia-800 via-fuchsia-600 to-fuchsia-800',
}

export function CardFace({ card, className = '' }: { card: CardDef; className?: string }) {
  const [imgFailed, setImgFailed] = useState(false)

  if (!imgFailed) {
    return (
      <img
        src={cardImageUrl(card.id)}
        alt={card.name}
        onError={() => setImgFailed(true)}
        className={`aspect-[59/86] w-full rounded-md object-cover shadow-lg ${className}`}
        draggable={false}
      />
    )
  }

  const frame = FRAME_COLORS[card.category]
  return (
    <div
      className={`aspect-[59/86] w-full rounded-md bg-gradient-to-b ${frame} p-[3px] shadow-lg ${className}`}
      title={`${card.name} (Vorschau-Platzhalter – echtes Artwork lädt auf deinem Gerät mit Internet)`}
    >
      <div className="flex h-full w-full flex-col rounded-[4px] bg-neutral-900 p-1.5 text-left">
        <div className="truncate text-[9px] font-bold leading-tight text-neutral-100">{card.name}</div>
        <div className="mt-0.5 flex-1 rounded bg-neutral-800/70 p-1 text-[6.5px] leading-[1.15] text-neutral-300">
          {card.category === 'Monster' && (
            <div className="mb-1 flex items-center justify-between text-[6.5px] text-neutral-400">
              <span>{card.attribute}</span>
              <span>{card.kind}</span>
            </div>
          )}
          <div className="line-clamp-5">{card.desc}</div>
        </div>
        {card.category === 'Monster' ? (
          <div className="mt-1 flex items-center justify-between text-[7px] font-semibold text-neutral-200">
            <span>{'★'.repeat(Math.min(card.level ?? 0, 12))}</span>
            <span>
              ATK/{card.atk ?? '?'} DEF/{card.def ?? '?'}
            </span>
          </div>
        ) : (
          <div className="mt-1 text-[7px] font-semibold uppercase text-neutral-300">{card.category}</div>
        )}
      </div>
    </div>
  )
}
