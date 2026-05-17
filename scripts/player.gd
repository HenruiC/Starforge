class_name Player
extends CharacterBody2D

# === 属性 ===
@export var max_health: int = 100
@export var move_speed: float = 300.0
@export var attack_range: float = 120.0
@export var attack_power: int = 15
@export var defense: int = 2
@export var attack_cooldown: float = 0.5
@export var contact_damage_cooldown: float = 1.0

# 成长
@export var level: int = 1
@export var exp: int = 0
@export var exp_to_next: int = 50

# === 节点引用 ===
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var hitbox: Area2D = $Hitbox
@onready var hit_flash: ColorRect = $HitFlash
@onready var sprite: ColorRect = $Sprite

# HUD
@onready var hp_bar: ProgressBar = $HUD/HBox/HPBox/HPBar
@onready var hp_label: Label = $HUD/HBox/HPBox/HPLabel
@onready var exp_bar: ProgressBar = $HUD/EXPBar
@onready var level_label: Label = $HUD/LevelLabel
@onready var stats_label: Label = $HUD/StatsLabel

# === 私有变量 ===
var _health: int
var _attack_timer: float = 0.0
var _current_target: Node2D = null
var _contact_timer: float = 0.0
var _is_dead: bool = false

func _ready() -> void:
	_health = max_health
	(attack_shape.shape as CircleShape2D).radius = attack_range

	attack_area.body_entered.connect(_on_enemy_in_range)
	attack_area.body_exited.connect(_on_enemy_out_of_range)

	_update_all_ui()

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# 移动
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * move_speed
	move_and_slide()

	# 接触伤害（持续检测重叠的敌人）
	_contact_timer += delta
	if _contact_timer >= contact_damage_cooldown:
		_contact_timer = 0.0
		_check_contact_damage()

	# 自动攻击
	_attack_timer += delta
	if _attack_timer >= attack_cooldown and _current_target != null:
		_attack_timer = 0.0
		_attack_current_target()

func _check_contact_damage() -> void:
	var bodies := hitbox.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("enemy") and body.has_method("get_contact_damage"):
			var raw_dmg: int = body.get_contact_damage()
			take_damage(raw_dmg)

func _attack_current_target() -> void:
	if not is_instance_valid(_current_target) or not _current_target.has_method("take_damage") or _current_target.is_dead:
		_current_target = null
		return

	_current_target.take_damage(attack_power)
	_show_attack_flash()

func _show_attack_flash() -> void:
	sprite.modulate = Color(1.5, 1.5, 1.5, 1.0)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.08)

func take_damage(raw_amount: int) -> void:
	if _is_dead:
		return

	var actual: int = max(raw_amount - defense, 1)
	_health = max(_health - actual, 0)
	_update_all_ui()
	EventBus.player_hit.emit(actual, _health)

	var tween := create_tween()
	tween.tween_property(hit_flash, "color:a", 0.35, 0.04)
	tween.tween_property(hit_flash, "color:a", 0.0, 0.12)

	if _health <= 0:
		_die()

func _die() -> void:
	_is_dead = true
	EventBus.player_died.emit()
	sprite.modulate = Color(0.4, 0.4, 0.4, 0.6)
	set_physics_process(false)

func gain_exp(amount: int) -> void:
	exp += amount
	while exp >= exp_to_next:
		exp -= exp_to_next
		_level_up()
	_update_all_ui()

func _level_up() -> void:
	level += 1
	exp_to_next = int(exp_to_next * 1.35)
	attack_power += 3
	max_health += 15
	_health = min(_health + 15, max_health)
	defense += 1
	move_speed += 5

	EventBus.enemy_killed.emit(Vector2.ZERO, 0)  # 仅触发UI刷新

func _update_all_ui() -> void:
	hp_bar.value = clamp((_health as float / max_health) * 100.0, 0.0, 100.0)
	hp_label.text = "%d / %d" % [_health, max_health]

	exp_bar.value = clamp((exp as float / exp_to_next) * 100.0, 0.0, 100.0)
	level_label.text = "Lv.%d" % level

	stats_label.text = "ATK: %d  DEF: %d  SPD: %.0f" % [attack_power, defense, move_speed]

func _on_enemy_in_range(body: Node2D) -> void:
	if body.is_in_group("enemy") and _current_target == null:
		_current_target = body

func _on_enemy_out_of_range(body: Node2D) -> void:
	if body == _current_target:
		_current_target = null
		for b in attack_area.get_overlapping_bodies():
			if b.is_in_group("enemy") and not b.is_dead:
				_current_target = b
				break
