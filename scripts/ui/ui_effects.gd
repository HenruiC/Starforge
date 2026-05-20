class_name UIEffects
extends RefCounted

# 静态UI动效工具 — 六人共识定稿参数表
# 所有 Tween 使用 TWEEN_PROCESS_IDLE 以保证暂停时仍可运行动画

# --- 通用参数 ---
static var PANEL_FADE_DURATION := 0.2
static var HOVER_SCALE := 1.05
static var HOVER_DURATION := 0.12
static var BOUNCE_SCALE_PEAK := 1.2
static var BOUNCE_DURATION := 0.25
static var STAGGER_INTERVAL := 0.06
static var TYPEWRITE_SPEED := 0.02

# --- 仪式感递减 — 击杀弹跳 ---
# 前 10 次 peak=1.2, 11-50 次 peak=1.1, 51+ 次 peak=1.05
static var BOUNCE_SCALE_PEAK_1 := 1.2
static var BOUNCE_SCALE_PEAK_2 := 1.1
static var BOUNCE_SCALE_PEAK_3 := 1.05
static var BOUNCE_DECAY_THRESHOLD_1 := 10
static var BOUNCE_DECAY_THRESHOLD_2 := 50

# --- 仪式感递减 — 波次切换 ---
# 初始 peak=1.3, 每波递减 0.02, 最低 1.05
static var WAVE_INITIAL_PEAK := 1.3
static var WAVE_DECAY_PER_STEP := 0.02
static var WAVE_MIN_PEAK := 1.05
static var WAVE_FLASH_DURATION := 0.08
static var WAVE_FLASH_COLOR := Color(0.9, 0.7, 0.2, 1.0)

# Phase D — 注册的 Tween Group 名称（用于文档参考）
# hud_silence     — 沉默时刻 HUD 消退/恢复（与所有常规 HUD group 互斥）
# hud_boss_hp     — Boss 血条入场/退场/HP 减少
# hud_vignette    — 暗角 alpha 渐变
# hud_victory_text — 胜利文字入场/呼吸/退场
# hud_boss_panel  — 佐藤的馈赠面板入场

# Tween 注册表: {group_name: [Tween]}
static var _tweens: Dictionary = {}

# --- Hover 效果 ---

static func hover_in(ctrl: Control) -> void:
	kill_group("__hover")
	var t: Tween = ctrl.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(ctrl, "scale", Vector2(HOVER_SCALE, HOVER_SCALE), HOVER_DURATION)
	_register_tween("__hover", t)


static func hover_out(ctrl: Control) -> void:
	kill_group("__hover")
	var t: Tween = ctrl.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(ctrl, "scale", Vector2.ONE, HOVER_DURATION)
	_register_tween("__hover", t)


# --- Bounce (e.g. 经验值获得 / 数字弹跳) ---

static func bounce(label: Label) -> void:
	kill_group("__bounce")
	var t: Tween = label.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(label, "scale", Vector2(BOUNCE_SCALE_PEAK, BOUNCE_SCALE_PEAK), BOUNCE_DURATION * 0.5)
	t.tween_property(label, "scale", Vector2.ONE, BOUNCE_DURATION * 0.5)
	_register_tween("__bounce", t)


# --- Bounce with configurable peak (for ritualistic decay) ---

static func bounce_with_peak(label: Label, peak_scale: float) -> void:
	kill_group("__bounce")
	var t: Tween = label.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(label, "scale", Vector2(peak_scale, peak_scale), BOUNCE_DURATION * 0.5)
	t.tween_property(label, "scale", Vector2.ONE, BOUNCE_DURATION * 0.5)
	_register_tween("__bounce", t)


# --- Wave 切换动画 ---

static func wave_flash(label: Label, peak_scale: float) -> void:
	kill_group("__wave")
	# Scale pop
	var t: Tween = label.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(label, "scale", Vector2(peak_scale, peak_scale), 0.15)
	t.tween_property(label, "scale", Vector2.ONE, 0.15)
	_register_tween("__wave", t)

	# Color flash
	var orig_color: Color = label.modulate
	label.modulate = WAVE_FLASH_COLOR
	var restore_t: SceneTreeTimer = label.get_tree().create_timer(WAVE_FLASH_DURATION)
	restore_t.timeout.connect(func():
		if is_instance_valid(label):
			label.modulate = orig_color
	, CONNECT_ONE_SHOT)


# --- Panel 淡入/淡出 ---
# from_alpha: 中断场景下从当前透明度开始 (0.0 = 标准入场)

static func panel_in(panel: Control, group: String, from_alpha: float = 0.0) -> Tween:
	print("UIEFFECTS: panel_in group=", group, " from_alpha=", from_alpha)
	kill_group(group)
	panel.visible = true
	panel.modulate = Color(1.0, 1.0, 1.0, from_alpha)
	var t: Tween = panel.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	var dur: float = PANEL_FADE_DURATION * (1.0 - from_alpha)
	t.tween_property(panel, "modulate", Color.WHITE, maxf(dur, 0.05))
	_register_tween(group, t)
	return t


static func panel_out(panel: Control, group: String) -> Tween:
	print("UIEFFECTS: panel_out group=", group, " panel.visible=", panel.visible)
	kill_group(group)
	var from_a: float = panel.modulate.a
	var dur: float = PANEL_FADE_DURATION * from_a
	var t: Tween = panel.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.tween_property(panel, "modulate", Color(1.0, 1.0, 1.0, 0.0), maxf(dur, 0.05))
	t.finished.connect(func():
		if is_instance_valid(panel):
			panel.visible = false
	)
	_register_tween(group, t)
	return t


# --- 组管理 ---

static func kill_group(group: String) -> void:
	if not _tweens.has(group):
		return
	for t in _tweens[group]:
		if is_instance_valid(t):
			t.kill()
	_tweens[group].clear()


static func _register_tween(group: String, t: Tween) -> void:
	if not _tweens.has(group):
		_tweens[group] = []
	# 手动清理死引用, 避免 filter() 在热路径分配新Array
	var list: Array = _tweens[group]
	var i: int = list.size() - 1
	while i >= 0:
		if not is_instance_valid(list[i]):
			list.remove_at(i)
		i -= 1
	list.append(t)
