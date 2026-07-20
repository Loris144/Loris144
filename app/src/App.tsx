import { Navigate, Route, HashRouter, Routes } from 'react-router-dom'
import { AppShell } from './components/AppShell'
import { ShopScreen } from './screens/ShopScreen'
import { BoosterScreen } from './screens/BoosterScreen'
import { BinderScreen } from './screens/BinderScreen'
import { DeckBuilderScreen } from './screens/DeckBuilderScreen'
import { DuelScreen } from './screens/DuelScreen'

function App() {
  return (
    <HashRouter>
      <Routes>
        <Route element={<AppShell />}>
          <Route index element={<Navigate to="/shop" replace />} />
          <Route path="/shop" element={<ShopScreen />} />
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
