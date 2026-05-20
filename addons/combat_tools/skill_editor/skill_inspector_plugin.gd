@tool
extends EditorInspectorPlugin

## 技能/Boss 检查器 — 为 BossAttackData / BossPhaseData 提供自定义检查器


func _can_handle(object: Object) -> bool:
	if object is BossAttackData:
		return true
	if object is BossPhaseData:
		return true
	return false


func _parse_begin(object: Object) -> void:
	if object is BossAttackData:
		_add_attack_preview(object)
	if object is BossPhaseData:
		_add_phase_quick_info(object)


func _parse_property(
	_object: Object,
	_type: Variant.Type,
	_name: String,
	_hint_type: PropertyHint,
	_hint_string: String,
	_usage_flags: int,
	_wide: bool
) -> bool:
	return false


# ==============================================================================
# BossAttackData — 攻击范围 2D 预览
# ==============================================================================

class AttackPreviewCanvas:
	extends Control

	var _attack: BossAttackData

	func _init(attack: BossAttackData) -> void:
		_attack = attack
		custom_minimum_size = Vector2(0, 180)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL

	func _draw() -> void:
		var center := size / 2.0
		var scale: float = 0.8
		var max_range: float = max(_attack.range, _attack.aoe_radius, _attack.cone_range, _attack.dash_distance, 120.0)

		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.12))

		# 玩家位置
		draw_circle(center, 6, Color.GREEN)

		# AOE
		if _attack.aoe_radius > 0:
			var r: float = _attack.aoe_radius * scale * min(size.x, size.y) / (max_range * 2.0)
			draw_arc(center, r, 0, TAU, 64, Color(1.0, 0.3, 0.1, 0.3), 2.0)

		# 扇形
		if _attack.cone_angle > 0 and _attack.cone_range > 0:
			var r: float = _attack.cone_range * scale * min(size.x, size.y) / (max_range * 2.0)
			var half_angle: float = deg_to_rad(_attack.cone_angle / 2.0)
			draw_arc(center, r, -half_angle, half_angle, 32, Color(1.0, 0.6, 0.1, 0.3), 1.0)
			var left_edge: Vector2 = center + Vector2.RIGHT.rotated(-half_angle) * r
			var right_edge: Vector2 = center + Vector2.RIGHT.rotated(half_angle) * r
			draw_line(center, left_edge, Color(1.0, 0.6, 0.1, 0.5), 1.0)
			draw_line(center, right_edge, Color(1.0, 0.6, 0.1, 0.5), 1.0)

		# 普通范围
		if _attack.range > 0 and _attack.aoe_radius <= 0 and _attack.cone_angle <= 0:
			var r: float = _attack.range * scale * min(size.x, size.y) / (max_range * 2.0)
			draw_arc(center, r, 0, TAU, 64, Color(0.4, 0.6, 1.0, 0.3), 1.5)

		# 冲刺
		if _attack.dash_distance > 0:
			var dash_len: float = _attack.dash_distance * scale * min(size.x, size.y) / (max_range * 2.0)
			var end: Vector2 = center + Vector2.RIGHT * dash_len
			draw_line(center, end, Color(1.0, 0.2, 0.2, 0.6), 3.0)
			var arrow_size: float = 10.0
			draw_line(end, end + Vector2.LEFT.rotated(0.3) * arrow_size, Color(1.0, 0.2, 0.2, 0.6), 2.0)
			draw_line(end, end + Vector2.LEFT.rotated(-0.3) * arrow_size, Color(1.0, 0.2, 0.2, 0.6), 2.0)

		# 投射物
		if _attack.projectile_speed > 0:
			var px: float = center.x + 30
			for i: int in _attack.projectile_count:
				var py: float = center.y - float(_attack.projectile_count - 1) * 10.0 + float(i) * 20.0
				draw_circle(Vector2(px, py), 4, Color(1.0, 0.8, 0.2))
				draw_line(Vector2(px, py), Vector2(px + 40, py), Color(1.0, 0.8, 0.2, 0.4), 1.0)


func _add_attack_preview(attack: BossAttackData) -> void:
	var container := VBoxContainer.new()
	container.add_child(_make_section_label("攻击范围预览"))

	var canvas := AttackPreviewCanvas.new(attack)
	container.add_child(canvas)

	add_custom_control(container)


# ==============================================================================
# BossPhaseData — 阶段快速概览
# ==============================================================================

func _add_phase_quick_info(phase: BossPhaseData) -> void:
	var container := VBoxContainer.new()
	container.add_child(_make_section_label("乐章概览"))

	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.text = _format_phase_info(phase)
	container.add_child(info)

	add_custom_control(container)


func _format_phase_info(phase: BossPhaseData) -> String:
	return """[b]%s (Stage %d)[/b]
HP阈值: %.0f%% | 移速: %.0f | 防御: %d | 伤害: %d
攻击间隔: %.1f-%.1fs | 技能槽: %s
光环: %s (%.2f-%.2f)
弹幕: %d发 x %.0fpx/s x %.0f°
召唤: %s | 核心暴露: %s""" % [
		phase.phase_name, phase.phase_index,
		phase.health_threshold * 100, phase.move_speed, phase.defense, phase.contact_damage,
		phase.attack_interval_min, phase.attack_interval_max, str(phase.skill_slots),
		phase.aura_color.to_html(false), phase.aura_alpha_min, phase.aura_alpha_max,
		phase.bullet_count, phase.bullet_speed, phase.bullet_spread_angle,
		"是 (%d/%.0fs)" % [phase.summon_count, phase.summon_interval] if phase.summon_enabled else "否",
		"是" if phase.core_exposed else "否"
	]


func _make_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	return lbl
