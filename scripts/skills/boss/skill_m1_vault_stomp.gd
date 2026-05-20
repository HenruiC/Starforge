class_name SkillM1_VaultStomp
extends SkillBase

## M1-D: 跳马践踏 — AOE 圆形区域
## 前 0.5s 标记跟随玩家，后 0.5s 锁定 → 半径 60px 圆形，伤害 20 + 1s 击晕

var _locked_position: Vector2 = Vector2.ZERO

func _init() -> void:
	skill_id = "m1_vault_stomp"
	skill_name = "跳马践踏"
	attack_category = "aoe_ground"
	_windup_duration = 1.0
	_recovery_duration = 0.8
	damage = 20
	cooldown = 4.0

func execute() -> void:
	if not owner_unit or not effect_parent:
		return

	var player := _find_player()
	if not player:
		return

	# 锁定玩家位置
	_locked_position = player.global_position

	# 地面标记（红色圆圈，从淡红到深红渐变）
	var marker := ColorRect.new()
	marker.color = Color(1.0, 0.2, 0.05, 0.3)
	marker.size = Vector2(120, 120)
	marker.global_position = _locked_position - Vector2(60, 60)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.z_index = 8
	effect_parent.add_child(marker)

	# 标记渐变（浅红 → 深红）
	var marker_tween: Tween = create_tween()
	marker_tween.tween_property(marker, "color", Color(1.0, 0.05, 0.0, 0.6), 0.4)

	# 0.5s 后践踏
	await get_tree().create_timer(0.5).timeout

	if not is_instance_valid(marker):
		return

	# 践踏效果：粒子爆发 + 范围伤害
	CombatFeedback.hit_particles(_locked_position, 10, Color(1.0, 0.4, 0.05))
	CombatFeedback.screen_shake(6.0)

	# 燃烧标记
	marker.color = Color(1.0, 0.8, 0.2, 0.5)
	var burn_tween: Tween = create_tween()
	burn_tween.tween_property(marker, "color:a", 0.0, 0.4)
	burn_tween.tween_callback(marker.queue_free)

	# 检测范围内的玩家
	if player and is_instance_valid(player):
		var dist: float = player.global_position.distance_to(_locked_position)
		if dist < 60.0:
			_deal_damage(player, damage)
			# 1s 击晕
			if player.has_method("set_stunned"):
				player.set_stunned(true)
				get_tree().create_timer(1.0).timeout.connect(
					func(): player.set_stunned(false), CONNECT_ONE_SHOT
				)
			# 击退
			if player.has_method("knockback"):
				var kb_dir: Vector2 = (player.global_position - _locked_position).normalized()
				player.knockback(kb_dir * 100.0)

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
