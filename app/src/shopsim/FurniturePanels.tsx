import { useState } from 'react'
import { boosterSets } from '../data/boosters'
import { cardDb } from '../data/cardDb'
import { furnitureDefs, type FurnitureType } from '../data/furniture'
import { CardFace } from '../components/CardFace'
import { useGameStore } from '../store/useGameStore'
import type { PlacedFurniture } from './types'

function Sheet({ children, onClose }: { children: React.ReactNode; onClose: () => void }) {
  return (
    <div className="fixed inset-0 z-30 flex items-end justify-center bg-black/70" onClick={onClose}>
      <div className="w-full max-w-md rounded-t-xl bg-duel-panel p-4" onClick={(e) => e.stopPropagation()}>
        {children}
      </div>
    </div>
  )
}

export function BuildMenu({ x, y, onClose }: { x: number; y: number; onClose: () => void }) {
  const dp = useGameStore((s) => s.duelPoints)
  const buildFurniture = useGameStore((s) => s.buildFurniture)
  const options: FurnitureType[] = ['shelf', 'case', 'table']

  return (
    <Sheet onClose={onClose}>
      <div className="mb-3 text-sm font-semibold text-neutral-200">Möbel bauen</div>
      <div className="flex flex-col gap-2">
        {options.map((type) => {
          const def = furnitureDefs[type]
          return (
            <button
              key={type}
              disabled={dp < def.cost}
              onClick={() => {
                if (buildFurniture(type, x, y)) onClose()
              }}
              className="flex items-center justify-between rounded bg-neutral-800 px-3 py-2 text-left disabled:opacity-40"
            >
              <span className="text-xs font-semibold text-neutral-100">{def.name}</span>
              <span className="text-xs text-duel-gold">{def.cost} DP</span>
            </button>
          )
        })}
      </div>
    </Sheet>
  )
}

export function ShelfPanel({ furniture, onClose }: { furniture: PlacedFurniture; onClose: () => void }) {
  const assignShelfSet = useGameStore((s) => s.assignShelfSet)
  const setShelfPrice = useGameStore((s) => s.setShelfPrice)
  const restockShelf = useGameStore((s) => s.restockShelf)
  const removeFurniture = useGameStore((s) => s.removeFurniture)
  const warehouseBoxes = useGameStore((s) => s.warehouseBoxes)
  const [priceInput, setPriceInput] = useState(String(furniture.pricePerPack ?? 0))

  const capacityPacks = furnitureDefs.shelf.capacity * 12
  const assignedSet = boosterSets.find((b) => b.id === furniture.assignedSetId)
  const boxesAvailable = furniture.assignedSetId ? (warehouseBoxes[furniture.assignedSetId] ?? 0) : 0

  return (
    <Sheet onClose={onClose}>
      <div className="mb-3 text-sm font-semibold text-neutral-200">Booster-Regal</div>

      {!furniture.assignedSetId || furniture.stockedPacks === 0 ? (
        <div className="mb-3">
          <div className="mb-1 text-xs text-neutral-400">Set zuweisen</div>
          <div className="flex flex-wrap gap-1.5">
            {boosterSets.map((b) => (
              <button key={b.id} onClick={() => assignShelfSet(furniture.id, b.id)} className={`rounded px-2 py-1 text-[11px] ${furniture.assignedSetId === b.id ? 'bg-duel-gold text-black' : 'bg-neutral-800 text-neutral-300'}`}>
                {b.name}
              </button>
            ))}
          </div>
        </div>
      ) : (
        <div className="mb-3 text-xs text-neutral-300">Sortiment: {assignedSet?.name}</div>
      )}

      <div className="mb-3 text-xs text-neutral-400">
        Bestand: {furniture.stockedPacks ?? 0} / {capacityPacks} Packs
      </div>

      <button
        onClick={() => restockShelf(furniture.id)}
        disabled={!furniture.assignedSetId || boxesAvailable <= 0 || (furniture.stockedPacks ?? 0) + 12 > capacityPacks}
        className="mb-3 w-full rounded bg-duel-blue py-2 text-xs font-semibold text-white disabled:opacity-40"
      >
        Box nachfüllen ({boxesAvailable} im Lager)
      </button>

      <div className="mb-3 flex items-center gap-2">
        <input
          type="number"
          value={priceInput}
          onChange={(e) => setPriceInput(e.target.value)}
          className="w-24 rounded bg-neutral-900 px-2 py-1 text-xs text-neutral-100"
        />
        <button onClick={() => setShelfPrice(furniture.id, Number(priceInput) || 0)} className="rounded bg-neutral-700 px-3 py-1.5 text-xs font-semibold text-white">
          Preis/Pack setzen
        </button>
      </div>

      <button
        onClick={() => {
          removeFurniture(furniture.id)
          onClose()
        }}
        className="w-full rounded bg-rose-800 py-2 text-xs font-semibold text-white"
      >
        Regal entfernen (50% Rückerstattung)
      </button>
    </Sheet>
  )
}

export function CasePanel({ furniture, onClose }: { furniture: PlacedFurniture; onClose: () => void }) {
  const ownedCards = useGameStore((s) => s.ownedCards)
  const stockCase = useGameStore((s) => s.stockCase)
  const unstockCase = useGameStore((s) => s.unstockCase)
  const setCasePrice = useGameStore((s) => s.setCasePrice)
  const removeFurniture = useGameStore((s) => s.removeFurniture)
  const [pickerOpen, setPickerOpen] = useState(false)

  const slots = furniture.caseSlots ?? []
  const capacity = furnitureDefs.case.capacity

  return (
    <Sheet onClose={onClose}>
      <div className="mb-3 text-sm font-semibold text-neutral-200">
        Vitrine ({slots.length}/{capacity})
      </div>

      <div className="mb-3 grid grid-cols-3 gap-2">
        {slots.map((slot, i) => {
          const card = cardDb.byId(slot.cardId)
          if (!card) return null
          return (
            <div key={slot.instanceId} className="flex flex-col gap-1">
              <CardFace card={card} />
              <input
                type="number"
                defaultValue={slot.price}
                onBlur={(e) => setCasePrice(furniture.id, i, Number(e.target.value) || 0)}
                className="w-full rounded bg-neutral-900 px-1 py-0.5 text-[10px] text-neutral-100"
              />
              <button onClick={() => unstockCase(furniture.id, i)} className="rounded bg-neutral-700 py-0.5 text-[10px] text-white">
                Zurück in Binder
              </button>
            </div>
          )
        })}
      </div>

      <button
        onClick={() => setPickerOpen(true)}
        disabled={slots.length >= capacity}
        className="mb-3 w-full rounded bg-duel-blue py-2 text-xs font-semibold text-white disabled:opacity-40"
      >
        Karte einlagern
      </button>

      <button
        onClick={() => {
          removeFurniture(furniture.id)
          onClose()
        }}
        className="w-full rounded bg-rose-800 py-2 text-xs font-semibold text-white"
      >
        Vitrine entfernen (50% Rückerstattung)
      </button>

      {pickerOpen && (
        <Sheet onClose={() => setPickerOpen(false)}>
          <div className="mb-2 text-xs font-semibold text-neutral-300">Karte aus dem Binder wählen</div>
          <div className="grid max-h-80 grid-cols-4 gap-1.5 overflow-y-auto">
            {ownedCards.map((oc) => {
              const card = cardDb.byId(oc.cardId)
              if (!card) return null
              return (
                <button
                  key={oc.instanceId}
                  onClick={() => {
                    stockCase(furniture.id, oc.instanceId, card.price)
                    setPickerOpen(false)
                  }}
                >
                  <CardFace card={card} />
                </button>
              )
            })}
            {ownedCards.length === 0 && <div className="col-span-4 text-xs text-neutral-500">Dein Binder ist leer.</div>}
          </div>
        </Sheet>
      )}
    </Sheet>
  )
}

export function TablePanel({ furniture, onClose }: { furniture: PlacedFurniture; onClose: () => void }) {
  const removeFurniture = useGameStore((s) => s.removeFurniture)
  return (
    <Sheet onClose={onClose}>
      <div className="mb-3 text-sm font-semibold text-neutral-200">Duelltisch</div>
      <p className="mb-3 text-xs text-neutral-400">Kunden setzen sich hierhin, um gegeneinander zu duellieren. Für jedes Duell fällt eine kleine Tischgebühr an, die du an der Kasse kassierst.</p>
      <button
        onClick={() => {
          removeFurniture(furniture.id)
          onClose()
        }}
        className="w-full rounded bg-rose-800 py-2 text-xs font-semibold text-white"
      >
        Tisch entfernen (50% Rückerstattung)
      </button>
    </Sheet>
  )
}
