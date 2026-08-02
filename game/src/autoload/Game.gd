extends Node
## Global game state: the player, their collection, deck and story progress.
## Everything persisted lives here so saving is a single dictionary dump.

const SAVE_PATH := "user://savegame.json"
const SETTINGS_PATH := "user://settings.json"

const START_DP := 0
const DP_PER_WIN := 700
const PACK_COST := 100

signal dp_changed(value: int)
signal objective_changed(text: String)
signal collection_changed()

# ---------------------------------------------------------------- player
var player_name: String = "Yugi-Fan"
var player_gender: String = "m"          # "m" | "f"
var player_look: String = "quiet"        # quiet | bold | outsider
var dp: int = START_DP

# ---------------------------------------------------------------- progress
var flags: Dictionary = {}               # story flags -> true
var objective: String = ""               # banner text
var chapter: String = "prolog"
var current_map: String = "player_home"
var spawn_pos: Vector2i = Vector2i(6, 6)
var duels_won: int = 0
var duels_lost: int = 0
var title: String = "Neuling"

# ---------------------------------------------------------------- cards
var collection: Dictionary = {}          # card_id(int) -> count(int)
var deck_main: Array[int] = []
var deck_extra: Array[int] = []

# ---------------------------------------------------------------- settings
var settings: Dictionary = {
	"text_speed": 1,        # 0 slow, 1 normal, 2 fast
	"music": 0.7,
	"sfx": 0.8,
	"duel_speed": 1,        # 0 normal, 1 fast
	"touch_controls": true,
}


func _ready() -> void:
	load_settings()


# =====================================================================
# player identity
# =====================================================================

func sprite_key() -> String:
	return "player_%s_%s" % [player_gender, player_look]


func pronoun(kind: String) -> String:
	var male := player_gender == "m"
	match kind:
		"ER_SIE": return "er" if male else "sie"
		"ER_SIE_CAP": return "Er" if male else "Sie"
		"IHN_IHR": return "ihn" if male else "ihr"
		"IHM_IHR": return "ihm" if male else "ihr"
		"SEIN_IHR": return "sein" if male else "ihr"
		"DER_DIE": return "der" if male else "die"
		"SICH": return "sich"
		"IN": return "" if male else "in"
	return ""


## Replace {PLAYER} and the gender tokens in a story line.
func fill(text: String) -> String:
	var out := text.replace("{PLAYER}", player_name)
	for key in ["ER_SIE_CAP", "ER_SIE", "IHN_IHR", "IHM_IHR", "SEIN_IHR",
			"DER_DIE", "SICH", "IN"]:
		out = out.replace("{%s}" % key, pronoun(key))
	return out


# =====================================================================
# economy
# =====================================================================

func add_dp(amount: int) -> void:
	dp = max(0, dp + amount)
	dp_changed.emit(dp)


func spend_dp(amount: int) -> bool:
	if dp < amount:
		return false
	dp -= amount
	dp_changed.emit(dp)
	return true


# =====================================================================
# collection & deck
# =====================================================================

func add_card(id: int, count: int = 1) -> void:
	collection[id] = int(collection.get(id, 0)) + count
	collection_changed.emit()


func add_cards(ids: Array) -> void:
	for id in ids:
		collection[int(id)] = int(collection.get(int(id), 0)) + 1
	collection_changed.emit()


func owned(id: int) -> int:
	return int(collection.get(id, 0))


func total_cards() -> int:
	var n := 0
	for v in collection.values():
		n += int(v)
	return n


func unique_cards() -> int:
	return collection.size()


## How many copies of `id` are still free to put into a deck.
func available(id: int) -> int:
	var used := 0
	for c in deck_main:
		if c == id:
			used += 1
	for c in deck_extra:
		if c == id:
			used += 1
	return owned(id) - used


func deck_is_legal() -> bool:
	return deck_main.size() >= 40 and deck_main.size() <= 60 and deck_extra.size() <= 15


func give_starter_deck(deck_id: String) -> void:
	var deck: Dictionary = CardDB.get_deck(deck_id)
	if deck.is_empty():
		push_warning("Starter deck not found: %s" % deck_id)
		return
	deck_main.clear()
	deck_extra.clear()
	for id in deck.get("main", []):
		add_card(int(id))
		deck_main.append(int(id))
	for id in deck.get("extra", []):
		add_card(int(id))
		deck_extra.append(int(id))
	set_flag("has_deck")
	collection_changed.emit()


# =====================================================================
# story flags
# =====================================================================

func set_flag(name: String, value: bool = true) -> void:
	flags[name] = value


func has_flag(name: String) -> bool:
	return bool(flags.get(name, false))


func set_objective(text: String) -> void:
	objective = text
	objective_changed.emit(text)


func record_duel(won: bool, earn_dp: bool = true) -> void:
	if won:
		duels_won += 1
		if earn_dp:
			add_dp(DP_PER_WIN)
	else:
		duels_lost += 1


# =====================================================================
# save / load
# =====================================================================

func to_dict() -> Dictionary:
	# JSON only round-trips string keys, so store the collection as pairs.
	var coll: Array = []
	for k in collection.keys():
		coll.append([int(k), int(collection[k])])
	return {
		"version": 1,
		"name": player_name, "gender": player_gender, "look": player_look,
		"dp": dp, "flags": flags, "objective": objective, "chapter": chapter,
		"map": current_map, "spawn": [spawn_pos.x, spawn_pos.y],
		"won": duels_won, "lost": duels_lost, "title": title,
		"collection": coll,
		"deck_main": deck_main, "deck_extra": deck_extra,
	}


func from_dict(d: Dictionary) -> void:
	player_name = str(d.get("name", player_name))
	player_gender = str(d.get("gender", "m"))
	player_look = str(d.get("look", "quiet"))
	dp = int(d.get("dp", 0))
	flags = d.get("flags", {})
	objective = str(d.get("objective", ""))
	chapter = str(d.get("chapter", "prolog"))
	current_map = str(d.get("map", "player_home"))
	var sp: Array = d.get("spawn", [6, 6])
	spawn_pos = Vector2i(int(sp[0]), int(sp[1]))
	duels_won = int(d.get("won", 0))
	duels_lost = int(d.get("lost", 0))
	title = str(d.get("title", "Neuling"))
	collection.clear()
	for pair in d.get("collection", []):
		collection[int(pair[0])] = int(pair[1])
	deck_main.clear()
	for c in d.get("deck_main", []):
		deck_main.append(int(c))
	deck_extra.clear()
	for c in d.get("deck_extra", []):
		deck_extra.append(int(c))
	dp_changed.emit(dp)
	objective_changed.emit(objective)
	collection_changed.emit()


func save_game() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Could not open save file for writing")
		return false
	f.store_string(JSON.stringify(to_dict()))
	f.close()
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Save file corrupt")
		return false
	from_dict(parsed)
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func new_game() -> void:
	player_name = "Yugi-Fan"
	player_gender = "m"
	player_look = "quiet"
	dp = START_DP
	flags = {}
	objective = ""
	chapter = "prolog"
	current_map = "player_home"
	spawn_pos = Vector2i(6, 6)
	duels_won = 0
	duels_lost = 0
	title = "Neuling"
	collection = {}
	deck_main = []
	deck_extra = []


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))
		f.close()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		for k in parsed.keys():
			settings[k] = parsed[k]


func text_delay() -> float:
	return [0.055, 0.028, 0.008][clampi(int(settings.get("text_speed", 1)), 0, 2)]
