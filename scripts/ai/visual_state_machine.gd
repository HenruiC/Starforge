class_name EnemyVisualStateMachine
extends Node

## 敌人视觉状态机 — 管理 ColorRect 颜色/scale 变化
##
## 独立于 AIBehaviorController，负责"怎么显示"而非"做什么"。
## 采用栈模型：高优先级状态覆盖低优先级外观。

# --------------------------------------------------------------------------
# 视觉状态枚举
# --------------------------------------------------------------------------

enum VisualState {
	NORMAL,     # 默认外观
	WINDUP,     # 攻击蓄力中（橙黄渐变）
	ACTIVE,     # 伤害帧（白色闪光）
	RECOVERY,   # 攻击后硬直（颜色恢复）
	STUNNED,    # 被控/冻结（蓝色）
	LOW_HP,     # 低血量警示
	BERSERK,    # 狂暴（红色脉冲）
	STEALTH,    # 潜伏（alpha 降低）
	DEAD,       # 死亡（颜色变灰 + 缩放出局）
}

# --------------------------------------------------------------------------
# 颜色常量表（宫崎英高 2.5 节颜色语义系统）
# --------------------------------------------------------------------------

## 每个视觉状态的配置：目标颜色 / 过渡时长 / 附加效果
const STATE_CONFIG := {
	VisualState.NORMAL:   {"color": Color(1.0, 1.0, 1.0, 1.0), "time": 0.0},
	VisualState.WINDUP:   {"color": Color(1.0, 0.55, 0.0, 1.0), "time": -1.0},
	VisualState.ACTIVE:   {"color": Color(1.0, 1.0, 1.0, 1.0), "time": 0.0},
	VisualState.RECOVERY: {"color": Color(1.0, 1.0, 1.0, 1.0), "time": -1.0},
	VisualState.STUNNED:  {"color": Color(0.27, 0.53, 1.0, 1.0), "time": 0.1},
	VisualState.LOW_HP:   {"color": Color(0.7, 0.2, 0.2, 0.7), "time": 0.3},
	VisualState.BERSERK:  {"color": Color(1.0, 0.13, 0.13, 1.0), "time": 0.2},
	VisualState.STEALTH:  {"color": Color(1.0, 1.0, 1.0, 0.35), "time": 0.3},
	VisualState.DEAD:     {"color": Color(0.5, 0.5, 0.5, 0.0), "time": 0.3},
}

## 状态优先级（数值越高优先级越高）
const STATE_PRIORITY := {
	VisualState.NORMAL:   0,
	VisualState.STEALTH:  1,
	VisualState.RECOVERY: 2,
	VisualState.LOW_HP:   3,
	VisualState.BERSERK:  4,
	VisualState.WINDUP:   5,
	VisualState.ACTIVE:   6,
	VisualState.STUNNED:  7,
	VisualState.DEAD:     8,
}

# --------------------------------------------------------------------------
# 引用
# --------------------------------------------------------------------------

## 主视觉 ColorRect
var _sprite: ColorRect = null
## 光环 ColorRect（精英/Boss 的发光层）
var _glow: ColorRect = null

# --------------------------------------------------------------------------
# 状态栈
# --------------------------------------------------------------------------

## 当前状态栈（栈顶 = 最高优先级）
var _state_stack: Array[int] = []
## 活跃的 Tween 列表（用于清理）
var _pending_tweens: Array[Tween] = []
## 脉冲 Tween（STEALTH/BERSERK 等循环效果）
var _pulse_tween: Tween = null

# --------------------------------------------------------------------------
# 默认基础颜色（由 EnemyVisualFactory 或 enemy.gd 设置）
# --------------------------------------------------------------------------

var _base_color: Color = Color(0.9, 0.25, 0.2, 1.0)

# --------------------------------------------------------------------------
# 初始化
# --------------------------------------------------------------------------

## 设置引用的 ColorRect 节点
func setup(sprite: ColorRect, glow: ColorRect = null) -> void:
	_sprite = sprite
	_glow = glow
	_base_color = sprite.color if sprite else _base_color
	_push_state(VisualState.NORMAL)

## 设置基础颜色（在工厂创建后调用）
func set_base_color(color: Color) -> void:
	_base_color = color
	if _state_stack.is_empty():
		_apply_state(VisualState.NORMAL)

# --------------------------------------------------------------------------
# 公开接口
# --------------------------------------------------------------------------

## 推入视觉状态（自动处理优先级）
func push_state(state: int, auto_pop_duration: float = -1.0) -> void:
	_push_state(state)
	if auto_pop_duration > 0.0:
		# 自动弹出（ACTIVE 帧等短暂状态）
		get_tree().create_timer(auto_pop_duration).timeout.connect(
			func(): pop_state(state), CONNECT_ONE_SHOT
		)

## 弹出指定视觉状态
func pop_state(state: int) -> void:
	var idx := _state_stack.rfind(state)
	if idx >= 0:
		_state_stack.remove_at(idx)
	_apply_top_state()

## 清除到指定状态（移除栈中所有高于 priority 的状态）
func clear_above(priority: int) -> void:
	var i := _state_stack.size() - 1
	while i >= 0:
		if STATE_PRIORITY.get(_state_stack[i], 0) > priority:
			_state_stack.remove_at(i)
		i -= 1
	_apply_top_state()

## 恢复到 NORMAL 状态（清除整个栈）
func clear_to_normal() -> void:
	_state_stack.clear()
	_push_state(VisualState.NORMAL)

## 获取当前最高优先级状态
func get_current_state() -> int:
	if _state_stack.is_empty():
		return VisualState.NORMAL
	return _state_stack.back()

## 是否为 NORMAL 状态
func is_normal() -> bool:
	return get_current_state() == VisualState.NORMAL

# --------------------------------------------------------------------------
# 内部栈管理
# --------------------------------------------------------------------------

func _push_state(state: int) -> void:
	# 去重：如果栈顶已经是此状态，不重复推入
	if not _state_stack.is_empty() and _state_stack.back() == state:
		return

	_state_stack.append(state)
	_apply_state(state)

func _apply_top_state() -> void:
	if _state_stack.is_empty():
		_apply_state(VisualState.NORMAL)
	else:
		_apply_state(_state_stack.back())

func _apply_state(state: int) -> void:
	# 停止所有正在进行的颜色 Tween
	_kill_pending_tweens()
	_stop_pulse()

	var cfg: Dictionary = STATE_CONFIG.get(state, STATE_CONFIG[VisualState.NORMAL])

	# 如果状态使用"基色 * 颜色乘数"（WINDUP、RECOVERY 等），需要合成
	var target_color: Color = cfg["color"]
	var duration: float = cfg["time"]

	match state:
		VisualState.NORMAL:
			target_color = _base_color
			duration = 0.2
			_apply_color_tween(target_color, duration)
		VisualState.WINDUP:
			# 基础颜色渐变到橙黄，过渡时长由外部攻击前摇决定
			if duration < 0.0:
				duration = 0.35  # 默认前摇时长
			_apply_color_tween(target_color, duration)
			_apply_windup_scale()
			return
		VisualState.ACTIVE:
			target_color = Color.WHITE
			duration = 0.0  # 瞬间切换
			_apply_color_instant(target_color)
			return
		VisualState.RECOVERY:
			# 从当前颜色渐回基础色
			target_color = _base_color
			if duration < 0.0:
				duration = 0.2  # 默认硬直时长
			_apply_color_tween(target_color, duration)
			return
		VisualState.STUNNED:
			_apply_color_tween(target_color, duration)
			_start_stunned_pulse()
			return
		VisualState.BERSERK:
			_apply_color_tween(target_color, duration)
			_start_berserk_pulse()
			_start_berserk_shake()
			return
		VisualState.STEALTH:
			_apply_color_tween(target_color, duration)
			_start_stealth_pulse()
			return
		VisualState.DEAD:
			_apply_color_tween(target_color, duration)
			_apply_dead_scale()
			return
		VisualState.LOW_HP:
			_apply_color_tween(target_color, duration)
			return
		_:
			_apply_color_tween(target_color, duration)

# --------------------------------------------------------------------------
# 颜色应用
# --------------------------------------------------------------------------

func _apply_color_instant(color: Color) -> void:
	if _sprite:
		_sprite.modulate = color

func _apply_color_tween(target: Color, duration: float) -> void:
	if not _sprite:
		return
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", target, duration)
	_pending_tweens.append(tw)

# --------------------------------------------------------------------------
# 特殊效果
# --------------------------------------------------------------------------

func _apply_windup_scale() -> void:
	# 前摇时身体后仰（scale.y 压缩）并回弹到正常
	if not _sprite:
		return
	var orig_scale := _sprite.scale
	var compressed_scale := Vector2(orig_scale.x * 1.05, orig_scale.y * 0.85)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_sprite, "scale", compressed_scale, 0.2)
	tw.tween_property(_sprite, "scale", orig_scale, 0.2).set_delay(0.2)
	_pending_tweens.append(tw)

func _apply_dead_scale() -> void:
	if not _sprite:
		return
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", _sprite.scale * 1.3, 0.3)
	_pending_tweens.append(tw)

func _start_stunned_pulse() -> void:
	# 蓝色 + alpha 脉冲
	if not _sprite:
		return
	_pulse_tween = create_tween().set_loops(0)
	_pulse_tween.tween_property(_sprite, "modulate:a", 0.5, 0.3)
	_pulse_tween.tween_property(_sprite, "modulate:a", 1.0, 0.3)

func _start_berserk_pulse() -> void:
	if not _sprite:
		return
	_pulse_tween = create_tween().set_loops(0)
	_pulse_tween.tween_property(_sprite, "modulate:a", 0.6, 0.25)
	_pulse_tween.tween_property(_sprite, "modulate:a", 1.0, 0.25)
	# 光环放大
	if _glow:
		var gt := create_tween().set_loops(0)
		gt.tween_property(_glow, "scale", Vector2(1.3, 1.3), 0.25)
		gt.tween_property(_glow, "scale", Vector2(1.0, 1.0), 0.25)

func _start_berserk_shake() -> void:
	## body micro-shake, 2-3px random offset for rage visual
	if not _sprite:
		return
	var orig_x := _sprite.position.x
	var shake_tween := create_tween().set_loops(0)
	shake_tween.tween_property(_sprite, "position:x", orig_x + 2.0, 0.05)
	shake_tween.tween_property(_sprite, "position:x", orig_x - 2.0, 0.05)
	shake_tween.tween_property(_sprite, "position:x", orig_x + 1.0, 0.05)
	shake_tween.tween_property(_sprite, "position:x", orig_x, 0.05)

func _start_stealth_pulse() -> void:
	if not _sprite:
		return
	_pulse_tween = create_tween().set_loops(0)
	_pulse_tween.tween_property(_sprite, "modulate:a", 0.3, 1.5)
	_pulse_tween.tween_property(_sprite, "modulate:a", 0.4, 1.5)

# --------------------------------------------------------------------------
# 清理
# --------------------------------------------------------------------------

func _stop_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null

func _kill_pending_tweens() -> void:
	for tw in _pending_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_pending_tweens.clear()

# --------------------------------------------------------------------------
# AIBehaviorController 信号对接
# --------------------------------------------------------------------------

## 由外部连接：ai_controller.behavior_changed.connect(_on_behavior_changed)
func _on_behavior_changed(_old_state: int, new_state: int) -> void:
	pass
	# 行为变化本身不直接驱动视觉状态（视觉由攻击阶段变化驱动）

## 由外部连接：ai_controller.attack_phase_changed.connect(_on_attack_phase_changed)
func _on_attack_phase_changed(phase: String) -> void:
	match phase:
		"windup":
			clear_above(STATE_PRIORITY[VisualState.WINDUP] - 1)
			push_state(VisualState.WINDUP)
		"active":
			pop_state(VisualState.WINDUP)
			push_state(VisualState.ACTIVE, 0.05)  # 自动弹出
		"recovery":
			push_state(VisualState.RECOVERY)
		"idle":
			pop_state(VisualState.RECOVERY)
			clear_to_normal()

## 由外部连接：受击时调用
func _on_hit() -> void:
	push_state(VisualState.ACTIVE, 0.05)

## 由外部连接：被冻结时调用
func _on_stunned(enabled: bool) -> void:
	if enabled:
		push_state(VisualState.STUNNED)
	else:
		pop_state(VisualState.STUNNED)

## 由外部连接：低血量时调用
func _on_low_hp(enabled: bool) -> void:
	if enabled:
		push_state(VisualState.LOW_HP)
	else:
		pop_state(VisualState.LOW_HP)

## 由外部连接：死亡时调用
func _on_dead() -> void:
	clear_to_normal()
	push_state(VisualState.DEAD)
