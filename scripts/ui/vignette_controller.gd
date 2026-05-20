class_name VignetteController
extends Node

## Vignette 暗角效果控制器 — TASK-I06
##
## 管理屏幕边缘的径向渐变暗角，在 Boss 战不同阶段动态变化。
##
## 四种状态：
##   NORMAL        — alpha 0.0，常规游戏
##   BOSS_APPROACH — alpha 0.3，玩家接近 Boss 区域（15s 渐变）
##   BOSS_BATTLE   — alpha 0.6，Boss 战中（0.5s 渐变）
##   BOSS_DEFEAT   — alpha 0.0，Boss 战后消退（2s 渐变）
##
## 使用方式：
##   1. 挂到 HUDLayer 下
##   2. 调用 set_state(VignetteController.State.BOSS_BATTLE) 切换状态
##   3. 自动创建并管理暗角 TextureRect

enum State {
	NORMAL = 0,        # 常规游戏，无暗角
	BOSS_APPROACH = 1, # 接近 Boss 区域，轻微暗角
	BOSS_BATTLE = 2,   # Boss 战中，明显暗角
	BOSS_DEFEAT = 3    # Boss 战后消退
}

# 各状态的目标 alpha
const ALPHA_NORMAL: float = 0.0
const ALPHA_APPROACH: float = 0.3
const ALPHA_BATTLE: float = 0.6
const ALPHA_DEFEAT: float = 0.0

# 各状态的默认渐变时长
const DURATION_NORMAL: float = 2.0
const DURATION_APPROACH: float = 15.0
const DURATION_BATTLE: float = 0.5
const DURATION_DEFEAT: float = 2.0

# 暗角颜色 - 极暗红黑（不是纯黑，带体育馆的气味）
const VIGNETTE_COLOR: Color = Color(0.05, 0.02, 0.02, 0.6)

var _overlay: TextureRect
var _current_state: int = State.NORMAL


func _ready() -> void:
	name = "VignetteController"
	_build_overlay()


func _build_overlay() -> void:
	_overlay = TextureRect.new()
	_overlay.name = "VignetteOverlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_overlay.modulate = Color(1, 1, 1, 0)  # 初始完全透明
	_overlay.z_index = 8
	_overlay.stretch_mode = TextureRect.STRETCH_SCALE

	# 创建径向渐变：中心透明 → 边缘暗红黑
	var grad := Gradient.new()
	# 渐变点：中心(alpha 0) → 边缘(alpha 1.0)
	# 使用 modulate.a 控制整体强度
	grad.colors = [
		Color(0.05, 0.02, 0.02, 0.0),    # 中心完全透明
		Color(0.05, 0.02, 0.02, 1.0)     # 边缘完全强度（由 modulate.a 缩放）
	]

	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)     # 渐变起始点：中心
	gt.fill_to = Vector2(0.5, 0.5)       # 渐变结束点：中心（均匀径向）
	gt.width = 1
	gt.height = 1

	_overlay.texture = gt

	# 添加到父节点（HUDLayer）
	get_parent().add_child.call_deferred(_overlay)


## 切换到指定状态
## [param new_state] State 枚举值
## [param custom_duration] 可选的自定义渐变时长，-1 使用默认值
func set_state(new_state: int, custom_duration: float = -1.0) -> void:
	_current_state = new_state

	var target_alpha: float
	var transition_duration: float

	match new_state:
		State.NORMAL:
			target_alpha = ALPHA_NORMAL
			transition_duration = DURATION_NORMAL if custom_duration < 0.0 else custom_duration
		State.BOSS_APPROACH:
			target_alpha = ALPHA_APPROACH
			transition_duration = DURATION_APPROACH if custom_duration < 0.0 else custom_duration
		State.BOSS_BATTLE:
			target_alpha = ALPHA_BATTLE
			transition_duration = DURATION_BATTLE if custom_duration < 0.0 else custom_duration
		State.BOSS_DEFEAT:
			target_alpha = ALPHA_DEFEAT
			transition_duration = DURATION_DEFEAT if custom_duration < 0.0 else custom_duration
		_:
			return

	# kill 进行中的暗角渐变
	UIEffects.kill_group("hud_vignette")

	var t: Tween = _overlay.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(_overlay, "modulate:a", target_alpha, transition_duration)
	UIEffects._register_tween("hud_vignette", t)


## 获取当前状态
func get_current_state() -> int:
	return _current_state


## 强制设置 alpha（无动画，用于初始化/重置）
func set_alpha_instant(alpha: float) -> void:
	UIEffects.kill_group("hud_vignette")
	_overlay.modulate.a = alpha
