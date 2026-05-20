class_name BossHpBar
extends Control

## Boss 血条 UI — TASK-I02+P08
##
## 屏幕顶部居中血条，游戏中首次出现"顶部血条"。
## 特征：
##   - 深红前景 + 半透明深灰背景
##   - 三条阶段标记线（75%/50%/25%）
##   - HP 减少用 0.3s ease_out 平滑动画
##   - 入场：从 -30px 滑入；退场：淡出 + 上滑消失

# ---- 可配置参数 ----

var bar_width_ratio: float = 0.6       # 血条宽度占屏幕比例
var bar_min_width: float = 600.0      # 最小宽度
var bar_max_width: float = 800.0      # 最大宽度
var bar_height: float = 14.0          # 血条高度
var bar_top_margin: float = 24.0      # 距屏幕顶部距离

var fill_color_normal: Color = Color(0.6, 0.05, 0.02)     # 深红
var fill_color_phase2: Color = Color(0.75, 0.15, 0.02)    # 略偏橙（第二乐章）
var fill_color_phase4: Color = Color(0.35, 0.03, 0.01)    # 暗红近乎黑（第四乐章）

var bg_color: Color = Color(0.1, 0.1, 0.12, 0.25)         # 背景
var marker_color: Color = Color(0.7, 0.7, 0.7, 0.6)       # 标记线

var hp_decrease_duration: float = 0.3    # HP 减少动画时长
var entry_duration: float = 0.3          # 入场滑入时长
var exit_duration: float = 0.3           # 退场时长

# ---- 内部节点 ----

var _bg: ColorRect                    # 背景层
var _fill: ColorRect                  # 前景血量填充
var _markers: Array[ColorRect] = []   # 三条阶段标记线 [75%, 50%, 25%]
var _name_label: Label                # "体育老师 · 佐藤"
var _hp_label: Label                  # "1200 / 1600"
var _bar_x: float                     # 血条左边缘 X
var _bar_y: float                     # 血条顶部 Y

# ---- 运行时状态 ----

var _display_ratio: float = 1.0       # 血条当前的显示比例（用于 Tween）
var _max_hp: int = 1
var _current_hp: int = 1
var _is_entered: bool = false
var _last_phase_check: float = 1.0    # 上次检查阶段的 HP 比例


func _ready() -> void:
	name = "BossHpBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_ui()


func _build_ui() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var bar_width: float = clamp(viewport_size.x * bar_width_ratio, bar_min_width, bar_max_width)
	_bar_x = (viewport_size.x - bar_width) * 0.5
	_bar_y = bar_top_margin

	# ---- 背景层 ----
	_bg = ColorRect.new()
	_bg.color = bg_color
	_bg.size = Vector2(bar_width, bar_height)
	_bg.position = Vector2(_bar_x, _bar_y)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# ---- 前景血量填充 ----
	_fill = ColorRect.new()
	_fill.color = fill_color_normal
	_fill.size = Vector2(bar_width, bar_height)
	_fill.position = Vector2(_bar_x, _bar_y)
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fill)

	# ---- 阶段标记线（75%, 50%, 25%） ----
	var mark_positions: Array[float] = [0.75, 0.50, 0.25]
	for pos in mark_positions:
		var marker := ColorRect.new()
		marker.color = marker_color
		marker.size = Vector2(2, bar_height)
		marker.position = Vector2(_bar_x + bar_width * pos, _bar_y)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 标记线需要知道自己的百分比位置（用于 pulse 动画时定位）
		marker.set_meta("threshold", pos)
		add_child(marker)
		_markers.append(marker)

	# ---- 名称标签（血条左上方） ----
	_name_label = Label.new()
	_name_label.text = "佐藤 幸雄"
	_name_label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.1))
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_name_label.add_theme_constant_override("outline_size", 1)
	_name_label.position = Vector2(_bar_x, _bar_y - 22)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)

	# ---- HP 数值标签（血条右上方） ----
	_hp_label = Label.new()
	_hp_label.text = "500 / 500"
	_hp_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_hp_label.add_theme_font_size_override("font_size", 12)
	_hp_label.position = Vector2(_bar_x + bar_width + 8, _bar_y + 2)
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hp_label)


# =============================================================================
# Public API
# =============================================================================

## 设置当前 HP（带平滑动画）
func set_hp(current: int, max_hp: int) -> void:
	if max_hp <= 0:
		return

	var prev_ratio: float = _display_ratio
	_current_hp = clampi(current, 0, max_hp)
	_max_hp = max_hp
	var target_ratio: float = float(_current_hp) / float(_max_hp)

	# 更新 HP 文字
	_hp_label.text = "%d / %d" % [_current_hp, _max_hp]

	# 平滑动画减少
	UIEffects.kill_group("hud_boss_hp")
	var t: Tween = create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.tween_method(_update_fill_width, _display_ratio, target_ratio, hp_decrease_duration) \
		.set_ease(Tween.EASE_OUT)
	_display_ratio = target_ratio

	# 检查阶段标记线穿越（HP 首次低于某阈值时脉冲闪光）
	_check_phase_threshold(prev_ratio, target_ratio)


## 入场动效：从屏幕顶部滑入 + 淡入
func enter() -> void:
	if _is_entered:
		return
	_is_entered = true

	UIEffects.kill_group("hud_boss_hp")

	# 初始状态：在顶部上方且透明
	modulate = Color(1, 1, 1, 0)
	position = Vector2(0, -30)
	visible = true

	var t: Tween = create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_CUBIC)

	# 滑入 + 淡入
	t.set_parallel(true)
	t.tween_property(self, "position:y", 0.0, entry_duration)
	t.tween_property(self, "modulate", Color.WHITE, entry_duration * 0.8)

	# 入场后：初始脉冲闪光（标记线的入场表演）
	t.tween_interval(entry_duration + 0.1)
	t.tween_callback(_entry_marker_flash)


## 退场动效：淡出 + 上滑消失
func exit() -> void:
	if not _is_entered:
		return
	_is_entered = false

	UIEffects.kill_group("hud_boss_hp")

	var t: Tween = create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.set_ease(Tween.EASE_OUT)
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, exit_duration)
	t.tween_property(self, "position:y", -10.0, exit_duration)

	t.tween_callback(func():
		visible = false
		position = Vector2.ZERO
	)


## 设置阶段对应的血条颜色
func set_phase_color(phase: int) -> void:
	match phase:
		2:
			# 第二乐章：略偏橙
			_fill.color = fill_color_phase2
		3:
			# 第三乐章：正常深红（标记线脉冲由单独调用触发）
			_fill.color = fill_color_normal
		4:
			# 第四乐章：暗红近乎黑
			_fill.color = fill_color_phase4
		_:
			# 第一乐章 / 默认：深红
			_fill.color = fill_color_normal


## 脉冲指定标记线（阶段转换时）
func flash_marker(index: int) -> void:
	if index < 0 or index >= _markers.size():
		return
	var marker: ColorRect = _markers[index]
	if not is_instance_valid(marker):
		return

	# 标记线脉冲：短暂变亮 + 缩放
	var orig_color: Color = marker.color
	UIEffects.kill_group("hud_boss_hp")
	var t: Tween = create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.tween_property(marker, "color", Color(1.0, 1.0, 1.0, 1.0), 0.1)
	t.tween_property(marker, "color", orig_color, 0.2)
	t.parallel().tween_property(marker, "scale", Vector2(1.0, 1.5), 0.1).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(marker, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT)


# =============================================================================
# Internal
# =============================================================================

func _update_fill_width(ratio: float) -> void:
	if not is_instance_valid(_fill) or not is_instance_valid(_bg):
		return
	_fill.size.x = _bg.size.x * clampf(ratio, 0.0, 1.0)


func _check_phase_threshold(prev_ratio: float, new_ratio: float) -> void:
	# 三条标记线对应的 HP 阈值
	var thresholds: Array[float] = [0.75, 0.50, 0.25]
	for i in range(thresholds.size()):
		var threshold: float = thresholds[i]
		if new_ratio <= threshold and prev_ratio > threshold:
			flash_marker(i)
			# 广播阶段变化（供其他系统使用）
			var phase_idx: int = i + 2  # 2=第二乐章, 3=第三乐章, 4=第四乐章
			EventBus.boss_phase_changed.emit(phase_idx, "phase_%d" % phase_idx)
			break


func _entry_marker_flash() -> void:
	# 入场时三条标记线从左到右依次闪一下
	for i in range(_markers.size()):
		var marker: ColorRect = _markers[i]
		if not is_instance_valid(marker):
			continue
		var t: Tween = create_tween()
		t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		t.tween_interval(i * 0.1)
		t.tween_property(marker, "color", Color(1.0, 1.0, 1.0, 1.0), 0.1)
		t.tween_property(marker, "color", marker_color, 0.2)
