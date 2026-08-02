extends Control
## Card binder: a scrollable grid of every owned card with filters, sorting
## and a detail view.

const FRAME_SIZE := Vector2(100, 146)
const ART_OFFSET := Vector2(8, 21)
const ART_SIZE := Vector2(84, 62)
const CARD_SCALE := 0.42

const COLS := 9
const ROWS_VISIBLE := 3
const CELL := Vector2(42, 61)          # FRAME_SIZE * CARD_SCALE, rounded
const GAP := Vector2(8, 8)
const GRID_ORIGIN := Vector2(20, 48)

const FILTERS := ["all", "monster", "spell", "trap"]
const FILTER_LABELS := ["Alle", "Monster", "Zauber", "Fallen"]
const SORTS := ["name", "atk", "level"]
const SORT_LABELS := ["Name", "ATK", "Level"]

const RARITY_COLOR := {
	"common": Color8(126, 138, 160),
	"rare": Color8(88, 168, 224),
	"super": Color8(206, 214, 228),
	"ultra": Color8(232, 194, 70),
}
const RARITY_LABEL := {
	"common": "Common", "rare": "Rare", "super": "Super Rare", "ultra": "Ultra Rare",
}
const ATTR_DE := {
	"DARK": "FINSTERNIS", "LIGHT": "LICHT", "FIRE": "FEUER", "WATER": "WASSER",
	"EARTH": "ERDE", "WIND": "WIND", "DIVINE": "GÖTTLICH",
}
const RACE_DE := {
	"Aqua": "Aqua", "Beast": "Ungeheuer", "Beast-Warrior": "Ungeheuer-Krieger",
	"Creator God": "Schöpfergott", "Cyberse": "Cyberse", "Dinosaur": "Dinosaurier",
	"Divine-Beast": "Göttliches Ungeheuer", "Dragon": "Drache", "Fairy": "Fee",
	"Fiend": "Unterweltler", "Fish": "Fisch", "Illusion": "Illusion",
	"Insect": "Insekt", "Machine": "Maschine", "Plant": "Pflanze", "Pyro": "Pyro",
	"Reptile": "Reptil", "Rock": "Fels", "Sea Serpent": "Seeschlange",
	"Spellcaster": "Hexer", "Thunder": "Donner", "Warrior": "Krieger",
	"Winged Beast": "Geflügeltes Ungeheuer", "Wyrm": "Wyrm", "Zombie": "Zombie",
}
const KIND_DE := {
	"normal": "Normal", "effect": "Effekt", "fusion": "Fusion", "ritual": "Ritual",
	"synchro": "Synchro", "xyz": "Xyz", "link": "Link", "pendulum": "Pendel",
	"continuous": "Permanent", "equip": "Ausrüstung", "field": "Spielfeld",
	"quick": "Schnellzauber", "counter": "Konter",
}

var _back := ""
var _back_map := ""
var _back_pos := Vector2i(6, 6)

var _ids: Array[int] = []              # filtered + sorted card ids
var _sel := 0
var _scroll := 0                       # first visible row
var _filter := 0
var _sort := 0
var _busy := false

var _grid: Control
var _cursor: Panel
var _empty_label: Label
var _count_label: Label
var _filter_buttons: Array[Button] = []
var _sort_button: Button
var _bar: ColorRect
var _hint: Label

var _art_rects: Dictionary = {}        # card_id -> Array[TextureRect] on screen

var _detail: Control
var _detail_frame: TextureRect
var _detail_art: TextureRect
var _detail_name: Label
var _detail_type: Label
var _detail_stats: Label
var _detail_meta: Label
var _detail_text: RichTextLabel
var _detail_id := 0


func setup(args: Dictionary) -> void:
	_back = str(args.get("back", ""))
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
	_rebuild_list()
	Art.card_image_ready.connect(_on_art_ready)


# =====================================================================
# construction
# =====================================================================

func _build() -> void:
	add_child(UI.backdrop(Color8(10, 14, 26), Color8(26, 20, 44)))

	add_child(UI.rect(Rect2(0, 0, 480, 18), Color(0.05, 0.07, 0.12, 0.85)))
	var head := UI.label("Kartensammlung", UI.FS_M, UI.GOLD)
	head.position = Vector2(8, 1)
	head.size = Vector2(200, 15)
	add_child(head)

	_count_label = UI.label("", UI.FS_S, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_count_label.position = Vector2(260, 1)
	_count_label.size = Vector2(212, 15)
	add_child(_count_label)

	for i in FILTERS.size():
		var b := UI.button(FILTER_LABELS[i], UI.FS_S)
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(20 + i * 56, 22)
		b.size = Vector2(52, 18)
		b.pressed.connect(_set_filter.bind(i))
		add_child(b)
		_filter_buttons.append(b)

	_sort_button = UI.button("", UI.FS_S)
	_sort_button.focus_mode = Control.FOCUS_NONE
	_sort_button.position = Vector2(330, 22)
	_sort_button.size = Vector2(122, 18)
	_sort_button.pressed.connect(_cycle_sort)
	add_child(_sort_button)

	_grid = Control.new()
	_grid.position = Vector2.ZERO
	_grid.size = Vector2(480, 270)
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grid)

	_cursor = Panel.new()
	_cursor.size = CELL + Vector2(6, 6)
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.add_theme_stylebox_override("panel",
		UI.panel_style(Color(1, 1, 1, 0), UI.GOLD, 2, 2))
	_cursor.visible = false
	add_child(_cursor)

	_bar = UI.rect(Rect2(466, GRID_ORIGIN.y, 3, 40), UI.EDGE_HI)
	add_child(_bar)

	_empty_label = UI.label("Noch keine Karten.", UI.FS_L, UI.TEXT_DIM,
			HORIZONTAL_ALIGNMENT_CENTER)
	_empty_label.position = Vector2(0, 120)
	_empty_label.size = Vector2(480, 20)
	_empty_label.visible = false
	add_child(_empty_label)

	_hint = UI.label("Pfeile wählen  •  Enter Details  •  Q/E Filter  •  R Sortierung  •  Esc zurück",
			UI.FS_S, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.position = Vector2(0, 254)
	_hint.size = Vector2(480, 12)
	add_child(_hint)

	_build_detail()


func _build_detail() -> void:
	_detail = Control.new()
	_detail.set_anchors_preset(Control.PRESET_FULL_RECT)
	_detail.visible = false
	add_child(_detail)

	_detail.add_child(UI.rect(Rect2(0, 0, 480, 270), Color(0, 0, 0, 0.72)))
	_detail.add_child(UI.panel(Rect2(14, 16, 452, 238),
			Color(0.07, 0.09, 0.16, 0.98), UI.EDGE_HI))

	_detail_frame = UI.texture(null, Vector2(28, 32), 1.0)
	_detail_frame.size = FRAME_SIZE
	_detail.add_child(_detail_frame)

	_detail_art = UI.texture(null, Vector2(28, 32) + ART_OFFSET, 1.0)
	_detail_art.size = ART_SIZE
	_detail.add_child(_detail_art)

	_detail_name = UI.label("", UI.FS_M, UI.GOLD)
	_detail_name.position = Vector2(142, 30)
	_detail_name.size = Vector2(312, 16)
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(_detail_name)

	_detail_type = UI.label("", UI.FS_S, UI.TEXT)
	_detail_type.position = Vector2(142, 48)
	_detail_type.size = Vector2(312, 12)
	_detail.add_child(_detail_type)

	_detail_stats = UI.label("", UI.FS_M, UI.TEXT)
	_detail_stats.position = Vector2(142, 62)
	_detail_stats.size = Vector2(312, 14)
	_detail.add_child(_detail_stats)

	_detail_meta = UI.label("", UI.FS_S, UI.TEXT_DIM)
	_detail_meta.position = Vector2(142, 78)
	_detail_meta.size = Vector2(312, 12)
	_detail.add_child(_detail_meta)

	_detail.add_child(UI.rect(Rect2(142, 92, 312, 1), UI.EDGE))

	_detail_text = UI.rich("", UI.FS_S, UI.TEXT)
	_detail_text.position = Vector2(142, 96)
	_detail_text.size = Vector2(312, 132)
	_detail_text.fit_content = false
	_detail_text.scroll_active = true
	_detail.add_child(_detail_text)

	var close := UI.button("Schließen", UI.FS_S)
	close.focus_mode = Control.FOCUS_NONE
	close.position = Vector2(28, 190)
	close.size = Vector2(100, 18)
	close.pressed.connect(_close_detail)
	_detail.add_child(close)

	var tip := UI.label("↑↓ scrollen  •  Esc schließen", UI.FS_S, UI.TEXT_DIM,
			HORIZONTAL_ALIGNMENT_CENTER)
	tip.position = Vector2(14, 232)
	tip.size = Vector2(452, 12)
	_detail.add_child(tip)


# =====================================================================
# list / filtering / sorting
# =====================================================================

func _rebuild_list() -> void:
	var kept: Array[int] = []
	for key in Game.collection.keys():
		var id := int(key)
		if Game.owned(id) <= 0:
			continue
		match FILTERS[_filter]:
			"monster":
				if not CardDB.is_monster(id):
					continue
			"spell":
				if not CardDB.is_spell(id):
					continue
			"trap":
				if not CardDB.is_trap(id):
					continue
		kept.append(id)

	match SORTS[_sort]:
		"atk":
			kept.sort_custom(func(a, b):
				if CardDB.atk(a) == CardDB.atk(b):
					return CardDB.card_name(a).naturalnocasecmp_to(CardDB.card_name(b)) < 0
				return CardDB.atk(a) > CardDB.atk(b))
		"level":
			kept.sort_custom(func(a, b):
				if CardDB.level(a) == CardDB.level(b):
					return CardDB.card_name(a).naturalnocasecmp_to(CardDB.card_name(b)) < 0
				return CardDB.level(a) > CardDB.level(b))
		_:
			kept.sort_custom(func(a, b):
				return CardDB.card_name(a).naturalnocasecmp_to(CardDB.card_name(b)) < 0)

	_ids = kept
	_sel = clampi(_sel, 0, maxi(0, _ids.size() - 1))
	_scroll = 0
	_ensure_visible()
	_refresh_header()
	_rebuild_grid()


func _refresh_header() -> void:
	_count_label.text = "%d Karten  •  %d verschiedene" % [
		Game.total_cards(), Game.unique_cards()]
	for i in _filter_buttons.size():
		var on := i == _filter
		_filter_buttons[i].add_theme_stylebox_override("normal",
			UI.panel_style(UI.PANEL.lightened(0.14) if on else UI.PANEL_DK,
				UI.GOLD if on else UI.EDGE))
		_filter_buttons[i].add_theme_color_override("font_color",
			UI.GOLD if on else UI.TEXT_DIM)
	_sort_button.text = "Sortierung: %s" % SORT_LABELS[_sort]


func _rows_total() -> int:
	return int(ceil(float(_ids.size()) / float(COLS)))


func _ensure_visible() -> void:
	if _ids.is_empty():
		_scroll = 0
		return
	var row := _sel / COLS
	if row < _scroll:
		_scroll = row
	elif row >= _scroll + ROWS_VISIBLE:
		_scroll = row - ROWS_VISIBLE + 1
	_scroll = clampi(_scroll, 0, maxi(0, _rows_total() - ROWS_VISIBLE))


# =====================================================================
# grid drawing
# =====================================================================

func _cell_pos(index: int) -> Vector2:
	var row := index / COLS - _scroll
	var col := index % COLS
	return GRID_ORIGIN + Vector2(col * (CELL.x + GAP.x), row * (CELL.y + GAP.y))


func _rebuild_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_art_rects.clear()

	_empty_label.visible = _ids.is_empty()
	_cursor.visible = not _ids.is_empty()
	_bar.visible = _rows_total() > ROWS_VISIBLE
	if _ids.is_empty():
		_empty_label.text = "Noch keine Karten." if Game.collection.is_empty() \
			else "Keine Karten in diesem Filter."
		return

	var first := _scroll * COLS
	var last: int = mini(_ids.size(), first + COLS * ROWS_VISIBLE)
	for i in range(first, last):
		_make_cell(i)

	_update_cursor()
	_update_bar()


func _make_cell(index: int) -> void:
	var id: int = _ids[index]
	var pos := _cell_pos(index)

	var ring := Panel.new()
	ring.position = pos - Vector2(2, 2)
	ring.size = CELL + Vector2(4, 4)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring_color: Color = RARITY_COLOR.get(CardDB.best_rarity(id), UI.EDGE)
	ring.add_theme_stylebox_override("panel",
		UI.panel_style(Color(0.05, 0.06, 0.11, 0.9), ring_color, 1, 2))
	_grid.add_child(ring)

	var frame := UI.texture(Art.card_frame(CardDB.frame_kind(id)), pos, CARD_SCALE)
	frame.size = CELL
	_grid.add_child(frame)

	var art := UI.texture(Art.card_art(id), pos + ART_OFFSET * CARD_SCALE, CARD_SCALE)
	art.size = ART_SIZE * CARD_SCALE
	_grid.add_child(art)
	if not _art_rects.has(id):
		_art_rects[id] = []
	_art_rects[id].append(art)

	var count := Game.owned(id)
	if count > 1:
		var badge := UI.label("x%d" % count, UI.FS_S, UI.GOLD,
				HORIZONTAL_ALIGNMENT_RIGHT)
		badge.position = pos + Vector2(0, CELL.y - 11)
		badge.size = Vector2(CELL.x - 2, 10)
		_grid.add_child(badge)

	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.position = pos
	hit.size = CELL
	hit.pressed.connect(_on_cell_pressed.bind(index))
	_grid.add_child(hit)


func _update_cursor() -> void:
	if _ids.is_empty():
		_cursor.visible = false
		return
	_cursor.visible = true
	_cursor.position = _cell_pos(_sel) - Vector2(3, 3)


func _update_bar() -> void:
	var rows := _rows_total()
	if rows <= ROWS_VISIBLE:
		_bar.visible = false
		return
	var track := ROWS_VISIBLE * CELL.y + (ROWS_VISIBLE - 1) * GAP.y
	var h: float = maxf(12.0, track * float(ROWS_VISIBLE) / float(rows))
	var t := float(_scroll) / float(rows - ROWS_VISIBLE)
	_bar.visible = true
	_bar.size = Vector2(3, h)
	_bar.position = Vector2(466, GRID_ORIGIN.y + (track - h) * t)


func _on_art_ready(card_id: int) -> void:
	if _art_rects.has(card_id):
		var tex := Art.card_art(card_id)
		for r in _art_rects[card_id]:
			if is_instance_valid(r):
				r.texture = tex
	if _detail.visible and _detail_id == card_id:
		_detail_art.texture = Art.card_art(card_id)


# =====================================================================
# navigation
# =====================================================================

func _move(dx: int, dy: int) -> void:
	if _ids.is_empty():
		return
	var col := _sel % COLS
	var row := _sel / COLS
	var target := _sel
	if dx != 0:
		var ncol := col + dx
		if ncol < 0 or ncol >= COLS:
			return
		target = row * COLS + ncol
	else:
		var nrow := row + dy
		if nrow < 0:
			return
		target = nrow * COLS + col
	if target < 0 or target >= _ids.size() or target == _sel:
		return
	_sel = target
	Audio.sfx("cursor")
	var old := _scroll
	_ensure_visible()
	if old != _scroll:
		_rebuild_grid()
	else:
		_update_cursor()


func _set_filter(index: int) -> void:
	if _busy or index == _filter:
		return
	_filter = index
	_sel = 0
	Audio.sfx("cursor")
	_rebuild_list()


func _cycle_filter(dir: int) -> void:
	_set_filter((_filter + dir + FILTERS.size()) % FILTERS.size())


func _cycle_sort() -> void:
	if _busy:
		return
	_sort = (_sort + 1) % SORTS.size()
	_sel = 0
	Audio.sfx("cursor")
	_rebuild_list()


func _on_cell_pressed(index: int) -> void:
	if _busy:
		return
	if index != _sel:
		_sel = index
		Audio.sfx("cursor")
		_update_cursor()
		return
	_open_detail()


# =====================================================================
# detail panel
# =====================================================================

func _open_detail() -> void:
	if _ids.is_empty():
		return
	var id: int = _ids[_sel]
	_detail_id = id
	Audio.sfx("open")
	_detail_frame.texture = Art.card_frame(CardDB.frame_kind(id))
	_detail_art.texture = Art.card_art(id)
	_detail_name.text = CardDB.card_name(id)
	_detail_type.text = _type_line(id)
	if CardDB.is_monster(id):
		_detail_stats.text = "ATK %d    DEF %d" % [CardDB.atk(id), CardDB.def(id)]
	else:
		_detail_stats.text = ""
	var rarity := CardDB.best_rarity(id)
	_detail_meta.text = "%s  •  %dx im Besitz" % [
		str(RARITY_LABEL.get(rarity, "Common")), Game.owned(id)]
	var meta_color: Color = RARITY_COLOR.get(rarity, UI.TEXT_DIM)
	_detail_meta.add_theme_color_override("font_color", meta_color)
	var body := CardDB.text(id)
	_detail_text.text = body if body != "" else "[i]Kein Kartentext.[/i]"
	_detail_text.scroll_to_line(0)
	_detail.visible = true


func _close_detail() -> void:
	if not _detail.visible:
		return
	Audio.sfx("cancel")
	_detail.visible = false
	_detail_id = 0


func _type_line(id: int) -> String:
	if CardDB.is_spell(id):
		return "Zauberkarte  •  %s" % str(KIND_DE.get(CardDB.kind(id), "Normal"))
	if CardDB.is_trap(id):
		return "Fallenkarte  •  %s" % str(KIND_DE.get(CardDB.kind(id), "Normal"))
	var parts: Array[String] = []
	if CardDB.level(id) > 0:
		parts.append("Stufe %d" % CardDB.level(id))
	var attr := CardDB.attribute(id)
	if attr != "":
		parts.append(str(ATTR_DE.get(attr, attr)))
	var race := CardDB.race(id)
	if race != "":
		parts.append(str(RACE_DE.get(race, race)))
	parts.append(str(KIND_DE.get(CardDB.kind(id), "Normal")))
	return "  •  ".join(parts)


func _scroll_detail(dir: int) -> void:
	var sb := _detail_text.get_v_scroll_bar()
	if sb:
		sb.value += dir * 16.0


# =====================================================================
# input
# =====================================================================

func _unhandled_input(e: InputEvent) -> void:
	if _busy:
		return
	if _detail.visible:
		if e.is_action_pressed("ui_cancel") or e.is_action_pressed("ui_accept"):
			_close_detail()
		elif e.is_action_pressed("ui_down"):
			_scroll_detail(1)
		elif e.is_action_pressed("ui_up"):
			_scroll_detail(-1)
		return

	if e.is_action_pressed("ui_cancel"):
		_leave()
	elif e.is_action_pressed("ui_accept"):
		_open_detail()
	elif e.is_action_pressed("ui_left"):
		_move(-1, 0)
	elif e.is_action_pressed("ui_right"):
		_move(1, 0)
	elif e.is_action_pressed("ui_up"):
		_move(0, -1)
	elif e.is_action_pressed("ui_down"):
		_move(0, 1)
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_Q: _cycle_filter(-1)
			KEY_E: _cycle_filter(1)
			KEY_R: _cycle_sort()


func _leave() -> void:
	if _busy:
		return
	_busy = true
	Audio.sfx("cancel")
	if _back != "" and _back != "World":
		SceneFlow.goto(_back, {"back_map": _back_map, "back_pos": _back_pos})
	else:
		SceneFlow.goto("World", {"map": _back_map, "pos": _back_pos})
