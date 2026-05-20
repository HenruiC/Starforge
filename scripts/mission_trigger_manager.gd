class_name MissionTriggerManager
extends Node

# ==============================
# 通用任务触发引擎
# V2.0 新增 2 种 Trigger 类型：
#   DEFEND_ZONE / PROTECT_OBJECT
# V1.0 保留 3 种：LOCATION_REACH / KILL_COUNT / TIME_SURVIVE
# ==============================

signal stage_activated(stage_id: int)
signal stage_completed(stage_id: int)
signal objective_progressed(stage_id: int, objective_id: String, current: float, target: float)
signal objective_completed(stage_id: int, objective_id: String)
signal chain_completed(chain_id: String, success: bool)
signal prompt_requested(prompt: PromptConfig)
signal prompt_dismissed(prompt_id: String)

# ------------------------------
# 内部状态
# ------------------------------
var _chain: MissionChain = null
var _tracked_zone_areas: Array[Area2D] = []
var _zone_signal_map: Dictionary = {}  # Area2D → {"entered": Callable, "exited": Callable}
var _survive_timer: float = 0.0
var _is_paused: bool = false
var _current_stage_index: int = -1
var _pending_activation_index: int = -1

# DEFEND_ZONE: 追踪各 Objective 的驻守激活状态（用于 emit state_changed 信号）
var _defend_zone_states: Dictionary = {}  # objective_id → was_active: bool

# PROTECT_OBJECT: 已损毁的保护目标（避免重复处理）
var _protect_object_destroyed: Dictionary = {}  # object_id → true

# Evaluator 注册表：MissionTriggerType → Callable
var _evaluators: Dictionary = {}

# 记录精英/Boss/远程敌人生成时的引用，用于 KILL_COUNT 过滤
# 暂保留字段，V1.0 简化处理


# ==============================
# 生命周期
# ==============================

func _ready():
	add_to_group("mission_trigger")
	process_mode = Node.PROCESS_MODE_ALWAYS

	_register_evaluators()

	EventBus.enemy_killed_filtered.connect(_on_enemy_killed_filtered)
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_entered_zone.connect(_on_player_entered_zone)
	EventBus.player_exited_zone.connect(_on_player_exited_zone)
	EventBus.protectable_destroyed.connect(_on_protectable_destroyed)
	GameState.state_changed.connect(_on_game_state_changed)

func _register_evaluators() -> void:
	_evaluators[TriggerConfig.MissionTriggerType.LOCATION_REACH] = _eval_location
	_evaluators[TriggerConfig.MissionTriggerType.KILL_COUNT] = _eval_kill
	_evaluators[TriggerConfig.MissionTriggerType.TIME_SURVIVE] = _eval_time
	# 预留类型注册空函数，避免 key 缺失
	_evaluators[TriggerConfig.MissionTriggerType.INTERACT] = _eval_not_implemented
	_evaluators[TriggerConfig.MissionTriggerType.COLLECT] = _eval_not_implemented
	_evaluators[TriggerConfig.MissionTriggerType.BOSS_HP_THRESHOLD] = _eval_not_implemented
	# V2.0: DEFEND_ZONE 和 PROTECT_OBJECT 独立注册
	_evaluators[TriggerConfig.MissionTriggerType.DEFEND_ZONE] = _eval_defend_zone
	_evaluators[TriggerConfig.MissionTriggerType.PROTECT_OBJECT] = _eval_protect_object


# ==============================
# 公共 API
# ==============================

## 加载任务链并开始追踪
func load_chain(chain: MissionChain) -> void:
	_cleanup()

	_chain = chain
	if _chain == null:
		return

	_chain.status = MissionChain.ChainStatus.RUNNING
	_chain.current_stage_index = 0
	_current_stage_index = -1
	_pending_activation_index = -1
	_defend_zone_states.clear()
	_protect_object_destroyed.clear()
	_survive_timer = 0.0

	# 从链定义中创建 Zone
	_create_chain_zones()
	# 扫描场景中已有的 Zone
	_find_existing_zones()

	# 激活第一个 Stage（无激活条件的首个 Stage）
	_activate_stage(0)

## 获取当前 Stage（可能为 null）
func get_current_stage() -> MissionStage:
	if _chain == null:
		return null
	if _current_stage_index < 0 or _current_stage_index >= _chain.stages.size():
		return null
	return _chain.stages[_current_stage_index]

## 获取当前 Stage 索引（0-based，-1 表示无活跃 Stage）
func get_current_stage_index() -> int:
	return _current_stage_index

## 外部通知击杀（兼容旧接口，不执行实际逻辑）
func notify_kill(_is_elite: bool = false) -> void:
	# 已废弃 — MissionTriggerManager 通过 EventBus.enemy_killed_filtered 自动追踪
	pass


# ==============================
# _process — 驱动 TIME_SURVIVE 计时器
# ==============================

func _process(delta: float) -> void:
	if _chain == null or _chain.status != MissionChain.ChainStatus.RUNNING:
		return
	if _current_stage_index < 0 or _current_stage_index >= _chain.stages.size():
		return

	var stage: MissionStage = _chain.stages[_current_stage_index]
	if stage.status != MissionStage.StageStatus.ACTIVE:
		return

	# TIME_SURVIVE 需要逐帧推进
	if _is_paused:
		return

	var any_time_active := false
	for obj in stage.objectives:
		if obj.trigger == null:
			continue
		if obj.trigger.trigger_type != TriggerConfig.MissionTriggerType.TIME_SURVIVE:
			continue
		if obj.trigger.current_value >= obj.trigger.target_value:
			continue
		any_time_active = true
		obj.trigger.current_value += delta
		objective_progressed.emit(
			stage.stage_id, obj.objective_id,
			obj.trigger.current_value, obj.trigger.target_value
		)
		if obj.trigger.current_value >= obj.trigger.target_value:
			_on_objective_completed(stage, obj)

	if any_time_active:
		_survive_timer += delta

	# ==== DEFEND_ZONE（新，独立于 TIME_SURVIVE）====
	for obj in stage.objectives:
		if obj.trigger == null:
			continue
		if obj.trigger.trigger_type != TriggerConfig.MissionTriggerType.DEFEND_ZONE:
			continue
		if obj.trigger.current_value >= obj.trigger.target_value:
			continue
		_eval_defend_zone(stage, obj, delta)

	# ==== PROTECT_OBJECT（新，独立于 TIME_SURVIVE）====
	for obj in stage.objectives:
		if obj.trigger == null:
			continue
		if obj.trigger.trigger_type != TriggerConfig.MissionTriggerType.PROTECT_OBJECT:
			continue
		if obj.trigger.current_value >= obj.trigger.target_value:
			continue
		_eval_protect_object(stage, obj, delta)


# ==============================
# 内部：Stage 管理
# ==============================

## 激活指定索引的 Stage
func _activate_stage(index: int) -> void:
	if _chain == null or index >= _chain.stages.size():
		return

	var stage: MissionStage = _chain.stages[index]
	stage.status = MissionStage.StageStatus.ACTIVE
	_current_stage_index = index
	_chain.current_stage_index = index
	_pending_activation_index = -1
	_survive_timer = 0.0

	# 重置所有 Objective 的运行时进度
	for obj in stage.objectives:
		if obj.trigger != null:
			obj.trigger.current_value = 0.0

	stage_activated.emit(stage.stage_id)

	# 激活提示
	if stage.on_activate_prompt != null:
		prompt_requested.emit(stage.on_activate_prompt)
	# 激活对话
	if stage.on_activate_dialogue != null:
		EventBus.dialogue_triggered.emit(stage.on_activate_dialogue, stage.on_activate_dialogue_group)

## 尝试激活下一个 Stage（可能被 activation_condition 阻塞）
func _try_advance_to_next() -> void:
	if _chain == null:
		return
	var next_index: int = _current_stage_index + 1
	if next_index >= _chain.stages.size():
		# 所有 Stage 完成
		_chain.status = MissionChain.ChainStatus.COMPLETED
		chain_completed.emit(_chain.chain_id, true)
		return

	var next_stage: MissionStage = _chain.stages[next_index]
	if next_stage.activation_condition != null:
		# 有激活条件 — 暂不激活，等待条件满足
		_pending_activation_index = next_index
		# 首次检查
		_check_pending_activation()
		return

	_activate_stage(next_index)

## 检查 pending 的 Stage 激活条件是否满足
func _check_pending_activation() -> void:
	if _pending_activation_index < 0:
		return
	var stage := _chain.stages[_pending_activation_index]
	var cond := stage.activation_condition
	if cond == null:
		return
	# LOCATION_REACH: check if player already in zone
	if cond.trigger_type == TriggerConfig.MissionTriggerType.LOCATION_REACH:
		var zone_id: String = cond.params.get("zone_id", "")
		if not zone_id.is_empty():
			for area in _tracked_zone_areas:
				if area.get_meta("zone_id", "") == zone_id:
					for body in area.get_overlapping_bodies():
						if body.is_in_group("player"):
							_activate_stage(_pending_activation_index)
							return


# ==============================
# 内部：Objective 完成 & Stage 完成检查
# ==============================

## 当单个 Objective 完成时调用
func _on_objective_completed(stage: MissionStage, obj: MissionObjective) -> void:
	print("MISSION: objective completed id=", obj.objective_id, " action=", obj.completion_action)
	objective_completed.emit(stage.stage_id, obj.objective_id)
	# 分发 completion_action（纯数据驱动，不耦合任何 Trigger 类型）
	if obj.completion_action != null and not obj.completion_action.is_empty():
		_dispatch_completion_action(obj)
	# Objective 完成对话
	if obj.on_complete_dialogue != null:
		EventBus.dialogue_triggered.emit(obj.on_complete_dialogue)
	_check_stage_completion(stage)

## 检查 Stage 是否所有必填 Objective 完成
func _check_stage_completion(stage: MissionStage) -> void:
	for obj in stage.objectives:
		if obj.is_optional:
			continue
		if obj.trigger == null:
			continue
		if obj.trigger.current_value < obj.trigger.target_value:
			return  # 还有必填未完成，不推进

	# 所有必填已完成
	stage.status = MissionStage.StageStatus.COMPLETED
	stage_completed.emit(stage.stage_id)

	# 完成提示
	if stage.on_complete_prompt != null:
		prompt_requested.emit(stage.on_complete_prompt)
	# 完成对话
	if stage.on_complete_dialogue != null:
		EventBus.dialogue_triggered.emit(stage.on_complete_dialogue)

	# 尝试推进到下一 Stage
	_try_advance_to_next()


# ==============================
# Zone 管理
# ==============================

## 从 MissionChain.zone_definitions 动态创建 Area2D 区域
func _create_chain_zones() -> void:
	if _chain == null or _chain.zone_definitions.is_empty():
		return

	for zd in _chain.zone_definitions:
		var zone_id: String = zd.get("zone_id", "")
		if zone_id.is_empty():
			continue

		var area := Area2D.new()
		area.name = "Zone_%s" % zone_id
		area.add_to_group("mission_zone")
		area.set_meta("zone_id", zone_id)
		area.position = zd.get("position", Vector2.ZERO)

		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = zd.get("size", Vector2(200, 200))
		collision.shape = shape
		area.add_child(collision)

		_connect_zone_signals(area)
		add_child(area)
		_tracked_zone_areas.append(area)

## 扫描场景中已存在的 mission_zone 组 Area2D
func _find_existing_zones() -> void:
	if not is_inside_tree():
		return

	var all_zones: Array[Node] = get_tree().get_nodes_in_group("mission_zone")
	for zone in all_zones:
		if zone is Area2D and not _tracked_zone_areas.has(zone):
			_connect_zone_signals(zone)
			_tracked_zone_areas.append(zone)

## 连接 Area2D 的 body_entered / body_exited 信号
func _connect_zone_signals(area: Area2D) -> void:
	if _zone_signal_map.has(area):
		return  # 已连接
	var entered_callable := _on_zone_body_entered.bind(area)
	var exited_callable := _on_zone_body_exited.bind(area)
	area.body_entered.connect(entered_callable)
	area.body_exited.connect(exited_callable)
	_zone_signal_map[area] = {"entered": entered_callable, "exited": exited_callable}


# ==============================
# Zone 事件回调 → EventBus
# ==============================

func _on_zone_body_entered(body: Node2D, area: Area2D) -> void:
	if body.is_in_group("player"):
		var zone_id: String = area.get_meta("zone_id", "")
		if not zone_id.is_empty():
			EventBus.player_entered_zone.emit(zone_id)

func _on_zone_body_exited(body: Node2D, area: Area2D) -> void:
	if body.is_in_group("player"):
		var zone_id: String = area.get_meta("zone_id", "")
		if not zone_id.is_empty():
			EventBus.player_exited_zone.emit(zone_id)


# ==============================
# EventBus 事件处理
# ==============================

func _on_player_entered_zone(zone_id: String) -> void:
	if _chain == null or _chain.status != MissionChain.ChainStatus.RUNNING:
		return

	# 检查当前活跃 Stage 的 LOCATION_REACH 目标
	if _current_stage_index >= 0 and _current_stage_index < _chain.stages.size():
		var stage: MissionStage = _chain.stages[_current_stage_index]
		if stage.status == MissionStage.StageStatus.ACTIVE:
			_eval_location_zone(stage, zone_id)

	# 检查 pending 激活条件的 LOCATION_REACH
	if _pending_activation_index >= 0:
		var pending: MissionStage = _chain.stages[_pending_activation_index]
		if pending.activation_condition != null \
				and pending.activation_condition.trigger_type == TriggerConfig.MissionTriggerType.LOCATION_REACH:
			var target: String = pending.activation_condition.params.get("zone_id", "")
			if zone_id == target:
				# 激活前给一小帧缓冲
				_activate_stage(_pending_activation_index)

func _on_player_exited_zone(zone_id: String) -> void:
	if _chain == null or _chain.status != MissionChain.ChainStatus.RUNNING:
		return
	if _current_stage_index < 0 or _current_stage_index >= _chain.stages.size():
		return

	var stage: MissionStage = _chain.stages[_current_stage_index]
	if stage.status != MissionStage.StageStatus.ACTIVE:
		return

	for obj in stage.objectives:
		if obj.trigger == null or obj.trigger.current_value >= obj.trigger.target_value:
			continue
		if obj.trigger.trigger_type != TriggerConfig.MissionTriggerType.LOCATION_REACH:
			continue
		var mode: String = obj.trigger.params.get("trigger_mode", "enter")
		if mode != "exit":
			continue
		var target: String = obj.trigger.params.get("zone_id", "")
		if zone_id == target:
			obj.trigger.current_value = obj.trigger.target_value
			objective_progressed.emit(
				stage.stage_id, obj.objective_id,
				obj.trigger.current_value, obj.trigger.target_value
			)
			_on_objective_completed(stage, obj)

func _on_enemy_killed_filtered(
	_pos: Vector2, _score: int,
	is_elite: bool, is_boss: bool, is_ranged: bool
) -> void:
	if _chain == null or _chain.status != MissionChain.ChainStatus.RUNNING:
		return
	if _current_stage_index < 0 or _current_stage_index >= _chain.stages.size():
		return

	var stage: MissionStage = _chain.stages[_current_stage_index]
	if stage.status != MissionStage.StageStatus.ACTIVE:
		return

	for obj in stage.objectives:
		if obj.trigger == null or obj.trigger.current_value >= obj.trigger.target_value:
			continue
		if obj.trigger.trigger_type != TriggerConfig.MissionTriggerType.KILL_COUNT:
			continue

		# 检查敌人过滤器
		var filter: String = obj.trigger.params.get("enemy_filter", "any")
		if not _match_enemy_filter(filter, is_elite, is_boss, is_ranged):
			continue

		# 位置过滤器（V1.0 简化：非空时通过参数检查，但不进行空间查询）
		var loc_filter: String = obj.trigger.params.get("location_filter", "")
		if not loc_filter.is_empty():
			# TODO: 实现空间击杀区域追踪
			pass

		obj.trigger.current_value = min(obj.trigger.current_value + 1.0, obj.trigger.target_value)
		objective_progressed.emit(
			stage.stage_id, obj.objective_id,
			obj.trigger.current_value, obj.trigger.target_value
		)
		if obj.trigger.current_value >= obj.trigger.target_value:
			_on_objective_completed(stage, obj)

func _on_player_died(_kc: int = 0) -> void:
	if _chain == null:
		return
	_chain.status = MissionChain.ChainStatus.FAILED
	for stage in _chain.stages:
		if stage.status == MissionStage.StageStatus.ACTIVE:
			stage.status = MissionStage.StageStatus.FAILED
	chain_completed.emit(_chain.chain_id, false)

func _on_game_state_changed(new_state: int, _old_state: int) -> void:
	# PAUSED / MAP / INVENTORY / DIALOGUE / DEAD 时暂停计时
	_is_paused = (new_state != GameState.State.PLAYING)


# ==============================
# Evaluator 函数
# ==============================

## LOCATION_REACH Evaluator — 由事件驱动，此函数仅用于统一接口
func _eval_location(_trigger: TriggerConfig, _delta: float) -> void:
	pass  # 事件驱动，不在 _process 中处理

## KILL_COUNT Evaluator — 由事件驱动
func _eval_kill(_trigger: TriggerConfig, _delta: float) -> void:
	pass  # 事件驱动，不在 _process 中处理

## TIME_SURVIVE Evaluator — 在 _process 中处理
func _eval_time(_trigger: TriggerConfig, _delta: float) -> void:
	pass  # 实际逻辑在 _process 中内联处理

## 预留类型的空函数
func _eval_not_implemented(_trigger: TriggerConfig, _delta: float) -> void:
	push_warning("MissionTriggerManager: trigger type not yet implemented")


# ==============================
# V2.0 Evaluator 函数
# ==============================

## DEFEND_ZONE Evaluator — 在 _process 中逐帧评估
## 玩家在 zone 内时当前值递增，离开时暂停/重置
func _eval_defend_zone(stage: MissionStage, obj: MissionObjective, delta: float) -> void:
	var trigger: TriggerConfig = obj.trigger
	var zone_id: String = trigger.params.get("zone_id", "")
	if zone_id.is_empty():
		return

	var pause_on_exit: bool = trigger.params.get("pause_on_exit", true)
	var reset_on_exit: bool = trigger.params.get("reset_on_exit", false)

	# 查找 zone 并检查玩家是否在其中
	var player_in_zone := false
	for area in _tracked_zone_areas:
		if area.get_meta("zone_id", "") == zone_id:
			for body in area.get_overlapping_bodies():
				if body.is_in_group("player"):
					player_in_zone = true
					break
			break

	if player_in_zone:
		trigger.current_value += delta
	elif reset_on_exit:
		trigger.current_value = 0.0
	# pause_on_exit=true 默认：离开区域不递增也不重置

	# 状态变更信号（仅变化时 emit）
	var prev_active: bool = _defend_zone_states.get(obj.objective_id, false)
	if player_in_zone != prev_active:
		_defend_zone_states[obj.objective_id] = player_in_zone
		EventBus.defend_zone_state_changed.emit(zone_id, player_in_zone)

	objective_progressed.emit(
		stage.stage_id, obj.objective_id,
		trigger.current_value, trigger.target_value
	)
	if trigger.current_value >= trigger.target_value:
		_on_objective_completed(stage, obj)


## PROTECT_OBJECT Evaluator — 在 _process 中逐帧评估
## 保护目标存活且 HP > 阈值时递增计时
func _eval_protect_object(stage: MissionStage, obj: MissionObjective, delta: float) -> void:
	var trigger: TriggerConfig = obj.trigger
	var object_id: String = trigger.params.get("object_id", "")
	if object_id.is_empty():
		return

	var hp_threshold: float = trigger.params.get("target_hp_threshold", 0.0)

	# 标记为已销毁——避免重复处理
	if _protect_object_destroyed.get(object_id, false):
		return

	# 查找匹配的 ProtectableObject
	var protectables: Array[Node] = get_tree().get_nodes_in_group("protectable_object")
	var target_obj: Node = null
	for p in protectables:
		if is_instance_valid(p) and p.has_method("get_object_id") and p.get_object_id() == object_id:
			target_obj = p
			break

	if target_obj == null or not is_instance_valid(target_obj):
		# 对象不存在或已被销毁——快速完成（给 Stage 推进的出口）
		trigger.current_value = trigger.target_value
		_protect_object_destroyed[object_id] = true
		_on_objective_completed(stage, obj)
		return

	# 检查对象是否存活
	var is_alive: bool = target_obj.has_method("is_alive") and target_obj.is_alive()
	if not is_alive:
		trigger.current_value = trigger.target_value
		_protect_object_destroyed[object_id] = true
		_on_objective_completed(stage, obj)
		return

	# 检查 HP 阈值
	var hp_pct: float = target_obj.hp_percent() if target_obj.has_method("hp_percent") else 1.0
	if hp_threshold < 0:
		# -1：目标可以被摧毁但仍持续计时（剧情用）
		trigger.current_value += delta
	elif hp_pct > hp_threshold:
		trigger.current_value += delta
	# else: HP 低于阈值，不递增（等待恢复或任务失败）

	objective_progressed.emit(
		stage.stage_id, obj.objective_id,
		trigger.current_value, trigger.target_value
	)
	if trigger.current_value >= trigger.target_value:
		_on_objective_completed(stage, obj)


## 分发 Objective 完成动作
## 纯数据驱动：根据 completion_action.type 路由到对应的 EventBus 信号
## 当前支持："unlock_door"
func _dispatch_completion_action(obj: MissionObjective) -> void:
	var action: Dictionary = obj.completion_action
	print("MISSION: dispatch action=", action)
	if action.is_empty():
		return
	match action.get("type", ""):
		"unlock_door":
			var door_id: String = action.get("door_id", "")
			if not door_id.is_empty():
				EventBus.door_unlock_requested.emit(door_id)
		_:
			push_warning("MissionTriggerManager: unknown completion_action type: ", action.get("type", ""))


## 保护目标被摧毁时的回调
func _on_protectable_destroyed(object_id: String) -> void:
	_protect_object_destroyed[object_id] = true


# ==============================
# 辅助方法
# ==============================

## 检查 Zone 进入是否匹配某个 LOCATION_REACH Objective
func _eval_location_zone(stage: MissionStage, zone_id: String) -> void:
	for obj in stage.objectives:
		if obj.trigger == null or obj.trigger.current_value >= obj.trigger.target_value:
			continue
		if obj.trigger.trigger_type != TriggerConfig.MissionTriggerType.LOCATION_REACH:
			continue
		var mode: String = obj.trigger.params.get("trigger_mode", "enter")
		if mode == "exit":
			continue
		var target: String = obj.trigger.params.get("zone_id", "")
		if zone_id == target:
			obj.trigger.current_value = obj.trigger.target_value
			objective_progressed.emit(
				stage.stage_id, obj.objective_id,
				obj.trigger.current_value, obj.trigger.target_value
			)
			_on_objective_completed(stage, obj)

## 匹配敌人类型过滤器
func _match_enemy_filter(filter: String, is_elite: bool, is_boss: bool, is_ranged: bool) -> bool:
	match filter:
		"any":
			return true
		"elite":
			return is_elite
		"boss":
			return is_boss
		"ranged":
			return is_ranged
		_:
			return true  # 未知过滤器默认允许

## 清理运行时状态（加载新链前调用）
func _cleanup() -> void:
	# 断开已连接的区域信号
	for area in _tracked_zone_areas:
		if is_instance_valid(area):
			var sigs: Dictionary = _zone_signal_map.get(area, {})
			if sigs.has("entered") and area.body_entered.is_connected(sigs["entered"]):
				area.body_entered.disconnect(sigs["entered"])
			if sigs.has("exited") and area.body_exited.is_connected(sigs["exited"]):
				area.body_exited.disconnect(sigs["exited"])
	_zone_signal_map.clear()
	_tracked_zone_areas.clear()

	# 移除动态创建的 Zone 子节点
	for child in get_children():
		if child is Area2D and child.is_in_group("mission_zone"):
			child.queue_free()

	_survive_timer = 0.0
	_current_stage_index = -1
	_pending_activation_index = -1

# 返回当前激活的防御区域中心坐标（供敌人 AI 使用）
func get_defend_zone_center() -> Vector2:
	if _chain == null or _current_stage_index < 0:
		return Vector2.ZERO
	var stage := _chain.stages[_current_stage_index]
	if stage.status != MissionStage.StageStatus.ACTIVE:
		return Vector2.ZERO
	for obj in stage.objectives:
		if obj.trigger and obj.trigger.trigger_type == TriggerConfig.MissionTriggerType.DEFEND_ZONE:
			var zone_id: String = obj.trigger.params.get("zone_id", "")
			for area in _tracked_zone_areas:
				if area.get_meta("zone_id", "") == zone_id:
					return area.global_position
	return Vector2.ZERO
