import { cardDb } from '../data/cardDb'
import { activateSpellEffect, activateTimeWizard, activateTrapEffect, resolveFlipEffect } from './effects'
import {
  checkExodiaWin,
  drawCard,
  findMonsterAnywhere,
  getPlayer,
  log,
  monstersControlledBy,
  opponent,
  placeInExtraZone,
  placeInMainZone,
  removeMonsterAnywhere,
  sendToGraveyard,
  tributesNeeded,
} from './helpers'
import type { DuelState, MonsterSlot, Phase, Side } from './types'
import { hasEligiblePriorityResponse } from './priority'

const PHASE_ORDER: Phase[] = ['Draw', 'Standby', 'Main1', 'Battle', 'Main2', 'End']

function clone(state: DuelState): DuelState {
  return structuredClone(state)
}

export function advancePhase(input: DuelState): DuelState {
  const state = clone(input)
  if (state.winner) return state

  const curIdx = PHASE_ORDER.indexOf(state.phase)
  if (curIdx < PHASE_ORDER.length - 1) {
    state.phase = PHASE_ORDER[curIdx + 1]
  } else {
    endTurnInternal(state)
    state.phase = 'Draw'
  }

  if (state.phase === 'Draw') {
    const isVeryFirstTurn = state.turn === 1 && state.log.length <= 1
    if (!isVeryFirstTurn) {
      drawCard(state, state.activePlayer)
      log(state, `${state.activePlayer === 'player' ? 'Du ziehst' : 'Gegner zieht'} eine Karte.`)
    }
    checkExodiaWin(state, state.activePlayer)
  }

  if (state.phase === 'Standby') {
    const p = getPlayer(state, state.activePlayer)
    if (p.swordsOfRevealingLightTurns > 0) p.swordsOfRevealingLightTurns -= 1
  }

  return state
}

function endTurnInternal(state: DuelState): void {
  for (const side of ['player', 'cpu'] as Side[]) {
    const p = getPlayer(state, side)
    p.normalSummonUsed = false
    for (const slot of p.monsterZones) {
      if (slot) {
        slot.hasAttacked = false
        slot.summonedThisTurn = false
      }
    }
  }
  for (const zone of state.extraMonsterZones) {
    if (zone) {
      zone.monster.hasAttacked = false
      zone.monster.summonedThisTurn = false
    }
  }
  state.activePlayer = opponent(state.activePlayer)
  if (state.activePlayer === state.player.side) state.turn += 1
  state.damageNegated = false
  log(state, `--- Runde ${state.turn}: ${state.activePlayer === 'player' ? 'Du bist' : 'Gegner ist'} am Zug ---`)
}

export function normalSummon(
  input: DuelState,
  side: Side,
  handInstanceId: string,
  position: 'Attack' | 'Defense',
  faceDown: boolean,
  tributeInstanceIds: string[],
): DuelState {
  const state = clone(input)
  const p = getPlayer(state, side)
  if (p.normalSummonUsed) return input
  const handIdx = p.hand.findIndex((c) => c.instanceId === handInstanceId)
  if (handIdx < 0) return input
  const def = cardDb.byId(p.hand[handIdx].cardId)
  if (!def || def.category !== 'Monster') return input
  if (['Fusion', 'Synchro', 'Xyz', 'Link'].includes(def.kind)) return input

  const needed = tributesNeeded(def.level)
  if (tributeInstanceIds.length !== needed) return input
  const controlled = monstersControlledBy(state, side)
  if (!tributeInstanceIds.every((id) => controlled.some((m) => m.card.instanceId === id))) return input
  if (!p.monsterZones.some((z) => z === null)) return input

  for (const id of tributeInstanceIds) {
    const slot = removeMonsterAnywhere(state, id)
    if (slot) sendToGraveyard(state, side, slot.card)
  }

  const [card] = p.hand.splice(handIdx, 1)
  const slot: MonsterSlot = {
    card,
    position,
    faceDown,
    hasAttacked: false,
    summonedThisTurn: true,
    equips: [],
    spellCounters: 0,
  }
  placeInMainZone(state, side, slot)
  p.normalSummonUsed = true
  log(state, `${side === 'player' ? 'Du beschwörst' : 'Gegner beschwört'} ${faceDown ? 'eine verdeckte Monsterkarte' : def.name}.`)

  if (!faceDown) resolveFlipEffect(state, side, card)

  const responder = opponent(side)
  if (hasEligiblePriorityResponse(state, responder)) {
    state.pendingPriority = { side: responder, reason: 'normal-summon', contextInstanceId: card.instanceId }
  }

  return state
}

export function setSpellTrap(input: DuelState, side: Side, handInstanceId: string): DuelState {
  const state = clone(input)
  const p = getPlayer(state, side)
  const handIdx = p.hand.findIndex((c) => c.instanceId === handInstanceId)
  if (handIdx < 0) return input
  const def = cardDb.byId(p.hand[handIdx].cardId)
  if (!def || def.category === 'Monster') return input
  const zoneIdx = p.spellTrapZones.findIndex((z) => z === null)
  if (zoneIdx < 0) return input
  const [card] = p.hand.splice(handIdx, 1)
  card.turnPlaced = state.turn
  p.spellTrapZones[zoneIdx] = { card, faceDown: true }
  log(state, `${side === 'player' ? 'Du legst' : 'Gegner legt'} eine Karte verdeckt.`)
  return state
}

export function activateSpellFromHand(input: DuelState, side: Side, handInstanceId: string, targetInstanceId?: string): DuelState {
  const state = clone(input)
  const p = getPlayer(state, side)
  const handIdx = p.hand.findIndex((c) => c.instanceId === handInstanceId)
  if (handIdx < 0) return input
  const [card] = p.hand.splice(handIdx, 1)
  const def = cardDb.byId(card.cardId)
  const message = activateSpellEffect(state, side, card, targetInstanceId)
  sendToGraveyard(state, side, card)
  log(state, `${def?.name}: ${message}`)

  const responder = opponent(side)
  if (hasEligiblePriorityResponse(state, responder)) {
    state.pendingPriority = { side: responder, reason: 'spell-activation' }
  }

  return state
}

export function activateSetSpell(input: DuelState, side: Side, zoneInstanceId: string, targetInstanceId?: string): DuelState {
  const state = clone(input)
  const p = getPlayer(state, side)
  const idx = p.spellTrapZones.findIndex((z) => z?.card.instanceId === zoneInstanceId)
  if (idx < 0) return input
  const slot = p.spellTrapZones[idx]!
  const def = cardDb.byId(slot.card.cardId)
  if (def?.category !== 'Spell') return input
  p.spellTrapZones[idx] = null
  const message = activateSpellEffect(state, side, slot.card, targetInstanceId)
  sendToGraveyard(state, side, slot.card)
  log(state, `${def?.name}: ${message}`)

  const responder = opponent(side)
  if (hasEligiblePriorityResponse(state, responder)) {
    state.pendingPriority = { side: responder, reason: 'spell-activation' }
  }

  return state
}

export function declareAttack(input: DuelState, attackerInstanceId: string, target: string | 'direct'): DuelState {
  const state = clone(input)
  const found = findMonsterAnywhere(state, attackerInstanceId)
  if (!found || found.side !== state.activePlayer) return input
  const slot = found.slot
  if (slot.hasAttacked || slot.summonedThisTurn || slot.position !== 'Attack') return input
  if (getPlayer(state, state.activePlayer).swordsOfRevealingLightTurns > 0) return input
  state.pendingAttacker = attackerInstanceId
  state.pendingTarget = target
  state.battleResolved = false
  const def = cardDb.byId(slot.card.cardId)
  log(state, `${state.activePlayer === 'player' ? 'Du greifst' : 'Gegner greift'} mit ${def?.name} an.`)
  return state
}

export function activateTrapResponse(input: DuelState, side: Side, zoneInstanceId: string, targetInstanceId?: string): DuelState {
  const state = clone(input)
  const p = getPlayer(state, side)
  const idx = p.spellTrapZones.findIndex((z) => z?.card.instanceId === zoneInstanceId)
  if (idx < 0) return input
  const slot = p.spellTrapZones[idx]!
  if (slot.card.turnPlaced === state.turn) return input // can't activate the turn it was set
  const def = cardDb.byId(slot.card.cardId)
  if (def?.category !== 'Trap') return input
  p.spellTrapZones[idx] = null
  const message = activateTrapEffect(state, side, slot.card, {
    attackerInstanceId: state.pendingAttacker ?? undefined,
    summonedInstanceId: targetInstanceId,
  })
  sendToGraveyard(state, side, slot.card)
  log(state, `${def?.name}: ${message}`)
  return state
}

export function discardKuriboh(input: DuelState, side: Side, handInstanceId: string): DuelState {
  const state = clone(input)
  const p = getPlayer(state, side)
  const idx = p.hand.findIndex((c) => c.instanceId === handInstanceId)
  if (idx < 0) return input
  const def = cardDb.byId(p.hand[idx].cardId)
  if (def?.name !== 'Kuriboh') return input
  const [card] = p.hand.splice(idx, 1)
  sendToGraveyard(state, side, card)
  state.damageNegated = true
  log(state, `${side === 'player' ? 'Du wirfst' : 'Gegner wirft'} Kuriboh ab: Kampfschaden diese Runde wird 0.`)
  return state
}

export function passResponse(input: DuelState): DuelState {
  const state = clone(input)
  if (!state.pendingAttacker || state.battleResolved) return state
  resolveBattleInternal(state)
  return state
}

function resolveBattleInternal(state: DuelState): void {
  const attackerSide = state.activePlayer
  const defenderSide = opponent(attackerSide)
  const atkPlayer = getPlayer(state, attackerSide)
  const defPlayer = getPlayer(state, defenderSide)
  const attackerFound = state.pendingAttacker ? findMonsterAnywhere(state, state.pendingAttacker) : null
  if (!attackerFound) { state.pendingAttacker = null; state.pendingTarget = null; return }
  const attackerSlot = attackerFound.slot
  attackerSlot.hasAttacked = true
  const attackerDef = cardDb.byId(attackerSlot.card.cardId)
  const atk = attackerDef?.atk ?? 0

  if (state.pendingTarget === 'direct' || !state.pendingTarget) {
    if (!state.damageNegated) defPlayer.lifePoints = Math.max(0, defPlayer.lifePoints - atk)
    log(state, `Direkter Angriff: ${state.damageNegated ? 0 : atk} Schaden.`)
  } else {
    const targetFound = findMonsterAnywhere(state, state.pendingTarget)
    if (!targetFound) {
      if (!state.damageNegated) defPlayer.lifePoints = Math.max(0, defPlayer.lifePoints - atk)
    } else {
      const targetSlot = targetFound.slot
      const targetDef = cardDb.byId(targetSlot.card.cardId)
      const targetPower = targetSlot.position === 'Attack' ? (targetDef?.atk ?? 0) : (targetDef?.def ?? 0)

      if (atk > targetPower) {
        sendToGraveyard(state, defenderSide, targetSlot.card)
        removeMonsterAnywhere(state, targetSlot.card.instanceId)
        if (targetSlot.position === 'Attack' && !state.damageNegated) {
          defPlayer.lifePoints = Math.max(0, defPlayer.lifePoints - (atk - targetPower))
        }
        log(state, `${targetDef?.name} wird zerstört.`)
      } else if (atk < targetPower) {
        sendToGraveyard(state, attackerSide, attackerSlot.card)
        removeMonsterAnywhere(state, attackerSlot.card.instanceId)
        if (targetSlot.position === 'Attack' && !state.damageNegated) {
          atkPlayer.lifePoints = Math.max(0, atkPlayer.lifePoints - (targetPower - atk))
        }
        log(state, `${attackerDef?.name} wird zerstört.`)
      } else {
        if (targetSlot.position === 'Attack') {
          sendToGraveyard(state, defenderSide, targetSlot.card)
          removeMonsterAnywhere(state, targetSlot.card.instanceId)
          sendToGraveyard(state, attackerSide, attackerSlot.card)
          removeMonsterAnywhere(state, attackerSlot.card.instanceId)
          log(state, 'Beide Monster werden zerstört (Gleichstand).')
        }
      }
    }
  }

  state.pendingAttacker = null
  state.pendingTarget = null
  state.battleResolved = true

  if (state.player.lifePoints <= 0) { state.winner = 'cpu'; state.winReason = 'Deine Lebenspunkte erreichten 0.' }
  if (state.cpu.lifePoints <= 0) { state.winner = 'player'; state.winReason = 'Die Lebenspunkte des Gegners erreichten 0.' }
}

export function changePosition(input: DuelState, side: Side, instanceId: string): DuelState {
  const state = clone(input)
  const found = findMonsterAnywhere(state, instanceId)
  if (!found || found.side !== side) return input
  const slot = found.slot
  if (slot.summonedThisTurn || slot.hasAttacked) return input
  slot.position = slot.position === 'Attack' ? 'Defense' : 'Attack'
  slot.faceDown = false
  return state
}

export function activateMonsterEffect(input: DuelState, side: Side, instanceId: string): DuelState {
  const state = clone(input)
  const found = findMonsterAnywhere(state, instanceId)
  if (!found || found.side !== side) return input
  const def = cardDb.byId(found.slot.card.cardId)
  if (def?.name === 'Time Wizard') {
    activateTimeWizard(state, side, found.slot.card)
  }
  return state
}

/**
 * Ritual Summon: activates a Ritual Spell from hand together with a Ritual Monster from hand,
 * Tributing field/hand monsters whose combined Level meets or exceeds the Ritual Monster's Level
 * (the real TCG procedure). The summoned monster goes to a Main Monster Zone — Ritual Monsters
 * are not Extra Deck monsters, so Master Rule 5's Extra Monster Zones don't apply to them.
 */
export function ritualSummon(
  input: DuelState,
  side: Side,
  ritualSpellHandInstanceId: string,
  ritualMonsterHandInstanceId: string,
  tributeInstanceIds: string[],
): DuelState {
  const state = clone(input)
  const p = getPlayer(state, side)
  if (ritualSpellHandInstanceId === ritualMonsterHandInstanceId) return input
  const spellCard = p.hand.find((c) => c.instanceId === ritualSpellHandInstanceId)
  const monsterCard = p.hand.find((c) => c.instanceId === ritualMonsterHandInstanceId)
  if (!spellCard || !monsterCard) return input
  const spellDef = cardDb.byId(spellCard.cardId)
  const monsterDef = cardDb.byId(monsterCard.cardId)
  if (spellDef?.category !== 'Spell' || spellDef.kind !== 'Ritual') return input
  if (monsterDef?.category !== 'Monster' || monsterDef.kind !== 'Ritual') return input
  if (!p.monsterZones.some((z) => z === null)) return input

  const controlled = monstersControlledBy(state, side)
  const tributeSlots = tributeInstanceIds.map((id) => controlled.find((m) => m.card.instanceId === id))
  if (tributeSlots.some((s) => !s) || tributeSlots.length === 0) return input
  const totalLevel = tributeSlots.reduce((sum, s) => sum + (cardDb.byId(s!.card.cardId)?.level ?? 0), 0)
  if (totalLevel < (monsterDef.level ?? 0)) return input

  for (const id of tributeInstanceIds) {
    const slot = removeMonsterAnywhere(state, id)
    if (slot) sendToGraveyard(state, side, slot.card)
  }
  const [removedSpell] = p.hand.splice(p.hand.findIndex((c) => c.instanceId === ritualSpellHandInstanceId), 1)
  sendToGraveyard(state, side, removedSpell)
  const [removedMonster] = p.hand.splice(p.hand.findIndex((c) => c.instanceId === ritualMonsterHandInstanceId), 1)

  const slot: MonsterSlot = {
    card: removedMonster,
    position: 'Attack',
    faceDown: false,
    hasAttacked: false,
    summonedThisTurn: true,
    equips: [],
    spellCounters: 0,
  }
  placeInMainZone(state, side, slot)
  log(state, `${side === 'player' ? 'Du beschwörst' : 'Gegner beschwört'} ${monsterDef.name} durch Ritualbeschwörung!`)
  return state
}

/**
 * Synchro Summon: Tributes 1 Tuner monster plus 1+ non-Tuner monsters you control whose combined
 * Levels exactly equal the target Synchro Monster's Level (the real TCG procedure), then Special
 * Summons it from the Extra Deck into a shared Extra Monster Zone.
 */
export function synchroSummon(
  input: DuelState,
  side: Side,
  tunerInstanceId: string,
  materialInstanceIds: string[],
  extraDeckCardId: number,
): DuelState {
  const state = clone(input)
  const p = getPlayer(state, side)
  if (!state.extraMonsterZones.some((z) => z === null)) return input

  const controlled = monstersControlledBy(state, side)
  const tuner = controlled.find((m) => m.card.instanceId === tunerInstanceId)
  if (!tuner || cardDb.byId(tuner.card.cardId)?.kind !== 'Tuner') return input
  if (materialInstanceIds.length === 0) return input
  const materials = materialInstanceIds.map((id) => controlled.find((m) => m.card.instanceId === id))
  if (materials.some((m) => !m)) return input
  if (materials.some((m) => cardDb.byId(m!.card.cardId)?.kind === 'Tuner')) return input

  const extraIdx = p.extraDeck.findIndex((c) => c.cardId === extraDeckCardId)
  if (extraIdx < 0) return input
  const targetDef = cardDb.byId(extraDeckCardId)
  if (!targetDef || targetDef.kind !== 'Synchro') return input
  const tunerLevel = cardDb.byId(tuner.card.cardId)?.level ?? 0
  const totalLevel = tunerLevel + materials.reduce((sum, m) => sum + (cardDb.byId(m!.card.cardId)?.level ?? 0), 0)
  if (totalLevel !== targetDef.level) return input

  for (const id of [tunerInstanceId, ...materialInstanceIds]) {
    const slot = removeMonsterAnywhere(state, id)
    if (slot) sendToGraveyard(state, side, slot.card)
  }
  const [fused] = p.extraDeck.splice(extraIdx, 1)
  const slot: MonsterSlot = {
    card: fused,
    position: 'Attack',
    faceDown: false,
    hasAttacked: false,
    summonedThisTurn: true,
    equips: [],
    spellCounters: 0,
  }
  placeInExtraZone(state, side, slot)
  log(state, `${side === 'player' ? 'Du beschwörst' : 'Gegner beschwört'} ${targetDef.name} durch Synchrobeschwörung!`)
  return state
}

/** Responds to a generalized priority window (see `pendingPriority`) by activating a Set Trap. */
export function respondToPriorityWithTrap(input: DuelState, side: Side, zoneInstanceId: string): DuelState {
  if (!input.pendingPriority || input.pendingPriority.side !== side) return input
  const contextInstanceId = input.pendingPriority.contextInstanceId
  const afterTrap = activateTrapResponse(input, side, zoneInstanceId, contextInstanceId)
  const state = clone(afterTrap)
  state.pendingPriority = null
  return state
}

/** Responds to a generalized priority window by activating a Quick-Play Spell from hand. */
export function respondToPriorityWithQuickPlay(input: DuelState, side: Side, handInstanceId: string, targetInstanceId?: string): DuelState {
  if (!input.pendingPriority || input.pendingPriority.side !== side) return input
  const afterSpell = activateSpellFromHand(input, side, handInstanceId, targetInstanceId)
  const state = clone(afterSpell)
  state.pendingPriority = null
  return state
}

/** Declines the generalized priority window, letting play continue. */
export function passPriority(input: DuelState): DuelState {
  const state = clone(input)
  state.pendingPriority = null
  return state
}
