class_name BossAI
extends Node

## Boss AI 控制器 — 四乐章行为管理
##
## 替换标准 AIBehaviorController，为 Boss 提供基于乐章的行为驱动。
## 每乐章有独立的移动策略和攻击选择逻辑。
## 不继承 AIBehaviorController（Boss 不需要 PATROL/FLEE/GUARD 等状态）。
##
## 用法：
##   1. setup(boss_unit, player_ref, phase_controller, skills)
##   2. 在 enemy._process 中调用 tick(delta)
##   3. 技能通过直接调用 skill.try_execute() 触发

# --------------------------------------------------------------------------
# 信号
# --------------------------------------------------------------------------

## 行为阶段变化（windup / active / recovery / idle / summon）
signal attack_phase_changed(phase: String)

# --------------------------------------------------------------------------
# 引用
# --------------------------------------------------------------------------

var _unit: CombatUnit = null
var _player_ref: Node2D = null
var _phase_controller: BossPhaseController = null

## Boss 技能列表（SkillBase 实例）
var _skills: Array = []
## 每个技能是否在 CD 中（技能自身管理）
var _last_attack_index: int = -1
## 前摇视觉 Tween（红白脉冲 — 魂系可读性核心）
var _windup_visual_tween: Tween = null

# --------------------------------------------------------------------------
# 乐章专用状态
# --------------------------------------------------------------------------

# 第一乐章：固定循环
var _m1_attack_index: int = 0
var _m1_attack_order: Array[int] = [0, 1, 2, 3]  # 技能槽位索引

# 第二乐章：权重随机，同一攻击不连续
var _m2_weights: Array[float] = [0.25, 0.25, 0.2, 0.2, 0.1]

# 第三乐章：召唤计时
var _m3_summon_timer: float = 0.0
var _chase_patience_timer: float = 0.0
var _delta: float = 0.0
var _m3_summon_count: int = 0
var _m3_summon_interval: float = 12.0
var _m3_max_students: int = 9

# 第四乐章：冲刺间隔
var _m4_dash_interval: float = 2.0

# --------------------------------------------------------------------------
# 通用运行状态
# --------------------------------------------------------------------------

var _attack_timer: float = 0.0
var _can_attack: bool = true
var _is_attacking: bool = false  # windup/recovery 中禁止新攻击
var _is_in_windup: bool = false
var _is_in_recovery: bool = false
var _movement_enabled: bool = true  # windup 期间减速

# 外部 NavManager 引用
var _nav_agent: Node = null

# --------------------------------------------------------------------------
# 初始化
# --------------------------------------------------------------------------

func setup(unit: CombatUnit, player_ref: Node2D, phase_controller: BossPhaseController, skills: Array) -> void:
	_unit = unit
	_player_ref = player_ref
	_phase_controller = phase_controller
	_skills = skills

	_attack_timer = randf_range(0.5, 1.5)  # 初始随机延时

	# 连接技能信号
	for skill in skills:
		if skill.has_signal("windup_started"):
			skill.windup_started.connect(_on_skill_windup_started)
		if skill.has_signal("windup_ended"):
			skill.windup_ended.connect(_on_skill_windup_ended)
		if skill.has_signal("recovery_ended"):
			skill.recovery_ended.connect(_on_skill_recovery_ended)

# --------------------------------------------------------------------------
# 主 Tick（由 Enemy._process 或 _physics_process 调用）
# --------------------------------------------------------------------------

func tick(delta: float) -> void:
	_delta = delta
	if not _unit or _unit.is_dead or not _player_ref:
		_unit.velocity = Vector2.ZERO
		return

	var phase: BossPhaseData = _phase_controller.get_current_phase_data()
	if not phase or _phase_controller.is_transitioning:
		_unit.velocity = Vector2.ZERO
		return

	# 攻击计时
	_attack_timer -= delta
	if _attack_timer <= 0.0 and _can_attack and not _is_attacking:
		_attack_timer = 0.0

	# 乐章专属移动逻辑
	match phase.phase_index:
		0:
			_movement_phase1(delta, phase)
		1:
			_movement_phase2(delta, phase)
		2:
			_movement_phase3(delta, phase)
		3:
			_movement_phase4(delta, phase)

	# 攻击准备（不在 windup/recovery 中时发起）
	if _attack_timer <= 0.0 and _can_attack and not _is_attacking and not _phase_controller.is_transitioning:
		_select_and_execute_attack(phase)
		# 重置攻击计时（interval 在当前乐章范围内随机）
		_attack_timer = randf_range(phase.attack_interval_min, phase.attack_interval_max)

# --------------------------------------------------------------------------
# 乐章移动逻辑
# --------------------------------------------------------------------------

## 第一乐章：慢速追踪（KITE + 固定循环攻击）
func _movement_phase1(delta: float, phase: BossPhaseData) -> void:
	_chase_player(phase.move_speed)

## 第二乐章：保持中距离（KITE）
func _movement_phase2(delta: float, phase: BossPhaseData) -> void:
	_kite_player(phase.move_speed, 150.0, 200.0)

## 第三乐章：追踪 + 召唤独立计时
func _movement_phase3(delta: float, phase: BossPhaseData) -> void:
	_chase_player(phase.move_speed)

	# 召唤计时
	_m3_summon_timer += delta
	if _m3_summon_timer >= phase.summon_interval and phase.summon_enabled:
		_m3_summon_timer = 0.0
		_m3_summon_count += 1
		if _m3_summon_count == 3:  # 第 3 次吹哨 → 空哨
			_trigger_empty_whistle()
		else:
			_try_summon_students(phase)

## 第四乐章：狂暴追踪 + 冲刺递减
func _movement_phase4(_delta: float, phase: BossPhaseData) -> void:
	var hp: int = _unit.get_current_health()
	var max_hp: int = _unit.max_health
	var hp_ratio: float = float(hp) / float(max_hp) if max_hp > 0 else 0.0

	# HP < 5%：站桩
	if hp_ratio < 0.05:
		_unit.velocity = Vector2.ZERO
		_m4_dash_interval = 0.8
	elif hp < 100:
		_m4_dash_interval = 1.0
	elif hp < 200:
		_m4_dash_interval = 1.5
	elif hp < 300:
		_m4_dash_interval = 2.0
	else:
		_m4_dash_interval = 2.0

	_chase_player(phase.move_speed)

# --------------------------------------------------------------------------
# 攻击选择
# --------------------------------------------------------------------------

func _select_and_execute_attack(phase: BossPhaseData) -> void:
	if _skills.is_empty() or phase.skill_slots.is_empty():
		return

	var skill_idx: int = -1
	match phase.phase_index:
		0:
			skill_idx = _select_m1_attack(phase)
		1:
			skill_idx = _select_m2_attack(phase)
		2:
			skill_idx = _select_m3_attack(phase)
		3:
			skill_idx = _select_m4_attack(phase)

	if skill_idx >= 0 and skill_idx < _skills.size():
		var skill = _skills[skill_idx]
		if skill.has_method("try_execute"):
			_is_attacking = true
			skill.try_execute()

# --------------------------------------------------------------------------
# 乐章攻击选择策略
# --------------------------------------------------------------------------

## 第一乐章：固定循环 M1-A → M1-B → M1-C → M1-D
func _select_m1_attack(phase: BossPhaseData) -> int:
	if _m1_attack_order.is_empty():
		return -1
	var idx: int = _m1_attack_order[_m1_attack_index]
	_m1_attack_index = (_m1_attack_index + 1) % _m1_attack_order.size()
	# 映射到 phase 的 skill_slots
	if idx < phase.skill_slots.size():
		return phase.skill_slots[idx]
	return phase.skill_slots[0]

## 第二乐章：权重随机，不连续重复
func _select_m2_attack(phase: BossPhaseData) -> int:
	var slots: Array[int] = phase.skill_slots
	if slots.is_empty():
		return -1
	# 构建候选池（排除上一次）
	var candidates: Array[int] = []
	var weights: Array[float] = []
	for i in range(slots.size()):
		if i != _last_attack_index:
			candidates.append(slots[i])
			weights.append(_m2_weights[i] if i < _m2_weights.size() else 0.1)

	if candidates.is_empty():
		candidates = slots
		weights = _m2_weights.slice(0, slots.size())

	# 按权重随机
	var total: float = 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return slots[0]
	var r: float = randf() * total
	var accum: float = 0.0
	for i in range(candidates.size()):
		accum += weights[i]
		if r <= accum:
			_last_attack_index = i
			return candidates[i]
	return candidates.back()

## 第三乐章：从 [M3-B, M3-C, M3-D] 随机
func _select_m3_attack(phase: BossPhaseData) -> int:
	var slots: Array[int] = phase.skill_slots
	if slots.is_empty():
		return -1
	# 排除 summon（slot 0 保留给召唤）
	if slots.size() <= 1:
		return slots[0]
	var non_summon: Array[int] = []
	for i in range(1, slots.size()):
		non_summon.append(slots[i])
	if non_summon.is_empty():
		return slots[0]
	return non_summon[randi() % non_summon.size()]

## 第四乐章：绝望冲刺为主 + 器材雨 CD
func _select_m4_attack(phase: BossPhaseData) -> int:
	var slots: Array[int] = phase.skill_slots
	if slots.is_empty():
		return -1
	# 优先器材雨（slot 1），以 _m4_dash_interval 为间隔切换
	# 简单实现：交替 dash 和 equipment rain
	if _last_attack_index < 0 or _last_attack_index == 1:
		return slots[0]  # 绝望冲刺
	else:
		return slots[1] if slots.size() > 1 else slots[0]

# --------------------------------------------------------------------------
# 移动辅助
# --------------------------------------------------------------------------

func _chase_player(speed: float) -> void:
	if not _player_ref:
		_unit.velocity = Vector2.ZERO
		return
	if _is_in_windup or _is_in_recovery:
		_unit.velocity = Vector2.ZERO
		return

	var dist: float = _unit.global_position.distance_to(_player_ref.global_position)
	var dir: Vector2 = _unit.global_position.direction_to(_player_ref.global_position)

	# 近战反制：玩家太近，用近战技能
	var phase: BossPhaseData = _phase_controller.get_current_phase_data()
	if phase and phase.close_range_skill_slot >= 0 and dist < 80:
		if _can_attack and not _is_attacking and not _phase_controller.is_transitioning:
			# 近战反制：直接在技能槽中选择并执行
			var slot: int = phase.close_range_skill_slot
			if slot >= 0 and slot < _skills.size():
				var s: SkillBase = _skills[slot]
				if s and s.has_method("try_execute"):
					s.try_execute()
			_attack_timer = randf_range(phase.attack_interval_min, phase.attack_interval_max)
			return

	# 追杀惩罚：玩家逃跑太远，加速追击
	if phase and phase.chase_distance_threshold > 0 and dist > phase.chase_distance_threshold:
		_chase_patience_timer += _delta
		if _chase_patience_timer > phase.chase_patience:
			# 冲刺追击
			_unit.velocity = dir * phase.chase_speed
			return
	else:
		_chase_patience_timer = 0.0

	_unit.velocity = dir * speed

func _kite_player(speed: float, min_dist: float, max_dist: float) -> void:
	if not _player_ref:
		_unit.velocity = Vector2.ZERO
		return
	if _is_in_windup or _is_in_recovery:
		_unit.velocity = Vector2.ZERO
		return

	var dist: float = _unit.global_position.distance_to(_player_ref.global_position)
	var dir: Vector2 = _unit.global_position.direction_to(_player_ref.global_position)

	if dist < min_dist:
		# 太近，后退
		_unit.velocity = -dir * speed * 0.6
	elif dist > max_dist:
		# 太远，接近
		_unit.velocity = dir * speed
	else:
		# 在理想距离内横向移动
		var strafe: Vector2 = dir.rotated(PI / 2.0) * speed * 0.3
		_unit.velocity = strafe

# --------------------------------------------------------------------------
# 第三乐章特殊逻辑
# --------------------------------------------------------------------------

func _try_summon_students(phase: BossPhaseData) -> void:
	# 检查场上学生数量（由外部设置）
	var student_count: int = _get_student_count()
	if student_count >= _m3_max_students:
		return

	# 查找 summon 技能（slot 0 通常是 summon）
	if _skills.size() > 0:
		var skill = _skills[0]
		if skill and skill.skill_id == "m3_summon_whistle" and skill.has_method("try_execute"):
			if skill.is_ready:
				_is_attacking = true
				skill.try_execute()

## 空哨叙事事件
func _trigger_empty_whistle() -> void:
	# 视觉表现：脉冲 → 声波 → 无学生出现
	# 由视觉层处理，此处仅暂停召唤 CD 20s
	_m3_summon_timer = -20.0  # 20s CD

## 获取场上学生数量（遍历场景中的 StudentMinion）
func _get_student_count() -> int:
	var count: int = 0
	var tree := get_tree()
	if not tree:
		return 0
	var students := tree.get_nodes_in_group("student_minion")
	return students.size()

# --------------------------------------------------------------------------
# 技能信号回调
# --------------------------------------------------------------------------

func _on_skill_windup_started(duration: float) -> void:
	_is_attacking = true
	_is_in_windup = true
	_movement_enabled = false
	attack_phase_changed.emit("windup")
	_flash_boss_windup(duration)

func _on_skill_windup_ended() -> void:
	_is_in_windup = false
	_clear_windup_visual()
	attack_phase_changed.emit("active")

func _on_skill_recovery_ended() -> void:
	_is_in_recovery = false
	_is_attacking = false
	_movement_enabled = true
	attack_phase_changed.emit("idle")


# --------------------------------------------------------------------------
# 前摇视觉效果：Boss 攻击前身体周期闪红白，让玩家能预判
# --------------------------------------------------------------------------

func _flash_boss_windup(duration: float) -> void:
	_clear_windup_visual()
	if not _unit:
		return
	var sprite: ColorRect = _unit.get_node_or_null("Sprite") as ColorRect
	if not sprite:
		return

	var orig_color := sprite.color
	var pulse_count: int = maxi(ceilf(duration / 0.2), 2)
	var pulse_interval: float = duration / float(pulse_count)

	_windup_visual_tween = _unit.create_tween()
	for i in range(pulse_count):
		_windup_visual_tween.tween_property(sprite, "modulate", Color(1.3, 0.3, 0.2, 1.0), pulse_interval * 0.4)
		_windup_visual_tween.tween_property(sprite, "modulate", orig_color, pulse_interval * 0.6)

func _clear_windup_visual() -> void:
	if _windup_visual_tween and is_instance_valid(_windup_visual_tween):
		_windup_visual_tween.kill()
	_windup_visual_tween = null
	if _unit and is_instance_valid(_unit):
		var sprite: ColorRect = _unit.get_node_or_null("Sprite") as ColorRect
		if sprite:
			sprite.modulate = Color.WHITE

# --------------------------------------------------------------------------
# 公共接口
	# --------------------------------------------------------------------------

func get_attack_timer() -> float:
	return _attack_timer

func set_can_attack(v: bool) -> void:
	_can_attack = v

func is_attacking() -> bool:
	return _is_attacking
