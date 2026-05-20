class_name SkillM4_DesperateDash
extends SkillBase

## M4-A: 绝望冲刺x4 — 连续 4 次冲刺
## 每次 0.4s 前摇 → 冲刺 150px → 0.2s 停顿 → 重新锁定
## 第 4 次后 1.0s 硬直 + 核心暴露
##
## 这是一个复合攻击，覆盖 try_execute() 实现完整序列。
## 前摇/硬直信号仅在第 1 次和第 4 次发出。

func _init() -> void:
	skill_id = "m4_desperate_dash"
	skill_name = "绝望冲刺x4"
	attack_category = "melee_heavy"
	_windup_duration = 0.4
	_recovery_duration = 1.0
	damage = 20
	cooldown = 3.0

# 重写 try_execute 实现 4 连冲刺
func try_execute() -> bool:
	if not is_ready:
		return false
	if not can_execute():
		return false
	if _is_windup or _is_recovery or _is_active_frame:
		return false

	is_ready = false
	cooldown_remaining = cooldown

	var dash_count: int = 4
	var dash_dist: float = 150.0
	var dash_speed: float = 400.0
	var pause_duration: float = 0.2

	# 第 1 次前摇
	_is_windup = true
	windup_started.emit(_windup_duration)
	await get_tree().create_timer(_windup_duration).timeout
	_is_windup = false
	windup_ended.emit()

	for i in range(dash_count):
		if not owner_unit or owner_unit.is_dead:
			return true

		var player := _find_player()
		if not player:
			continue

		# 锁定方向（每次重新锁定）
		var locked_dir: Vector2 = owner_unit.global_position.direction_to(player.global_position)

		# 身体闪烁
		var sprite := _find_sprite()
		if sprite:
			var flash: Tween = create_tween()
			flash.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 0.5), 0.05)
			flash.tween_property(sprite, "modulate", Color.WHITE, 0.05)

		# 冲刺
		var traveled: float = 0.0
		while traveled < dash_dist and is_instance_valid(owner_unit) and not owner_unit.is_dead:
			await get_tree().process_frame
			var dt: float = get_process_delta_time()
			var step: float = dash_speed * dt
			traveled += step
			owner_unit.global_position += locked_dir * step

			# 碰撞检测
			if player and is_instance_valid(player):
				if owner_unit.global_position.distance_to(player.global_position) < 25.0:
					_deal_damage(player, damage)
					CombatFeedback.hit_particles(player.global_position, 4, Color(1.0, 0.6, 0.1))
					# 击退
					if player.has_method("knockback"):
						player.knockback(locked_dir * 60.0)
					break

		# 停顿（除最后一次外）
		if i < dash_count - 1:
			await get_tree().create_timer(pause_duration).timeout

		# 最后一次后不需要 pause，直接 recovery

	# 第 4 次后：长硬直 1.0s + 核心暴露
	_is_recovery = true
	recovery_started.emit(_recovery_duration)

	# 视觉：Boss 体色变暗 + 核心暴露
	_final_pose()

	await get_tree().create_timer(_recovery_duration).timeout
	_is_recovery = false
	recovery_ended.emit()

	_trigger_feedback()
	return true

func _final_pose() -> void:
	var sprite := _find_sprite()
	if sprite:
		var t: Tween = create_tween()
		t.tween_property(sprite, "modulate", Color(0.4, 0.05, 0.02, 1.0), 0.2)

func can_execute() -> bool:
	if not owner_unit or owner_unit.is_dead:
		return false
	return true

func _find_player() -> Node2D:
	var tree := get_tree()
	if not tree:
		return null
	var players := tree.get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null

func _find_sprite() -> ColorRect:
	if not owner_unit:
		return null
	return owner_unit.get_node_or_null("Sprite") as ColorRect

func _deal_damage(target: Node2D, amount: int) -> void:
	if target.has_method("take_damage"):
		target.take_damage(amount, owner_unit as CombatUnit)
