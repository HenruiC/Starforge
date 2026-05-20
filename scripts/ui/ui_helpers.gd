class_name UIHelpers
extends RefCounted

# 纯静态UI工厂方法 — 供 CharSelectUI / UpgradeUI 共享

# Phase 4 — 玩家武器类型，影响 UI 边框颜色
# 在 GameManager._finish_char_select_start 中设置
static var weapon_type: String = "sword"

## 根据当前武器类型获取 HUD 边框色调
## sword: 暖金, bow: 冷银, staff: 紫
static func get_weapon_border_color() -> Color:
	match weapon_type:
		"sword":
			return Color(0.85, 0.6, 0.1, 0.3)   # 暖金
		"bow":
			return Color(0.55, 0.6, 0.7, 0.3)   # 冷银
		"staff":
			return Color(0.55, 0.4, 0.7, 0.3)   # 紫
		_:
			return Color(0.8, 0.6, 0.1, 0.3)

## 获取武器类型的 HUD 强调色（非边框，用于细节点缀）
static func get_weapon_accent_color() -> Color:
	match weapon_type:
		"sword":
			return Color(0.85, 0.6, 0.1, 0.15)  # 暖金柔光
		"bow":
			return Color(0.55, 0.6, 0.7, 0.12)  # 冷银柔光
		"staff":
			return Color(0.55, 0.4, 0.7, 0.15)  # 紫柔光
		_:
			return Color(0.8, 0.6, 0.1, 0.15)


## 创建 HUD 边框装饰 ColorRect
## 根据武器类型返回一个带颜色的 HUD 强调条
## [param parent_size] 父容器尺寸，用于确定强调条大小
static func create_hud_accent(parent_size: Vector2) -> ColorRect:
	var accent := ColorRect.new()
	accent.name = "HUDWeaponAccent"
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	accent.color = get_weapon_accent_color()
	accent.size = Vector2(parent_size.x, 2)
	accent.position = Vector2(0, 0)
	accent.z_index = 5
	return accent


static func make_style(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.08, 0.16, 1.0)
	s.border_width_left = 1
	s.border_width_right = 1
	s.border_width_top = 1
	s.border_width_bottom = 1
	s.border_color = Color(c.r, c.g, c.b, 0.3)
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


static func make_zone(title: String, color: Color) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.custom_minimum_size = Vector2(175, 0)
	var l := Label.new()
	l.text = title
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l)
	return vb


static func make_btn(icon_key: String, title: String, desc: String, color: Color) -> Button:
	var b := Button.new()
	b.icon = AssetLoader.texture(icon_key, 48, color)
	b.text = title + "\n" + desc
	b.custom_minimum_size = Vector2(170, 55)
	b.expand_icon = true
	var s := make_style(color)
	b.add_theme_stylebox_override("normal", s)

	# Hover feedback: scale 1.05, 0.12s, ease_out
	b.mouse_entered.connect(func():
		UIEffects.hover_in(b)
	)
	b.mouse_exited.connect(func():
		UIEffects.hover_out(b)
	)
	return b
