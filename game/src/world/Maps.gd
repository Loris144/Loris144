class_name Maps
extends Object
## Every location in the game, described compactly and expanded at load time.
##
## A map is built from an ASCII layout (one char per tile) plus a legend that
## maps characters onto tile names from data/tiles.json. Buildings, NPCs,
## warps and story triggers are listed separately.
##
## Legend characters shared by all maps:
##   .  walkable ground (per-map default)
##   ,  ground variant
##   #  solid wall
##   T  tree (2 tiles tall — put T on the trunk row, the canopy is auto-added)
##   ~  water        ^  cliff        _  path        =  road       :  sidewalk
##   b  bush         r  rock         f  fence       s  sign       l  lamp
##   D  door (warp)  W  window       P  palm        H  hieroglyph wall
##   p  pillar       %  sand dune    *  flowers     "  tall grass

const W := 16  # tile size in pixels


static func all_ids() -> Array:
	return DEFS.keys()


static func get_map(id: String) -> Dictionary:
	return DEFS.get(id, {})


static func exists(id: String) -> bool:
	return DEFS.has(id)


# ---------------------------------------------------------------------
# helpers used by the definitions below
# ---------------------------------------------------------------------

static func _row(pattern: String, times: int) -> Array:
	var a: Array = []
	for _i in times:
		a.append(pattern)
	return a


# =====================================================================
# THE MAPS
# =====================================================================

const DEFS := {

# ------------------------------------------------------------- PROLOG
"player_home": {
	"name": "Dein Zimmer",
	"music": "town",
	"ground": "wood_floor",
	"indoor": true,
	"layout": [
		"###############",
		"#WW#....#..WW.#",
		"#..............#",
		"#.B..........S.#",
		"#..............#",
		"#....t.........#",
		"#..............#",
		"#.....p........#",
		"#..............#",
		"#######DD######",
	],
	"legend": {"B": "bed", "S": "shelf", "t": "table", "p": "plant"},
	"warps": [{"x": 7, "y": 9, "to": "domino_street", "tx": 12, "ty": 8},
			  {"x": 8, "y": 9, "to": "domino_street", "tx": 12, "ty": 8}],
	"npcs": [],
	"triggers": [{"x": 7, "y": 8, "w": 2, "h": 1, "scene": "prolog_street",
				  "once": "seen_street", "require": "game_started"}],
},

"domino_street": {
	"name": "Domino City — Wohnviertel",
	"music": "town",
	"ground": "sidewalk",
	"layout": [
		"BBBBBBB.BBBBBBBB.BBBBBBB.BBBBBB",
		"BBBBBBB.BBBBBBBB.BBBBBBB.BBBBBB",
		"WWDWWWW.WWWWDWWW.WWWWWWW.WWDWWW",
		":::::::.:::::::::.::::::::.:::::",
		"::l:::::::::l:::::::::l:::::::l:",
		":::::::::::::::::::::::::::::::",
		"===============================",
		"-------------------------------",
		"===============================",
		":::::::::::::::::::::::::::::::",
		"::b::*:::::::::b:::::*::::b::::",
		":::::::::::::::::::::::::::::::",
		"::l:::::::::l:::::::::l:::::::l:",
		"WWWWDWW.WWWWWWWW.WWDWWWW.WWWWWW",
		"BBBBBBB.BBBBBBBB.BBBBBBB.BBBBBB",
		"BBBBBBB.BBBBBBBB.BBBBBBB.BBBBBB",
	],
	"legend": {"-": "road_line", "B": "roof_blue", "W": "wall"},
	"warps": [
		{"x": 20, "y": 13, "to": "player_home", "tx": 7, "ty": 8},
		{"x": 30, "y": 6, "to": "domino_plaza", "tx": 1, "ty": 7},
		{"x": 30, "y": 7, "to": "domino_plaza", "tx": 1, "ty": 7},
		{"x": 30, "y": 8, "to": "domino_plaza", "tx": 1, "ty": 7},
	],
	"npcs": [
		{"sprite": "npc00", "x": 8, "y": 10, "dir": "down",
		 "lines": ["Der Spieleladen von Großvater Muto? Immer nach Osten!"]},
		{"sprite": "npc03", "x": 22, "y": 11, "dir": "left",
		 "lines": ["In Domino dreht sich alles um Duel Monsters.",
				   "Ohne Deck bist du hier niemand."]},
		{"sprite": "npc06", "x": 14, "y": 4, "dir": "down",
		 "lines": ["Mein Bruder sagt, Kaiba Corp baut überall Duell-Arenen."]},
	],
	"triggers": [],
},

"domino_plaza": {
	"name": "Domino City — Zentrum",
	"music": "town",
	"ground": "sidewalk",
	"layout": [
		"RRRRR.GGGGG.RRRRR.BBBBB.GGGGGG",
		"RRRRR.GGGGG.RRRRR.BBBBB.GGGGGG",
		"WWDWW.WWDWW.WWWWW.WWDWW.WWWDWW",
		"::::::::::::::::::::::::::::::",
		"::l:::::::::::l:::::::::::l:::",
		"::::::::::::::::::::::::::::::",
		"==============================",
		"------------------------------",
		"==============================",
		"::::::::::::::::::::::::::::::",
		"::*:::b:::::::::::::b::::*::::",
		"::::::::::::::::::::::::::::::",
		"::l:::::::::::l:::::::::::l:::",
		"::::::::::::::::::::::::::::::",
		"WWWDWW.WWWWWW.WWDWWW.WWWWWWWWW",
		"BBBBBB.RRRRRR.GGGGGG.RRRRRRRRR",
		"BBBBBB.RRRRRR.GGGGGG.RRRRRRRRR",
	],
	"legend": {"-": "road_line", "R": "roof_red", "G": "roof_green",
			   "B": "roof_blue", "W": "wall"},
	"warps": [
		{"x": 0, "y": 6, "to": "domino_street", "tx": 29, "ty": 7},
		{"x": 0, "y": 7, "to": "domino_street", "tx": 29, "ty": 7},
		{"x": 0, "y": 8, "to": "domino_street", "tx": 29, "ty": 7},
		{"x": 8, "y": 2, "to": "kame_shop", "tx": 7, "ty": 8},
		{"x": 21, "y": 2, "to": "domino_museum", "tx": 7, "ty": 9},
		{"x": 3, "y": 14, "to": "card_shop", "tx": 6, "ty": 8},
		{"x": 16, "y": 14, "to": "bc_alley", "tx": 3, "ty": 4},
		{"x": 29, "y": 6, "to": "domino_harbor", "tx": 1, "ty": 6},
		{"x": 29, "y": 7, "to": "domino_harbor", "tx": 1, "ty": 6},
	],
	"npcs": [
		{"sprite": "npc01", "x": 6, "y": 10, "dir": "down",
		 "lines": ["Der Kartenladen da unten hat immer neue Packs!"]},
		{"sprite": "npc05", "x": 24, "y": 4, "dir": "down",
		 "lines": ["Kaiba Corp baut überall diese Duell-Arenen.",
				   "Der Junge ist erst 16 und leitet einen Konzern!"]},
		{"sprite": "npc08", "x": 13, "y": 11, "dir": "right", "duelist": true,
		 "deck": "random_t1", "name": "Schüler-Duellant",
		 "lines": ["Hey! Du siehst nach einem Duellanten aus. Zeig, was du kannst!"],
		 "win": ["Wow, du bist echt stark! Gut gespielt."],
		 "lose": ["Ich hab gewonnen?! Ich hab wirklich gewonnen!"]},
		{"sprite": "npc11", "x": 19, "y": 10, "dir": "down",
		 "lines": ["Sternenchips, Lokalisierungskarten … die Turniere",
				   "werden auch nicht einfacher."]},
	],
	"triggers": [
		{"x": 7, "y": 3, "w": 3, "h": 1, "scene": "dk_message",
		 "once": "dk_started", "require": "prolog_done"},
	],
	"shop": true,
},

"kame_shop": {
	"name": "Kame Game — Spieleladen",
	"music": "town",
	"ground": "wood_floor",
	"indoor": true,
	"layout": [
		"###############",
		"#SSSS###SSSS..#",
		"#.............#",
		"#.....ccc.....#",
		"#.............#",
		"#.SS.......SS.#",
		"#.............#",
		"#.......p.....#",
		"#######DD######",
	],
	"legend": {"S": "shelf", "c": "counter", "p": "plant"},
	"warps": [{"x": 7, "y": 8, "to": "domino_plaza", "tx": 11, "ty": 2},
			  {"x": 8, "y": 8, "to": "domino_plaza", "tx": 11, "ty": 2}],
	"npcs": [
		{"sprite": "grandpa", "x": 7, "y": 4, "dir": "down", "key": "grandpa",
		 "lines": ["Willkommen im Kame Game, {PLAYER}!",
				   "Ein Deck ist wie ein Spiegel deiner Seele."]},
		{"sprite": "yugi", "x": 5, "y": 6, "dir": "right", "key": "yugi",
		 "lines": ["Schön, dass du da bist! Wie läuft's mit deinem Deck?"]},
	],
	"triggers": [
		{"x": 7, "y": 7, "w": 2, "h": 1, "scene": "prolog_shop",
		 "once": "prolog_shop_done"},
	],
},

"card_shop": {
	"name": "Kartenladen",
	"music": "town",
	"ground": "tile_floor",
	"indoor": true,
	"layout": [
		"##############",
		"#SSSSS##SSSSS#",
		"#............#",
		"#...cccccc...#",
		"#............#",
		"#.S........S.#",
		"#............#",
		"#####DD######",
	],
	"legend": {"S": "shelf", "c": "counter"},
	"warps": [{"x": 5, "y": 7, "to": "domino_plaza", "tx": 11, "ty": 8},
			  {"x": 6, "y": 7, "to": "domino_plaza", "tx": 11, "ty": 8}],
	"npcs": [
		{"sprite": "npc11", "x": 7, "y": 2, "dir": "down", "shopkeeper": true,
		 "lines": ["Willkommen! Jedes Pack kostet 100 DP.",
				   "Sprich mich an, wenn du kaufen willst."]},
	],
	"triggers": [],
	"shop": true,
},

"domino_museum": {
	"name": "Domino-Museum",
	"music": "tense",
	"ground": "tile_floor",
	"indoor": true,
	"layout": [
		"###############",
		"#HHHH#####HHHH#",
		"#.............#",
		"#..p.......p..#",
		"#.............#",
		"#....HHHHH....#",
		"#.............#",
		"#.............#",
		"#......DD.....#",
		"###############",
	],
	"legend": {"H": "hieroglyph", "p": "pillar"},
	"warps": [{"x": 7, "y": 9, "to": "domino_plaza", "tx": 19, "ty": 2},
			  {"x": 8, "y": 9, "to": "domino_plaza", "tx": 19, "ty": 2}],
	"npcs": [],
	"triggers": [
		{"x": 5, "y": 6, "w": 5, "h": 1, "scene": "bc_museum",
		 "once": "bc_museum_done", "require": "bc_started"},
	],
},

"domino_harbor": {
	"name": "Hafen von Domino",
	"music": "tense",
	"ground": "stone_path",
	"layout": [
		"::::::::::::::::::::",
		"::::::::::::::::::::",
		"::l::::::::::l::::::",
		"::::::::::::::::::::",
		"::::::::::::::::::::",
		"::::::::::::::::::::",
		"::::::::::::::::::::",
		"~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~",
	],
	"legend": {},
	"warps": [{"x": 0, "y": 4, "to": "domino_plaza", "tx": 18, "ty": 4},
			  {"x": 0, "y": 5, "to": "domino_plaza", "tx": 18, "ty": 4}],
	"npcs": [
		{"sprite": "npc06", "x": 14, "y": 5, "dir": "left", "duelist": true,
		 "deck": "random_t2", "name": "Straßen-Rowdy",
		 "lines": ["Was willst du hier? Verschwinde — oder duelliere!"],
		 "win": ["Tch … besser als du aussiehst."],
		 "lose": ["Ha! Komm wieder, wenn du duellieren gelernt hast."]},
	],
	"triggers": [
		{"x": 8, "y": 5, "w": 4, "h": 2, "scene": "bc_joey_harbor",
		 "once": "bc_harbor_done", "require": "bc_strings_done"},
		{"x": 2, "y": 6, "w": 6, "h": 1, "scene": "dk_ship",
		 "once": "dk_ship_done", "require": "dk_started"},
	],
},

"bc_alley": {
	"name": "Seitenstraße",
	"music": "tense",
	"ground": "road",
	"layout": [
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	],
	"legend": {},
	"warps": [{"x": 1, "y": 4, "to": "domino_plaza", "tx": 4, "ty": 6}],
	"npcs": [],
	"triggers": [
		{"x": 12, "y": 2, "w": 3, "h": 2, "scene": "bc_rare_hunter",
		 "once": "bc_rh_done", "require": "bc_started"},
	],
},

"bc_square": {
	"name": "Leerer Platz",
	"music": "tense",
	"ground": "stone_path",
	"layout": [
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################",
	],
	"legend": {},
	"warps": [{"x": 1, "y": 3, "to": "domino_plaza", "tx": 4, "ty": 6}],
	"npcs": [],
	"triggers": [
		{"x": 12, "y": 2, "w": 4, "h": 3, "scene": "bc_strings",
		 "once": "bc_strings_done", "require": "bc_museum_done"},
	],
},

"bc_tower": {
	"name": "Kaibas Turm",
	"music": "tense",
	"ground": "tile_floor",
	"indoor": true,
	"layout": [
		"###############",
		"#.............#",
		"#..p.......p..#",
		"#.............#",
		"#.............#",
		"#.............#",
		"#......DD.....#",
		"###############",
	],
	"legend": {"p": "pillar"},
	"warps": [{"x": 7, "y": 6, "to": "domino_plaza", "tx": 11, "ty": 4},
			  {"x": 8, "y": 6, "to": "domino_plaza", "tx": 11, "ty": 4}],
	"npcs": [],
	"triggers": [
		{"x": 5, "y": 2, "w": 5, "h": 2, "scene": "bc_finals_masked",
		 "once": "bc_finals_done", "require": "bc_qualified"},
	],
},

# ------------------------------------------------- DUELIST KINGDOM
"dk_shore": {
	"name": "Duelist Kingdom — Anlegestelle",
	"music": "town",
	"ground": "sand",
	"layout": [
		"~~~~~~~~~~~~~~~~~~~~",
		"~~~~~~~~~~~~~~~~~~~~",
		"%%%%%%%%%%%%%%%%%%%%",
		"....................",
		"..P.............P...",
		"....................",
		"..,,....,,....,,....",
		"....................",
		"TTTTTTTT....TTTTTTTT",
	],
	"legend": {},
	"warps": [{"x": 9, "y": 8, "to": "dk_forest", "tx": 9, "ty": 1},
			  {"x": 10, "y": 8, "to": "dk_forest", "tx": 9, "ty": 1}],
	"npcs": [
		{"sprite": "announcer", "x": 6, "y": 5, "dir": "right", "key": "announcer",
		 "lines": ["Willkommen auf Duelist Kingdom!",
				   "Zwei Sternenchips zum Start. Wer alle verliert, scheidet aus."]},
	],
	"triggers": [
		{"x": 8, "y": 3, "w": 4, "h": 1, "scene": "dk_arrive",
		 "once": "dk_arrived"},
	],
},

"dk_forest": {
	"name": "Der Wald",
	"music": "town",
	"ground": "grass",
	"layout": [
		"TTTT....TTTTTTTTTTTT",
		"TTT......TTTTTTTTTTT",
		'T..""...b...."".....',
		"....................",
		"..b.......b.........",
		"...........,,.......",
		'T...""..........b...',
		"....................",
		"TTTTTTTT....TTTTTTTT",
	],
	"legend": {},
	"warps": [
		{"x": 9, "y": 0, "to": "dk_shore", "tx": 9, "ty": 7},
		{"x": 9, "y": 8, "to": "dk_rocky", "tx": 9, "ty": 1},
		{"x": 10, "y": 8, "to": "dk_rocky", "tx": 9, "ty": 1},
	],
	"npcs": [
		{"sprite": "npc02", "x": 4, "y": 5, "dir": "down", "duelist": true,
		 "deck": "random_t2", "name": "Waldduellant",
		 "lines": ["Na los, zeig, was du kannst!"],
		 "win": ["Verdammt … du hast mich geschlagen."],
		 "lose": ["Zu schwach! Übe noch etwas."]},
	],
	"triggers": [
		{"x": 13, "y": 4, "w": 3, "h": 2, "scene": "dk_weevil",
		 "once": "dk_weevil_done", "require": "dk_arrived"},
	],
},

"dk_rocky": {
	"name": "Felsige Ebene",
	"music": "town",
	"ground": "dirt",
	"layout": [
		"^^^^^....^^^^^^^^^^^",
		"^^^..............^^^",
		"^....r......r......^",
		"...................^",
		"..r...........r....^",
		"...................^",
		"^....r......r......^",
		"^^^..............^^^",
		"^^^^^^^^....^^^^^^^^",
	],
	"legend": {},
	"warps": [
		{"x": 9, "y": 0, "to": "dk_forest", "tx": 9, "ty": 7},
		{"x": 9, "y": 8, "to": "dk_hill", "tx": 9, "ty": 1},
		{"x": 10, "y": 8, "to": "dk_hill", "tx": 9, "ty": 1},
	],
	"npcs": [],
	"triggers": [
		{"x": 12, "y": 3, "w": 4, "h": 2, "scene": "dk_rex",
		 "once": "dk_rex_done", "require": "dk_arrived"},
	],
},

"dk_hill": {
	"name": "Sonniger Hügel",
	"music": "town",
	"ground": "grass",
	"layout": [
		"TTTTT....TTTTTTTTTTT",
		"...*..........*.....",
		"....................",
		"..b......*.......b..",
		"....................",
		".....*.......*......",
		"....................",
		"...b.............b..",
		"TTTTTTTT....TTTTTTTT",
	],
	"legend": {},
	"warps": [
		{"x": 9, "y": 0, "to": "dk_rocky", "tx": 9, "ty": 7},
		{"x": 9, "y": 8, "to": "dk_castle_ext", "tx": 9, "ty": 1},
		{"x": 10, "y": 8, "to": "dk_castle_ext", "tx": 9, "ty": 1},
	],
	"npcs": [
		{"sprite": "npc09", "x": 15, "y": 6, "dir": "left", "duelist": true,
		 "deck": "random_t2", "name": "Möchtegern-Profi",
		 "lines": ["Amateure sollten zu Hause bleiben."],
		 "win": ["Unfassbar. Ich dachte, ich hätte dich durchschaut."],
		 "lose": ["Was hab ich gesagt? Amateur."]},
	],
	"triggers": [
		{"x": 12, "y": 3, "w": 4, "h": 2, "scene": "dk_mai",
		 "once": "dk_mai_done", "require": "dk_arrived"},
	],
},

"dk_castle_ext": {
	"name": "Vor dem Schloss",
	"music": "tense",
	"ground": "stone_path",
	"layout": [
		"^^^^^....^^^^^^^^^^^",
		"^^..............^^^^",
		"^..................^",
		"^..................^",
		"^..................^",
		"^..................^",
		"####################",
		"####DD##############",
	],
	"legend": {},
	"warps": [
		{"x": 9, "y": 0, "to": "dk_hill", "tx": 9, "ty": 7},
		{"x": 4, "y": 7, "to": "dk_castle_int", "tx": 7, "ty": 8},
		{"x": 5, "y": 7, "to": "dk_castle_int", "tx": 7, "ty": 8},
	],
	"npcs": [],
	"triggers": [
		{"x": 12, "y": 3, "w": 4, "h": 2, "scene": "dk_keith",
		 "once": "dk_keith_done", "require": "dk_arrived"},
		{"x": 3, "y": 6, "w": 4, "h": 1, "scene": "dk_castle_gate",
		 "once": "dk_gate_done", "require": "dk_four_done"},
	],
},

"dk_castle_int": {
	"name": "Pegasus' Schloss",
	"music": "tense",
	"ground": "carpet",
	"indoor": true,
	"layout": [
		"###############",
		"#p...........p#",
		"#.............#",
		"#.............#",
		"#.............#",
		"#.............#",
		"#p...........p#",
		"#.............#",
		"#######DD######",
	],
	"legend": {"p": "pillar"},
	"warps": [{"x": 7, "y": 8, "to": "dk_castle_ext", "tx": 4, "ty": 6},
			  {"x": 8, "y": 8, "to": "dk_castle_ext", "tx": 4, "ty": 6}],
	"npcs": [],
	"triggers": [
		{"x": 5, "y": 2, "w": 5, "h": 2, "scene": "dk_pegasus",
		 "once": "dk_pegasus_done", "require": "dk_gate_done"},
	],
},

# ------------------------------------------------------ MEMORY WORLD
"eg_palace_ext": {
	"name": "Palastbezirk",
	"music": "egypt",
	"ground": "sand",
	"layout": [
		"%%%%%%%%%%%%%%%%%%%%",
		"..P..............P..",
		"....................",
		"..,,....,,....,,....",
		"....................",
		"..P..............P..",
		"....................",
		"#######DD###########",
	],
	"legend": {},
	"warps": [
		{"x": 7, "y": 7, "to": "eg_throne", "tx": 7, "ty": 8},
		{"x": 8, "y": 7, "to": "eg_throne", "tx": 7, "ty": 8},
		{"x": 0, "y": 4, "to": "eg_village", "tx": 18, "ty": 4},
		{"x": 19, "y": 4, "to": "eg_temple", "tx": 1, "ty": 4},
		{"x": 9, "y": 0, "to": "eg_desert", "tx": 9, "ty": 7},
	],
	"npcs": [
		{"sprite": "npc10", "x": 5, "y": 4, "dir": "down",
		 "lines": ["Der Pharao beschützt uns. Möge Ra ihn segnen."]},
	],
	"triggers": [
		{"x": 11, "y": 3, "w": 4, "h": 2, "scene": "mem_thiefking",
		 "once": "mem_tk_done", "require": "mem_court_done"},
	],
},

"eg_throne": {
	"name": "Thronsaal",
	"music": "egypt",
	"ground": "sandstone",
	"indoor": true,
	"layout": [
		"###############",
		"#HHHH#####HHHH#",
		"#.............#",
		"#p...........p#",
		"#.............#",
		"#.............#",
		"#p...........p#",
		"#.............#",
		"#######DD######",
	],
	"legend": {"H": "hieroglyph", "p": "pillar"},
	"warps": [{"x": 7, "y": 8, "to": "eg_palace_ext", "tx": 7, "ty": 6},
			  {"x": 8, "y": 8, "to": "eg_palace_ext", "tx": 7, "ty": 6}],
	"npcs": [],
	"triggers": [
		{"x": 5, "y": 2, "w": 5, "h": 2, "scene": "mem_court",
		 "once": "mem_court_done", "require": "mem_entered"},
		{"x": 5, "y": 4, "w": 5, "h": 2, "scene": "mem_mahad",
		 "once": "mem_mahad_done", "require": "mem_tk_done"},
	],
},

"eg_village": {
	"name": "Kul Elna",
	"music": "sad",
	"ground": "dirt",
	"layout": [
		"####################",
		"#..................#",
		"#..##....##....##..#",
		"#..................#",
		"...................#",
		"#..##....##....##..#",
		"#..................#",
		"####################",
	],
	"legend": {},
	"warps": [{"x": 19, "y": 4, "to": "eg_palace_ext", "tx": 1, "ty": 4}],
	"npcs": [],
	"triggers": [
		{"x": 8, "y": 3, "w": 4, "h": 2, "scene": "mem_search",
		 "once": "mem_village_done", "require": "mem_mahad_done",
		 "flag": "mem_village_visited"},
	],
},

"eg_temple": {
	"name": "Der Tempel",
	"music": "egypt",
	"ground": "sandstone",
	"indoor": true,
	"layout": [
		"###############",
		"#HHHHHHHHHHHHH#",
		"#.............#",
		"#p...........p#",
		"#.............#",
		"#p...........p#",
		"#.............#",
		"#######DD######",
	],
	"legend": {"H": "hieroglyph", "p": "pillar"},
	"warps": [{"x": 7, "y": 7, "to": "eg_palace_ext", "tx": 18, "ty": 4},
			  {"x": 8, "y": 7, "to": "eg_palace_ext", "tx": 18, "ty": 4}],
	"npcs": [
		{"sprite": "mahad", "x": 4, "y": 4, "dir": "right", "key": "mahad",
		 "lines": ["Die Schriftrollen sprechen von drei göttlichen Bestien."]},
	],
	"triggers": [
		{"x": 6, "y": 2, "w": 4, "h": 2, "scene": "mem_search",
		 "once": "mem_temple_done", "require": "mem_mahad_done",
		 "flag": "mem_temple_visited"},
		{"x": 6, "y": 5, "w": 4, "h": 1, "scene": "mem_name",
		 "once": "mem_name_done", "require": "mem_seto_done"},
	],
},

"eg_desert": {
	"name": "Die Wüste",
	"music": "egypt",
	"ground": "sand",
	"layout": [
		"%%%%%%%%%%%%%%%%%%%%",
		"%..................%",
		"%....r........r....%",
		"%..................%",
		"%.......%%%........%",
		"%..................%",
		"%....r........r....%",
		"%%%%%%%%....%%%%%%%%",
	],
	"legend": {},
	"warps": [{"x": 9, "y": 7, "to": "eg_palace_ext", "tx": 9, "ty": 1},
			  {"x": 10, "y": 7, "to": "eg_palace_ext", "tx": 9, "ty": 1}],
	"npcs": [
		{"sprite": "npc04", "x": 13, "y": 3, "dir": "left", "duelist": true,
		 "deck": "random_t3", "name": "Grabräuber",
		 "lines": ["Das Grab gehört mir! Verschwinde!"],
		 "win": ["Verflucht … du bist stärker als du aussiehst."],
		 "lose": ["Der Schatz gehört mir!"]},
	],
	"triggers": [],
},

"tomb": {
	"name": "Zeremonienkammer",
	"music": "sad",
	"ground": "sandstone",
	"indoor": true,
	"layout": [
		"###############",
		"#HHHHHHHHHHHHH#",
		"#.............#",
		"#p...........p#",
		"#.............#",
		"#p...........p#",
		"#.............#",
		"#######DD######",
	],
	"legend": {"H": "hieroglyph", "p": "pillar"},
	"warps": [{"x": 7, "y": 7, "to": "domino_plaza", "tx": 9, "ty": 4},
			  {"x": 8, "y": 7, "to": "domino_plaza", "tx": 9, "ty": 4}],
	"npcs": [],
	"triggers": [
		{"x": 5, "y": 2, "w": 5, "h": 2, "scene": "fin_ceremonial",
		 "once": "fin_done", "require": "mem_finished"},
	],
},
}
