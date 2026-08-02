extends Node2D
## The overworld: renders a map, moves the player on a grid, runs NPCs,
## warps and story triggers.

const TS := 16
const VIEW := Vector2(480, 270)
const WALK_TIME := 0.16

var map_id := "player_home"
var map_def: Dictionary = {}
var grid: Array = []              # [y][x] -> tile name
var solid: Array = []             # [y][x] -> bool
var overlay: Array = []           # [y][x] -> tile name drawn above the player
var mw := 0
var mh := 0

var player_cell := Vector2i(4, 4)
var player_dir := "down"
var player_px := Vector2.ZERO
var _moving := false
var _anim_t := 0.0
var _frame := 0
var _input_locked := false

var npcs: Array = []              # dicts with runtime state
var _cam := Vector2.ZERO

var _world: Node2D
var _hud: CanvasLayer
var _banner: Label
var _dp_label: Label
var _name_label: Label
var _touch: Control


func setup(args: Dictionary) -> void:
	map_id = str(args.get("map", Game.current_map))
	var p = args.get("pos", null)
	if p is Vector2i:
		player_cell = p
	elif p is Array and p.size() == 2:
		player_cell = Vector2i(int(p[0]), int(p[1]))
	else:
		player_cell = Game.spawn_pos


func _ready() -> void:
	_world = Node2D.new()
	add_child(_world)
	_build_hud()
	load_map(map_id, player_cell)
	set_process(true)
	set_process_unhandled_input(true)


# =====================================================================
# map loading
# =====================================================================

func load_map(id: String, cell: Vector2i) -> void:
	if not Maps.exists(id):
		push_error("[World] unknown map %s" % id)
		return
	map_id = id
	map_def = Maps.get_map(id)
	Game.current_map = id
	_build_grid()
	cell += pad
	Game.spawn_pos = cell - pad
	player_cell = cell
	player_px = Vector2(cell) * TS
	_spawn_npcs()
	Audio.play_music(str(map_def.get("music", "town")))
	_name_label.text = str(map_def.get("name", ""))
	_show_name()
	_update_camera(true)
	queue_redraw()
	# a trigger may fire the moment we arrive
	await get_tree().process_frame
	_check_triggers(true)


## Maps are authored compactly; anything smaller than the viewport gets
## padded out so the screen is always filled. `pad` is the offset applied to
## every authored coordinate (warps, NPCs, triggers, buildings, spawn).
const MIN_W := 31
const MIN_H := 18

var pad := Vector2i.ZERO


func _build_grid() -> void:
	var layout: Array = map_def.get("layout", [])
	var legend: Dictionary = map_def.get("legend", {})
	var ground := str(map_def.get("ground", "grass"))
	var indoor := bool(map_def.get("indoor", false))
	var raw_h := layout.size()
	var raw_w := 0
	for row in layout:
		raw_w = maxi(raw_w, str(row).length())

	mw = maxi(raw_w, MIN_W)
	mh = maxi(raw_h, MIN_H)
	pad = Vector2i((mw - raw_w) / 2, (mh - raw_h) / 2)
	# indoors the surround is black void; outdoors the terrain continues
	var filler := "void" if indoor else str(map_def.get("surround", ground))

	grid = []
	solid = []
	overlay = []
	for y in mh:
		var grow: Array = []
		var srow: Array = []
		var orow: Array = []
		var ly := y - pad.y
		var line := str(layout[ly]) if (ly >= 0 and ly < raw_h) else ""
		for x in mw:
			var lx := x - pad.x
			var name := filler
			if line != "" and lx >= 0 and lx < line.length():
				name = _tile_for(line[lx], ground, legend)
			elif ly >= 0 and ly < raw_h and lx >= 0 and lx < raw_w:
				name = _tile_for(" ", ground, legend)
			grow.append(name)
			srow.append(TileGfx.is_solid(name))
			orow.append("")
		grid.append(grow)
		solid.append(srow)
		overlay.append(orow)

	# keep the player inside the padded area
	if not indoor:
		for x in mw:
			solid[0][x] = true
			solid[mh - 1][x] = true
		for y in mh:
			solid[y][0] = true
			solid[y][mw - 1] = true

	# trees are two tiles tall: canopy sits on the row above the trunk
	for y in mh:
		for x in mw:
			if grid[y][x] == "tree_bottom" and y > 0:
				overlay[y - 1][x] = "tree_top"
				solid[y - 1][x] = true
			elif grid[y][x] == "palm_bottom" and y > 0:
				overlay[y - 1][x] = "palm_top"
				solid[y - 1][x] = true

	_apply_buildings()
	# doors are walkable so the warp underneath can fire
	for w in map_def.get("warps", []):
		var wx := int(w.get("x", 0)) + pad.x
		var wy := int(w.get("y", 0)) + pad.y
		if wy >= 0 and wy < mh and wx >= 0 and wx < mw:
			solid[wy][wx] = false


func _tile_for(ch: String, ground: String, legend: Dictionary) -> String:
	if legend.has(ch):
		return str(legend[ch])
	match ch:
		".": return ground
		",": return "grass2" if ground == "grass" else ground
		" ": return "void"
		"#": return "wall"
		"T": return "tree_bottom"
		"P": return "palm_bottom"
		"~": return "water"
		"^": return "cliff"
		"_": return "stone_path"
		"=": return "road"
		"-": return "road_line"
		":": return "sidewalk"
		"%": return "sand_dune"
		"b": return "bush"
		"r": return "rock"
		"f": return "fence"
		"s": return "sign"
		"l": return "lamp"
		"D": return "door"
		"W": return "window"
		"H": return "hieroglyph"
		"p": return "pillar"
		"*": return "flowers"
		"\"": return "tall_grass"
	return ground


func _apply_buildings() -> void:
	for b in map_def.get("buildings", []):
		var bx := int(b.get("x", 0)) + pad.x
		var by := int(b.get("y", 0)) + pad.y
		var bw := int(b.get("w", 4))
		var bh := int(b.get("h", 3))
		var roof := str(b.get("roof", "roof_red"))
		var door := int(b.get("door", -1))
		for y in range(by, mini(by + bh, mh)):
			for x in range(bx, mini(bx + bw, mw)):
				if y < 0 or x < 0:
					continue
				var is_roof := y < by + bh - 1
				grid[y][x] = roof if is_roof else "wall"
				solid[y][x] = true
			if y == by + bh - 2 and y >= 0:
				for x in range(bx, mini(bx + bw, mw)):
					grid[y][x] = roof.replace("roof_", "roof_") + "_edge" \
						if TileGfx.has(roof + "_edge") else roof
		# window row + door
		var wall_y := by + bh - 1
		if wall_y >= 0 and wall_y < mh:
			for x in range(bx + 1, mini(bx + bw - 1, mw), 2):
				grid[wall_y][x] = "window"
			door += pad.x
			if door >= 0 and door < mw:
				grid[wall_y][door] = "door"
				solid[wall_y][door] = false


func _spawn_npcs() -> void:
	for n in npcs:
		if is_instance_valid(n.get("node")):
			n["node"].queue_free()
	npcs.clear()
	for def in map_def.get("npcs", []):
		var d: Dictionary = def.duplicate(true)
		if d.has("require") and not Game.has_flag(str(d["require"])):
			continue
		if d.has("hide_if") and Game.has_flag(str(d["hide_if"])):
			continue
		if d.get("duelist", false) and Game.has_flag("beat_%s_%s" % [map_id, d.get("name", "")]):
			pass  # keep them around for rematches
		d["cell"] = Vector2i(int(d.get("x", 0)), int(d.get("y", 0))) + pad
		npcs.append(d)
		if bool(d.get("solid", true)):
			var c: Vector2i = d["cell"]
			if c.y >= 0 and c.y < mh and c.x >= 0 and c.x < mw:
				solid[c.y][c.x] = true


# =====================================================================
# HUD
# =====================================================================

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 5
	add_child(_hud)

	var top := UI.rect(Rect2(0, 0, 480, 16), Color(0.05, 0.07, 0.12, 0.8))
	_hud.add_child(top)

	_banner = UI.label("", UI.FS_S, UI.GOLD)
	_banner.position = Vector2(6, 1)
	_banner.size = Vector2(340, 14)
	_hud.add_child(_banner)

	_dp_label = UI.label("", UI.FS_S, UI.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_dp_label.position = Vector2(340, 1)
	_dp_label.size = Vector2(134, 14)
	_hud.add_child(_dp_label)

	_name_label = UI.label("", UI.FS_M, UI.TEXT)
	_name_label.position = Vector2(8, 22)
	_name_label.size = Vector2(300, 16)
	_name_label.modulate.a = 0.0
	_hud.add_child(_name_label)

	_build_touch()
	_refresh_hud()
	Game.dp_changed.connect(func(_v): _refresh_hud())
	Game.objective_changed.connect(func(_t): _refresh_hud())


func _refresh_hud() -> void:
	_banner.text = ("► " + Game.objective) if Game.objective != "" else ""
	_dp_label.text = "%d DP   [M] Menü" % Game.dp


func _show_name() -> void:
	_name_label.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(1.6)
	t.tween_property(_name_label, "modulate:a", 0.0, 0.5)


func _build_touch() -> void:
	_touch = Control.new()
	_touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	_touch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_touch)
	if not bool(Game.settings.get("touch_controls", true)):
		_touch.visible = false
	var pad_tex := Art.ui("dpad")
	var pr := TextureRect.new()
	pr.texture = pad_tex
	pr.position = Vector2(8, 270 - 128)
	pr.size = Vector2(120, 120)
	pr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pr.modulate.a = 0.55
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_touch.add_child(pr)
	for spec in [["ui_up", 40, 0, 40, 40], ["ui_down", 40, 80, 40, 40],
			["ui_left", 0, 40, 40, 40], ["ui_right", 80, 40, 40, 40]]:
		var b := Button.new()
		b.flat = true
		b.position = Vector2(8 + int(spec[1]), 270 - 128 + int(spec[2]))
		b.size = Vector2(int(spec[3]), int(spec[4]))
		b.button_down.connect(func(): _touch_dir = str(spec[0]))
		b.button_up.connect(func(): if _touch_dir == str(spec[0]): _touch_dir = "")
		_touch.add_child(b)
	var a := Button.new()
	a.text = "A"
	a.position = Vector2(480 - 76, 270 - 76)
	a.size = Vector2(60, 60)
	a.add_theme_font_size_override("font_size", 16)
	a.add_theme_stylebox_override("normal", UI.panel_style(Color(0.3, 0.5, 0.8, 0.5), UI.EDGE_HI, 2, 30))
	a.pressed.connect(_interact)
	_touch.add_child(a)
	var m := Button.new()
	m.text = "Menü"
	m.position = Vector2(480 - 76, 270 - 140)
	m.size = Vector2(60, 26)
	m.add_theme_font_size_override("font_size", 9)
	m.add_theme_stylebox_override("normal", UI.panel_style(Color(0.3, 0.35, 0.5, 0.5), UI.EDGE, 2, 8))
	m.pressed.connect(_open_menu)
	_touch.add_child(m)


var _touch_dir := ""


# =====================================================================
# input & movement
# =====================================================================

func _unhandled_input(e: InputEvent) -> void:
	if _input_locked:
		return
	if e.is_action_pressed("ui_accept"):
		_interact()
	elif e.is_action_pressed("ui_cancel"):
		_open_menu()
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_M:
			_open_menu()


func _process(delta: float) -> void:
	if _moving:
		_anim_t += delta
		var t: float = clampf(_anim_t / WALK_TIME, 0.0, 1.0)
		player_px = _move_from.lerp(_move_to, t)
		if t >= 1.0:
			_moving = false
			player_px = _move_to
			_frame = (_frame + 1) % 4
			_check_triggers(false)
			_check_warp()
	elif not _input_locked:
		_try_step()
	_update_camera(false)
	queue_redraw()


var _move_from := Vector2.ZERO
var _move_to := Vector2.ZERO


func _try_step() -> void:
	var dir := ""
	if _touch_dir != "":
		dir = _touch_dir
	elif Input.is_action_pressed("ui_up"):
		dir = "ui_up"
	elif Input.is_action_pressed("ui_down"):
		dir = "ui_down"
	elif Input.is_action_pressed("ui_left"):
		dir = "ui_left"
	elif Input.is_action_pressed("ui_right"):
		dir = "ui_right"
	if dir == "":
		_frame = 0
		return
	var delta := Vector2i.ZERO
	match dir:
		"ui_up": delta = Vector2i(0, -1); player_dir = "up"
		"ui_down": delta = Vector2i(0, 1); player_dir = "down"
		"ui_left": delta = Vector2i(-1, 0); player_dir = "left"
		"ui_right": delta = Vector2i(1, 0); player_dir = "right"
	var target := player_cell + delta
	if _blocked(target):
		return
	player_cell = target
	_move_from = player_px
	_move_to = Vector2(target) * TS
	_anim_t = 0.0
	_moving = true
	Audio.sfx("step")


func _blocked(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.y >= mh or cell.x >= mw:
		return true
	if solid[cell.y][cell.x]:
		return true
	for n in npcs:
		if n.get("cell", Vector2i(-1, -1)) == cell:
			return true
	return false


func _update_camera(instant: bool) -> void:
	var target := player_px + Vector2(TS * 0.5, TS * 0.5) - VIEW * 0.5
	var max_x: float = maxf(0.0, mw * TS - VIEW.x)
	var max_y: float = maxf(0.0, mh * TS - VIEW.y)
	target.x = clampf(target.x, 0.0, max_x)
	target.y = clampf(target.y, 0.0, max_y)
	if mw * TS < VIEW.x:
		target.x = (mw * TS - VIEW.x) * 0.5
	if mh * TS < VIEW.y:
		target.y = (mh * TS - VIEW.y) * 0.5
	_cam = target if instant else _cam.lerp(target, 0.25)
	_world.position = -_cam.round()


# =====================================================================
# interaction
# =====================================================================

func _facing_cell() -> Vector2i:
	match player_dir:
		"up": return player_cell + Vector2i(0, -1)
		"down": return player_cell + Vector2i(0, 1)
		"left": return player_cell + Vector2i(-1, 0)
	return player_cell + Vector2i(1, 0)


func _interact() -> void:
	if _input_locked or _moving:
		return
	var cell := _facing_cell()
	for n in npcs:
		if n.get("cell") == cell:
			_talk(n)
			return
	# reading a sign
	if cell.y >= 0 and cell.y < mh and cell.x >= 0 and cell.x < mw:
		if grid[cell.y][cell.x] == "sign":
			_say([str(map_def.get("name", "Domino City"))])


func _talk(npc: Dictionary) -> void:
	_input_locked = true
	Audio.sfx("confirm")
	var lines: Array = npc.get("lines", [])
	if npc.get("shopkeeper", false):
		await _say(lines)
		_input_locked = false
		SceneFlow.goto("Shop", {"back_map": map_id, "back_pos": player_cell})
		return
	if npc.get("duelist", false):
		if not Game.has_flag("has_deck"):
			await _say(["Ohne Deck kann ich dich nicht duellieren.",
						"Besorg dir erst mal Karten."])
			_input_locked = false
			return
		await _say(lines)
		_input_locked = false
		SceneFlow.goto("Duel", {
			"deck": str(npc.get("deck", "random_t1")),
			"opponent_name": str(npc.get("name", "Duellant")),
			"opponent_sprite": str(npc.get("sprite", "npc00")),
			"back_map": map_id, "back_pos": player_cell,
			"win_lines": npc.get("win", []),
			"lose_lines": npc.get("lose", []),
			"reward_dp": Game.DP_PER_WIN,
		})
		return
	await _say(lines, str(npc.get("key", npc.get("sprite", ""))))
	_input_locked = false


func _say(lines: Array, speaker: String = "") -> void:
	var box := preload("res://src/ui/DialogBox.gd").new()
	_hud.add_child(box)
	for line in lines:
		await box.show_line(Game.fill(str(line)), speaker)
	box.queue_free()


func _open_menu() -> void:
	if _input_locked:
		return
	Audio.sfx("open")
	SceneFlow.goto("Menu", {"back_map": map_id, "back_pos": player_cell})


# =====================================================================
# triggers & warps
# =====================================================================

func _check_warp() -> void:
	for w in map_def.get("warps", []):
		if int(w.get("x", -1)) + pad.x == player_cell.x and int(w.get("y", -1)) + pad.y == player_cell.y:
			var to := str(w.get("to", ""))
			if not Maps.exists(to):
				continue
			_input_locked = true
			await SceneFlow.fade_out(0.15)
			load_map(to, Vector2i(int(w.get("tx", 4)), int(w.get("ty", 4))))
			await SceneFlow.fade_in(0.15)
			_input_locked = false
			return


func _check_triggers(on_enter: bool) -> void:
	for t in map_def.get("triggers", []):
		var once := str(t.get("once", ""))
		if once != "" and Game.has_flag(once):
			continue
		var req := str(t.get("require", ""))
		if req != "" and not Game.has_flag(req):
			continue
		var tx := int(t.get("x", 0)) + pad.x
		var ty := int(t.get("y", 0)) + pad.y
		var tw := int(t.get("w", 1))
		var th := int(t.get("h", 1))
		if player_cell.x < tx or player_cell.x >= tx + tw:
			continue
		if player_cell.y < ty or player_cell.y >= ty + th:
			continue
		var scene := str(t.get("scene", ""))
		if scene == "" or not StoryDB.has_scene(scene):
			if once != "":
				Game.set_flag(once)
			continue
		if once != "":
			Game.set_flag(once)
		if t.has("flag"):
			Game.set_flag(str(t["flag"]))
		_input_locked = true
		SceneFlow.goto("Story", {
			"scene": scene, "then": "World",
			"back_map": map_id, "back_pos": player_cell,
		})
		return


# =====================================================================
# rendering
# =====================================================================

func _draw() -> void:
	var tex := TileGfx.texture()
	if tex == null:
		return
	var off := -_cam.round()
	# ground layer
	var x0 := maxi(0, int(_cam.x / TS) - 1)
	var x1 := mini(mw, int((_cam.x + VIEW.x) / TS) + 2)
	var y0 := maxi(0, int(_cam.y / TS) - 1)
	var y1 := mini(mh, int((_cam.y + VIEW.y) / TS) + 2)
	for y in range(y0, y1):
		for x in range(x0, x1):
			var name: String = grid[y][x]
			if name == "void":
				continue
			draw_texture_rect_region(tex,
				Rect2(off + Vector2(x * TS, y * TS), Vector2(TS, TS)),
				TileGfx.region(name))

	# entities sorted by y so they overlap correctly
	var ents: Array = []
	for n in npcs:
		var c: Vector2i = n.get("cell")
		ents.append([c.y, Vector2(c) * TS, str(n.get("sprite", "npc00")),
					 str(n.get("dir", "down")), 0])
	ents.append([player_cell.y, player_px, Game.sprite_key(), player_dir,
				 _frame if _moving else 0])
	ents.sort_custom(func(a, b): return a[0] < b[0])
	for e in ents:
		_draw_char(str(e[2]), e[1] + off, str(e[3]), int(e[4]))

	# overlay layer (tree canopies) drawn last
	for y in range(y0, y1):
		for x in range(x0, x1):
			var name: String = overlay[y][x]
			if name == "":
				continue
			draw_texture_rect_region(tex,
				Rect2(off + Vector2(x * TS, y * TS), Vector2(TS, TS)),
				TileGfx.region(name))


func _draw_char(key: String, pos: Vector2, dir: String, frame: int) -> void:
	var sheet := Art.char_sheet(key)
	if sheet == null:
		return
	var row: int = {"down": 0, "left": 1, "right": 2, "up": 3}.get(dir, 0)
	# feet sit on the tile, sprite is taller than a tile
	var draw_pos := pos + Vector2(-8, -24)
	draw_texture_rect_region(sheet, Rect2(draw_pos, Vector2(32, 40)),
		Rect2(frame * 32, row * 40, 32, 40))
