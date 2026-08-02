extends Control
## The duel screen: GX Tag Force style playmat, driven by DuelEngine.

const CardViewScene := preload("res://src/ui/CardView.gd")
const FIELD_SCALE := 0.32
const HAND_SCALE := 0.34

# board geometry, 480x270 — rows stack from the opponent's plate down to the
# player's hand with no overlap:
#   0..13 opponent plate | 16..32 opp S/T | 34..81 opp monsters
#   91 divider | 96..143 my monsters | 145..161 my S/T | 163..172 my plate
#   176..226 hand | 230..268 buttons
const OPP_S_Y := 16
const OPP_M_Y := 34
const MY_M_Y := 96
const MY_S_Y := 145
const HAND_Y := 176
const ZONE_W := 32
const ZONE_H := 47
const ST_H := 16
const ZONE_GAP := 6

var engine: DuelEngine
var ai: DuelAI

# args
var deck_id := "random_t1"
var opponent_name := "Duellant"
var opponent_sprite := "npc00"
var must_win := false
var reward_dp := Game.DP_PER_WIN
var reward_cards: Array = []
var return_scene := ""
var return_index := 0
var back_map := ""
var back_pos := Vector2i(4, 4)
var then_screen := "World"
var win_lines: Array = []
var lose_lines: Array = []

# ui
var _bg: TextureRect
var _field_layer: Control
var _hand_layer: Control
var _hud: Control
var _log: Label
var _phase_label: Label
var _my_lp: Label
var _opp_lp: Label
var _my_lp_bar: ColorRect
var _opp_lp_bar: ColorRect
var _action_panel: Control
var _prompt: Label
var _busy := false
var _selected_hand := -1
var _attacker = null
var _picking_target := false
var _card_nodes: Dictionary = {}     # uid -> CardView


func setup(args: Dictionary) -> void:
	deck_id = str(args.get("deck", "random_t1"))
	opponent_name = str(args.get("opponent_name", "Duellant"))
	opponent_sprite = str(args.get("opponent_sprite", "npc00"))
	must_win = bool(args.get("must_win", false))
	reward_dp = int(args.get("reward_dp", Game.DP_PER_WIN))
	reward_cards = args.get("reward_cards", [])
	return_scene = str(args.get("return_scene", ""))
	return_index = int(args.get("return_index", 0))
	back_map = str(args.get("back_map", Game.current_map))
	then_screen = str(args.get("then", "World"))
	win_lines = args.get("win_lines", [])
	lose_lines = args.get("lose_lines", [])
	var p = args.get("back_pos", null)
	if p is Vector2i:
		back_pos = p
	elif p is Array and p.size() == 2:
		back_pos = Vector2i(int(p[0]), int(p[1]))
	else:
		back_pos = Game.spawn_pos


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_start_duel()


# =====================================================================
# setup
# =====================================================================

func _start_duel() -> void:
	engine = DuelEngine.new()
	engine.event.connect(_on_event)
	engine.response_handler = Callable(self, "_ask_response")

	var my_main: Array = Game.deck_main.duplicate()
	var my_extra: Array = Game.deck_extra.duplicate()
	if my_main.size() < 40:
		# safety net: if the player somehow has no legal deck, lend them one
		var fallback: Dictionary = CardDB.get_deck("starter_spellcaster")
		my_main = fallback.get("main", []).duplicate()
		my_extra = fallback.get("extra", []).duplicate()

	var od: Dictionary = CardDB.get_deck(deck_id)
	var o_main: Array = od.get("main", [])
	var o_extra: Array = od.get("extra", [])
	if o_main.is_empty():
		od = CardDB.get_deck("random_t1")
		o_main = od.get("main", [])
		o_extra = od.get("extra", [])

	Art.prefetch(my_main.slice(0, 25))
	Art.prefetch(o_main.slice(0, 25))

	engine.setup_duel(my_main, my_extra, Game.player_name, Game.sprite_key(),
		o_main, o_extra, opponent_name, opponent_sprite)

	var tier := 3
	var parts := deck_id.split("_t")
	if parts.size() > 1:
		tier = int(parts[1])
	ai = DuelAI.new(engine, 1, tier)

	Audio.play_music("duel")
	_refresh()
	_set_prompt("")


func _build_ui() -> void:
	_bg = TextureRect.new()
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.texture = Art.ui("duel_field")
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.size = Vector2(480, 270)
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_field_layer = Control.new()
	_field_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_field_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_field_layer)

	_hand_layer = Control.new()
	_hand_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hand_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hand_layer)

	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)

	# --- opponent plate (top-left)
	_hud.add_child(UI.rect(Rect2(0, 0, 200, 14), Color(0.04, 0.06, 0.11, 0.9)))
	var on := UI.label(opponent_name, UI.FS_S, UI.TEXT)
	on.position = Vector2(5, 0); on.size = Vector2(96, 12)
	_hud.add_child(on)
	_hud.add_child(UI.rect(Rect2(104, 4, 60, 6), Color(0.12, 0.14, 0.22)))
	_opp_lp_bar = UI.rect(Rect2(104, 4, 60, 6), Color8(210, 80, 90))
	_hud.add_child(_opp_lp_bar)
	_opp_lp = UI.label("8000", UI.FS_S, UI.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_opp_lp.position = Vector2(160, 0); _opp_lp.size = Vector2(38, 12)
	_hud.add_child(_opp_lp)

	# --- player plate (just above the hand)
	_hud.add_child(UI.rect(Rect2(280, 162, 200, 12), Color(0.04, 0.06, 0.11, 0.9)))
	var pn := UI.label(Game.player_name, UI.FS_S, UI.TEXT)
	pn.position = Vector2(284, 162); pn.size = Vector2(90, 12)
	_hud.add_child(pn)
	_hud.add_child(UI.rect(Rect2(376, 165, 60, 6), Color(0.12, 0.14, 0.22)))
	_my_lp_bar = UI.rect(Rect2(376, 165, 60, 6), Color8(110, 200, 140))
	_hud.add_child(_my_lp_bar)
	_my_lp = UI.label("8000", UI.FS_S, UI.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_my_lp.position = Vector2(436, 162); _my_lp.size = Vector2(40, 12)
	_hud.add_child(_my_lp)

	# --- phase readout on the centre divider
	_phase_label = UI.label("", UI.FS_S, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_phase_label.position = Vector2(150, 84); _phase_label.size = Vector2(180, 10)
	_hud.add_child(_phase_label)

	# --- last action, left of the divider
	_log = UI.label("", UI.FS_S, UI.TEXT_DIM)
	_log.position = Vector2(4, 150); _log.size = Vector2(130, 22)
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud.add_child(_log)

	_prompt = UI.label("", UI.FS_S, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.position = Vector2(150, 230); _prompt.size = Vector2(180, 10)
	_hud.add_child(_prompt)

	# --- buttons along the bottom strip
	var b_phase := UI.button("Phase ►", UI.FS_S)
	b_phase.position = Vector2(340, 228); b_phase.size = Vector2(64, 16)
	b_phase.pressed.connect(_on_next_phase)
	_hud.add_child(b_phase)

	var b_end := UI.button("Zug beenden", UI.FS_S)
	b_end.position = Vector2(408, 228); b_end.size = Vector2(68, 16)
	b_end.pressed.connect(_on_end_turn)
	_hud.add_child(b_end)

	var b_giveup := UI.button("Aufgeben", UI.FS_S)
	b_giveup.position = Vector2(4, 228); b_giveup.size = Vector2(56, 16)
	b_giveup.add_theme_color_override("font_color", UI.RED)
	b_giveup.pressed.connect(func(): engine.surrender(0))
	_hud.add_child(b_giveup)

	_action_panel = Control.new()
	_action_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_action_panel)


# =====================================================================
# rendering
# =====================================================================

func _zone_x(i: int) -> int:
	var total := 5 * ZONE_W + 4 * ZONE_GAP
	return int((480 - total) * 0.5) + i * (ZONE_W + ZONE_GAP)


func _refresh() -> void:
	for c in _field_layer.get_children():
		c.queue_free()
	for c in _hand_layer.get_children():
		c.queue_free()
	_card_nodes.clear()

	var me: DuelSide = engine.st.players[0]
	var op: DuelSide = engine.st.players[1]

	# empty-zone outlines so the mat reads as a playing field
	for i in DuelState.MZONES:
		_zone_outline(_zone_x(i), OPP_M_Y, ZONE_W, ZONE_H, Color8(88, 168, 224, 70))
		_zone_outline(_zone_x(i), MY_M_Y, ZONE_W, ZONE_H, Color8(88, 168, 224, 110))
		_zone_outline(_zone_x(i), OPP_S_Y, ZONE_W, ST_H, Color8(88, 224, 168, 60))
		_zone_outline(_zone_x(i), MY_S_Y, ZONE_W, ST_H, Color8(88, 224, 168, 95))

	# opponent monsters + spell/traps
	for i in DuelState.MZONES:
		if op.monsters[i] != null:
			_place(op.monsters[i], _zone_x(i), OPP_M_Y, false, 1)
		if op.spells[i] != null:
			_place_st(op.spells[i], _zone_x(i), OPP_S_Y, 1)
	# my monsters + spell/traps
	for i in DuelState.MZONES:
		if me.monsters[i] != null:
			_place(me.monsters[i], _zone_x(i), MY_M_Y, true, 0)
		if me.spells[i] != null:
			_place_st(me.spells[i], _zone_x(i), MY_S_Y, 0)

	# hand
	var n := me.hand.size()
	var hw := int(100 * HAND_SCALE)
	var step: int = mini(hw + 3, int(360.0 / maxi(1, n)))
	var x0 := int((480 - (n - 1) * step - hw) * 0.5)
	for i in n:
		var c: DuelCard = me.hand[i]
		var v := CardViewScene.new()
		_hand_layer.add_child(v)
		v.setup(c.id, true, false, HAND_SCALE, true)
		v.position = Vector2(x0 + i * step, HAND_Y)
		v.gui_input.connect(_on_hand_input.bind(i))
		v.mouse_filter = Control.MOUSE_FILTER_PASS
		if i == _selected_hand:
			v.set_selected(true)
			v.position.y -= 6
		_card_nodes[c.uid] = v

	# piles
	_draw_pile_counts(me, op)
	_update_lp()


func _zone_outline(x: int, y: int, w: int, h: int, col: Color) -> void:
	var p := Panel.new()
	p.position = Vector2(x, y)
	p.size = Vector2(w, h)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel",
		UI.panel_style(Color(col.r, col.g, col.b, 0.10), col, 1))
	_field_layer.add_child(p)


func _place(card: DuelCard, x: int, y: int, mine: bool, owner: int) -> void:
	var v := CardViewScene.new()
	_field_layer.add_child(v)
	v.setup(card.id, card.face_up, card.defense, FIELD_SCALE, true)
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	# defence position: rotate 90° around the card centre so it stays in zone
	if card.defense:
		v.pivot_offset = Vector2(ZONE_W, ZONE_H) * 0.5
		v.rotation_degrees = 90
		v.position = Vector2(x, y)
	else:
		v.position = Vector2(x, y)
	if card.face_up and CardDB.is_monster(card.id):
		v.set_live_stats(card.atk(), card.def_())
	if mine and CardDB.is_monster(card.id) and card.attacked:
		v.set_dim(true)
	v.gui_input.connect(_on_field_input.bind(card, owner))
	_card_nodes[card.uid] = v


## Spell/trap zones are short, so cards there show as compact plates.
func _place_st(card: DuelCard, x: int, y: int, owner: int) -> void:
	var col := Color8(150, 150, 160)
	if card.face_up:
		col = Color8(47, 154, 134) if CardDB.is_spell(card.id) else Color8(176, 64, 122)
	var p := Panel.new()
	p.position = Vector2(x, y)
	p.size = Vector2(ZONE_W, ST_H)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_theme_stylebox_override("panel",
		UI.panel_style(col.darkened(0.35), col.lightened(0.25), 1))
	_field_layer.add_child(p)
	var txt := "SET" if not card.face_up else CardDB.card_name(card.id)
	var l := UI.label(txt, 6, Color(1, 1, 1, 0.95), HORIZONTAL_ALIGNMENT_CENTER)
	l.position = Vector2(x + 1, y + 2)
	l.size = Vector2(ZONE_W - 2, ST_H - 4)
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field_layer.add_child(l)
	p.gui_input.connect(_on_field_input.bind(card, owner))
	_card_nodes[card.uid] = p


func _draw_pile_counts(me: DuelSide, op: DuelSide) -> void:
	for spec in [
			[me.deck.size(), "Deck", 448, 100], [me.grave.size(), "GY", 448, 112],
			[me.extra.size(), "Ex", 448, 124],
			[op.deck.size(), "Deck", 2, 36], [op.grave.size(), "GY", 2, 48],
			[op.hand.size(), "Hand", 2, 60]]:
		var l := UI.label("%s %d" % [spec[1], spec[0]], UI.FS_S, UI.TEXT_DIM)
		l.position = Vector2(int(spec[2]), int(spec[3]))
		l.size = Vector2(32, 10)
		_field_layer.add_child(l)


func _update_lp() -> void:
	var me: DuelSide = engine.st.players[0]
	var op: DuelSide = engine.st.players[1]
	_my_lp.text = str(me.lp)
	_opp_lp.text = str(op.lp)
	_my_lp_bar.size.x = 120.0 * clampf(float(me.lp) / DuelState.START_LP, 0.0, 1.0)
	_opp_lp_bar.size.x = 120.0 * clampf(float(op.lp) / DuelState.START_LP, 0.0, 1.0)
	_phase_label.text = "%s — %s" % [
		"Dein Zug" if engine.st.turn_player == 0 else "Gegner",
		engine.st.phase_name()]


func _set_prompt(text: String) -> void:
	_prompt.text = text


# =====================================================================
# player interaction
# =====================================================================

func _my_turn() -> bool:
	return engine.st.turn_player == 0 and not _busy and not engine.st.is_over()


func _on_hand_input(e: InputEvent, index: int) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if not _my_turn():
		return
	_selected_hand = index
	Audio.sfx("cursor")
	_refresh()
	_show_hand_actions(index)


func _show_hand_actions(index: int) -> void:
	_clear_actions()
	var me: DuelSide = engine.st.players[0]
	if index < 0 or index >= me.hand.size():
		return
	var card: DuelCard = me.hand[index]
	var actions: Array = []
	var in_main := engine.st.phase in [DuelState.Phase.MAIN1, DuelState.Phase.MAIN2]

	if CardDB.is_monster(card.id) and in_main:
		if engine.can_normal_summon(0, card):
			var need := engine.tributes_needed(card.id)
			var lbl := "Normal beschwören"
			if need > 0:
				lbl = "Tribut-Beschwörung (%d)" % need
			actions.append([lbl, func(): _do_summon(card, false, false)])
			actions.append(["Verdeckt setzen", func(): _do_summon(card, true, true)])
	elif (CardDB.is_spell(card.id) or CardDB.is_trap(card.id)):
		if CardDB.is_spell(card.id) and engine.can_activate(0, card, true):
			actions.append(["Aktivieren", func(): _do_activate(card)])
		if in_main and me.free_szone() >= 0:
			actions.append(["Setzen", func(): _do_set(card)])

	actions.append(["Info", func(): _show_info(card.id)])
	actions.append(["Abbrechen", func(): _cancel()])
	_build_action_menu(actions, Vector2(clampf(_card_nodes.get(card.uid, self).position.x - 20, 4, 330), 150))


func _on_field_input(e: InputEvent, card: DuelCard, owner: int) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if engine.st.is_over():
		return
	if _picking_target and owner == 1:
		_picking_target = false
		var atk = _attacker
		_attacker = null
		_clear_actions()
		_busy = true
		await engine.declare_attack(0, atk, card)
		_busy = false
		_refresh()
		return
	if not _my_turn():
		_show_info(card.id)
		return
	if owner == 1:
		_show_info(card.id)
		return
	_selected_hand = -1
	_clear_actions()
	var actions: Array = []
	if CardDB.is_monster(card.id):
		if engine.st.phase == DuelState.Phase.BATTLE and card.face_up \
				and not card.defense and not card.attacked \
				and engine.scripts.can_attack_check(0):
			actions.append(["Angreifen", func(): _begin_attack(card)])
		if engine.st.phase in [DuelState.Phase.MAIN1, DuelState.Phase.MAIN2]:
			if not card.face_up and not card.summoned_this_turn and not card.position_changed:
				actions.append(["Flipp-Beschwörung", func(): _do_flip(card)])
			elif card.face_up and not card.summoned_this_turn and not card.position_changed:
				actions.append(["Position wechseln", func(): _do_position(card)])
	elif not card.face_up and (CardDB.is_trap(card.id) or CardDB.kind(card.id) == "quick"):
		actions.append(["Aktivieren", func(): _do_activate_set(card)])
	elif not card.face_up and CardDB.is_spell(card.id):
		if engine.can_activate(0, card, false):
			actions.append(["Aktivieren", func(): _do_activate_set(card)])
	actions.append(["Info", func(): _show_info(card.id)])
	actions.append(["Abbrechen", func(): _cancel()])
	_build_action_menu(actions, Vector2(clampf(_card_nodes.get(card.uid, self).position.x - 20, 4, 330), 110))


func _build_action_menu(actions: Array, pos: Vector2) -> void:
	_clear_actions()
	var h := actions.size() * 17 + 6
	var panel := UI.panel(Rect2(pos.x, clampf(pos.y, 20, 270 - h - 4), 130, h))
	_action_panel.add_child(panel)
	for i in actions.size():
		var b := UI.button(str(actions[i][0]), UI.FS_S)
		b.position = Vector2(pos.x + 4, clampf(pos.y, 20, 270 - h - 4) + 3 + i * 17)
		b.size = Vector2(122, 15)
		var cb: Callable = actions[i][1]
		b.pressed.connect(func():
			Audio.sfx("confirm")
			_clear_actions()
			cb.call())
		_action_panel.add_child(b)


func _clear_actions() -> void:
	for c in _action_panel.get_children():
		c.queue_free()


func _cancel() -> void:
	_selected_hand = -1
	_picking_target = false
	_attacker = null
	Audio.sfx("cancel")
	_refresh()
	_set_prompt("")


# ---- actions ---------------------------------------------------------

func _do_summon(card: DuelCard, defense: bool, face_down: bool) -> void:
	_busy = true
	var need := engine.tributes_needed(card.id)
	var tributes: Array = []
	if need > 0:
		tributes = await _pick_tributes(need)
		if tributes.size() < need:
			_busy = false
			_cancel()
			return
	if engine.normal_summon(0, card, defense, tributes, face_down):
		Audio.sfx("summon")
	_selected_hand = -1
	_busy = false
	_refresh()


func _pick_tributes(need: int) -> Array:
	_set_prompt("Wähle %d Tribut(e)" % need)
	var me: DuelSide = engine.st.players[0]
	var chosen: Array = []
	var pool := me.all_monsters()
	if pool.size() < need:
		return []
	# simple modal: click monsters until enough are chosen
	var done := false
	var handlers: Array = []
	for m in pool:
		var v = _card_nodes.get(m.uid)
		if v != null and v.has_method("set_selected"):
			v.set_selected(true, Color(1, 0.4, 0.4))
	while not done:
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_cancel"):
			return []
		for m in pool:
			var v = _card_nodes.get(m.uid)
			if v != null and v.get_global_rect().has_point(get_global_mouse_position()) \
					and Input.is_action_just_pressed("ui_accept"):
				pass
		# mouse click detection
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			for m in pool:
				var v2 = _card_nodes.get(m.uid)
				if v2 != null and v2.get_global_rect().has_point(get_global_mouse_position()):
					if not (m.uid in chosen):
						chosen.append(m.uid)
						Audio.sfx("cursor")
						if v2.has_method("set_selected"):
							v2.set_selected(true, Color(1, 0.8, 0.2))
					break
			await get_tree().create_timer(0.18).timeout
		if chosen.size() >= need:
			done = true
	_set_prompt("")
	return chosen


func _do_set(card: DuelCard) -> void:
	if engine.set_spell(0, card):
		Audio.sfx("card")
	_selected_hand = -1
	_refresh()


func _do_activate(card: DuelCard) -> void:
	_busy = true
	engine.activate_spell(0, card, true)
	_selected_hand = -1
	_busy = false
	_refresh()


func _do_activate_set(card: DuelCard) -> void:
	_busy = true
	if CardDB.is_trap(card.id):
		engine.activate_trap(0, card, {})
	else:
		engine.activate_spell(0, card, false)
	_busy = false
	_refresh()


func _do_flip(card: DuelCard) -> void:
	engine.flip_summon(0, card)
	_refresh()


func _do_position(card: DuelCard) -> void:
	engine.change_position(0, card)
	_refresh()


func _begin_attack(card: DuelCard) -> void:
	var targets := engine.legal_targets(0)
	if targets.is_empty():
		_busy = true
		await engine.declare_attack(0, card, null)
		_busy = false
		_refresh()
		return
	_attacker = card
	_picking_target = true
	_set_prompt("Wähle ein Ziel")
	for t in targets:
		var v = _card_nodes.get(t.uid)
		if v and v.has_method("set_selected"):
			v.set_selected(true, Color(1, 0.35, 0.35))


func _show_info(id: int) -> void:
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var shade := UI.rect(Rect2(0, 0, 480, 270), Color(0, 0, 0, 0.72))
	panel.add_child(shade)
	var v := CardViewScene.new()
	panel.add_child(v)
	v.setup(id, true, false, 0.86, true)
	v.position = Vector2(24, 60)
	var box := UI.panel(Rect2(126, 40, 330, 190))
	panel.add_child(box)
	var nm := UI.label(CardDB.card_name(id), UI.FS_L, UI.GOLD)
	nm.position = Vector2(134, 46); nm.size = Vector2(316, 16)
	panel.add_child(nm)
	var meta := ""
	if CardDB.is_monster(id):
		meta = "%s / %s ・ Stufe %d ・ ATK %d / DEF %d" % [
			CardDB.attribute(id), CardDB.race(id), CardDB.level(id),
			CardDB.atk(id), CardDB.def(id)]
	else:
		meta = "%s ・ %s" % [
			"Zauberkarte" if CardDB.is_spell(id) else "Fallenkarte",
			CardDB.kind(id)]
	var ml := UI.label(meta, UI.FS_S, UI.TEXT_DIM)
	ml.position = Vector2(134, 64); ml.size = Vector2(316, 12)
	panel.add_child(ml)
	var txt := UI.rich(CardDB.text(id), UI.FS_S, UI.TEXT)
	txt.position = Vector2(134, 80)
	txt.size = Vector2(314, 140)
	txt.scroll_active = true
	txt.fit_content = false
	panel.add_child(txt)
	var close := UI.button("Schließen", UI.FS_S)
	close.position = Vector2(370, 234); close.size = Vector2(80, 18)
	close.pressed.connect(func():
		Audio.sfx("cancel")
		panel.queue_free())
	panel.add_child(close)


# ---- phase control ---------------------------------------------------

func _on_next_phase() -> void:
	if not _my_turn():
		return
	_clear_actions()
	Audio.sfx("cursor")
	engine.next_phase()
	_refresh()


func _on_end_turn() -> void:
	if not _my_turn():
		return
	_clear_actions()
	_selected_hand = -1
	Audio.sfx("cursor")
	engine.end_turn()
	_refresh()
	if engine.st.turn_player == 1 and not engine.st.is_over():
		_run_ai()


func _run_ai() -> void:
	_busy = true
	_set_prompt("%s ist am Zug …" % opponent_name)
	await ai.take_turn()
	_busy = false
	_refresh()
	if not engine.st.is_over():
		_set_prompt("")


# ---- trap response ---------------------------------------------------

func _ask_response(options: Array, ctx: Dictionary):
	if options.is_empty():
		return null
	var result := [null]
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	panel.add_child(UI.rect(Rect2(0, 0, 480, 270), Color(0, 0, 0, 0.5)))
	var h := options.size() * 18 + 30
	panel.add_child(UI.panel(Rect2(140, 90, 200, h)))
	var t := UI.label("Reagieren?", UI.FS_M, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	t.position = Vector2(140, 94); t.size = Vector2(200, 14)
	panel.add_child(t)
	for i in options.size():
		var c: DuelCard = options[i]
		var b := UI.button(CardDB.card_name(c.id), UI.FS_S)
		b.position = Vector2(148, 110 + i * 18); b.size = Vector2(184, 16)
		b.pressed.connect(func():
			result[0] = c)
		panel.add_child(b)
	var skip := UI.button("Nichts tun", UI.FS_S)
	skip.position = Vector2(148, 110 + options.size() * 18)
	skip.size = Vector2(184, 16)
	skip.pressed.connect(func():
		result[0] = "skip")
	panel.add_child(skip)
	while result[0] == null:
		await get_tree().process_frame
	panel.queue_free()
	Audio.sfx("confirm")
	return null if result[0] == "skip" else result[0]


# =====================================================================
# engine events
# =====================================================================

func _on_event(kind: String, data: Dictionary) -> void:
	match kind:
		"damage":
			Audio.sfx("damage")
			_update_lp()
			SceneFlow.flash(Color(0.8, 0.1, 0.1, 0.35), 0.2)
		"heal":
			_update_lp()
		"summon", "special_summon":
			Audio.sfx("summon")
		"battle":
			Audio.sfx("attack")
		"draw":
			Audio.sfx("card")
		"activate":
			Audio.sfx("open")
		"phase", "turn":
			_update_lp()
		"win":
			_end_duel(int(data.get("winner", 1)), str(data.get("reason", "")))
	if engine and engine.st.log_lines.size() > 0:
		_log.text = engine.st.log_lines[-1]


# =====================================================================
# end of duel
# =====================================================================

func _end_duel(winner: int, reason: String) -> void:
	if _busy:
		_busy = false
	_clear_actions()
	var won := winner == 0
	Audio.stop_music()
	Audio.sfx("win" if won else "lose")
	Game.record_duel(won, reward_dp > 0)
	if won and not reward_cards.is_empty():
		Game.add_cards(reward_cards)
	Game.save_game()

	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	panel.add_child(UI.rect(Rect2(0, 0, 480, 270), Color(0, 0, 0, 0.78)))
	panel.add_child(UI.panel(Rect2(90, 70, 300, 130)))
	var title := UI.label("SIEG!" if won else "NIEDERLAGE",
		UI.FS_XL, UI.GOLD if won else UI.RED, HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(90, 82); title.size = Vector2(300, 24)
	panel.add_child(title)
	var sub := UI.label(reason, UI.FS_S, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	sub.position = Vector2(96, 110); sub.size = Vector2(288, 12)
	panel.add_child(sub)
	var lines: Array = win_lines if won else lose_lines
	if not lines.is_empty():
		var fl := UI.label(Game.fill(str(lines[0])), UI.FS_S, UI.TEXT,
			HORIZONTAL_ALIGNMENT_CENTER)
		fl.position = Vector2(96, 126); fl.size = Vector2(288, 24)
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(fl)
	if won and reward_dp > 0:
		var dpl := UI.label("+%d DP" % reward_dp, UI.FS_L, UI.GREEN,
			HORIZONTAL_ALIGNMENT_CENTER)
		dpl.position = Vector2(96, 152); dpl.size = Vector2(288, 16)
		panel.add_child(dpl)
	var again_needed := must_win and not won
	var b := UI.button("Nochmal" if again_needed else "Weiter", UI.FS_M)
	b.position = Vector2(190, 174); b.size = Vector2(100, 20)
	b.pressed.connect(func():
		Audio.sfx("confirm")
		if again_needed:
			SceneFlow.goto("Duel", _self_args())
		else:
			_leave())
	panel.add_child(b)


func _self_args() -> Dictionary:
	return {
		"deck": deck_id, "opponent_name": opponent_name,
		"opponent_sprite": opponent_sprite, "must_win": must_win,
		"reward_dp": reward_dp, "reward_cards": reward_cards,
		"return_scene": return_scene, "return_index": return_index,
		"back_map": back_map, "back_pos": back_pos, "then": then_screen,
		"win_lines": win_lines, "lose_lines": lose_lines,
	}


func _leave() -> void:
	if return_scene != "":
		SceneFlow.goto("Story", {
			"scene": return_scene, "then": then_screen,
			"back_map": back_map, "back_pos": back_pos,
			"start_index": return_index,
		})
	else:
		SceneFlow.goto("World", {"map": back_map, "pos": back_pos})


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		_cancel()
