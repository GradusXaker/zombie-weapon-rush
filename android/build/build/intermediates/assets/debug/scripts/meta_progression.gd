extends Node

const SAVE_PATH := "user://meta_progression.save"

var total_scrap := 0
var unlocked_weapons: Array[String] = ["pistol"]
var unlock_costs := {
	"shotgun": 120,
	"rifle": 180
}

var session_scrap := 0

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		save_data()
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var raw = file.get_as_text()
	if raw.is_empty():
		return
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var dict: Dictionary = parsed
	total_scrap = int(dict.get("total_scrap", 0))
	unlocked_weapons.clear()
	for id in dict.get("unlocked_weapons", ["pistol"]):
		unlocked_weapons.append(str(id))
	if not unlocked_weapons.has("pistol"):
		unlocked_weapons.append("pistol")

func save_data() -> void:
	var payload = {
		"total_scrap": total_scrap,
		"unlocked_weapons": unlocked_weapons
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload))

func begin_session() -> void:
	session_scrap = 0

func set_unlock_costs(costs: Dictionary) -> void:
	unlock_costs = costs.duplicate(true)

func add_scrap(amount: int) -> void:
	session_scrap += max(0, amount)

func commit_session() -> void:
	total_scrap += session_scrap
	session_scrap = 0
	save_data()

func can_unlock(weapon_id: String) -> bool:
	if unlocked_weapons.has(weapon_id):
		return false
	if not unlock_costs.has(weapon_id):
		return false
	return total_scrap >= int(unlock_costs[weapon_id])

func unlock_weapon(weapon_id: String) -> bool:
	if not can_unlock(weapon_id):
		return false
	total_scrap -= int(unlock_costs[weapon_id])
	unlocked_weapons.append(weapon_id)
	save_data()
	return true

func get_unlock_entries() -> Array:
	var result: Array = []
	var ids = unlock_costs.keys()
	ids.sort()
	for weapon_id in ids:
		result.append({
			"id": weapon_id,
			"cost": int(unlock_costs[weapon_id]),
			"unlocked": unlocked_weapons.has(weapon_id),
			"affordable": total_scrap >= int(unlock_costs[weapon_id])
		})
	return result
