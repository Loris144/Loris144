extends Node
## Loads the card pool, booster packs and decklists from res://data.

const CARDS_PATH := "res://data/cards.json"
const PACKS_PATH := "res://data/packs.json"
const DECKS_PATH := "res://data/decks.json"

# card_id -> card dictionary
var cards: Dictionary = {}
var packs: Array = []
var decks: Dictionary = {}

var _by_name: Dictionary = {}
var loaded := false

const GOD_IDS := [10000000, 10000010, 10000020]


func _ready() -> void:
	load_all()


func load_all() -> void:
	cards.clear()
	_by_name.clear()
	var cdata: Dictionary = _read_json(CARDS_PATH)
	for c in cdata.get("cards", []):
		var id := int(c.get("id", 0))
		if id == 0:
			continue
		cards[id] = c
		_by_name[str(c.get("name", "")).to_lower()] = id
	var pdata: Dictionary = _read_json(PACKS_PATH)
	packs = pdata.get("packs", [])
	var ddata: Dictionary = _read_json(DECKS_PATH)
	decks = ddata.get("decks", {})
	loaded = cards.size() > 0
	print("[CardDB] %d cards, %d packs, %d decks" % [cards.size(), packs.size(), decks.size()])


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("[CardDB] missing %s" % path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[CardDB] %s is not a JSON object" % path)
		return {}
	return parsed


# =====================================================================
# lookups
# =====================================================================

func get_card(id: int) -> Dictionary:
	return cards.get(id, {})


func has(id: int) -> bool:
	return cards.has(id)


func find_by_name(name: String) -> int:
	return int(_by_name.get(name.to_lower(), 0))


func card_name(id: int) -> String:
	var c: Dictionary = get_card(id)
	if c.is_empty():
		return "Unbekannte Karte"
	var de := str(c.get("name_de", ""))
	return de if de != "" else str(c.get("name", "?"))


func is_monster(id: int) -> bool:
	return str(get_card(id).get("cat", "")) == "monster"


func is_spell(id: int) -> bool:
	return str(get_card(id).get("cat", "")) == "spell"


func is_trap(id: int) -> bool:
	return str(get_card(id).get("cat", "")) == "trap"


func is_extra_deck(id: int) -> bool:
	var k := str(get_card(id).get("kind", ""))
	return k in ["fusion", "synchro", "xyz", "link"]


func kind(id: int) -> String:
	return str(get_card(id).get("kind", "normal"))


func level(id: int) -> int:
	return int(get_card(id).get("level", 0))


func atk(id: int) -> int:
	return int(get_card(id).get("atk", 0))


func def(id: int) -> int:
	return int(get_card(id).get("def", 0))


func attribute(id: int) -> String:
	return str(get_card(id).get("attr", ""))


func race(id: int) -> String:
	return str(get_card(id).get("race", ""))


func text(id: int) -> String:
	return str(get_card(id).get("text", ""))


## Frame colour key used to pick the card frame texture.
func frame_kind(id: int) -> String:
	var c: Dictionary = get_card(id)
	if c.is_empty():
		return "normal"
	var cat := str(c.get("cat", "monster"))
	if cat == "spell":
		return "spell"
	if cat == "trap":
		return "trap"
	if attribute(id) == "DIVINE":
		return "divine"
	var k := str(c.get("kind", "normal"))
	if k in ["fusion", "ritual"]:
		return k
	if k == "effect":
		return "effect"
	return "normal"


# =====================================================================
# decks
# =====================================================================

func get_deck(id: String) -> Dictionary:
	return decks.get(id, {})


func deck_name(id: String) -> String:
	return str(get_deck(id).get("name", id))


func deck_owner(id: String) -> String:
	return str(get_deck(id).get("owner", ""))


# =====================================================================
# packs
# =====================================================================

func get_pack(id: String) -> Dictionary:
	for p in packs:
		if str(p.get("id", "")) == id:
			return p
	return {}


## Draw 5 cards: 3 common, 1 rare, 1 super (85%) or ultra (15%).
func open_pack(pack_id: String, rng: RandomNumberGenerator = null) -> Array[int]:
	var pack: Dictionary = get_pack(pack_id)
	var out: Array[int] = []
	if pack.is_empty():
		return out
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var pool: Dictionary = pack.get("cards", {})
	var commons: Array = pool.get("common", [])
	var rares: Array = pool.get("rare", [])
	var supers: Array = pool.get("super", [])
	var ultras: Array = pool.get("ultra", [])

	for i in 3:
		var pick := _pick(commons, rng)
		if pick > 0:
			out.append(pick)
	var r := _pick(rares, rng)
	if r > 0:
		out.append(r)
	var last_pool: Array = ultras if (rng.randf() < 0.15 and not ultras.is_empty()) else supers
	var s := _pick(last_pool, rng)
	if s > 0:
		out.append(s)
	# pad if a tier was empty so a pack is always 5 cards
	while out.size() < 5:
		var fb := _pick(commons + rares + supers, rng)
		if fb <= 0:
			break
		out.append(fb)
	return out


func _pick(arr: Array, rng: RandomNumberGenerator) -> int:
	if arr.is_empty():
		return 0
	return int(arr[rng.randi_range(0, arr.size() - 1)])


func rarity_of(pack_id: String, card_id: int) -> String:
	var pack: Dictionary = get_pack(pack_id)
	var pool: Dictionary = pack.get("cards", {})
	for tier in ["ultra", "super", "rare", "common"]:
		if card_id in pool.get(tier, []):
			return tier
	return "common"


## Best rarity the card has across all packs (used for collection glow).
func best_rarity(card_id: int) -> String:
	var rank := {"common": 0, "rare": 1, "super": 2, "ultra": 3}
	var best := "common"
	for p in packs:
		var pool: Dictionary = p.get("cards", {})
		for tier in ["ultra", "super", "rare"]:
			if card_id in pool.get(tier, []):
				if rank[tier] > rank[best]:
					best = tier
				break
	if card_id in GOD_IDS:
		return "ultra"
	return best
