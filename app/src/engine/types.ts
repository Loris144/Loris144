export type Phase = 'Draw' | 'Standby' | 'Main1' | 'Battle' | 'Main2' | 'End'
export type Position = 'Attack' | 'Defense'
export type Side = 'player' | 'cpu'

export interface DuelCard {
  instanceId: string
  cardId: number
  /** turn number this card entered its current field position, for summoning-sickness / just-set traps */
  turnPlaced: number
}

export interface MonsterSlot {
  card: DuelCard
  position: Position
  faceDown: boolean
  hasAttacked: boolean
  summonedThisTurn: boolean
  equips: DuelCard[]
  spellCounters: number
}

export interface SpellTrapSlot {
  card: DuelCard
  faceDown: boolean
}

export interface PlayerState {
  side: Side
  lifePoints: number
  deck: DuelCard[]
  hand: DuelCard[]
  extraDeck: DuelCard[]
  graveyard: DuelCard[]
  banished: DuelCard[]
  monsterZones: (MonsterSlot | null)[]
  spellTrapZones: (SpellTrapSlot | null)[]
  fieldSpell: SpellTrapSlot | null
  normalSummonUsed: boolean
  swordsOfRevealingLightTurns: number
}

export type ChainLink =
  | { kind: 'spell'; card: DuelCard; controller: Side }
  | { kind: 'trap'; card: DuelCard; controller: Side }
  | { kind: 'monster-effect'; card: DuelCard; controller: Side }

export interface DuelState {
  turn: number
  activePlayer: Side
  phase: Phase
  player: PlayerState
  cpu: PlayerState
  log: string[]
  chain: ChainLink[]
  winner: Side | 'draw' | null
  winReason: string | null
  pendingAttacker: string | null // instanceId of monster that declared attack, awaiting response
  pendingTarget: string | 'direct' | null
  damageNegated: boolean
  battleResolved: boolean
}
