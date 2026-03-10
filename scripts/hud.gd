extends CanvasLayer

signal upgrade_selected(id: String)
signal restart_pressed
signal unlock_requested(id: String)

@onready var hp_label: Label = $Root/TopBar/HpLabel
@onready var level_label: Label = $Root/TopBar/LevelLabel
@onready var weapon_label: Label = $Root/TopBar/WeaponLabel
@onready var scrap_label: Label = $Root/TopBar/ScrapLabel
@onready var xp_bar: ProgressBar = $Root/XpBar
@onready var upgrade_panel: Panel = $Root/UpgradePanel
@onready var option_1: Button = $Root/UpgradePanel/Margin/UpgradeVBox/Option1
@onready var option_2: Button = $Root/UpgradePanel/Margin/UpgradeVBox/Option2
@onready var option_3: Button = $Root/UpgradePanel/Margin/UpgradeVBox/Option3
@onready var game_over_panel: Panel = $Root/GameOver
@onready var unlock_1: Button = $Root/GameOver/GameOverMargin/GameOverVBox/Unlock1
@onready var unlock_2: Button = $Root/GameOver/GameOverMargin/GameOverVBox/Unlock2
@onready var restart_button: Button = $Root/GameOver/GameOverMargin/GameOverVBox/RestartButton

var _current_options: Array = []
var _weapon_name := "Pistol"
var _weapon_tier := 1
var _labels := {
	"damage_up": "Damage +",
	"fire_rate_up": "Fire Rate +",
	"bullet_speed_up": "Bullet Speed +",
	"multishot_up": "Multishot +",
	"crit_up": "Crit Chance +",
	"heal_up": "Repair HP"
}

func _ready() -> void:
	option_1.pressed.connect(func(): _pick(0))
	option_2.pressed.connect(func(): _pick(1))
	option_3.pressed.connect(func(): _pick(2))
	unlock_1.pressed.connect(func(): _request_unlock(unlock_1))
	unlock_2.pressed.connect(func(): _request_unlock(unlock_2))
	restart_button.pressed.connect(func(): restart_pressed.emit())

func update_hp(current: int, max_hp: int) -> void:
	hp_label.text = "HP: %d/%d" % [current, max_hp]

func update_level(value: int) -> void:
	level_label.text = "LVL: %d" % value

func update_weapon_tier(value: int) -> void:
	_weapon_tier = value
	_refresh_weapon_label()

func update_weapon_name(name: String) -> void:
	_weapon_name = name
	_refresh_weapon_label()

func update_scrap(total: int, pending: int) -> void:
	scrap_label.text = "Scrap: %d (+%d)" % [total, pending]

func update_xp(current: int, needed: int) -> void:
	xp_bar.max_value = float(needed)
	xp_bar.value = float(current)

func show_upgrade_options(options: Array) -> void:
	_current_options = options
	option_1.text = _labels.get(options[0], options[0])
	option_2.text = _labels.get(options[1], options[1])
	option_3.text = _labels.get(options[2], options[2])
	upgrade_panel.visible = true

func hide_upgrade_options() -> void:
	upgrade_panel.visible = false

func show_game_over(unlock_entries: Array) -> void:
	_apply_unlock_button(unlock_1, unlock_entries, 0)
	_apply_unlock_button(unlock_2, unlock_entries, 1)
	game_over_panel.visible = true

func _pick(index: int) -> void:
	if index >= 0 and index < _current_options.size():
		upgrade_selected.emit(_current_options[index])

func _apply_unlock_button(button: Button, entries: Array, index: int) -> void:
	if index >= entries.size():
		button.visible = false
		button.disabled = true
		button.set_meta("unlock_id", "")
		return
	button.visible = true
	var entry: Dictionary = entries[index]
	var weapon_id = str(entry.get("id", ""))
	var cost = int(entry.get("cost", 0))
	var unlocked = bool(entry.get("unlocked", false))
	var affordable = bool(entry.get("affordable", false))
	button.set_meta("unlock_id", weapon_id)
	if unlocked:
		button.text = "%s unlocked" % weapon_id.capitalize()
		button.disabled = true
	else:
		button.text = "Unlock %s (%d scrap)" % [weapon_id.capitalize(), cost]
		button.disabled = not affordable

func _request_unlock(button: Button) -> void:
	var id = str(button.get_meta("unlock_id", ""))
	if not id.is_empty():
		unlock_requested.emit(id)

func _refresh_weapon_label() -> void:
	weapon_label.text = "%s T%d" % [_weapon_name, _weapon_tier]
