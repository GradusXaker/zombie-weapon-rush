extends Resource
class_name GameBalance

@export var base_spawn_interval := 1.1
@export var min_spawn_interval := 0.22
@export var spawn_acceleration := 0.01
@export var burst_start_time := 20.0
@export var burst_interval := 15.0
@export var burst_amount := 2

@export var drop_chance := 0.24
@export var weapon_drop_share := 0.46
@export var heal_drop_share := 0.36
@export var rapid_fire_drop_share := 0.18

@export var prewarm_zombies := 70
@export var prewarm_bullets := 140
@export var prewarm_drops := 40
