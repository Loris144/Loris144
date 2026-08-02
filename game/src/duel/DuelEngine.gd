class_name DuelEngine
extends RefCounted
## Rules engine for classic Duel Monsters: normal/tribute/set/flip summons,
## fusion and ritual summons, battle, spells and traps with a simplified
## chain, and win conditions.
##
## Deliberately excludes Synchro/Xyz/Link/Pendulum — the card pool for this
## game is the pre-2005 era and the decks never contain them.

signal event(kind: String, data: Dictionary)


var st: DuelState
var scripts                      # CardScripts instance
var rng := RandomNumberGenerator.new()

# a pending response window: the other player may answer with a trap
var pending: Dictionary = {}


func _init() -> void:
	st = DuelState.new()
	rng.randomize()
	scripts = load("res://src/duel/CardScripts.gd").new()
	scripts.engine = self


func emit(kind: String, data: Dictionary = {}) -> void:
	event.emit(kind, data)


# =====================================================================
# setup
# =====================================================================

func setup_duel(p0_main: Array, p0_extra: Array, p0_name: String, p0_sprite: String,
		p1_main: Array, p1_extra: Array, p1_name: String, p1_sprite: String,
		seed_value: int = 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	var a: DuelSide = st.players[0]
	var b: DuelSide = st.players[1]
	a.name = p0_name
	a.sprite = p0_sprite
	b.name = p1_name
	b.sprite = p1_sprite
	b.is_ai = true
	_fill(a, p0_main, p0_extra)
	_fill(b, p1_main, p1_extra)
	_shuffle(a)
	_shuffle(b)
	for i in DuelState.START_HAND:
		_draw_raw(0)
		_draw_raw(1)
	st.turn_player = 0
	st.phase = DuelState.Phase.MAIN1
	st.turn = 1
	st.first_turn = true
	a.normal_summons_left = 1
	st.add_log("Das Duell beginnt!")
	emit("duel_start", {})
	emit("phase", {"phase": st.phase})


func _fill(s: DuelSide, main: Array, extra: Array) -> void:
	s.deck.clear()
	s.extra.clear()
	for id in main:
		s.deck.append(DuelCard.new(int(id), st.new_uid()))
	for id in extra:
		s.extra.append(DuelCard.new(int(id), st.new_uid()))


func _shuffle(s: DuelSide) -> void:
	var n := s.deck.size()
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = s.deck[i]
		s.deck[i] = s.deck[j]
		s.deck[j] = tmp


# =====================================================================
# drawing
# =====================================================================

func _draw_raw(player: int) -> bool:
	var s: DuelSide = st.players[player]
	if s.deck.is_empty():
		return false
	var c = s.deck.pop_front()
	s.hand.append(c)
	return true


func draw_cards(player: int, n: int) -> void:
	var s: DuelSide = st.players[player]
	for i in n:
		if s.deck.is_empty():
			st.winner = 1 - player
			st.win_reason = "%s hat keine Karten mehr im Deck." % s.name
			emit("win", {"winner": st.winner, "reason": st.win_reason})
			return
		var c = s.deck.pop_front()
		s.hand.append(c)
		emit("draw", {"player": player, "uid": c.uid, "id": c.id})
	_check_exodia(player)


func _check_exodia(player: int) -> void:
	const PARTS := [33396948, 7902349, 44519536, 70903634, 8124921]
	var s: DuelSide = st.players[player]
	var have := {}
	for c in s.hand:
		have[c.id] = true
	for p in PARTS:
		if not have.has(p):
			return
	st.winner = player
	st.win_reason = "%s vereint Exodia!" % s.name
	emit("exodia", {"player": player})
	emit("win", {"winner": st.winner, "reason": st.win_reason})


# =====================================================================
# summoning
# =====================================================================

func tributes_needed(card_id: int) -> int:
	var lv := CardDB.level(card_id)
	if lv >= 7:
		return 2
	if lv >= 5:
		return 1
	return 0


func can_normal_summon(player: int, card: DuelCard) -> bool:
	var s: DuelSide = st.players[player]
	if s.normal_summons_left <= 0:
		return false
	if not CardDB.is_monster(card.id):
		return false
	if CardDB.is_extra_deck(card.id):
		return false
	if CardDB.kind(card.id) == "ritual":
		return false
	if st.phase != DuelState.Phase.MAIN1 and st.phase != DuelState.Phase.MAIN2:
		return false
	var need := tributes_needed(card.id)
	if s.free_mzone() < 0 and need == 0:
		return false
	return s.monster_count() >= need


## Summon a monster from hand. `tribute_uids` must match tributes_needed().
func normal_summon(player: int, card: DuelCard, defense: bool,
		tribute_uids: Array = [], face_down: bool = false) -> bool:
	var s: DuelSide = st.players[player]
	if not can_normal_summon(player, card):
		return false
	var need := tributes_needed(card.id)
	if tribute_uids.size() < need:
		# auto-pick the weakest monsters
		tribute_uids = _auto_tributes(s, need)
		if tribute_uids.size() < need:
			return false
	for uid in tribute_uids:
		var z := s.find_monster_zone(int(uid))
		if z >= 0:
			_send_to_grave(player, s.monsters[z], "tribute")
			s.monsters[z] = null
	var zone := s.free_mzone()
	if zone < 0:
		return false
	s.hand.erase(card)
	card.face_up = not face_down
	card.defense = defense or face_down
	card.summoned_this_turn = true
	card.attacked = false
	card.just_set = face_down
	s.monsters[zone] = card
	s.normal_summons_left -= 1
	st.add_log("%s beschwört %s." % [s.name, card.name() if not face_down else "eine Karte verdeckt"])
	emit("summon", {"player": player, "uid": card.uid, "id": card.id,
		"zone": zone, "face_down": face_down, "defense": card.defense,
		"tributes": tribute_uids})
	if not face_down:
		scripts.on_summon(player, card)
	return true


func _auto_tributes(s: DuelSide, need: int) -> Array:
	var ms := s.all_monsters()
	ms.sort_custom(func(a, b): return a.atk() < b.atk())
	var out: Array = []
	for i in mini(need, ms.size()):
		out.append(ms[i].uid)
	return out


func flip_summon(player: int, card: DuelCard) -> bool:
	var s: DuelSide = st.players[player]
	if card.face_up or card.summoned_this_turn or card.position_changed:
		return false
	if st.phase != DuelState.Phase.MAIN1 and st.phase != DuelState.Phase.MAIN2:
		return false
	card.face_up = true
	card.defense = false
	card.position_changed = true
	st.add_log("%s dreht %s offen." % [s.name, card.name()])
	emit("flip", {"player": player, "uid": card.uid, "id": card.id})
	scripts.on_flip(player, card)
	return true


func change_position(player: int, card: DuelCard) -> bool:
	if not card.face_up or card.summoned_this_turn or card.position_changed:
		return false
	if card.attacked:
		return false
	if st.phase != DuelState.Phase.MAIN1 and st.phase != DuelState.Phase.MAIN2:
		return false
	card.defense = not card.defense
	card.position_changed = true
	emit("position", {"player": player, "uid": card.uid, "defense": card.defense})
	return true


## Special summon from anywhere (used by effects, fusion, ritual).
func special_summon(player: int, card: DuelCard, defense: bool = false,
		face_down: bool = false, from: String = "extra") -> bool:
	var s: DuelSide = st.players[player]
	var zone := s.free_mzone()
	if zone < 0:
		return false
	match from:
		"extra": s.extra.erase(card)
		"hand": s.hand.erase(card)
		"grave": s.grave.erase(card)
		"deck": s.deck.erase(card)
		"banished": s.banished.erase(card)
	card.face_up = not face_down
	card.defense = defense
	card.summoned_this_turn = true
	card.attacked = false
	card.position_changed = false
	card.atk_mod = 0
	card.def_mod = 0
	s.monsters[zone] = card
	st.add_log("%s beschwört %s als Spezialbeschwörung." % [s.name, card.name()])
	emit("special_summon", {"player": player, "uid": card.uid, "id": card.id,
		"zone": zone, "defense": defense, "from": from})
	scripts.on_summon(player, card)
	return true


# ---- fusion -----------------------------------------------------------

## Which extra-deck fusions can be made right now from hand+field?
func available_fusions(player: int) -> Array:
	var s: DuelSide = st.players[player]
	var out: Array = []
	var has_poly := false
	for c in s.hand:
		if CardDB.card_name(c.id).findn("Polymerisation") >= 0 \
				or CardDB.get_card(c.id).get("name", "") == "Polymerization":
			has_poly = true
			break
	if not has_poly:
		return out
	for f in s.extra:
		if CardDB.kind(f.id) != "fusion":
			continue
		var mats: Array = scripts.fusion_materials(f.id)
		if mats.is_empty():
			continue
		if _has_materials(s, mats):
			out.append(f)
	return out


func _has_materials(s: DuelSide, mats: Array) -> bool:
	var pool: Array = []
	for c in s.hand:
		pool.append(c)
	for c in s.all_monsters():
		if c.face_up:
			pool.append(c)
	var used: Array = []
	for want in mats:
		var found = null
		for c in pool:
			if c in used:
				continue
			if _matches_material(c, want):
				found = c
				break
		if found == null:
			return false
		used.append(found)
	return true


func _matches_material(c: DuelCard, want) -> bool:
	if typeof(want) == TYPE_INT:
		return c.id == int(want)
	var w := str(want)
	if w.begins_with("race:"):
		return CardDB.race(c.id) == w.substr(5)
	if w.begins_with("attr:"):
		return CardDB.attribute(c.id) == w.substr(5)
	return CardDB.get_card(c.id).get("name", "") == w


func fusion_summon(player: int, fusion: DuelCard) -> bool:
	var s: DuelSide = st.players[player]
	var mats: Array = scripts.fusion_materials(fusion.id)
	if mats.is_empty() or not _has_materials(s, mats):
		return false
	# spend Polymerization
	for c in s.hand:
		if CardDB.get_card(c.id).get("name", "") == "Polymerization":
			s.hand.erase(c)
			_to_grave_pile(player, c)
			break
	# spend materials
	var pool: Array = []
	for c in s.hand:
		pool.append(["hand", c])
	for i in DuelState.MZONES:
		if s.monsters[i] != null and s.monsters[i].face_up:
			pool.append(["field", s.monsters[i]])
	var used: Array = []
	for want in mats:
		for entry in pool:
			var c: DuelCard = entry[1]
			if c in used:
				continue
			if _matches_material(c, want):
				used.append(c)
				if entry[0] == "hand":
					s.hand.erase(c)
				else:
					var z := s.find_monster_zone(c.uid)
					if z >= 0:
						s.monsters[z] = null
				_to_grave_pile(player, c)
				break
	emit("fusion", {"player": player, "id": fusion.id})
	return special_summon(player, fusion, false, false, "extra")


# ---- ritual -----------------------------------------------------------

func can_ritual(player: int, ritual_spell: DuelCard) -> Dictionary:
	var s: DuelSide = st.players[player]
	var target_id: int = scripts.ritual_target(ritual_spell.id)
	if target_id == 0:
		return {}
	var monster = null
	for c in s.hand:
		if c.id == target_id:
			monster = c
			break
	if monster == null:
		return {}
	var need := CardDB.level(target_id)
	# tribute from hand or field, levels must sum to >= need
	var pool: Array = []
	for c in s.all_monsters():
		pool.append(c)
	for c in s.hand:
		if c != monster and CardDB.is_monster(c.id):
			pool.append(c)
	pool.sort_custom(func(a, b): return a.level() > b.level())
	var sum := 0
	var chosen: Array = []
	for c in pool:
		if sum >= need:
			break
		sum += c.level()
		chosen.append(c)
	if sum < need:
		return {}
	return {"monster": monster, "tributes": chosen}


func ritual_summon(player: int, ritual_spell: DuelCard) -> bool:
	var plan := can_ritual(player, ritual_spell)
	if plan.is_empty():
		return false
	var s: DuelSide = st.players[player]
	for c in plan["tributes"]:
		var z := s.find_monster_zone(c.uid)
		if z >= 0:
			s.monsters[z] = null
		else:
			s.hand.erase(c)
		_to_grave_pile(player, c)
	var monster: DuelCard = plan["monster"]
	emit("ritual", {"player": player, "id": monster.id})
	return special_summon(player, monster, false, false, "hand")


# =====================================================================
# spells & traps
# =====================================================================

func can_activate(player: int, card: DuelCard, from_hand: bool) -> bool:
	var cat := str(CardDB.get_card(card.id).get("cat", ""))
	var kind := CardDB.kind(card.id)
	if cat == "spell":
		if from_hand:
			if kind == "quick":
				return true
			return st.turn_player == player and st.phase in [DuelState.Phase.MAIN1, DuelState.Phase.MAIN2]
		# face-down spell on the field
		if kind == "quick":
			return not card.just_set or st.turn_player != player
		return st.turn_player == player and st.phase in [DuelState.Phase.MAIN1, DuelState.Phase.MAIN2]
	if cat == "trap":
		if from_hand:
			return false
		return not card.just_set
	return false


func set_spell(player: int, card: DuelCard) -> bool:
	var s: DuelSide = st.players[player]
	var cat := str(CardDB.get_card(card.id).get("cat", ""))
	if cat not in ["spell", "trap"]:
		return false
	if CardDB.kind(card.id) == "field":
		return activate_spell(player, card, true)
	var zone := s.free_szone()
	if zone < 0:
		return false
	s.hand.erase(card)
	card.face_up = false
	card.just_set = true
	s.spells[zone] = card
	st.add_log("%s legt eine Karte verdeckt." % s.name)
	emit("set_spell", {"player": player, "uid": card.uid, "zone": zone})
	return true


func activate_spell(player: int, card: DuelCard, from_hand: bool) -> bool:
	var s: DuelSide = st.players[player]
	var kind := CardDB.kind(card.id)
	var cat := str(CardDB.get_card(card.id).get("cat", ""))

	if kind == "ritual":
		if not can_ritual(player, card).is_empty():
			if from_hand:
				s.hand.erase(card)
			else:
				var z0 := s.find_spell_zone(card.uid)
				if z0 >= 0:
					s.spells[z0] = null
			emit("activate", {"player": player, "uid": card.uid, "id": card.id})
			ritual_summon(player, card)
			_to_grave_pile(player, card)
			return true
		return false

	# put it in a zone so the UI can show it flipping up
	var zone := -1
	if from_hand:
		if kind == "field":
			if s.field_spell != null:
				_to_grave_pile(player, s.field_spell)
			s.hand.erase(card)
			card.face_up = true
			s.field_spell = card
		else:
			zone = s.free_szone()
			if zone < 0:
				return false
			s.hand.erase(card)
			card.face_up = true
			s.spells[zone] = card
	else:
		zone = s.find_spell_zone(card.uid)
		card.face_up = true

	st.add_log("%s aktiviert %s." % [s.name, card.name()])
	emit("activate", {"player": player, "uid": card.uid, "id": card.id, "zone": zone})

	var keep: bool = scripts.resolve(player, card)

	if st.is_over():
		return true
	# continuous / equip / field cards stay on the field
	if kind in ["continuous", "equip", "field"] or keep:
		if kind == "field":
			pass
		return true
	# everything else goes to the graveyard
	if kind != "field":
		var z := s.find_spell_zone(card.uid)
		if z >= 0:
			s.spells[z] = null
		_to_grave_pile(player, card)
	return true


func activate_trap(player: int, card: DuelCard, ctx: Dictionary = {}) -> bool:
	var s: DuelSide = st.players[player]
	if card.just_set:
		return false
	card.face_up = true
	st.add_log("%s aktiviert %s!" % [s.name, card.name()])
	emit("activate", {"player": player, "uid": card.uid, "id": card.id,
		"zone": s.find_spell_zone(card.uid)})
	var keep: bool = scripts.resolve(player, card, ctx)
	if CardDB.kind(card.id) != "continuous" and not keep:
		var z := s.find_spell_zone(card.uid)
		if z >= 0:
			s.spells[z] = null
		_to_grave_pile(player, card)
	return true


# =====================================================================
# battle
# =====================================================================

## May this player have a Battle Phase at all this turn?
## (Deliberately does NOT check the current phase, so callers can use it to
## decide whether to advance into the Battle Phase.)
func can_enter_battle(player: int) -> bool:
	if st.turn_player != player:
		return false
	if st.turn == 1 and st.first_turn:
		return false          # no battle on the very first turn
	if not scripts.can_attack_check(player):
		return false          # Swords of Revealing Light etc.
	return true


## Are we in the Battle Phase and allowed to attack right now?
func can_attack_now(player: int) -> bool:
	return st.phase == DuelState.Phase.BATTLE and can_enter_battle(player)


func legal_targets(attacker_player: int) -> Array:
	var d: DuelSide = st.players[1 - attacker_player]
	var out: Array = []
	for m in d.all_monsters():
		out.append(m)
	return out


func declare_attack(player: int, attacker: DuelCard, target) -> void:
	var atk_side: DuelSide = st.players[player]
	var def_side: DuelSide = st.players[1 - player]
	if attacker.attacked or attacker.defense or not attacker.face_up:
		return
	attacker.attacked = true
	emit("attack_declared", {"player": player, "uid": attacker.uid,
		"target_uid": target.uid if target != null else -1})

	# defender gets a chance to respond with a set trap
	await _response_window(1 - player, {"type": "attack",
		"attacker": attacker, "target": target})
	if st.is_over():
		return
	# the attacker may have been removed by that trap
	if atk_side.find_monster_zone(attacker.uid) < 0:
		emit("attack_cancelled", {})
		return
	if scripts.attack_negated:
		scripts.attack_negated = false
		emit("attack_cancelled", {})
		return

	if target == null:
		# direct attack
		var dmg := attacker.atk()
		_damage(1 - player, dmg, "battle")
		emit("direct_attack", {"player": player, "uid": attacker.uid, "damage": dmg})
		return

	if def_side.find_monster_zone(target.uid) < 0:
		emit("attack_cancelled", {})
		return

	_resolve_battle(player, attacker, target)


func _resolve_battle(player: int, a: DuelCard, d: DuelCard) -> void:
	var def_player := 1 - player
	var a_atk := a.atk()
	var was_face_down := not d.face_up
	if was_face_down:
		d.face_up = true
		emit("flip", {"player": def_player, "uid": d.uid, "id": d.id})
		scripts.on_flip(def_player, d)
		if st.is_over():
			return
		# the flip effect may have destroyed the attacker
		if st.players[player].find_monster_zone(a.uid) < 0:
			return

	var d_val := d.def_() if d.defense else d.atk()
	emit("battle", {"attacker": a.uid, "target": d.uid,
		"atk": a_atk, "def": d_val, "defending": d.defense})

	if d.defense:
		if a_atk > d_val:
			_destroy_monster(def_player, d, "battle")
			if scripts.has_piercing(a):
				_damage(def_player, a_atk - d_val, "battle")
		elif a_atk < d_val:
			_damage(player, d_val - a_atk, "battle")
		# equal: nothing happens
	else:
		if a_atk > d_val:
			_destroy_monster(def_player, d, "battle")
			_damage(def_player, a_atk - d_val, "battle")
		elif a_atk < d_val:
			_destroy_monster(player, a, "battle")
			_damage(player, d_val - a_atk, "battle")
		else:
			_destroy_monster(def_player, d, "battle")
			_destroy_monster(player, a, "battle")


func _damage(player: int, amount: int, _source: String) -> void:
	if amount <= 0:
		return
	var s: DuelSide = st.players[player]
	s.lp = maxi(0, s.lp - amount)
	st.add_log("%s erleidet %d Schaden." % [s.name, amount])
	emit("damage", {"player": player, "amount": amount, "lp": s.lp})
	_check_lp()


func heal(player: int, amount: int) -> void:
	var s: DuelSide = st.players[player]
	s.lp += amount
	emit("heal", {"player": player, "amount": amount, "lp": s.lp})


func _check_lp() -> void:
	for i in 2:
		if st.players[i].lp <= 0:
			st.winner = 1 - i
			st.win_reason = "%s hat keine Lebenspunkte mehr." % st.players[i].name
			emit("win", {"winner": st.winner, "reason": st.win_reason})
			return


# =====================================================================
# destruction & movement
# =====================================================================

func _destroy_monster(player: int, card: DuelCard, reason: String) -> void:
	var s: DuelSide = st.players[player]
	var z := s.find_monster_zone(card.uid)
	if z < 0:
		return
	s.monsters[z] = null
	st.add_log("%s wird zerstört." % card.name())
	emit("destroy", {"player": player, "uid": card.uid, "id": card.id,
		"reason": reason})
	scripts.on_destroyed(player, card, reason)
	_to_grave_pile(player, card)


func destroy_monster(player: int, card: DuelCard, reason: String = "effect") -> void:
	_destroy_monster(player, card, reason)


func destroy_spell(player: int, card: DuelCard) -> void:
	var s: DuelSide = st.players[player]
	if s.field_spell == card:
		s.field_spell = null
		emit("destroy", {"player": player, "uid": card.uid, "id": card.id,
			"reason": "effect"})
		_to_grave_pile(player, card)
		return
	var z := s.find_spell_zone(card.uid)
	if z < 0:
		return
	s.spells[z] = null
	emit("destroy", {"player": player, "uid": card.uid, "id": card.id,
		"reason": "effect"})
	_to_grave_pile(player, card)


func _send_to_grave(player: int, card: DuelCard, _reason: String) -> void:
	emit("to_grave", {"player": player, "uid": card.uid, "id": card.id})
	_to_grave_pile(player, card)


func _to_grave_pile(player: int, card: DuelCard) -> void:
	card.face_up = true
	card.defense = false
	card.atk_mod = 0
	card.def_mod = 0
	card.attacked = false
	card.summoned_this_turn = false
	card.position_changed = false
	card.just_set = false
	card.equips.clear()
	st.players[player].grave.append(card)


func banish(player: int, card: DuelCard) -> void:
	st.players[player].banished.append(card)
	emit("banish", {"player": player, "uid": card.uid, "id": card.id})


# =====================================================================
# response window (simplified chain)
# =====================================================================

var response_handler: Callable = Callable()


## Give `player` the chance to activate a set trap / quick-play spell.
func _response_window(player: int, ctx: Dictionary) -> void:
	var s: DuelSide = st.players[player]
	var options: Array = []
	for c in s.spells:
		if c == null or c.face_up or c.just_set:
			continue
		if scripts.can_respond(player, c, ctx):
			options.append(c)
	if options.is_empty():
		return
	if s.is_ai:
		var pick = scripts.ai_pick_response(player, options, ctx)
		if pick != null:
			await _activate_response(player, pick, ctx)
		return
	if response_handler.is_valid():
		var chosen = await response_handler.call(options, ctx)
		if chosen != null:
			await _activate_response(player, chosen, ctx)


func _activate_response(player: int, card: DuelCard, ctx: Dictionary) -> void:
	activate_trap(player, card, ctx)
	await _idle()


func _idle() -> void:
	pass


# =====================================================================
# phases & turns
# =====================================================================

func next_phase() -> void:
	if st.is_over():
		return
	match st.phase:
		DuelState.Phase.DRAW:
			st.phase = DuelState.Phase.STANDBY
		DuelState.Phase.STANDBY:
			st.phase = DuelState.Phase.MAIN1
		DuelState.Phase.MAIN1:
			st.phase = DuelState.Phase.BATTLE
		DuelState.Phase.BATTLE:
			st.phase = DuelState.Phase.MAIN2
		DuelState.Phase.MAIN2:
			st.phase = DuelState.Phase.END
		DuelState.Phase.END:
			end_turn()
			return
	emit("phase", {"phase": st.phase})
	if st.phase == DuelState.Phase.BATTLE and not can_enter_battle(st.turn_player):
		# skip an impossible battle phase
		st.phase = DuelState.Phase.MAIN2
		emit("phase", {"phase": st.phase})


func go_to_phase(p: int) -> void:
	if p <= st.phase:
		return
	while st.phase < p and not st.is_over():
		next_phase()


func end_turn() -> void:
	var s: DuelSide = st.me()
	# hand size limit
	while s.hand.size() > DuelState.MAX_HAND:
		var c = s.hand.pop_back()
		_to_grave_pile(st.turn_player, c)
		emit("discard", {"player": st.turn_player, "uid": c.uid})
	scripts.on_end_turn(st.turn_player)

	st.turn_player = 1 - st.turn_player
	st.turn += 1
	st.first_turn = false
	var n: DuelSide = st.me()
	n.normal_summons_left = 1
	for m in n.all_monsters():
		m.attacked = false
		m.summoned_this_turn = false
		m.position_changed = false
		m.can_attack = true
	for c in n.spells:
		if c != null:
			c.just_set = false
	for c in st.opp().spells:
		if c != null:
			c.just_set = false
	st.phase = DuelState.Phase.DRAW
	emit("turn", {"player": st.turn_player, "turn": st.turn})
	emit("phase", {"phase": st.phase})
	scripts.on_start_turn(st.turn_player)
	if st.is_over():
		return
	draw_cards(st.turn_player, 1)
	if st.is_over():
		return
	st.phase = DuelState.Phase.MAIN1
	emit("phase", {"phase": st.phase})


func surrender(player: int) -> void:
	st.winner = 1 - player
	st.win_reason = "%s gibt auf." % st.players[player].name
	emit("win", {"winner": st.winner, "reason": st.win_reason})
