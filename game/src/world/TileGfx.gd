class_name TileGfx
extends Object
## Access to the generated tile atlas described by data/tiles.json.

const ATLAS := "res://assets/gen/tiles/atlas.png"
const INDEX := "res://data/tiles.json"

static var _tex: Texture2D = null
static var _index: Dictionary = {}
static var _size := 16
static var _loaded := false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if ResourceLoader.exists(ATLAS):
		_tex = load(ATLAS)
	if FileAccess.file_exists(INDEX):
		var f := FileAccess.open(INDEX, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		f.close()
		if typeof(parsed) == TYPE_DICTIONARY:
			_index = parsed.get("tiles", {})
			_size = int(parsed.get("tile_size", 16))


static func texture() -> Texture2D:
	_ensure()
	return _tex


static func size() -> int:
	_ensure()
	return _size


static func has(name: String) -> bool:
	_ensure()
	return _index.has(name)


static func region(name: String) -> Rect2:
	_ensure()
	var t: Dictionary = _index.get(name, {})
	if t.is_empty():
		return Rect2(0, 0, _size, _size)
	return Rect2(int(t.get("x", 0)) * _size, int(t.get("y", 0)) * _size, _size, _size)


static func is_solid(name: String) -> bool:
	_ensure()
	return bool(_index.get(name, {}).get("solid", false))


static func names() -> Array:
	_ensure()
	return _index.keys()
