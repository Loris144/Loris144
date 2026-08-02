extends Node
## Art service: sprite sheets, card frames, and card artwork.
##
## Card artwork is fetched from the public YGOPRODeck image CDN the first time
## a card is displayed and cached under user://cardart/. Until an image is
## available (offline, or still downloading) we show a deterministic
## procedurally generated placeholder so nothing is ever blank.

const CHAR_DIR := "res://assets/gen/chars/"
const PORTRAIT_DIR := "res://assets/gen/portraits/"
const CARD_DIR := "res://assets/gen/cards/"
const UI_DIR := "res://assets/gen/ui/"
const CACHE_DIR := "user://cardart/"
const IMG_URL := "https://images.ygoprodeck.com/images/cards_cropped/%d.jpg"

const ART_W := 84
const ART_H := 62

signal card_image_ready(card_id: int)

var _tex_cache: Dictionary = {}          # path/key -> Texture2D
var _card_art: Dictionary = {}           # card_id -> Texture2D
var _queue: Array[int] = []
var _in_flight: Dictionary = {}          # card_id -> HTTPRequest
var _failed: Dictionary = {}             # card_id -> true (don't retry this run)
var downloads_enabled := true
var max_parallel := 3


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)


# =====================================================================
# static art
# =====================================================================

func _load(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	if tex == null:
		tex = _blank()
	_tex_cache[path] = tex
	return tex


func _blank() -> Texture2D:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 1, 1))
	return ImageTexture.create_from_image(img)


func char_sheet(key: String) -> Texture2D:
	return _load(CHAR_DIR + key + ".png")


func has_char(key: String) -> bool:
	return ResourceLoader.exists(CHAR_DIR + key + ".png")


func portrait(key: String) -> Texture2D:
	if not ResourceLoader.exists(PORTRAIT_DIR + key + ".png"):
		return null
	return _load(PORTRAIT_DIR + key + ".png")


func card_frame(kind: String) -> Texture2D:
	return _load(CARD_DIR + "frame_" + kind + ".png")


func card_back() -> Texture2D:
	return _load(CARD_DIR + "back.png")


func ui(name: String) -> Texture2D:
	return _load(UI_DIR + name + ".png")


# =====================================================================
# card artwork
# =====================================================================

func card_art(card_id: int) -> Texture2D:
	if _card_art.has(card_id):
		return _card_art[card_id]
	# 1) disk cache
	var path := CACHE_DIR + "%d.png" % card_id
	if FileAccess.file_exists(path):
		var img := Image.new()
		if img.load(path) == OK:
			var tex := ImageTexture.create_from_image(img)
			_card_art[card_id] = tex
			return tex
	# 2) placeholder, and kick off a download
	var ph := _placeholder(card_id)
	_card_art[card_id] = ph
	_request(card_id)
	return ph


func _request(card_id: int) -> void:
	if not downloads_enabled or _failed.has(card_id) or _in_flight.has(card_id):
		return
	if CardDB.get_card(card_id).get("noimage", false):
		return
	if card_id <= 0:
		return
	if card_id in _queue:
		return
	_queue.append(card_id)
	_pump()


func _pump() -> void:
	while _in_flight.size() < max_parallel and not _queue.is_empty():
		var id: int = _queue.pop_front()
		var req := HTTPRequest.new()
		req.timeout = 12.0
		add_child(req)
		_in_flight[id] = req
		req.request_completed.connect(_on_done.bind(id, req))
		var err := req.request(IMG_URL % id)
		if err != OK:
			_finish(id, req, false)


func _on_done(result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray, card_id: int, req: HTTPRequest) -> void:
	var ok := false
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and body.size() > 512:
		var img := Image.new()
		var err := img.load_jpg_from_buffer(body)
		if err != OK:
			err = img.load_png_from_buffer(body)
		if err == OK:
			img.resize(ART_W, ART_H, Image.INTERPOLATE_LANCZOS)
			img.save_png(CACHE_DIR + "%d.png" % card_id)
			_card_art[card_id] = ImageTexture.create_from_image(img)
			ok = true
			card_image_ready.emit(card_id)
	_finish(card_id, req, ok)


func _finish(card_id: int, req: HTTPRequest, ok: bool) -> void:
	if not ok:
		_failed[card_id] = true
	_in_flight.erase(card_id)
	if is_instance_valid(req):
		req.queue_free()
	_pump()


## Warm the cache for a list of cards (e.g. the player's deck before a duel).
func prefetch(ids: Array) -> void:
	for id in ids:
		if not _card_art.has(int(id)):
			_request(int(id))


func cached_count() -> int:
	var dir := DirAccess.open(CACHE_DIR)
	if dir == null:
		return 0
	var n := 0
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".png"):
			n += 1
		f = dir.get_next()
	dir.list_dir_end()
	return n


# ---------------------------------------------------------------------
# procedural placeholder art
# ---------------------------------------------------------------------

const ATTR_PALETTE := {
	"DARK":   [Color8(42, 32, 56), Color8(90, 58, 120), Color8(138, 90, 168), Color8(200, 160, 224)],
	"LIGHT":  [Color8(74, 66, 48), Color8(138, 122, 64), Color8(216, 192, 96), Color8(246, 236, 176)],
	"FIRE":   [Color8(58, 26, 24), Color8(138, 42, 32), Color8(208, 90, 40), Color8(240, 168, 80)],
	"WATER":  [Color8(21, 42, 64), Color8(31, 85, 128), Color8(58, 154, 200), Color8(138, 216, 240)],
	"EARTH":  [Color8(42, 36, 24), Color8(90, 74, 40), Color8(138, 112, 64), Color8(192, 168, 112)],
	"WIND":   [Color8(26, 42, 32), Color8(47, 106, 74), Color8(79, 170, 120), Color8(160, 224, 184)],
	"DIVINE": [Color8(58, 42, 16), Color8(138, 106, 16), Color8(224, 184, 48), Color8(255, 240, 160)],
}
const SPELL_PALETTE := [Color8(20, 58, 52), Color8(28, 106, 92), Color8(47, 154, 134), Color8(140, 216, 200)]
const TRAP_PALETTE := [Color8(58, 20, 40), Color8(120, 38, 79), Color8(176, 64, 122), Color8(232, 150, 190)]


func _placeholder(card_id: int) -> Texture2D:
	var card: Dictionary = CardDB.get_card(card_id)
	var name := str(card.get("name", str(card_id)))
	var pal: Array = SPELL_PALETTE
	var cat := str(card.get("cat", "monster"))
	if cat == "trap":
		pal = TRAP_PALETTE
	elif cat == "monster":
		pal = ATTR_PALETTE.get(str(card.get("attr", "")), ATTR_PALETTE["DARK"])

	var img := Image.create(ART_W, ART_H, false, Image.FORMAT_RGBA8)
	img.fill(pal[0])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)

	# layered blobs, dark to light
	for layer in range(1, 4):
		for _i in range(2 + layer):
			var cx := rng.randi_range(6, ART_W - 6)
			var cy := rng.randi_range(8, ART_H - 6)
			var rx := rng.randi_range(6, 20 - layer * 3)
			var ry := rng.randi_range(5, 16 - layer * 3)
			for y in range(maxi(0, cy - ry), mini(ART_H, cy + ry)):
				for x in range(maxi(0, cx - rx), mini(ART_W, cx + rx)):
					var dx := float(x - cx) / float(rx)
					var dy := float(y - cy) / float(ry)
					if dx * dx + dy * dy <= 1.0:
						img.set_pixel(x, y, pal[layer])
	# scanlines for a retro feel
	for y in range(0, ART_H, 3):
		for x in range(ART_W):
			img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.12))
	return ImageTexture.create_from_image(img)
