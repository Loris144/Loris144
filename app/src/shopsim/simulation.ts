import { boosterSets } from '../data/boosters'
import { COUNTER_CELL, DOOR_CELL, TABLE_FEE } from '../data/furniture'
import type { PlacedFurniture } from './types'
import type { Customer, CustomerGoal } from './types'

const SPEED = 1.8 // cells per second
const ARRIVE_EPSILON = 0.08
const BROWSE_DURATION = [1.2, 2.4] as const
const DUEL_DURATION = [3.5, 5.5] as const
const DUEL_WAIT_TIMEOUT = 14
const CUSTOMER_COLORS = ['#e0a458', '#4f9d69', '#c1495f', '#5a7fb0', '#9b6bb0', '#d6c24a']

function uid(): string {
  return Math.random().toString(36).slice(2) + Date.now().toString(36)
}

function rand(range: readonly [number, number]): number {
  return range[0] + Math.random() * (range[1] - range[0])
}

export interface SimActions {
  sellPackFromShelf: (furnitureId: string) => number | null
  sellCardFromCase: (furnitureId: string, slotIndex: number) => number | null
}

function pickGoal(layout: PlacedFurniture[], customers: Customer[], actions: SimActions): CustomerGoal | null {
  const options: { weight: number; make: () => CustomerGoal | null }[] = []

  for (const f of layout) {
    if (f.type === 'shelf' && (f.stockedPacks ?? 0) > 0 && (f.pricePerPack ?? 0) > 0) {
      options.push({
        weight: 4,
        make: () => {
          const price = actions.sellPackFromShelf(f.id)
          return price === null ? null : { kind: 'buyPack', furnitureId: f.id, price }
        },
      })
    }
    if (f.type === 'case' && f.caseSlots && f.caseSlots.length > 0) {
      options.push({
        weight: 3,
        make: () => {
          const idx = Math.floor(Math.random() * f.caseSlots!.length)
          const slot = f.caseSlots![idx]
          const price = actions.sellCardFromCase(f.id, idx)
          return price === null ? null : { kind: 'buyCard', furnitureId: f.id, slotIndex: idx, instanceId: slot.instanceId, price }
        },
      })
    }
    if (f.type === 'table') {
      const occupants = customers.filter((c) => c.goal.kind === 'duel' && c.goal.tableId === f.id && c.state !== 'leaving')
      if (occupants.length < 2) {
        options.push({ weight: 2, make: () => ({ kind: 'duel', tableId: f.id }) })
      }
    }
  }

  options.push({ weight: 1.5, make: () => ({ kind: 'browse' }) })

  const total = options.reduce((s, o) => s + o.weight, 0)
  let roll = Math.random() * total
  for (const opt of options) {
    if (roll < opt.weight) return opt.make()
    roll -= opt.weight
  }
  return null
}

function targetForFurniture(f: PlacedFurniture): { x: number; y: number } {
  return { x: f.x + 0.5, y: f.y + 0.5 }
}

export function trySpawnCustomer(layout: PlacedFurniture[], customers: Customer[], shopOpen: boolean, actions: SimActions): Customer | null {
  if (!shopOpen) return null
  if (customers.length >= 6) return null
  const goal = pickGoal(layout, customers, actions)
  if (!goal) return null

  let target = { x: DOOR_CELL.x + 0.5, y: DOOR_CELL.y + 1.5 }
  if (goal.kind === 'buyPack' || goal.kind === 'buyCard') {
    const f = layout.find((x) => x.id === goal.furnitureId)
    if (f) target = targetForFurniture(f)
  } else if (goal.kind === 'duel') {
    const f = layout.find((x) => x.id === goal.tableId)
    if (f) target = targetForFurniture(f)
  } else {
    target = { x: 1 + Math.random() * 4, y: 2 + Math.random() * 2 }
  }

  return {
    id: uid(),
    x: DOOR_CELL.x + 0.5,
    y: DOOR_CELL.y + 0.5,
    targetX: target.x,
    targetY: target.y,
    color: CUSTOMER_COLORS[Math.floor(Math.random() * CUSTOMER_COLORS.length)],
    state: 'walkingToGoal',
    goal,
    busyUntil: 0,
    pendingPayment: 0,
    pendingLabel: '',
  }
}

function moveToward(c: Customer, dt: number): boolean {
  const dx = c.targetX - c.x
  const dy = c.targetY - c.y
  const dist = Math.hypot(dx, dy)
  if (dist < ARRIVE_EPSILON) return true
  const step = Math.min(dist, SPEED * dt)
  c.x += (dx / dist) * step
  c.y += (dy / dist) * step
  return false
}

export function advanceSimulation(customers: Customer[], now: number, dt: number): Customer[] {
  const next = customers.map((c) => ({ ...c }))
  const toRemove = new Set<string>()

  for (const c of next) {
    switch (c.state) {
      case 'walkingToGoal': {
        if (moveToward(c, dt)) {
          if (c.goal.kind === 'duel') {
            const partner = next.find(
              (o) => o.id !== c.id && o.goal.kind === 'duel' && o.goal.tableId === (c.goal as { tableId: string }).tableId && o.state === 'busy',
            )
            if (partner) {
              const duration = rand(DUEL_DURATION)
              c.busyUntil = now + duration
              partner.busyUntil = now + duration
              c.pendingPayment = Math.round(TABLE_FEE / 2)
              partner.pendingPayment = Math.round(TABLE_FEE / 2)
              c.pendingLabel = 'Duell-Tischgebühr'
              partner.pendingLabel = 'Duell-Tischgebühr'
              c.state = 'busy'
            } else {
              c.busyUntil = now + DUEL_WAIT_TIMEOUT
              c.state = 'busy'
            }
          } else {
            c.busyUntil = now + rand(BROWSE_DURATION)
            c.state = 'busy'
          }
        }
        break
      }
      case 'busy': {
        if (now >= c.busyUntil) {
          if (c.goal.kind === 'duel' && c.pendingPayment === 0) {
            // timed out waiting for a partner
            c.state = 'leaving'
            c.targetX = DOOR_CELL.x + 0.5
            c.targetY = DOOR_CELL.y + 0.5
          } else if (c.goal.kind === 'browse') {
            c.state = 'leaving'
            c.targetX = DOOR_CELL.x + 0.5
            c.targetY = DOOR_CELL.y + 0.5
          } else {
            if (c.goal.kind === 'buyPack' || c.goal.kind === 'buyCard') {
              c.pendingPayment = c.goal.price
              c.pendingLabel = c.goal.kind === 'buyPack' ? 'Booster-Pack' : 'Einzelkarte'
            }
            c.state = 'walkingToCheckout'
            c.targetX = COUNTER_CELL.x + 0.5
            c.targetY = COUNTER_CELL.y + 0.5
          }
        }
        break
      }
      case 'walkingToCheckout': {
        if (moveToward(c, dt)) c.state = 'queuing'
        break
      }
      case 'queuing':
        break
      case 'leaving': {
        if (moveToward(c, dt)) toRemove.add(c.id)
        break
      }
      default:
        break
    }
  }

  return next.filter((c) => !toRemove.has(c.id))
}

export function getSuggestedShelfPrice(boosterId: string): number {
  return boosterSets.find((b) => b.id === boosterId)?.price ?? 100
}

/** Player tapped "Kassieren" for a queuing customer: sends them toward the door and clears their bill. */
export function checkoutCustomer(customers: Customer[], customerId: string): Customer[] {
  return customers.map((c) =>
    c.id === customerId && c.state === 'queuing'
      ? { ...c, state: 'leaving' as const, pendingPayment: 0, targetX: DOOR_CELL.x + 0.5, targetY: DOOR_CELL.y + 0.5 }
      : c,
  )
}
