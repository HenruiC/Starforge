class_name SkillSlash
extends SkillBase

# 近战自动斩击 — 锁定最近敌人并打出弧形斩击线

var _target: Node2D = null

func can_execute() -> bool:
	if player == null: return false
	_find_target()
	return _target != null

func execute() -> void:
	if _target == null or not is_instance_valid(_target): return
	if _target.has_method("take_damage") and not _target.is_dead:
		_target.take_damage(damage)
	_spawn_slash_vfx()

func _find_target() -> void:
	if attack_area == null: return
	var bodies := attack_area.get_overlapping_bodies()
	_target = null; var min_d: float = INF
	for b in bodies:
		if b.is_in_group("enemy") and not b.is_dead:
			var d := player.global_position.distance_squared_to(b.global_position)
			if d < min_d: min_d = d; _target = b

func _spawn_slash_vfx() -> void:
	if _target == null or not is_instance_valid(_target): return
	var to_target := _target.global_position - player.global_position
	var mid := player.global_position + to_target * 0.5
	var angle := to_target.angle(); var dist := to_target.length()

	var colors := [Color(1.0, 0.95, 0.6), Color(1.0, 0.7, 0.2), Color(1.0, 0.5, 0.1)]
	var offs := [0.0, -8.0, 8.0]
	for i in 3:
		var slash := _create_effect_rect(colors[i], Vector2(30, 4), mid, 12)
		slash.rotation = angle + [0.0, -0.2, 0.2][i]
		slash.scale = Vector2(0.2, 0.8)
		slash.position = mid + Vector2(0, offs[i]).rotated(angle) - Vector2(15, 2)
		var t := create_tween().set_parallel(true)
		t.tween_property(slash, "scale", Vector2(dist / 10.0, 0.6), 0.15)
		t.tween_property(slash, "modulate:a", 0.0, 0.15)
		t.chain().tween_callback(slash.queue_free)
