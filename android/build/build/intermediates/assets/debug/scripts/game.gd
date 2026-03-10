extends Node2D

const ZOMBIE_SCENE := preload("res://scenes/Zombie.tscn")
const BULLET_SCENE := preload("res://scenes/Bullet.tscn")
const DROP_SCENE := preload("res://scenes/Drop.tscn")
const META_PROGRESSION := preload("res://scripts/meta_progression.gd")
const BALANCE = preload("res://data/game_balance.tres")
const WEAPON_RESOURCES := [
	preload("res://data/weapons/pistol.tres"),
	preload("res://data/weapons/shotgun.tres"),
	preload("res://data/weapons/rifle.tres")
]

@onready var player = $Player
@onready var zombies = $Zombies
@onready var bullets = $Bullets
@onready var drops = $Drops
@onready var hud = $HUD

var elapsed := 0.0
var spawn_timer := 0.0
var next_burst_time := 20.0
var _meta = null
var _session_committed := false
var _weapon_defs := {}
var _weapon_drop_weights := {}
var _unlock_costs := {}
var _zombie_pool: Array = []
var _bullet_pool: Array = []
var _drop_pool: Array = []

func _ready() -> void:
	add_to_group("game")
	randomize()
	_load_weapon_catalog()
	hud.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_meta = META_PROGRESSION.new()
	add_child(_meta)
	_meta.set_unlock_costs(_unlock_costs)
	_meta.load_data()
	_meta.begin_session()
	player.set_game(self)
	player.set_weapon_defs(_weapon_defs)
	player.set_unlocked_weapons(_meta.unlocked_weapons)
	_meta.unlocked_weapons = player.unlocked_weapons.duplicate()
	player.hp_changed.connect(hud.update_hp)
	player.xp_changed.connect(hud.update_xp)
	player.level_changed.connect(hud.update_level)
	player.weapon_tier_changed.connect(hud.update_weapon_tier)
	player.weapon_changed.connect(_on_player_weapon_changed)
	player.request_upgrade.connect(_on_player_request_upgrade)
	player.died.connect(_on_player_died)
	hud.upgrade_selected.connect(_on_upgrade_selected)
	hud.restart_pressed.connect(_on_restart_pressed)
	hud.unlock_requested.connect(_on_unlock_requested)
	hud.update_hp(player.hp, player.max_hp)
	hud.update_xp(player.xp, player.xp_to_next_level)
	hud.update_level(player.level)
	hud.update_weapon_tier(player.weapon_tier)
	hud.update_weapon_name(player.get_weapon_name())
	hud.update_scrap(_meta.total_scrap, _meta.session_scrap)
	next_burst_time = BALANCE.burst_start_time
	_prewarm_pools()

func _process(delta: float) -> void:
	if get_tree().paused:
		return

	elapsed += delta
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = max(BALANCE.min_spawn_interval, BALANCE.base_spawn_interval - elapsed * BALANCE.spawn_acceleration)
		spawn_zombie()

	if elapsed >= next_burst_time:
		spawn_zombie(BALANCE.burst_amount)
		next_burst_time += BALANCE.burst_interval

func spawn_zombie(amount: int = 1) -> void:
	for i in amount:
		var z = _get_zombie()
		var dir = Vector2.RIGHT.rotated(randf() * TAU)
		var distance = randf_range(450.0, 700.0)
		var z_type = _roll_zombie_type()
		z.global_position = player.global_position + dir * distance
		var hp_scale = 1.0 + elapsed * 0.02
		if z_type == "runner":
			z.setup(player, 18.0 * hp_scale, 130.0 + elapsed * 1.5, 7.0 + elapsed * 0.25, z_type)
		elif z_type == "tank":
			z.setup(player, 95.0 * hp_scale, 58.0 + elapsed * 0.8, 14.0 + elapsed * 0.45, z_type)
		else:
			z.setup(player, 30.0 * hp_scale, 80.0 + elapsed * 1.3, 8.0 + elapsed * 0.3, z_type)
		z.visible = true
		zombies.add_child(z)

func _roll_zombie_type() -> String:
	var roll = randf()
	if elapsed < 20.0:
		return "walker"
	if elapsed < 45.0:
		if roll < 0.25:
			return "runner"
		return "walker"
	if roll < 0.2:
		return "tank"
	if roll < 0.55:
		return "runner"
	return "walker"

func spawn_bullet(origin: Vector2, direction: Vector2, damage: float, speed: float) -> void:
	var b = _get_bullet()
	b.global_position = origin
	b.setup(direction, damage, speed)
	bullets.add_child(b)

func get_nearest_zombie(from_pos: Vector2) -> Node:
	var nearest: Node = null
	var nearest_dist := INF
	for z in zombies.get_children():
		if not is_instance_valid(z):
			continue
		if not z.visible:
			continue
		var d = from_pos.distance_squared_to(z.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = z
	return nearest

func _on_zombie_died(zombie: Node, pos: Vector2, xp_value: int) -> void:
	_recycle_zombie(zombie)
	player.add_xp(xp_value)
	_meta.add_scrap(max(1, int(xp_value / 6)))
	hud.update_scrap(_meta.total_scrap, _meta.session_scrap)
	if randf() < BALANCE.drop_chance:
		_spawn_drop(pos)

func _spawn_drop(pos: Vector2) -> void:
	var d = _get_drop()
	d.global_position = pos
	var roll = randf()
	if roll < BALANCE.weapon_drop_share:
		d.setup("weapon_swap", _pick_specific_weapon_drop())
	elif roll < BALANCE.weapon_drop_share + BALANCE.heal_drop_share:
		d.setup("heal", "")
	else:
		d.setup("rapid_fire", "")
	drops.add_child(d)

func _pick_specific_weapon_drop() -> String:
	var unlocked: Array = _meta.unlocked_weapons
	var total_weight := 0.0
	for weapon_id in unlocked:
		total_weight += float(_weapon_drop_weights.get(weapon_id, 1.0))
	if total_weight <= 0.0:
		return "pistol"
	var ticket = randf() * total_weight
	for weapon_id in unlocked:
		ticket -= float(_weapon_drop_weights.get(weapon_id, 1.0))
		if ticket <= 0.0:
			return str(weapon_id)
	return "pistol"

func _on_drop_picked(drop: Node, kind: String, value: String) -> void:
	_recycle_drop(drop)
	match kind:
		"weapon_swap":
			player.equip_weapon(value)
			player.apply_weapon_token()
		"heal":
			player.heal(22)
		"rapid_fire":
			player.apply_temp_rapid_fire(6.0)

func _on_drop_expired(drop: Node) -> void:
	_recycle_drop(drop)

func _on_bullet_expired(bullet: Node) -> void:
	_recycle_bullet(bullet)

func _on_player_request_upgrade(options: Array) -> void:
	get_tree().paused = true
	hud.show_upgrade_options(options)

func _on_upgrade_selected(id: String) -> void:
	player.apply_upgrade(id)
	hud.hide_upgrade_options()
	get_tree().paused = false

func _on_player_died() -> void:
	if not _session_committed:
		_meta.commit_session()
		_session_committed = true
		hud.update_scrap(_meta.total_scrap, _meta.session_scrap)
	get_tree().paused = true
	hud.show_game_over(_meta.get_unlock_entries())

func _on_unlock_requested(weapon_id: String) -> void:
	if _meta.unlock_weapon(weapon_id):
		player.set_unlocked_weapons(_meta.unlocked_weapons)
		hud.update_scrap(_meta.total_scrap, _meta.session_scrap)
	hud.show_game_over(_meta.get_unlock_entries())

func _on_player_weapon_changed(name: String) -> void:
	hud.update_weapon_name(name)

func _load_weapon_catalog() -> void:
	_weapon_defs.clear()
	_weapon_drop_weights.clear()
	_unlock_costs.clear()
	for res in WEAPON_RESOURCES:
		var id: String = str(res.weapon_id)
		_weapon_defs[id] = {
			"name": str(res.display_name),
			"damage": float(res.damage),
			"fire_rate": float(res.fire_rate),
			"bullet_speed": float(res.bullet_speed),
			"pellets": int(res.pellets),
			"spread": float(res.spread),
			"crit": float(res.crit)
		}
		_weapon_drop_weights[id] = float(res.drop_weight)
		if int(res.unlock_cost) > 0:
			_unlock_costs[id] = int(res.unlock_cost)

func _prewarm_pools() -> void:
	for i in BALANCE.prewarm_zombies:
		var z = _create_zombie()
		zombies.add_child(z)
		z.deactivate()
		_zombie_pool.append(z)
	for i in BALANCE.prewarm_bullets:
		var b = _create_bullet()
		bullets.add_child(b)
		b.deactivate()
		_bullet_pool.append(b)
	for i in BALANCE.prewarm_drops:
		var d = _create_drop()
		drops.add_child(d)
		d.deactivate()
		_drop_pool.append(d)

func _create_zombie() -> Node:
	var z = ZOMBIE_SCENE.instantiate()
	z.died.connect(_on_zombie_died)
	return z

func _create_bullet() -> Node:
	var b = BULLET_SCENE.instantiate()
	b.expired.connect(_on_bullet_expired)
	return b

func _create_drop() -> Node:
	var d = DROP_SCENE.instantiate()
	d.picked.connect(_on_drop_picked)
	d.expired.connect(_on_drop_expired)
	return d

func _get_zombie() -> Node:
	if _zombie_pool.is_empty():
		return _create_zombie()
	return _zombie_pool.pop_back()

func _get_bullet() -> Node:
	if _bullet_pool.is_empty():
		return _create_bullet()
	return _bullet_pool.pop_back()

func _get_drop() -> Node:
	if _drop_pool.is_empty():
		return _create_drop()
	return _drop_pool.pop_back()

func _recycle_zombie(zombie: Node) -> void:
	if not is_instance_valid(zombie):
		return
	zombie.deactivate()
	if not _zombie_pool.has(zombie):
		_zombie_pool.append(zombie)

func _recycle_bullet(bullet: Node) -> void:
	if not is_instance_valid(bullet):
		return
	bullet.deactivate()
	if not _bullet_pool.has(bullet):
		_bullet_pool.append(bullet)

func _recycle_drop(drop: Node) -> void:
	if not is_instance_valid(drop):
		return
	drop.deactivate()
	if not _drop_pool.has(drop):
		_drop_pool.append(drop)

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
