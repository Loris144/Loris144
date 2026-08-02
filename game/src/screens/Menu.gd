extends Control
## Pause menu: hub for deck, collection, shop, status, settings and saving.

const ENTRIES := [
	{"label": "Deck bearbeiten", "action": "DeckBuilder",
	 "info": "Stelle dein Main- und Extra-Deck zusammen."},
	{"label": "Kartensammlung", "action": "Collection",
	 "info": "Blättere durch alle Karten, die du besitzt."},
	{"label": "Shop", "action": "Shop",
	 "info": "Kaufe Booster-Packs für deine Duel Points."},
	{"label": "Status", "action": "status",
	 "info": "Zeigt deine Werte und deinen Fortschritt."},
	{"label": "Einstellungen", "action": "Settings",
	 "info": "Text, Lautstärke und Steuerung anpassen."},
	{"label": "Speichern", "action": "save",
	 "info": "Sichert deinen Fortschritt."},
	{"label": "Zurück", "action": "back",
	 "info": "Zurück ins Spiel."},
]

var _back_map := ""
var _back_pos := Vector2i(6, 6)

var _sel := 0
var _busy := false
var _buttons: Array[Button] = []
var _info: Label
var _hint: Label
var _toast: Label
var _status_panel: Control
var _status_text: RichTextLabel
var _preview: Control


func setup(args: Dictionary) -> void:
	_back_map = str(args.get("back_map", Game.current_map))
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
	add_child(UI.backdrop(Color8(10, 14, 26), Color8(28, 22, 46)))

	# ---- header
	add_child(UI.rect(Rect2(0, 0, 480, 30), Color(0.05, 0.07, 0.12, 0.85)))
	add_child(UI.rect(Rect2(0, 30, 480, 1), UI.EDGE))

	var who := UI.label("%s  •  %s" % [Game.player_name, Game.title], UI.FS_M, UI.TEXT)
	who.position = Vector2(8, 1)
	who.size = Vector2(300, 15)
	add_child(who)

	var dp := UI.label("%d DP" % Game.dp, UI.FS_M, UI.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	dp.position = Vector2(300, 1)
	dp.size = Vector2(172, 15)
	add_child(dp)

	var obj_text := ("► " + Game.objective) if Game.objective != "" else "► Kein Auftrag"
	var obj := UI.label(obj_text, UI.FS_S, UI.GREEN)
	obj.position = Vector2(8, 16)
	obj.size = Vector2(464, 13)
	add_child(obj)

	# ---- entry list
	add_child(UI.panel(Rect2(12, 40, 168, 218), Color(0.08, 0.10, 0.18, 0.85), UI.EDGE))
	for i in ENTRIES.size():
		var b := UI.button(str(ENTRIES[i]["label"]), UI.FS_M)
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.position = Vector2(20, 48 + i * 29)
		b.size = Vector2(152, 24)
		b.pressed.connect(_activate.bind(i))
		b.mouse_entered.connect(_hover.bind(i))
		add_child(b)
		_buttons.append(b)

	# ---- info / preview side
	add_child(UI.panel(Rect2(190, 40, 278, 218), Color(0.08, 0.10, 0.18, 0.85), UI.EDGE))

	_preview = _build_preview()
	_preview.position = Vector2(300, 62)
	add_child(_preview)

	var motto := UI.label("Menü", UI.FS_L, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	motto.position = Vector2(190, 46)
	motto.size = Vector2(278, 18)
	add_child(motto)

	_info = UI.label("", UI.FS_S, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_info.position = Vector2(196, 228)
	_info.size = Vector2(266, 24)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_info)

	_build_status_panel()

	_toast = UI.label("", UI.FS_M, UI.GREEN, HORIZONTAL_ALIGNMENT_CENTER)
	_toast.position = Vector2(0, 258)
	_toast.size = Vector2(480, 12)
	_toast.modulate.a = 0.0
	add_child(_toast)

	var hint := UI.label("↑↓ wählen  •  Enter bestätigen  •  Esc zurück ins Spiel",
			UI.FS_S, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(0, 258)
	hint.size = Vector2(480, 12)
	add_child(hint)
	_hint = hint


func _build_preview() -> Control:
	var root := Control.new()
	root.size = Vector2(64, 80)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var atlas := AtlasTexture.new()
	atlas.atlas = Art.char_sheet(Game.sprite_key())
	atlas.region = Rect2(0, 0, 32, 40)
	var t := UI.texture(atlas, Vector2.ZERO, 2.0)
	t.size = Vector2(64, 80)
	root.add_child(t)
	return root


func _build_status_panel() -> void:
	_status_panel = UI.box(Rect2(190, 40, 278, 218), "Status")
	_status_panel.visible = false
	add_child(_status_panel)

	_status_text = UI.rich("", UI.FS_S, UI.TEXT)
	_status_text.position = Vector2(10, 20)
	_status_text.size = Vector2(258, 172)
	_status_text.fit_content = false
	_status_text.scroll_active = true
	_status_panel.add_child(_status_text)

	var close := UI.button("Schließen", UI.FS_S)
	close.focus_mode = Control.FOCUS_NONE
	close.position = Vector2(180, 194)
	close.size = Vector2(88, 18)
	close.pressed.connect(_close_status)
	_status_panel.add_child(close)


# =====================================================================
# state
# =====================================================================

func _refresh() -> void:
	for i in _buttons.size():
		var on := i == _sel
		_buttons[i].add_theme_stylebox_override("normal",
			UI.panel_style(UI.PANEL.lightened(0.14) if on else UI.PANEL,
				UI.GOLD if on else UI.EDGE))
		_buttons[i].add_theme_color_override("font_color",
			UI.GOLD if on else UI.TEXT)
	_info.text = str(ENTRIES[_sel]["info"])


func _hover(index: int) -> void:
	if _busy or _status_panel.visible or index == _sel:
		return
	_sel = index
	Audio.sfx("cursor")
	_refresh()


func _sub_args() -> Dictionary:
	return {"back": "Menu", "back_map": _back_map, "back_pos": _back_pos}


# =====================================================================
# input
# =====================================================================

func _unhandled_input(e: InputEvent) -> void:
	if _busy:
		return
	if _status_panel.visible:
		if e.is_action_pressed("ui_cancel") or e.is_action_pressed("ui_accept"):
			_close_status()
		return
	if e.is_action_pressed("ui_down"):
		_sel = (_sel + 1) % ENTRIES.size()
		Audio.sfx("cursor")
		_refresh()
	elif e.is_action_pressed("ui_up"):
		_sel = (_sel - 1 + ENTRIES.size()) % ENTRIES.size()
		Audio.sfx("cursor")
		_refresh()
	elif e.is_action_pressed("ui_accept"):
		_activate(_sel)
	elif e.is_action_pressed("ui_cancel"):
		_leave()


func _activate(index: int) -> void:
	if _busy or _status_panel.visible:
		return
	_sel = index
	_refresh()
	var action := str(ENTRIES[index]["action"])
	match action:
		"back":
			_leave()
		"save":
			Audio.sfx("confirm")
			if Game.save_game():
				_show_toast("Spiel gespeichert.", UI.GREEN)
			else:
				_show_toast("Speichern fehlgeschlagen!", UI.RED)
		"status":
			Audio.sfx("open")
			_open_status()
		_:
			Audio.sfx("confirm")
			_busy = true
			SceneFlow.goto(action, _sub_args())


func _leave() -> void:
	if _busy:
		return
	_busy = true
	Audio.sfx("cancel")
	SceneFlow.goto("World", {"map": _back_map, "pos": _back_pos})


# =====================================================================
# status panel
# =====================================================================

func _open_status() -> void:
	_status_text.text = _status_body()
	_status_panel.visible = true
	_preview.visible = false
	_hint.text = "Esc / Enter schließen"


func _close_status() -> void:
	Audio.sfx("cancel")
	_status_panel.visible = false
	_preview.visible = true
	_hint.text = "↑↓ wählen  •  Enter bestätigen  •  Esc zurück ins Spiel"


func _status_body() -> String:
	var legal := Game.deck_is_legal()
	var lines := [
		"[b]Name[/b]    %s" % Game.player_name,
		"[b]Titel[/b]   %s" % Game.title,
		"[b]Kapitel[/b] %s" % Game.chapter,
		"",
		"[b]Duel Points[/b]  %d DP" % Game.dp,
		"[b]Duelle[/b]  %d gewonnen / %d verloren" % [Game.duels_won, Game.duels_lost],
		"",
		"[b]Karten[/b]  %d gesamt, %d verschiedene" % [Game.total_cards(), Game.unique_cards()],
		"[b]Deck[/b]    %d Main / %d Extra" % [Game.deck_main.size(), Game.deck_extra.size()],
		"[b]Regelkonform[/b]  %s" % ("[color=#50be82]ja[/color]" if legal
			else "[color=#c84050]nein (40-60 Main, max. 15 Extra)[/color]"),
	]
	return "\n".join(lines)


# =====================================================================
# toast
# =====================================================================

func _show_toast(text: String, color: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.modulate.a = 1.0
	_hint.visible = false
	var t := create_tween()
	t.tween_interval(1.1)
	t.tween_property(_toast, "modulate:a", 0.0, 0.4)
	t.tween_callback(func(): _hint.visible = true)
