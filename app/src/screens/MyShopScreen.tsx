import { useEffect, useRef, useState } from 'react'
import { ShopScene } from '../shopsim/ShopScene'
import { MarketPanel } from '../shopsim/MarketPanel'
import { BuildMenu, CasePanel, ShelfPanel, TablePanel } from '../shopsim/FurniturePanels'
import { advanceSimulation, checkoutCustomer, trySpawnCustomer } from '../shopsim/simulation'
import { useGameStore } from '../store/useGameStore'
import type { Customer, PlacedFurniture } from '../shopsim/types'

const TICK_INTERVAL = 1 / 12 // simulate at 12Hz; smooth enough, gentle on React re-renders

export function MyShopScreen() {
  const shopLayout = useGameStore((s) => s.shopLayout)
  const shopOpen = useGameStore((s) => s.shopOpen)
  const toggleShopOpen = useGameStore((s) => s.toggleShopOpen)

  const [customers, setCustomers] = useState<Customer[]>([])
  const [selectedCell, setSelectedCell] = useState<{ x: number; y: number } | null>(null)
  const [selectedFurniture, setSelectedFurniture] = useState<PlacedFurniture | null>(null)
  const [marketOpen, setMarketOpen] = useState(false)

  const customersRef = useRef<Customer[]>([])
  useEffect(() => {
    customersRef.current = customers
  }, [customers])

  const lastTsRef = useRef<number | null>(null)
  const accumulatorRef = useRef(0)
  const nextSpawnRef = useRef(2)
  const rafRef = useRef<number>(0)

  useEffect(() => {
    function frame(ts: number) {
      const nowSec = ts / 1000
      if (lastTsRef.current === null) lastTsRef.current = nowSec
      const frameDt = Math.min(0.25, nowSec - lastTsRef.current)
      lastTsRef.current = nowSec
      accumulatorRef.current += frameDt

      if (accumulatorRef.current >= TICK_INTERVAL) {
        const dt = accumulatorRef.current
        accumulatorRef.current = 0

        // All side effects (ref mutation, store mutation, RNG) happen here, OUTSIDE the
        // setState updater below — React (StrictMode) may invoke that updater twice with
        // the same input, so it must be a pure function of `prev`.
        let newCustomer: Customer | null = null
        if (nowSec >= nextSpawnRef.current) {
          const state = useGameStore.getState()
          newCustomer = trySpawnCustomer(state.shopLayout, customersRef.current, state.shopOpen, {
            sellPackFromShelf: state.sellPackFromShelf,
            sellCardFromCase: state.sellCardFromCase,
          })
          nextSpawnRef.current = nowSec + 3 + Math.random() * 4
        }

        setCustomers((prev) => {
          const list = advanceSimulation(prev, nowSec, dt)
          return newCustomer ? [...list, newCustomer] : list
        })
      }

      rafRef.current = requestAnimationFrame(frame)
    }
    rafRef.current = requestAnimationFrame(frame)
    return () => cancelAnimationFrame(rafRef.current)
  }, [])

  // keep selectedFurniture in sync with live store updates (e.g. after restock/price change)
  useEffect(() => {
    if (!selectedFurniture) return
    const fresh = shopLayout.find((f) => f.id === selectedFurniture.id)
    if (fresh) setSelectedFurniture(fresh)
    else setSelectedFurniture(null)
  }, [shopLayout, selectedFurniture])

  function handleCheckout(customerId: string, amount: number) {
    useGameStore.getState().collectRevenue(amount)
    setCustomers((prev) => checkoutCustomer(prev, customerId))
  }

  const queuing = customers.filter((c) => c.state === 'queuing')

  return (
    <div className="relative flex h-full flex-col">
      <div className="flex items-center justify-between gap-2 px-3 py-2">
        <button onClick={() => setMarketOpen(true)} className="rounded bg-duel-blue px-3 py-1.5 text-xs font-semibold text-white">
          Großhandel
        </button>
        <button
          onClick={toggleShopOpen}
          className={`rounded px-3 py-1.5 text-xs font-semibold ${shopOpen ? 'bg-emerald-700 text-white' : 'bg-neutral-700 text-neutral-300'}`}
        >
          {shopOpen ? 'Laden geöffnet' : 'Laden geschlossen'}
        </button>
      </div>

      <div className="relative flex-1">
        <ShopScene
          layout={shopLayout}
          customers={customers}
          onSelectCell={(x, y) => setSelectedCell({ x, y })}
          onSelectFurniture={(f) => (f.type !== 'counter' ? setSelectedFurniture(f) : setSelectedCell(null))}
        />

        {queuing.length > 0 && (
          <div className="absolute bottom-2 left-2 right-2 rounded-lg bg-black/80 p-2">
            <div className="mb-1 text-[11px] font-semibold text-duel-gold">Kasse · {queuing.length} wartend</div>
            <div className="flex flex-col gap-1">
              {queuing.map((c) => (
                <button
                  key={c.id}
                  onClick={() => handleCheckout(c.id, c.pendingPayment)}
                  className="flex items-center justify-between rounded bg-neutral-800 px-2 py-1.5 text-[11px] text-neutral-200"
                >
                  <span>{c.pendingLabel || 'Einkauf'}</span>
                  <span className="font-bold text-emerald-400">Kassieren · {c.pendingPayment} DP</span>
                </button>
              ))}
            </div>
          </div>
        )}
      </div>

      {selectedCell && !selectedFurniture && (
        <BuildMenu x={selectedCell.x} y={selectedCell.y} onClose={() => setSelectedCell(null)} />
      )}

      {selectedFurniture?.type === 'shelf' && <ShelfPanel furniture={selectedFurniture} onClose={() => setSelectedFurniture(null)} />}
      {selectedFurniture?.type === 'case' && <CasePanel furniture={selectedFurniture} onClose={() => setSelectedFurniture(null)} />}
      {selectedFurniture?.type === 'table' && <TablePanel furniture={selectedFurniture} onClose={() => setSelectedFurniture(null)} />}

      {marketOpen && <MarketPanel onClose={() => setMarketOpen(false)} />}
    </div>
  )
}
