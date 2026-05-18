class_name SkillSlash
extends SkillBase

# 近战自动斩击 — 锁定最近敌人并打出弧形斩击线

var _target: CharacterBody2D = null

func can_execute() -> bool:
	return player != null  # 鼠标方向攻击, 总是可用

func execute() -> void:
	if player == null: return
	var aim_dir: Vector2 = player.get("_aim_direction") if "_aim_direction" in player else Vector2.RIGHT
	# 在攻击方向上查找敌人
	var hit_enemy: Node2D = null
	var min_dist: float = INF
	if attack_area != null:
		for body in attack_area.get_overlapping_bodies():
			if body.is_in_group("enemy") and not body.is_dead:
				var to_body := body.global_position - player.global_position
				# 检查是否在攻击方向±45度内
				if aim_dir.dot(to_body.normalized()) > 0.7:
					var d := to_body.length_squared()
					if d < min_dist: min_dist = d; hit_enemy = body

	if hit_enemy and hit_enemy.has_method("take_damage"):
		hit_enemy.take_damage(damage)
		_spawn_slash_vfx_dir(aim_dir, hit_enemy.global_position)
		if player.global_position.distance_to(hit_enemy.global_position) < 50:
			CombatFeedback.big_hit_stop()
		else:
			CombatFeedback.hit_stop()
	else:
		# 空挥也有特效
		_spawn_slash_vfx_dir(aim_dir, player.global_position + aim_dir * 80)

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

func _spawn_slash_vfx_dir(dir: Vector2, hit_pos: Vector2) -> void:
	# 特效从玩家延伸到命中点(或120距离的无命中位置)
	var dist := player.global_position.distance_to(hit_pos)
	if dist > 180: dist = 120.0
	var mid := player.global_position + dir * (dist * 0.5)
	var angle := dir.angle()

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
