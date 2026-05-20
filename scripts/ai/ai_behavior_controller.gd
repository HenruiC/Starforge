class_name AIBehaviorController
extends Node

## AI 行为控制器 — 马斯克减法方案
##
## 挂在 Enemy (CombatUnit) 下，管理行为状态机切换与每帧行为 Tick。
## 通过 enum + switch 实现，不做行为类继承（MVP 阶段减法）。
##
## 行为优先级（高→低）：
##   STUNNED > FLEE > RETURN > CHASE > KITE > AMBUSH > GUARD > PATROL > IDLE

# --------------------------------------------------------------------------
# 行为模式枚举
# --------------------------------------------------------------------------

enum AIState {
	IDLE,       # 待机，不移动
	PATROL,     # 沿路径巡逻，发现玩家后切换
	GUARD,      # 守卫固定区域
	CHASE,      # 追踪玩家，近战攻击
	KITE,       # 保持距离，远程攻击
	FLEE,       # 低血量逃跑
	STUNNED,    # 被控/冻结
	RETURN,     # 回到出发点
}

# --------------------------------------------------------------------------
# 信号
# --------------------------------------------------------------------------

## 行为切换
signal behavior_changed(old_state: int, new_state: int)
## 攻击阶段变化（"windup" / "active" / "recovery" / "idle"）
signal attack_phase_changed(phase: String)

# --------------------------------------------------------------------------
# 导出参数
# --------------------------------------------------------------------------

## 行为决策频率（秒），避免每帧评估
@export var decision_interval: float = 0.15
## 路径更新频率（秒）
@export var path_update_interval: float = 0.05

# --------------------------------------------------------------------------
# 运行时引用
# --------------------------------------------------------------------------

var _unit: CombatUnit = null
var _player_ref: Node2D = null

# 当前行为状态
var _current_state: int = AIState.IDLE
var _previous_state: int = AIState.IDLE
var _state_elapsed: float = 0.0

# 决策／路径定时器
var _decision_timer: float = 0.0
var _path_timer: float = 0.0

# 攻击阶段状态
var _windup_speed_mult: float = 1.0
var _can_start_new_attack: bool = true
var _is_in_windup: bool = false
var _is_in_recovery: bool = false

# 攻击相位偏移（避免所有敌人同时攻击）
var _attack_phase_offset: float = 0.0

# 当前连接的所有技能
var _skills: Array = []

# PATROL 状态专用
var _patrol_index: int = 0
var _patrol_wait_timer: float = 0.0
var _patrol_waiting: bool = false
var _patrol_forward: bool = true

# FLEE 状态专用
var _flee_timer: float = 0.0

# --------------------------------------------------------------------------
# 设置
# --------------------------------------------------------------------------

## 初始化（由 Enemy._ready 调用）
func setup(unit: CombatUnit, player_ref: Node2D) -> void:
	_unit = unit
	_player_ref = player_ref
	_attack_phase_offset = randf()  # [0, 1) 随机相位偏移

	# 从 unit 读取行为参数
	_enter_state(_determine_initial_state())

## 连接技能信号（由 Enemy 初始化技能后调用）
func connect_skills(skills: Array) -> void:
	_skills = skills
	for skill in skills:
		if skill.has_signal("windup_started"):
			skill.windup_started.connect(_on_skill_windup_started)
		if skill.has_signal("windup_ended"):
			skill.windup_ended.connect(_on_skill_windup_ended)
		if skill.has_signal("recovery_ended"):
			skill.recovery_ended.connect(_on_skill_recovery_ended)

# --------------------------------------------------------------------------
# 每帧流程
# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _unit or _unit.is_dead:
		return

	_state_elapsed += delta

	# 行为切换评估（受 decision_interval 节流）
	_decision_timer += delta
	if _decision_timer >= decision_interval:
		_decision_timer = 0.0
		_evaluate_transition()

	# 当前行为 Tick
	_tick_behavior(delta)

func _tick_behavior(delta: float) -> void:
	match _current_state:
		AIState.CHASE:
			_tick_chase(delta)
		AIState.KITE:
			_tick_kite(delta)
		AIState.PATROL:
			_tick_patrol(delta)
		AIState.GUARD:
			_tick_guard(delta)
		AIState.FLEE:
			_tick_flee(delta)
		AIState.RETURN:
			_tick_return(delta)
		AIState.STUNNED:
			# 不移动，不攻击
			_unit.velocity = Vector2.ZERO
		_:  # IDLE
			_unit.velocity = Vector2.ZERO

# --------------------------------------------------------------------------
# 行为转换
# --------------------------------------------------------------------------

func _evaluate_transition() -> void:
	if _is_in_windup or _is_in_recovery:
		return  # 攻击进行中，不切换行为

	var target_state := _current_state

	# 按优先级评估（高→低）
	if _should_stun():
		target_state = AIState.STUNNED
	elif _should_flee():
		target_state = AIState.FLEE
	elif _should_return():
		target_state = AIState.RETURN
	elif _should_chase():
		target_state = AIState.CHASE
	elif _should_kite():
		target_state = AIState.KITE
	elif _should_guard():
		target_state = AIState.GUARD
	elif _should_patrol():
		target_state = AIState.PATROL
	else:
		target_state = AIState.IDLE

	if target_state != _current_state:
		_enter_state(target_state)

func _enter_state(new_state: int) -> void:
	if new_state == _current_state:
		return
	_previous_state = _current_state
	_current_state = new_state
	_state_elapsed = 0.0

	# 状态进入时的特殊处理
	match new_state:
		AIState.FLEE:
			_flee_timer = 0.0
		AIState.PATROL:
			_patrol_waiting = false
			_patrol_wait_timer = 0.0
		AIState.RETURN:
			# 回到 GUARD 位置或生成位置
			pass

	behavior_changed.emit(_previous_state, new_state)

# --------------------------------------------------------------------------
# 决策函数
# --------------------------------------------------------------------------

func _should_stun() -> bool:
	# 由外部（BuffComponent）通过 set_stunned(true) 设置
	return _current_state == AIState.STUNNED

func _should_flee() -> bool:
	if not _player_ref:
		return false
	if _unit.has_method("get_stat"):
		var is_boss: bool = _unit.get_stat("is_boss", 0.0) > 0.5
		if is_boss:
			return false
	var hp_ratio := _unit.get_health_ratio()
	if hp_ratio < 0.2:
		_flee_timer += _decision_timer
		if _flee_timer < 5.0:
			return true
	return false

func _should_chase() -> bool:
	if not _player_ref:
		return false
	var dist := _unit.global_position.distance_to(_player_ref.global_position)
	var melee_range := _unit.get_stat("melee_range", 45.0)
	var detection_range := _unit.get_stat("detection_range", 250.0)

	if dist < melee_range:
		return true
	# 非远程怪检测到玩家就追
	var is_ranged: bool = _unit.get_stat("is_ranged", 0.0) > 0.5
	if dist < detection_range and not is_ranged:
		return true
	return false

func _should_kite() -> bool:
	if not _player_ref:
		return false
	var is_ranged: bool = _unit.get_stat("is_ranged", 0.0) > 0.5
	if not is_ranged:
		return false
	var dist := _unit.global_position.distance_to(_player_ref.global_position)
	var pref_dist := _unit.get_stat("preferred_distance", 180.0)
	var melee_range := _unit.get_stat("melee_range", 45.0)
	return dist < pref_dist + 30.0 and dist > melee_range

func _should_guard() -> bool:
	var guard_pos_str := _unit.get_stat("guard_position_x", 0.0)
	return guard_pos_str != 0.0 or _current_state == AIState.GUARD

func _should_patrol() -> bool:
	# patrol_path 不为空 → 可以巡逻
	var path_count := int(_unit.get_stat("patrol_path_count", 0.0))
	return path_count >= 2 or _current_state == AIState.PATROL

func _should_return() -> bool:
	if not _player_ref:
		return false
	var dist := _unit.global_position.distance_to(_player_ref.global_position)
	var leash := _unit.get_stat("leash_range", 400.0)
	return dist > leash and _current_state not in [AIState.RETURN, AIState.GUARD]

# --------------------------------------------------------------------------
# CHASE — 追踪近战
# --------------------------------------------------------------------------

func _get_coordinator() -> AttackCoordinator:
	var tree := get_tree()
	if tree and tree.root.has_node("Coordinator"):
		return tree.root.get_node("Coordinator") as AttackCoordinator
	return null

func _tick_chase(delta: float) -> void:
	if not _player_ref:
		_unit.velocity = Vector2.ZERO
		return

	var dist := _unit.global_position.distance_to(_player_ref.global_position)
	var dir := _unit.global_position.direction_to(_player_ref.global_position)
	var move_speed := _unit.get_stat("move_speed", 200.0)

	# 攻击相位偏移：不同敌人速度微差异（0.85~1.15），避免同时到达
	var speed_var := 0.85 + _attack_phase_offset * 0.3

	# 根据距离决定行为
	if dist > 150.0:
		# 远距：全速追击
		_unit.velocity = dir * move_speed * speed_var
	elif dist > 45.0:
		# 中距：降速，准备攻击
		var coordinator := _get_coordinator()
		if coordinator and coordinator.get_active_melee_count() < 3:
			_unit.velocity = dir * move_speed * 0.7 * speed_var
		else:
			# 超过 3 个近战在攻击 → 在 60px 外 hold
			_hold_at_distance(_player_ref.global_position, 60.0)
	else:
		# 近战范围：尝试攻击
		_unit.velocity = Vector2.ZERO
		_try_melee_attack()

func _try_melee_attack() -> void:
	if not _can_start_new_attack or _is_in_windup or _is_in_recovery:
		return

	var coordinator := _get_coordinator()
	if coordinator and coordinator.register_attack(_unit):
		# 尝试使用第一个技能（slash 等近战技能）
		if _skills.size() > 0 and _skills[0].has_method("try_execute"):
			var skill = _skills[0]
			if skill.is_ready:
				skill.try_execute()  # 不 await，后台协程
				coordinator.finish_attack(_unit)

# --------------------------------------------------------------------------
# KITE — 保持距离远程
# --------------------------------------------------------------------------

func _tick_kite(delta: float) -> void:
	if not _player_ref:
		_unit.velocity = Vector2.ZERO
		return

	var dist := _unit.global_position.distance_to(_player_ref.global_position)
	var dir := _unit.global_position.direction_to(_player_ref.global_position)
	var move_speed := _unit.get_stat("move_speed", 200.0)
	var pref_dist := _unit.get_stat("preferred_distance", 180.0)

	# 群组协调：近战正在骚扰玩家时，远程缩近距离
	var coordinator := _get_coordinator()
	if coordinator and coordinator.is_player_under_melee_pressure():
		pref_dist *= 0.7

	# 距离维持
	if dist > pref_dist + 30.0:
		_unit.velocity = dir * move_speed
	elif dist < pref_dist - 30.0:
		# 被逼近，后退
		_unit.velocity = -dir * move_speed * 0.6
	else:
		# 在射程内横向移动（strafe）
		var strafe := dir.rotated(PI / 2) * move_speed * 0.3
		_unit.velocity = strafe

	# 尝试远程攻击
	if _skills.size() > 0 and not _is_in_windup:
		var skill = _skills[0]
		if skill.is_ready:
			skill.try_execute()  # 不 await，后台协程

# --------------------------------------------------------------------------
# PATROL — 巡逻
# --------------------------------------------------------------------------

func _tick_patrol(delta: float) -> void:
	# 如果发现玩家且在视野内，转 CHASE（由 _evaluate_transition 处理）
	if _player_ref:
		var dist := _unit.global_position.distance_to(_player_ref.global_position)
		if dist < _unit.get_stat("detection_range", 250.0):
			# 简单视野锥检查
			var to_player := _player_ref.global_position - _unit.global_position
			if to_player.length() > 0:
				_unit.velocity = Vector2.ZERO
				return  # 让评估函数处理切换

	# 巡逻路径为空 → 转 IDLE
	var path_count := int(_unit.get_stat("patrol_path_count", 0.0))
	if path_count < 2:
		_enter_state(AIState.IDLE)
		return

	# 到达等待中
	if _patrol_waiting:
		_patrol_wait_timer += delta
		if _patrol_wait_timer >= _unit.get_stat("patrol_wait_time", 1.0):
			_patrol_waiting = false
			_patrol_wait_timer = 0.0
			_advance_patrol_index()
		return

	# 有路径点——通过 get_stat 间接获取（实际 patrol_points 在 Enemy 上）
	# 简化版本：用 guard_position 作为目标
	var target_pos := _get_patrol_target()
	if target_pos == Vector2.ZERO:
		_unit.velocity = Vector2.ZERO
		return

	var dir := _unit.global_position.direction_to(target_pos)
	var dist := _unit.global_position.distance_to(target_pos)

	if dist < 16.0:
		_patrol_waiting = true
		_unit.velocity = Vector2.ZERO
	else:
		_unit.velocity = dir * _unit.get_stat("move_speed", 200.0) * 0.5

func _advance_patrol_index() -> void:
	var path_count := int(_unit.get_stat("patrol_path_count", 0.0))
	if _patrol_forward:
		_patrol_index += 1
		if _patrol_index >= path_count - 1:
			_patrol_forward = false
	else:
		_patrol_index -= 1
		if _patrol_index <= 0:
			_patrol_forward = true

func _get_patrol_target() -> Vector2:
	# 从 Enemy 获取 patrol_points 数组
	if _unit.has_method("get_patrol_point"):
		return _unit.get_patrol_point(_patrol_index)
	return Vector2.ZERO

# --------------------------------------------------------------------------
# GUARD — 守卫
# --------------------------------------------------------------------------

func _tick_guard(delta: float) -> void:
	var guard_pos := Vector2(
		_unit.get_stat("guard_position_x", _unit.global_position.x),
		_unit.get_stat("guard_position_y", _unit.global_position.y)
	)
	var radius := _unit.get_stat("guard_radius", 60.0)
	var move_speed := _unit.get_stat("move_speed", 200.0)

	var dist_to_guard := _unit.global_position.distance_to(guard_pos)

	if dist_to_guard > radius:
		# 走回守卫点
		var dir := _unit.global_position.direction_to(guard_pos)
		_unit.velocity = dir * move_speed * 0.5
	else:
		# 在守卫范围内随机慢速移动
		_unit.velocity = Vector2.ZERO

	# 玩家在守卫范围内？让 eval 处理转 CHASE
	if _player_ref:
		var dist := _unit.global_position.distance_to(_player_ref.global_position)
		if dist < _unit.get_stat("guard_leash", 200.0):
			# 守卫范围内攻击
			if _skills.size() > 0 and not _is_in_windup:
				var skill = _skills[0]
				if skill.is_ready:
					skill.try_execute()

# --------------------------------------------------------------------------
# FLEE — 逃跑
# --------------------------------------------------------------------------

func _tick_flee(delta: float) -> void:
	if not _player_ref:
		_unit.velocity = Vector2.ZERO
		return

	var dir := _unit.global_position.direction_to(_player_ref.global_position)
	var move_speed := _unit.get_stat("move_speed", 200.0)
	var flee_speed_mult := _unit.get_stat("flee_speed_mult", 1.3)

	# 远离玩家方向 + 随机偏转
	var flee_dir := -dir
	flee_dir = flee_dir.rotated(randf_range(-0.5, 0.5))  # ±30度随机
	_unit.velocity = flee_dir * move_speed * flee_speed_mult

	# 逃跑时不攻击

func _tick_return(delta: float) -> void:
	var return_pos := Vector2(
		_unit.get_stat("guard_position_x", 0.0),
		_unit.get_stat("guard_position_y", 0.0)
	)
	if return_pos == Vector2.ZERO:
		# 没有守卫点 → 转 IDLE
		_enter_state(AIState.IDLE)
		return

	var dir := _unit.global_position.direction_to(return_pos)
	var dist := _unit.global_position.distance_to(return_pos)
	var move_speed := _unit.get_stat("move_speed", 200.0)

	if dist < 30.0:
		_unit.velocity = Vector2.ZERO
		_enter_state(AIState.GUARD)
	else:
		_unit.velocity = dir * move_speed

# --------------------------------------------------------------------------
# 辅助方法
# --------------------------------------------------------------------------

func _hold_at_distance(target_pos: Vector2, dist: float) -> void:
	var dir := _unit.global_position.direction_to(target_pos)
	var hold_pos := target_pos - dir * dist
	hold_pos += Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
	var move_dir := _unit.global_position.direction_to(hold_pos)
	_unit.velocity = move_dir * _unit.get_stat("move_speed", 200.0) * 0.3

# --------------------------------------------------------------------------
# 初始状态推断
# --------------------------------------------------------------------------

func _determine_initial_state() -> int:
	var is_ranged: bool = _unit.get_stat("is_ranged", 0.0) > 0.5
	if is_ranged:
		return AIState.KITE
	return AIState.CHASE

# --------------------------------------------------------------------------
# 技能信号回调（前摇/硬直期间的行为限制）
# --------------------------------------------------------------------------

func _on_skill_windup_started(duration: float) -> void:
	_is_in_windup = true
	_windup_speed_mult = 0.2
	_can_start_new_attack = false
	attack_phase_changed.emit("windup")

func _on_skill_windup_ended() -> void:
	_is_in_windup = false
	_windup_speed_mult = 0.0
	attack_phase_changed.emit("active")

func _on_skill_recovery_ended() -> void:
	_is_in_recovery = false
	_windup_speed_mult = 1.0
	_can_start_new_attack = true
	attack_phase_changed.emit("idle")

# --------------------------------------------------------------------------
# 公共查询接口
# --------------------------------------------------------------------------

func get_current_state() -> int:
	return _current_state

func is_in_windup() -> bool:
	return _is_in_windup

func is_in_recovery() -> bool:
	return _is_in_recovery

func get_skill_count() -> int:
	return _skills.size()
