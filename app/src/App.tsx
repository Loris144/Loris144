import { useEffect } from 'react'
import { Navigate, Route, HashRouter, Routes } from 'react-router-dom'
import { AppShell } from './components/AppShell'
import { GbaFilterDefs } from './components/GbaFilterDefs'
import { MyShopScreen } from './screens/MyShopScreen'
import { BoosterScreen } from './screens/BoosterScreen'
import { BinderScreen } from './screens/BinderScreen'
import { DeckBuilderScreen } from './screens/DeckBuilderScreen'
import { DuelScreen } from './screens/DuelScreen'
import { loadLiveCardData } from './data/liveCardLoader'

function App() {
  useEffect(() => {
    loadLiveCardData()
  }, [])

  return (
    <HashRouter>
      <GbaFilterDefs />
      <Routes>
        <Route element={<AppShell />}>
          <Route index element={<Navigate to="/shop" replace />} />
          <Route path="/shop" element={<MyShopScreen />} />
          <Route path="/boosters" element={<BoosterScreen />} />
          <Route path="/binder" element={<BinderScreen />} />
          <Route path="/deck" element={<DeckBuilderScreen />} />
          <Route path="/duel" element={<DuelScreen />} />
        </Route>
      </Routes>
    </HashRouter>
  )
}

export default App
