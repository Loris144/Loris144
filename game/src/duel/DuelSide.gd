class_name DuelSide
extends RefCounted
## One duelist's side of the field.

const MZONES := 5
const SZONES := 5

var name: String = "Spieler"
var sprite: String = "player_m_quiet"
var lp: int = 8000
var deck: Array = []               # Array[DuelCard], index 0 = top
var hand: Array = []
var monsters: Array = []           # size MZONES, null or DuelCard
var spells: Array = []             # size SZONES, null or DuelCard
var field_spell = null
var grave: Array = []
var banished: Array = []
var extra: Array = []
var normal_summons_left: int = 1
var is_ai: bool = false


func _init() -> void:
	monsters.resize(MZONES)
	spells.resize(SZONES)
	for i in MZONES:
		monsters[i] = null
	for i in SZONES:
		spells[i] = null


func monster_count() -> int:
	var n := 0
	for m in monsters:
		if m != null:
			n += 1
	return n


func free_mzone() -> int:
	for i in MZONES:
		if monsters[i] == null:
			return i
	return -1


func free_szone() -> int:
	for i in SZONES:
		if spells[i] == null:
			return i
	return -1


func attackers() -> Array:
	var out: Array = []
	for m in monsters:
		if m != null and m.face_up and not m.defense and not m.attacked and m.can_attack:
			out.append(m)
	return out


func face_up_monsters() -> Array:
	var out: Array = []
	for m in monsters:
		if m != null and m.face_up:
			out.append(m)
	return out


func all_monsters() -> Array:
	var out: Array = []
	for m in monsters:
		if m != null:
			out.append(m)
	return out


func all_spells() -> Array:
	var out: Array = []
	for s in spells:
		if s != null:
			out.append(s)
	return out


func find_monster_zone(uid: int) -> int:
	for i in MZONES:
		if monsters[i] != null and monsters[i].uid == uid:
			return i
	return -1


func find_spell_zone(uid: int) -> int:
	for i in SZONES:
		if spells[i] != null and spells[i].uid == uid:
			return i
	return -1
