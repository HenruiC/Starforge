class_name SilenceController
extends Node

## 沉默时刻 HUD 消退/恢复控制器
## TASK-I01: Boss 出场前 HUD 阶梯消退，战斗开始后逆序恢复
##
## 使用方式：
##   1. GameManager 创建此控制器，挂到 HUDLayer 下
##   2. 调用 register_element() 注册所有 HUD 元素，指定消退/恢复优先级
##   3. 在 boss_phase_changed 信号触发时自动消退/恢复
##   4. 也可手动调用 trigger_silence() / trigger_restore()
##
## 消退优先级（0=最先消退，4=最后消退）：
##   0: 任务目标文字、外围标签
##   1: 波次标签
##   2: 计时器
##   3: 击杀数
##   4: (预留) HP 条等核心数值
##
## 恢复优先级（0=最先恢复，4=最后恢复）：
##   0: (预留) 核心数值
##   1: 击杀数
##   2: 计时器
##   3: 波次标签
##   4: 任务目标等外围标签

# 消退 stagger 间隔（秒）
var silence_out_interval: float = 0.25
# 恢复 stagger 间隔（秒）
var silence_in_interval: float = 0.08
# 消退淡出时长
var fade_out_duration: float = 0.5
# 恢复淡入时长
var fade_in_duration: float = 0.3

# 分层注册表: _fade_out_layers[priority] = [Control, ...]
var _fade_out_layers: Array[Array] = []
# 分层注册表: _fade_in_layers[priority] = [Control, ...]
var _fade_in_layers: Array[Array] = []

# 是否正在沉默状态
var _is_silent: bool = false

func _ready() -> void:
	name = "SilenceController"
	EventBus.boss_phase_changed.connect(_on_boss_phase_changed)
	# 也监听 boss_defeated 确保战后恢复
	EventBus.boss_defeated.connect(_on_boss_defeated)


## 注册 HUD 元素
## [param ctrl] 要控制的 Control 节点
## [param out_layer] 消退优先级（0=最先消退）
## [param in_layer] 恢复优先级（0=最先恢复）
func register_element(ctrl: Control, out_layer: int, in_layer: int) -> void:
	# 确保数组足够大
	while _fade_out_layers.size() <= out_layer:
		_fade_out_layers.append([])
	while _fade_in_layers.size() <= in_layer:
		_fade_in_layers.append([])

	_fade_out_layers[out_layer].append(ctrl)
	_fade_in_layers[in_layer].append(ctrl)


## 手动触发沉默消退
func trigger_silence() -> void:
	if _is_silent:
		return
	_is_silent = true

	# 1. kill 所有进行中的常规 HUD Tween groups
	UIEffects.kill_group("hud_killcount")
	UIEffects.kill_group("hud_wave")
	UIEffects.kill_group("hud_timer")
	UIEffects.kill_group("hud_mission")
	UIEffects.kill_group("hud_cooldown")
	UIEffects.kill_group("hud_exp")
	UIEffects.kill_group("hud_silence")

	# 2. 按层阶梯消退
	# 每层内的元素并行消退，层间间隔 silence_out_interval
	for layer_idx in range(_fade_out_layers.size()):
		var layer: Array = _fade_out_layers[layer_idx]
		for ctrl in layer:
			if not is_instance_valid(ctrl):
				continue
			# 确保初始 alpha 为当前值，防止中断时跳变
			var start_alpha: float = ctrl.modulate.a
			var t: Tween = ctrl.create_tween()
			t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
			t.tween_property(ctrl, "modulate:a", 0.0, fade_out_duration * start_alpha) \
				.set_delay(layer_idx * silence_out_interval) \
				.set_ease(Tween.EASE_OUT)
			UIEffects._register_tween("hud_silence", t)


## 手动触发恢复
func trigger_restore() -> void:
	if not _is_silent:
		return
	_is_silent = false

	UIEffects.kill_group("hud_silence")

	# 逆序恢复：核心数值先回来
	for layer_idx in range(_fade_in_layers.size()):
		var layer: Array = _fade_in_layers[layer_idx]
		for ctrl in layer:
			if not is_instance_valid(ctrl):
				continue
			var t: Tween = ctrl.create_tween()
			t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
			t.tween_property(ctrl, "modulate:a", 1.0, fade_in_duration) \
				.set_delay(layer_idx * silence_in_interval) \
				.set_ease(Tween.EASE_OUT)
			UIEffects._register_tween("hud_silence", t)


## 强制重置所有元素到可见状态（用于出错恢复）
func force_restore() -> void:
	_is_silent = false
	UIEffects.kill_group("hud_silence")

	for layer in _fade_out_layers:
		for ctrl in layer:
			if is_instance_valid(ctrl):
				ctrl.modulate.a = 1.0

	for layer in _fade_in_layers:
		for ctrl in layer:
			if is_instance_valid(ctrl):
				ctrl.modulate.a = 1.0


# ---- 信号响应 ----

func _on_boss_phase_changed(phase: int, _phase_name: String) -> void:
	match phase:
		0:
			# phase 0 = 沉默结束，战斗开始 → 恢复 HUD
			trigger_restore()
		1:
			# phase 1 = 沉默时刻开始 → 消退 HUD
			trigger_silence()
		_:
			# 其他阶段：确保 HUD 可见
			trigger_restore()


func _on_boss_defeated() -> void:
	# Boss 战后确保 HUD 完全恢复
	force_restore()
