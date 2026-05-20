class_name BossPhaseController
extends Node

## Boss 乐章控制器 — 管理四乐章状态转换
##
## 挂载在 Boss CombatUnit 下，通过 HP 阈值触发阶段转换。
## 每乐章包含移速/防御/光环/技能槽/召唤参数等配置。
## 阶段转换时向 EventBus 广播 boss_phase_changed 信号。
##
## 生命周期：
##   1. init(phases_data) 传入四乐章配置数组
##   2. 外部每帧调用 check_transition(hp_ratio) 检测跨阶段
##   3. HP 降至阈值时触发 _do_transition() 演出
##   4. AI 通过 get_current_phase_data() 获取当前乐章参数

# --------------------------------------------------------------------------
# 信号
# --------------------------------------------------------------------------

## 乐章即将转换（from_index to_index），演出开始前发出
signal phase_transition_started(from_index: int, to_index: int)
## 乐章转换完成，演出结束
signal phase_transition_finished(new_index: int)

# --------------------------------------------------------------------------
# 运行时状态
# --------------------------------------------------------------------------

## 当前乐章索引（0-3。 -1 = 未初始化，-2 = defeat 序列中）
var current_phase: int = -1
## 配置数据数组
var _phases: Array[BossPhaseData] = []
## 是否正在转换演出中（AI 和技能应在此期间暂停）
var is_transitioning: bool = false
## 上次检测时的 HP 比例
var _last_hp_ratio: float = 1.0
## 是否已初始化
var _initialized: bool = false

# --------------------------------------------------------------------------
# 初始化
# --------------------------------------------------------------------------

## 传入四乐章配置数组（按顺序，索引 0-3）
func init_phases(phases: Array[BossPhaseData]) -> void:
	_phases = phases
	current_phase = 0
	_last_hp_ratio = 1.0
	_initialized = true

# --------------------------------------------------------------------------
# 每帧检测
# --------------------------------------------------------------------------

func _process(_delta: float) -> void:
	# 空壳 — check_transition 由外部在 HP 变化时调用
	pass

## 检查是否需要转换乐章。返回 true 表示发生了转换。
## hp_ratio: 当前 HP 比例 [0.0, 1.0]
func check_transition(hp_ratio: float) -> bool:
	if not _initialized or is_transitioning:
		return false
	if current_phase < 0 or current_phase >= _phases.size() - 1:
		return false

	var next_phase_idx: int = current_phase + 1
	if next_phase_idx >= _phases.size():
		return false

	var next_phase: BossPhaseData = _phases[next_phase_idx]
	if hp_ratio <= next_phase.health_threshold and _last_hp_ratio > next_phase.health_threshold:
		_do_transition(next_phase_idx)
		return true
	return false

## 获取当前乐章配置
func get_current_phase_data() -> BossPhaseData:
	if current_phase >= 0 and current_phase < _phases.size():
		return _phases[current_phase]
	return null

## 直接进入指定乐章（用于初始化或调试）
func force_enter_phase(phase_index: int) -> void:
	if phase_index < 0 or phase_index >= _phases.size():
		return
	current_phase = phase_index
	if _phases[phase_index]:
		_last_hp_ratio = _phases[phase_index].health_threshold

# --------------------------------------------------------------------------
# 内部：转换流程
# --------------------------------------------------------------------------

func _do_transition(to_idx: int) -> void:
	var from_idx: int = current_phase
	var to_data: BossPhaseData = _phases[to_idx]

	is_transitioning = true
	phase_transition_started.emit(from_idx, to_idx)

	# 转阶段演出 — 通知外部系统
	EventBus.boss_phase_changed.emit(to_idx + 1, to_data.phase_name)

	# 等待演出时长（视觉层在此期间处理后撤+光环变色）
	await get_tree().create_timer(to_data.transition_duration).timeout

	current_phase = to_idx
	is_transitioning = false
	_last_hp_ratio = to_data.health_threshold
	phase_transition_finished.emit(to_idx)

## 终结序列 — Boss 死亡时调用
func trigger_defeat_sequence() -> void:
	is_transitioning = true
	current_phase = -2
	EventBus.boss_phase_changed.emit(-1, "defeated")

## Boss HP 变化时的外部通知（由 BossAI 或 enemy 连接）
func on_health_changed(current_hp: int, max_hp: int) -> void:
	if max_hp <= 0:
		return
	var ratio: float = float(current_hp) / float(max_hp)
	# 更新 last 用于下一帧检测穿越
	check_transition(ratio)
	_last_hp_ratio = ratio
