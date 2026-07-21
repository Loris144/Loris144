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

/** The 2 Extra Monster Zones from the real Master Rule 5 sit between the two players' fields —
 * shared, not owned by either side. Only Fusion/Synchro/Xyz/Link monsters may occupy one (there
 * are no Link Monsters in this card pool yet to unlock using a Main Monster Zone instead). */
export interface ExtraZoneSlot {
  controller: Side
  monster: MonsterSlot
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
  /** The 2 shared Extra Monster Zones (Master Rule 5). */
  extraMonsterZones: (ExtraZoneSlot | null)[]
  log: string[]
  chain: ChainLink[]
  winner: Side | 'draw' | null
  winReason: string | null
  pendingAttacker: string | null // instanceId of monster that declared attack, awaiting response
  pendingTarget: string | 'direct' | null
  damageNegated: boolean
  battleResolved: boolean
  /** A general priority window: after a Normal Summon or Spell activation resolves, the
   * non-active player gets one chance to respond with a Quick-Play Spell or Set Trap before
   * play continues (a simplified but rules-faithful stand-in for full Spell Speed priority,
   * sized to this card pool's actual needs rather than a full arbitrary-depth chain engine). */
  pendingPriority: { side: Side; reason: 'normal-summon' | 'spell-activation'; contextInstanceId?: string } | null
}
