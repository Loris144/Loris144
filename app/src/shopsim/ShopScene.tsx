import { Canvas } from '@react-three/fiber'
import { OrbitControls, OrthographicCamera } from '@react-three/drei'
import { Suspense } from 'react'
import type { ReactElement } from 'react'
import { DOOR_CELL, GRID_H, GRID_W, furnitureDefs } from '../data/furniture'
import type { Customer, PlacedFurniture } from './types'

function toWorld(x: number, y: number): [number, number] {
  return [x - GRID_W / 2, y - GRID_H / 2]
}

const FLOOR_TILE_A = '#f8f6f0'
const FLOOR_TILE_B = '#e9e4d6'
const FLOOR_DOOR_MAT = '#d8c9a3'
const WALL_COLOR = '#ecdfbd'
const WALL_HEIGHT = 1.5
const WALL_THICKNESS = 0.15

function Floor({ onSelectCell }: { onSelectCell: (x: number, y: number) => void }) {
  const tiles = []
  for (let x = 0; x < GRID_W; x++) {
    for (let y = 0; y < GRID_H; y++) {
      const [wx, wz] = toWorld(x + 0.5, y + 0.5)
      const isDoor = x === DOOR_CELL.x && y === DOOR_CELL.y
      const alt = (x + y) % 2 === 0
      tiles.push(
        <mesh
          key={`${x}-${y}`}
          position={[wx, 0, wz]}
          rotation={[-Math.PI / 2, 0, 0]}
          onClick={(e) => {
            e.stopPropagation()
            onSelectCell(x, y)
          }}
        >
          <planeGeometry args={[0.96, 0.96]} />
          <meshStandardMaterial color={isDoor ? FLOOR_DOOR_MAT : alt ? FLOOR_TILE_A : FLOOR_TILE_B} />
        </mesh>,
      )
    }
  }
  return <group>{tiles}</group>
}

function Walls() {
  const segments: ReactElement[] = []

  for (let x = 0; x < GRID_W; x++) {
    if (x === DOOR_CELL.x) continue
    const [wx, wz] = toWorld(x + 0.5, 0)
    segments.push(
      <mesh key={`back-${x}`} position={[wx, WALL_HEIGHT / 2, wz - WALL_THICKNESS / 2]}>
        <boxGeometry args={[1, WALL_HEIGHT, WALL_THICKNESS]} />
        <meshStandardMaterial color={WALL_COLOR} />
      </mesh>,
    )
  }

  for (let y = 0; y < GRID_H; y++) {
    const [wx, wz] = toWorld(0, y + 0.5)
    segments.push(
      <mesh key={`left-${y}`} position={[wx - WALL_THICKNESS / 2, WALL_HEIGHT / 2, wz]}>
        <boxGeometry args={[WALL_THICKNESS, WALL_HEIGHT, 1]} />
        <meshStandardMaterial color={WALL_COLOR} />
      </mesh>,
    )
  }

  return <group>{segments}</group>
}

function ShelfMesh({ f }: { f: PlacedFurniture }) {
  const def = furnitureDefs.shelf
  const capacityPacks = def.capacity * 12
  const fillRatio = Math.min(1, (f.stockedPacks ?? 0) / capacityPacks)
  const boxCount = Math.round(fillRatio * 4)
  return (
    <group>
      <mesh position={[0, 0.5, 0]}>
        <boxGeometry args={[0.8, 1, 0.6]} />
        <meshStandardMaterial color="#c99a5f" />
      </mesh>
      <mesh position={[0, 0.72, 0.31]}>
        <boxGeometry args={[0.84, 0.04, 0.02]} />
        <meshStandardMaterial color="#a97c46" />
      </mesh>
      <mesh position={[0, 0.4, 0.31]}>
        <boxGeometry args={[0.84, 0.04, 0.02]} />
        <meshStandardMaterial color="#a97c46" />
      </mesh>
      {Array.from({ length: boxCount }).map((_, i) => (
        <mesh key={i} position={[-0.24 + (i % 2) * 0.48, 0.85 + Math.floor(i / 2) * 0.28, 0]}>
          <boxGeometry args={[0.36, 0.24, 0.4]} />
          <meshStandardMaterial color="#d9a441" />
        </mesh>
      ))}
    </group>
  )
}

function CaseMesh({ f }: { f: PlacedFurniture }) {
  const slots = f.caseSlots ?? []
  return (
    <group>
      <mesh position={[0, 0.4, 0]}>
        <boxGeometry args={[0.8, 0.8, 0.6]} />
        <meshStandardMaterial color="#bfe4f0" transparent opacity={0.35} />
      </mesh>
      <mesh position={[0, 0.05, 0]}>
        <boxGeometry args={[0.85, 0.1, 0.65]} />
        <meshStandardMaterial color="#3a3a3a" />
      </mesh>
      {slots.map((_, i) => {
        const col = i % 3
        const row = Math.floor(i / 3)
        return (
          <mesh key={i} position={[-0.24 + col * 0.24, 0.35 + row * 0.28, 0]}>
            <cylinderGeometry args={[0.06, 0.06, 0.18, 10]} />
            <meshStandardMaterial color="#e8c85a" />
          </mesh>
        )
      })}
    </group>
  )
}

function TableMesh() {
  return (
    <group>
      <mesh position={[0, 0.4, 0]}>
        <boxGeometry args={[1.6, 0.08, 0.8]} />
        <meshStandardMaterial color="#5a4630" />
      </mesh>
      <mesh position={[-0.65, 0.2, 0]}>
        <cylinderGeometry args={[0.15, 0.15, 0.4, 10]} />
        <meshStandardMaterial color="#2f2a22" />
      </mesh>
      <mesh position={[0.65, 0.2, 0]}>
        <cylinderGeometry args={[0.15, 0.15, 0.4, 10]} />
        <meshStandardMaterial color="#2f2a22" />
      </mesh>
    </group>
  )
}

function CounterMesh() {
  return (
    <group>
      <mesh position={[0, 0.45, 0]}>
        <boxGeometry args={[1.6, 0.9, 0.6]} />
        <meshStandardMaterial color="#caa23f" />
      </mesh>
      <mesh position={[0, 0.95, 0]}>
        <boxGeometry args={[0.35, 0.2, 0.3]} />
        <meshStandardMaterial color="#222222" />
      </mesh>
    </group>
  )
}

function FurniturePiece({ f, onSelect }: { f: PlacedFurniture; onSelect: (f: PlacedFurniture) => void }) {
  const def = furnitureDefs[f.type]
  const [wx, wz] = toWorld(f.x + def.footprintW / 2, f.y + def.footprintH / 2)
  return (
    <group
      position={[wx, 0, wz]}
      onClick={(e) => {
        e.stopPropagation()
        onSelect(f)
      }}
    >
      {f.type === 'shelf' && <ShelfMesh f={f} />}
      {f.type === 'case' && <CaseMesh f={f} />}
      {f.type === 'table' && <TableMesh />}
      {f.type === 'counter' && <CounterMesh />}
    </group>
  )
}

function CustomerMesh({ c }: { c: Customer }) {
  const [wx, wz] = toWorld(c.x, c.y)
  return (
    <group position={[wx, 0, wz]}>
      <mesh position={[0, 0.32, 0]}>
        <capsuleGeometry args={[0.16, 0.32, 4, 8]} />
        <meshStandardMaterial color={c.color} />
      </mesh>
      <mesh position={[0, 0.62, 0]}>
        <sphereGeometry args={[0.13, 10, 10]} />
        <meshStandardMaterial color="#f0d9b5" />
      </mesh>
      {c.state === 'queuing' && (
        <mesh position={[0, 0.95, 0]}>
          <sphereGeometry args={[0.06, 8, 8]} />
          <meshStandardMaterial color="#ffd23f" emissive="#ffd23f" emissiveIntensity={0.8} />
        </mesh>
      )}
    </group>
  )
}

export function ShopScene({
  layout,
  customers,
  onSelectCell,
  onSelectFurniture,
}: {
  layout: PlacedFurniture[]
  customers: Customer[]
  onSelectCell: (x: number, y: number) => void
  onSelectFurniture: (f: PlacedFurniture) => void
}) {
  const occupied = new Set(layout.flatMap((f) => {
    const def = furnitureDefs[f.type]
    const cells: string[] = []
    for (let dx = 0; dx < def.footprintW; dx++)
      for (let dy = 0; dy < def.footprintH; dy++) cells.push(`${f.x + dx}-${f.y + dy}`)
    return cells
  }))

  return (
    <Canvas shadows dpr={[1, 1.5]}>
      <Suspense fallback={null}>
        <OrthographicCamera makeDefault position={[8.5, 9.5, 8.5]} zoom={76} near={0.1} far={100} />
        <OrbitControls
          enablePan={false}
          enableZoom={true}
          minZoom={55}
          maxZoom={120}
          minPolarAngle={Math.PI / 4.2}
          maxPolarAngle={Math.PI / 2.6}
          target={[0, 0, 0.4]}
        />
        <ambientLight intensity={0.85} />
        <directionalLight position={[6, 10, 4]} intensity={0.9} />
        <Walls />
        <Floor
          onSelectCell={(x, y) => {
            if (!occupied.has(`${x}-${y}`)) onSelectCell(x, y)
          }}
        />
        {layout.map((f) => (
          <FurniturePiece key={f.id} f={f} onSelect={onSelectFurniture} />
        ))}
        {customers.map((c) => (
          <CustomerMesh key={c.id} c={c} />
        ))}
      </Suspense>
    </Canvas>
  )
}
