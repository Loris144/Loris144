extends Control
## Cutscene player: walks through a scene from story.json step by step.

const MAP_ALIAS := {
	"home_room": "player_home", "domino_street": "domino_street",
	"kame_shop": "kame_shop", "ship_deck": "domino_harbor",
	"domino_city": "domino_plaza", "domino_plaza": "domino_plaza",
	"alley": "bc_alley", "domino_alley": "bc_alley",
	"domino_museum": "domino_museum", "domino_harbor": "domino_harbor",
	"kaiba_airship": "bc_tower", "bc_tower": "bc_tower",
	"dk_shore": "dk_shore", "dk_forest": "dk_forest",
	"dk_rocks": "dk_rocky", "dk_rocky": "dk_rocky", "dk_hill": "dk_hill",
	"dk_castle_area": "dk_castle_ext", "dk_castle_gate": "dk_castle_ext",
	"dk_castle_hall": "dk_castle_int",
	"egypt_desert": "eg_desert", "egypt_shrine": "eg_temple",
	"egypt_ceremony": "tomb", "memory_city": "eg_palace_ext",
	"memory_palace": "eg_throne", "memory_courtyard": "eg_palace_ext",
	"memory_village": "eg_village", "memory_chamber": "eg_temple",
	"memory_sky": "eg_palace_ext",
}

var scene_id := ""
var then_screen := "World"
var back_map := ""
var back_pos := Vector2i(4, 4)

var _steps: Array = []
var _i := 0
var _box
var _stage: Label
var _choice_panel: Control
var _bg: TextureRect
var _left: TextureRect
var _right: TextureRect
var _running := false


func setup(args: Dictionary) -> void:
	scene_id = str(args.get("scene", ""))
	then_screen = str(args.get("then", "World"))
	back_map = str(args.get("back_map", Game.current_map))
	var p = args.get("back_pos", null)
	if p is Vector2i:
		back_pos = p
	elif p is Array and p.size() == 2:
		back_pos = Vector2i(int(p[0]), int(p[1]))
	else:
		back_pos = Game.spawn_pos


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_steps = StoryDB.steps(scene_id)
	if _steps.is_empty():
		push_warning("[Story] empty scene '%s'" % scene_id)
		call_deferred("_finish")
		return
	_running = true
	call_deferred("_run")


func _build() -> void:
	_bg = TextureRect.new()
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.size = Vector2(480, 270)
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_bg.texture = _gradient(Color8(12, 14, 26), Color8(30, 20, 44))
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_left = TextureRect.new()
	_left.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_left.position = Vector2(28, 78)
	_left.size = Vector2(96, 96)
	_left.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_left.stretch_mode = TextureRect.STRETCH_SCALE
	_left.visible = false
	_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_left)

	_right = TextureRect.new()
	_right.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_right.position = Vector2(356, 78)
	_right.size = Vector2(96, 96)
	_right.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_right.stretch_mode = TextureRect.STRETCH_SCALE
	_right.visible = false
	_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_right)

	_stage = UI.label("", UI.FS_M, Color8(200, 210, 235),
		HORIZONTAL_ALIGNMENT_CENTER)
	_stage.position = Vector2(40, 34)
	_stage.size = Vector2(400, 120)
	_stage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stage.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_stage)

	_box = preload("res://src/ui/DialogBox.gd").new()
	add_child(_box)
	_box.visible = false


func _gradient(a: Color, b: Color) -> Texture2D:
	var g := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.set_color(0, a)
	grad.set_color(1, b)
	g.gradient = grad
	g.fill_from = Vector2(0, 0)
	g.fill_to = Vector2(0, 1)
	g.width = 8
	g.height = 64
	return g


# =====================================================================
# the step loop
# =====================================================================

func _run() -> void:
	while _i < _steps.size():
		var step = _steps[_i]
		_i += 1
		if typeof(step) != TYPE_DICTIONARY:
			continue
		await _do_step(step)
		if not _running:
			return
	_finish()


func _do_step(step: Dictionary) -> void:
	match str(step.get("t", "")):
		"say":
			await _say(step, false)
		"think":
			await _say(step, true)
		"stage":
			await _stage_text(Game.fill(str(step.get("text", ""))))
		"choice":
			await _choice(step)
		"choice_duel":
			await _choice_duel(step)
		"duel":
			await _duel(step)
		"mission":
			Game.set_objective(Game.fill(str(step.get("text", ""))))
			await _stage_text("► " + Game.objective)
		"flag":
			Game.set_flag(str(step.get("set", "")), bool(step.get("value", true)))
		"give":
			await _give(step)
		"music":
			Audio.play_music(str(step.get("track", "town")))
		"goto":
			var m := str(step.get("map", ""))
			back_map = MAP_ALIAS.get(m, m)
			if step.has("x") and int(step.get("x", 0)) > 0:
				back_pos = Vector2i(int(step.get("x", 4)), int(step.get("y", 4)))
		"free":
			pass   # handled by finishing the scene
		_:
			pass


func _say(step: Dictionary, italic: bool) -> void:
	var who := str(step.get("who", ""))
	var text := Game.fill(str(step.get("text", "")))
	_stage.text = ""
	_show_portrait(who)
	_box.visible = true
	await _box.show_line(text, who, italic)


func _show_portrait(who: String) -> void:
	if who in ["narrator", "system", ""]:
		return
	var key := StoryDB.speaker_sprite(who)
	var tex := Art.portrait(key)
	if tex == null:
		return
	# player on the left, everyone else on the right
	if who == "player":
		_left.texture = tex
		_left.visible = true
		_left.modulate = Color(1, 1, 1, 1)
		_right.modulate = Color(0.55, 0.58, 0.68, 1)
	else:
		_right.texture = tex
		_right.visible = true
		_right.modulate = Color(1, 1, 1, 1)
		_left.modulate = Color(0.55, 0.58, 0.68, 1)


func _stage_text(text: String) -> void:
	if text.strip_edges() == "":
		return
	_box.visible = false
	_stage.text = text
	_stage.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_stage, "modulate:a", 1.0, 0.22)
	await t.finished
	await _wait_input(1.1)


func _wait_input(min_secs: float) -> void:
	var elapsed := 0.0
	while elapsed < min_secs:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_accept") or _tap:
			_tap = false
			return


var _tap := false


func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		_tap = true


func _choice(step: Dictionary) -> void:
	var options: Array = step.get("options", [])
	if options.is_empty():
		return
	_box.visible = false
	var picked := await _show_choices(options.map(func(o):
		return Game.fill(str(o.get("text", "…")))))
	var chosen: Dictionary = options[picked]
	Game.set_flag("choice_" + str(chosen.get("tag", "x")))
	# echo the choice back as the player's line
	_show_portrait("player")
	_box.visible = true
	await _box.show_line(Game.fill(str(chosen.get("text", ""))), "player")


func _show_choices(labels: Array) -> int:
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var h := labels.size() * 26 + 10
	var bg := UI.panel(Rect2(60, 270 - h - 14, 360, h))
	panel.add_child(bg)
	var result := [-1]
	var buttons: Array[Button] = []
	for i in labels.size():
		var b := UI.button(str(labels[i]), UI.FS_M)
		b.position = Vector2(70, 270 - h - 8 + i * 26)
		b.size = Vector2(340, 22)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func():
			result[0] = i)
		panel.add_child(b)
		buttons.append(b)
	var sel := 0
	var _mark := func():
		for j in buttons.size():
			var on := j == sel
			buttons[j].add_theme_stylebox_override("normal",
				UI.panel_style(UI.PANEL.lightened(0.14) if on else UI.PANEL,
					UI.GOLD if on else UI.EDGE))
			buttons[j].add_theme_color_override("font_color",
				UI.GOLD if on else UI.TEXT)
	_mark.call()
	while result[0] < 0:
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_down"):
			sel = (sel + 1) % buttons.size(); Audio.sfx("cursor"); _mark.call()
		elif Input.is_action_just_pressed("ui_up"):
			sel = (sel - 1 + buttons.size()) % buttons.size(); Audio.sfx("cursor"); _mark.call()
		elif Input.is_action_just_pressed("ui_accept"):
			result[0] = sel
	Audio.sfx("confirm")
	panel.queue_free()
	return result[0]


func _choice_duel(step: Dictionary) -> void:
	var self_duel: Dictionary = step.get("self", {})
	var other: Dictionary = step.get("other", {})
	var who := str(other.get("who", "yugi"))
	var pick := await _show_choices([
		"⚔  Selbst duellieren",
		"👁  %s duellieren lassen" % StoryDB.speaker_name(who),
	])
	if pick == 0:
		await _duel(self_duel)
	else:
		for line in other.get("lines", []):
			if typeof(line) != TYPE_DICTIONARY:
				continue
			await _do_step(line)


func _duel(step: Dictionary) -> void:
	var deck_id := str(step.get("opponent", "random_t1"))
	var mode := str(step.get("mode", "play"))
	if mode == "watch":
		await _stage_text("Ein Duell entbrennt … du siehst gebannt zu.")
		var winner := str(step.get("winner", ""))
		return
	# hand off to the duel screen; it returns to this scene afterwards
	_running = false
	var deck := CardDB.get_deck(deck_id)
	SceneFlow.goto("Duel", {
		"deck": deck_id,
		"opponent_name": str(deck.get("owner", CardDB.deck_name(deck_id))),
		"opponent_sprite": _sprite_for_deck(deck_id),
		"must_win": bool(step.get("must_win", false)),
		"reward_dp": int(step.get("reward_dp", Game.DP_PER_WIN)),
		"reward_cards": step.get("reward_cards", []),
		"return_scene": scene_id,
		"return_index": _i,
		"back_map": back_map, "back_pos": back_pos,
		"then": then_screen,
	})


func _sprite_for_deck(deck_id: String) -> String:
	var base := deck_id.split("_t")[0]
	if Art.has_char(base):
		return base
	return "npc00"


func _give(step: Dictionary) -> void:
	var ids: Array = step.get("cards", [])
	var dp := int(step.get("dp", 0))
	if dp != 0:
		Game.add_dp(dp)
	if not ids.is_empty():
		Game.add_cards(ids)
		var names: Array = []
		for id in ids:
			names.append(CardDB.card_name(int(id)))
		Audio.sfx("win")
		await _stage_text("Erhalten: %s" % ", ".join(names))


func _finish() -> void:
	Game.set_flag(scene_id + "_played")
	Game.save_game()
	var args := {"map": back_map, "pos": back_pos}
	if then_screen == "CharCreate":
		SceneFlow.goto("CharCreate", {"then": "Story", "scene": "prolog_home"})
	elif then_screen == "World":
		SceneFlow.goto("World", args)
	else:
		SceneFlow.goto(then_screen, args)
