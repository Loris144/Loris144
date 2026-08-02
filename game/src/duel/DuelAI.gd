class_name DuelAI
extends RefCounted
## Opponent logic. Plays a solid, readable game: develop the board, use
## removal on real threats, attack when it profits, hold traps for defence.
## `skill` (1..5, mirroring the deck tiers) tunes how well it evaluates.

var engine
var player := 1
var skill := 3
## When true the AI plays with no animation delays (headless simulation).
var instant := false


func _init(e, p: int = 1, s: int = 3) -> void:
	engine = e
	player = p
	skill = s


func st() -> DuelState:
	return engine.st


func me() -> DuelSide:
	return st().players[player]


func foe() -> DuelSide:
	return st().players[1 - player]


func eng_name(id: int) -> String:
	return str(CardDB.get_card(id).get("name", ""))


# =====================================================================
# main phase
# =====================================================================

func take_turn() -> void:
	if st().is_over():
		return
	await _pause(0.35)
	await _main_phase()
	if st().is_over():
		return
	# battle
	if engine.can_enter_battle(player):
		engine.go_to_phase(DuelState.Phase.BATTLE)
		await _pause(0.3)
		await _battle_phase()
	if st().is_over():
		return
	engine.go_to_phase(DuelState.Phase.MAIN2)
	await _pause(0.2)
	await _main_phase()
	if st().is_over():
		return
	await _pause(0.25)
	engine.end_turn()


func _pause(secs: float) -> void:
	if instant:
		return          # headless simulation: no waiting at all
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var t := 1.0 if int(Game.settings.get("duel_speed", 1)) == 0 else 0.55
	await tree.create_timer(secs * t).timeout


func _main_phase() -> void:
	# 1) removal / draw spells that are clearly good right now
	for c in me().hand.duplicate():
		if st().is_over():
			return
		if not CardDB.is_spell(c.id):
			continue
		if not engine.can_activate(player, c, true):
			continue
		if _spell_is_useful(c):
			engine.activate_spell(player, c, true)
			await _pause(0.4)

	# 2) fusion, if the board allows it
	var fus: Array = engine.available_fusions(player)
	if not fus.is_empty():
		var best = fus[0]
		for f in fus:
			if CardDB.atk(f.id) > CardDB.atk(best.id):
				best = f
		engine.fusion_summon(player, best)
		await _pause(0.5)

	# 3) summon the best monster we can
	if me().normal_summons_left > 0:
		var pick = _best_summon()
		if pick != null:
			var need: int = engine.tributes_needed(pick.id)
			var defensive := _should_set(pick)
			if defensive and need == 0:
				engine.normal_summon(player, pick, true, [], true)
			else:
				engine.normal_summon(player, pick, false, [], false)
			await _pause(0.45)

	# 4) flip defenders into attack once they out-muscle the opposition
	var biggest := 0
	for m in foe().all_monsters():
		biggest = maxi(biggest, m.atk())
	for m in me().all_monsters():
		if m.face_up and m.defense and not m.position_changed \
				and not m.summoned_this_turn and m.atk() > biggest:
			engine.change_position(player, m)

	# 5) set spells/traps we are holding
	for c in me().hand.duplicate():
		if me().free_szone() < 0:
			break
		var cat := str(CardDB.get_card(c.id).get("cat", ""))
		if cat == "trap" or (cat == "spell" and CardDB.kind(c.id) == "quick"):
			engine.set_spell(player, c)
			await _pause(0.25)


func _spell_is_useful(c: DuelCard) -> bool:
	var n := eng_name(c.id)
	var foe_monsters := foe().all_monsters().size()
	var my_monsters := me().all_monsters().size()
	match n:
		"Pot of Greed", "Graceful Charity", "Card of Sanctity", "Jar of Greed":
			return true
		"Raigeki", "Dark Hole":
			return foe_monsters >= maxi(1, my_monsters)
		"Harpie's Feather Duster", "Heavy Storm":
			var cnt := 0
			for s in foe().spells:
				if s != null: cnt += 1
			return cnt >= 2
		"Monster Reborn", "Premature Burial", "Call of the Haunted":
			for g in me().grave:
				if CardDB.is_monster(g.id) and CardDB.atk(g.id) >= 1800:
					return true
			return false
		"Fissure", "Smashing Ground", "Tribute to The Doomed":
			return foe_monsters > 0
		"Mystical Space Typhoon", "De-Spell":
			for s in foe().spells:
				if s != null: return true
			return false
		"Change of Heart", "Brain Control", "Snatch Steal":
			return foe_monsters > 0
		"Swords of Revealing Light":
			return foe_monsters > my_monsters
		"Polymerization", "Red-Eyes Fusion":
			return not engine.available_fusions(player).is_empty()
		"Scapegoat":
			return my_monsters == 0 and foe_monsters >= 2
	# equips / pumps only when we have something to put them on
	if CardDB.kind(c.id) == "equip":
		return my_monsters > 0
	if CardDB.kind(c.id) == "field":
		return true
	# unknown normal spells: play them, they are usually beneficial
	return CardDB.kind(c.id) == "normal" and skill >= 2


func _best_summon():
	var best = null
	var best_score := -99999
	for c in me().hand:
		if not CardDB.is_monster(c.id):
			continue
		if not engine.can_normal_summon(player, c):
			continue
		var need: int = engine.tributes_needed(c.id)
		var score: int = CardDB.atk(c.id)
		# tributing costs board presence
		score -= need * 900
		if need > 0 and me().all_monsters().size() <= need:
			continue
		if CardDB.text(c.id) != "" and skill >= 3:
			score += 150
		if score > best_score:
			best_score = score
			best = c
	return best


func _should_set(c: DuelCard) -> bool:
	# Only hide genuinely weak monsters. Anything that can trade or push
	# damage belongs face-up in attack position, otherwise the board stalls.
	var biggest := 0
	for m in foe().all_monsters():
		biggest = maxi(biggest, m.atk())
	var a := CardDB.atk(c.id)
	var d := CardDB.def(c.id)
	if a >= biggest:
		return false                      # can win a fight — attack with it
	if d > a and d >= biggest:
		return true                       # a real wall
	return a < 1200 and d > a


# =====================================================================
# battle phase
# =====================================================================

func _battle_phase() -> void:
	if not engine.scripts.can_attack_check(player):
		return          # Swords of Revealing Light
	var guard := 0
	while guard < 10:
		guard += 1
		if st().is_over():
			return
		var attackers := me().attackers()
		if attackers.is_empty():
			return
		# attack with the weakest monster that still has a good target first,
		# so the big beater is kept free for whatever survives
		var acted := false
		attackers.sort_custom(func(x, y): return x.atk() > y.atk())
		for attacker in attackers:
			var plan := _pick_target(attacker)
			if not bool(plan.get("attack", false)):
				continue
			await engine.declare_attack(player, attacker, plan.get("target"))
			await _pause(0.55)
			acted = true
			break
		if not acted:
			return


## Decide what this monster should attack.
## Returns {"attack": bool, "target": DuelCard or null}; a null target with
## attack=true means a direct attack.
func _pick_target(attacker: DuelCard) -> Dictionary:
	var enemies := foe().all_monsters()
	if enemies.is_empty():
		return {"attack": true, "target": null}     # direct attack
	var atk := attacker.atk()
	var best = null
	var best_gain := -99999
	for m in enemies:
		var gain := 0
		if not m.face_up:
			# unknown; assume roughly average and value the information
			gain = 200 if atk >= 1700 else -400
		elif m.defense:
			if atk > m.def_():
				gain = 300
			else:
				gain = -600
		else:
			if atk > m.atk():
				gain = (atk - m.atk()) + 400
			elif atk == m.atk():
				gain = -300
			else:
				gain = -(m.atk() - atk) - 500
		if gain > best_gain:
			best_gain = gain
			best = m
	# A stalled board loses on time, so accept an even trade once the duel
	# drags on, and always take a trade when we are behind on life points.
	var threshold := 0
	if st().turn > 16 or me().lp < foe().lp:
		threshold = -400
	if st().turn > 30:
		threshold = -900
	if best_gain <= threshold and skill >= 2:
		return {"attack": false, "target": null}
	return {"attack": true, "target": best}
