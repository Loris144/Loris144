import { NavLink, Outlet } from 'react-router-dom'
import { useGameStore } from '../store/useGameStore'

const TABS = [
  { to: '/shop', label: 'Shop', icon: '🛒' },
  { to: '/boosters', label: 'Packs', icon: '📦' },
  { to: '/binder', label: 'Binder', icon: '📘' },
  { to: '/deck', label: 'Deck', icon: '🗂️' },
  { to: '/duel', label: 'Duell', icon: '⚔️' },
]

export function AppShell() {
  const dp = useGameStore((s) => s.duelPoints)

  return (
    <div className="mx-auto flex h-full max-w-md flex-col bg-duel-dark">
      <header className="flex shrink-0 items-center justify-between border-b border-neutral-800 bg-duel-panel px-4 py-3">
        <div className="text-sm font-bold tracking-wide text-duel-gold">DUEL VAULT</div>
        <div className="flex items-center gap-1 rounded-full bg-neutral-800 px-3 py-1 text-xs font-semibold text-amber-300">
          <span>💰</span>
          <span>{dp.toLocaleString('de-DE')} DP</span>
        </div>
      </header>

      <main className="flex-1 overflow-y-auto pb-2">
        <Outlet />
      </main>

      <nav className="grid shrink-0 grid-cols-5 border-t border-neutral-800 bg-duel-panel">
        {TABS.map((tab) => (
          <NavLink
            key={tab.to}
            to={tab.to}
            className={({ isActive }) =>
              `flex flex-col items-center gap-0.5 py-2 text-[10px] font-medium ${
                isActive ? 'text-duel-gold' : 'text-neutral-400'
              }`
            }
          >
            <span className="text-lg leading-none">{tab.icon}</span>
            {tab.label}
          </NavLink>
        ))}
      </nav>
    </div>
  )
}
