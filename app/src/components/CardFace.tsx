import { useState } from 'react'
import { cardImageId, cardImageUrl } from '../data/types'
import type { CardDef } from '../data/types'
import { PixelSprite } from './PixelSprite'

interface FrameStyle {
  gradient: string
  border: string
}

const MONSTER_FRAME: Record<string, FrameStyle> = {
  Normal: { gradient: 'from-amber-600 via-amber-300 to-amber-600', border: 'border-amber-400' },
  Effect: { gradient: 'from-orange-800 via-orange-500 to-orange-800', border: 'border-orange-500' },
  Ritual: { gradient: 'from-blue-950 via-blue-700 to-blue-950', border: 'border-blue-600' },
  Fusion: { gradient: 'from-purple-900 via-purple-600 to-purple-900', border: 'border-purple-500' },
  Synchro: { gradient: 'from-neutral-200 via-white to-neutral-200', border: 'border-neutral-300' },
  Xyz: { gradient: 'from-neutral-950 via-neutral-700 to-neutral-950', border: 'border-neutral-400' },
  Link: { gradient: 'from-sky-600 via-sky-300 to-sky-600', border: 'border-sky-400' },
}

const SPELL_FRAME: FrameStyle = { gradient: 'from-emerald-700 via-emerald-500 to-emerald-700', border: 'border-emerald-500' }
const TRAP_FRAME: FrameStyle = { gradient: 'from-pink-800 via-pink-500 to-pink-800', border: 'border-pink-500' }

function frameStyleFor(card: CardDef): FrameStyle {
  if (card.category === 'Spell') return SPELL_FRAME
  if (card.category === 'Trap') return TRAP_FRAME
  return MONSTER_FRAME[card.kind] ?? MONSTER_FRAME.Effect
}

/** Applied to every piece of card art (real photo or pixel sprite) for a consistent, softly
 * blurred, limited-palette "old handheld console" look — still clearly recognizable. */
const GBA_STYLE = { filter: 'url(#gba-retro) saturate(1.35) contrast(1.12) blur(0.5px)' } as const
const GBA_STYLE_FIELD = { filter: 'url(#gba-retro) saturate(1.35) contrast(1.12) blur(2.5px)' } as const

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
  const frame = frameStyleFor(card)

  if (variant === 'field') {
    return (
      <div className={`relative aspect-[59/86] w-full overflow-hidden rounded-md border-2 ${frame.border} bg-neutral-900 shadow-lg ${className}`}>
        {!imgFailed ? (
          <img
            src={cardImageUrl(cardImageId(card))}
            alt=""
            aria-hidden="true"
            onError={() => setImgFailed(true)}
            className="absolute inset-0 h-full w-full scale-110 object-cover"
            style={GBA_STYLE_FIELD}
            draggable={false}
          />
        ) : (
          <PixelSprite card={card} className="absolute inset-0" style={GBA_STYLE_FIELD} />
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
        src={cardImageUrl(cardImageId(card))}
        alt={card.name}
        onError={() => setImgFailed(true)}
        className={`aspect-[59/86] w-full rounded-md object-cover shadow-lg ${glowClass} ${className}`}
        style={GBA_STYLE}
        draggable={false}
      />
    )
  }

  return (
    <div
      className={`aspect-[59/86] w-full rounded-md bg-gradient-to-b ${frame.gradient} p-[3px] shadow-lg ${glowClass} ${className}`}
      title={`${card.name} (Original-Pixel-Art-Platzhalter – echtes Artwork lädt auf deinem Gerät mit Internet)`}
    >
      <div className="flex h-full w-full flex-col rounded-[4px] bg-neutral-900 p-1 text-left">
        <div className="truncate text-[8px] font-bold leading-tight text-neutral-100">{card.name}</div>
        <div className="my-0.5 flex-1 overflow-hidden rounded-sm" style={{ imageRendering: 'pixelated' }}>
          <PixelSprite card={card} style={GBA_STYLE} />
        </div>
        {card.category === 'Monster' ? (
          <div className="flex items-center justify-between text-[6.5px] font-semibold text-neutral-200">
            <span className="truncate">{card.attribute ?? ''}</span>
            <span>
              {card.atk ?? '?'}/{card.def ?? '?'}
            </span>
          </div>
        ) : (
          <div className="text-[6.5px] font-semibold uppercase text-neutral-300">{card.category}</div>
        )}
      </div>
    </div>
  )
}
