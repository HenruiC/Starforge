class_name SkillIceNova
extends SkillBase

# 冰霜新星 — 冻结范围内敌人2秒

@export var freeze_duration: float = 2.0
@export var nova_radius: float = 100.0

func execute() -> void:
	if attack_area == null: return
	var bodies := attack_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("enemy") and body.has_method("take_damage") and not body.is_dead:
			body.take_damage(damage)
			# 冻结: 移速降为0
			if "move_speed" in body:
				var orig: float = body.move_speed
				body.set("move_speed", 0.0)
				body.modulate = Color.CYAN
				var t := create_tween()
				t.tween_interval(freeze_duration)
				t.tween_callback(func():
					if is_instance_valid(body): body.set("move_speed", orig); body.modulate = Color.WHITE
				)

	# VFX: 冰蓝扩散环
	var ring := _create_effect_rect(Color(0.3, 0.7, 1.0, 0.5), Vector2(nova_radius*2, nova_radius*2), player.global_position, 11)
	ring.scale = Vector2(0.2, 0.2)
	var t := create_tween().set_parallel(true)
	t.tween_property(ring, "scale", Vector2(1.2, 1.2), 0.2)
	t.tween_property(ring, "modulate:a", 0.0, 0.25)
	t.chain().tween_callback(ring.queue_free)

func apply_level_up(power: int = 1) -> void:
	damage += power * 3; freeze_duration += 0.5
	cooldown = maxf(cooldown * 0.92, 1.5)
