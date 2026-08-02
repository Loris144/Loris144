extends Control
## Booster-Shop.
##
## Links die Liste aller Packs, rechts Beschreibung und eine Vorschau auf die
## Ultra-Raritäten. Gekaufte Packs werden in einem Overlay aufgedeckt: einzeln
## mit Flip-Animation, im 10er-Bundle als kompaktes Raster.

# ------------------------------------------------------------------ layout
const LIST_RECT := Rect2(4, 20, 196, 212)
const DETAIL_RECT := Rect2(204, 20, 272, 212)
const ROW_H := 14
const ROWS := 14
const LIST_ORIGIN := Vector2(8, 24)

const CARD_W := 100.0
const CARD_H := 146.0
const ART_OFFSET := Vector2(8, 21)

const RARITY_COLOR := {
	"common": UI.TEXT_DIM,
	"rare": UI.BLUE,
	"super": Color8(120, 220, 200),
	"ultra": UI.GOLD,
}

# ------------------------------------------------------------------ state
var _back_map := ""
var _back_pos := Vector2i(6, 6)

var _sel := 0
var _top := 0
var _buy_sel := 0            # 0 = 1 Pack, 1 = 10 Packs
var _mode := "browse"        # browse | reveal | done | leaving
var _skip := false

var _rows: Array = []        # [{root, button, name, cost}]
var _detail: Control
var _overlay: Control
var _dp_label: Label
var _msg_label: Label
var _page_label: Label
var _buy_buttons: Array[Button] = []
var _art_nodes: Dictionary = {}   # card_id -> Array[TextureRect]


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
	_build()
	Game.dp_changed.connect(_on_dp_changed)
	Art.card_image_ready.connect(_on_art_ready)


# =====================================================================
# build
# =====================================================================

func _build() -> void:
	add_child(UI.backdrop(Color8(12, 16, 30), Color8(30, 20, 44)))

	add_child(UI.rect(Rect2(0, 0, 480, 17), Color(0.05, 0.07, 0.13, 0.85)))
	var title := UI.label("BOOSTER-SHOP", UI.FS_M, UI.GOLD)
	title.position = Vector2(6, 1)
	title.size = Vector2(200, 15)
	add_child(title)

	_dp_label = UI.label("", UI.FS_M, UI.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_dp_label.position = Vector2(280, 1)
	_dp_label.size = Vector2(194, 15)
	add_child(_dp_label)

	add_child(UI.panel(LIST_RECT, UI.PANEL_DK, UI.EDGE))
	add_child(UI.panel(DETAIL_RECT, UI.PANEL_DK, UI.EDGE))

	_build_rows()

	_page_label = UI.label("", UI.FS_S, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_page_label.position = Vector2(LIST_RECT.position.x + 4, 219)
	_page_label.size = Vector2(LIST_RECT.size.x - 8, 10)
	add_child(_page_label)

	_detail = Control.new()
	_detail.position = DETAIL_RECT.position + Vector2(6, 5)
	_detail.size = DETAIL_RECT.size - Vector2(12, 10)
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_detail)

	var b1 := UI.button("1 Pack (%d DP)" % Game.PACK_COST, UI.FS_S)
	b1.position = Vector2(4, 236)
	b1.size = Vector2(128, 18)
	b1.focus_mode = Control.FOCUS_NONE
	b1.pressed.connect(_on_buy_pressed.bind(1))
	add_child(b1)
	_buy_buttons.append(b1)

	var b10 := UI.button("10 Packs (%d DP)" % (Game.PACK_COST * 10), UI.FS_S)
	b10.position = Vector2(136, 236)
	b10.size = Vector2(148, 18)
	b10.focus_mode = Control.FOCUS_NONE
	b10.pressed.connect(_on_buy_pressed.bind(10))
	add_child(b10)
	_buy_buttons.append(b10)

	var back := UI.button("Zurück", UI.FS_S)
	back.position = Vector2(414, 236)
	back.size = Vector2(62, 18)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_leave)
	add_child(back)

	_msg_label = UI.label("", UI.FS_S, UI.RED)
	_msg_label.position = Vector2(290, 236)
	_msg_label.size = Vector2(120, 18)
	add_child(_msg_label)

	var hint := UI.label(
			"Hoch/Runter Pack  •  Links/Rechts Menge  •  Enter kaufen  •  Esc zurück",
			UI.FS_S, UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(0, 257)
	hint.size = Vector2(480, 11)
	add_child(hint)

	_refresh_dp()
	_refresh_list()
	_refresh_buttons()
	_refresh_detail()


func _build_rows() -> void:
	for i in ROWS:
		var row := Control.new()
		row.position = LIST_ORIGIN + Vector2(0, i * ROW_H)
		row.size = Vector2(LIST_RECT.size.x - 8, ROW_H - 1)
		add_child(row)

		var b := Button.new()
		b.size = row.size
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("hover",
			UI.panel_style(UI.PANEL.lightened(0.08), UI.EDGE))
		b.add_theme_stylebox_override("pressed",
			UI.panel_style(UI.PANEL_DK, UI.EDGE_HI))
		b.add_theme_stylebox_override("focus",
			UI.panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
		b.pressed.connect(_on_row_pressed.bind(i))
		row.add_child(b)

		var nm := UI.label("", UI.FS_S, UI.TEXT)
		nm.position = Vector2(3, 0)
		nm.size = Vector2(row.size.x - 46, row.size.y)
		nm.clip_text = true
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(nm)

		var cost := UI.label("", UI.FS_S, UI.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		cost.position = Vector2(row.size.x - 44, 0)
		cost.size = Vector2(42, row.size.y)
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cost)

		_rows.append({"root": row, "button": b, "name": nm, "cost": cost})


# =====================================================================
# refresh
# =====================================================================

func _pack_count() -> int:
	return CardDB.packs.size()


func _pack(i: int) -> Dictionary:
	if i < 0 or i >= _pack_count():
		return {}
	return CardDB.packs[i]


func _on_dp_changed(_value: int) -> void:
	_refresh_dp()


func _refresh_dp() -> void:
	if is_instance_valid(_dp_label):
		_dp_label.text = "%d DP" % Game.dp


func _refresh_list() -> void:
	var total := _pack_count()
	if _sel < _top:
		_top = _sel
	elif _sel >= _top + ROWS:
		_top = _sel - ROWS + 1
	_top = clampi(_top, 0, maxi(0, total - ROWS))
	for i in _rows.size():
		var idx := _top + i
		var row: Dictionary = _rows[i]
		var vis := idx < total
		row["root"].visible = vis
		if not vis:
			continue
		var p: Dictionary = _pack(idx)
		var on := idx == _sel
		row["name"].text = str(p.get("name", "?"))
		row["name"].add_theme_color_override("font_color", UI.GOLD if on else UI.TEXT)
		row["cost"].text = "%d DP" % int(p.get("cost", Game.PACK_COST))
		var style: StyleBoxFlat
		if on:
			style = UI.panel_style(UI.PANEL.lightened(0.10), UI.GOLD)
		else:
			style = UI.panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0))
		row["button"].add_theme_stylebox_override("normal", style)
	if is_instance_valid(_page_label):
		_page_label.text = "%d / %d" % [mini(_sel + 1, total), total]


func _refresh_buttons() -> void:
	for i in _buy_buttons.size():
		var on := i == _buy_sel
		_buy_buttons[i].add_theme_stylebox_override("normal",
			UI.panel_style(UI.PANEL.lightened(0.14) if on else UI.PANEL,
				UI.GOLD if on else UI.EDGE))
		_buy_buttons[i].add_theme_color_override("font_color",
			UI.GOLD if on else UI.TEXT)


func _refresh_detail() -> void:
	if not is_instance_valid(_detail):
		return
	for c in _detail.get_children():
		c.queue_free()
	_art_nodes.clear()

	var p: Dictionary = _pack(_sel)
	if p.is_empty():
		var none := UI.label("Keine Packs verfügbar.", UI.FS_S, UI.TEXT_DIM)
		none.position = Vector2.ZERO
		none.size = Vector2(_detail.size.x, 12)
		_detail.add_child(none)
		return

	var nm := UI.rich("[b]%s[/b]" % str(p.get("name", "?")), UI.FS_M, UI.GOLD)
	nm.position = Vector2.ZERO
	nm.size = Vector2(_detail.size.x, 26)
	nm.fit_content = false
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(nm)

	var desc := UI.rich(str(p.get("desc", "")), UI.FS_S, UI.TEXT)
	desc.position = Vector2(0, 28)
	desc.size = Vector2(_detail.size.x, 54)
	desc.fit_content = false
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(desc)

	var pool: Dictionary = p.get("cards", {})
	var commons: Array = pool.get("common", [])
	var rares: Array = pool.get("rare", [])
	var supers: Array = pool.get("super", [])
	var ultras: Array = pool.get("ultra", [])
	var cl := UI.label("%d Common • %d Rare • %d Super • %d Ultra" % [
			commons.size(), rares.size(), supers.size(), ultras.size()],
			UI.FS_S, UI.TEXT_DIM)
	cl.position = Vector2(0, 84)
	cl.size = Vector2(_detail.size.x, 11)
	_detail.add_child(cl)

	var head := UI.label("Ultra-Raritäten in diesem Pack:", UI.FS_S, UI.GOLD)
	head.position = Vector2(0, 98)
	head.size = Vector2(_detail.size.x, 11)
	_detail.add_child(head)

	var preview: Array = ultras if not ultras.is_empty() else supers
	var shown: Array = []
	for i in mini(4, preview.size()):
		shown.append(int(preview[i]))

	if shown.is_empty():
		var empty := UI.label("(keine Vorschau verfügbar)", UI.FS_S, UI.TEXT_DIM)
		empty.position = Vector2(0, 114)
		empty.size = Vector2(_detail.size.x, 11)
		_detail.add_child(empty)
		return

	var s := 0.42
	var tw := CARD_W * s
	var gap := 10.0
	var total_w := shown.size() * tw + (shown.size() - 1) * gap
	var x0 := (_detail.size.x - total_w) * 0.5
	for i in shown.size():
		var id: int = shown[i]
		var pos := Vector2(x0 + i * (tw + gap), 112)
		var card := _card_node(id, s)
		card.position = pos
		_detail.add_child(card)
		var lbl := UI.label(CardDB.card_name(id), UI.FS_S, UI.TEXT,
				HORIZONTAL_ALIGNMENT_CENTER)
		lbl.position = pos + Vector2(-8, CARD_H * s + 2)
		lbl.size = Vector2(tw + 16, 20)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_detail.add_child(lbl)
		if Game.owned(id) > 0:
			var have := UI.label("im Besitz", UI.FS_S, UI.GREEN,
					HORIZONTAL_ALIGNMENT_CENTER)
			have.position = pos + Vector2(-8, CARD_H * s + 22)
			have.size = Vector2(tw + 16, 10)
			_detail.add_child(have)


# =====================================================================
# card widgets
# =====================================================================

## A card (frame + artwork) scaled down around its top-left corner, so the
## node's `position` is exactly where the card appears.
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
# input
# =====================================================================

func _unhandled_input(e: InputEvent) -> void:
	if _mode == "leaving":
		return
	if _mode == "reveal":
		if e.is_action_pressed("ui_accept") or e.is_action_pressed("ui_cancel"):
			_skip = true
		return
	if _mode == "done":
		if e.is_action_pressed("ui_accept") or e.is_action_pressed("ui_cancel"):
			Audio.sfx("confirm")
			_close_overlay()
		return

	if e.is_action_pressed("ui_cancel"):
		_leave()
	elif e.is_action_pressed("ui_down"):
		_move_sel(1)
	elif e.is_action_pressed("ui_up"):
		_move_sel(-1)
	elif e.is_action_pressed("ui_left"):
		_set_buy_sel(0)
	elif e.is_action_pressed("ui_right"):
		_set_buy_sel(1)
	elif e.is_action_pressed("ui_accept"):
		_buy(1 if _buy_sel == 0 else 10)
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_UP: _move_sel(-1)
			KEY_DOWN: _move_sel(1)
			KEY_LEFT: _set_buy_sel(0)
			KEY_RIGHT: _set_buy_sel(1)
			KEY_PAGEUP: _move_sel(-ROWS)
			KEY_PAGEDOWN: _move_sel(ROWS)
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_move_sel(-1)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_move_sel(1)


func _set_buy_sel(v: int) -> void:
	if _buy_sel == v:
		return
	_buy_sel = v
	Audio.sfx("cursor")
	_refresh_buttons()


func _move_sel(delta: int) -> void:
	var total := _pack_count()
	if total <= 0:
		return
	var nxt := clampi(_sel + delta, 0, total - 1)
	if nxt == _sel:
		return
	_sel = nxt
	Audio.sfx("cursor")
	_refresh_list()
	_refresh_detail()


func _on_row_pressed(row_index: int) -> void:
	if _mode != "browse":
		return
	var idx := _top + row_index
	if idx < 0 or idx >= _pack_count():
		return
	if idx == _sel:
		_buy(1 if _buy_sel == 0 else 10)
		return
	_sel = idx
	Audio.sfx("cursor")
	_refresh_list()
	_refresh_detail()


func _on_buy_pressed(count: int) -> void:
	_set_buy_sel(0 if count == 1 else 1)
	_buy(count)


func _leave() -> void:
	if _mode != "browse":
		return
	_mode = "leaving"
	Audio.sfx("cancel")
	SceneFlow.goto("Menu", {"back_map": _back_map, "back_pos": _back_pos})


func _message(text: String, color: Color = UI.RED) -> void:
	if not is_instance_valid(_msg_label):
		return
	_msg_label.text = text
	_msg_label.add_theme_color_override("font_color", color)
	var t := create_tween()
	t.tween_interval(2.2)
	t.tween_callback(_clear_message)


func _clear_message() -> void:
	if is_instance_valid(_msg_label):
		_msg_label.text = ""


# =====================================================================
# buying
# =====================================================================

func _buy(count: int) -> void:
	if _mode != "browse":
		return
	var p: Dictionary = _pack(_sel)
	if p.is_empty():
		return
	var cost := int(p.get("cost", Game.PACK_COST)) * count
	if not Game.spend_dp(cost):
		Audio.sfx("cancel")
		_message("Nicht genug DP.")
		return
	var pack_id := str(p.get("id", ""))
	var drawn: Array[int] = []
	for i in count:
		for id in CardDB.open_pack(pack_id):
			drawn.append(int(id))
	if drawn.is_empty():
		Game.add_dp(cost)
		_message("Dieses Pack ist leer.")
		return
	Audio.sfx("open")
	_mode = "reveal"
	_skip = false
	if count == 1:
		await _reveal_single(pack_id, drawn)
	else:
		await _reveal_grid(pack_id, drawn, count)


## Cards of the batch that the player does not own yet.
func _count_new(drawn: Array) -> int:
	var seen: Dictionary = {}
	var n := 0
	for id in drawn:
		var i := int(id)
		if Game.owned(i) <= 0 and not seen.has(i):
			n += 1
		seen[i] = true
	return n


func _new_flags(drawn: Array) -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for id in drawn:
		var i := int(id)
		var is_new: bool = Game.owned(i) <= 0 and not seen.has(i)
		seen[i] = true
		out.append(is_new)
	return out


func _make_overlay() -> Control:
	var o := Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	o.add_child(UI.rect(Rect2(0, 0, 480, 270), Color(0.02, 0.03, 0.06, 0.93)))
	add_child(o)
	_overlay = o
	return o


func _close_overlay() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_mode = "browse"
	_refresh_dp()
	_refresh_list()
	_refresh_detail()


func _wait(secs: float) -> void:
	var t := create_tween()
	t.tween_interval(secs)
	await t.finished


# ---------------------------------------------------------------- 1 pack

func _reveal_single(pack_id: String, drawn: Array) -> void:
	var news := _new_flags(drawn)
	var o := _make_overlay()

	var head := UI.label(str(CardDB.get_pack(pack_id).get("name", "Booster")),
			UI.FS_M, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	head.position = Vector2(0, 16)
	head.size = Vector2(480, 16)
	o.add_child(head)

	var s := 0.62
	var tw := CARD_W * s
	var th := CARD_H * s
	var gap := 8.0
	var total_w := drawn.size() * tw + (drawn.size() - 1) * gap
	var x0 := (480.0 - total_w) * 0.5
	var y0 := 54.0

	var slots: Array = []
	for i in drawn.size():
		var id: int = int(drawn[i])
		var pos := Vector2(x0 + i * (tw + gap), y0)
		var rarity := CardDB.rarity_of(pack_id, id)

		var glow := UI.rect(Rect2(pos - Vector2(3, 3), Vector2(tw + 6, th + 6)),
				RARITY_COLOR.get(rarity, UI.TEXT_DIM))
		glow.modulate.a = 0.0
		o.add_child(glow)

		# wrapper scaled around its centre so the flip looks like a rotation
		var slot := Control.new()
		slot.size = Vector2(CARD_W, CARD_H)
		slot.pivot_offset = Vector2(CARD_W, CARD_H) * 0.5
		slot.scale = Vector2(s, s)
		slot.position = pos - Vector2(CARD_W, CARD_H) * 0.5 * (1.0 - s)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		o.add_child(slot)

		var back := UI.texture(Art.card_back(), Vector2.ZERO)
		back.size = Vector2(CARD_W, CARD_H)
		slot.add_child(back)

		var face := _card_node(id, 1.0)
		face.visible = false
		slot.add_child(face)

		var nm := UI.label("", UI.FS_S, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		nm.position = Vector2(pos.x - 10, y0 + th + 4)
		nm.size = Vector2(tw + 20, 24)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		o.add_child(nm)

		var tag := UI.label("", UI.FS_S, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		tag.position = Vector2(pos.x - 10, y0 + th + 30)
		tag.size = Vector2(tw + 20, 10)
		o.add_child(tag)

		slots.append({"slot": slot, "back": back, "face": face, "glow": glow,
			"name": nm, "tag": tag, "id": id, "rarity": rarity,
			"new": bool(news[i])})

	var hint := UI.label("Enter = überspringen", UI.FS_S, UI.TEXT_DIM,
			HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(0, 246)
	hint.size = Vector2(480, 11)
	o.add_child(hint)

	for entry in slots:
		if not is_instance_valid(_overlay):
			return
		await _flip(entry, s)
		Game.add_card(int(entry["id"]))

	Game.save_game()
	if not is_instance_valid(_overlay):
		return
	hint.queue_free()
	_finish_overlay(o, _count_new(drawn), drawn.size())


func _flip(entry: Dictionary, s: float) -> void:
	var slot: Control = entry["slot"]
	var rarity: String = str(entry["rarity"])
	var special := rarity == "super" or rarity == "ultra"

	if _skip:
		_flip_midpoint(entry)
		slot.scale = Vector2(s, s)
	else:
		var t := create_tween()
		t.tween_property(slot, "scale:x", 0.02, 0.10).set_trans(Tween.TRANS_SINE)
		t.tween_callback(_flip_midpoint.bind(entry))
		t.tween_property(slot, "scale:x", s, 0.13) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await t.finished
	if not is_instance_valid(slot):
		return

	entry["name"].text = CardDB.card_name(int(entry["id"]))
	if bool(entry["new"]):
		entry["tag"].text = "NEU!"
		entry["tag"].add_theme_color_override("font_color", UI.GREEN)
	elif special:
		entry["tag"].text = rarity.to_upper()
		entry["tag"].add_theme_color_override("font_color",
			RARITY_COLOR.get(rarity, UI.GOLD))

	if special:
		var glow: ColorRect = entry["glow"]
		if is_instance_valid(glow):
			var g := glow.create_tween()
			g.set_loops(3)
			g.tween_property(glow, "modulate:a", 0.55, 0.12)
			g.tween_property(glow, "modulate:a", 0.20, 0.22)
		if rarity == "ultra":
			SceneFlow.flash(Color(1.0, 0.92, 0.6, 0.30), 0.30)

	if not _skip:
		await _wait(0.40 if special else 0.14)


func _flip_midpoint(entry: Dictionary) -> void:
	var back: TextureRect = entry["back"]
	var face: Control = entry["face"]
	if is_instance_valid(back):
		back.visible = false
	if is_instance_valid(face):
		face.visible = true
	Audio.sfx("card")


# ---------------------------------------------------------------- 10 packs

func _reveal_grid(pack_id: String, drawn: Array, packs_bought: int) -> void:
	var news := _new_flags(drawn)
	var o := _make_overlay()

	var head := UI.label("%d Packs – %s" % [packs_bought,
			str(CardDB.get_pack(pack_id).get("name", "Booster"))],
			UI.FS_M, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	head.position = Vector2(0, 10)
	head.size = Vector2(480, 15)
	o.add_child(head)

	var legend := UI.label("Goldener Rahmen = neu in deiner Sammlung", UI.FS_S,
			UI.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	legend.position = Vector2(0, 26)
	legend.size = Vector2(480, 10)
	o.add_child(legend)

	var cols := 10
	var s := 0.22
	var tw := CARD_W * s
	var th := CARD_H * s
	var gx := 3.0
	var gy := 2.0
	var rows := int(ceil(float(drawn.size()) / float(cols)))
	var grid_w := cols * tw + (cols - 1) * gx
	var x0 := (480.0 - grid_w) * 0.5
	var y0 := 38.0

	var tiles: Array = []
	for i in drawn.size():
		var id: int = int(drawn[i])
		var cx: int = i % cols
		var cy: int = i / cols
		var pos := Vector2(x0 + cx * (tw + gx), y0 + cy * (th + gy))
		var rarity := CardDB.rarity_of(pack_id, id)

		var holder := Control.new()
		holder.position = pos
		holder.size = Vector2(tw, th)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.modulate.a = 0.0
		o.add_child(holder)

		if bool(news[i]):
			holder.add_child(UI.rect(Rect2(-2, -2, tw + 4, th + 4), UI.GOLD))
		elif rarity == "ultra" or rarity == "super":
			holder.add_child(UI.rect(Rect2(-1, -1, tw + 2, th + 2),
				RARITY_COLOR.get(rarity, UI.EDGE)))

		var card := _card_node(id, s)
		card.position = Vector2.ZERO
		holder.add_child(card)
		tiles.append(holder)

	var hint := UI.label("Enter = überspringen", UI.FS_S, UI.TEXT_DIM,
			HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(0, minf(y0 + rows * (th + gy) + 3, 248.0))
	hint.size = Vector2(480, 11)
	o.add_child(hint)

	for i in tiles.size():
		if not is_instance_valid(_overlay):
			return
		var holder: Control = tiles[i]
		if _skip:
			holder.modulate.a = 1.0
		else:
			var t := holder.create_tween()
			t.tween_property(holder, "modulate:a", 1.0, 0.12)
			if i % cols == 0:
				Audio.sfx("card")
				await _wait(0.07)
		Game.add_card(int(drawn[i]))
	for holder in tiles:
		if is_instance_valid(holder):
			holder.modulate.a = 1.0

	Game.save_game()
	if not is_instance_valid(_overlay):
		return
	hint.queue_free()
	_finish_overlay(o, _count_new(drawn), drawn.size())


# ---------------------------------------------------------------- summary

func _finish_overlay(o: Control, new_count: int, total: int) -> void:
	_mode = "done"
	_skip = false
	var text := "Keine neue Karte dabei."
	var col := UI.TEXT_DIM
	if new_count == 1:
		text = "1 neue Karte!"
		col = UI.GREEN
	elif new_count > 1:
		text = "%d neue Karten!" % new_count
		col = UI.GREEN
	var sum_label := UI.label("%s   (%d Karten erhalten)" % [text, total],
			UI.FS_M, col, HORIZONTAL_ALIGNMENT_CENTER)
	sum_label.position = Vector2(0, 210)
	sum_label.size = Vector2(480, 16)
	o.add_child(sum_label)

	var dpl := UI.label("%d DP übrig" % Game.dp, UI.FS_S, UI.GOLD,
			HORIZONTAL_ALIGNMENT_CENTER)
	dpl.position = Vector2(0, 226)
	dpl.size = Vector2(480, 11)
	o.add_child(dpl)

	var cont := UI.button("Weiter", UI.FS_S)
	cont.position = Vector2(148, 240)
	cont.size = Vector2(80, 18)
	cont.focus_mode = Control.FOCUS_NONE
	cont.pressed.connect(_on_continue_pressed)
	o.add_child(cont)

	var again := UI.button("Nochmal kaufen", UI.FS_S)
	again.position = Vector2(234, 240)
	again.size = Vector2(98, 18)
	again.focus_mode = Control.FOCUS_NONE
	again.pressed.connect(_on_again_pressed)
	o.add_child(again)


func _on_continue_pressed() -> void:
	if _mode != "done":
		return
	Audio.sfx("confirm")
	_close_overlay()


func _on_again_pressed() -> void:
	if _mode != "done":
		return
	Audio.sfx("confirm")
	_close_overlay()
	_buy(1 if _buy_sel == 0 else 10)
