import { cardDb } from '../data/cardDb'
import type { DuelCard, DuelState, PlayerState, Side } from './types'

export function uid(): string {
  return Math.random().toString(36).slice(2) + Date.now().toString(36)
}

export function opponent(side: Side): Side {
  return side === 'player' ? 'cpu' : 'player'
}

export function getPlayer(state: DuelState, side: Side): PlayerState {
  return side === 'player' ? state.player : state.cpu
}

export function log(state: DuelState, message: string): void {
  state.log.push(message)
  if (state.log.length > 200) state.log.shift()
}

export function cardName(cardId: number): string {
  return cardDb.byId(cardId)?.name ?? `#${cardId}`
}

export function drawCard(state: DuelState, side: Side, count = 1): void {
  const p = getPlayer(state, side)
  for (let i = 0; i < count; i++) {
    const next = p.deck.shift()
    if (!next) {
      state.winner = opponent(side)
      state.winReason = `${side === 'player' ? 'Du hast' : 'Der Gegner hat'} keine Karten mehr im Deck (Decked Out).`
      return
    }
    p.hand.push(next)
  }
}

export function sendToGraveyard(state: DuelState, side: Side, card: DuelCard): void {
  const p = getPlayer(state, side)
  p.graveyard.push(card)
  checkWhiteStoneTrigger(state, side, card)
}

function checkWhiteStoneTrigger(state: DuelState, side: Side, card: DuelCard): void {
  if (card.cardId !== 60) return // The White Stone of Legend
  const p = getPlayer(state, side)
  const idx = p.deck.findIndex((c) => c.cardId === 2)
  if (idx >= 0) {
    const [blueEyes] = p.deck.splice(idx, 1)
    p.hand.push(blueEyes)
    log(state, `${side === 'player' ? 'Du hast' : 'Der Gegner hat'} durch "The White Stone of Legend" einen Blue-Eyes White Dragon aufs Hand geholt.`)
  }
}

export function checkExodiaWin(state: DuelState, side: Side): void {
  const p = getPlayer(state, side)
  const required = [16, 17, 18, 19, 20]
  const hasAll = required.every((id) => p.hand.some((c) => c.cardId === id))
  if (hasAll) {
    state.winner = side
    state.winReason = `${side === 'player' ? 'Du hast' : 'Der Gegner hat'} alle 5 Exodia-Teile auf der Hand: Sofortiger Sieg!`
  }
}

export function tributesNeeded(level: number | undefined): number {
  if (!level) return 0
  if (level >= 7) return 2
  if (level >= 5) return 1
  return 0
}

export function allField(p: PlayerState) {
  return p.monsterZones.filter((z) => z !== null)
}

export function findEmptyZoneIndex<T>(zones: (T | null)[]): number {
  return zones.findIndex((z) => z === null)
}
