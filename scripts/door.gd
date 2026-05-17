class_name Door
extends StaticBody2D

# 门 — 玩家靠近自动打开，可被敌人/技能破坏

@export var open_radius: float = 60.0
@export var max_health: int = 80
var _is_open: bool = false
var _health: int = 80

@onready var sprite: ColorRect = $Sprite
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var detect_area: Area2D = $DetectArea
@onready var hp_bar: ProgressBar = $HealthBar

func _ready() -> void:
	_health = max_health
	add_to_group("destructible")
	add_to_group("door")
	detect_area.body_entered.connect(_on_body_near)

func _on_body_near(body: Node2D) -> void:
	if body.is_in_group("player") and not _is_open:
		_open()

func _open() -> void:
	_is_open = true
	var t := create_tween().set_parallel(true)
	t.tween_property(sprite, "modulate:a", 0.2, 0.3)
	t.tween_property(sprite, "scale", Vector2(0.3, 1.0), 0.3)
	collision.set_deferred("disabled", true)
	hp_bar.visible = false

func take_damage(amount: int) -> void:
	_health = max(_health - amount, 0)
	var ratio: float = float(_health) / float(max_health) * 100.0
	hp_bar.value = ratio
	hp_bar.visible = true

	sprite.modulate = Color.WHITE
	create_tween().tween_property(sprite, "modulate", Color(0.6, 0.5, 0.3, 1.0) if not _is_open else Color(0.3, 0.6, 0.4, 1.0), 0.1)

	if _health <= 0:
		CombatFeedback.hit_particles(global_position, 6, Color(0.5, 0.4, 0.3))
		queue_free()
