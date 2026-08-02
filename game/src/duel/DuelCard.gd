class_name DuelCard
extends RefCounted
## One physical card instance inside a duel.

var id: int = 0                   # card database id
var uid: int = 0                  # unique instance id within the duel
var face_up: bool = true
var defense: bool = false
var can_attack: bool = true
var attacked: bool = false
var summoned_this_turn: bool = false
var position_changed: bool = false
var atk_mod: int = 0
var def_mod: int = 0
var equips: Array = []
var counters: int = 0
var negated: bool = false
var just_set: bool = false
var is_token: bool = false


func _init(card_id: int = 0, unique: int = 0) -> void:
	id = card_id
	uid = unique


func atk() -> int:
	return maxi(0, CardDB.atk(id) + atk_mod)


func def_() -> int:
	return maxi(0, CardDB.def(id) + def_mod)


func level() -> int:
	return CardDB.level(id)


func name() -> String:
	return CardDB.card_name(id)


func eng_name() -> String:
	return str(CardDB.get_card(id).get("name", ""))


func reset_field_state() -> void:
	face_up = true
	defense = false
	atk_mod = 0
	def_mod = 0
	attacked = false
	summoned_this_turn = false
	position_changed = false
	just_set = false
	equips.clear()
