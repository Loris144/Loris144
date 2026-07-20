import type { FurnitureType } from '../data/furniture'

export interface CaseSlot {
  instanceId: string
  cardId: number
  price: number
}

export interface PlacedFurniture {
  id: string
  type: FurnitureType
  x: number
  y: number
  // shelf-only
  assignedSetId?: string
  stockedPacks?: number
  pricePerPack?: number
  // case-only
  caseSlots?: CaseSlot[]
}

export type CustomerGoal =
  | { kind: 'buyPack'; furnitureId: string; price: number }
  | { kind: 'buyCard'; furnitureId: string; slotIndex: number; instanceId: string; price: number }
  | { kind: 'duel'; tableId: string }
  | { kind: 'browse' }

export type CustomerState = 'entering' | 'walkingToGoal' | 'busy' | 'walkingToCheckout' | 'queuing' | 'leaving'

export interface Customer {
  id: string
  x: number
  y: number
  targetX: number
  targetY: number
  color: string
  state: CustomerState
  goal: CustomerGoal
  busyUntil: number
  pendingPayment: number
  pendingLabel: string
}
