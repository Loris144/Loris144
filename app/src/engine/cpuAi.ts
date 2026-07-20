import { cardDb } from '../data/cardDb'
import {
  activateSetSpell,
  activateSpellFromHand,
  activateTrapResponse,
  declareAttack,
  discardKuriboh,
  normalSummon,
  setSpellTrap,
} from './duelEngine'
import { getSpellTargets, isScriptedSpell, isScriptedTrap } from './effects'
import { getPlayer, tributesNeeded } from './helpers'
import type { DuelState } from './types'

const TRAP_NAMES_ATTACK_WINDOW = new Set(['Mirror Force', 'Magic Cylinder', 'Negate Attack'])

function pickTarget(state: DuelState, cardName: string): string | undefined {
  const targets = getSpellTargets(state, 'cpu', cardName)
  return targets[0]
}

export function cpuRunMainPhase(input: DuelState): DuelState {
  let state = input
  const p = getPlayer(state, 'cpu')

  // Activate helpful spells from hand first.
  const handSnapshot = [...p.hand]
  for (const card of handSnapshot) {
    const def = cardDb.byId(card.cardId)
    if (!def || def.category !== 'Spell' || !isScriptedSpell(def.name)) continue
    if (def.name === 'Swords of Revealing Light' && getPlayer(state, 'cpu').monsterZones.every((z) => z === null)) continue
    const target = pickTarget(state, def.name)
    const currentPlayer = getPlayer(state, 'cpu')
    if (!currentPlayer.hand.some((c) => c.instanceId === card.instanceId)) continue
    state = activateSpellFromHand(state, 'cpu', card.instanceId, target)
  }

  // Normal summon the strongest playable monster.
  const cpuNow = getPlayer(state, 'cpu')
  if (!cpuNow.normalSummonUsed) {
    const candidates = cpuNow.hand
      .map((c) => ({ c, def: cardDb.byId(c.cardId) }))
      .filter((x) => x.def?.category === 'Monster' && !['Fusion', 'Synchro', 'Xyz', 'Link'].includes(x.def.kind))
      .filter((x) => tributesNeeded(x.def!.level) <= cpuNow.monsterZones.filter((z) => z !== null).length)
      .sort((a, b) => (b.def!.atk ?? 0) - (a.def!.atk ?? 0))

    if (candidates.length > 0 && cpuNow.monsterZones.some((z) => z === null)) {
      const best = candidates[0]
      const needed = tributesNeeded(best.def!.level)
      const tributeIds = cpuNow.monsterZones
        .filter((z): z is NonNullable<typeof z> => z !== null)
        .sort((a, b) => (cardDb.byId(a.card.cardId)?.atk ?? 0) - (cardDb.byId(b.card.cardId)?.atk ?? 0))
        .slice(0, needed)
        .map((z) => z.card.instanceId)
      if (tributeIds.length === needed) {
        const opponentField = getPlayer(state, 'player').monsterZones.filter((z) => z !== null)
        const position = opponentField.length > 0 && (best.def!.atk ?? 0) < 1500 ? 'Defense' : 'Attack'
        state = normalSummon(state, 'cpu', best.c.instanceId, position, position === 'Defense', tributeIds)
      }
    }
  }

  // Set a trap if available and a zone is free.
  const cpuAfterSummon = getPlayer(state, 'cpu')
  const trapInHand = cpuAfterSummon.hand.find((c) => cardDb.byId(c.cardId)?.category === 'Trap')
  if (trapInHand && cpuAfterSummon.spellTrapZones.some((z) => z === null)) {
    state = setSpellTrap(state, 'cpu', trapInHand.instanceId)
  }

  // Set any remaining scripted spell that needs field presence (handled above) — leftover Spells just get set too.
  const cpuAfterTrap = getPlayer(state, 'cpu')
  const spellInHand = cpuAfterTrap.hand.find((c) => cardDb.byId(c.cardId)?.category === 'Spell')
  if (spellInHand && cpuAfterTrap.spellTrapZones.some((z) => z === null)) {
    state = activateSetSpell(state, 'cpu', spellInHand.instanceId, pickTarget(state, cardDb.byId(spellInHand.cardId)!.name))
  }

  return state
}

function nextEligibleAttacker(state: DuelState) {
  const cpu = getPlayer(state, 'cpu')
  const attackers = cpu.monsterZones.filter(
    (z): z is NonNullable<typeof z> => z !== null && !z.hasAttacked && !z.summonedThisTurn && z.position === 'Attack',
  )
  for (const attacker of attackers) {
    const atk = cardDb.byId(attacker.card.cardId)?.atk ?? 0
    const opponentMonsters = getPlayer(state, 'player').monsterZones.filter((z): z is NonNullable<typeof z> => z !== null)
    if (opponentMonsters.length === 0) return { attacker, target: 'direct' as const }
    const beatable = opponentMonsters
      .map((z) => ({ z, power: z.position === 'Attack' ? (cardDb.byId(z.card.cardId)?.atk ?? 0) : (cardDb.byId(z.card.cardId)?.def ?? 0) }))
      .filter((x) => x.power < atk)
      .sort((a, b) => b.power - a.power)
    if (beatable.length > 0) return { attacker, target: beatable[0].z.card.instanceId }
  }
  return null
}

/** Declares a single CPU attack (if any eligible attacker remains) and stops so the human player
 * can be offered a response window before the battle resolves. Returns the input state unchanged
 * if the CPU has no more good attacks this turn. */
export function cpuDeclareNextAttack(input: DuelState): DuelState {
  const pick = nextEligibleAttacker(input)
  if (!pick) return input
  return declareAttack(input, pick.attacker.card.instanceId, pick.target)
}

export function cpuHasMoreAttacks(state: DuelState): boolean {
  return nextEligibleAttacker(state) !== null
}

export function cpuRespondToAttack(input: DuelState): DuelState {
  const state = input
  if (!state.pendingAttacker || state.battleResolved) return state
  const cpu = getPlayer(state, 'cpu')
  const trapSlot = cpu.spellTrapZones.find(
    (z) => z !== null && z.card.turnPlaced !== state.turn && TRAP_NAMES_ATTACK_WINDOW.has(cardDb.byId(z.card.cardId)?.name ?? ''),
  )

  const attackerSlot = getPlayer(state, 'player').monsterZones.find((z) => z?.card.instanceId === state.pendingAttacker)
  const incomingAtk = attackerSlot ? cardDb.byId(attackerSlot.card.cardId)?.atk ?? 0 : 0

  if (trapSlot) {
    return activateTrapResponse(state, 'cpu', trapSlot.card.instanceId)
  }
  if (incomingAtk >= cpu.lifePoints) {
    const kuriboh = cpu.hand.find((c) => cardDb.byId(c.cardId)?.name === 'Kuriboh')
    if (kuriboh) return discardKuriboh(state, 'cpu', kuriboh.instanceId)
  }
  return state
}

export function isScriptedTrapName(name: string): boolean {
  return isScriptedTrap(name)
}
