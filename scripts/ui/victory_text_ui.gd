class_name VictoryTextUI
extends Control

## "下课"胜利文字演出 — 通用组件
##
## Boss 击败后屏幕中央浮现 "<boss_name> —— <defeat_text>"。
## 所有参数可从外部设置，使此组件可被任何 Boss 复用。
##
## 用法：
##   var v := VictoryTextUI.new()
##   v.boss_display_name = "魔王"
##   v.defeat_text = "倒下了。"
##   v.text_color = Color(1.0, 0.2, 0.1)
##   add_child(v)
##
## 入场：从下方 30px 滑入 + 缩放 + 淡入（0.4s, TRANS_BACK）
## 停留：呼吸 pulse（scale 1.0 ↔ 1.03, 共 hold_duration 秒）
## 退场：淡出 + 上浮（0.5s）
## 总计约 (entry_duration + hold_duration + exit_duration) 秒后自动销毁

var label: Label

# 可配置参数
var boss_display_name: String = "UNKNOWN"
var defeat_text: String = "已击败"
var entry_duration: float = 0.4
var hold_duration: float = 3.0
var exit_duration: float = 0.5
var breathe_period: float = 1.2
var font_size: int = 36
var text_color: Color = Color(0.85, 0.65, 0.1)       # 暗金色
var outline_color: Color = Color(0, 0, 0, 0.8)
var outline_size: int = 2


func _ready() -> void:
	name = "VictoryTextUI"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_label()
	_play_entrance()


func _build_label() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	label = Label.new()
	label.name = "VictoryLabel"
	label.text = "%s —— %s" % [boss_display_name, defeat_text]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_constant_override("outline_size", outline_size)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 定位到屏幕中央（y 偏上 40px 给后续内容留空间）
	label.custom_minimum_size = Vector2(viewport_size.x, 60)
	label.size = Vector2(viewport_size.x, 60)
	label.position = Vector2(0, viewport_size.y * 0.5 - 40.0)
	add_child(label)


func _play_entrance() -> void:
	# 初始状态：透明，在目标位置下方 30px，小 scale
	var target_y: float = label.position.y
	label.modulate = Color(1, 1, 1, 0)
	label.position.y = target_y + 30.0
	label.scale = Vector2(0.3, 0.3)

	# 入场动效：缩放 + 滑入 + 淡入
	var t: Tween = create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_BACK)

	t.set_parallel(true)
	t.tween_property(label, "modulate:a", 1.0, entry_duration)
	t.tween_property(label, "position:y", target_y, entry_duration)
	t.tween_property(label, "scale", Vector2(1.0, 1.0), entry_duration)

	# 入场后的呼吸 pulse（持续 hold_duration 秒）
	t.tween_interval(0.05)  # 微小间隔让入场动画落定
	t.tween_callback(_start_breathing)

	# 退场
	t.tween_interval(hold_duration)
	t.tween_property(label, "modulate:a", 0.0, exit_duration)
	t.parallel().tween_property(label, "position:y", target_y - 20.0, exit_duration)

	t.tween_callback(queue_free)


func _start_breathing() -> void:
	# 呼吸 pulse：scale 1.0 ↔ 1.03，无限循环
	var breath_tween: Tween = create_tween().set_loops()
	breath_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	breath_tween.set_ease(Tween.EASE_IN_OUT)
	breath_tween.tween_property(label, "scale", Vector2(1.03, 1.03), breathe_period)
	breath_tween.tween_property(label, "scale", Vector2.ONE, breathe_period)
