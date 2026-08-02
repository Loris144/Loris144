extends Control
## One card: frame + artwork + optional name/ATK overlay.
## Used on the field, in hand, and in list views.

const FRAME_W := 100.0
const FRAME_H := 146.0
const ART_OFF := Vector2(8, 21)
const ART_SIZE := Vector2(84, 62)

var card_id := 0
var face_up := true
var defense := false
var show_stats := true
var scale_factor := 1.0

var _frame: TextureRect
var _art: TextureRect
var _name: Label
var _stats: Label
var _glow: Panel
var _selected := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	if not Art.card_image_ready.is_connected(_on_art_ready):
		Art.card_image_ready.connect(_on_art_ready)


func setup(id: int, up: bool = true, def_pos: bool = false,
		sc: float = 1.0, stats: bool = true) -> void:
	card_id = id
	face_up = up
	defense = def_pos
	scale_factor = sc
	show_stats = stats
	_rebuild()


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var w := FRAME_W * scale_factor
	var h := FRAME_H * scale_factor
	custom_minimum_size = Vector2(w, h)
	size = Vector2(w, h)

	_glow = Panel.new()
	_glow.position = Vector2(-2, -2)
	_glow.size = Vector2(w + 4, h + 4)
	_glow.add_theme_stylebox_override("panel",
		UI.panel_style(Color(0, 0, 0, 0), Color(1, 1, 1, 0), 2))
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glow)

	_frame = TextureRect.new()
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.texture = Art.card_frame(CardDB.frame_kind(card_id)) if face_up else Art.card_back()
	_frame.size = Vector2(w, h)
	_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	if not face_up:
		return

	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.texture = Art.card_art(card_id)
	_art.position = ART_OFF * scale_factor
	_art.size = ART_SIZE * scale_factor
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)

	if scale_factor >= 0.3:
		_name = UI.label(CardDB.card_name(card_id),
			maxi(6, int(8 * scale_factor * 1.4)), Color8(24, 20, 14))
		_name.position = Vector2(7 * scale_factor, 5 * scale_factor)
		_name.size = Vector2(86 * scale_factor, 13 * scale_factor)
		_name.clip_text = true
		_name.add_theme_constant_override("outline_size", 0)
		_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_name)

	if show_stats and CardDB.is_monster(card_id) and scale_factor >= 0.3:
		var a := CardDB.atk(card_id)
		var d := CardDB.def(card_id)
		_stats = UI.label("%s/%s" % ["?" if a < 0 else str(a), "?" if d < 0 else str(d)],
			maxi(6, int(8 * scale_factor * 1.4)), Color8(24, 20, 14),
			HORIZONTAL_ALIGNMENT_RIGHT)
		_stats.position = Vector2(7 * scale_factor, (FRAME_H - 19) * scale_factor)
		_stats.size = Vector2(86 * scale_factor, 12 * scale_factor)
		_stats.add_theme_constant_override("outline_size", 0)
		_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_stats)


func _on_art_ready(id: int) -> void:
	if id == card_id and face_up and is_instance_valid(_art):
		_art.texture = Art.card_art(card_id)


func set_selected(on: bool, color: Color = Color(1, 0.85, 0.3)) -> void:
	_selected = on
	if is_instance_valid(_glow):
		_glow.add_theme_stylebox_override("panel",
			UI.panel_style(Color(0, 0, 0, 0), color if on else Color(1, 1, 1, 0), 2))


func set_dim(on: bool) -> void:
	modulate = Color(0.55, 0.58, 0.66) if on else Color(1, 1, 1)


## Live ATK/DEF including modifiers (field cards only).
func set_live_stats(atk: int, def_: int) -> void:
	if is_instance_valid(_stats):
		_stats.text = "%d/%d" % [atk, def_]
