class_name DuelState
extends RefCounted
## Full state of a duel: two sides, whose turn it is, and the phase.

enum Phase { DRAW, STANDBY, MAIN1, BATTLE, MAIN2, END }

const PHASE_NAMES := {
	Phase.DRAW: "Draw Phase", Phase.STANDBY: "Standby Phase",
	Phase.MAIN1: "Main Phase 1", Phase.BATTLE: "Battle Phase",
	Phase.MAIN2: "Main Phase 2", Phase.END: "End Phase",
}

const START_LP := 8000
const START_HAND := 5
const MZONES := 5
const SZONES := 5
const MAX_HAND := 6

var players: Array = []            # [DuelSide, DuelSide]; 0 = human
var turn_player: int = 0
var phase: int = Phase.MAIN1
var turn: int = 1
var winner: int = -1               # -1 running, 0/1 winner
var win_reason: String = ""
var log_lines: Array = []
var first_turn: bool = true
var _next_uid: int = 1


func _init() -> void:
	players = [DuelSide.new(), DuelSide.new()]


func me() -> DuelSide:
	return players[turn_player]


func opp() -> DuelSide:
	return players[1 - turn_player]


func side(i: int) -> DuelSide:
	return players[i]


func new_uid() -> int:
	_next_uid += 1
	return _next_uid


func add_log(msg: String) -> void:
	log_lines.append(msg)
	if log_lines.size() > 200:
		log_lines.pop_front()


func is_over() -> bool:
	return winner >= 0


func phase_name() -> String:
	return str(PHASE_NAMES.get(phase, "?"))
