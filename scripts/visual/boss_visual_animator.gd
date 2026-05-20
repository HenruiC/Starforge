class_name BossVisualAnimator
extends Node

## Boss 攻击动画/姿态控制器 — TASK-V02 + TASK-V05
##
## 连接 Boss 的技能信号或 EventBus 信号，驱动视觉部件（Body/Arms/Whistle/Aura）
## 在攻击前摇/释放/硬直阶段播放不同的姿态 Tween。
## 同时负责击败坍塌动画（TASK-V05）。
##
## 使用方式：
##   1. 创建实例并 init() 传入视觉部件引用
##   2. 自动连接到 EventBus.boss_attack_started
##   3. 也可手动调用 play_windup/play_release/play_recovery
##   4. 死亡时调用 play_collapse()

# === 颜色常量 ===
const COLOR_BODY_DEFAULT := Color(0.28, 0.20, 0.30, 1.0)
const COLOR_BODY_WINDUP := Color(0.9, 0.55, 0.15, 1.0)   # 橙黄—蓄力警示
const COLOR_BODY_PHASE4 := Color(0.18, 0.12, 0.15, 1.0)   # 暗红近乎黑
const COLOR_BODY_DEATH := Color(0.5, 0.5, 0.5, 0.5)       # 灰白—死亡瞬间
const COLOR_WHISTLE_DEFAULT := Color(0.6, 0.6, 0.65, 1.0)
const COLOR_WHISTLE_WINDUP := Color(1.0, 0.6, 0.35, 1.0)  # 橙红—哨声蓄力

# Tween group 名称
const GROUP_WINDUP := "boss_visual_windup"
const GROUP_RELEASE := "boss_visual_release"
const GROUP_RECOVERY := "boss_visual_recovery"
const GROUP_COLLAPSE := "boss_visual_collapse"
const GROUP_IDLE := "boss_visual_idle"

# === 部件引用 ===
var _body: ColorRect = null
var _whistle: ColorRect = null
var _aura: ColorRect = null
var _arm_l: ColorRect = null
var _arm_r: ColorRect = null
var _core: ColorRect = null
var _hit_flash: ColorRect = null

# === 攻击姿态参数表 — TASK-V02 ===
# 每个攻击定义：前摇/释放/硬直的姿态变化参数
const ATTACK_PARAMS := {
	# ---- 第一乐章：热身 ----
	"M1-A": {  # 示范重击
		"windup_duration": 0.6, "release_duration": 0.1, "recovery_duration": 0.5,
		"windup": {
			"arm_l_rotation": -30.0, "arm_r_rotation": -30.0,
			"body_rotation": -5.0, "body_scale_x": 0.82,
		},
		"release": {
			"arm_l_rotation": 20.0, "arm_r_rotation": 20.0,
			"body_rotation": 3.0, "body_scale_x": 1.08,
			"aura_scale": 1.3,
		},
	},
	"M1-B": {  # 哨声音波
		"windup_duration": 0.6, "release_duration": 0.15, "recovery_duration": 0.4,
		"windup": {
			"whistle_scale": 1.25, "whistle_color_variant": "orange_red",
		},
		"release": {
			"whistle_scale": 1.0, "whistle_color_variant": "default",
		},
	},
	"M1-C": {  # 前滚翻冲撞
		"windup_duration": 0.8, "release_duration": 0.5, "recovery_duration": 0.5,
		"windup": {
			"body_scale_y": 0.5, "body_rotation": -15.0,
			"body_color_variant": "darken",
		},
		"release": {
			"body_scale_x": 1.3, "body_scale_y": 0.7,
		},
	},
	"M1-D": {  # 跳马践踏
		"windup_duration": 1.0, "release_duration": 0.2, "recovery_duration": 0.8,
		"windup": {
			"arm_l_rotation": -60.0, "arm_r_rotation": -60.0,
			"body_rotation": -15.0, "body_scale_y": 0.85,
		},
		"release": {
			"body_scale_y": 0.8, "body_position_y": -15.0,
		},
	},
	# ---- 第二乐章：球类训练 ----
	"M2-A": {  # 抛投直球
		"windup_duration": 0.4, "release_duration": 0.1, "recovery_duration": 0.3,
		"windup": {
			"arm_r_rotation": -45.0, "body_rotation": -3.0,
		},
		"release": {
			"arm_r_rotation": 30.0, "body_rotation": 3.0,
		},
	},
	"M2-B": {  # 抛投高吊
		"windup_duration": 0.5, "release_duration": 0.1, "recovery_duration": 0.3,
		"windup": {
			"arm_r_rotation": -35.0, "body_rotation": -8.0,
			"body_scale_y": 0.9,
		},
		"release": {
			"arm_r_rotation": -60.0, "body_rotation": -3.0,
		},
	},
	"M2-C": {  # 哨声尖啸
		"windup_duration": 0.5, "release_duration": 0.1, "recovery_duration": 0.4,
		"windup": {
			"whistle_flash_count": 2, "body_scale_xy": 1.05,
		},
		"release": {
			"body_scale_xy": 1.0,
		},
	},
	"M2-D": {  # 铁山靠
		"windup_duration": 0.6, "release_duration": 0.15, "recovery_duration": 0.6,
		"windup": {
			"body_rotation": 90.0, "body_color_variant": "metallic",
			"arm_l_rotation": 0.0, "arm_r_rotation": 0.0,
			"body_scale_x": 0.7, "body_scale_y": 1.1,
		},
		"release": {
			"body_rotation": 0.0, "body_color_variant": "metallic_flash",
		},
	},
	"M2-E": {  # 震地波
		"windup_duration": 1.2, "release_duration": 0.1, "recovery_duration": 1.0,
		"windup": {
			"arm_l_rotation": -80.0, "arm_r_rotation": -80.0,
			"body_scale_y": 0.7,
		},
		"release": {
			"arm_l_rotation": 10.0, "arm_r_rotation": 10.0,
			"body_scale_y": 1.15,
		},
	},
	# ---- 第三乐章：集合 ----
	"M3-A": {  # 吹哨集合
		"windup_duration": 1.2, "release_duration": 0.15, "recovery_duration": 0.5,
		"windup": {
			"body_rotation": -10.0, "whistle_pulse_count": 3, "whistle_pulse_interval": 0.08,
		},
		"release": {
			"body_rotation": 0.0,
		},
	},
	"M3-E": {  # 空哨（无人回应）
		"windup_duration": 0.8, "release_duration": 0.3, "recovery_duration": 0.5,
		"windup": {
			"body_rotation": -8.0, "whistle_pulse_count": 2, "whistle_pulse_interval": 0.1,
		},
		"release": {
			"body_rotation": 0.0, "whistle_color_variant": "gray",
		},
	},
	# ---- 第四乐章：毕业考试 ----
	"M4-A": {  # 绝望冲刺
		"windup_duration": 0.4, "release_duration": 0.2, "recovery_duration": 0.5,
		"windup": {
			"body_flash_brighten": 0.1, "body_scale_x": 0.85,
		},
		"release": {
			"body_scale_x": 1.25, "body_scale_y": 0.85,
		},
	},
	"M4-B": {  # 器材雨
		"windup_duration": 1.5, "release_duration": 0.3, "recovery_duration": 2.0,
		"windup": {
			"body_scale_xy": 0.6, "body_rotation": -5.0,
		},
		"release": {
			"body_scale_xy": 1.0, "body_rotation": 0.0,
		},
	},
}

# === 运行时状态 ===
var _current_body_color: Color = COLOR_BODY_DEFAULT
var _current_whistle_color: Color = COLOR_WHISTLE_DEFAULT
var _tween_registry: Dictionary = {}  # {group_name: Array[Tween]}


# =============================================================================
# 初始化
# =============================================================================

## 传入视觉部件的引用
func init(parts: Dictionary) -> void:
	_body = parts.get("body") as ColorRect
	_whistle = parts.get("whistle") as ColorRect
	_aura = parts.get("aura") as ColorRect
	_arm_l = parts.get("arm_l") as ColorRect
	_arm_r = parts.get("arm_r") as ColorRect
	_core = parts.get("core") as ColorRect
	_hit_flash = parts.get("hit_flash") as ColorRect

	# 连入 EventBus 信号
	_connect_signals()


func _connect_signals() -> void:
	if not EventBus.boss_attack_started.is_connected(_on_boss_attack_started):
		EventBus.boss_attack_started.connect(_on_boss_attack_started)


# =============================================================================
# Public API — 攻击动画
# =============================================================================

## 播放攻击前摇动画
func play_windup(attack_id: String, duration_override: float = -1.0) -> void:
	_kill_group(GROUP_WINDUP)

	var params: Dictionary = ATTACK_PARAMS.get(attack_id, {})
	if params.is_empty():
		return

	var wparams: Dictionary = params.get("windup", {})
	if wparams.is_empty():
		return

	var duration: float = duration_override if duration_override > 0.0 else params.get("windup_duration", 0.4)

	# 身体 scale 横向压缩（Phase E 核心要求：蓄力时横向压缩 0.1s + 颜色变为橙黄）
	var body_scale_x: float = wparams.get("body_scale_x", 1.0)
	if body_scale_x != 1.0 and _body:
		var t := _create_registered_tween(GROUP_WINDUP)
		t.tween_property(_body, "scale:x", body_scale_x, minf(duration * 0.3, 0.1))
		t.set_ease(Tween.EASE_OUT)

	# 身体 scale 纵向
	var body_scale_y: float = wparams.get("body_scale_y", 1.0)
	if body_scale_y != 1.0 and _body:
		var t := _create_registered_tween(GROUP_WINDUP)
		t.tween_property(_body, "scale:y", body_scale_y, minf(duration * 0.3, 0.15))
		t.set_ease(Tween.EASE_OUT)

	# 身体整体缩放
	var body_scale_xy: float = wparams.get("body_scale_xy", 0.0)
	if body_scale_xy > 0.0 and _body:
		var target := Vector2(body_scale_xy, body_scale_xy)
		var t := _create_registered_tween(GROUP_WINDUP)
		t.tween_property(_body, "scale", target, minf(duration * 0.5, 0.3))
		t.set_ease(Tween.EASE_OUT)

	# 身体旋转
	var body_rotation: float = wparams.get("body_rotation", 0.0)
	if body_rotation != 0.0 and _body:
		var t := _create_registered_tween(GROUP_WINDUP)
		t.tween_property(_body, "rotation", deg_to_rad(body_rotation), duration * 0.5)
		t.set_ease(Tween.EASE_OUT)

	# 身体颜色渐变到橙黄（Phase E 核心要求）
	var body_color_variant: String = wparams.get("body_color_variant", "")
	var target_body_color: Color = COLOR_BODY_WINDUP
	match body_color_variant:
		"darken":
			target_body_color = Color(0.15, 0.1, 0.15, 1.0)
		"metallic":
			target_body_color = Color(0.5, 0.5, 0.55, 1.0)
		_:
			target_body_color = COLOR_BODY_WINDUP

	if _body:
		var t := _create_registered_tween(GROUP_WINDUP)
		t.tween_property(_body, "color", target_body_color, minf(duration * 0.5, 0.15))
		t.set_ease(Tween.EASE_OUT)

	# 手臂旋转
	var arm_l_rot: float = wparams.get("arm_l_rotation", 0.0)
	if arm_l_rot != 0.0 and _arm_l:
		var t := _create_registered_tween(GROUP_WINDUP)
		t.tween_property(_arm_l, "rotation", deg_to_rad(arm_l_rot), duration * 0.6)
		t.set_ease(Tween.EASE_OUT)

	var arm_r_rot: float = wparams.get("arm_r_rotation", 0.0)
	if arm_r_rot != 0.0 and _arm_r:
		var t := _create_registered_tween(GROUP_WINDUP)
		t.tween_property(_arm_r, "rotation", deg_to_rad(arm_r_rot), duration * 0.6)
		t.set_ease(Tween.EASE_OUT)

	# 口哨脉冲/缩放
	var whistle_scale: float = wparams.get("whistle_scale", 0.0)
	if whistle_scale > 0.0 and _whistle:
		var t := _create_registered_tween(GROUP_WINDUP)
		t.tween_property(_whistle, "scale", Vector2(whistle_scale, whistle_scale), duration * 0.4)
		t.set_ease(Tween.EASE_OUT)

	# 口哨颜色变化
	var whistle_color_variant: String = wparams.get("whistle_color_variant", "")
	if whistle_color_variant != "" and _whistle:
		var w_target: Color
		match whistle_color_variant:
			"orange_red":
				w_target = COLOR_WHISTLE_WINDUP
			"gray":
				w_target = Color(0.4, 0.4, 0.4, 1.0)
			_:
				w_target = COLOR_WHISTLE_DEFAULT
		var t := _create_registered_tween(GROUP_WINDUP)
		t.tween_property(_whistle, "color", w_target, duration * 0.3)
		t.set_ease(Tween.EASE_OUT)

	# 口哨快速闪烁
	var whistle_flash_count: int = wparams.get("whistle_flash_count", 0)
	if whistle_flash_count > 0 and _whistle:
		_play_whistle_flash(whistle_flash_count)

	# 口哨脉冲序列
	var whistle_pulse_count: int = wparams.get("whistle_pulse_count", 0)
	var whistle_pulse_interval: float = wparams.get("whistle_pulse_interval", 0.08)
	if whistle_pulse_count > 0 and _whistle:
		_play_whistle_pulse_sequence(whistle_pulse_count, whistle_pulse_interval)

	# 身体闪烁（亮化）
	var body_flash_brighten: float = wparams.get("body_flash_brighten", 0.0)
	if body_flash_brighten > 0.0 and _body:
		var t := _create_registered_tween(GROUP_WINDUP)
		t.tween_property(_body, "modulate", Color(1.3, 1.3, 1.3, 1.0), body_flash_brighten)
		t.tween_property(_body, "modulate", Color.WHITE, body_flash_brighten * 0.5)
		t.set_ease(Tween.EASE_OUT)


## 播放攻击释放动画（回弹 + 颜色恢复）
func play_release(attack_id: String) -> void:
	_kill_group(GROUP_WINDUP)
	_kill_group(GROUP_RELEASE)

	var params: Dictionary = ATTACK_PARAMS.get(attack_id, {})
	if params.is_empty():
		return

	var rparams: Dictionary = params.get("release", {})
	if rparams.is_empty():
		_restore_idle()
		return

	var duration: float = params.get("release_duration", 0.1)

	# 身体 scale.x 回弹（Phase E 核心：释放时回弹 0.05s）
	var body_scale_x: float = rparams.get("body_scale_x", 1.0)
	if body_scale_x != 1.0 and _body:
		var t := _create_registered_tween(GROUP_RELEASE)
		t.tween_property(_body, "scale:x", body_scale_x, minf(duration, 0.05))
		t.set_ease(Tween.EASE_OUT)
	else:
		# 默认：弹回 1.0
		if _body and _body.scale.x != 1.0:
			var t := _create_registered_tween(GROUP_RELEASE)
			t.tween_property(_body, "scale:x", 1.0, 0.05)
			t.set_ease(Tween.EASE_OUT)

	# 身体 scale.y 恢复
	var body_scale_y: float = rparams.get("body_scale_y", 1.0)
	if body_scale_y != 1.0 and _body:
		var t := _create_registered_tween(GROUP_RELEASE)
		t.tween_property(_body, "scale:y", body_scale_y, duration)
		t.set_ease(Tween.EASE_OUT)

	# 身体整体缩放
	var body_scale_xy: float = rparams.get("body_scale_xy", 0.0)
	if body_scale_xy > 0.0 and _body:
		var t := _create_registered_tween(GROUP_RELEASE)
		t.tween_property(_body, "scale", Vector2(body_scale_xy, body_scale_xy), duration)
		t.set_ease(Tween.EASE_OUT)

	# 身体旋转
	var body_rotation: float = rparams.get("body_rotation", 0.0)
	if body_rotation != 0.0 and _body:
		var t := _create_registered_tween(GROUP_RELEASE)
		t.tween_property(_body, "rotation", deg_to_rad(body_rotation), duration)

	# 身体颜色恢复（Phase E 核心要求）
	if _body:
		var t := _create_registered_tween(GROUP_RELEASE)
		t.tween_property(_body, "color", _current_body_color, 0.05)
		t.set_ease(Tween.EASE_OUT)

	# 手臂旋转（释放姿态）
	var arm_l_rot: float = rparams.get("arm_l_rotation", 0.0)
	if arm_l_rot != 0.0 and _arm_l:
		var t := _create_registered_tween(GROUP_RELEASE)
		t.tween_property(_arm_l, "rotation", deg_to_rad(arm_l_rot), duration)
		t.set_ease(Tween.EASE_OUT)

	var arm_r_rot: float = rparams.get("arm_r_rotation", 0.0)
	if arm_r_rot != 0.0 and _arm_r:
		var t := _create_registered_tween(GROUP_RELEASE)
		t.tween_property(_arm_r, "rotation", deg_to_rad(arm_r_rot), duration)
		t.set_ease(Tween.EASE_OUT)

	# 口哨缩放恢复
	if _whistle:
		var t := _create_registered_tween(GROUP_RELEASE)
		t.tween_property(_whistle, "scale", Vector2.ONE, duration)
		t.set_ease(Tween.EASE_OUT)

	# 口哨颜色恢复
	var whistle_color_variant: String = rparams.get("whistle_color_variant", "")
	if whistle_color_variant != "" and _whistle:
		var w_target: Color
		match whistle_color_variant:
			"default":
				w_target = COLOR_WHISTLE_DEFAULT
			"gray":
				w_target = Color(0.4, 0.4, 0.4, 1.0)
			_:
				w_target = _current_whistle_color
		var t := _create_registered_tween(GROUP_RELEASE)
		t.tween_property(_whistle, "color", w_target, duration)
		t.set_ease(Tween.EASE_OUT)

	# 光环扩张（重击时）
	var aura_scale_val: float = rparams.get("aura_scale", 0.0)
	if aura_scale_val > 0.0 and _aura:
		var t := _create_registered_tween(GROUP_RELEASE)
		t.tween_property(_aura, "scale", Vector2(aura_scale_val, aura_scale_val), duration)
		t.set_ease(Tween.EASE_OUT)


## 播放硬直恢复动画（回到 idle 姿态）
func play_recovery(attack_id: String) -> void:
	_kill_group(GROUP_RELEASE)
	_kill_group(GROUP_RECOVERY)

	var params: Dictionary = ATTACK_PARAMS.get(attack_id, {})
	var duration: float = params.get("recovery_duration", 0.3) if not params.is_empty() else 0.3

	_restore_idle(duration)


# =============================================================================
# Public API — 坍塌动画（TASK-V05）
# =============================================================================

## 播放击败坍塌动画
## 横向拉宽 + 纵向压缩 + 口哨延迟消失 + 光环爆闪熄灭
func play_collapse() -> void:
	_kill_all_groups()

	# t=0.00s: 身体瞬间变灰白（死亡瞬间）
	if _body:
		_body.color = COLOR_BODY_DEATH
		_body.modulate.a = 0.5

	# 双臂下垂
	if _arm_l:
		var t_l := _create_registered_tween(GROUP_COLLAPSE)
		t_l.tween_property(_arm_l, "rotation", deg_to_rad(15.0), 0.3)
		t_l.set_ease(Tween.EASE_IN)
	if _arm_r:
		var t_r := _create_registered_tween(GROUP_COLLAPSE)
		t_r.tween_property(_arm_r, "rotation", deg_to_rad(15.0), 0.3)
		t_r.set_ease(Tween.EASE_IN)

	# t=0.10s: 坍塌开始 — 横向拉宽 + 纵向压缩（0.6s, EASE_IN）
	if _body:
		var t := _create_registered_tween(GROUP_COLLAPSE)
		t.set_parallel(true)
		t.tween_property(_body, "scale:x", 1.8, 0.6).set_ease(Tween.EASE_IN).set_delay(0.1)
		t.tween_property(_body, "scale:y", 0.3, 0.6).set_ease(Tween.EASE_IN).set_delay(0.1)
		t.tween_property(_body, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN).set_delay(0.1)

	# 手臂也塌下去
	if _arm_l:
		var t := _create_registered_tween(GROUP_COLLAPSE)
		t.set_parallel(true)
		t.tween_property(_arm_l, "scale:x", 1.3, 0.6).set_ease(Tween.EASE_IN).set_delay(0.1)
		t.tween_property(_arm_l, "scale:y", 0.3, 0.6).set_ease(Tween.EASE_IN).set_delay(0.1)
		t.tween_property(_arm_l, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN).set_delay(0.1)
	if _arm_r:
		var t := _create_registered_tween(GROUP_COLLAPSE)
		t.set_parallel(true)
		t.tween_property(_arm_r, "scale:x", 1.3, 0.6).set_ease(Tween.EASE_IN).set_delay(0.1)
		t.tween_property(_arm_r, "scale:y", 0.3, 0.6).set_ease(Tween.EASE_IN).set_delay(0.1)
		t.tween_property(_arm_r, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN).set_delay(0.1)

	# 光环爆闪后熄灭
	if _aura:
		var t := _create_registered_tween(GROUP_COLLAPSE)
		t.set_parallel(true)
		# 先爆闪（alpha 瞬间提升）
		t.tween_property(_aura, "modulate:a", 0.8, 0.05).set_delay(0.1)
		t.tween_property(_aura, "modulate:a", 0.0, 0.5).set_delay(0.15).set_ease(Tween.EASE_IN)
		t.tween_property(_aura, "scale", Vector2(1.5, 1.5), 0.5).set_delay(0.1).set_ease(Tween.EASE_IN)

	# t=0.40s: 口哨延迟 0.2s 后消失（比主体慢）
	if _whistle:
		var t := _create_registered_tween(GROUP_COLLAPSE)
		t.set_parallel(true)
		t.tween_property(_whistle, "modulate:a", 0.0, 0.6).set_delay(0.4).set_ease(Tween.EASE_IN)
		t.tween_property(_whistle, "scale", Vector2(0.8, 0.8), 0.6).set_delay(0.4).set_ease(Tween.EASE_IN)

	# 核心弱点隐藏
	if _core:
		var t := _create_registered_tween(GROUP_COLLAPSE)
		t.tween_property(_core, "modulate:a", 0.0, 0.3)
		t.tween_callback(func(): _core.visible = false)


# =============================================================================
# Public API — 阶段转换辅助
# =============================================================================

## 设置第四乐章暗色身体
func set_phase4_body() -> void:
	_current_body_color = COLOR_BODY_PHASE4
	if _body:
		var t := _create_registered_tween(GROUP_RECOVERY)
		t.tween_property(_body, "color", COLOR_BODY_PHASE4, 0.3)
		t.set_ease(Tween.EASE_OUT)


## 身体颤抖动画（第三→第四乐章过渡）
func play_body_tremble(duration: float = 0.3) -> void:
	if not _body:
		return
	var orig_pos := _body.position
	var t := _create_registered_tween(GROUP_IDLE)
	for i in 6:
		var offset_x: float = 3.0 if i % 2 == 0 else -3.0
		t.tween_property(_body, "position:x", orig_pos.x + offset_x, 0.05)
	t.tween_property(_body, "position:x", orig_pos.x, 0.05)


## 暴露核心弱点（第四乐章）
func reveal_core() -> void:
	if not _core:
		return
	_core.visible = true
	var t := _create_registered_tween(GROUP_IDLE)
	t.tween_property(_core, "color:a", 0.9, 0.3)
	t.set_ease(Tween.EASE_OUT)


# =============================================================================
# Internal — Idle 恢复
# =============================================================================

func _restore_idle(duration: float = 0.3) -> void:
	_kill_group(GROUP_RECOVERY)

	var t := _create_registered_tween(GROUP_RECOVERY)
	t.set_parallel(true)

	# 身体恢复到默认
	if _body:
		t.tween_property(_body, "scale", Vector2.ONE, duration).set_ease(Tween.EASE_OUT)
		t.tween_property(_body, "rotation", 0.0, duration).set_ease(Tween.EASE_OUT)
		t.tween_property(_body, "color", _current_body_color, duration).set_ease(Tween.EASE_OUT)
		t.tween_property(_body, "modulate", Color.WHITE, duration).set_ease(Tween.EASE_OUT)

	# 手臂归位
	if _arm_l:
		t.tween_property(_arm_l, "rotation", 0.0, duration).set_ease(Tween.EASE_OUT)
		t.tween_property(_arm_l, "scale", Vector2.ONE, duration).set_ease(Tween.EASE_OUT)
	if _arm_r:
		t.tween_property(_arm_r, "rotation", 0.0, duration).set_ease(Tween.EASE_OUT)
		t.tween_property(_arm_r, "scale", Vector2.ONE, duration).set_ease(Tween.EASE_OUT)

	# 口哨恢复
	if _whistle:
		t.tween_property(_whistle, "scale", Vector2.ONE, duration).set_ease(Tween.EASE_OUT)
		t.tween_property(_whistle, "color", _current_whistle_color, duration).set_ease(Tween.EASE_OUT)

	# 光环恢复
	if _aura:
		t.tween_property(_aura, "scale", Vector2.ONE, duration).set_ease(Tween.EASE_OUT)


# =============================================================================
# Internal — 哨声特效
# =============================================================================

func _play_whistle_flash(count: int) -> void:
	if not _whistle:
		return
	var t := _create_registered_tween(GROUP_WINDUP)
	for _i in count:
		t.tween_property(_whistle, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.05)
		t.tween_property(_whistle, "modulate", Color.WHITE, 0.05)


func _play_whistle_pulse_sequence(count: int, interval: float) -> void:
	if not _whistle:
		return
	var t := _create_registered_tween(GROUP_WINDUP)
	for _i in count:
		t.tween_property(_whistle, "scale", Vector2(1.2, 1.2), interval)
		t.tween_property(_whistle, "scale", Vector2.ONE, interval)


# =============================================================================
# Internal — Tween 管理
# =============================================================================

func _create_registered_tween(group_name: String) -> Tween:
	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	if not _tween_registry.has(group_name):
		_tween_registry[group_name] = []
	var arr: Array = _tween_registry[group_name]
	arr.append(t)
	return t


func _kill_group(group_name: String) -> void:
	var arr: Array = _tween_registry.get(group_name, [])
	if arr.is_empty():
		return
	var i: int = arr.size() - 1
	while i >= 0:
		var tw: Tween = arr[i]
		if is_instance_valid(tw) and tw.is_running():
			tw.kill()
		arr.remove_at(i)
		i -= 1


func _kill_all_groups() -> void:
	for group_name in _tween_registry.keys():
		var arr: Array = _tween_registry[group_name]
		var i: int = arr.size() - 1
		while i >= 0:
			var tw: Tween = arr[i]
			if is_instance_valid(tw) and tw.is_running():
				tw.kill()
			arr.remove_at(i)
			i -= 1
	_tween_registry.clear()


# =============================================================================
# Signal Handlers
# =============================================================================

func _on_boss_attack_started(attack_id: String, windup_duration: float) -> void:
	play_windup(attack_id, windup_duration)
