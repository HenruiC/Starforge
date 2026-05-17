class_name SkillAOE
extends SkillBase

@export var knockback: float = 200.0
@export var visual_radius: float = 50.0

func execute() -> void:
	if attack_area == null: return
	var bodies := attack_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("enemy") and body.has_method("take_damage") and not body.is_dead:
			body.take_damage(damage)
			if body.has_method("knockback"):
				var dir := body.global_position.direction_to(player.global_position)
				body.knockback(dir * knockback)

	_spawn_aoe_vfx()

func _spawn_aoe_vfx() -> void:
	var r := visual_radius
	var ring := _create_effect_rect(Color(1.0, 0.5, 0.08, 0.55), Vector2(r * 2, r * 2), player.global_position, 11)
	ring.scale = Vector2(0.2, 0.2)
	var t := create_tween().set_parallel(true)
	t.tween_property(ring, "scale", Vector2(attack_range / visual_radius, attack_range / visual_radius), 0.25)
	t.tween_property(ring, "modulate:a", 0.0, 0.28)
	t.chain().tween_callback(ring.queue_free)

	var inner := _create_effect_rect(Color(1.0, 0.9, 0.6, 0.8), Vector2(30, 30), player.global_position, 12)
	var it := create_tween().set_parallel(true)
	it.tween_property(inner, "scale", Vector2(2.5, 2.5), 0.15)
	it.tween_property(inner, "modulate:a", 0.0, 0.18)
	it.chain().tween_callback(inner.queue_free)
