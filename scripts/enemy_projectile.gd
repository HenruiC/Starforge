class_name EnemyProjectile
extends Area2D

@export var speed: float = 250.0
@export var damage: int = 8
@export var lifetime: float = 5.0

var _direction: Vector2 = Vector2.ZERO
var _timer: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_hit)

func setup(dir: Vector2, spd: float, dmg: int) -> void:
	_direction = dir
	speed = spd
	damage = dmg
	rotation = dir.angle()

func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer > lifetime:
		queue_free()
		return

	position += _direction * speed * delta

func _on_hit(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
