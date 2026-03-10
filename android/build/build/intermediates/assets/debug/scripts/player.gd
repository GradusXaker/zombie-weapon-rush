extends CharacterBody2D

signal hp_changed(current: int, max: int)
signal xp_changed(current: int, needed: int)
signal level_changed(value: int)
signal weapon_tier_changed(value: int)
signal weapon_changed(name: String)
signal request_upgrade(options: Array)
signal died

const MOVE_SPEED := 220.0
const TOUCH_DEADZONE := 24.0

var max_hp := 100
var hp := 100
var level := 1
var xp := 0
var xp_to_next_level := 100
var weapon_tier := 1

var weapon_defs := {
	"pistol": {
		"name": "Pistol",
		"damage": 14.0,
		"fire_rate": 2.8,
		"bullet_speed": 640.0,
		"pellets": 1,
		"spread": 0.05,
		"crit": 0.06
	},
	"shotgun": {
		"name": "Shotgun",
		"damage": 8.0,
		"fire_rate": 1.45,
		"bullet_speed": 560.0,
		"pellets": 5,
		"spread": 0.22,
		"crit": 0.04
	},
	"rifle": {
		"name": "Rifle",
		"damage": 10.0,
		"fire_rate": 5.3,
		"bullet_speed": 760.0,
		"pellets": 1,
		"spread": 0.03,
		"crit": 0.08
	}
}

var current_weapon_id := "pistol"
var unlocked_weapons: Array[String] = ["pistol"]

var weapon_damage := 14.0
var weapon_fire_rate := 2.8
var weapon_bullet_speed := 640.0
var weapon_pellets := 1
var weapon_spread := 0.05
var weapon_crit := 0.06

var bonus_damage_flat := 0.0
var bonus_fire_rate_flat := 0.0
var bonus_bullet_speed := 0.0
var bonus_multishot := 0
var bonus_spread := 0.0
var bonus_crit := 0.0

var _fire_timer := 0.0
var _rapid_fire_timer := 0.0
var _game: Node = null

var _touch_id := -1
var _touch_origin := Vector2.ZERO
var _touch_vector := Vector2.ZERO

func _ready() -> void:
	add_to_group("player")
	_ensure_action("move_up", Key.KEY_W)
	_ensure_action("move_down", Key.KEY_S)
	_ensure_action("move_left", Key.KEY_A)
	_ensure_action("move_right", Key.KEY_D)
	_apply_weapon_stats("pistol")

func _ensure_action(action_name: String, key: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var event := InputEventKey.new()
	event.physical_keycode = key
	var events = InputMap.action_get_events(action_name)
	for existing in events:
		if existing is InputEventKey and existing.physical_keycode == key:
			return
	InputMap.action_add_event(action_name, event)

func set_game(game_node: Node) -> void:
	_game = game_node

func _physics_process(delta: float) -> void:
	if _rapid_fire_timer > 0.0:
		_rapid_fire_timer -= delta

	var input_vector = _keyboard_input()
	if input_vector == Vector2.ZERO:
		input_vector = _touch_vector

	velocity = input_vector * MOVE_SPEED
	move_and_slide()

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		auto_fire()
		_fire_timer = 1.0 / _effective_fire_rate()

	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 20.0, Color(0.18, 0.8, 0.4))
	draw_circle(Vector2(14, -10), 6.0, Color(0.98, 0.95, 0.8))

func _keyboard_input() -> Vector2:
	var x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	return Vector2(x, y).normalized()

func _unhandled_input(event: InputEvent) -> void:
	var width = get_viewport_rect().size.x
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x <= width * 0.5 and _touch_id == -1:
			_touch_id = event.index
			_touch_origin = event.position
			_touch_vector = Vector2.ZERO
		elif not event.pressed and event.index == _touch_id:
			_touch_id = -1
			_touch_vector = Vector2.ZERO
	elif event is InputEventScreenDrag and event.index == _touch_id:
		var delta_vec = event.position - _touch_origin
		if delta_vec.length() < TOUCH_DEADZONE:
			_touch_vector = Vector2.ZERO
		else:
			_touch_vector = delta_vec.normalized()

func auto_fire() -> void:
	if _game == null:
		return
	var target = _game.get_nearest_zombie(global_position)
	if target == null:
		return

	var to_target = (target.global_position - global_position).normalized()
	var pellet_count = weapon_pellets + bonus_multishot
	var total_spread = weapon_spread + bonus_spread
	for i in pellet_count:
		var offset = (float(i) - float(pellet_count - 1) * 0.5) * total_spread
		var dir = to_target.rotated(offset)
		var damage = _roll_damage()
		_game.spawn_bullet(global_position + dir * 26.0, dir, damage, weapon_bullet_speed + bonus_bullet_speed)

func _effective_fire_rate() -> float:
	if _rapid_fire_timer > 0.0:
		return (weapon_fire_rate + bonus_fire_rate_flat) * 1.45
	return weapon_fire_rate + bonus_fire_rate_flat

func _roll_damage() -> float:
	var crit = min(0.5, weapon_crit + bonus_crit)
	var damage = weapon_damage + bonus_damage_flat + float(weapon_tier - 1) * 1.7
	if randf() <= crit:
		return damage * 2.0
	return damage

func take_damage(amount: float) -> void:
	hp = max(0, hp - int(round(amount)))
	hp_changed.emit(hp, max_hp)
	if hp <= 0:
		died.emit()

func heal(amount: int) -> void:
	hp = min(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next_level:
		xp -= xp_to_next_level
		level += 1
		xp_to_next_level = int(round(xp_to_next_level * 1.28))
		level_changed.emit(level)
		request_upgrade.emit(_get_upgrade_choices())
	xp_changed.emit(xp, xp_to_next_level)

func _get_upgrade_choices() -> Array:
	var pool = [
		"damage_up",
		"fire_rate_up",
		"bullet_speed_up",
		"multishot_up",
		"crit_up",
		"heal_up"
	]
	pool.shuffle()
	return pool.slice(0, 3)

func apply_upgrade(id: String) -> void:
	match id:
		"damage_up":
			bonus_damage_flat += 3.8
		"fire_rate_up":
			bonus_fire_rate_flat += 0.28
		"bullet_speed_up":
			bonus_bullet_speed += 70.0
		"multishot_up":
			bonus_multishot = min(4, bonus_multishot + 1)
			bonus_spread = min(0.16, bonus_spread + 0.018)
		"crit_up":
			bonus_crit = min(0.36, bonus_crit + 0.045)
		"heal_up":
			heal(20)

func apply_weapon_token() -> void:
	weapon_tier += 1
	weapon_tier_changed.emit(weapon_tier)

func apply_temp_rapid_fire(duration: float) -> void:
	_rapid_fire_timer = max(_rapid_fire_timer, duration)

func set_unlocked_weapons(ids: Array[String]) -> void:
	unlocked_weapons.clear()
	for id in ids:
		if weapon_defs.has(id):
			unlocked_weapons.append(id)
	if not unlocked_weapons.has("pistol"):
		unlocked_weapons.append("pistol")
	if not unlocked_weapons.has(current_weapon_id):
		equip_weapon("pistol")

func equip_weapon(id: String) -> void:
	if not weapon_defs.has(id):
		return
	current_weapon_id = id
	_apply_weapon_stats(id)

func switch_to_random_weapon() -> void:
	if unlocked_weapons.size() == 0:
		return
	var pool := unlocked_weapons.duplicate()
	if pool.size() > 1:
		pool.erase(current_weapon_id)
	if pool.size() == 0:
		return
	equip_weapon(str(pool[randi() % pool.size()]))


func get_weapon_name(id: String = "") -> String:
	if id.is_empty():
		id = current_weapon_id
	if weapon_defs.has(id):
		return str(weapon_defs[id]["name"])
	return id.capitalize()

func _apply_weapon_stats(id: String) -> void:
	var cfg = weapon_defs[id]
	weapon_damage = float(cfg["damage"])
	weapon_fire_rate = float(cfg["fire_rate"])
	weapon_bullet_speed = float(cfg["bullet_speed"])
	weapon_pellets = int(cfg["pellets"])
	weapon_spread = float(cfg["spread"])
	weapon_crit = float(cfg["crit"])
	weapon_changed.emit(get_weapon_name(id))

func set_weapon_defs(defs: Dictionary) -> void:
	if defs.is_empty():
		return
	weapon_defs = defs.duplicate(true)
	if not weapon_defs.has("pistol"):
		weapon_defs["pistol"] = {
			"name": "Pistol",
			"damage": 14.0,
			"fire_rate": 2.8,
			"bullet_speed": 640.0,
			"pellets": 1,
			"spread": 0.05,
			"crit": 0.06
		}
	if not weapon_defs.has(current_weapon_id):
		current_weapon_id = "pistol"
	_apply_weapon_stats(current_weapon_id)
