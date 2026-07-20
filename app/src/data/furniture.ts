export type FurnitureType = 'shelf' | 'case' | 'table' | 'counter'

export interface FurnitureDef {
  type: FurnitureType
  name: string
  cost: number
  footprintW: number
  footprintH: number
  capacity: number
  color: string
}

export const furnitureDefs: Record<FurnitureType, FurnitureDef> = {
  shelf: {
    type: 'shelf',
    name: 'Booster-Regal',
    cost: 400,
    footprintW: 1,
    footprintH: 1,
    capacity: 4, // boxes
    color: '#8a5a2b',
  },
  case: {
    type: 'case',
    name: 'Vitrine',
    cost: 500,
    footprintW: 1,
    footprintH: 1,
    capacity: 6, // single cards
    color: '#3fa0c9',
  },
  table: {
    type: 'table',
    name: 'Duelltisch',
    cost: 300,
    footprintW: 2,
    footprintH: 1,
    capacity: 2, // seats
    color: '#4a3f2a',
  },
  counter: {
    type: 'counter',
    name: 'Kasse',
    cost: 0,
    footprintW: 2,
    footprintH: 1,
    capacity: 1,
    color: '#c9a13f',
  },
}

export const GRID_W = 7
export const GRID_H = 6
export const DOOR_CELL = { x: 3, y: 0 }
export const COUNTER_CELL = { x: 2, y: 5 }
export const TABLE_FEE = 20
