extends Control
## Character creation: gender -> look -> name.
##
## All three looks of the current gender are shown side by side at scale 3 and
## walk on the spot, so the choice is a purely visual one.

const GENDERS := ["m", "f"]
const GENDER_LABELS := ["Männlich", "Weiblich"]
const LOOKS := ["quiet", "bold", "outsider"]
const LOOK_LABELS := {
	"m": ["Der Ruhige", "Der Draufgänger", "Der Außenseiter"],
	"f": ["Die Ruhige", "Die Draufgängerin", "Die Außenseiterin"],
}
const LOOK_BLURB := {
	"quiet": "Ruhig, aufmerksam – du liest deine Gegner.",
	"bold": "Laut und mutig – du greifst zuerst an.",
	"outsider": "Ein Einzelgänger mit eigenem Kopf.",
}
const STEP_TITLE := ["Wer bist du?", "Wie siehst du aus?", "Wie heißt du?"]
const STEP_HINT := [
	"◄ ► wählen  •  Enter bestätigen",
	"◄ ► wählen  •  Enter bestätigen  •  Esc zurück",
	"Name eintippen  •  Enter bestätigen  •  Esc zurück",
]

const FRAME_W := 32
const FRAME_H := 44
const SPR_SCALE := 3
const ANIM_FPS := 5.0
const MAX_NAME := 12
const DEFAULT_NAME := "Yugi-Fan"
const SLOT_X := [100, 240, 380]        # centres of the three preview slots

var _then := "Story"
var _scene := "prolog_home"

var _step := 0
var _gender := 0
var _look := 0
var _busy := false
var _time := 0.0
var _frame := -1

var _step_label: Label
var _blurb: Label
var _hint: Label
var _slot_panels: Array[Panel] = []
var _slot_buttons: Array[Button] = []
var _slot_labels: Array[Label] = []
var _atlases: Array[AtlasTexture] = []
var _gender_buttons: Array[Button] = []
var _name_row: Control
var _name_edit: LineEdit
var _back_button: Button
var _next_button: Button


func setup(args: Dictionary) -> void:
	_then = str(args.get("then", "Story"))
	_scene = str(args.get("scene", "prolog_home"))


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Audio.play_music("title")
	_build()
	_refresh()
	set_process(true)


# =====================================================================
# construction
# =====================================================================

func _build() -> void:
	add_child(UI.backdrop(Color8(12, 16, 30), Color8(38, 26, 54)))

	var head := UI.label("Charakter erstellen", UI.FS_L, UI.GOLD,
			HORIZONTAL_ALIGNMENT_CENTER)
	head.position = Vector2(0, 6)
	head.size = Vector2(480, 18)
	add_child(head)

	_step_label = UI.label("", UI.FS_M, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_step_label.position = Vector2(0, 26)
	_step_label.size = Vector2(480, 14)
	add_child(_step_label)

	for i in 3:
		var cx: int = SLOT_X[i]
		var panel := UI.panel(Rect2(cx - 58, 44, 116, 154),
				Color(0.08, 0.10, 0.18, 0.75), UI.EDGE)
		add_child(panel)
		_slot_panels.append(panel)

		var atlas := AtlasTexture.new()
		atlas.region = Rect2(0, 0, FRAME_W, FRAME_H)
		_atlases.append(atlas)

		var tex := UI.texture(atlas, Vector2(cx - FRAME_W * SPR_SCALE * 0.5, 52),
				float(SPR_SCALE))
		tex.size = Vector2(FRAME_W * SPR_SCALE, FRAME_H * SPR_SCALE)
		add_child(tex)

		var name_label := UI.label("", UI.FS_S, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		name_label.position = Vector2(cx - 58, 178)
		name_label.size = Vector2(116, 14)
		add_child(name_label)
		_slot_labels.append(name_label)

		var hit := Button.new()
		hit.flat = true
		hit.focus_mode = Control.FOCUS_NONE
		hit.position = Vector2(cx - 58, 44)
		hit.size = Vector2(116, 154)
		hit.pressed.connect(_on_slot_pressed.bind(i))
		add_child(hit)
		_slot_buttons.append(hit)

	_blurb = UI.label("", UI.FS_S, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_blurb.position = Vector2(0, 198)
	_blurb.size = Vector2(480, 12)
	add_child(_blurb)

	# --- step 0: gender buttons
	for i in 2:
		var b := UI.button(GENDER_LABELS[i], UI.FS_M)
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(130 + i * 120, 214)
		b.size = Vector2(100, 20)
		b.pressed.connect(_on_gender_pressed.bind(i))
		add_child(b)
		_gender_buttons.append(b)

	# --- step 2: name entry
	_name_row = Control.new()
	_name_row.position = Vector2(0, 212)
	_name_row.size = Vector2(480, 24)
	add_child(_name_row)

	var name_tag := UI.label("Name:", UI.FS_M, UI.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	name_tag.position = Vector2(110, 2)
	name_tag.size = Vector2(50, 20)
	_name_row.add_child(name_tag)

	_name_edit = LineEdit.new()
	_name_edit.text = DEFAULT_NAME
	_name_edit.max_length = MAX_NAME
	_name_edit.position = Vector2(168, 0)
	_name_edit.size = Vector2(140, 22)
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.add_theme_font_size_override("font_size", UI.FS_M)
	_name_edit.add_theme_color_override("font_color", UI.TEXT)
	_name_edit.add_theme_color_override("caret_color", UI.GOLD)
	_name_edit.add_theme_stylebox_override("normal", UI.panel_style(UI.PANEL_DK, UI.EDGE))
	_name_edit.add_theme_stylebox_override("focus", UI.panel_style(UI.PANEL_DK, UI.GOLD))
	_name_edit.text_submitted.connect(func(_t: String): _advance())
	_name_row.add_child(_name_edit)

	var ok := UI.button("Fertig", UI.FS_M)
	ok.focus_mode = Control.FOCUS_NONE
	ok.position = Vector2(316, 0)
	ok.size = Vector2(60, 22)
	ok.pressed.connect(_advance)
	_name_row.add_child(ok)

	# --- navigation
	_back_button = UI.button("Zurück", UI.FS_S)
	_back_button.focus_mode = Control.FOCUS_NONE
	_back_button.position = Vector2(10, 242)
	_back_button.size = Vector2(64, 18)
	_back_button.pressed.connect(_go_back)
	add_child(_back_button)

	_next_button = UI.button("Weiter", UI.FS_S)
	_next_button.focus_mode = Control.FOCUS_NONE
	_next_button.position = Vector2(406, 242)
	_next_button.size = Vector2(64, 18)
	_next_button.pressed.connect(_advance)
	add_child(_next_button)

	_hint = UI.label("", UI.FS_S, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.position = Vector2(0, 244)
	_hint.size = Vector2(480, 14)
	add_child(_hint)


# =====================================================================
# state
# =====================================================================

func _refresh() -> void:
	var gender: String = GENDERS[_gender]
	var labels: Array = LOOK_LABELS[gender]
	_step_label.text = STEP_TITLE[_step]
	_hint.text = STEP_HINT[_step]
	_hint.add_theme_color_override("font_color", UI.TEXT_DIM)

	for i in 3:
		_atlases[i].atlas = Art.char_sheet("player_%s_%s" % [gender, LOOKS[i]])
		_slot_labels[i].text = str(labels[i])
		var chosen := i == _look and _step > 0
		_slot_panels[i].add_theme_stylebox_override("panel",
			UI.panel_style(Color(0.13, 0.16, 0.27, 0.85) if chosen
				else Color(0.08, 0.10, 0.18, 0.7),
				UI.GOLD if chosen else UI.EDGE, 2 if chosen else 1))
		_slot_labels[i].add_theme_color_override("font_color",
			UI.GOLD if chosen else UI.TEXT)
		_slot_buttons[i].disabled = _step != 1

	_blurb.text = str(LOOK_BLURB.get(LOOKS[_look], "")) if _step > 0 else \
		"Wähle das Geschlecht deines Charakters."

	for i in 2:
		_gender_buttons[i].visible = _step == 0
		var on := i == _gender
		_gender_buttons[i].add_theme_stylebox_override("normal",
			UI.panel_style(UI.PANEL.lightened(0.14) if on else UI.PANEL,
				UI.GOLD if on else UI.EDGE))
		_gender_buttons[i].add_theme_color_override("font_color",
			UI.GOLD if on else UI.TEXT)

	_name_row.visible = _step == 2
	if _step == 2 and not _name_edit.has_focus():
		_name_edit.grab_focus()
		_name_edit.caret_column = _name_edit.text.length()
	_next_button.text = "Fertig" if _step == 2 else "Weiter"
	_frame = -1   # force a sprite region update next frame


func _process(delta: float) -> void:
	_time += delta
	var f := int(_time * ANIM_FPS) % 4
	if f == _frame:
		return
	_frame = f
	for a in _atlases:
		a.region = Rect2(f * FRAME_W, 0, FRAME_W, FRAME_H)


# =====================================================================
# input
# =====================================================================

func _unhandled_input(e: InputEvent) -> void:
	if _busy:
		return
	if e.is_action_pressed("ui_cancel"):
		_go_back()
		return
	if _step == 2:
		return
	if e.is_action_pressed("ui_left"):
		_nudge(-1)
	elif e.is_action_pressed("ui_right"):
		_nudge(1)
	elif e.is_action_pressed("ui_accept"):
		_advance()


func _nudge(dir: int) -> void:
	if _step == 0:
		_gender = (_gender + dir + GENDERS.size()) % GENDERS.size()
	else:
		_look = (_look + dir + LOOKS.size()) % LOOKS.size()
	Audio.sfx("cursor")
	_refresh()


func _on_gender_pressed(index: int) -> void:
	if _busy:
		return
	_gender = index
	Audio.sfx("cursor")
	_refresh()
	_advance()


func _on_slot_pressed(index: int) -> void:
	if _busy or _step != 1:
		return
	if _look == index:
		_advance()
		return
	_look = index
	Audio.sfx("cursor")
	_refresh()


func _advance() -> void:
	if _busy:
		return
	if _step < 2:
		_step += 1
		Audio.sfx("confirm")
		_refresh()
		return
	_finish()


func _go_back() -> void:
	if _busy:
		return
	Audio.sfx("cancel")
	if _step == 0:
		_busy = true
		SceneFlow.goto("Title")
		return
	_step -= 1
	if _step < 2 and _name_edit.has_focus():
		_name_edit.release_focus()
	_refresh()


func _finish() -> void:
	var chosen := _name_edit.text.strip_edges()
	if chosen.is_empty():
		Audio.sfx("cancel")
		_hint.text = "Bitte gib einen Namen ein."
		_hint.add_theme_color_override("font_color", UI.RED)
		_name_edit.grab_focus()
		return
	_busy = true
	Audio.sfx("confirm")
	Game.player_gender = GENDERS[_gender]
	Game.player_look = LOOKS[_look]
	Game.player_name = chosen.substr(0, MAX_NAME)
	Game.set_flag("game_started")
	SceneFlow.goto(_then, {"scene": _scene, "then": "World"})
