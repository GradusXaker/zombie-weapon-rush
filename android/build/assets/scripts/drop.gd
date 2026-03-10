extends Area2D

signal picked(drop: Node, kind: String, value: String)
signal expired(drop: Node)

var kind := "weapon_swap"
var value := ""
var lifetime := 12.0
var _active := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	deactivate()

func setup(kind_id: String, payload: String = "") -> void:
	_active = true
	visible = true
	monitoring = true
	monitorable = true
	set_process(true)
	kind = kind_id
	value = payload
	lifetime = 12.0
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
	lifetime -= delta
	if lifetime <= 0.0:
		_expire()
	queue_redraw()

func _draw() -> void:
	var c = Color(0.4, 0.8, 1.0)
	if kind == "weapon_swap":
		if value == "pistol":
			c = Color(0.3, 0.9, 0.4)
		elif value == "shotgun":
			c = Color(0.25, 0.65, 1.0)
		else:
			c = Color(0.95, 0.8, 0.25)
	elif kind == "heal":
		c = Color(1.0, 0.4, 0.4)
	elif kind == "rapid_fire":
		c = Color(1.0, 0.8, 0.2)
	draw_circle(Vector2.ZERO, 12.0, c)

func _on_body_entered(body: Node) -> void:
	if not _active:
		return
	if body.is_in_group("player"):
		_active = false
		picked.emit(self, kind, value)

func _expire() -> void:
	if not _active:
		return
	_active = false
	expired.emit(self)
