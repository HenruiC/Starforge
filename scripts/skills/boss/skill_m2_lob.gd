class_name SkillM2_Lob
extends SkillBase

## M2-B: 抛投高吊 — 抛物线弹道
## 水平速度 200px/s，顶点高度 80px，伤害 25，落地留 0.5s 光斑

func _init() -> void:
	skill_id = "m2_lob"
	skill_name = "抛投高吊"
	attack_category = "ranged_single"
	_windup_duration = 0.5
	_recovery_duration = 0.3
	damage = 25
	cooldown = 2.5

func execute() -> void:
	if not owner_unit or not effect_parent:
		return

	var player := _find_player()
	if not player:
		return

	var target_pos: Vector2 = player.global_position
	var start_pos: Vector2 = owner_unit.global_position
	var dir: Vector2 = (target_pos - start_pos).normalized()
	var distance: float = start_pos.distance_to(target_pos)
	var arc_height: float = 80.0
	var speed: float = 200.0
	var travel_time: float = distance / speed if speed > 0 else 1.0

	# 器材方块
	var proj := ColorRect.new()
	proj.color = Color(1.0, 0.8, 0.2, 1.0)
	proj.size = Vector2(10, 10)
	proj.global_position = start_pos
	proj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	proj.z_index = 10
	effect_parent.add_child(proj)

	# 抛物线运动
	var elapsed: float = 0.0
	var progress: float = 0.0
	while progress < 1.0 and is_instance_valid(proj) and is_instance_valid(owner_unit):
		await get_tree().process_frame
		var dt: float = get_process_delta_time()
		elapsed += dt
		progress = clampf(elapsed / travel_time, 0.0, 1.0)

		if not is_instance_valid(proj):
			return

		# 水平位置：线性插值
		var pos: Vector2 = start_pos.lerp(target_pos, progress)
		# 垂直偏移：抛物线弧
		var arc_offset: float = sin(progress * PI) * arc_height
		pos.y -= arc_offset
		proj.global_position = pos

	# 落地
	if not is_instance_valid(proj):
		return

	# AOE 检测
	if player and is_instance_valid(player):
		if player.global_position.distance_to(target_pos) < 40.0:
			_deal_damage(player, damage)

	# 落地光斑
	CombatFeedback.hit_particles(target_pos, 6, Color(1.0, 0.8, 0.2))
	var spot := ColorRect.new()
	spot.color = Color(1.0, 0.8, 0.2, 0.3)
	spot.size = Vector2(30, 30)
	spot.global_position = target_pos - Vector2(15, 15)
	spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spot.z_index = 8
	effect_parent.add_child(spot)
	var spot_tween: Tween = create_tween()
	spot_tween.tween_property(spot, "color:a", 0.0, 0.5)
	spot_tween.tween_callback(spot.queue_free)

	proj.queue_free()

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
