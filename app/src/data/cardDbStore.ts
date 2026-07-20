import { create } from 'zustand'

interface CardDbState {
  status: 'idle' | 'loading' | 'ready' | 'error'
  /** Bumped every time cardDb.merge() runs, so components can subscribe to trigger a re-render. */
  version: number
  markLoading: () => void
  markUpdated: () => void
  markError: () => void
}

export const useCardDbStore = create<CardDbState>((set) => ({
  status: 'idle',
  version: 0,
  markLoading: () => set({ status: 'loading' }),
  markUpdated: () => set((s) => ({ status: 'ready', version: s.version + 1 })),
  markError: () => set({ status: 'error' }),
}))
