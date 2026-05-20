class_name DungeonSelectUI
extends Control

## 副本选择界面 — 启动时展示可选副本，选择后进入
##
## 纯代码构建，无 .tscn。读取可用副本列表，玩家选择后发射信号。

signal dungeon_selected(dungeon_id: String)

const DUNGEONS := {
	"school": {
		"name": "学校副本",
		"subtitle": "三年二班 · 体育教师 佐藤幸雄",
		"description": "踏入废弃校舍，穿越教室走廊，\n在体育馆面对最后的哨声。",
		"color": Color(0.42, 0.23, 0.16),       # 红褐 — 体育馆
		"accent": Color(0.7, 0.3, 0.3),
		"mission": "res://resources/missions/school_mission.tres",
		"blueprint": "res://resources/blueprints/school_blueprint.tres",
	},
	"rooftop": {
		"name": "天台副本",
		"subtitle": "放课后的屋顶",
		"description": "爬上教学楼顶层，\n在夕阳下迎接最后的挑战。",
		"color": Color(0.85, 0.55, 0.2),         # 橙黄 — 夕阳
		"accent": Color(0.9, 0.5, 0.1),
		"mission": "res://resources/missions/rooftop_mission.tres",
		"blueprint": "res://resources/blueprints/rooftop_blueprint.tres",
	},
}

var _cards: Array[Control] = []
var _selected: String = ""


func _init() -> void:
	_build_ui()


func _build_ui() -> void:
	# 全屏暗色背景
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 居中容器
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	add_child(center)

	# 标题
	var title := Label.new()
	title.text = "选择副本"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	center.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "选择一个副本进入"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	center.add_child(subtitle)

	center.add_child(_spacer(20))

	# 卡片容器
	var cards := HBoxContainer.new()
	cards.name = "Cards"
	cards.add_theme_constant_override("separation", 24)
	center.add_child(cards)

	for dungeon_id in DUNGEONS:
		var info: Dictionary = DUNGEONS[dungeon_id]
		var card := _create_card(dungeon_id, info)
		cards.add_child(card)
		_cards.append(card)

	center.add_child(_spacer(30))

	# 确认按钮
	var btn := Button.new()
	btn.text = "进入副本"
	btn.custom_minimum_size = Vector2(200, 50)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(_on_enter)
	center.add_child(btn)

	# 默认选中第一个
	if _cards.size() > 0:
		_select_card(_cards[0])


func _create_card(dungeon_id: String, info: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(280, 360)
	card.name = dungeon_id

	var style := StyleBoxFlat.new()
	style.bg_color = info.color
	style.bg_color.a = 0.15
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = info.accent
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	card.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)

	# 色块顶栏
	var header := ColorRect.new()
	header.color = info.accent
	header.custom_minimum_size = Vector2(0, 80)
	vb.add_child(header)

	var header_label := Label.new()
	header_label.text = info.name
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_label.add_theme_font_size_override("font_size", 24)
	header_label.add_theme_color_override("font_color", Color.WHITE)
	header_label.set_anchors_preset(Control.PRESET_CENTER)
	header.add_child(header_label)

	# 副标题
	var sub := Label.new()
	sub.text = info.subtitle
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vb.add_child(sub)

	vb.add_child(_spacer(10))

	# 描述
	var desc := Label.new()
	desc.text = info.description
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 14)
	vb.add_child(desc)

	# 点击选中
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_select_card(card)
	)

	return card


func _select_card(card: Control) -> void:
	_selected = card.name
	for c in _cards:
		var style := c.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			style.border_width_left = 3 if c == card else 1
			style.border_width_right = 3 if c == card else 1
			style.border_width_top = 3 if c == card else 1
			style.border_width_bottom = 3 if c == card else 1
		c.queue_redraw()


func _on_enter() -> void:
	if _selected.is_empty():
		return
	var info: Dictionary = DUNGEONS.get(_selected, {})
	dungeon_selected.emit(_selected)
	print("[DungeonSelect] 进入副本: %s" % info.get("name", _selected))
	# game_manager 应监听此信号，加载对应副本配置
	queue_free()


func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s
