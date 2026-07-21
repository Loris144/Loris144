import { cardDb } from '../data/cardDb'
import { isScriptedSpell, isScriptedTrap } from './effects'
import { getPlayer } from './helpers'
import type { DuelState, Side } from './types'

/**
 * Whether `side` has any card they could legally activate right now at instant speed: a Set Trap
 * (not placed this turn) or a Quick-Play Spell in hand. This is a simplified stand-in for the
 * real Spell Speed system (1/2/3) — sized to what this card pool actually needs (no Counter Traps
 * exist yet), not a full arbitrary-depth chain engine.
 */
export function hasEligiblePriorityResponse(state: DuelState, side: Side): boolean {
  const p = getPlayer(state, side)
  const hasSetTrap = p.spellTrapZones.some((z) => {
    if (!z || z.card.turnPlaced === state.turn) return false
    const def = cardDb.byId(z.card.cardId)
    return def?.category === 'Trap' && isScriptedTrap(def.name)
  })
  if (hasSetTrap) return true
  return p.hand.some((c) => {
    const def = cardDb.byId(c.cardId)
    return def?.category === 'Spell' && def.kind === 'Quick-Play' && isScriptedSpell(def.name)
  })
}
