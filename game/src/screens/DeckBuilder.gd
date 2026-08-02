extends Control
## Deck-Baukasten.
##
## Links die Sammlung (nur freie Kopien), rechts das aktuelle Deck, getrennt in
## Main und Extra. Karten werden als kleine Kachel-Grids gezeigt; Filter und
## Namenssuche schränken die Sammlung ein.

# ------------------------------------------------------------------ layout
const COLL_RECT := Rect2(4, 33, 234, 194)
const MAIN_RECT := Rect2(242, 33, 234, 116)
const EXTRA_RECT := Rect2(242, 153, 234, 74)
const DETAIL_RECT := Rect2(4, 240, 472, 28)

const CARD_W := 100.0
const CARD_H := 146.0
const ART_OFFSET := Vector2(8, 21)

const MAIN_MIN := 40
const MAIN_MAX := 60
const EXTRA_MAX := 15
const MAX_COPIES := 3

const FILTERS := ["Alle", "Monster", "Zauber", "Fallen"]

const KIND_DE := {
	"normal": "Normal", "effect": "Effekt", "fusion": "Fusion",
	"synchro": "Synchro", "xyz": "XYZ", "link": "Link", "ritual": "Ritual",
	"pendulum": "Pendel", "continuous": "Fortlaufend", "equip": "Ausrüstung",
	"quick": "Schnellzauber", "field": "Feld", "counter": "Konter",
}

# ------------------------------------------------------------------ state
var _back_map := ""
var _back_pos := Vector2i(6, 6)

var _mode := "edit"           # edit | confirm | leaving
var _focus := "coll"          # coll | main | extra
var _filter := 0
var _search := ""

var _panes: Dictionary = {}
var _art_nodes: Dictionary = {}

var _main_label: Label
var _extra_label: Label
var _legal_label: Label
var _msg_label: Label
var _detail_name: Label
var _detail_type: Label
var _detail_text: Label
var _filter_buttons: Array[Button] = []
var _search_edit: LineEdit
var _confirm: Control


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
	mouse_filter = Control.MOUSE_FILTER_PASS
	_panes = {
		"coll": {
			"rect": COLL_RECT, "origin": Vector2(8, 45), "cols": 5, "rows": 3,
			"cell": Vector2(45, 60), "scale": 0.34, "top": 0, "sel": 0,
			"entries": [], "tiles": [], "node": null, "caption": null,
			"title": "SAMMLUNG",
		},
		"main": {
			"rect": MAIN_RECT, "origin": Vector2(246, 45), "cols": 5, "rows": 2,
			"cell": Vector2(45, 50), "scale": 0.28, "top": 0, "sel": 0,
			"entries": [], "tiles": [], "node": null, "caption": null,
			"title": "MAIN DECK",
		},
		"extra": {
			"rect": EXTRA_RECT, "origin": Vector2(246, 166), "cols": 5, "rows": 1,
			"cell": Vector2(45, 50), "scale": 0.28, "top": 0, "sel": 0,
			"entries": [], "tiles": [], "node": null, "caption": null,
			"title": "EXTRA DECK",
		},
	}
	_build()
	Art.card_image_ready.connect(_on_art_ready)


# =====================================================================
# build
# =====================================================================

func _build() -> void:
	add_child(UI.backdrop(Color8(12, 16, 30), Color8(24, 26, 48)))
	add_child(UI.rect(Rect2(0, 0, 480, 17), Color(0.05, 0.07, 0.13, 0.85)))

	var title := UI.label("DECK-BAUKASTEN", UI.FS_M, UI.GOLD)
	title.position = Vector2(6, 1)
	title.size = Vector2(140, 15)
	add_child(title)

	_main_label = UI.label("", UI.FS_M, UI.GREEN)
	_main_label.position = Vector2(150, 1)
	_main_label.size = Vector2(90, 15)
	add_child(_main_label)

	_extra_label = UI.label("", UI.FS_M, UI.TEXT)
	_extra_label.position = Vector2(240, 1)
	_extra_label.size = Vector2(90, 15)
	add_child(_extra_label)

	_legal_label = UI.label("", UI.FS_S, UI.GREEN, HORIZONTAL_ALIGNMENT_RIGHT)
	_legal_label.position = Vector2(320, 1)
	_legal_label.size = Vector2(154, 15)
	add_child(_legal_label)

	# ------------------------------------------------------------ filters
	for i in FILTERS.size():
		var b := UI.button(FILTERS[i], UI.FS_S)
		b.position = Vector2(4 + i * 46, 18)
		b.size = Vector2(44, 14)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_set_filter.bind(i))
		add_child(b)
		_filter_buttons.append(b)

	_search_edit = LineEdit.new()
	_search_edit.position = Vector2(192, 18)
	_search_edit.size = Vector2(100, 14)
	_search_edit.placeholder_text = "Suche…"
	_search_edit.add_theme_font_size_override("font_size", UI.FS_S)
	_search_edit.add_theme_color_override("font_color", UI.TEXT)
	_search_edit.add_theme_color_override("font_placeholder_color", UI.TEXT_DIM)
	_search_edit.add_theme_stylebox_override("normal",
		UI.panel_style(UI.PANEL_DK, UI.EDGE))
	_search_edit.add_theme_stylebox_override("focus",
		UI.panel_style(UI.PANEL_DK, UI.GOLD))
	_search_edit.text_changed.connect(_on_search_changed)
	_search_edit.text_submitted.connect(_on_search_submitted)
	add_child(_search_edit)

	var save := UI.button("Speichern & Zurück", UI.FS_S)
	save.position = Vector2(296, 18)
	save.size = Vector2(180, 14)
	save.focus_mode = Control.FOCUS_NONE
	save.pressed.connect(_try_leave)
	add_child(save)

	# ------------------------------------------------------------ panes
	for key in ["coll", "main", "extra"]:
		var p: Dictionary = _panes[key]
		var r: Rect2 = p["rect"]
		add_child(UI.panel(r, UI.PANEL_DK, UI.EDGE))
		var cap := UI.label("", UI.FS_S, UI.TEXT_DIM)
		cap.position = r.position + Vector2(4, 2)
		cap.size = Vector2(r.size.x - 8, 9)
		add_child(cap)
		p["caption"] = cap
		var cont := Control.new()
		cont.position = Vector2.ZERO
		cont.size = Vector2(480, 270)
		cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cont)
		p["node"] = cont

	# ------------------------------------------------------------ detail
	add_child(UI.panel(DETAIL_RECT, UI.PANEL_DK, UI.EDGE))
	_detail_name = UI.label("", UI.FS_S, UI.GOLD)
	_detail_name.position = DETAIL_RECT.position + Vector2(5, 1)
	_detail_name.size = Vector2(300, 9)
	_detail_name.clip_text = true
	add_child(_detail_name)

	_msg_label = UI.label("", UI.FS_S, UI.RED, HORIZONTAL_ALIGNMENT_RIGHT)
	_msg_label.position = DETAIL_RECT.position + Vector2(300, 1)
	_msg_label.size = Vector2(167, 9)
	add_child(_msg_label)

	_detail_type = UI.label("", UI.FS_S, UI.BLUE)
	_detail_type.position = DETAIL_RECT.position + Vector2(5, 10)
	_detail_type.size = Vector2(462, 9)
	_detail_type.clip_text = true
	add_child(_detail_type)

	_detail_text = UI.label("", UI.FS_S, UI.TEXT_DIM)
	_detail_text.position = DETAIL_RECT.position + Vector2(5, 19)
	_detail_text.size = Vector2(462, 9)
	_detail_text.clip_text = true
	add_child(_detail_text)

	var hint := UI.label(
			"Pfeile bewegen  •  Enter hinzufügen/entfernen  •  Tab Filter  •  Esc speichern",
			UI.FS_S, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(0, 229)
	hint.size = Vector2(480, 10)
	add_child(hint)

	_refresh_filters()
	_rebuild_all()


# =====================================================================
# data
# =====================================================================

func _sorted(ids: Array) -> Array:
	var arr := ids.duplicate()
	arr.sort_custom(_compare_cards)
	return arr


func _cat_rank(id: int) -> int:
	if CardDB.is_monster(id):
		return 0
	if CardDB.is_spell(id):
		return 1
	return 2


func _compare_cards(a: int, b: int) -> bool:
	var ra := _cat_rank(a)
	var rb := _cat_rank(b)
	if ra != rb:
		return ra < rb
	var la := CardDB.level(a)
	var lb := CardDB.level(b)
	if la != lb:
		return la < lb
	return CardDB.card_name(a).naturalnocasecmp_to(CardDB.card_name(b)) < 0


func _passes_filter(id: int) -> bool:
	match _filter:
		1: if not CardDB.is_monster(id): return false
		2: if not CardDB.is_spell(id): return false
		3: if not CardDB.is_trap(id): return false
	if _search != "":
		if CardDB.card_name(id).to_lower().find(_search) < 0:
			return false
	return true


func _collection_entries() -> Array:
	var out: Array = []
	for k in Game.collection.keys():
		var id := int(k)
		if Game.available(id) <= 0:
			continue
		if not _passes_filter(id):
			continue
		out.append(id)
	return _sorted(out)


func _deck_entries(deck: Array) -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for c in deck:
		var id := int(c)
		if not seen.has(id):
			seen[id] = true
			out.append(id)
	return _sorted(out)


func _count_in(deck: Array, id: int) -> int:
	var n := 0
	for c in deck:
		if int(c) == id:
			n += 1
	return n


func _copies_in_deck(id: int) -> int:
	return _count_in(Game.deck_main, id) + _count_in(Game.deck_extra, id)


func _entry_count(key: String, id: int) -> int:
	match key:
		"main": return _count_in(Game.deck_main, id)
		"extra": return _count_in(Game.deck_extra, id)
	return Game.available(id)


# =====================================================================
# rebuild
# =====================================================================

func _rebuild_all() -> void:
	_panes["coll"]["entries"] = _collection_entries()
	_panes["main"]["entries"] = _deck_entries(Game.deck_main)
	_panes["extra"]["entries"] = _deck_entries(Game.deck_extra)
	for key in ["coll", "main", "extra"]:
		var p: Dictionary = _panes[key]
		var n: int = (p["entries"] as Array).size()
		p["sel"] = clampi(int(p["sel"]), 0, maxi(0, n - 1))
		_build_tiles(key)
	if (_panes[_focus]["entries"] as Array).is_empty():
		for key in ["coll", "main", "extra"]:
			if not (_panes[key]["entries"] as Array).is_empty():
				_focus = key
				break
	_refresh_header()
	_refresh_highlight()
	_refresh_detail()


func _build_tiles(key: String) -> void:
	var p: Dictionary = _panes[key]
	var cont: Control = p["node"]
	for c in cont.get_children():
		c.queue_free()
	p["tiles"] = []

	var entries: Array = p["entries"]
	var cols: int = p["cols"]
	var rows: int = p["rows"]
	var cell: Vector2 = p["cell"]
	var origin: Vector2 = p["origin"]
	var s: float = p["scale"]
	var per_page := cols * rows

	# keep the selection on screen
	var sel: int = int(p["sel"])
	var top: int = int(p["top"])
	var sel_row := 0 if entries.is_empty() else sel / cols
	var max_row: int = maxi(0, int(ceil(float(entries.size()) / float(cols))) - rows)
	if sel_row < top:
		top = sel_row
	elif sel_row >= top + rows:
		top = sel_row - rows + 1
	top = clampi(top, 0, max_row)
	p["top"] = top

	if entries.is_empty():
		var empty := UI.label(_empty_text(key), UI.FS_S, UI.TEXT_DIM)
		empty.position = origin + Vector2(2, 8)
		empty.size = Vector2(cell.x * cols - 4, 20)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		cont.add_child(empty)
		return

	var first := top * cols
	var last: int = mini(entries.size(), first + per_page)
	for i in range(first, last):
		var id: int = int(entries[i])
		var slot := i - first
		var pos := origin + Vector2((slot % cols) * cell.x, (slot / cols) * cell.y)
		var tw := CARD_W * s
		var th := CARD_H * s
		var cx := pos.x + (cell.x - tw) * 0.5

		var holder := Control.new()
		holder.position = Vector2(cx, pos.y)
		holder.size = Vector2(tw, th)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cont.add_child(holder)

		var border := UI.rect(Rect2(-2, -2, tw + 4, th + 4), Color(0, 0, 0, 0))
		holder.add_child(border)

		var card := _card_node(id, s)
		holder.add_child(card)

		var count := _entry_count(key, id)
		if count > 1:
			var badge := UI.rect(Rect2(tw - 15, th - 10, 15, 10),
					Color(0.05, 0.06, 0.1, 0.9))
			holder.add_child(badge)
			var cl := UI.label("x%d" % count, UI.FS_S, UI.GOLD,
					HORIZONTAL_ALIGNMENT_CENTER)
			cl.position = Vector2(tw - 15, th - 10)
			cl.size = Vector2(15, 10)
			holder.add_child(cl)

		var nm := UI.label(CardDB.card_name(id), UI.FS_S, UI.TEXT,
				HORIZONTAL_ALIGNMENT_CENTER)
		nm.position = Vector2(pos.x, pos.y + th + 1)
		nm.size = Vector2(cell.x, maxf(8.0, cell.y - th - 1))
		nm.clip_text = true
		cont.add_child(nm)

		# invisible click target on top of the tile
		var btn := Button.new()
		btn.flat = true
		btn.position = Vector2(pos.x, pos.y)
		btn.size = Vector2(cell.x, cell.y - 1)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_on_tile_pressed.bind(key, i))
		cont.add_child(btn)

		(p["tiles"] as Array).append({"index": i, "border": border,
			"name": nm, "id": id})


func _empty_text(key: String) -> String:
	match key:
		"main": return "Noch keine Karten im Main Deck."
		"extra": return "Extra Deck ist leer."
	if Game.collection.is_empty():
		return "Deine Sammlung ist leer – kauf Booster im Shop!"
	return "Keine Karte passt zu Filter/Suche."


func _refresh_header() -> void:
	var m := Game.deck_main.size()
	var x := Game.deck_extra.size()
	_main_label.text = "Main %d/%d" % [m, MAIN_MIN]
	_main_label.add_theme_color_override("font_color",
		UI.GREEN if (m >= MAIN_MIN and m <= MAIN_MAX) else UI.RED)
	_extra_label.text = "Extra %d/%d" % [x, EXTRA_MAX]
	_extra_label.add_theme_color_override("font_color",
		UI.TEXT if x <= EXTRA_MAX else UI.RED)
	if Game.deck_is_legal():
		_legal_label.text = "Deck ist regelkonform"
		_legal_label.add_theme_color_override("font_color", UI.GREEN)
	elif m < MAIN_MIN:
		_legal_label.text = "Noch %d Karten bis 40" % (MAIN_MIN - m)
		_legal_label.add_theme_color_override("font_color", UI.RED)
	else:
		_legal_label.text = "Deck ist nicht regelkonform"
		_legal_label.add_theme_color_override("font_color", UI.RED)

	for key in ["coll", "main", "extra"]:
		var p: Dictionary = _panes[key]
		var entries: Array = p["entries"]
		var cols: int = p["cols"]
		var per_page: int = cols * int(p["rows"])
		var first: int = int(p["top"]) * cols
		var last: int = mini(entries.size(), first + per_page)
		var mark := "> " if _focus == key else ""
		var range_txt := ""
		if entries.size() > per_page:
			range_txt = "   %d-%d von %d" % [first + 1, last, entries.size()]
		elif not entries.is_empty():
			range_txt = "   %d Einträge" % entries.size()
		var cap: Label = p["caption"]
		cap.text = "%s%s%s" % [mark, str(p["title"]), range_txt]
		cap.add_theme_color_override("font_color",
			UI.GOLD if _focus == key else UI.TEXT_DIM)


func _refresh_highlight() -> void:
	for key in ["coll", "main", "extra"]:
		var p: Dictionary = _panes[key]
		for t in p["tiles"]:
			var on: bool = int(t["index"]) == int(p["sel"])
			var col := Color(0, 0, 0, 0)
			if on:
				col = UI.GOLD if _focus == key else UI.EDGE
			if is_instance_valid(t["border"]):
				t["border"].color = col
			if is_instance_valid(t["name"]):
				t["name"].add_theme_color_override("font_color",
					UI.GOLD if on else UI.TEXT)


func _current_id() -> int:
	var p: Dictionary = _panes[_focus]
	var entries: Array = p["entries"]
	var sel: int = int(p["sel"])
	if sel < 0 or sel >= entries.size():
		return 0
	return int(entries[sel])


func _refresh_detail() -> void:
	var id := _current_id()
	if id == 0:
		_detail_name.text = "—"
		_detail_type.text = ""
		_detail_text.text = ""
		return
	_detail_name.text = CardDB.card_name(id)
	var k := str(KIND_DE.get(CardDB.kind(id), CardDB.kind(id)))
	if CardDB.is_monster(id):
		_detail_type.text = "%s-Monster • %s / %s • Stufe %d • ATK %d / DEF %d" % [
			k, CardDB.attribute(id), CardDB.race(id), CardDB.level(id),
			CardDB.atk(id), CardDB.def(id)]
	elif CardDB.is_spell(id):
		_detail_type.text = "Zauberkarte • %s" % k
	else:
		_detail_type.text = "Fallenkarte • %s" % k
	var t := CardDB.text(id).replace("\n", " ")
	if t.length() > 150:
		t = t.substr(0, 149) + "…"
	_detail_text.text = t


func _message(text: String, color: Color = UI.RED) -> void:
	if not is_instance_valid(_msg_label):
		return
	_msg_label.text = text
	_msg_label.add_theme_color_override("font_color", color)
	var t := create_tween()
	t.tween_interval(2.0)
	t.tween_callback(_clear_message)


func _clear_message() -> void:
	if is_instance_valid(_msg_label):
		_msg_label.text = ""


# =====================================================================
# card widgets
# =====================================================================

func _card_node(id: int, s: float) -> Control:
	var root := Control.new()
	root.size = Vector2(CARD_W, CARD_H)
	root.pivot_offset = Vector2.ZERO
	root.scale = Vector2(s, s)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(UI.texture(Art.card_frame(CardDB.frame_kind(id)), Vector2.ZERO))
	var art := UI.texture(Art.card_art(id), ART_OFFSET)
	art.size = Vector2(Art.ART_W, Art.ART_H)
	root.add_child(art)
	if not _art_nodes.has(id):
		_art_nodes[id] = []
	_art_nodes[id].append(art)
	return root


func _on_art_ready(card_id: int) -> void:
	if not _art_nodes.has(card_id):
		return
	var tex := Art.card_art(card_id)
	var keep: Array = []
	for n in _art_nodes[card_id]:
		if is_instance_valid(n):
			n.texture = tex
			keep.append(n)
	_art_nodes[card_id] = keep


# =====================================================================
# editing
# =====================================================================

func _activate() -> void:
	var id := _current_id()
	if id == 0:
		return
	if _focus == "coll":
		_add_card(id)
	else:
		_remove_card(_focus, id)


func _add_card(id: int) -> void:
	if Game.available(id) <= 0:
		Audio.sfx("cancel")
		_message("Keine freie Kopie mehr.")
		return
	if _copies_in_deck(id) >= MAX_COPIES:
		Audio.sfx("cancel")
		_message("Maximal %d Kopien pro Karte." % MAX_COPIES)
		return
	if CardDB.is_extra_deck(id):
		if Game.deck_extra.size() >= EXTRA_MAX:
			Audio.sfx("cancel")
			_message("Extra Deck ist voll (%d)." % EXTRA_MAX)
			return
		Game.deck_extra.append(id)
	else:
		if Game.deck_main.size() >= MAIN_MAX:
			Audio.sfx("cancel")
			_message("Main Deck ist voll (%d)." % MAIN_MAX)
			return
		Game.deck_main.append(id)
	Audio.sfx("card")
	_rebuild_all()


func _remove_card(key: String, id: int) -> void:
	if key == "extra":
		if not Game.deck_extra.has(id):
			return
		Game.deck_extra.erase(id)
	else:
		if not Game.deck_main.has(id):
			return
		Game.deck_main.erase(id)
	Audio.sfx("cancel")
	_rebuild_all()


func _on_tile_pressed(key: String, index: int) -> void:
	if _mode != "edit":
		return
	var p: Dictionary = _panes[key]
	var entries: Array = p["entries"]
	if index < 0 or index >= entries.size():
		return
	if _focus == key and int(p["sel"]) == index:
		_activate()
		return
	_focus = key
	p["sel"] = index
	Audio.sfx("cursor")
	_refresh_header()
	_refresh_highlight()
	_refresh_detail()


# =====================================================================
# filters & search
# =====================================================================

func _set_filter(i: int) -> void:
	if _filter == i:
		return
	_filter = i
	Audio.sfx("cursor")
	_panes["coll"]["sel"] = 0
	_panes["coll"]["top"] = 0
	_refresh_filters()
	_rebuild_all()


func _refresh_filters() -> void:
	for i in _filter_buttons.size():
		var on := i == _filter
		_filter_buttons[i].add_theme_stylebox_override("normal",
			UI.panel_style(UI.PANEL.lightened(0.14) if on else UI.PANEL,
				UI.GOLD if on else UI.EDGE))
		_filter_buttons[i].add_theme_color_override("font_color",
			UI.GOLD if on else UI.TEXT)


func _on_search_changed(text: String) -> void:
	_search = text.strip_edges().to_lower()
	_panes["coll"]["sel"] = 0
	_panes["coll"]["top"] = 0
	_focus = "coll"
	_rebuild_all()


func _on_search_submitted(_text: String) -> void:
	_search_edit.release_focus()


# =====================================================================
# navigation
# =====================================================================

func _move(dx: int, dy: int) -> void:
	var p: Dictionary = _panes[_focus]
	var entries: Array = p["entries"]
	var cols: int = p["cols"]
	if entries.is_empty():
		return
	var sel: int = int(p["sel"])
	var col := sel % cols
	var row: int = sel / cols
	var last_row: int = (entries.size() - 1) / cols

	if dx != 0:
		var nxt := sel + dx
		if dx > 0 and (col == cols - 1 or nxt >= entries.size()):
			if _focus == "coll":
				_switch_pane("main", 0)
				return
		elif dx < 0 and col == 0:
			if _focus != "coll":
				_switch_pane("coll", -1)
				return
		if nxt >= 0 and nxt < entries.size():
			p["sel"] = nxt
			_after_move()
		return

	if dy != 0:
		var nrow := row + dy
		if nrow < 0:
			if _focus == "extra":
				_switch_pane("main", -1)
			return
		if nrow > last_row:
			if _focus == "main":
				_switch_pane("extra", 0)
			return
		var nxt: int = mini(nrow * cols + col, entries.size() - 1)
		p["sel"] = nxt
		_after_move()


## Move the cursor to another pane; `where` -1 means "last entry".
func _switch_pane(key: String, where: int) -> void:
	var p: Dictionary = _panes[key]
	var entries: Array = p["entries"]
	if entries.is_empty():
		return
	_focus = key
	if where < 0:
		p["sel"] = entries.size() - 1
	else:
		p["sel"] = clampi(int(p["sel"]), 0, entries.size() - 1)
	_after_move()


func _after_move() -> void:
	Audio.sfx("cursor")
	_build_tiles(_focus)
	_refresh_header()
	_refresh_highlight()
	_refresh_detail()


func _cycle_focus() -> void:
	var order := ["coll", "main", "extra"]
	var i := order.find(_focus)
	for step in range(1, 4):
		var key: String = order[(i + step) % order.size()]
		if not (_panes[key]["entries"] as Array).is_empty():
			_switch_pane(key, 0)
			return


# =====================================================================
# input
# =====================================================================

## Tab would otherwise be swallowed by the GUI focus navigation.
func _input(e: InputEvent) -> void:
	if _mode != "edit" or _search_edit == null or _search_edit.has_focus():
		return
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_TAB:
		_set_filter((_filter + 1) % FILTERS.size())
		get_viewport().set_input_as_handled()


func _unhandled_input(e: InputEvent) -> void:
	if _mode == "leaving":
		return
	if _mode == "confirm":
		if e.is_action_pressed("ui_accept"):
			_do_leave()
		elif e.is_action_pressed("ui_cancel"):
			_close_confirm()
		return
	if _search_edit.has_focus():
		if e.is_action_pressed("ui_cancel"):
			_search_edit.release_focus()
		return

	if e.is_action_pressed("ui_cancel"):
		_try_leave()
	elif e.is_action_pressed("ui_accept"):
		_activate()
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
			KEY_LEFT: _move(-1, 0)
			KEY_RIGHT: _move(1, 0)
			KEY_UP: _move(0, -1)
			KEY_DOWN: _move(0, 1)
			KEY_SLASH: _search_edit.grab_focus()
			KEY_F: _search_edit.grab_focus()
			KEY_Q: _cycle_focus()


# =====================================================================
# leaving
# =====================================================================

func _try_leave() -> void:
	if _mode != "edit":
		return
	if Game.deck_is_legal():
		_do_leave()
		return
	_show_confirm()


func _show_confirm() -> void:
	_mode = "confirm"
	Audio.sfx("cancel")
	var o := Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	o.add_child(UI.rect(Rect2(0, 0, 480, 270), Color(0.02, 0.03, 0.06, 0.8)))
	add_child(o)
	_confirm = o

	var box := UI.box(Rect2(90, 92, 300, 86), "Achtung")
	o.add_child(box)

	var why := "Main Deck: %d Karten (40-60 nötig), Extra: %d/%d." % [
			Game.deck_main.size(), Game.deck_extra.size(), EXTRA_MAX]
	var l1 := UI.label("Dein Deck ist nicht regelkonform.", UI.FS_S, UI.RED,
			HORIZONTAL_ALIGNMENT_CENTER)
	l1.position = Vector2(100, 116)
	l1.size = Vector2(280, 11)
	o.add_child(l1)

	var l2 := UI.label(why, UI.FS_S, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	l2.position = Vector2(100, 128)
	l2.size = Vector2(280, 11)
	o.add_child(l2)

	var l3 := UI.label("Trotzdem speichern und zurück?", UI.FS_S, UI.TEXT,
			HORIZONTAL_ALIGNMENT_CENTER)
	l3.position = Vector2(100, 140)
	l3.size = Vector2(280, 11)
	o.add_child(l3)

	var yes := UI.button("Ja (Enter)", UI.FS_S)
	yes.position = Vector2(118, 154)
	yes.size = Vector2(110, 16)
	yes.focus_mode = Control.FOCUS_NONE
	yes.pressed.connect(_do_leave)
	o.add_child(yes)

	var no := UI.button("Nein (Esc)", UI.FS_S)
	no.position = Vector2(252, 154)
	no.size = Vector2(110, 16)
	no.focus_mode = Control.FOCUS_NONE
	no.pressed.connect(_close_confirm)
	o.add_child(no)


func _close_confirm() -> void:
	if is_instance_valid(_confirm):
		_confirm.queue_free()
	_confirm = null
	_mode = "edit"
	Audio.sfx("cancel")


func _do_leave() -> void:
	if _mode == "leaving":
		return
	_mode = "leaving"
	Audio.sfx("confirm")
	Game.save_game()
	SceneFlow.goto("Menu", {"back_map": _back_map, "back_pos": _back_pos})
