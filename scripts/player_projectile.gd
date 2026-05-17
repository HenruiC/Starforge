class_name PlayerProjectile
extends Area2D

@export var speed: float = 400.0
@export var damage: int = 12
@export var lifetime: float = 3.0
@export var pierce: int = 0  # 穿透数，0=命中后消失

var _direction: Vector2 = Vector2.RIGHT
var _timer: float = 0.0
var _hit_count: int = 0

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
	if body.is_in_group("enemy") and body.has_method("take_damage") and not body.is_dead:
		body.take_damage(damage)
		_hit_count += 1
		if _hit_count > pierce:
			queue_free()
