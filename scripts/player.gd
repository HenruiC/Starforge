class_name Player
extends CharacterBody2D

# === 属性 ===
@export var max_health: int = 100
@export var move_speed: float = 300.0
@export var attack_range: float = 120.0
@export var attack_damage: int = 15
@export var attack_cooldown: float = 0.5

# === 节点引用 ===
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var hit_flash: ColorRect = $HitFlash
@onready var sprite: ColorRect = $Sprite
@onready var hp_bar: ProgressBar = $UI/HealthBar
@onready var hp_label: Label = $UI/HealthLabel

# === 私有变量 ===
var _health: int
var _attack_timer: float = 0.0
var _current_target: Node2D = null
var _is_dead: bool = false

func _ready() -> void:
	_health = max_health
	_update_hp_ui()

	# 设置攻击范围
	(attack_shape.shape as CircleShape2D).radius = attack_range

	# 攻击区域检测
	attack_area.body_entered.connect(_on_enemy_in_range)
	attack_area.body_exited.connect(_on_enemy_out_of_range)

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# 移动
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * move_speed
	move_and_slide()

	# 自动攻击
	_attack_timer += delta
	if _attack_timer >= attack_cooldown and _current_target != null:
		_attack_timer = 0.0
		_attack_current_target()

func _attack_current_target() -> void:
	if not is_instance_valid(_current_target):
		_current_target = null
		return

	if _current_target and _current_target.has_method("take_damage") and not _current_target.is_dead:
		_current_target.take_damage(attack_damage)
		# 攻击闪光
		_show_attack_flash()

func _show_attack_flash() -> void:
	sprite.modulate = Color.RED
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func take_damage(amount: int) -> void:
	if _is_dead:
		return

	_health = max(_health - amount, 0)
	_update_hp_ui()
	EventBus.player_hit.emit(amount, _health)

	# 受击闪红
	var tween := create_tween()
	tween.tween_property(hit_flash, "color:a", 0.3, 0.05)
	tween.tween_property(hit_flash, "color:a", 0.0, 0.15)

	if _health <= 0:
		_die()

func _die() -> void:
	_is_dead = true
	EventBus.player_died.emit()
	sprite.modulate = Color(0.4, 0.4, 0.4, 0.6)
	set_physics_process(false)

func heal(amount: int) -> void:
	_health = min(_health + amount, max_health)
	_update_hp_ui()

func _update_hp_ui() -> void:
	hp_bar.value = (_health as float / max_health) * 100.0
	hp_label.text = "%d / %d" % [_health, max_health]

func _on_enemy_in_range(body: Node2D) -> void:
	if body.is_in_group("enemy") and _current_target == null:
		_current_target = body

func _on_enemy_out_of_range(body: Node2D) -> void:
	if body == _current_target:
		_current_target = null
		# 找范围内最近的敌人
		var bodies := attack_area.get_overlapping_bodies()
		for b in bodies:
			if b.is_in_group("enemy") and not b.is_dead:
				_current_target = b
				break
