class_name CardScripts
extends RefCounted
## Card effects.
##
## Two layers:
##  1. Hand-written scripts for the cards that matter to the story and to
##     deck strategy (staples, boss monsters, the Egyptian Gods).
##  2. Generic behaviour derived from the card database — fusion and ritual
##     recipes are parsed straight out of the English card text, so every
##     Fusion/Ritual monster in the pool is summonable without a bespoke
##     script.
## Anything not covered plays as a vanilla stat card, which is correct for
## the large Normal-monster share of a classic-era pool.

var engine                       # DuelEngine
var attack_negated := false
var _fusion_cache: Dictionary = {}
var _ritual_cache: Dictionary = {}

# per-duel continuous state
var swords_turns := [0, 0]       # Swords of Revealing Light on player i


func st() -> DuelState:
	return engine.st


func eng_name(id: int) -> String:
	return str(CardDB.get_card(id).get("name", ""))


# =====================================================================
# recipe parsing
# =====================================================================

## Fusion materials for `id`, parsed from the card text: the text of a Fusion
## monster starts with the material line, e.g.
##   "Blue-Eyes White Dragon" + "Blue-Eyes White Dragon" + ...
## Entries can also be descriptors such as `1 Dragon monster`.
func fusion_materials(id: int) -> Array:
	if _fusion_cache.has(id):
		return _fusion_cache[id]
	var out: Array = []
	var text := CardDB.text(id).strip_edges()
	# take everything up to the first sentence end that still contains a '+'
	var head := text
	var stop := text.find("\n")
	if stop < 0:
		stop = text.length()
	head = text.substr(0, stop)
	if head.find("+") < 0:
		# some entries put the materials before the first period
		var dot := text.find(". ")
		if dot > 0:
			head = text.substr(0, dot)
	if head.find("+") >= 0:
		for part in head.split("+"):
			var p := str(part).strip_edges()
			# quoted card name
			var q0 := p.find("\"")
			var q1 := p.rfind("\"")
			if q0 >= 0 and q1 > q0:
				var nm := p.substr(q0 + 1, q1 - q0 - 1)
				var cid := CardDB.find_by_name(nm)
				if cid != 0:
					out.append(cid)
				else:
					out.append(nm)
				continue
			# "1 Dragon monster" / "2 Spellcaster-Type monsters"
			var lower := p.to_lower()
			var matched := false
			for race in ["dragon", "spellcaster", "warrior", "beast", "fiend",
					"machine", "zombie", "aqua", "pyro", "rock", "fairy",
					"insect", "plant", "thunder", "dinosaur", "fish",
					"winged beast", "sea serpent", "reptile"]:
				if lower.find(race) >= 0:
					out.append("race:" + race.capitalize().replace(" B", " B"))
					matched = true
					break
			if not matched and p != "":
				out.append(p)
	_fusion_cache[id] = out
	return out


## The monster a Ritual Spell summons, parsed from its text.
func ritual_target(spell_id: int) -> int:
	if _ritual_cache.has(spell_id):
		return _ritual_cache[spell_id]
	var text := CardDB.text(spell_id)
	var found := 0
	var idx := 0
	while true:
		var q0 := text.find("\"", idx)
		if q0 < 0:
			break
		var q1 := text.find("\"", q0 + 1)
		if q1 < 0:
			break
		var nm := text.substr(q0 + 1, q1 - q0 - 1)
		var cid := CardDB.find_by_name(nm)
		if cid != 0 and CardDB.kind(cid) == "ritual" and CardDB.is_monster(cid):
			found = cid
			break
		idx = q1 + 1
	_ritual_cache[spell_id] = found
	return found


# =====================================================================
# helpers
# =====================================================================

func _side(p: int) -> DuelSide:
	return st().players[p]


func _all_monsters(p: int) -> Array:
	return _side(p).all_monsters()


func _draw(p: int, n: int) -> void:
	engine.draw_cards(p, n)


func _destroy_all_monsters(p: int) -> void:
	for m in _all_monsters(p).duplicate():
		engine.destroy_monster(p, m, "effect")


func _destroy_all_spells(p: int) -> void:
	var s := _side(p)
	for i in DuelState.SZONES:
		if s.spells[i] != null:
			engine.destroy_spell(p, s.spells[i])
	if s.field_spell != null:
		engine.destroy_spell(p, s.field_spell)


func _strongest(p: int, by_def: bool = false) -> DuelCard:
	var best = null
	for m in _all_monsters(p):
		if best == null:
			best = m
		elif (m.def_() if by_def else m.atk()) > (best.def_() if by_def else best.atk()):
			best = m
	return best


func _weakest(p: int) -> DuelCard:
	var best = null
	for m in _all_monsters(p):
		if best == null or m.atk() < best.atk():
			best = m
	return best


func _revive_from_grave(p: int, from_player: int) -> bool:
	var g := _side(from_player).grave
	var best = null
	for c in g:
		if not CardDB.is_monster(c.id):
			continue
		if CardDB.is_extra_deck(c.id) or CardDB.kind(c.id) == "ritual":
			continue
		if best == null or c.atk() > best.atk():
			best = c
	if best == null:
		return false
	g.erase(best)
	return engine.special_summon(p, best, false, false, "none")


func has_piercing(card: DuelCard) -> bool:
	var t := CardDB.text(card.id).to_lower()
	return t.find("piercing") >= 0 or t.find("inflict the difference") >= 0


# =====================================================================
# main resolution
# =====================================================================

## Resolve a spell/trap. Returns true if the card should stay on the field.
func resolve(player: int, card: DuelCard, ctx: Dictionary = {}) -> bool:
	var n := eng_name(card.id)
	var opp := 1 - player
	var s := _side(player)

	match n:
		# ---------------- draw / hand -------------------------------
		"Pot of Greed":
			_draw(player, 2)
		"Graceful Charity":
			_draw(player, 3)
			for i in 2:
				if s.hand.size() > 0:
					var c = s.hand.pop_back()
					engine._to_grave_pile(player, c)
					engine.emit("discard", {"player": player, "uid": c.uid})
		"Jar of Greed", "Card of Demise":
			_draw(player, 1)
		"Card of Sanctity":
			for p in 2:
				var need: int = 6 - _side(p).hand.size()
				if need > 0:
					_draw(p, need)
		"Upstart Goblin":
			_draw(player, 1)
			engine.heal(opp, 1000)

		# ---------------- mass removal ------------------------------
		"Dark Hole":
			_destroy_all_monsters(0)
			_destroy_all_monsters(1)
		"Raigeki":
			_destroy_all_monsters(opp)
		"Torrential Tribute":
			_destroy_all_monsters(0)
			_destroy_all_monsters(1)
		"Heavy Storm":
			_destroy_all_spells(0)
			_destroy_all_spells(1)
		"Harpie's Feather Duster":
			_destroy_all_spells(opp)
		"Mirror Force":
			for m in _all_monsters(opp).duplicate():
				if not m.defense and m.face_up:
					engine.destroy_monster(opp, m, "effect")

		# ---------------- targeted removal --------------------------
		"Fissure":
			var t := _weakest(opp)
			if t: engine.destroy_monster(opp, t, "effect")
		"Smashing Ground":
			var t2 := _strongest(opp, true)
			if t2: engine.destroy_monster(opp, t2, "effect")
		"Tribute to The Doomed":
			if s.hand.size() > 0:
				engine._to_grave_pile(player, s.hand.pop_back())
			var t3 := _strongest(opp)
			if t3: engine.destroy_monster(opp, t3, "effect")
		"Mystical Space Typhoon", "Dust Tornado", "De-Spell":
			var od := _side(opp)
			for i in DuelState.SZONES:
				if od.spells[i] != null:
					engine.destroy_spell(opp, od.spells[i])
					break
		"Sakuretsu Armor", "Widespread Ruin":
			var a = ctx.get("attacker")
			if a != null:
				engine.destroy_monster(opp, a, "effect")
		"Trap Hole":
			var sm = ctx.get("summoned")
			if sm != null and sm.atk() >= 1000:
				engine.destroy_monster(opp, sm, "effect")
		"Ring of Destruction":
			var t4 := _strongest(opp)
			if t4:
				var dmg := t4.atk()
				engine.destroy_monster(opp, t4, "effect")
				engine._damage(player, dmg, "effect")
				engine._damage(opp, dmg, "effect")
		"Exiled Force":
			var t5 := _strongest(opp)
			if t5: engine.destroy_monster(opp, t5, "effect")

		# ---------------- battle protection -------------------------
		"Waboku", "Negate Attack", "Draining Shield", "Magic Cylinder", \
		"Mirror Wall", "Kuriboh", "Threatening Roar", "Scapegoat":
			return _battle_protection(player, card, n, ctx)

		# ---------------- revival -----------------------------------
		"Monster Reborn":
			var target_player := opp if _side(opp).grave.size() > _side(player).grave.size() else player
			if not _revive_from_grave(player, player):
				_revive_from_grave(player, target_player)
		"Premature Burial":
			if s.lp > 800:
				s.lp -= 800
				engine.emit("damage", {"player": player, "amount": 800, "lp": s.lp})
				_revive_from_grave(player, player)
			return true
		"Call of the Haunted", "Red-Eyes Spirit", "Return of the Red-Eyes", \
		"Rite of Spirit", "Silent Doom":
			_revive_from_grave(player, player)
			return true

		# ---------------- control -----------------------------------
		"Change of Heart", "Brain Control", "Snatch Steal":
			var steal := _strongest(opp)
			if steal:
				var z := _side(opp).find_monster_zone(steal.uid)
				var free := s.free_mzone()
				if z >= 0 and free >= 0:
					_side(opp).monsters[z] = null
					s.monsters[free] = steal
					steal.attacked = false
					engine.emit("control", {"player": player, "uid": steal.uid})
			if n == "Snatch Steal":
				return true

		# ---------------- stall -------------------------------------
		"Swords of Revealing Light":
			swords_turns[opp] = 3
			for m in _all_monsters(opp):
				m.face_up = true
			engine.emit("swords", {"player": opp})
			return true
		"Gravity Bind", "Level Limit - Area B", "Messenger of Peace":
			return true

		# ---------------- pumps / equips ----------------------------
		"Rush Recklessly":
			var tgt := _strongest(player)
			if tgt:
				tgt.atk_mod += 700
				engine.emit("stat", {"uid": tgt.uid})
		"Shrink":
			var t6 := _strongest(opp)
			if t6:
				t6.atk_mod -= int(CardDB.atk(t6.id) / 2.0)
				engine.emit("stat", {"uid": t6.uid})
		"United We Stand":
			var t7 := _strongest(player)
			if t7:
				t7.atk_mod += 800 * maxi(1, _all_monsters(player).size())
				engine.emit("stat", {"uid": t7.uid})
			return true
		"Mage Power":
			var t8 := _strongest(player)
			if t8:
				var cnt := 0
				for c2 in s.spells:
					if c2 != null: cnt += 1
				t8.atk_mod += 500 * maxi(1, cnt)
				engine.emit("stat", {"uid": t8.uid})
			return true
		"Megamorph", "Axe of Despair", "Sword of Deep-Seated", \
		"Malevolent Nuzzler", "Salamandra", "Fairy Meteor Crush", \
		"Magic Formula", "Book of Secret Arts", "Cyber Shield":
			var t9 := _strongest(player)
			if t9:
				t9.atk_mod += 700
				engine.emit("stat", {"uid": t9.uid})
			return true

		# ---------------- position ----------------------------------
		"Book of Moon":
			var t10 := _strongest(opp)
			if t10:
				t10.face_up = false
				t10.defense = true
				engine.emit("position", {"player": opp, "uid": t10.uid, "defense": true})

		# ---------------- fusion ------------------------------------
		"Polymerization", "Red-Eyes Fusion", "Dragon's Mirror":
			var opts: Array = engine.available_fusions(player)
			if not opts.is_empty():
				var best = opts[0]
				for f in opts:
					if CardDB.atk(f.id) > CardDB.atk(best.id):
						best = f
				engine.fusion_summon(player, best)
				return true   # fusion_summon already consumed the card

		# ---------------- searching ---------------------------------
		"Reinforcement of the Army", "Red-Eyes Insight", "Sage's Stone", \
		"Dark Magic Curtain", "Ancient Chant", "Terraforming":
			_search_to_hand(player, n)

		_:
			_generic(player, card, ctx)
	return false


func _battle_protection(player: int, card: DuelCard, n: String,
		ctx: Dictionary) -> bool:
	var opp := 1 - player
	match n:
		"Waboku", "Threatening Roar":
			attack_negated = true
		"Negate Attack":
			attack_negated = true
		"Draining Shield":
			var a = ctx.get("attacker")
			if a != null:
				engine.heal(player, a.atk())
			attack_negated = true
		"Magic Cylinder":
			var a2 = ctx.get("attacker")
			if a2 != null:
				engine._damage(opp, a2.atk(), "effect")
			attack_negated = true
		"Mirror Wall":
			var a3 = ctx.get("attacker")
			if a3 != null:
				a3.atk_mod -= int(CardDB.atk(a3.id) / 2.0)
				engine.emit("stat", {"uid": a3.uid})
			return true
		"Kuriboh":
			attack_negated = true
		"Scapegoat":
			var s := _side(player)
			for i in 4:
				var z := s.free_mzone()
				if z < 0:
					break
				var tok := DuelCard.new(card.id, st().new_uid())
				tok.face_up = true
				tok.defense = true
				tok.can_attack = false
				tok.atk_mod = -CardDB.atk(card.id)
				tok.def_mod = -CardDB.def(card.id)
				s.monsters[z] = tok
			engine.emit("tokens", {"player": player})
	return false


func _search_to_hand(player: int, spell_name: String) -> void:
	var s := _side(player)
	var want_race := ""
	var want_text := ""
	match spell_name:
		"Reinforcement of the Army": want_race = "Warrior"
		"Red-Eyes Insight": want_text = "Red-Eyes"
		"Sage's Stone", "Dark Magic Curtain": want_text = "Dark Magician"
		"Ancient Chant": want_text = "The Winged Dragon of Ra"
		"Terraforming": want_text = "field"
	for c in s.deck:
		var nm := eng_name(c.id)
		var ok := false
		if want_race != "" and CardDB.is_monster(c.id) \
				and CardDB.race(c.id) == want_race and CardDB.level(c.id) <= 4:
			ok = true
		elif want_text != "" and nm.find(want_text) >= 0:
			ok = true
		elif want_text == "field" and CardDB.kind(c.id) == "field":
			ok = true
		if ok:
			s.deck.erase(c)
			s.hand.append(c)
			engine.emit("search", {"player": player, "id": c.id})
			return


## Fallback: read simple, very common patterns out of the English card text.
func _generic(player: int, card: DuelCard, _ctx: Dictionary) -> void:
	var t := CardDB.text(card.id).to_lower()
	var opp := 1 - player
	if t.find("draw 2 cards") >= 0:
		_draw(player, 2)
	elif t.find("draw 1 card") >= 0 or t.find("draw a card") >= 0:
		_draw(player, 1)
	elif t.find("destroy all monsters your opponent controls") >= 0:
		_destroy_all_monsters(opp)
	elif t.find("destroy all monsters") >= 0:
		_destroy_all_monsters(0); _destroy_all_monsters(1)
	elif t.find("destroy all spell and trap") >= 0:
		_destroy_all_spells(0); _destroy_all_spells(1)
	elif t.find("destroy 1 monster") >= 0 or t.find("destroy that target") >= 0:
		var m := _strongest(opp)
		if m: engine.destroy_monster(opp, m, "effect")
	elif t.find("destroy 1 spell") >= 0 or t.find("destroy 1 set") >= 0:
		var od := _side(opp)
		for i in DuelState.SZONES:
			if od.spells[i] != null:
				engine.destroy_spell(opp, od.spells[i]); break
	elif t.find("special summon") >= 0 and t.find("graveyard") >= 0:
		_revive_from_grave(player, player)
	elif t.find("gain") >= 0 and t.find("life points") >= 0:
		engine.heal(player, 1000)
	elif t.find("inflict") >= 0 and t.find("damage") >= 0:
		engine._damage(opp, 800, "effect")


# =====================================================================
# monster effect hooks
# =====================================================================

func on_summon(player: int, card: DuelCard) -> void:
	var n := eng_name(card.id)
	var opp := 1 - player
	match n:
		"Breaker the Magical Warrior":
			card.counters = 1
			card.atk_mod += 300
			var od := _side(opp)
			for i in DuelState.SZONES:
				if od.spells[i] != null:
					engine.destroy_spell(opp, od.spells[i]); break
		"Cyber Jar", "Morphing Jar":
			_draw(player, 2); _draw(opp, 2)
		"Mystical Knight of Jackal", "Airknight Parshath":
			pass
	# Gods gain their signature power
	if n == "The Winged Dragon of Ra":
		card.atk_mod = 1000
	elif n == "Slifer the Sky Dragon":
		card.atk_mod = maxi(0, _side(player).hand.size() * 1000 - CardDB.atk(card.id))
	elif n == "Obelisk the Tormentor":
		pass


func on_flip(player: int, card: DuelCard) -> void:
	var n := eng_name(card.id)
	var opp := 1 - player
	match n:
		"Man-Eater Bug":
			var t := _strongest(opp)
			if t: engine.destroy_monster(opp, t, "effect")
			engine.destroy_monster(player, card, "effect")
		"Magician of Faith":
			var s := _side(player)
			for c in s.grave:
				if CardDB.is_spell(c.id):
					s.grave.erase(c)
					s.hand.append(c)
					engine.emit("search", {"player": player, "id": c.id})
					break
		"Penguin Soldier":
			var od := _side(opp)
			for m in od.all_monsters().duplicate():
				var z := od.find_monster_zone(m.uid)
				if z >= 0:
					od.monsters[z] = null
					od.hand.append(m)
					engine.emit("to_hand", {"player": opp, "uid": m.uid})
					break
		"Cyber Jar", "Morphing Jar":
			_draw(player, 2); _draw(opp, 2)
		"4-Starred Ladybug of Doom":
			for m in _all_monsters(opp).duplicate():
				if m.level() == 4:
					engine.destroy_monster(opp, m, "effect")


func on_destroyed(player: int, card: DuelCard, _reason: String) -> void:
	var n := eng_name(card.id)
	var s := _side(player)
	match n:
		"Sangan", "Witch of the Black Forest":
			var limit := 1500 if n == "Sangan" else 1500
			for c in s.deck:
				if CardDB.is_monster(c.id) and CardDB.atk(c.id) <= limit \
						and not CardDB.is_extra_deck(c.id):
					s.deck.erase(c)
					s.hand.append(c)
					engine.emit("search", {"player": player, "id": c.id})
					return
		"Mystic Tomato":
			for c in s.deck:
				if CardDB.is_monster(c.id) and CardDB.attribute(c.id) == "DARK" \
						and CardDB.atk(c.id) <= 1500 and not CardDB.is_extra_deck(c.id):
					s.deck.erase(c)
					engine.special_summon(player, c, false, false, "none")
					return
		"Mother Grizzly":
			for c in s.deck:
				if CardDB.is_monster(c.id) and CardDB.attribute(c.id) == "WATER" \
						and CardDB.atk(c.id) <= 1500 and not CardDB.is_extra_deck(c.id):
					s.deck.erase(c)
					engine.special_summon(player, c, false, false, "none")
					return
		"Nimble Momonga":
			engine.heal(player, 1000)


func on_start_turn(player: int) -> void:
	if swords_turns[player] > 0:
		swords_turns[player] -= 1
		if swords_turns[player] == 0:
			engine.emit("swords_end", {"player": player})
	# Slifer's ATK tracks the hand size
	for m in _all_monsters(player):
		if eng_name(m.id) == "Slifer the Sky Dragon":
			m.atk_mod = maxi(0, _side(player).hand.size() * 1000 - CardDB.atk(m.id))


func on_end_turn(_player: int) -> void:
	pass


func can_attack_check(player: int) -> bool:
	return swords_turns[player] <= 0


# =====================================================================
# responses (traps)
# =====================================================================

func can_respond(player: int, card: DuelCard, ctx: Dictionary) -> bool:
	var cat := str(CardDB.get_card(card.id).get("cat", ""))
	if cat != "trap" and CardDB.kind(card.id) != "quick":
		return false
	var n := eng_name(card.id)
	var kind := str(ctx.get("type", ""))
	if kind == "attack":
		return n in ["Mirror Force", "Magic Cylinder", "Waboku", "Negate Attack",
			"Sakuretsu Armor", "Draining Shield", "Mirror Wall", "Widespread Ruin",
			"Ring of Destruction", "Threatening Roar", "Dimensional Prison"]
	if kind == "summon":
		return n in ["Trap Hole", "Torrential Tribute", "Bottomless Trap Hole",
			"Solemn Judgment"]
	return false


func ai_pick_response(player: int, options: Array, ctx: Dictionary):
	# use the strongest answer available, but only when it actually pays off
	var order := ["Mirror Force", "Magic Cylinder", "Ring of Destruction",
		"Sakuretsu Armor", "Dimensional Prison", "Widespread Ruin",
		"Torrential Tribute", "Trap Hole", "Draining Shield", "Mirror Wall",
		"Negate Attack", "Waboku", "Threatening Roar"]
	var a = ctx.get("attacker")
	var incoming: int = a.atk() if a != null else 0
	# don't waste a big trap on a tiny attack unless it would actually hurt
	if incoming > 0 and incoming < 800 and _side(player).lp > 2000:
		return null
	for want in order:
		for c in options:
			if eng_name(c.id) == want:
				return c
	return options[0] if not options.is_empty() else null
