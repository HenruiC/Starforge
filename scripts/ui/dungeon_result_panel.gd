class_name DungeonResultPanel
extends Control

# =============================================================================
# 副本结算面板 — 杨奇"暗金琥珀"配色方案
# 设计文档: output/docs/副本结算与校门-杨奇.md §2
#
# 纯代码构建（不依赖 .tscn），全屏暗金琥珀面板
# =============================================================================

# ===== 配色常量（杨奇色板） =====
const COLOR_DEEP_SPACE := Color(0.039, 0.039, 0.078)       # #0A0A14 深空背景
const COLOR_AMBER := Color(0.788, 0.659, 0.298)            # #C9A84C 暗金琥珀
const COLOR_AMBER_DIM := Color(0.788, 0.659, 0.298, 0.7)   # 暗金琥珀 @ 70%
const COLOR_AMBER_LINE := Color(0.788, 0.659, 0.298, 0.3)  # 分隔线 @ 30%
const COLOR_CARD_BG := Color(0.227, 0.165, 0.361, 0.4)    # #3A2A5C @ 40%
const COLOR_CARD_BG_FULL := Color(0.227, 0.165, 0.361, 0.6) # #3A2A5C @ 60%
const COLOR_SAND := Color(0.91, 0.84, 0.72)                # #E8D5B7 浅沙
const COLOR_BROWN := Color(0.55, 0.49, 0.42)               # #8B7D6B 土棕
const COLOR_RED_BROWN := Color(0.42, 0.23, 0.16)           # #6B3A2A 红褐
const COLOR_TEXT := Color(0.85, 0.85, 0.85)                # 浅白文字
const COLOR_TEXT_DIM := Color(0.7, 0.7, 0.7, 0.6)          # 暗淡文字

# ===== 内部节点引用 =====
var _bg: ColorRect              # 全屏深空背景
var _content: VBoxContainer     # 面板内容
var _title_label: Label         # "── 放課後 ──"
var _subtitle_label: Label      # "佐藤 幸雄，下课。"
var _grade_value: Label         # 评分字母 (S/A/B/C)

# Called when the result panel is created and ready to show data
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP  # 拦截所有输入
	_build_ui()


# =============================================================================
# UI 构建
# =============================================================================

func _build_ui() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	# ---- 全屏深空背景 ----
	_bg = ColorRect.new()
	_bg.name = "DungeonResultBg"
	_bg.color = COLOR_DEEP_SPACE
	_bg.color.a = 0.92
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.anchors_preset = Control.PRESET_FULL_RECT
	add_child(_bg)

	# ---- 内容容器（居中） ----
	_content = VBoxContainer.new()
	_content.name = "DungeonResultContent"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_theme_constant_override("separation", 0)
	# 居中定位
	_content.custom_minimum_size = Vector2(480, 0)
	_content.size = Vector2(480, 0)
	_content.position = Vector2(
		(viewport_size.x - 480) * 0.5,
		(viewport_size.y - 500) * 0.5
	)
	add_child(_content)

	# ---- 标题区 ----
	_build_title_section()

	# ---- 数据卡片行（三列） ----
	_build_stats_row()

	# ---- 评分明细区 ----
	_build_detail_section()

	# ---- 奖励槽 ----
	_build_reward_section()

	# ---- 继续提示 ----
	_build_continue_hint()


func _build_title_section() -> void:
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 8)

	# 标题："── 放課後 ──"
	_title_label = Label.new()
	_title_label.text = "── 放課後 ──"
	_title_label.add_theme_color_override("font_color", COLOR_AMBER)
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_constant_override("outline_size", 1)
	_title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.3))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_child(_title_label)

	# 副标题："佐藤 幸雄，下课。"
	_subtitle_label = Label.new()
	_subtitle_label.text = ""
	_subtitle_label.add_theme_color_override("font_color", COLOR_AMBER_DIM)
	_subtitle_label.add_theme_font_size_override("font_size", 16)
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_child(_subtitle_label)

	# 分隔线
	var divider := ColorRect.new()
	divider.color = COLOR_AMBER_LINE
	divider.custom_minimum_size = Vector2(200, 1)
	divider.size = Vector2(200, 1)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# center it within the VBox — wrap in a center container
	var div_wrap := HBoxContainer.new()
	div_wrap.add_theme_constant_override("separation", 0)
	div_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Add spacer and divider
	var left_spacer := Control.new()
	left_spacer.custom_minimum_size = Vector2(140, 1)
	var right_spacer := Control.new()
	right_spacer.custom_minimum_size = Vector2(140, 1)
	div_wrap.add_child(left_spacer)
	div_wrap.add_child(divider)
	div_wrap.add_child(right_spacer)
	title_box.add_child(div_wrap)

	title_box.add_theme_constant_override("separation", 12)
	_content.add_child(title_box)


func _build_stats_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 三列数据卡片：通关时间 / 等级 / 评价
	var time_card := _make_stat_card("通关时间", "--:--")
	var level_card := _make_stat_card("等级", "Lv.--")
	var grade_card := _make_stat_card("评价", "--")

	# 保存评分字母引用（用于特殊动画）
	_grade_value = grade_card.get_node("Value") as Label

	row.add_child(time_card)
	row.add_child(level_card)
	row.add_child(grade_card)

	_content.add_child(row)

	# 储存卡片引用给 set_data 用
	set_meta("time_card_value", time_card.get_node("Value"))
	set_meta("level_card_value", level_card.get_node("Value"))
	set_meta("grade_card_value", _grade_value)
	set_meta("grade_card_label", grade_card.get_node("Label"))


## 创建单张数据卡片（VBoxContainer 含 Value + Label）
static func _make_stat_card(card_label: String, default_value: String) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(140, 90)
	card.size_flags_horizontal = Control.SIZE_EXPAND
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_constant_override("separation", 6)

	# 背景
	var card_bg := ColorRect.new()
	card_bg.color = COLOR_CARD_BG
	card_bg.anchors_preset = Control.PRESET_FULL_RECT
	card_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(card_bg)

	# 数值
	var val := Label.new()
	val.name = "Value"
	val.text = default_value
	val.add_theme_color_override("font_color", Color.WHITE)
	val.add_theme_font_size_override("font_size", 22)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(val)

	# 标签
	var lbl := Label.new()
	lbl.name = "Label"
	lbl.text = card_label
	lbl.add_theme_color_override("font_color", COLOR_AMBER_DIM)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(lbl)

	return card


func _build_detail_section() -> void:
	# 评分明细卡片
	var detail_card := VBoxContainer.new()
	detail_card.name = "DetailSection"
	detail_card.add_theme_constant_override("separation", 2)
	detail_card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 暗紫底背景
	var detail_bg := ColorRect.new()
	detail_bg.name = "DetailBg"
	detail_bg.color = COLOR_CARD_BG
	detail_bg.anchors_preset = Control.PRESET_FULL_RECT
	detail_card.add_child(detail_bg)

	# 标题
	var detail_title := Label.new()
	detail_title.text = "─ 评分明细 ─"
	detail_title.add_theme_color_override("font_color", COLOR_AMBER_DIM)
	detail_title.add_theme_font_size_override("font_size", 12)
	detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_card.add_child(detail_title)

	# 三行评分明细（由 set_data 填充）
	var labels := ["时间：--  (+--)", "死亡：--  (--)", "击杀：--  (+--)"]
	for txt in labels:
		var lbl := Label.new()
		lbl.name = "Detail_%s" % txt.substr(0, 2)
		lbl.text = txt
		lbl.add_theme_color_override("font_color", COLOR_SAND)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_constant_override("outline_size", 0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail_card.add_child(lbl)

	_content.add_child(detail_card)
	set_meta("detail_section", detail_card)


func _build_reward_section() -> void:
	var reward_box := HBoxContainer.new()
	reward_box.name = "RewardSection"
	reward_box.add_theme_constant_override("separation", 12)
	reward_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for i in 3:
		var slot := ColorRect.new()
		slot.name = "RewardSlot_%d" % (i + 1)
		slot.color = COLOR_CARD_BG_FULL
		slot.custom_minimum_size = Vector2(120, 80)
		slot.size = Vector2(120, 80)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# 金边
		var border := ColorRect.new()
		border.color = COLOR_AMBER_LINE
		border.anchors_preset = Control.PRESET_FULL_RECT
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(border)

		# 占位符
		var placeholder := Label.new()
		placeholder.name = "Placeholder"
		placeholder.text = "--"
		placeholder.add_theme_color_override("font_color", COLOR_AMBER_DIM)
		placeholder.add_theme_font_size_override("font_size", 14)
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.size = Vector2(120, 80)
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(placeholder)

		reward_box.add_child(slot)

	_content.add_child(reward_box)
	set_meta("reward_box", reward_box)


func _build_continue_hint() -> void:
	var hint := Label.new()
	hint.name = "ContinueHint"
	hint.text = "—— 按任意键继续 ——"
	hint.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	hint.add_theme_font_size_override("font_size", 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(hint)

	# 呼吸闪烁
	var t: Tween = create_tween().set_loops()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.tween_property(hint, "modulate:a", 0.3, 1.2).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(hint, "modulate:a", 1.0, 1.2).set_ease(Tween.EASE_IN_OUT)


# =============================================================================
# 公共 API — 填充数据
# =============================================================================

## 接收评分数据并更新所有 UI 元素
##
## result 字典结构见 game_manager._calculate_rating() 返回值：
##   clear_time_str, player_level, grade, grade_color, grade_flavor,
##   time_score, death_score, kill_score, kill_count, death_count,
##   reward_slots, total_score
func set_data(result: Dictionary) -> void:
	# ---- 副标题 ----
	var grade_flavor: String = result.get("grade_flavor", "")
	_subtitle_label.text = grade_flavor

	# ---- 三列数据卡片 ----
	var time_card_val: Label = get_meta("time_card_value", null)
	var level_card_val: Label = get_meta("level_card_value", null)
	var grade_card_val: Label = get_meta("grade_card_value", null)

	if time_card_val:
		time_card_val.text = result.get("clear_time_str", "--:--")
	if level_card_val:
		level_card_val.text = "Lv.%d" % result.get("player_level", 0)
	if grade_card_val:
		grade_card_val.text = result.get("grade", "--")
		grade_card_val.add_theme_color_override("font_color", result.get("grade_color", COLOR_AMBER))
		grade_card_val.add_theme_font_size_override("font_size", 30)

	# ---- 评分明细 ----
	var clear_secs: float = result.get("clear_time_secs", 0.0)
	var minutes := int(clear_secs) / 60
	var seconds := int(clear_secs) % 60
	var formatted_time := "%d分%02d秒" % [minutes, seconds]

	var time_score: float = result.get("time_score", 0.0)
	var death_score: float = result.get("death_score", 0.0)
	var kill_score: float = result.get("kill_score", 0.0)
	var kill_count: int = result.get("kill_count", 0)
	var death_count: int = result.get("death_count", 0)

	var detail_section: VBoxContainer = get_meta("detail_section", null)
	if detail_section:
		var detail_labels: Array[Node] = []
		for child in detail_section.get_children():
			if child is Label and child.name.begins_with("Detail_"):
				detail_labels.append(child)

		if detail_labels.size() >= 3:
			detail_labels[0].text = "时间：%s  (+%d)" % [formatted_time, int(time_score)]
			detail_labels[1].text = "死亡：%d次  (-%d)" % [death_count, int(min(death_count * 25, 100))]
			detail_labels[2].text = "击杀：%d体  (+%d)" % [kill_count, int(kill_score)]

	# ---- 奖励槽 ----
	var reward_slots: int = result.get("reward_slots", 1)
	var reward_box: HBoxContainer = get_meta("reward_box", null)
	if reward_box:
		var idx := 0
		for child in reward_box.get_children():
			if child is ColorRect:
				var placeholder: Label = child.get_node_or_null("Placeholder") as Label
				if placeholder:
					if idx < reward_slots:
						placeholder.text = "?"
						placeholder.add_theme_color_override("font_color", COLOR_AMBER)
					else:
						placeholder.text = "--"
						placeholder.add_theme_color_override("font_color", COLOR_TEXT_DIM)
				# 不可用的槽暗淡
				if idx >= reward_slots:
					child.color = Color(0.227, 0.165, 0.361, 0.2)
					child.modulate = Color(1, 1, 1, 0.4)
				idx += 1


# =============================================================================
# 入场动画
# =============================================================================

func play_enter_animation() -> void:
	# 面板整体从 opacity 0 + scale 0.9 开始
	modulate = Color(1, 1, 1, 0)
	scale = Vector2(0.9, 0.9)
	pivot_offset = size * 0.5

	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.set_parallel(true)
	t.tween_property(self, "modulate", Color.WHITE, 0.4).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# 评分字母特殊动画：从大 → 小（overshoot）
	if _grade_value and is_instance_valid(_grade_value):
		var grade_t := create_tween()
		grade_t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		grade_t.tween_property(_grade_value, "scale", Vector2(1.4, 1.4), 0.3).set_ease(Tween.EASE_OUT)
		grade_t.tween_property(_grade_value, "scale", Vector2(0.95, 0.95), 0.15).set_ease(Tween.EASE_IN)
		grade_t.tween_property(_grade_value, "scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_OUT)

	# 标题先出（delay 0.1s）
	if _title_label and is_instance_valid(_title_label):
		var title_t := create_tween()
		title_t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		title_t.tween_property(_title_label, "modulate:a", 1.0, 0.3).set_delay(0.1)

	# 子节点 stagger 入场
	_build_stagger_animation()


func _build_stagger_animation() -> void:
	# 从 _content 的子节点中找到数据卡片、详情、奖励槽做 staggered 入场
	var stagger_targets: Array[Node] = []
	for child in _content.get_children():
		if child is VBoxContainer or child is HBoxContainer:
			# Skip title section
			if child == _content.get_child(0):
				continue
			stagger_targets.append(child)

	for i in range(stagger_targets.size()):
		var target := stagger_targets[i]
		# Kill any existing scale/modulate on stagger children
		# Already set by _build_*; we add delay here by tweening alpha to full
		var s_tween := create_tween()
		s_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		var delay_val: float = 0.5 + i * 0.12
		s_tween.tween_property(target, "modulate:a", 1.0, 0.25).set_delay(delay_val)


# =============================================================================
# 退出逻辑
# =============================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return
	# 任意按键继续
	if event is InputEventKey and event.pressed and not event.echo:
		_exit_result_screen()
	if event is InputEventMouseButton and event.pressed:
		_exit_result_screen()


func _exit_result_screen() -> void:
	# 防止重复退出
	if get_meta("_exiting", false):
		return
	set_meta("_exiting", true)

	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.tween_property(self, "modulate:a", 0.0, 0.4)
	t.tween_callback(func():
		# 回到角色选择 / 重开副本
		get_tree().reload_current_scene()
	)
