extends CharacterBody2D

signal died(zombie: Node, pos: Vector2, xp_value: int)

var hp := 30.0
var move_speed := 90.0
var touch_damage := 8.0
var xp_reward := 16
var zombie_type := "walker"
var _player: Node = null
var _damage_cooldown := 0.0
var _wobble := 0.0
var _active := false

func _ready() -> void:
	deactivate()

func setup(player_node: Node, max_hp: float, speed: float, damage: float, kind: String = "walker") -> void:
	_active = true
	visible = true
	set_physics_process(true)
	set_process(true)
	_player = player_node
	hp = max_hp
	move_speed = speed
	touch_damage = damage
	zombie_type = kind
	xp_reward = int(12 + hp * 0.16)
	_wobble = randf() * TAU
	var radius = 18.0
	if zombie_type == "runner":
		radius = 14.0
	elif zombie_type == "tank":
		radius = 26.0
	var shape = $CollisionShape2D.shape
	if shape is CircleShape2D:
		shape.radius = radius
	var collider = $CollisionShape2D
	if collider:
		collider.disabled = false

func deactivate() -> void:
	_active = false
	visible = false
	velocity = Vector2.ZERO
	set_physics_process(false)
	set_process(false)
	var collider = $CollisionShape2D
	if collider:
		collider.disabled = true

func _physics_process(delta: float) -> void:
	if not _active:
		return
	if _player == null or not is_instance_valid(_player):
		return

	_damage_cooldown -= delta
	var to_player = _player.global_position - global_position
	var move_dir = to_player.normalized()
	if zombie_type == "runner":
		_wobble += delta * 8.0
		move_dir = move_dir.rotated(sin(_wobble) * 0.26)
	velocity = move_dir * move_speed
	move_and_slide()

	if to_player.length() < 28.0 and _damage_cooldown <= 0.0:
		_player.take_damage(touch_damage)
		_damage_cooldown = 0.7

	queue_redraw()

func _draw() -> void:
	var c = Color(0.76, 0.2, 0.24)
	var r = 18.0
	if zombie_type == "runner":
		c = Color(0.98, 0.52, 0.18)
		r = 14.0
	elif zombie_type == "tank":
		c = Color(0.5, 0.2, 0.72)
		r = 26.0
	draw_circle(Vector2.ZERO, r, c)
	draw_circle(Vector2(-6, -3), 3.0, Color(0.1, 0.05, 0.05))
	draw_circle(Vector2(6, -3), 3.0, Color(0.1, 0.05, 0.05))

func take_hit(amount: float) -> void:
	if not _active:
		return
	hp -= amount
	if hp <= 0.0:
		died.emit(self, global_position, xp_reward)
