extends Control
## Typewriter dialogue box with an optional speaker portrait.

signal finished

const BOX_H := 74

var _panel: Panel
var _text: RichTextLabel
var _name: Label
var _portrait: TextureRect
var _arrow: Label
var _typing := false
var _skip := false
var _full := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50

	_panel = Panel.new()
	_panel.position = Vector2(8, 270 - BOX_H - 8)
	_panel.size = Vector2(464, BOX_H)
	_panel.add_theme_stylebox_override("panel",
		UI.panel_style(Color8(18, 24, 42, 245), UI.EDGE_HI, 2))
	add_child(_panel)

	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.position = Vector2(14, 270 - BOX_H - 14)
	_portrait.size = Vector2(56, 56)
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.stretch_mode = TextureRect.STRETCH_SCALE
	_portrait.visible = false
	add_child(_portrait)

	_name = UI.label("", UI.FS_S, UI.GOLD)
	_name.position = Vector2(76, 270 - BOX_H - 2)
	_name.size = Vector2(200, 12)
	add_child(_name)

	_text = UI.rich("", UI.FS_M, UI.TEXT)
	_text.position = Vector2(76, 270 - BOX_H + 12)
	_text.size = Vector2(386, BOX_H - 18)
	_text.fit_content = false
	_text.scroll_active = false
	add_child(_text)

	_arrow = UI.label("▼", UI.FS_S, UI.GOLD)
	_arrow.position = Vector2(452, 270 - 22)
	_arrow.size = Vector2(12, 12)
	_arrow.visible = false
	add_child(_arrow)


## Show one line and wait for the player to confirm.
func show_line(text: String, speaker: String = "", italic: bool = false) -> void:
	_full = text
	var sprite := ""
	if speaker != "":
		sprite = StoryDB.speaker_sprite(speaker)
		_name.text = StoryDB.speaker_name(speaker)
		var p := Art.portrait(sprite)
		if p:
			_portrait.texture = p
			_portrait.visible = true
			_text.position.x = 76
			_name.position.x = 76
		else:
			_portrait.visible = false
			_text.position.x = 20
			_name.position.x = 20
	else:
		_name.text = ""
		_portrait.visible = false
		_text.position.x = 20
		_name.position.x = 20
	_text.size.x = 462 - _text.position.x

	var body := text
	if italic:
		body = "[i]%s[/i]" % text
	_typing = true
	_skip = false
	_arrow.visible = false
	_text.text = body
	_text.visible_ratio = 0.0

	var chars := maxi(1, text.length())
	var delay := Game.text_delay()
	var shown := 0
	while shown < chars:
		if _skip:
			break
		shown += 1
		_text.visible_ratio = float(shown) / float(chars)
		if shown % 3 == 0:
			Audio.sfx("text")
		await get_tree().create_timer(delay).timeout
	_text.visible_ratio = 1.0
	_typing = false
	_arrow.visible = true

	# wait for confirm
	await _wait_confirm()
	_arrow.visible = false


func _wait_confirm() -> void:
	var done := false
	while not done:
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_accept") or _clicked:
			_clicked = false
			done = true


var _clicked := false


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if _typing:
			_skip = true
		else:
			_clicked = true
		accept_event()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_accept") and _typing:
		_skip = true
