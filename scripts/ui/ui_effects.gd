class_name UIEffects
extends RefCounted

# 静态UI动效工具 — 六人共识定稿参数表
# 所有 Tween 使用 TWEEN_PROCESS_IDLE 以保证暂停时仍可运行动画

static var PANEL_FADE_DURATION := 0.2
static var HOVER_SCALE := 1.05
static var HOVER_DURATION := 0.12
static var BOUNCE_SCALE_PEAK := 1.2
static var BOUNCE_DURATION := 0.25
static var STAGGER_INTERVAL := 0.06
static var TYPEWRITE_SPEED := 0.02
static var WAVE_FLASH_DURATION := 0.08

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


# --- Panel 淡入/淡出 ---
# from_alpha: 中断场景下从当前透明度开始 (0.0 = 标准入场)

static func panel_in(panel: Control, group: String, from_alpha: float = 0.0) -> Tween:
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
