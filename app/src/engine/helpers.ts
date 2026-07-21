import { cardDb } from '../data/cardDb'
import type { DuelCard, DuelState, MonsterSlot, PlayerState, Side } from './types'

export const EXTRA_DECK_KINDS = new Set(['Fusion', 'Synchro', 'Xyz', 'Link'])

/** Every monster slot a side controls: their 5 Main Monster Zones plus any of the 2 shared Extra
 * Monster Zones they currently control (Master Rule 5). */
export function monstersControlledBy(state: DuelState, side: Side): MonsterSlot[] {
  const p = getPlayer(state, side)
  const main = p.monsterZones.filter((z): z is MonsterSlot => z !== null)
  const extra = state.extraMonsterZones.filter((z) => z !== null && z.controller === side).map((z) => z!.monster)
  return [...main, ...extra]
}

export interface MonsterLocation {
  zone: 'main' | 'extra'
  side: Side
  idx: number
  slot: MonsterSlot
}

/** Finds a monster by instance id anywhere on the field, regardless of which side placed it in a
 * shared Extra Monster Zone. */
export function findMonsterAnywhere(state: DuelState, instanceId: string): MonsterLocation | null {
  for (const side of ['player', 'cpu'] as Side[]) {
    const p = getPlayer(state, side)
    const idx = p.monsterZones.findIndex((z) => z?.card.instanceId === instanceId)
    if (idx >= 0) return { zone: 'main', side, idx, slot: p.monsterZones[idx]! }
  }
  const extraIdx = state.extraMonsterZones.findIndex((z) => z?.monster.card.instanceId === instanceId)
  if (extraIdx >= 0) {
    const z = state.extraMonsterZones[extraIdx]!
    return { zone: 'extra', side: z.controller, idx: extraIdx, slot: z.monster }
  }
  return null
}

/** Removes and returns a monster slot from wherever it is on the field. */
export function removeMonsterAnywhere(state: DuelState, instanceId: string): MonsterSlot | null {
  const found = findMonsterAnywhere(state, instanceId)
  if (!found) return null
  if (found.zone === 'main') {
    getPlayer(state, found.side).monsterZones[found.idx] = null
  } else {
    state.extraMonsterZones[found.idx] = null
  }
  return found.slot
}

/** Places a Special Summoned Extra Deck monster (Fusion/Synchro/Xyz/Link) into a free shared
 * Extra Monster Zone. Returns false if both are occupied (no Link Monster exists yet to unlock a
 * Main Monster Zone instead). */
export function placeInExtraZone(state: DuelState, side: Side, monster: MonsterSlot): boolean {
  const idx = state.extraMonsterZones.findIndex((z) => z === null)
  if (idx < 0) return false
  state.extraMonsterZones[idx] = { controller: side, monster }
  return true
}

/** Places a Normal/Ritual-summoned (or otherwise Main-Deck) monster into a free Main Monster
 * Zone. Returns false if all 5 are occupied. */
export function placeInMainZone(state: DuelState, side: Side, monster: MonsterSlot): boolean {
  const p = getPlayer(state, side)
  const idx = p.monsterZones.findIndex((z) => z === null)
  if (idx < 0) return false
  p.monsterZones[idx] = monster
  return true
}

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
