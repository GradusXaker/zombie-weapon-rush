extends Area2D

signal expired(bullet: Node)

var direction := Vector2.RIGHT
var damage := 10.0
var speed := 600.0
var life := 1.8
var _active := false

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	deactivate()

func setup(dir: Vector2, bullet_damage: float, bullet_speed: float) -> void:
	_active = true
	visible = true
	monitoring = true
	monitorable = true
	set_process(true)
	direction = dir.normalized()
	damage = bullet_damage
	speed = bullet_speed
	life = 1.8
	var collider = $CollisionShape2D
	if collider:
		collider.disabled = false

func deactivate() -> void:
	_active = false
	visible = false
	monitoring = false
	monitorable = false
	set_process(false)
	var collider = $CollisionShape2D
	if collider:
		collider.disabled = true

func _process(delta: float) -> void:
	if not _active:
		return
	global_position += direction * speed * delta
	life -= delta
	if life <= 0.0:
		_expire()
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.86, 0.33))

func _on_area_entered(_area: Area2D) -> void:
	pass

func _on_body_entered(body: Node) -> void:
	if not _active:
		return
	if body.has_method("take_hit"):
		body.take_hit(damage)
		_expire()

func _expire() -> void:
	if not _active:
		return
	_active = false
	expired.emit(self)
