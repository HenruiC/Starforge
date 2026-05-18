class_name UIHelpers
extends RefCounted

# 纯静态UI工厂方法 — 供 CharSelectUI / UpgradeUI 共享

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
	return b
