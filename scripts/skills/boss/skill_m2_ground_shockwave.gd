class_name SkillM2_GroundShockwave
extends SkillBase

## M2-E: 震地波 — 三连同心冲击波
## 3 道波，半径 50/100/180px，到达时间 0.3/0.6/0.9s，每波伤害 15
## 玩家可用闪避无敌帧躲避

var _wave_data: Array[Dictionary] = [
	{"radius": 50.0, "time": 0.3, "damage": 15},
	{"radius": 100.0, "time": 0.6, "damage": 15},
	{"radius": 180.0, "time": 0.9, "damage": 15},
]

func _init() -> void:
	skill_id = "m2_ground_shockwave"
	skill_name = "震地波"
	attack_category = "aoe_ground"
	_windup_duration = 1.2
	_recovery_duration = 1.0
	damage = 15
	cooldown = 5.0

func execute() -> void:
	if not owner_unit or not effect_parent:
		return

	var center: Vector2 = owner_unit.global_position

	# 震地瞬间
	CombatFeedback.screen_shake(8.0)

	var player := _find_player()

	# 依次发出 3 道波
	var cumulative_delay: float = 0.0
	for wave in _wave_data:
		var radius: float = wave["radius"] as float
		var arrival_time: float = wave["time"] as float
		var wave_damage: int = wave["damage"] as int

		# 创建环形波视觉
		var ring := ColorRect.new()
		ring.color = Color(1.0, 0.2, 0.05, 0.4)
		ring.size = Vector2(radius * 2.0, radius * 2.0)
		ring.global_position = center - Vector2(radius, radius)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.z_index = 9
		effect_parent.add_child(ring)

		# 扩散动画
		var ring_tween: Tween = create_tween()
		ring_tween.tween_property(ring, "color:a", 0.0, arrival_time)
		ring_tween.parallel().tween_property(ring, "scale", Vector2(1.5, 1.5), arrival_time)
		ring_tween.tween_callback(ring.queue_free)

		# 等波到达边缘
		cumulative_delay += 0.3  # 每波间隔 0.3s
		await get_tree().create_timer(0.3).timeout

		if owner_unit and owner_unit.is_dead:
			return

		# 检测玩家
		if player and is_instance_valid(player):
			var dist: float = player.global_position.distance_to(center)
			# 每波在到达边缘时检测（波从中心扩散到 radius）
			if dist < radius * 1.1:  # 容忍 10% 误差
				_deal_damage(player, wave_damage)
				CombatFeedback.hit_particles(player.global_position, 4, Color(1.0, 0.4, 0.05))
				CombatFeedback.screen_shake(3.0)

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
