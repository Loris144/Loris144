import { cardDb } from '../data/cardDb'
import { fusionRecipes } from './fusion'
import {
  EXTRA_DECK_KINDS,
  findMonsterAnywhere,
  getPlayer,
  log,
  monstersControlledBy,
  opponent,
  placeInExtraZone,
  placeInMainZone,
  removeMonsterAnywhere,
  sendToGraveyard,
  uid,
} from './helpers'
import type { DuelCard, DuelState, MonsterSlot, Side } from './types'

export type TargetKind = 'graveyard-monster' | 'spelltrap' | 'face-up-monster' | 'hand-level8' | 'none'

const NO_TARGET_SPELLS = new Set(['Pot of Greed', 'Dark Hole', 'Raigeki', 'Swords of Revealing Light', 'Polymerization', 'Red-Eyes Insight'])

export function targetKindForCard(name: string): TargetKind {
  switch (name) {
    case 'Monster Reborn':
      return 'graveyard-monster'
    case 'Mystical Space Typhoon':
      return 'spelltrap'
    case 'Book of Moon':
      return 'face-up-monster'
    case 'Trade-In':
      return 'hand-level8'
    default:
      return NO_TARGET_SPELLS.has(name) ? 'none' : 'none'
  }
}

export function isScriptedSpell(name: string): boolean {
  return [
    'Pot of Greed', 'Dark Hole', 'Raigeki', 'Swords of Revealing Light', 'Monster Reborn',
    'Book of Moon', 'Mystical Space Typhoon', 'Polymerization', 'Trade-In', 'Red-Eyes Insight',
  ].includes(name)
}

export function isScriptedTrap(name: string): boolean {
  return ['Mirror Force', 'Magic Cylinder', 'Negate Attack', 'Trap Hole'].includes(name)
}

function destroyAllMonsters(state: DuelState, side: Side): void {
  for (const slot of monstersControlledBy(state, side)) {
    sendToGraveyard(state, side, slot.card)
    removeMonsterAnywhere(state, slot.card.instanceId)
  }
}

function summonToCorrectZone(state: DuelState, side: Side, monsterCardId: number, card: DuelCard): boolean {
  const def = cardDb.byId(monsterCardId)
  const slot: MonsterSlot = { card, position: 'Attack', faceDown: false, hasAttacked: false, summonedThisTurn: true, equips: [], spellCounters: 0 }
  if (def && EXTRA_DECK_KINDS.has(def.kind)) return placeInExtraZone(state, side, slot)
  return placeInMainZone(state, side, slot)
}

export function activateSpellEffect(state: DuelState, side: Side, card: DuelCard, targetInstanceId?: string): string {
  const def = cardDb.byId(card.cardId)
  const name = def?.name ?? ''
  const p = getPlayer(state, side)
  const opp = getPlayer(state, opponent(side))

  switch (name) {
    case 'Pot of Greed': {
      for (let i = 0; i < 2; i++) {
        const c = p.deck.shift()
        if (c) p.hand.push(c)
      }
      return 'Du ziehst 2 Karten.'
    }
    case 'Dark Hole': {
      destroyAllMonsters(state, 'player')
      destroyAllMonsters(state, 'cpu')
      return 'Alle Monster werden zerstört.'
    }
    case 'Raigeki': {
      destroyAllMonsters(state, opponent(side))
      return 'Alle gegnerischen Monster werden zerstört.'
    }
    case 'Swords of Revealing Light': {
      opp.swordsOfRevealingLightTurns = 3
      return 'Der Gegner kann 3 Runden lang nicht angreifen.'
    }
    case 'Monster Reborn': {
      if (!targetInstanceId) return 'Kein Ziel gewählt.'
      for (const side_ of ['player', 'cpu'] as Side[]) {
        const pl = getPlayer(state, side_)
        const idx = pl.graveyard.findIndex((c) => c.instanceId === targetInstanceId)
        if (idx >= 0) {
          const [revived] = pl.graveyard.splice(idx, 1)
          const placed = summonToCorrectZone(state, side, revived.cardId, revived)
          if (!placed) return 'Keine freie Monsterzone.'
          return `${cardDb.byId(revived.cardId)?.name} wird wiederbelebt.`
        }
      }
      return 'Ziel nicht gefunden.'
    }
    case 'Book of Moon': {
      if (!targetInstanceId) return 'Kein Ziel gewählt.'
      const found = findMonsterAnywhere(state, targetInstanceId)
      if (!found) return 'Ziel nicht gefunden.'
      found.slot.position = 'Defense'
      found.slot.faceDown = true
      return `${cardDb.byId(found.slot.card.cardId)?.name} wird verdeckt.`
    }
    case 'Mystical Space Typhoon': {
      if (!targetInstanceId) return 'Kein Ziel gewählt.'
      for (const side_ of ['player', 'cpu'] as Side[]) {
        const pl = getPlayer(state, side_)
        const idx = pl.spellTrapZones.findIndex((z) => z?.card.instanceId === targetInstanceId)
        if (idx >= 0) {
          const slot = pl.spellTrapZones[idx]!
          sendToGraveyard(state, side_, slot.card)
          pl.spellTrapZones[idx] = null
          return `${cardDb.byId(slot.card.cardId)?.name} wird zerstört.`
        }
        if (pl.fieldSpell?.card.instanceId === targetInstanceId) {
          sendToGraveyard(state, side_, pl.fieldSpell.card)
          pl.fieldSpell = null
          return 'Feldzauber zerstört.'
        }
      }
      return 'Ziel nicht gefunden.'
    }
    case 'Polymerization': {
      for (const recipe of fusionRecipes) {
        const needed = [...recipe.materialCardIds]
        const handCopy = [...p.hand]
        const usedInstances: DuelCard[] = []
        for (const need of needed) {
          const idx = handCopy.findIndex((c) => c.cardId === need)
          if (idx < 0) { usedInstances.length = 0; break }
          usedInstances.push(handCopy[idx])
          handCopy.splice(idx, 1)
        }
        if (usedInstances.length === needed.length) {
          const extraIdx = p.extraDeck.findIndex((c) => c.cardId === recipe.resultCardId)
          if (extraIdx < 0 || !state.extraMonsterZones.some((z) => z === null)) continue
          for (const used of usedInstances) {
            p.hand = p.hand.filter((c) => c.instanceId !== used.instanceId)
            sendToGraveyard(state, side, used)
          }
          const [fused] = p.extraDeck.splice(extraIdx, 1)
          summonToCorrectZone(state, side, fused.cardId, fused)
          return `${cardDb.byId(fused.cardId)?.name} wird fusionsbeschworen!`
        }
      }
      return 'Keine passenden Fusionsmaterialien auf der Hand.'
    }
    case 'Trade-In': {
      const idx = targetInstanceId
        ? p.hand.findIndex((c) => c.instanceId === targetInstanceId)
        : p.hand.findIndex((c) => (cardDb.byId(c.cardId)?.level ?? 0) === 8)
      if (idx < 0) return 'Keine Level-8-Monster auf der Hand.'
      const [discarded] = p.hand.splice(idx, 1)
      sendToGraveyard(state, side, discarded)
      for (let i = 0; i < 2; i++) {
        const c = p.deck.shift()
        if (c) p.hand.push(c)
      }
      return 'Level-8-Monster abgeworfen, 2 Karten gezogen.'
    }
    case 'Red-Eyes Insight': {
      const idx = p.deck.findIndex((c) => c.cardId === 3)
      if (idx < 0) return 'Kein Red-Eyes B. Dragon im Deck.'
      const [found] = p.deck.splice(idx, 1)
      p.hand.push(found)
      p.lifePoints = Math.max(0, p.lifePoints - 500)
      return 'Red-Eyes B. Dragon geholt, 500 LP bezahlt.'
    }
    default:
      return `${name}: In dieser Version keine besondere Wirkung (Vanilla).`
  }
}

export function activateTrapEffect(
  state: DuelState,
  side: Side,
  card: DuelCard,
  context: { attackerInstanceId?: string; summonedInstanceId?: string },
): string {
  const def = cardDb.byId(card.cardId)
  const name = def?.name ?? ''
  const opp = getPlayer(state, opponent(side))

  switch (name) {
    case 'Mirror Force': {
      for (const slot of monstersControlledBy(state, opponent(side))) {
        if (slot.position === 'Attack') {
          sendToGraveyard(state, opponent(side), slot.card)
          removeMonsterAnywhere(state, slot.card.instanceId)
        }
      }
      state.pendingAttacker = null
      state.battleResolved = true
      return 'Alle gegnerischen Angriffsmonster werden zerstört.'
    }
    case 'Magic Cylinder': {
      const found = context.attackerInstanceId ? findMonsterAnywhere(state, context.attackerInstanceId) : null
      if (!found) return 'Kein Angreifer gefunden.'
      const atk = cardDb.byId(found.slot.card.cardId)?.atk ?? 0
      opp.lifePoints = Math.max(0, opp.lifePoints - atk)
      state.pendingAttacker = null
      state.battleResolved = true
      return `Angriff negiert, ${atk} Schaden reflektiert.`
    }
    case 'Negate Attack': {
      state.pendingAttacker = null
      state.battleResolved = true
      state.phase = 'Main2'
      return 'Angriff negiert, Battle Phase beendet.'
    }
    case 'Trap Hole': {
      const found = context.summonedInstanceId ? findMonsterAnywhere(state, context.summonedInstanceId) : null
      if (!found) return 'Kein gültiges Ziel.'
      const atk = cardDb.byId(found.slot.card.cardId)?.atk ?? 0
      if (atk < 1000) return 'Zielmonster hat weniger als 1000 ATK.'
      sendToGraveyard(state, found.side, found.slot.card)
      removeMonsterAnywhere(state, found.slot.card.instanceId)
      return 'Beschworenes Monster wird zerstört.'
    }
    default:
      log(state, `${name}: keine Wirkung implementiert.`)
      return `${name}: keine Wirkung implementiert.`
  }
}

export function resolveFlipEffect(state: DuelState, side: Side, card: DuelCard): void {
  const name = cardDb.byId(card.cardId)?.name
  if (name === 'Man-Eater Bug') {
    const oppSide = opponent(side)
    const target = monstersControlledBy(state, oppSide)[0]
    if (target) {
      sendToGraveyard(state, oppSide, target.card)
      removeMonsterAnywhere(state, target.card.instanceId)
      log(state, `Man-Eater Bug zerstört ${cardDb.byId(target.card.cardId)?.name}.`)
    }
  }
}

export function activateTimeWizard(state: DuelState, side: Side, card: DuelCard): void {
  const success = Math.random() < 0.5
  if (success) {
    destroyAllMonsters(state, 'player')
    destroyAllMonsters(state, 'cpu')
    log(state, 'Time Wizard: Erfolg! Alle Monster auf dem Feld werden zerstört.')
  } else {
    const found = findMonsterAnywhere(state, card.instanceId)
    if (found) {
      sendToGraveyard(state, side, found.slot.card)
      removeMonsterAnywhere(state, card.instanceId)
    }
    getPlayer(state, side).lifePoints = Math.max(0, getPlayer(state, side).lifePoints - 1000)
    log(state, 'Time Wizard: Fehlschlag! Time Wizard wird zerstört, 1000 Schaden.')
  }
}

export function getSpellTargets(state: DuelState, side: Side, cardName: string): string[] {
  const kind = targetKindForCard(cardName)
  if (kind === 'graveyard-monster') {
    return [...state.player.graveyard, ...state.cpu.graveyard]
      .filter((c) => cardDb.byId(c.cardId)?.category === 'Monster')
      .map((c) => c.instanceId)
  }
  if (kind === 'spelltrap') {
    const all = [...state.player.spellTrapZones, ...state.cpu.spellTrapZones].filter((z) => z !== null)
    return all.map((z) => z!.card.instanceId)
  }
  if (kind === 'face-up-monster') {
    const main = [...state.player.monsterZones, ...state.cpu.monsterZones].filter((z) => z !== null && !z.faceDown)
    const extra = state.extraMonsterZones.filter((z) => z !== null && !z.monster.faceDown).map((z) => z!.monster)
    return [...main.map((z) => z!.card.instanceId), ...extra.map((m) => m.card.instanceId)]
  }
  if (kind === 'hand-level8') {
    const p = getPlayer(state, side)
    return p.hand.filter((c) => (cardDb.byId(c.cardId)?.level ?? 0) === 8).map((c) => c.instanceId)
  }
  return []
}

export { uid }
