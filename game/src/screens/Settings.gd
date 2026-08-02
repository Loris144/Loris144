extends Control
## Options screen. Every change is written straight into Game.settings and
## persisted, so the music volume reacts on the next audio frame.

const ROWS := [
	{"key": "text_speed", "label": "Textgeschwindigkeit", "kind": "enum",
	 "opts": ["langsam", "normal", "schnell"],
	 "info": "Wie schnell Dialoge Buchstabe für Buchstabe erscheinen."},
	{"key": "music", "label": "Musik-Lautstärke", "kind": "percent",
	 "info": "Lautstärke der Hintergrundmusik."},
	{"key": "sfx", "label": "Soundeffekte", "kind": "percent",
	 "info": "Lautstärke von Menü- und Duellgeräuschen."},
	{"key": "duel_speed", "label": "Duell-Geschwindigkeit", "kind": "enum",
	 "opts": ["normal", "schnell"],
	 "info": "Tempo der Animationen im Duell."},
	{"key": "touch_controls", "label": "Touch-Steuerung", "kind": "bool",
	 "info": "Blendet D-Pad und Knöpfe auf dem Bildschirm ein."},
	{"key": "", "label": "Zurück", "kind": "back",
	 "info": "Einstellungen schließen."},
]
const PERCENT_STEP := 0.05

var _back := ""
var _back_map := ""
var _back_pos := Vector2i(6, 6)

var _sel := 0
var _busy := false
var _rows: Array[Control] = []
var _name_labels: Array[Label] = []
var _value_labels: Array[Label] = []
var _info: Label


func setup(args: Dictionary) -> void:
	_back = str(args.get("back", ""))
	_back_map = str(args.get("back_map", ""))
	var p = args.get("back_pos", null)
	if p is Vector2i:
		_back_pos = p
	elif p is Array and p.size() == 2:
		_back_pos = Vector2i(int(p[0]), int(p[1]))
	else:
		_back_pos = Game.spawn_pos


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh()


# =====================================================================
# construction
# =====================================================================

func _build() -> void:
	add_child(UI.backdrop(Color8(10, 14, 26), Color8(24, 26, 48)))

	var head := UI.label("Einstellungen", UI.FS_L, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	head.position = Vector2(0, 8)
	head.size = Vector2(480, 20)
	add_child(head)
	add_child(UI.rect(Rect2(40, 30, 400, 1), UI.EDGE))

	for i in ROWS.size():
		var row: Dictionary = ROWS[i]
		var holder := Control.new()
		holder.position = Vector2(40, 42 + i * 30)
		holder.size = Vector2(400, 26)
		add_child(holder)
		_rows.append(holder)

		var bg := Panel.new()
		bg.size = holder.size
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_theme_stylebox_override("panel", UI.panel_style(UI.PANEL, UI.EDGE))
		holder.add_child(bg)

		var name_label := UI.label(str(row["label"]), UI.FS_M, UI.TEXT)
		name_label.position = Vector2(10, 0)
		name_label.size = Vector2(220, 26)
		holder.add_child(name_label)
		_name_labels.append(name_label)

		var value_label := UI.label("", UI.FS_M, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		value_label.position = Vector2(248, 0)
		value_label.size = Vector2(112, 26)
		holder.add_child(value_label)
		_value_labels.append(value_label)

		if str(row["kind"]) == "back":
			var hit := Button.new()
			hit.flat = true
			hit.focus_mode = Control.FOCUS_NONE
			hit.size = holder.size
			hit.pressed.connect(_press.bind(i))
			hit.mouse_entered.connect(_hover.bind(i))
			holder.add_child(hit)
		else:
			var left := _arrow("◄", i, -1)
			left.position = Vector2(232, 4)
			holder.add_child(left)
			var right := _arrow("►", i, 1)
			right.position = Vector2(362, 4)
			holder.add_child(right)
			var hit := Button.new()
			hit.flat = true
			hit.focus_mode = Control.FOCUS_NONE
			hit.position = Vector2(0, 0)
			hit.size = Vector2(228, 26)
			hit.pressed.connect(_hover.bind(i))
			hit.mouse_entered.connect(_hover.bind(i))
			holder.add_child(hit)

	_info = UI.label("", UI.FS_S, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_info.position = Vector2(20, 232)
	_info.size = Vector2(440, 14)
	add_child(_info)

	var hint := UI.label("↑↓ wählen  •  ◄ ► ändern  •  Esc zurück",
			UI.FS_S, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(0, 250)
	hint.size = Vector2(480, 14)
	add_child(hint)


func _arrow(glyph: String, index: int, dir: int) -> Button:
	var b := UI.button(glyph, UI.FS_S)
	b.focus_mode = Control.FOCUS_NONE
	b.size = Vector2(18, 18)
	b.pressed.connect(func():
		_sel = index
		_change(dir))
	return b


# =====================================================================
# values
# =====================================================================

func _value_text(index: int) -> String:
	var row: Dictionary = ROWS[index]
	match str(row["kind"]):
		"enum":
			var opts: Array = row["opts"]
			var v: int = clampi(int(Game.settings.get(str(row["key"]), 0)), 0, opts.size() - 1)
			return "‹ %s ›" % str(opts[v])
		"percent":
			var f: float = float(Game.settings.get(str(row["key"]), 0.0))
			return "‹ %d%% ›" % int(round(clampf(f, 0.0, 1.0) * 100.0))
		"bool":
			return "‹ %s ›" % ("an" if bool(Game.settings.get(str(row["key"]), true)) else "aus")
	return ""


func _refresh() -> void:
	for i in ROWS.size():
		var on := i == _sel
		var bg := _rows[i].get_child(0) as Panel
		bg.add_theme_stylebox_override("panel",
			UI.panel_style(UI.PANEL.lightened(0.14) if on else UI.PANEL_DK,
				UI.GOLD if on else UI.EDGE, 2 if on else 1))
		_name_labels[i].add_theme_color_override("font_color",
			UI.GOLD if on else UI.TEXT)
		_value_labels[i].text = _value_text(i)
	_info.text = str(ROWS[_sel]["info"])


func _change(dir: int) -> void:
	if _busy:
		return
	var row: Dictionary = ROWS[_sel]
	var key := str(row["key"])
	match str(row["kind"]):
		"enum":
			var opts: Array = row["opts"]
			var v: int = clampi(int(Game.settings.get(key, 0)) + dir, 0, opts.size() - 1)
			Game.settings[key] = v
		"percent":
			var f: float = clampf(float(Game.settings.get(key, 0.0))
					+ dir * PERCENT_STEP, 0.0, 1.0)
			Game.settings[key] = snappedf(f, 0.01)
		"bool":
			Game.settings[key] = not bool(Game.settings.get(key, true))
		"back":
			return
	Audio.sfx("cursor")
	Game.save_settings()
	_refresh()


# =====================================================================
# input
# =====================================================================

func _unhandled_input(e: InputEvent) -> void:
	if _busy:
		return
	if e.is_action_pressed("ui_down"):
		_sel = (_sel + 1) % ROWS.size()
		Audio.sfx("cursor")
		_refresh()
	elif e.is_action_pressed("ui_up"):
		_sel = (_sel - 1 + ROWS.size()) % ROWS.size()
		Audio.sfx("cursor")
		_refresh()
	elif e.is_action_pressed("ui_left"):
		_change(-1)
	elif e.is_action_pressed("ui_right"):
		_change(1)
	elif e.is_action_pressed("ui_accept"):
		_press(_sel)
	elif e.is_action_pressed("ui_cancel"):
		_leave()


func _hover(index: int) -> void:
	if _busy or index == _sel:
		return
	_sel = index
	Audio.sfx("cursor")
	_refresh()


func _press(index: int) -> void:
	if _busy:
		return
	_sel = index
	_refresh()
	if str(ROWS[index]["kind"]) == "back":
		_leave()
	else:
		_change(1)


func _leave() -> void:
	if _busy:
		return
	_busy = true
	Audio.sfx("cancel")
	Game.save_settings()
	if _back != "" and _back != "World":
		var args := {}
		if _back_map != "":
			args["back_map"] = _back_map
			args["back_pos"] = _back_pos
		SceneFlow.goto(_back, args)
	elif _back_map != "":
		SceneFlow.goto("World", {"map": _back_map, "pos": _back_pos})
	else:
		SceneFlow.goto("Title")
