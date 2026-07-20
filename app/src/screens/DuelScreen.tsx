import { useEffect, useMemo, useState } from 'react'
import { cardDb } from '../data/cardDb'
import { CardFace } from '../components/CardFace'
import { cpuPresets, type CpuPreset } from '../engine/cpuDecks'
import {
  cpuDeclareNextAttack,
  cpuHasMoreAttacks,
  cpuRespondToAttack,
  cpuRunMainPhase,
} from '../engine/cpuAi'
import { createDuelState } from '../engine/deckSetup'
import {
  activateSetSpell,
  activateSpellFromHand,
  activateTrapResponse,
  advancePhase,
  changePosition,
  declareAttack,
  discardKuriboh,
  normalSummon,
  passResponse,
  setSpellTrap,
} from '../engine/duelEngine'
import { validateDeck } from '../engine/deckRules'
import { getSpellTargets, isScriptedTrap, targetKindForCard } from '../engine/effects'
import { tributesNeeded } from '../engine/helpers'
import { useGameStore } from '../store/useGameStore'
import type { DuelCard, DuelState, MonsterSlot, SpellTrapSlot } from '../engine/types'
import type { CardDef } from '../data/types'

const PHASE_LABEL: Record<string, string> = {
  Draw: 'Zug-Phase', Standby: 'Standby', Main1: 'Hauptphase 1', Battle: 'Kampfphase', Main2: 'Hauptphase 2', End: 'End-Phase',
}

function CardBack() {
  return <div className="flex aspect-[59/86] w-full items-center justify-center rounded-md bg-gradient-to-br from-indigo-900 to-neutral-900 text-lg shadow">🂠</div>
}

export function DuelScreen() {
  const decks = useGameStore((s) => s.decks)
  const recordDuelResult = useGameStore((s) => s.recordDuelResult)

  const [opponent, setOpponent] = useState<CpuPreset>(cpuPresets[0])
  const [chosenDeckId, setChosenDeckId] = useState<string>(decks[0]?.id ?? '')
  const [duel, setDuel] = useState<DuelState | null>(null)
  const [selectedHandCard, setSelectedHandCard] = useState<DuelCard | null>(null)
  const [selectedFieldCard, setSelectedFieldCard] = useState<string | null>(null)
  const [tributeMode, setTributeMode] = useState<{ card: DuelCard; needed: number; chosen: string[] } | null>(null)
  const [pendingTargetPick, setPendingTargetPick] = useState<{ cardName: string; resolve: (target?: string) => void } | null>(null)
  const [attackPickMode, setAttackPickMode] = useState<string | null>(null)
  const [infoCard, setInfoCard] = useState<CardDef | null>(null)
  const [zoneView, setZoneView] = useState<{ title: string; cards: DuelCard[] } | null>(null)

  const deck = decks.find((d) => d.id === chosenDeckId)
  const validation = deck ? validateDeck(deck) : null

  // Master auto-advance loop.
  useEffect(() => {
    if (!duel || duel.winner) return
    const timer = setTimeout(() => {
      setDuel((prev) => {
        if (!prev || prev.winner) return prev

        if (prev.phase === 'Draw' || prev.phase === 'Standby') {
          return advancePhase(prev)
        }

        if (prev.activePlayer === 'cpu') {
          if (prev.pendingAttacker && !prev.battleResolved) return prev // waits for player's response UI
          if (prev.phase === 'Main1') return advancePhase(cpuRunMainPhase(prev))
          if (prev.phase === 'Battle') {
            if (cpuHasMoreAttacks(prev)) return cpuDeclareNextAttack(prev)
            return advancePhase(prev)
          }
          if (prev.phase === 'Main2' || prev.phase === 'End') return advancePhase(prev)
        }

        if (prev.activePlayer === 'player') {
          if (prev.pendingAttacker && !prev.battleResolved) {
            const responded = cpuRespondToAttack(prev)
            return passResponse(responded)
          }
        }
        return prev
      })
    }, 700)
    return () => clearTimeout(timer)
  }, [duel])

  useEffect(() => {
    if (duel?.winner) {
      recordDuelResult(duel.winner === 'player')
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [duel?.winner])

  const eligibleResponseTraps = useMemo(() => {
    if (!duel || duel.activePlayer !== 'cpu' || !duel.pendingAttacker || duel.battleResolved) return []
    return duel.player.spellTrapZones.filter(
      (z): z is SpellTrapSlot => z !== null && z.card.turnPlaced !== duel.turn && isScriptedTrap(cardDb.byId(z.card.cardId)?.name ?? ''),
    )
  }, [duel])

  if (!duel) {
    return (
      <div className="px-3 py-4">
        <h2 className="mb-3 text-sm font-semibold text-neutral-300">Duell vorbereiten</h2>

        <div className="mb-4">
          <div className="mb-1 text-xs text-neutral-400">Gegner</div>
          <div className="flex gap-2">
            {cpuPresets.map((p) => (
              <button
                key={p.id}
                onClick={() => setOpponent(p)}
                className={`flex-1 rounded-lg py-3 text-xs font-semibold ${opponent.id === p.id ? 'bg-duel-blue text-white' : 'bg-neutral-800 text-neutral-300'}`}
              >
                {p.name}
              </button>
            ))}
          </div>
        </div>

        <div className="mb-4">
          <div className="mb-1 text-xs text-neutral-400">Dein Deck</div>
          {decks.length === 0 && <p className="text-sm text-neutral-500">Baue zuerst ein Deck im Deckbuilder.</p>}
          <div className="flex flex-col gap-2">
            {decks.map((d) => (
              <button
                key={d.id}
                onClick={() => setChosenDeckId(d.id)}
                className={`rounded px-3 py-2 text-left text-sm ${chosenDeckId === d.id ? 'bg-duel-blue text-white' : 'bg-neutral-800 text-neutral-300'}`}
              >
                {d.name} ({d.main.length}/{d.extra.length})
              </button>
            ))}
          </div>
        </div>

        {deck && validation && !validation.valid && (
          <div className="mb-3 rounded bg-rose-950/50 p-2 text-[11px] text-rose-300">{validation.issues.join(' · ')}</div>
        )}

        <button
          disabled={!deck || !validation?.valid}
          onClick={() => deck && setDuel(createDuelState(deck, opponent, Math.random() < 0.5))}
          className="w-full rounded bg-duel-gold py-3 text-sm font-bold text-black disabled:opacity-40"
        >
          Duell starten
        </button>
      </div>
    )
  }

  if (duel.winner) {
    return (
      <div className="flex flex-col items-center justify-center px-6 py-16 text-center">
        <div className="mb-2 text-2xl font-bold text-duel-gold">{duel.winner === 'player' ? 'Sieg!' : 'Niederlage'}</div>
        <div className="mb-6 text-sm text-neutral-400">{duel.winReason}</div>
        <button onClick={() => setDuel(null)} className="rounded bg-duel-blue px-6 py-2 text-sm font-semibold text-white">
          Zurück
        </button>
      </div>
    )
  }

  const isPlayerTurn = duel.activePlayer === 'player'
  const respondingToCpuAttack = duel.activePlayer === 'cpu' && !!duel.pendingAttacker && !duel.battleResolved

  function requestTarget(cardName: string): Promise<string | undefined> {
    const kind = targetKindForCard(cardName)
    if (kind === 'none') return Promise.resolve(undefined)
    return new Promise((resolve) => setPendingTargetPick({ cardName, resolve }))
  }

  async function handleActivateFromHand(card: DuelCard) {
    setSelectedHandCard(null)
    const def = cardDb.byId(card.cardId)!
    const target = await requestTarget(def.name)
    setDuel((prev) => (prev ? activateSpellFromHand(prev, 'player', card.instanceId, target) : prev))
  }

  function handleSetSpellTrap(card: DuelCard) {
    setSelectedHandCard(null)
    setDuel((prev) => (prev ? setSpellTrap(prev, 'player', card.instanceId) : prev))
  }

  function handleNormalSummon(card: DuelCard, position: 'Attack' | 'Defense') {
    const def = cardDb.byId(card.cardId)!
    const needed = tributesNeeded(def.level)
    setSelectedHandCard(null)
    if (needed > 0) {
      setTributeMode({ card, needed, chosen: [] })
      return
    }
    setDuel((prev) => (prev ? normalSummon(prev, 'player', card.instanceId, position, position === 'Defense', []) : prev))
  }

  function confirmTributeSummon(position: 'Attack' | 'Defense') {
    if (!tributeMode) return
    const { card, chosen, needed } = tributeMode
    if (chosen.length !== needed) return
    setDuel((prev) => (prev ? normalSummon(prev, 'player', card.instanceId, position, position === 'Defense', chosen) : prev))
    setTributeMode(null)
  }

  function handleFieldMonsterTap(instanceId: string) {
    if (!duel) return
    if (duel.phase === 'Battle' && isPlayerTurn) {
      const slot = duel.player.monsterZones.find((z) => z?.card.instanceId === instanceId)
      if (slot && !slot.hasAttacked && !slot.summonedThisTurn && slot.position === 'Attack') {
        setAttackPickMode(instanceId)
        return
      }
    }
    setSelectedFieldCard(instanceId)
  }

  async function handleActivateSetSpell(zoneInstanceId: string, cardName: string) {
    setSelectedFieldCard(null)
    const target = await requestTarget(cardName)
    setDuel((prev) => (prev ? activateSetSpell(prev, 'player', zoneInstanceId, target) : prev))
  }

  function declarePlayerAttack(target: string | 'direct') {
    if (!attackPickMode) return
    setDuel((prev) => (prev ? declareAttack(prev, attackPickMode, target) : prev))
    setAttackPickMode(null)
  }

  function respondWithTrap(zoneInstanceId: string) {
    setDuel((prev) => (prev ? activateTrapResponse(prev, 'player', zoneInstanceId) : prev))
  }

  function respondWithKuriboh(handInstanceId: string) {
    setDuel((prev) => (prev ? discardKuriboh(prev, 'player', handInstanceId) : prev))
  }

  function passTheResponse() {
    setDuel((prev) => (prev ? passResponse(prev) : prev))
  }

  return (
    <div className="flex flex-col gap-1.5 px-1.5 py-1.5">
      <PlayerBar name={opponent.name} state={duel.cpu} />
      <PlayerMat
        playerState={duel.cpu}
        onTapMonster={(id) => setInfoCard(cardOf(duel, id))}
        onTapSpellTrap={(id, faceDown) => !faceDown && setInfoCard(cardOf(duel, id))}
        onInfo={(id) => setInfoCard(cardOf(duel, id))}
        onGraveyard={() => setZoneView({ title: `${opponent.name} · Friedhof`, cards: duel.cpu.graveyard })}
        onExtraDeck={undefined}
        hideFaceDown
      />

      <div className="flex items-center justify-between rounded bg-duel-panel px-2 py-1 text-[11px] text-neutral-300">
        <span>Runde {duel.turn} · {isPlayerTurn ? 'Du' : opponent.name} · {PHASE_LABEL[duel.phase]}</span>
        {isPlayerTurn && !respondingToCpuAttack && (
          <button onClick={() => setDuel((prev) => (prev ? advancePhase(prev) : prev))} className="rounded bg-duel-blue px-2 py-1 text-[11px] font-semibold text-white">
            Nächste Phase
          </button>
        )}
      </div>

      <PlayerMat
        playerState={duel.player}
        onTapMonster={handleFieldMonsterTap}
        onTapSpellTrap={(id, faceDown) => (faceDown ? setSelectedFieldCard(id) : undefined)}
        onInfo={(id) => setSelectedFieldCard(id)}
        onGraveyard={() => setZoneView({ title: 'Dein Friedhof', cards: duel.player.graveyard })}
        onExtraDeck={() => setZoneView({ title: 'Dein Extra Deck', cards: duel.player.extraDeck })}
      />
      <PlayerBar name="Du" state={duel.player} />

      <div className="max-h-16 overflow-y-auto rounded bg-black/30 px-2 py-1 text-[10px] text-neutral-400">
        {duel.log.slice(-6).map((l, i) => <div key={i}>{l}</div>)}
      </div>

      <div className="flex gap-1.5 overflow-x-auto pb-1">
        {duel.player.hand.map((card) => (
          <button
            key={card.instanceId}
            onClick={() => setSelectedHandCard(card)}
            disabled={!isPlayerTurn || duel.phase !== 'Main1' && duel.phase !== 'Main2'}
            className="w-16 shrink-0 disabled:opacity-60"
          >
            <CardFace card={cardDb.byId(card.cardId)!} />
          </button>
        ))}
      </div>

      {/* Hand card action sheet */}
      {selectedHandCard && (
        <Sheet onClose={() => setSelectedHandCard(null)}>
          <CardDetail card={cardDb.byId(selectedHandCard.cardId)!} />
          <div className="mt-3 flex flex-col gap-2">
            {cardDb.byId(selectedHandCard.cardId)!.category === 'Monster' ? (
              <>
                <button onClick={() => handleNormalSummon(selectedHandCard, 'Attack')} disabled={duel.player.normalSummonUsed} className="rounded bg-duel-blue py-2 text-xs font-semibold text-white disabled:opacity-40">Beschwören (Angriff)</button>
                <button onClick={() => handleNormalSummon(selectedHandCard, 'Defense')} disabled={duel.player.normalSummonUsed} className="rounded bg-neutral-700 py-2 text-xs font-semibold text-white disabled:opacity-40">Verdeckt setzen (Verteidigung)</button>
              </>
            ) : (
              <>
                <button onClick={() => handleActivateFromHand(selectedHandCard)} className="rounded bg-duel-blue py-2 text-xs font-semibold text-white">Aktivieren</button>
                <button onClick={() => handleSetSpellTrap(selectedHandCard)} className="rounded bg-neutral-700 py-2 text-xs font-semibold text-white">Verdeckt legen</button>
              </>
            )}
          </div>
        </Sheet>
      )}

      {/* Tribute picker */}
      {tributeMode && (
        <Sheet onClose={() => setTributeMode(null)}>
          <div className="mb-2 text-xs text-neutral-300">Wähle {tributeMode.needed} Tribut-Monster ({tributeMode.chosen.length}/{tributeMode.needed})</div>
          <div className="grid grid-cols-4 gap-1.5">
            {duel.player.monsterZones.filter((z): z is MonsterSlot => z !== null).map((slot) => {
              const chosen = tributeMode.chosen.includes(slot.card.instanceId)
              return (
                <button
                  key={slot.card.instanceId}
                  onClick={() =>
                    setTributeMode((prev) => {
                      if (!prev) return prev
                      const already = prev.chosen.includes(slot.card.instanceId)
                      const next = already ? prev.chosen.filter((id) => id !== slot.card.instanceId) : [...prev.chosen, slot.card.instanceId].slice(0, prev.needed)
                      return { ...prev, chosen: next }
                    })
                  }
                  className={`rounded ${chosen ? 'ring-2 ring-duel-gold' : ''}`}
                >
                  <CardFace card={cardDb.byId(slot.card.cardId)!} />
                </button>
              )
            })}
          </div>
          <div className="mt-3 flex gap-2">
            <button onClick={() => confirmTributeSummon('Attack')} disabled={tributeMode.chosen.length !== tributeMode.needed} className="flex-1 rounded bg-duel-blue py-2 text-xs font-semibold text-white disabled:opacity-40">Angriffsposition</button>
            <button onClick={() => confirmTributeSummon('Defense')} disabled={tributeMode.chosen.length !== tributeMode.needed} className="flex-1 rounded bg-neutral-700 py-2 text-xs font-semibold text-white disabled:opacity-40">Verteidigung</button>
          </div>
        </Sheet>
      )}

      {/* Target picker */}
      {pendingTargetPick && (
        <Sheet onClose={() => { pendingTargetPick.resolve(undefined); setPendingTargetPick(null) }}>
          <div className="mb-2 text-xs text-neutral-300">Ziel für {pendingTargetPick.cardName} wählen</div>
          <TargetGrid duel={duel} cardName={pendingTargetPick.cardName} onPick={(id) => { pendingTargetPick.resolve(id); setPendingTargetPick(null) }} />
        </Sheet>
      )}

      {/* Attack target picker */}
      {attackPickMode && (
        <Sheet onClose={() => setAttackPickMode(null)}>
          <div className="mb-2 text-xs text-neutral-300">Angriffsziel wählen</div>
          <div className="grid grid-cols-4 gap-1.5">
            {duel.cpu.monsterZones.filter((z): z is MonsterSlot => z !== null).map((slot) => (
              <button key={slot.card.instanceId} onClick={() => declarePlayerAttack(slot.card.instanceId)}>
                {slot.faceDown ? <CardBack /> : <CardFace card={cardDb.byId(slot.card.cardId)!} />}
              </button>
            ))}
          </div>
          <button onClick={() => declarePlayerAttack('direct')} className="mt-3 w-full rounded bg-duel-gold py-2 text-xs font-bold text-black">
            Direkter Angriff
          </button>
        </Sheet>
      )}

      {/* Field monster action sheet (position change etc.) */}
      {selectedFieldCard && !attackPickMode && (
        <FieldCardSheet
          duel={duel}
          instanceId={selectedFieldCard}
          onClose={() => setSelectedFieldCard(null)}
          onChangePosition={(id) => { setDuel((prev) => (prev ? changePosition(prev, 'player', id) : prev)); setSelectedFieldCard(null) }}
          onActivateSetSpell={handleActivateSetSpell}
        />
      )}

      {/* Read-only card info (used for opponent's field cards) */}
      {infoCard && (
        <Sheet onClose={() => setInfoCard(null)}>
          <CardDetail card={infoCard} />
        </Sheet>
      )}

      {/* Graveyard / Extra Deck browser */}
      {zoneView && (
        <Sheet onClose={() => setZoneView(null)}>
          <div className="mb-2 text-xs font-semibold text-neutral-300">
            {zoneView.title} ({zoneView.cards.length})
          </div>
          <div className="grid max-h-80 grid-cols-4 gap-1.5 overflow-y-auto">
            {zoneView.cards.map((c) => (
              <button key={c.instanceId} onClick={() => setInfoCard(cardDb.byId(c.cardId) ?? null)}>
                <CardFace card={cardDb.byId(c.cardId)!} />
              </button>
            ))}
            {zoneView.cards.length === 0 && <div className="col-span-4 text-xs text-neutral-500">Leer.</div>}
          </div>
        </Sheet>
      )}

      {/* Response window when CPU attacks */}
      {respondingToCpuAttack && (
        <Sheet onClose={() => {}} noClose>
          <div className="mb-2 text-xs font-semibold text-rose-300">{opponent.name} greift an! Reagieren?</div>
          <div className="flex flex-col gap-2">
            {eligibleResponseTraps.map((z) => (
              <button key={z.card.instanceId} onClick={() => respondWithTrap(z.card.instanceId)} className="rounded bg-duel-blue py-2 text-xs font-semibold text-white">
                {cardDb.byId(z.card.cardId)?.name} aktivieren
              </button>
            ))}
            {duel.player.hand.filter((c) => cardDb.byId(c.cardId)?.name === 'Kuriboh').map((c) => (
              <button key={c.instanceId} onClick={() => respondWithKuriboh(c.instanceId)} className="rounded bg-neutral-700 py-2 text-xs font-semibold text-white">
                Kuriboh abwerfen
              </button>
            ))}
            <button onClick={passTheResponse} className="rounded bg-neutral-800 py-2 text-xs font-semibold text-neutral-300">Passen</button>
          </div>
        </Sheet>
      )}
    </div>
  )
}

function PlayerBar({ name, state }: { name: string; state: DuelState['player'] }) {
  return (
    <div className="flex items-center justify-between rounded bg-duel-panel px-2 py-1 text-[11px]">
      <span className="font-semibold text-neutral-200">{name}</span>
      <span className="text-neutral-400">🃏 {state.hand.length} · 📚 {state.deck.length}</span>
      <span className="font-bold text-emerald-400">{state.lifePoints} LP</span>
    </div>
  )
}

function ZoneTile({ label, count, onTap, dashed }: { label: string; count?: number; onTap?: () => void; dashed?: boolean }) {
  const content = (
    <div
      className={`relative flex aspect-[59/86] w-full flex-col items-center justify-center rounded-md text-[7px] font-semibold text-neutral-400 ${
        dashed ? 'border border-dashed border-neutral-700' : 'border border-neutral-600 bg-neutral-800/70'
      }`}
    >
      <span className="leading-tight">{label}</span>
      {count !== undefined && <span className="mt-0.5 text-[9px] font-bold text-neutral-200">{count}</span>}
    </div>
  )
  return onTap ? (
    <button onClick={onTap} className="h-full w-full">
      {content}
    </button>
  ) : (
    content
  )
}

function PlayerMat({
  playerState,
  onTapMonster,
  onTapSpellTrap,
  onInfo,
  onGraveyard,
  onExtraDeck,
  hideFaceDown,
}: {
  playerState: DuelState['player']
  onTapMonster: (id: string) => void
  onTapSpellTrap?: (id: string, faceDown: boolean) => void
  onInfo?: (id: string) => void
  onGraveyard?: () => void
  onExtraDeck?: () => void
  hideFaceDown?: boolean
}) {
  const { spellTrapZones, monsterZones, graveyard, deck, extraDeck } = playerState
  return (
    <div className="flex flex-col gap-1">
      <div className="grid grid-cols-7 gap-1">
        <ZoneTile label="FELD" dashed />
        {spellTrapZones.map((slot, i) => (
          <div key={i} className="aspect-[59/86]">
            {slot ? (
              hideFaceDown && slot.faceDown ? (
                <CardBack />
              ) : (
                <button onClick={() => onTapSpellTrap?.(slot.card.instanceId, slot.faceDown)} className="h-full w-full">
                  {slot.faceDown ? (
                    <CardBack />
                  ) : (
                    <CardFace card={cardDb.byId(slot.card.cardId)!} variant="field" onInfo={() => onInfo?.(slot.card.instanceId)} />
                  )}
                </button>
              )
            ) : (
              <div className="h-full w-full rounded-md border border-dashed border-neutral-700" />
            )}
          </div>
        ))}
        <ZoneTile label="GRAB" count={graveyard.length} onTap={onGraveyard} />
      </div>
      <div className="grid grid-cols-7 gap-1">
        <ZoneTile label="EXTRA" count={extraDeck.length} onTap={onExtraDeck} />
        {monsterZones.map((slot, i) => (
          <div key={i} className="aspect-[59/86]">
            {slot ? (
              hideFaceDown && slot.faceDown ? (
                <CardBack />
              ) : (
                <button onClick={() => onTapMonster(slot.card.instanceId)} className={`relative h-full w-full ${slot.position === 'Defense' ? 'rotate-90' : ''}`}>
                  {slot.faceDown ? (
                    <CardBack />
                  ) : (
                    <CardFace card={cardDb.byId(slot.card.cardId)!} variant="field" onInfo={() => onInfo?.(slot.card.instanceId)} />
                  )}
                </button>
              )
            ) : (
              <div className="h-full w-full rounded-md border border-dashed border-neutral-700" />
            )}
          </div>
        ))}
        <ZoneTile label="DECK" count={deck.length} />
      </div>
    </div>
  )
}

function Sheet({ children, onClose, noClose }: { children: React.ReactNode; onClose: () => void; noClose?: boolean }) {
  return (
    <div className="fixed inset-0 z-30 flex items-end justify-center bg-black/70" onClick={noClose ? undefined : onClose}>
      <div className="w-full max-w-md rounded-t-xl bg-duel-panel p-4" onClick={(e) => e.stopPropagation()}>
        {children}
      </div>
    </div>
  )
}

function cardOf(duel: DuelState, instanceId: string): CardDef | null {
  for (const p of [duel.player, duel.cpu]) {
    const m = p.monsterZones.find((z) => z?.card.instanceId === instanceId)
    if (m) return cardDb.byId(m.card.cardId) ?? null
    const s = p.spellTrapZones.find((z) => z?.card.instanceId === instanceId)
    if (s) return cardDb.byId(s.card.cardId) ?? null
  }
  return null
}

function CardDetail({ card }: { card: ReturnType<typeof cardDb.byId> }) {
  if (!card) return null
  return (
    <div className="flex gap-3">
      <div className="w-28 shrink-0">
        <CardFace card={card} />
      </div>
      <div>
        <div className="text-sm font-bold text-neutral-100">{card.name}</div>
        <div className="text-[11px] text-neutral-400">{card.category} · {card.kind}</div>
        {card.category === 'Monster' && <div className="text-[11px] text-neutral-400">ATK {card.atk} / DEF {card.def} · Level {card.level}</div>}
        <div className="mt-1 text-[11px] text-neutral-300">{card.desc}</div>
      </div>
    </div>
  )
}

function TargetGrid({ duel, cardName, onPick }: { duel: DuelState; cardName: string; onPick: (id: string) => void }) {
  const ids = getSpellTargets(duel, 'player', cardName)
  const findCard = (id: string): DuelCard | undefined =>
    [...duel.player.graveyard, ...duel.cpu.graveyard, ...duel.player.monsterZones, ...duel.cpu.monsterZones, ...duel.player.spellTrapZones, ...duel.cpu.spellTrapZones]
      .filter((x): x is DuelCard | MonsterSlot | SpellTrapSlot => x !== null)
      .map((x) => ('card' in x ? x.card : x))
      .find((c) => c.instanceId === id)

  return (
    <div className="grid grid-cols-4 gap-1.5">
      {ids.map((id) => {
        const c = findCard(id)
        if (!c) return null
        return (
          <button key={id} onClick={() => onPick(id)}>
            <CardFace card={cardDb.byId(c.cardId)!} />
          </button>
        )
      })}
      {ids.length === 0 && <div className="col-span-4 text-xs text-neutral-500">Keine gültigen Ziele.</div>}
    </div>
  )
}

function FieldCardSheet({
  duel,
  instanceId,
  onClose,
  onChangePosition,
  onActivateSetSpell,
}: {
  duel: DuelState
  instanceId: string
  onClose: () => void
  onChangePosition: (id: string) => void
  onActivateSetSpell: (zoneInstanceId: string, cardName: string) => void
}) {
  const monsterSlot = duel.player.monsterZones.find((z) => z?.card.instanceId === instanceId)
  const spellSlot = duel.player.spellTrapZones.find((z) => z?.card.instanceId === instanceId)
  const cardDefM = monsterSlot ? cardDb.byId(monsterSlot.card.cardId) : null
  const cardDefS = spellSlot ? cardDb.byId(spellSlot.card.cardId) : null

  return (
    <Sheet onClose={onClose}>
      {cardDefM && (
        <>
          <CardDetail card={cardDefM} />
          <button
            onClick={() => onChangePosition(instanceId)}
            disabled={monsterSlot!.summonedThisTurn || monsterSlot!.hasAttacked}
            className="mt-3 w-full rounded bg-duel-blue py-2 text-xs font-semibold text-white disabled:opacity-40"
          >
            Position wechseln
          </button>
        </>
      )}
      {cardDefS && (
        <>
          <CardDetail card={cardDefS} />
          {cardDefS.category === 'Spell' && (
            <button onClick={() => onActivateSetSpell(instanceId, cardDefS.name)} className="mt-3 w-full rounded bg-duel-blue py-2 text-xs font-semibold text-white">
              Aktivieren
            </button>
          )}
          {cardDefS.category === 'Trap' && <div className="mt-3 text-[11px] text-neutral-500">Fallen werden im Reaktionsfenster während eines gegnerischen Angriffs aktiviert.</div>}
        </>
      )}
    </Sheet>
  )
}
