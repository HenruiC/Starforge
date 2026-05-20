class_name BossAuraController
extends Node

## Boss 光环四乐章控制器 — TASK-V03
##
## 管理光环颜色切换、呼吸脉冲、大型脉冲、碎裂演出。
## 四个乐章的光环颜色和脉冲节奏完全不同。
##
## 使用方式：
##   1. 创建实例并 init(a_aura_ref)
##   2. 调用 set_phase(1-4) 切换乐章
##   3. 自动连接到 EventBus.boss_phase_changed

# === 光环颜色配置（四乐章） ===
const AURA_CONFIGS := {
	1: {  # 第一乐章：热身 — 橙色，均匀呼吸
		"color": Color(1.0, 0.5, 0.1),      # 橙色
		"alpha_min": 0.1,
		"alpha_max": 0.35,
		"pulse_period": 2.0,                  # 2s 一循环（Phase E 默认）
		"special": "",
	},
	2: {  # 第二乐章：球类训练 — 黄色，快节奏
		"color": Color(1.0, 0.7, 0.1),       # 黄色
		"alpha_min": 0.15,
		"alpha_max": 0.40,
		"pulse_period": 2.0,                  # 2s 一循环
		"special": "",
	},
	3: {  # 第三乐章：集合 — 白色/暖白，不稳定脉冲
		"color": Color(0.9, 0.85, 0.7),      # 白色/暖白
		"alpha_min": 0.1,
		"alpha_max": 0.45,
		"pulse_period": 2.0,                  # 基准 2s（实际随机 0.5-2.5s）
		"special": "random_pulse",            # 每循环随机周期 + 大型脉冲
	},
	4: {  # 第四乐章：毕业考试 — 无光环
		"color": Color.TRANSPARENT,
		"alpha_min": 0.0,
		"alpha_max": 0.0,
		"pulse_period": 0.0,
		"special": "",
	},
}

# 大型脉冲间隔（第三乐章）
const LARGE_PULSE_INTERVAL: float = 3.0

# Tween group
const GROUP_PULSE := "boss_aura_pulse"
const GROUP_TRANSITION := "boss_aura_transition"
const GROUP_SHATTER := "boss_aura_shatter"

# === 运行时状态 ===
var _aura: ColorRect = null
var _current_phase: int = 1
var _pulse_tween: Tween = null
var _large_pulse_timer: float = 0.0
var _is_pulsing: bool = false
var _is_shattered: bool = false

# Tween 注册表: {group_name: Array[Tween]}
var _tween_registry: Dictionary = {}


# =============================================================================
# 初始化
# =============================================================================

func init(aura: ColorRect) -> void:
	_aura = aura
	if not EventBus.boss_phase_changed.is_connected(_on_boss_phase_changed):
		EventBus.boss_phase_changed.connect(_on_boss_phase_changed)


func _process(delta: float) -> void:
	if _current_phase == 3 and _is_pulsing:
		_large_pulse_timer += delta
		if _large_pulse_timer >= LARGE_PULSE_INTERVAL:
			_large_pulse_timer = 0.0
			trigger_large_pulse()


# =============================================================================
# Public API
# =============================================================================

## 切换到指定乐章的光环配置
func set_phase(phase: int) -> void:
	if phase < 1 or phase > 4:
		return
	if _current_phase == phase:
		return

	_is_shattered = false
	var old_phase: int = _current_phase
	_current_phase = phase

	var config: Dictionary = AURA_CONFIGS.get(phase, AURA_CONFIGS[1])
	var target_color: Color = config.get("color", Color.TRANSPARENT)

	# kill 当前呼吸脉冲
	stop_pulse()

	# 颜色过渡（0.5s — Phase E 指定）
	if _aura:
		_kill_group(GROUP_TRANSITION)
		var t: Tween = create_tween()
		t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		t.tween_property(_aura, "color", target_color, 0.5).set_ease(Tween.EASE_OUT)
		_register_tween(GROUP_TRANSITION, t)

		# 如果目标 alpha 为 0，同步淡出
		if config.get("alpha_max", 0.0) <= 0.0:
			t.parallel().tween_property(_aura, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_OUT)

	# 第四乐章：无光环
	if phase == 4:
		_is_pulsing = false
		return

	# 启动新乐章的呼吸脉冲
	var delay_sec: float = 0.55
	await get_tree().create_timer(delay_sec).timeout
	start_pulse()


## 启动光环呼吸脉冲
func start_pulse() -> void:
	if _is_pulsing or _is_shattered:
		return
	if _current_phase >= 4:
		return
	if not _aura:
		return

	_is_pulsing = true
	_large_pulse_timer = 0.0
	_pulse_one_cycle()


## 停止光环脉冲
func stop_pulse() -> void:
	_is_pulsing = false
	_large_pulse_timer = 0.0
	_kill_group(GROUP_PULSE)


## 触发大型脉冲（第三乐章吹哨声波 / 手动触发）
func trigger_large_pulse() -> void:
	if not _aura:
		return

	# 光环 scale: 1.0→1.25→1.0，alpha: max→0.7→max
	var orig_scale := _aura.scale
	var config: Dictionary = AURA_CONFIGS.get(_current_phase, AURA_CONFIGS[1])
	var max_alpha: float = config.get("alpha_max", 0.45)

	var t: Tween = create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.set_parallel(true)
	t.tween_property(_aura, "scale", Vector2(1.25, 1.25), 0.4).set_ease(Tween.EASE_OUT)
	t.tween_property(_aura, "modulate:a", 0.75, 0.4).set_ease(Tween.EASE_OUT)
	t.tween_property(_aura, "scale", orig_scale, 0.4).set_delay(0.4).set_ease(Tween.EASE_IN)
	t.tween_property(_aura, "modulate:a", max_alpha, 0.4).set_delay(0.4).set_ease(Tween.EASE_IN)


## 触发重击时光环扩张（第一乐章 M1-A）
func trigger_heavy_attack_expand() -> void:
	if not _aura:
		return

	var orig_scale := _aura.scale
	var t: Tween = create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.tween_property(_aura, "scale", Vector2(1.3, 1.3), 0.15).set_ease(Tween.EASE_OUT)
	t.tween_property(_aura, "scale", orig_scale, 0.15).set_ease(Tween.EASE_IN)


## 光环碎裂（第三乐章→第四乐章过渡）
func shatter() -> void:
	if _is_shattered:
		return
	_is_shattered = true
	stop_pulse()

	if not _aura:
		return

	_kill_group(GROUP_SHATTER)

	# 瞬间变亮
	var t: Tween = create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)

	# 爆闪 0.05s → 闪烁 → 淡出 0.5s
	t.tween_property(_aura, "modulate:a", 0.8, 0.05)
	t.tween_property(_aura, "modulate:a", 0.3, 0.05)
	t.tween_property(_aura, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)

	# 光环膨胀后缩小
	t.parallel().tween_property(_aura, "scale", Vector2(1.6, 1.6), 0.15).set_delay(0.05)
	t.parallel().tween_property(_aura, "scale", Vector2(0.8, 0.8), 0.5).set_delay(0.2).set_ease(Tween.EASE_IN)

	_register_tween(GROUP_SHATTER, t)

	# 8 个白色碎片粒子从光环位置飞出
	_spawn_shatter_particles()


## 恢复光环（如需要）
func restore() -> void:
	_is_shattered = false
	if not _aura:
		return

	_kill_group(GROUP_SHATTER)
	_kill_group(GROUP_TRANSITION)

	var config: Dictionary = AURA_CONFIGS.get(_current_phase, AURA_CONFIGS[1])
	var target_color: Color = config.get("color", Color.TRANSPARENT)
	var max_alpha: float = config.get("alpha_max", 0.35)

	var t: Tween = create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.set_parallel(true)
	t.tween_property(_aura, "modulate:a", max_alpha, 0.3).set_ease(Tween.EASE_OUT)
	t.tween_property(_aura, "color", target_color, 0.3).set_ease(Tween.EASE_OUT)
	t.tween_property(_aura, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT)

	await t.finished
	start_pulse()


# =============================================================================
# Internal
# =============================================================================

func _pulse_one_cycle() -> void:
	if not _is_pulsing or not _aura:
		return

	_kill_group(GROUP_PULSE)

	var config: Dictionary = AURA_CONFIGS.get(_current_phase, AURA_CONFIGS[1])
	var period: float = config.get("pulse_period", 2.0)
	var alpha_min: float = config.get("alpha_min", 0.1)
	var alpha_max_val: float = config.get("alpha_max", 0.35)
	var special: String = config.get("special", "")

	# 第三乐章随机周期
	if special == "random_pulse":
		period = randf_range(0.5, 2.5)

	var half_period: float = period * 0.5

	# Phase E 核心：scale 1.0↔1.08，周期 2s
	var t: Tween = create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)

	# alpha 呼吸 + scale 微脉冲 并行
	t.set_parallel(true)
	t.tween_property(_aura, "modulate:a", alpha_max_val, half_period).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_aura, "scale", Vector2(1.08, 1.08), half_period).set_ease(Tween.EASE_IN_OUT)

	t.tween_property(_aura, "modulate:a", alpha_min, half_period).set_delay(half_period).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_aura, "scale", Vector2.ONE, half_period).set_delay(half_period).set_ease(Tween.EASE_IN_OUT)

	t.finished.connect(_on_pulse_cycle_done, CONNECT_ONE_SHOT)
	_pulse_tween = t


func _on_pulse_cycle_done() -> void:
	_pulse_one_cycle()


func _spawn_shatter_particles() -> void:
	if not _aura:
		return
	var parent := _aura.get_parent()
	if not parent:
		return

	var origin := _aura.position + _aura.size * 0.5
	var origin_global := _aura.global_position + _aura.size * 0.5

	for i in 8:
		var p := ColorRect.new()
		p.color = Color(1.0, 1.0, 1.0, 0.7)
		p.size = Vector2(4, 4)
		p.position = _aura.position + _aura.size * 0.5 - Vector2(2, 2)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.z_index = 10
		parent.add_child(p)

		var angle: float = float(i) / 8.0 * TAU
		var dist: float = randf_range(40, 80)
		var target_pos := Vector2(cos(angle) * dist, sin(angle) * dist) + origin

		var pt: Tween = create_tween()
		pt.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		pt.set_parallel(true)
		pt.tween_property(p, "position", target_pos, 0.5).set_ease(Tween.EASE_OUT)
		pt.tween_property(p, "color:a", 0.0, 0.5)
		pt.tween_callback(p.queue_free)


# =============================================================================
# Signal Handlers
# =============================================================================

func _on_boss_phase_changed(phase: int, _phase_name: String) -> void:
	if phase >= 1 and phase <= 4:
		set_phase(phase)


# =============================================================================
# Tween 注册管理
# =============================================================================

func _register_tween(group_name: String, tw: Tween) -> void:
	if not _tween_registry.has(group_name):
		_tween_registry[group_name] = []
	var arr: Array = _tween_registry[group_name]
	arr.append(tw)


func _kill_group(group_name: String) -> void:
	# 额外处理 pulse tween (通过引用管理)
	if group_name == GROUP_PULSE:
		if _pulse_tween and is_instance_valid(_pulse_tween) and _pulse_tween.is_running():
			_pulse_tween.kill()
			_pulse_tween = null

	# 从注册表清理指定 group 的 tweens
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
