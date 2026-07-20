import type { CardDef } from '../data/types'
import { CardFace } from './CardFace'

const RARITY_COLOR: Record<string, string> = {
  Common: 'text-neutral-400',
  Rare: 'text-sky-400',
  'Super Rare': 'text-violet-400',
  'Ultra Rare': 'text-amber-400',
  'Secret Rare': 'text-rose-400',
}

export function CardTile({
  card,
  badge,
  actionLabel,
  onAction,
  disabled,
  onClick,
}: {
  card: CardDef
  badge?: string
  actionLabel?: string
  onAction?: () => void
  disabled?: boolean
  onClick?: () => void
}) {
  return (
    <div className="flex flex-col gap-1">
      <button type="button" onClick={onClick} className="relative text-left">
        <CardFace card={card} />
        {badge && (
          <span className="absolute right-1 top-1 rounded bg-black/70 px-1 text-[10px] font-bold text-white">
            {badge}
          </span>
        )}
      </button>
      <div className="truncate text-[11px] font-medium text-neutral-100">{card.name}</div>
      <div className={`text-[10px] ${RARITY_COLOR[card.rarity]}`}>{card.rarity}</div>
      {actionLabel && (
        <button
          type="button"
          disabled={disabled}
          onClick={onAction}
          className="mt-0.5 rounded bg-duel-blue px-2 py-1 text-[11px] font-semibold text-white disabled:opacity-40"
        >
          {actionLabel}
        </button>
      )}
    </div>
  )
}
