extends Control
## Title screen: logo, menu, and the intro narration on a new game.

const ITEMS_NEW := ["Neues Spiel", "Einstellungen"]
const ITEMS_SAVE := ["Weiterspielen", "Neues Spiel", "Einstellungen"]

var _items: Array = []
var _sel := 0
var _buttons: Array[Button] = []
var _busy := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Audio.play_music("title")
	_build()


func _build() -> void:
	add_child(UI.backdrop(Color8(10, 12, 24), Color8(40, 22, 48)))

	# drifting starfield for a little life
	var stars := Node2D.new()
	stars.set_script(preload("res://src/ui/Starfield.gd"))
	add_child(stars)

	var logo := Art.ui("logo")
	var lt := UI.texture(logo, Vector2(240 - logo.get_width() * 0.5, 26))
	add_child(lt)

	var sub := UI.label("Duel Monsters", UI.FS_M, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	sub.position = Vector2(0, 132)
	sub.size = Vector2(480, 14)
	add_child(sub)

	var tag := UI.label("Deine Legende beginnt in Domino City", UI.FS_S,
			UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	tag.position = Vector2(0, 146)
	tag.size = Vector2(480, 12)
	add_child(tag)

	_items = (ITEMS_SAVE if Game.has_save() else ITEMS_NEW).duplicate()
	var y := 172
	for i in _items.size():
		var b := UI.button(_items[i], UI.FS_M)
		b.position = Vector2(170, y + i * 24)
		b.size = Vector2(140, 20)
		b.pressed.connect(_activate.bind(i))
		b.focus_mode = Control.FOCUS_NONE
		add_child(b)
		_buttons.append(b)

	var hint := UI.label("Pfeiltasten / WASD  •  Enter bestätigen", UI.FS_S,
			UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(0, 252)
	hint.size = Vector2(480, 12)
	add_child(hint)

	_refresh()


func _refresh() -> void:
	for i in _buttons.size():
		var on := i == _sel
		_buttons[i].add_theme_stylebox_override("normal",
			UI.panel_style(UI.PANEL.lightened(0.14) if on else UI.PANEL,
				UI.GOLD if on else UI.EDGE))
		_buttons[i].add_theme_color_override("font_color",
			UI.GOLD if on else UI.TEXT)


func _unhandled_input(e: InputEvent) -> void:
	if _busy:
		return
	if e.is_action_pressed("ui_down"):
		_sel = (_sel + 1) % _items.size()
		Audio.sfx("cursor")
		_refresh()
	elif e.is_action_pressed("ui_up"):
		_sel = (_sel - 1 + _items.size()) % _items.size()
		Audio.sfx("cursor")
		_refresh()
	elif e.is_action_pressed("ui_accept"):
		_activate(_sel)


func _activate(index: int) -> void:
	if _busy:
		return
	_sel = index
	_refresh()
	Audio.sfx("confirm")
	match _items[index]:
		"Weiterspielen":
			_busy = true
			Game.load_game()
			SceneFlow.goto("World", {"map": Game.current_map, "pos": Game.spawn_pos})
		"Neues Spiel":
			_busy = true
			Game.new_game()
			SceneFlow.goto("Story", {"scene": "prolog_intro", "then": "CharCreate"})
		"Einstellungen":
			_busy = true
			SceneFlow.goto("Settings", {"back": "Title"})
