class_name SkillShadowClone
extends SkillBase

# 暗影分身 — 生成一个分身吸引敌人3秒后爆炸

@export var clone_duration: float = 3.0
@export var explode_damage: int = 30
@export var explode_radius: float = 120.0

func execute() -> void:
	var pos := player.global_position + Vector2(randf_range(-60, 60), randf_range(-60, 60))

	# 分身视觉
	var clone := _create_effect_rect(Color(0.3, 0.1, 0.5, 0.7), Vector2(24, 24), pos, 10)
	clone.name = "ShadowClone"

	# 分身吸引敌人: 在附近创建一个碰撞体让敌人追踪
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new(); circle.radius = explode_radius
	shape.shape = circle
	area.add_child(shape)
	area.collision_layer = 16; area.collision_mask = 0
	clone.add_child(area)
	if clone.get_parent():
		clone.reparent(effect_parent)
	else:
		effect_parent.add_child(clone)

	# 定时爆炸
	var t := create_tween()
	t.tween_interval(clone_duration)
	t.tween_callback(func():
		_explode(pos)
		clone.queue_free()
	)

func _explode(pos: Vector2) -> void:
	# 伤害周围敌人
	if attack_area == null: return
	for body in attack_area.get_overlapping_bodies():
		if body.is_in_group("enemy") and body.has_method("take_damage") and not body.is_dead:
			var dist := pos.distance_to(body.global_position)
			if dist < explode_radius: body.take_damage(explode_damage)

	# VFX
	var ring := _create_effect_rect(Color(0.6, 0.2, 0.8, 0.5), Vector2(explode_radius*2, explode_radius*2), pos, 15)
	ring.scale = Vector2(0.3, 0.3)
	var t2 := create_tween().set_parallel(true)
	t2.tween_property(ring, "scale", Vector2(1.0, 1.0), 0.2)
	t2.tween_property(ring, "modulate:a", 0.0, 0.25)
	t2.chain().tween_callback(ring.queue_free)

func apply_level_up(power: int = 1) -> void:
	explode_damage += power * 6
	clone_duration += 0.5
	cooldown = maxf(cooldown * 0.9, 3.0)
