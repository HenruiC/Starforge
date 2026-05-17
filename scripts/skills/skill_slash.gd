class_name SkillSlash
extends SkillBase

# 近战自动斩击 — 锁定最近敌人并打出弧形斩击线

var _target: CharacterBody2D = null

func can_execute() -> bool:
	if player == null: return false
	_find_target()
	return _target != null

func execute() -> void:
	if _target == null or not is_instance_valid(_target): return

	# 安全检查：确保目标还活着且可以受伤
	var dead: bool = _target.get("is_dead") if _target.get("is_dead") != null else false
	if dead: return
	if not _target.has_method("take_damage"): return

	_target.take_damage(damage)
	_spawn_slash_vfx()

	var dist: float = player.global_position.distance_to(_target.global_position)
	if dist < 50:  # 近距离斩击额外顿帧
		CombatFeedback.big_hit_stop()
	else:
		CombatFeedback.hit_stop()

func _find_target() -> void:
	if attack_area == null: return
	var bodies := attack_area.get_overlapping_bodies()
	_target = null; var min_d: float = INF
	for b in bodies:
		if b is CharacterBody2D and b.is_in_group("enemy"):
			var dead: bool = b.get("is_dead") if b.get("is_dead") != null else false
			if dead: continue
			var d := player.global_position.distance_squared_to(b.global_position)
			if d < min_d: min_d = d; _target = b

func _spawn_slash_vfx() -> void:
	if _target == null or not is_instance_valid(_target): return
	var to_target := _target.global_position - player.global_position
	var mid := player.global_position + to_target * 0.5
	var angle := to_target.angle(); var dist := to_target.length()

	var colors := [Color(1.0, 0.95, 0.6), Color(1.0, 0.7, 0.2), Color(1.0, 0.5, 0.1)]
	var offs := [0.0, -10.0, 10.0]
	for i in 3:
		var slash := _create_effect_rect(colors[i], Vector2(36, 5), mid, 12)
		slash.rotation = angle + [0.0, -0.25, 0.25][i]
		slash.scale = Vector2(0.3, 1.0)
		slash.position = mid + Vector2(0, offs[i]).rotated(angle) - Vector2(18, 2)
		var t := create_tween().set_parallel(true)
		var s: float = maxf(dist / 8.0, 1.0)
		t.tween_property(slash, "scale", Vector2(s, 0.5), 0.12)
		t.tween_property(slash, "modulate:a", 0.0, 0.12)
		t.chain().tween_callback(slash.queue_free)

	# 目标身上命中闪光
	if _target and is_instance_valid(_target):
		var flash := _create_effect_rect(Color.WHITE, Vector2(30, 30), _target.global_position, 15)
		var ft := create_tween().set_parallel(true)
		ft.tween_property(flash, "scale", Vector2(1.8, 1.8), 0.08)
		ft.tween_property(flash, "modulate:a", 0.0, 0.1)
		ft.chain().tween_callback(flash.queue_free)

	# 残影 — 小岛要求：斩击线消失后留0.1秒白色轨迹
	_spawn_afterimages(mid, angle, dist, colors, offs)

func _spawn_afterimages(mid: Vector2, angle: float, dist: float, colors: Array, offs: Array) -> void:
	# 等待0.12秒（斩击线消失后）再生成残影
	var t := create_tween()
	t.tween_interval(0.1)
	t.tween_callback(func():
		if effect_parent == null: return
		for i in 3:
			var ghost := _create_effect_rect(Color.WHITE, Vector2(20, 3), mid, 8)
			ghost.rotation = angle + [0.0, -0.25, 0.25][i]
			ghost.scale = Vector2(maxf(dist / 8.0, 1.0) * 0.6, 0.3)
			ghost.modulate.a = 0.3
			var gt := create_tween()
			gt.tween_property(ghost, "modulate:a", 0.0, 0.15)
			gt.tween_callback(ghost.queue_free)
	)
