class_name SkillM1_WhistleWave
extends SkillBase

## M1-B: 哨声音波 — Boss 核心弹幕技能，扇形扩散弹幕
##
## 数值随 BossPhaseData 动态调整：
##   - bullet_count      弹丸数量（P1=5, P2=7, P3=9, P4=11）
##   - bullet_speed      弹丸速度（P1=200, P2=250, P3=300, P4=350）
##   - bullet_spread_angle 扇形展开角（P1=90, P2=100, P3=110, P4=120）
##
## 预判弹幕：弹丸飞向玩家移动方向的前方（读取 player.velocity）
## 魂系感觉：0.6s 前摇（口哨脉冲）+ 0.5s 硬直窗口

func _init() -> void:
	skill_id = "m1_whistle_wave"
	skill_name = "哨声音波"
	attack_category = "ranged_barrage"
	_windup_duration = 0.6    # 宫崎标准：扇形弹幕前摇 ≥0.5s
	_recovery_duration = 0.5   # 玩家反击窗口
	damage = 18
	cooldown = 2.0

func execute() -> void:
	if not owner_unit or not effect_parent:
		return

	# ---- 读取当前阶段数值 ----
	var bullet_count: int = _get_phase_bullet_count()
	var bullet_speed: float = _get_phase_bullet_speed()
	var spread_angle: float = _get_phase_bullet_spread_angle()
	var phase_damage: int = _get_phase_damage()

	# ---- 预判瞄准：弹幕飞向玩家移动方向的前方 ----
	var base_dir: Vector2 = _get_predictive_direction()
	if base_dir == Vector2.ZERO:
		base_dir = owner_unit.aim_direction if owner_unit.aim_direction != Vector2.ZERO else Vector2.RIGHT

	# ---- 生成扇形弹幕 ----
	var half_spread: float = deg_to_rad(spread_angle / 2.0)
	var step: float = deg_to_rad(spread_angle) / float(bullet_count - 1) if bullet_count > 1 else 0.0

	for i in range(bullet_count):
		var angle_offset: float
		if bullet_count == 1:
			angle_offset = 0.0
		else:
			angle_offset = -half_spread + step * float(i)
		var bullet_dir: Vector2 = base_dir.rotated(angle_offset)
		_spawn_projectile(bullet_dir, bullet_speed, phase_damage)

	# ---- 发射后闪光：本体短暂亮白 ----
	_show_shoot_flash()

# --------------------------------------------------------------------------
# 预判瞄准：弹丸飞向玩家移动方向的前方
# --------------------------------------------------------------------------

func _get_predictive_direction() -> Vector2:
	var player := _find_player()
	if not player:
		return Vector2.ZERO

	var player_pos: Vector2 = player.global_position
	var player_vel: Vector2 = Vector2.ZERO

	# 读取玩家速度（CharacterBody2D.velocity）
	if player is CharacterBody2D:
		player_vel = player.velocity
	elif "velocity" in player:
		player_vel = player.velocity

	# 预测时间 = 到玩家的估计飞行时间（0.25s 基准 + 距离微调）
	var dist: float = owner_unit.global_position.distance_to(player_pos)
	var bullet_speed: float = _get_phase_bullet_speed()
	var travel_time: float = clampf(dist / maxf(bullet_speed, 1.0), 0.15, 0.5)
	var predicted_pos: Vector2 = player_pos + player_vel * travel_time

	return owner_unit.global_position.direction_to(predicted_pos)

# --------------------------------------------------------------------------
# 射击闪光 — 魂系可读性关键：攻击帧 Boss 亮白
# --------------------------------------------------------------------------

func _show_shoot_flash() -> void:
	if not owner_unit:
		return
	var sprite: ColorRect = owner_unit.get_node_or_null("Sprite") as ColorRect
	if not sprite:
		return
	var orig_color := sprite.color
	var flash: Tween = create_tween()
	flash.tween_property(sprite, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.06)
	flash.tween_property(sprite, "modulate", orig_color, 0.15)

# --------------------------------------------------------------------------
# 弹丸生成 — 独立移动 + 碰撞检测
# --------------------------------------------------------------------------

func _spawn_projectile(dir: Vector2, speed: float, dmg: int) -> void:
	var proj := ColorRect.new()
	proj.color = VFXUtils.C_SCARLET  # 杨奇绯红：Boss弹幕
	proj.size = Vector2(8, 8)
	proj.global_position = owner_unit.global_position
	proj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	proj.z_index = 10
	effect_parent.add_child(proj)

	# 扩散缩放动画（魂系声波感）
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(proj, "scale", Vector2(2.2, 2.2), 0.12)
	tw.tween_property(proj, "color:a", 0.0, 0.25)

	# 移动和碰撞检测
	var lifetime: float = 2.0
	var elapsed: float = 0.0
	var player := _find_player()

	while elapsed < lifetime and is_instance_valid(proj) and is_instance_valid(owner_unit):
		await get_tree().process_frame
		var dt: float = get_process_delta_time()
		elapsed += dt
		if not is_instance_valid(proj):
			return
		proj.global_position += dir * speed * dt

		# 碰撞检测（刷新 player 引用以防切换场景）
		if player and is_instance_valid(player):
			if proj.global_position.distance_to(player.global_position) < 18.0:
				_deal_damage(player, dmg)
				CombatFeedback.hit_particles(proj.global_position, 4, VFXUtils.C_AMBER)
				proj.queue_free()
				return

		# 屏幕边界消失
		if _is_out_of_bounds(proj.global_position):
			proj.queue_free()
			return

	if is_instance_valid(proj):
		proj.queue_free()

# --------------------------------------------------------------------------
# 从 BossPhaseController 读取阶段专属数值
# --------------------------------------------------------------------------

func _get_phase_data() -> BossPhaseData:
	if not owner_unit:
		return null
	var phase_ctrl := owner_unit.get_node_or_null("PhaseController") as BossPhaseController
	if not phase_ctrl:
		return null
	return phase_ctrl.get_current_phase_data()

func _get_phase_bullet_count() -> int:
	var pd := _get_phase_data()
	if pd and pd.bullet_count > 0:
		return pd.bullet_count
	# 默认值（loading 时容错）
	return 5

func _get_phase_bullet_speed() -> float:
	var pd := _get_phase_data()
	if pd and pd.bullet_speed > 0.0:
		return pd.bullet_speed
	return 200.0

func _get_phase_bullet_spread_angle() -> float:
	var pd := _get_phase_data()
	if pd and pd.bullet_spread_angle > 0.0:
		return pd.bullet_spread_angle
	return 90.0

func _get_phase_damage() -> int:
	# 伤害随阶段递增：15 + phase_index * 4
	var pd := _get_phase_data()
	var base: int = damage
	if pd:
		base = damage + pd.phase_index * 4
	return max(base, damage)

# --------------------------------------------------------------------------
# 辅助工具
# --------------------------------------------------------------------------

func _is_out_of_bounds(pos: Vector2) -> bool:
	var vp := get_viewport()
	if not vp: return false
	var cam: Camera2D = vp.get_camera_2d()
	if not cam:
		return false
	var viewport_size := get_viewport().get_visible_rect().size
	return abs(pos.x - cam.global_position.x) > viewport_size.x * 1.1 \
		or abs(pos.y - cam.global_position.y) > viewport_size.y * 1.1

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
