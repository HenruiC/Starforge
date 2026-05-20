class_name VFXUtils
extends Node

# 杨奇色彩体系
const C_AMBER: Color = Color(0.788, 0.659, 0.298)
const C_PURPLE: Color = Color(0.227, 0.165, 0.361)
const C_SCARLET: Color = Color(0.8, 0.1, 0.1)
const C_GOLD: Color = Color(0.85, 0.65, 0.1)
const C_WARM_WHITE: Color = Color(1.0, 0.9, 0.75)
const C_EMBER: Color = Color(1.0, 0.55, 0.1)
const C_ICE_BLUE: Color = Color(0.3, 0.6, 0.9)
const C_DEEP_RED: Color = Color(0.5, 0.05, 0.05)
const C_ASH: Color = Color(0.6, 0.6, 0.6)
const C_CYAN: Color = Color(0.2, 0.8, 0.9)
const C_GREEN: Color = Color(0.2, 0.8, 0.3)
const C_DARK_SCARLET: Color = Color(0.4, 0.05, 0.05)
const C_DARK_ICE: Color = Color(0.1, 0.2, 0.35)
const C_SHADOW: Color = Color(0.15, 0.05, 0.2)

# z_index 分层
const Z_GROUND_SCAR: int = -10
const Z_AFTERIMAGE: int = -5
const Z_BULLET: int = 10
const Z_SHIELD: int = 15
const Z_SHOCKWAVE: int = 50
const Z_SCREEN_PULSE: int = 100

# 通用 ColorRect 工厂
static func create_rect(color: Color, size: Vector2, parent: Node, z: int = 0) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = color
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.z_index = z
	parent.add_child(r)
	return r

# 呼吸脉冲
static func breathe(rect: ColorRect, min_a: float, max_a: float, period: float) -> Tween:
	var t: Tween = rect.create_tween().set_loops(0)
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.tween_property(rect, "modulate:a", min_a, period * 0.5)
	t.tween_property(rect, "modulate:a", max_a, period * 0.5)
	return t

# 缩放弹出
static func pop_scale(rect: ColorRect, peak: float, duration: float) -> void:
	var orig: Vector2 = rect.scale
	var t: Tween = rect.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.tween_property(rect, "scale", orig * peak, duration * 0.3)
	t.tween_property(rect, "scale", orig, duration * 0.7).set_ease(Tween.EASE_OUT)

# 环形扩散
static func ring_expand(parent: Node, color: Color, radius: float, duration: float, pos: Vector2, z: int = 50) -> ColorRect:
	var ring: ColorRect = create_rect(color, Vector2(4, 4), parent, z)
	ring.position = pos - Vector2(2, 2)
	ring.pivot_offset = Vector2(2, 2)
	var t: Tween = ring.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.tween_property(ring, "scale", Vector2(radius / 2.0, radius / 2.0), duration)
	t.parallel().tween_property(ring, "modulate:a", 0.0, duration)
	t.tween_callback(ring.queue_free)
	return ring

# 碎片爆发
static func burst_fragments(parent: Node, color: Color, count: int, pos: Vector2, z: int = 20) -> void:
	for i in count:
		var f: ColorRect = create_rect(color, Vector2(4, 4), parent, z)
		f.position = pos - Vector2(2, 2)
		var angle: float = randf_range(0, TAU)
		var dist: float = randf_range(20, 60)
		var t: Tween = f.create_tween().set_parallel(true)
		t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		t.tween_property(f, "position", pos + Vector2(cos(angle) * dist, sin(angle) * dist), 0.4).set_ease(Tween.EASE_OUT)
		t.tween_property(f, "modulate:a", 0.0, 0.4)
		t.tween_callback(f.queue_free)

# 地面焦痕
static func create_scorch(parent: Node, pos: Vector2, radius: float, z: int = -5) -> ColorRect:
	var s: ColorRect = create_rect(Color(0.1, 0.05, 0.02, 0.5), Vector2(radius * 2, radius * 2), parent, z)
	s.position = pos - Vector2(radius, radius)
	var t: Tween = s.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.tween_interval(0.5)
	t.tween_property(s, "modulate:a", 0.0, 1.0)
	t.tween_callback(s.queue_free)
	return s

# 精英护盾环
static func create_shield_ring(parent: Node, pos: Vector2) -> ColorRect:
	var s: ColorRect = create_rect(C_ICE_BLUE, Vector2(32, 32), parent, Z_SHIELD)
	s.position = pos - Vector2(16, 16)
	s.modulate = Color(1, 1, 1, 0.25)
	return s

# 残影
static func spawn_afterimage(parent: Node, pos: Vector2, color: Color, size: Vector2, alpha: float, z: int = -5) -> ColorRect:
	var a: ColorRect = create_rect(color, size, parent, z)
	a.position = pos - size * 0.5
	a.modulate = Color(1, 1, 1, alpha)
	var t: Tween = a.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.tween_property(a, "modulate:a", 0.0, 0.3)
	t.tween_callback(a.queue_free)
	return a
