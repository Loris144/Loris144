import { useMemo } from 'react'
import type { CSSProperties } from 'react'
import type { CardDef } from '../data/types'

const GRID = 8
const HALF = GRID / 2

function hashString(str: string): number {
  let h = 0
  for (let i = 0; i < str.length; i++) h = (Math.imul(31, h) + str.charCodeAt(i)) | 0
  return h >>> 0
}

/** Deterministic PRNG so a given card always renders the same "sprite". */
function mulberry32(seed: number) {
  let s = seed
  return function next() {
    s = (s + 0x6d2b79f5) | 0
    let t = Math.imul(s ^ (s >>> 15), 1 | s)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

const ATTRIBUTE_PALETTE: Record<string, string[]> = {
  DARK: ['#2a1a3d', '#5b2d8f', '#9b5de5', '#c9a7f0'],
  LIGHT: ['#3d3417', '#a68b2c', '#f4d35e', '#fff3bf'],
  EARTH: ['#2b1d0e', '#6b4423', '#b5793a', '#e0b873'],
  WATER: ['#0b2740', '#1560a8', '#4aa8e0', '#bfe6ff'],
  FIRE: ['#3d0d0d', '#c1272d', '#f26c4f', '#ffb997'],
  WIND: ['#0d3d1f', '#2e8b57', '#7fd99a', '#d4f7df'],
  DIVINE: ['#3d3417', '#caa52c', '#ffe066', '#fffbe6'],
}
const SPELL_PALETTE = ['#0d3320', '#1f7a4d', '#4fd88a', '#c8f7dd']
const TRAP_PALETTE = ['#3d0d2b', '#8f1f66', '#e0559e', '#ffc2e6']
const DEFAULT_PALETTE = ['#1a1a1a', '#4a4a4a', '#8a8a8a', '#cfcfcf']

function paletteFor(card: CardDef): string[] {
  if (card.category === 'Spell') return SPELL_PALETTE
  if (card.category === 'Trap') return TRAP_PALETTE
  return (card.attribute && ATTRIBUTE_PALETTE[card.attribute]) || DEFAULT_PALETTE
}

/** Generates a small, symmetric, retro "monster sprite" mosaic — the same card always produces
 * the same pattern. Fully procedural/original artwork, no copyrighted material involved. */
function generateGrid(seed: number): number[][] {
  const rand = mulberry32(seed)
  const rows: number[][] = []
  for (let y = 0; y < GRID; y++) {
    const row: number[] = []
    for (let x = 0; x < HALF; x++) {
      const r = rand()
      // Bias toward background (0) so shapes read as a silhouette rather than noise.
      row.push(r < 0.45 ? 0 : 1 + Math.floor(r * 3))
    }
    rows.push([...row, ...row.slice().reverse()])
  }
  return rows
}

export function PixelSprite({
  card,
  className = '',
  style,
}: {
  card: CardDef
  className?: string
  style?: CSSProperties
}) {
  const palette = paletteFor(card)
  const grid = useMemo(() => generateGrid(hashString(card.name)), [card.name])

  return (
    <svg
      viewBox={`0 0 ${GRID} ${GRID}`}
      className={`h-full w-full ${className}`}
      style={style}
      shapeRendering="crispEdges"
      preserveAspectRatio="xMidYMid slice"
    >
      <rect x={0} y={0} width={GRID} height={GRID} fill={palette[0]} />
      {grid.map((row, y) =>
        row.map((cell, x) =>
          cell === 0 ? null : <rect key={`${x}-${y}`} x={x} y={y} width={1} height={1} fill={palette[cell]} />,
        ),
      )}
    </svg>
  )
}
