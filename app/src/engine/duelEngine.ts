import { cardDb } from '../data/cardDb'
import { activateSpellEffect, activateTimeWizard, activateTrapEffect, resolveFlipEffect } from './effects'
import { checkExodiaWin, drawCard, getPlayer, log, opponent, sendToGraveyard, tributesNeeded } from './helpers'
import type { DuelState, MonsterSlot, Phase, Side } from './types'

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
  const tributeIdxs = tributeInstanceIds.map((id) => p.monsterZones.findIndex((z) => z?.card.instanceId === id))
  if (tributeIdxs.some((i) => i < 0)) return input

  const zoneIdx = p.monsterZones.findIndex((z) => z === null)
  if (zoneIdx < 0) return input

  for (const idx of tributeIdxs) {
    const slot = p.monsterZones[idx]!
    sendToGraveyard(state, side, slot.card)
    p.monsterZones[idx] = null
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
  p.monsterZones[zoneIdx] = slot
  p.normalSummonUsed = true
  log(state, `${side === 'player' ? 'Du beschwörst' : 'Gegner beschwört'} ${faceDown ? 'eine verdeckte Monsterkarte' : def.name}.`)

  if (!faceDown) resolveFlipEffect(state, side, card)

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
  return state
}

export function declareAttack(input: DuelState, attackerInstanceId: string, target: string | 'direct'): DuelState {
  const state = clone(input)
  const p = getPlayer(state, state.activePlayer)
  const slot = p.monsterZones.find((z) => z?.card.instanceId === attackerInstanceId)
  if (!slot || slot.hasAttacked || slot.summonedThisTurn || slot.position !== 'Attack') return input
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
  const attackerIdx = atkPlayer.monsterZones.findIndex((z) => z?.card.instanceId === state.pendingAttacker)
  if (attackerIdx < 0) { state.pendingAttacker = null; state.pendingTarget = null; return }
  const attackerSlot = atkPlayer.monsterZones[attackerIdx]!
  attackerSlot.hasAttacked = true
  const attackerDef = cardDb.byId(attackerSlot.card.cardId)
  const atk = attackerDef?.atk ?? 0

  if (state.pendingTarget === 'direct' || !state.pendingTarget) {
    if (!state.damageNegated) defPlayer.lifePoints = Math.max(0, defPlayer.lifePoints - atk)
    log(state, `Direkter Angriff: ${state.damageNegated ? 0 : atk} Schaden.`)
  } else {
    const targetIdx = defPlayer.monsterZones.findIndex((z) => z?.card.instanceId === state.pendingTarget)
    if (targetIdx < 0) {
      if (!state.damageNegated) defPlayer.lifePoints = Math.max(0, defPlayer.lifePoints - atk)
    } else {
      const targetSlot = defPlayer.monsterZones[targetIdx]!
      const targetDef = cardDb.byId(targetSlot.card.cardId)
      const targetPower = targetSlot.position === 'Attack' ? (targetDef?.atk ?? 0) : (targetDef?.def ?? 0)

      if (atk > targetPower) {
        sendToGraveyard(state, defenderSide, targetSlot.card)
        defPlayer.monsterZones[targetIdx] = null
        if (targetSlot.position === 'Attack' && !state.damageNegated) {
          defPlayer.lifePoints = Math.max(0, defPlayer.lifePoints - (atk - targetPower))
        }
        log(state, `${targetDef?.name} wird zerstört.`)
      } else if (atk < targetPower) {
        sendToGraveyard(state, attackerSide, attackerSlot.card)
        atkPlayer.monsterZones[attackerIdx] = null
        if (targetSlot.position === 'Attack' && !state.damageNegated) {
          atkPlayer.lifePoints = Math.max(0, atkPlayer.lifePoints - (targetPower - atk))
        }
        log(state, `${attackerDef?.name} wird zerstört.`)
      } else {
        if (targetSlot.position === 'Attack') {
          sendToGraveyard(state, defenderSide, targetSlot.card)
          defPlayer.monsterZones[targetIdx] = null
          sendToGraveyard(state, attackerSide, attackerSlot.card)
          atkPlayer.monsterZones[attackerIdx] = null
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
  const p = getPlayer(state, side)
  const slot = p.monsterZones.find((z) => z?.card.instanceId === instanceId)
  if (!slot || slot.summonedThisTurn) return input
  if (slot.hasAttacked) return input
  slot.position = slot.position === 'Attack' ? 'Defense' : 'Attack'
  slot.faceDown = false
  return state
}

export function activateMonsterEffect(input: DuelState, side: Side, instanceId: string): DuelState {
  const state = clone(input)
  const p = getPlayer(state, side)
  const slot = p.monsterZones.find((z) => z?.card.instanceId === instanceId)
  if (!slot) return input
  const def = cardDb.byId(slot.card.cardId)
  if (def?.name === 'Time Wizard') {
    activateTimeWizard(state, side, slot.card)
  }
  return state
}
