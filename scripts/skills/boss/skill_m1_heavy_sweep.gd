class_name SkillM1_HeavySweep
extends SkillBase

## M1-A: 示范重击 — 近战扇形攻击
## Boss 双臂后摆 → 120 度扇形，半径 120px，伤害 30

func _init() -> void:
	skill_id = "m1_heavy_sweep"
	skill_name = "示范重击"
	attack_category = "melee_heavy"
	_windup_duration = 0.6
	_recovery_duration = 0.5
	damage = 30
	cooldown = 2.0

func execute() -> void:
	if not owner_unit or not effect_parent:
		return

	# 视觉：光环扩张
	_show_sweep_visual()

	# 检测扇形范围内的玩家
	var player: Node2D = _find_player()
	if not player:
		return

	var dir: Vector2 = owner_unit.aim_direction if owner_unit.aim_direction != Vector2.ZERO else Vector2.RIGHT
	var to_player: Vector2 = player.global_position - owner_unit.global_position
	var dist: float = to_player.length()
	if dist > 120.0:
		return

	var angle_diff: float = abs(dir.angle_to(to_player))
	if angle_diff > deg_to_rad(60.0):  # 120 度扇形 = ±60 度
		return

	# 造成伤害
	_deal_damage(player, damage)

	# 击退
	if player.has_method("knockback"):
		var kb_dir: Vector2 = to_player.normalized()
		player.knockback(kb_dir * 150.0)

	# 战斗反馈
	CombatFeedback.hit_particles(player.global_position, 6, Color(1.0, 0.6, 0.1))
	CombatFeedback.screen_shake(4.0)

func _show_sweep_visual() -> void:
	# 光环扩张视觉（扇形闪光）
	var arc := ColorRect.new()
	arc.color = Color(1.0, 0.6, 0.0, 0.3)
	arc.size = Vector2(240, 120)
	arc.position = owner_unit.global_position - Vector2(120, 60)
	arc.rotation = owner_unit.aim_direction.angle()
	arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arc.z_index = 10
	effect_parent.add_child(arc)

	var t: Tween = create_tween()
	t.tween_property(arc, "color:a", 0.0, 0.2)
	t.parallel().tween_property(arc, "scale", Vector2(0.8, 0.8), 0.2)
	t.tween_callback(arc.queue_free)

func _find_player() -> Node2D:
	var tree := get_tree()
	if not tree:
		return null
	var players := tree.get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null

func _deal_damage(target: Node2D, amount: int) -> void:
	if target.has_method("take_damage"):
		target.take_damage(amount, owner_unit as CombatUnit)
	elif target.has_method("get_current_health"):
		# 兼容 CombatUnit
		var unit := target as CombatUnit
		if unit:
			unit.take_damage(amount, owner_unit as CombatUnit)
