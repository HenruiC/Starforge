class_name SkillM4_EquipmentRain
extends SkillBase

## M4-B: 全屏体育器材雨 — 5 波器材从屏幕顶部落下
## 每波 3-5 个，随机 x 位置，落地前 0.5s 红色方形投影预警
## 落地半径 40px AOE，伤害 25/个
## CD 12s，释放后 2s 硬直 + 核心暴露

const WAVE_COUNT: int = 5
const ITEMS_PER_WAVE_MIN: int = 3
const ITEMS_PER_WAVE_MAX: int = 5
const AOE_RADIUS: float = 40.0
const ITEM_FALL_SPEED: float = 300.0
const WARNING_DURATION: float = 0.5
const WAVE_INTERVAL: float = 0.6

func _init() -> void:
	skill_id = "m4_equipment_rain"
	skill_name = "全屏体育器材雨"
	attack_category = "ultimate"
	_windup_duration = 1.5
	_recovery_duration = 2.0
	damage = 25
	cooldown = 12.0

func execute() -> void:
	if not owner_unit or not effect_parent:
		return

	# 前摇结束，Boss 短暂跳至场地中央（由视觉层处理）
	# 天空变暗（由视觉层处理）

	var player := _find_player()
	if not player:
		return

	# 获取可落地区域（以玩家为中心的场地范围）
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var cam_pos: Vector2 = cam.global_position
	var field_left: float = cam_pos.x - viewport_size.x * 0.4
	var field_right: float = cam_pos.x + viewport_size.x * 0.4
	var field_top: float = cam_pos.y - viewport_size.y * 0.5
	var fall_start_y: float = field_top - 50.0  # 从屏幕上方掉落

	for wave_idx in range(WAVE_COUNT):
		if owner_unit and owner_unit.is_dead:
			return

		var item_count: int = randi_range(ITEMS_PER_WAVE_MIN, ITEMS_PER_WAVE_MAX)

		for i in range(item_count):
			var target_x: float = randf_range(field_left, field_right)
			var target_y: float = randf_range(cam_pos.y - viewport_size.y * 0.3, cam_pos.y + viewport_size.y * 0.3)

			# 红色方形投影（预警）
			var warning := ColorRect.new()
			warning.color = Color(1.0, 0.1, 0.05, 0.25)
			warning.size = Vector2(AOE_RADIUS * 2.0, AOE_RADIUS * 2.0)
			warning.global_position = Vector2(target_x - AOE_RADIUS, target_y - AOE_RADIUS)
			warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
			warning.z_index = 8
			effect_parent.add_child(warning)

			# 预警闪烁
			var warn_tween: Tween = create_tween()
			warn_tween.tween_property(warning, "color:a", 0.5, WARNING_DURATION * 0.5)
			warn_tween.tween_property(warning, "color:a", 0.2, WARNING_DURATION * 0.5)

			# 器材本体（从屏幕上方落下）
			var item := ColorRect.new()
			item.color = Color(1.0, 0.85, 0.1, 1.0)  # 亮黄色器材
			item.size = Vector2(10, 10)
			item.global_position = Vector2(target_x, fall_start_y)
			item.mouse_filter = Control.MOUSE_FILTER_IGNORE
			item.z_index = 12
			effect_parent.add_child(item)

			# 落下动画
			var distance: float = abs(target_y - fall_start_y)
			var fall_time: float = distance / ITEM_FALL_SPEED

			# 预警结束后落地
			await get_tree().create_timer(WARNING_DURATION).timeout

			# 移出预警
			if is_instance_valid(warning):
				warning.queue_free()

			if not is_instance_valid(item):
				continue

			# 快速落下
			var item_tween: Tween = create_tween()
			item_tween.tween_property(item, "global_position:y", target_y, fall_time).set_ease(Tween.EASE_IN)

			await item_tween.finished

			if not is_instance_valid(item):
				continue

			# 落地：AOE 检测
			if player and is_instance_valid(player):
				if player.global_position.distance_to(Vector2(target_x, target_y)) < AOE_RADIUS:
					_deal_damage(player, damage)

			# 落地粒子
			CombatFeedback.hit_particles(Vector2(target_x, target_y), 4, Color(1.0, 0.85, 0.1))
			item.queue_free()

		# 波间隔
		if wave_idx < WAVE_COUNT - 1:
			await get_tree().create_timer(WAVE_INTERVAL).timeout

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

func _deal_damage(target: Node2D, amount: int) -> void:
	if target.has_method("take_damage"):
		target.take_damage(amount, owner_unit as CombatUnit)
