class_name SkillM2_IronShoulder
extends SkillBase

## M2-D: 铁山靠 — 侧向横靠突进
## 方向 0.4s 锁定，侧向 180px，速度 350px/s，伤害 40 + 击退 100px

var _locked_direction: Vector2 = Vector2.ZERO
var _direction_locked: bool = false

func _init() -> void:
	skill_id = "m2_iron_shoulder"
	skill_name = "铁山靠"
	attack_category = "dash"
	_windup_duration = 0.6
	_recovery_duration = 0.6
	damage = 40
	cooldown = 3.5

func execute() -> void:
	if not owner_unit or not effect_parent:
		return

	var player := _find_player()
	if not player:
		return

	# 锁定方向：朝向玩家旋转 90 度（侧向横靠）
	var to_player: Vector2 = player.global_position - owner_unit.global_position
	_locked_direction = to_player.normalized().rotated(PI / 2.0)  # 侧向
	# 随机选择左或右侧
	if randf() < 0.5:
		_locked_direction = -_locked_direction
	_direction_locked = true

	# 视觉：体色金属化闪灰
	var sprite := _find_sprite()
	if sprite:
		var flash: Tween = create_tween()
		flash.tween_property(sprite, "modulate", Color(0.7, 0.7, 0.7, 1.0), 0.1)
		flash.tween_property(sprite, "modulate", Color.WHITE, 0.1)

	# 冲刺
	var dash_dist: float = 180.0
	var dash_speed: float = 350.0
	var traveled: float = 0.0
	var hit_player: bool = false

	while traveled < dash_dist and is_instance_valid(owner_unit) and not owner_unit.is_dead:
		await get_tree().process_frame
		var dt: float = get_process_delta_time()
		var step: float = dash_speed * dt
		traveled += step
		owner_unit.global_position += _locked_direction * step

		# 碰撞检测
		if player and is_instance_valid(player):
			if owner_unit.global_position.distance_to(player.global_position) < 30.0:
				_deal_damage(player, damage)
				CombatFeedback.screen_shake(6.0)
				CombatFeedback.hit_particles(player.global_position, 8, Color(1.0, 0.5, 0.05))
				if player.has_method("knockback"):
					player.knockback(_locked_direction * 100.0)
				hit_player = true
				break

	_direction_locked = false

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
