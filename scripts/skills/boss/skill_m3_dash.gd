class_name SkillM3_Dash
extends SkillBase

## M3-D: 冲刺追击 — 方向锁定突进
## 0.5s 前摇 → 方向锁定 → 冲刺 160px 速度 380px/s → 伤害 25

var _locked_direction: Vector2 = Vector2.ZERO

func _init() -> void:
	skill_id = "m3_dash"
	skill_name = "冲刺追击"
	attack_category = "dash"
	_windup_duration = 0.5
	_recovery_duration = 0.5
	damage = 25
	cooldown = 2.5

func execute() -> void:
	if not owner_unit or not effect_parent:
		return

	var player := _find_player()
	if not player:
		return

	# 锁定方向
	_locked_direction = owner_unit.global_position.direction_to(player.global_position)

	# 视觉：体色短暂发亮
	var sprite := _find_sprite()
	if sprite:
		var flash: Tween = create_tween()
		flash.tween_property(sprite, "modulate", Color(1.2, 1.2, 1.0, 1.0), 0.1)
		flash.tween_property(sprite, "modulate", Color.WHITE, 0.1)

	# 冲刺
	var dash_dist: float = 160.0
	var dash_speed: float = 380.0
	var traveled: float = 0.0
	var hit_player: bool = false

	while traveled < dash_dist and is_instance_valid(owner_unit) and not owner_unit.is_dead:
		await get_tree().process_frame
		var dt: float = get_process_delta_time()
		var step: float = dash_speed * dt
		traveled += step
		owner_unit.global_position += _locked_direction * step

		if player and is_instance_valid(player):
			if owner_unit.global_position.distance_to(player.global_position) < 25.0:
				_deal_damage(player, damage)
				CombatFeedback.hit_particles(player.global_position, 5, Color(1.0, 0.8, 0.2))
				if player.has_method("knockback"):
					player.knockback(_locked_direction * 80.0)
				hit_player = true
				break

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
