class_name SkillM1_RollCharge
extends SkillBase

## M1-C: 前滚翻冲撞 — 方向锁定突进
## 0.5s 方向锁定 → 冲刺 200px 速度 400px/s → 撞墙额外硬直

var _locked_direction: Vector2 = Vector2.ZERO
var _direction_locked: bool = false

func _init() -> void:
	skill_id = "m1_roll_charge"
	skill_name = "前滚翻冲撞"
	attack_category = "dash"
	_windup_duration = 0.8
	_recovery_duration = 0.5
	damage = 30
	cooldown = 3.0

func execute() -> void:
	if not owner_unit or not effect_parent:
		return

	var player := _find_player()
	if not player:
		return

	# 0.5s 时锁定方向（简化为 execute 开始时锁定）
	_locked_direction = owner_unit.global_position.direction_to(player.global_position)
	_direction_locked = true

	# 视觉：蹲下 scale.y → 0.5
	var sprite := _find_sprite()
	var orig_scale: Vector2 = sprite.scale if sprite else Vector2.ONE
	if sprite:
		var squash_tween: Tween = create_tween()
		squash_tween.tween_property(sprite, "scale", Vector2(orig_scale.x * 1.2, orig_scale.y * 0.5), 0.15)

	# 冲刺
	var dash_dist: float = 200.0
	var dash_speed: float = 400.0
	var dash_time: float = dash_dist / dash_speed
	var traveled: float = 0.0
	var start_pos: Vector2 = owner_unit.global_position
	var hit_player: bool = false

	while traveled < dash_dist and is_instance_valid(owner_unit) and not owner_unit.is_dead:
		await get_tree().process_frame
		var dt: float = get_process_delta_time()
		var step: float = dash_speed * dt
		traveled += step

		owner_unit.global_position += _locked_direction * step

		# 碰撞检测（玩家）
		if player and is_instance_valid(player):
			if owner_unit.global_position.distance_to(player.global_position) < 30.0:
				_deal_damage(player, damage)
				CombatFeedback.screen_shake(4.0)
				CombatFeedback.hit_particles(player.global_position, 6, Color(1.0, 0.6, 0.1))
				hit_player = true
				# 击退
				if player.has_method("knockback"):
					player.knockback(_locked_direction * 120.0)
				break

	# 恢复 scale
	if sprite:
		var restore: Tween = create_tween()
		restore.tween_property(sprite, "scale", orig_scale, 0.1)

	_direction_locked = false
	_locked_direction = Vector2.ZERO

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
	var sprite: ColorRect = owner_unit.get_node_or_null("Sprite") as ColorRect
	return sprite

func _deal_damage(target: Node2D, amount: int) -> void:
	if target.has_method("take_damage"):
		target.take_damage(amount, owner_unit as CombatUnit)
