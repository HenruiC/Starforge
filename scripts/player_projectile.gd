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
	if GameState.current_state != GameState.State.PLAYING: return
	_timer += delta
	if _timer > lifetime:
		queue_free()
		return
	position += _direction * speed * delta

func _on_hit(body: Node2D) -> void:
	# 击中敌人
	if body.is_in_group("enemy") and body.has_method("take_damage") and not body.is_dead:
		body.take_damage(damage)
		_hit_count += 1
		if _hit_count > pierce:
			queue_free()
		return

	# 击中可破坏物 — 弹幕销毁
	if body.is_in_group("destructible") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
		_spawn_hit_vfx(body.global_position)

func _spawn_hit_vfx(pos: Vector2) -> void:
	var spark := ColorRect.new()
	spark.color = Color(1.0, 0.8, 0.2, 0.8)
	spark.size = Vector2(6, 6)
	spark.position = pos - Vector2(3, 3)
	spark.z_index = 16
	spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().current_scene.add_child(spark)
	var t := create_tween().set_parallel(true)
	t.tween_property(spark, "scale", Vector2(0.1, 0.1), 0.2)
	t.tween_property(spark, "modulate:a", 0.0, 0.2)
	t.chain().tween_callback(spark.queue_free)
