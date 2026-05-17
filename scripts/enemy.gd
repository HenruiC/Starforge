class_name Enemy
extends CharacterBody2D

# === 属性 ===
@export var max_health: int = 30
@export var move_speed: float = 120.0
@export var contact_damage: int = 10
@export var score_value: int = 1
@export var xp_value: int = 5

# === 节点引用 ===
@onready var sprite: ColorRect = $Sprite
@onready var hp_bar: ProgressBar = $HealthBar

# === 变量 ===
var _health: int
var _player_ref: Node2D = null
var is_dead: bool = false

func _ready() -> void:
	_health = max_health
	_update_hp()

	# 获取玩家引用
	var tree := get_tree()
	if tree:
		var players := tree.get_nodes_in_group("player")
		if players.size() > 0:
			_player_ref = players[0]

func _physics_process(_delta: float) -> void:
	if is_dead or _player_ref == null:
		return

	# 朝玩家移动
	var direction := global_position.direction_to(_player_ref.global_position)
	velocity = direction * move_speed
	move_and_slide()

	# 朝向玩家
	look_at(_player_ref.global_position)

func take_damage(amount: int) -> void:
	if is_dead:
		return

	_health = max(_health - amount, 0)
	_update_hp()

	# 受击闪白
	sprite.modulate = Color.WHITE
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, 0.08)

	if _health <= 0:
		_die()

func _die() -> void:
	is_dead = true
	EventBus.enemy_killed.emit(global_position, score_value)

	# 死亡动画
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.3)
	tween.chain().tween_callback(queue_free)

func _update_hp() -> void:
	var ratio := (_health as float / max_health) * 100.0
	hp_bar.value = ratio
	hp_bar.visible = ratio < 100.0

# 接触玩家时造成伤害
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_dead:
		body.take_damage(contact_damage)
