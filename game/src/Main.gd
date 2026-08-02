extends Node
## Entry point: wires the screen holder into SceneFlow and boots the title.

@onready var holder: Node = $Holder


func _ready() -> void:
	SceneFlow.register_holder(holder)
	var args := OS.get_cmdline_user_args()
	if "--selftest" in args:
		_selftest()
		return
	if "--smoke" in args:
		_smoke()
		return
	if "--simduel" in args:
		_sim_only()
		return
	if "--shots" in args:
		_screenshots()
		return
	SceneFlow.goto("Title")


func _selftest() -> void:
	var fails: Array[String] = []
	if CardDB.cards.size() < 100:
		fails.append("cards.json missing or too small (%d)" % CardDB.cards.size())
	if CardDB.packs.size() < 1:
		fails.append("packs.json missing")
	if CardDB.decks.size() < 1:
		fails.append("decks.json missing")
	if StoryDB.scenes.size() < 1:
		fails.append("story.json missing")
	for key in ["player_m_quiet", "player_f_bold", "yugi", "kaiba", "joey"]:
		if not Art.has_char(key):
			fails.append("missing sprite %s" % key)
	for screen in ["Title", "CharCreate", "World", "Duel", "Menu", "Shop",
			"DeckBuilder", "Collection", "Story"]:
		if not ResourceLoader.exists("res://src/screens/%s.gd" % screen):
			fails.append("missing screen %s" % screen)
	if fails.is_empty():
		print("SELFTEST OK")
	else:
		for f in fails:
			printerr("SELFTEST FAIL: %s" % f)
	get_tree().quit(0 if fails.is_empty() else 1)


var _logf: FileAccess = null


## Print that survives a hard kill (stdout is buffered and lost on SIGTERM).
func _plog(msg: String) -> void:
	print(msg)
	if _logf == null:
		_logf = FileAccess.open("user://simlog.txt", FileAccess.WRITE)
	if _logf:
		_logf.store_line(msg)
		_logf.flush()


func _sim_only() -> void:
	Game.new_game()
	Game.give_starter_deck("starter_spellcaster")
	_plog("sim start")
	_plog(await _simulate_duels(8))
	_plog("SIM DONE")
	if _logf:
		_logf.close()
	get_tree().quit(0)


## Headless smoke test: instantiate every screen and play a full AI-vs-AI
## duel, so runtime errors surface without a display.
func _smoke() -> void:
	print("--- smoke: screens ---")
	Game.new_game()
	Game.give_starter_deck("starter_spellcaster")
	# Story waits for player input, so it is exercised separately.
	for name in ["Title", "CharCreate", "Menu", "Settings", "Collection",
			"Shop", "DeckBuilder", "World", "Duel"]:
		var path := "res://src/screens/%s.gd" % name
		if not ResourceLoader.exists(path):
			printerr("  MISSING %s" % name)
			continue
		var scr: Script = load(path)
		if scr == null:
			printerr("  LOAD FAIL %s" % name)
			continue
		var node: Node = scr.new()
		if node.has_method("setup"):
			node.setup({"map": "player_home", "pos": Vector2i(6, 6),
				"scene": "prolog_home", "deck": "random_t1",
				"back_map": "player_home", "back_pos": Vector2i(6, 6)})
		holder.add_child(node)
		await get_tree().process_frame
		await get_tree().process_frame
		print("  ok %s" % name)
		node.queue_free()
		await get_tree().process_frame

	print("--- smoke: duel simulation ---")
	var report := await _simulate_duels(6)
	print(report)
	print("SMOKE DONE")
	get_tree().quit(0)


func _simulate_duels(count: int) -> String:
	var wins := [0, 0]
	var turns_total := 0
	var errors := 0
	var deck_ids := ["starter_warrior", "starter_spellcaster", "starter_dragon",
		"yugi_t5", "kaiba_t3", "joey_t2", "mai_t2", "pegasus_t5"]
	for i in count:
		var e := DuelEngine.new()
		var a: Dictionary = CardDB.get_deck(deck_ids[i % deck_ids.size()])
		var b: Dictionary = CardDB.get_deck(deck_ids[(i + 3) % deck_ids.size()])
		e.setup_duel(a.get("main", []), a.get("extra", []), "A", "yugi",
			b.get("main", []), b.get("extra", []), "B", "kaiba", 1000 + i)
		var ai0 := DuelAI.new(e, 0, 3)
		var ai1 := DuelAI.new(e, 1, 3)
		ai0.instant = true
		ai1.instant = true
		e.st.players[0].is_ai = true
		_plog("  duel %d: %s vs %s" % [i, deck_ids[i % deck_ids.size()],
			deck_ids[(i + 3) % deck_ids.size()]])
		var guard := 0
		while not e.st.is_over() and guard < 100:
			guard += 1
			var before := e.st.turn
			if e.st.turn_player == 0:
				await ai0.take_turn()
			else:
				await ai1.take_turn()
			if e.st.turn == before and not e.st.is_over():
				_plog("    !! turn did not advance at turn %d (phase %s) — aborting"
					% [e.st.turn, e.st.phase_name()])
				break
		turns_total += e.st.turn
		if e.st.winner >= 0 and e.st.winner < 2:
			wins[e.st.winner] += 1
		else:
			errors += 1
			if errors == 1:
				print("  [diag] unfinished duel: lp=%d/%d  monsters=%d/%d  hand=%d/%d  deck=%d/%d  phase=%s" % [
					e.st.players[0].lp, e.st.players[1].lp,
					e.st.players[0].monster_count(), e.st.players[1].monster_count(),
					e.st.players[0].hand.size(), e.st.players[1].hand.size(),
					e.st.players[0].deck.size(), e.st.players[1].deck.size(),
					e.st.phase_name()])
				var tail: Array = e.st.log_lines.slice(maxi(0, e.st.log_lines.size() - 8))
				for l in tail:
					print("     | %s" % l)
	return "duels=%d  p0_wins=%d  p1_wins=%d  unfinished=%d  avg_turns=%.1f" % [
		count, wins[0], wins[1], errors, float(turns_total) / maxf(1.0, float(count))]


# =====================================================================
# screenshot capture (run under xvfb so there is a real framebuffer)
# =====================================================================

const SHOT_DIR := "user://shots/"


func _screenshots() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	# SceneFlow's fade overlay starts opaque; screens are added directly here
	# (not via goto), so clear it or every shot is black.
	await SceneFlow.fade_in(0.01)
	Game.new_game()
	Game.player_name = "Loris"
	Game.give_starter_deck("starter_spellcaster")
	Game.add_dp(4200)
	Game.set_objective("Gehe zum Spieleladen von Großvater Muto")
	Game.set_flag("game_started")
	Game.set_flag("has_deck")

	var shots := [
		["01_title", "Title", {}],
		["02_charcreate", "CharCreate", {}],
		["03_world_home", "World", {"map": "player_home", "pos": Vector2i(6, 5)}],
		["04_world_street", "World", {"map": "domino_street", "pos": Vector2i(10, 6)}],
		["05_world_plaza", "World", {"map": "domino_plaza", "pos": Vector2i(9, 6)}],
		["06_world_shop", "World", {"map": "kame_shop", "pos": Vector2i(7, 6)}],
		["07_world_island", "World", {"map": "dk_forest", "pos": Vector2i(9, 4)}],
		["08_world_egypt", "World", {"map": "eg_palace_ext", "pos": Vector2i(9, 4)}],
		["09_menu", "Menu", {"back_map": "domino_plaza", "back_pos": Vector2i(9, 6)}],
		["10_shop", "Shop", {"back_map": "domino_plaza", "back_pos": Vector2i(9, 6)}],
		["11_deck", "DeckBuilder", {"back_map": "domino_plaza", "back_pos": Vector2i(9, 6)}],
		["12_collection", "Collection", {"back_map": "domino_plaza", "back_pos": Vector2i(9, 6)}],
		["13_duel", "Duel", {"deck": "kaiba_t3", "opponent_name": "Seto Kaiba",
			"opponent_sprite": "kaiba", "back_map": "domino_plaza",
			"back_pos": Vector2i(9, 6)}],
		["14_settings", "Settings", {"back": "Title"}],
	]
	for entry in shots:
		var file := str(entry[0])
		var screen := str(entry[1])
		var args: Dictionary = entry[2]
		var path := "res://src/screens/%s.gd" % screen
		if not ResourceLoader.exists(path):
			continue
		for c in holder.get_children():
			c.free()
		var scr: Script = load(path)
		var node: Node = scr.new()
		if node.has_method("setup"):
			node.setup(args)
		holder.add_child(node)
		# let layout, tweens and the first draw settle
		for i in 12:
			await get_tree().process_frame
		await get_tree().create_timer(0.35).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png(SHOT_DIR + file + ".png")
		print("shot %s" % file)
	print("SHOTS DONE")
	get_tree().quit(0)
