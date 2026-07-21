import type { Deck } from '../data/types'
import { buildMainDeckIds, type CpuPreset } from './cpuDecks'
import type { DuelCard, DuelState, PlayerState, Side } from './types'

function uid(): string {
  return Math.random().toString(36).slice(2) + Date.now().toString(36)
}

function shuffle<T>(arr: T[]): T[] {
  const a = [...arr]
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[a[i], a[j]] = [a[j], a[i]]
  }
  return a
}

function toDuelCards(cardIds: number[]): DuelCard[] {
  return cardIds.map((cardId) => ({ instanceId: uid(), cardId, turnPlaced: 0 }))
}

function makePlayerState(side: Side, mainIds: number[], extraIds: number[]): PlayerState {
  const deck = shuffle(toDuelCards(mainIds))
  const hand = deck.splice(0, 5)
  return {
    side,
    lifePoints: 8000,
    deck,
    hand,
    extraDeck: toDuelCards(extraIds),
    graveyard: [],
    banished: [],
    monsterZones: [null, null, null, null, null],
    spellTrapZones: [null, null, null, null, null],
    fieldSpell: null,
    normalSummonUsed: false,
    swordsOfRevealingLightTurns: 0,
  }
}

export function createDuelState(playerDeck: Deck, cpuPreset: CpuPreset, playerGoesFirst: boolean): DuelState {
  const player = makePlayerState('player', playerDeck.main, playerDeck.extra)
  const cpu = makePlayerState('cpu', buildMainDeckIds(cpuPreset), cpuPreset.extra)

  return {
    turn: 1,
    activePlayer: playerGoesFirst ? 'player' : 'cpu',
    phase: 'Draw',
    player,
    cpu,
    extraMonsterZones: [null, null],
    log: [`${playerGoesFirst ? 'Du beginnst' : `${cpuPreset.name} beginnt`}.`],
    chain: [],
    winner: null,
    winReason: null,
    pendingAttacker: null,
    pendingTarget: null,
    damageNegated: false,
    battleResolved: false,
    pendingPriority: null,
  }
}
