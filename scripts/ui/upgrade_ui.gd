class_name UpgradeUI
extends RefCounted

# 升级面板UI工厂 — 从 GameManager._show_upgrade_panel() 提取
# 静态方法 create(), 在指定容器中生成升级选项按钮
# 使用 UIHelpers.make_style() 创建按钮样式


static func create(buttons_container: Container, pool: Array, on_chosen: Callable) -> void:
	for child in buttons_container.get_children():
		child.queue_free()

	var n: int = mini(pool.size(), 3)
	for i in n:
		var opt: Dictionary = pool[i]
		var btn := Button.new()
		btn.text = "%s %s\n%s" % [opt.icon, opt.name, opt.desc]
		btn.custom_minimum_size = Vector2(180, 80)
		var oid: String = opt.id
		btn.pressed.connect(func():
			on_chosen.call(oid)
		)
		var s := UIHelpers.make_style(Color(0.5, 0.4, 0.1, 1.0))
		btn.add_theme_stylebox_override("normal", s)
		var h: StyleBoxFlat = s.duplicate() as StyleBoxFlat
		h.bg_color = Color(0.25, 0.25, 0.35, 1.0)
		h.border_color = Color(0.8, 0.6, 0.1, 1.0)
		btn.add_theme_stylebox_override("hover", h)
		buttons_container.add_child(btn)
