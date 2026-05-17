class_name Enemy
extends CharacterBody2D

# === 属性 ===
@export var max_health: int = 30
@export var move_speed: float = 120.0
@export var contact_damage: int = 10
@export var score_value: int = 1
@export var xp_value: int = 15

# === 节点引用 ===
@onready var sprite: ColorRect = $Sprite
@onready var hp_bar: ProgressBar = $HealthBar
@onready var contact_area: Area2D = $ContactArea

# === 变量 ===
var _health: int
var _player_ref: Node2D = null
var is_dead: bool = false

func _ready() -> void:
	_health = max_health
	_update_hp()

	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player_ref = players[0]

func _physics_process(_delta: float) -> void:
	if is_dead or _player_ref == null:
		return

	var direction := global_position.direction_to(_player_ref.global_position)
	velocity = direction * move_speed
	move_and_slide()

func take_damage(amount: int) -> void:
	if is_dead:
		return

	var actual: int = max(amount, 1)
	_health = max(_health - actual, 0)
	_update_hp()

	sprite.modulate = Color.WHITE
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, 0.06)

	if _health <= 0:
		_die()

func _die() -> void:
	is_dead = true
	EventBus.enemy_killed.emit(global_position, score_value)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
	tween.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.25)
	tween.chain().tween_callback(queue_free)

func get_contact_damage() -> int:
	return contact_damage

func _update_hp() -> void:
	var ratio := (_health as float / max_health) * 100.0
	hp_bar.value = ratio
	hp_bar.visible = ratio < 100.0
