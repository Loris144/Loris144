extends SceneTree
func _init() -> void:
	var files := ["res://src/duel/DuelState.gd","res://src/duel/DuelEngine.gd",
		"res://src/duel/CardScripts.gd","res://src/duel/DuelAI.gd",
		"res://src/screens/Duel.gd","res://src/screens/Story.gd",
		"res://src/screens/World.gd","res://src/world/Maps.gd"]
	for f in files:
		var r = load(f)
		print(("OK   " if r != null else "FAIL ") + f)
	quit(0)
