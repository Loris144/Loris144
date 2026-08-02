extends Node
## Loads story.json — every cutscene, split into scenes made of steps.

const STORY_PATH := "res://data/story.json"

var scenes: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	scenes.clear()
	if not FileAccess.file_exists(STORY_PATH):
		push_warning("[StoryDB] missing %s" % STORY_PATH)
		return
	var f := FileAccess.open(STORY_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[StoryDB] story.json is not an object")
		return
	scenes = parsed.get("scenes", {})
	print("[StoryDB] %d scenes" % scenes.size())


func has_scene(id: String) -> bool:
	return scenes.has(id)


func get_scene(id: String) -> Dictionary:
	return scenes.get(id, {})


func steps(id: String) -> Array:
	return get_scene(id).get("steps", [])


## Display name for a speaker key.
const NAMES := {
	"player": "", # filled at runtime with the player's name
	"yugi": "Yugi", "atem": "Atem", "pharao": "Pharao",
	"joey": "Joey", "tea": "Téa", "tristan": "Tristan",
	"grandpa": "Großvater", "kaiba": "Kaiba", "mokuba": "Mokuba",
	"pegasus": "Pegasus", "weevil": "Weevil", "rex": "Rex",
	"mai": "Mai", "keith": "Bandit Keith",
	"marik": "Marik", "yami_marik": "Yami Marik",
	"ishizu": "Ishizu", "odion": "Odion",
	"bakura": "Bakura", "yami_bakura": "Yami Bakura",
	"thiefking": "Diebeskönig Bakura",
	"priest_seto": "Priester Seto", "mahad": "Mahad", "mana": "Mana",
	"akhenaden": "Akhenaden", "strings": "Strings",
	"rare_hunter": "Rare Hunter", "zorc": "Zorc",
	"announcer": "Aufseher", "narrator": "", "system": "System",
	"npc": "",
}


func speaker_name(key: String) -> String:
	if key == "player":
		return Game.player_name
	return str(NAMES.get(key, key.capitalize()))


## Sprite key used for the portrait of a speaker.
func speaker_sprite(key: String) -> String:
	if key == "player":
		return Game.sprite_key()
	if key == "pharao":
		return "atem"
	return key
