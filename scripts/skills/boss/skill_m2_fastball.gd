class_name SkillM2_Fastball
extends SkillBase

## M2-A: 抛投直球 — 直线弹道
## 速度 350px/s，伤害 20，用于打断站桩

func _init() -> void:
	skill_id = "m2_fastball"
	skill_name = "抛投直球"
	attack_category = "ranged_single"
	_windup_duration = 0.4
	_recovery_duration = 0.3
	damage = 20
	cooldown = 2.0

func execute() -> void:
	if not owner_unit or not effect_parent:
		return

	var player := _find_player()
	if not player:
		return

	var dir: Vector2 = owner_unit.global_position.direction_to(player.global_position)

	# 视觉：右臂后摆 → 前甩（由视觉层处理）
	# 发射亮黄色器材方块
	var proj := ColorRect.new()
	proj.color = Color(1.0, 0.9, 0.1, 1.0)  # 亮黄色
	proj.size = Vector2(10, 10)
	proj.global_position = owner_unit.global_position
	proj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	proj.z_index = 10
	effect_parent.add_child(proj)

	# 拖尾效果
	var speed: float = 350.0
	var lifetime: float = 1.5
	var elapsed: float = 0.0

	while elapsed < lifetime and is_instance_valid(proj) and is_instance_valid(owner_unit):
		await get_tree().process_frame
		var dt: float = get_process_delta_time()
		elapsed += dt
		if not is_instance_valid(proj):
			return
		proj.global_position += dir * speed * dt

		# 碰撞检测
		if player and is_instance_valid(player):
			if proj.global_position.distance_to(player.global_position) < 18.0:
				_deal_damage(player, damage)
				CombatFeedback.hit_particles(proj.global_position, 5, Color(1.0, 0.9, 0.1))
				proj.queue_free()
				return

		# 出界
		if _is_out_of_bounds(proj.global_position):
			proj.queue_free()
			return

	if is_instance_valid(proj):
		proj.queue_free()

func _is_out_of_bounds(pos: Vector2) -> bool:
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return false
	var viewport_size := get_viewport().get_visible_rect().size
	return abs(pos.x - cam.global_position.x) > viewport_size.x * 1.2 \
		or abs(pos.y - cam.global_position.y) > viewport_size.y * 1.2

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
