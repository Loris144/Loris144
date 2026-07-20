import { useState } from 'react'
import { cardImageUrl } from '../data/types'
import type { CardDef } from '../data/types'

const FRAME_COLORS: Record<string, string> = {
  Monster: 'from-amber-700 via-amber-500 to-amber-700',
  Spell: 'from-emerald-700 via-emerald-500 to-emerald-700',
  Trap: 'from-fuchsia-800 via-fuchsia-600 to-fuchsia-800',
}

const FRAME_BORDER: Record<string, string> = {
  Monster: 'border-amber-500',
  Spell: 'border-emerald-500',
  Trap: 'border-fuchsia-500',
}

const RARITY_GLOW: Record<string, string> = {
  Common: '',
  Rare: 'shadow-[0_0_8px_1px_rgba(56,189,248,0.55)] ring-1 ring-sky-400/70',
  'Super Rare': 'shadow-[0_0_10px_2px_rgba(167,139,250,0.6)] ring-1 ring-violet-400/70',
  'Ultra Rare': 'shadow-[0_0_12px_2px_rgba(251,191,36,0.65)] ring-1 ring-amber-400/80',
  'Secret Rare': 'shadow-[0_0_14px_3px_rgba(244,63,94,0.65)] ring-1 ring-rose-400/80',
}

interface CardFaceProps {
  card: CardDef
  className?: string
  /** 'full' (default) shows a readable mini-card when no image is available; 'field' shows
   * only frame color + a blurred image + ATK/DEF, matching how cards look on a real duel field
   * until you tap for info. */
  variant?: 'full' | 'field'
  /** Adds a rarity-colored glow ring around the card, used in the binder. */
  rarityGlow?: boolean
  /** Shown as a small ⓘ button in the corner for the 'field' variant. */
  onInfo?: () => void
}

export function CardFace({ card, className = '', variant = 'full', rarityGlow = false, onInfo }: CardFaceProps) {
  const [imgFailed, setImgFailed] = useState(false)
  const glowClass = rarityGlow ? RARITY_GLOW[card.rarity] : ''

  if (variant === 'field') {
    return (
      <div className={`relative aspect-[59/86] w-full overflow-hidden rounded-md border-2 ${FRAME_BORDER[card.category]} bg-neutral-900 shadow-lg ${className}`}>
        {!imgFailed ? (
          <img
            src={cardImageUrl(card.id)}
            alt=""
            aria-hidden="true"
            onError={() => setImgFailed(true)}
            className="absolute inset-0 h-full w-full scale-110 object-cover blur-[3px]"
            draggable={false}
          />
        ) : (
          <div className={`absolute inset-0 bg-gradient-to-b ${FRAME_COLORS[card.category]} opacity-80 blur-[3px]`} />
        )}
        <div className="absolute inset-0 bg-black/10" />
        {onInfo && (
          <button
            type="button"
            onClick={(e) => {
              e.stopPropagation()
              onInfo()
            }}
            className="absolute right-0.5 top-0.5 flex h-4 w-4 items-center justify-center rounded-full bg-black/70 text-[9px] font-bold text-white"
            aria-label="Karteninfo"
          >
            i
          </button>
        )}
        {card.category === 'Monster' && (
          <div className="absolute inset-x-0 bottom-0 flex items-center justify-center bg-black/70 py-0.5 text-[7px] font-bold text-neutral-100">
            {card.atk ?? '?'} / {card.def ?? '?'}
          </div>
        )}
      </div>
    )
  }

  if (!imgFailed) {
    return (
      <img
        src={cardImageUrl(card.id)}
        alt={card.name}
        onError={() => setImgFailed(true)}
        className={`aspect-[59/86] w-full rounded-md object-cover shadow-lg ${glowClass} ${className}`}
        draggable={false}
      />
    )
  }

  const frame = FRAME_COLORS[card.category]
  return (
    <div
      className={`aspect-[59/86] w-full rounded-md bg-gradient-to-b ${frame} p-[3px] shadow-lg ${glowClass} ${className}`}
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
