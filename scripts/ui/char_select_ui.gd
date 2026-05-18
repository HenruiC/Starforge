class_name CharSelectUI
extends RefCounted

# 角色选择UI工厂 — 从 GameManager._show_char_select() 提取
# 提供静态工厂方法 create(), 返回 CharSelectUI 实例供 GameManager 持有
# 使用 UIHelpers 静态工厂方法创建UI元素

var sel_wp: String = "sword"
var sel_talents: Array = []
var wp_btns: Dictionary = {}   # weapon_key: Button
var talent_btns: Dictionary = {}  # talent_key: Button
var preview_vbox: VBoxContainer
var confirm_btn: Button
var panel: Control
var buttons_container: Container
var on_start: Callable  # Callable(weapon: String, talents: Array)


static func create(panel: Control, buttons_container: Container, on_start: Callable) -> CharSelectUI:
	var ui := CharSelectUI.new()
	ui.panel = panel
	ui.buttons_container = buttons_container
	ui.on_start = on_start
	ui._build()
	return ui


func _build() -> void:
	panel.visible = true

	# 移除旧的叙事文本避免重叠
	var old_n := panel.get_node_or_null("Narrative")
	if old_n:
		old_n.queue_free()

	var narrative := Label.new()
	narrative.name = "Narrative"
	narrative.text = "\"那一天，所有人都觉醒了天赋。\n而我，只有D级的——天赋适应。\""
	narrative.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	narrative.add_theme_font_size_override("font_size", 14)
	narrative.add_theme_color_override("font_color", Color(0.65, 0.6, 0.45, 1.0))
	narrative.anchor_left = 0.5
	narrative.anchor_right = 0.5
	narrative.offset_left = -350
	narrative.offset_top = 130
	narrative.offset_right = 350
	narrative.offset_bottom = 170
	panel.add_child(narrative)

	for child in buttons_container.get_children():
		child.queue_free()

	sel_wp = "sword"
	sel_talents.clear()
	wp_btns.clear()
	talent_btns.clear()

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_container.add_child(root)

	# 左: 武器
	var wp_vbox := UIHelpers.make_zone("武器", Color(0.3, 0.5, 0.8, 1.0))
	root.add_child(wp_vbox)
	for key in SkillManager.WEAPON_POOL:
		var d: Dictionary = SkillManager.WEAPON_POOL[key]
		var wk: String = key
		var b := UIHelpers.make_btn("weapon_" + wk, d["name"], d["desc"], Color(0.3, 0.5, 0.8, 1.0))
		b.pressed.connect(func():
			sel_wp = wk
			_refresh_preview()
		)
		wp_vbox.add_child(b)
		wp_btns[wk] = b

	# 中: 天赋池 (9个技能用ScrollContainer)
	var tp_vbox := UIHelpers.make_zone("天赋 (选3)", Color(0.8, 0.6, 0.2, 1.0))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(190, 280)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var tp_grid := GridContainer.new()
	tp_grid.columns = 1
	tp_grid.add_theme_constant_override("v_separation", 3)
	scroll.add_child(tp_grid)
	tp_vbox.add_child(scroll)
	root.add_child(tp_vbox)

	for key in SkillManager.TALENT_POOL:
		var d: Dictionary = SkillManager.TALENT_POOL[key]
		var tk: String = key
		var b := UIHelpers.make_btn("icon_" + tk, d["name"], d["desc"], d["color"])
		b.custom_minimum_size = Vector2(175, 42)
		b.pressed.connect(func():
			_toggle_talent(tk, b)
		)
		talent_btns[tk] = b
		tp_grid.add_child(b)

	# 右: 预览
	preview_vbox = UIHelpers.make_zone("已选", Color(0.3, 0.8, 0.3, 1.0))
	root.add_child(preview_vbox)

	confirm_btn = Button.new()
	confirm_btn.text = "踏入试炼"
	confirm_btn.custom_minimum_size = Vector2(280, 48)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.15, 0.1, 0.02, 1.0)
	cs.border_width_left = 2
	cs.border_width_right = 2
	cs.border_width_top = 2
	cs.border_width_bottom = 2
	cs.border_color = Color(0.8, 0.6, 0.1, 0.6)
	cs.corner_radius_top_left = 4
	cs.corner_radius_top_right = 4
	cs.corner_radius_bottom_left = 4
	cs.corner_radius_bottom_right = 4
	cs.content_margin_left = 12
	cs.content_margin_right = 12
	confirm_btn.add_theme_stylebox_override("normal", cs)
	confirm_btn.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2, 1.0))
	confirm_btn.add_theme_font_size_override("font_size", 16)
	confirm_btn.pressed.connect(_try_start)
	buttons_container.add_child(confirm_btn)

	_refresh_preview()


func _toggle_talent(key: String, btn: Button) -> void:
	if key in sel_talents:
		sel_talents.erase(key)
		btn.modulate = Color.WHITE
		var s := UIHelpers.make_style(SkillManager.TALENT_POOL[key]["color"])
		btn.add_theme_stylebox_override("normal", s)
	else:
		if sel_talents.size() >= 3:
			return
		sel_talents.append(key)
		btn.modulate = Color(0.5, 1.0, 0.5, 1.0)
		var h := UIHelpers.make_style(SkillManager.TALENT_POOL[key]["color"])
		h.border_color = Color.GREEN
		h.border_width_left = 2
		h.border_width_right = 2
		h.border_width_top = 2
		h.border_width_bottom = 2
		btn.add_theme_stylebox_override("normal", h)
	_refresh_preview()


func _refresh_preview() -> void:
	if preview_vbox == null:
		return
	for child in preview_vbox.get_children():
		if child is Label and child.text != "":
			child.queue_free()

	_update_weapon_highlight()

	var wp: Dictionary = SkillManager.WEAPON_POOL[sel_wp]
	var wl := Label.new()
	wl.text = "武器: %s %s" % [wp["icon"], wp["name"]]
	wl.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0, 1.0))
	preview_vbox.add_child(wl)


func _update_weapon_highlight() -> void:
	for wk in wp_btns:
		wp_btns[wk].modulate = Color.GREEN if wk == sel_wp else Color.WHITE

	var tl := Label.new()
	tl.text = "天赋: %d/3" % sel_talents.size()
	preview_vbox.add_child(tl)

	for tid in sel_talents:
		var td: Dictionary = SkillManager.TALENT_POOL[tid]
		var l := Label.new()
		l.text = "  %s %s" % [td["icon"], td["name"]]
		l.add_theme_color_override("font_color", td["color"])
		preview_vbox.add_child(l)

	if confirm_btn:
		var ready := sel_talents.size() == 3
		confirm_btn.text = "踏入试炼" if ready else "选择天赋 (%d/3)" % sel_talents.size()
		confirm_btn.disabled = not ready
		if ready:
			var box: StyleBox = confirm_btn.get_theme_stylebox("normal", "")
			if box:
				var cs2 := box.duplicate() as StyleBoxFlat
				if cs2:
					cs2.border_color = Color.GREEN
					confirm_btn.add_theme_stylebox_override("normal", cs2)


func _try_start() -> void:
	if sel_talents.size() != 3:
		return
	if on_start:
		on_start.call(sel_wp, sel_talents.duplicate())
