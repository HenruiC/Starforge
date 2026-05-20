class_name SkillM2_WhistleShriek
extends SkillBase

## M2-C: 哨声尖啸 — 扇形 5 发子弹，碰墙反弹一次
## 速度 250px/s，伤害 15/发，反弹后速度减半、伤害减半 (8)

var _reflection_count: int = 0

func _init() -> void:
	skill_id = "m2_whistle_shriek"
	skill_name = "哨声尖啸"
	attack_category = "ranged_barrage"
	_windup_duration = 0.5
	_recovery_duration = 0.4
	damage = 15
	cooldown = 2.5

func execute() -> void:
	if not owner_unit or not effect_parent:
		return

	var dir: Vector2 = owner_unit.aim_direction if owner_unit.aim_direction != Vector2.ZERO else Vector2.RIGHT

	# 120 度扇形，5 发
	var angles: Array[float] = [
		-deg_to_rad(60.0), -deg_to_rad(30.0), 0.0, deg_to_rad(30.0), deg_to_rad(60.0)
	]
	for angle_offset in angles:
		var bullet_dir: Vector2 = dir.rotated(angle_offset)
		_spawn_projectile(bullet_dir)

func _spawn_projectile(dir: Vector2) -> void:
	var proj := ColorRect.new()
	proj.color = Color(1.0, 0.6, 0.0, 0.9)  # 橙色
	proj.size = Vector2(6, 6)
	proj.global_position = owner_unit.global_position
	proj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	proj.z_index = 10
	effect_parent.add_child(proj)

	var speed: float = 250.0
	var current_damage: int = damage
	var lifetime: float = 2.0
	var elapsed: float = 0.0
	var has_reflected: bool = false

	while elapsed < lifetime and is_instance_valid(proj):
		await get_tree().process_frame
		var dt: float = get_process_delta_time()
		elapsed += dt
		if not is_instance_valid(proj):
			return

		proj.global_position += dir * speed * dt

		# 玩家碰撞检测
		var player := _find_player()
		if player and is_instance_valid(player):
			if proj.global_position.distance_to(player.global_position) < 15.0:
				_deal_damage(player, current_damage)
				CombatFeedback.hit_particles(proj.global_position, 3, Color(1.0, 0.6, 0.0))
				proj.queue_free()
				return

		# 墙壁碰撞（简易边界反弹）
		var cam := get_viewport().get_camera_2d()
		if cam:
			var viewport_size := get_viewport().get_visible_rect().size
			var cam_pos: Vector2 = cam.global_position
			var margin: float = 200.0
			var hit_wall: bool = false

			if proj.global_position.x < cam_pos.x - viewport_size.x * 0.5 - margin:
				dir.x = abs(dir.x)
				hit_wall = true
			elif proj.global_position.x > cam_pos.x + viewport_size.x * 0.5 + margin:
				dir.x = -abs(dir.x)
				hit_wall = true
			if proj.global_position.y < cam_pos.y - viewport_size.y * 0.5 - margin:
				dir.y = abs(dir.y)
				hit_wall = true
			elif proj.global_position.y > cam_pos.y + viewport_size.y * 0.5 + margin:
				dir.y = -abs(dir.y)
				hit_wall = true

			if hit_wall and not has_reflected:
				has_reflected = true
				speed *= 0.5  # 速度减半
				current_damage = maxi(8, current_damage / 2)  # 伤害减半
				proj.color = Color(0.6, 0.4, 0.0, 0.6)  # 变暗表示已反弹

	if is_instance_valid(proj):
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
