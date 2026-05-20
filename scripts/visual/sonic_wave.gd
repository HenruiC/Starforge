class_name SonicWave
extends RefCounted

## 哨声视觉声波工具 — TASK-V07
##
## 从指定位置扩展的 ColorRect 环形声波，模拟哨声的视觉传播。
## 玩家看到白色环形圈从 Boss 位置扩散，大脑会自动补全哨声。
##
## 三种哨声类型：
##   - 第一乐章哨声音波 (M1-B): 白→橙红, 3个, 90°扇形
##   - 第二乐章哨声尖啸 (M2-C): 白→橙红, 5个, 120°扇形
##   - 第三乐章吹哨集合 (M3-A): 纯白, 3个, 全方向
##   - 第三乐章空哨   (M3-E): 纯白→灰, 3个, 扩散到一半→回缩→消失

# === 颜色常量 ===
const COLOR_WAVE_WHITE := Color(1.0, 0.9, 0.8, 0.7)
const COLOR_WAVE_ORANGE_RED := Color(1.0, 0.5, 0.1, 0.7)
const COLOR_WAVE_YELLOW := Color(1.0, 0.7, 0.1, 0.7)
const COLOR_WAVE_GRAY := Color(0.5, 0.5, 0.5, 0.7)

# 哨声类型枚举
enum WhistleType {
	SONIC_WAVE = 0,      # M1-B: 白→橙红, 3个, 扇形
	SONIC_SHRIEK = 1,    # M2-C: 白→橙红, 5个, 宽扇形
	GATHERING = 2,       # M3-A: 纯白, 3个, 全方向
	EMPTY_CALL = 3,      # M3-E: 纯白→灰, 3个, 回缩
}

# === 参数配置 ===
const WAVE_CONFIGS := {
	WhistleType.SONIC_WAVE: {
		"start_color": Color(1.0, 0.9, 0.8, 0.7),
		"end_color": Color(1.0, 0.5, 0.1, 0.0),
		"count": 3,
		"spread_angle": 90.0,
		"duration": 0.6,
		"target_scale": 2.5,
	},
	WhistleType.SONIC_SHRIEK: {
		"start_color": Color(1.0, 0.9, 0.8, 0.7),
		"end_color": Color(1.0, 0.5, 0.1, 0.0),
		"count": 5,
		"spread_angle": 120.0,
		"duration": 0.5,
		"target_scale": 3.0,
	},
	WhistleType.GATHERING: {
		"start_color": Color(1.0, 0.95, 0.85, 0.7),
		"end_color": Color(1.0, 0.9, 0.7, 0.0),
		"count": 3,
		"spread_angle": 360.0,
		"duration": 0.8,
		"target_scale": 3.5,
	},
	WhistleType.EMPTY_CALL: {
		"start_color": Color(1.0, 0.9, 0.8, 0.7),
		"end_color": Color(0.5, 0.5, 0.5, 0.0),
		"count": 3,
		"spread_angle": 360.0,
		"duration": 0.8,
		"target_scale": 1.5,
	},
}

# 声波初始尺寸
const WAVE_INITIAL_SIZE := Vector2(16, 16)


## 创建视觉声波
## [param origin_global_pos] 声波发射点的全局坐标（通常是 Whistle 位置或 Boss 中心）
## [param wave_type] 哨声类型（WhistleType 枚举）
## [param parent] 声波 ColorRect 的父节点（通常是场景根节点）
static func create_sonic_wave(origin_global_pos: Vector2, wave_type: int, parent: Node) -> void:
	var config: Dictionary = WAVE_CONFIGS.get(wave_type, WAVE_CONFIGS[WhistleType.SONIC_WAVE])

	var count: int = config.get("count", 3)
	var spread_angle: float = deg_to_rad(config.get("spread_angle", 90.0))
	var duration: float = config.get("duration", 0.6)
	var target_scale: float = config.get("target_scale", 2.5)
	var start_color: Color = config.get("start_color")
	var end_color: Color = config.get("end_color")

	# 计算每个声波环的方向
	# 全方向 (360°) 时均匀分布
	# 扇形时在 spread_angle 范围内均匀分布，朝向玩家方向（默认向右）
	var base_angle: float = -spread_angle * 0.5 + deg_to_rad(90.0)  # 默认朝上偏右

	for i in range(count):
		var angle: float
		if spread_angle >= TAU - 0.01:
			# 全方向：均匀分布
			angle = float(i) / float(count) * TAU
		else:
			# 扇形：在 spread_angle 范围内
			angle = base_angle + spread_angle * float(i) / float(maxi(count - 1, 1))

		var ring := ColorRect.new()
		ring.name = "SonicWave_%d" % i
		ring.color = start_color
		ring.size = WAVE_INITIAL_SIZE
		ring.pivot_offset = WAVE_INITIAL_SIZE * 0.5
		ring.position = origin_global_pos - WAVE_INITIAL_SIZE * 0.5
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.z_index = 10
		parent.add_child(ring)

		# 扩散 + 淡出（Phase E 核心：scale 0→3.0, 0.4s + modulate.a 淡出）
		var t: Tween = ring.create_tween()
		t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		t.set_parallel(true)
		t.tween_property(ring, "scale", Vector2(target_scale, target_scale), duration).set_ease(Tween.EASE_OUT)
		t.tween_property(ring, "color", end_color, duration).set_ease(Tween.EASE_OUT)
		t.chain().tween_callback(ring.queue_free)


## 创建空哨特殊声波（M3-E）
## 扩散到 50% → 停止 → 回缩 → 颜色渐变到灰 → 消失
static func create_empty_call_wave(origin_global_pos: Vector2, parent: Node) -> void:
	var config: Dictionary = WAVE_CONFIGS[WhistleType.EMPTY_CALL]
	var count: int = config.get("count", 3)
	var start_color: Color = config.get("start_color")
	var mid_scale: float = config.get("target_scale", 1.5) * 0.5

	for i in range(count):
		var angle: float = float(i) / float(count) * TAU
		var dir := Vector2(cos(angle), sin(angle))

		var ring := ColorRect.new()
		ring.name = "EmptyCallWave_%d" % i
		ring.color = start_color
		ring.size = WAVE_INITIAL_SIZE
		ring.pivot_offset = WAVE_INITIAL_SIZE * 0.5
		ring.position = origin_global_pos - WAVE_INITIAL_SIZE * 0.5 + dir * 20.0
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.z_index = 10
		parent.add_child(ring)

		# 第一阶段：扩散到 50%（0.3s）
		var t: Tween = ring.create_tween()
		t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		t.tween_property(ring, "scale", Vector2(mid_scale, mid_scale), 0.3).set_ease(Tween.EASE_OUT)

		# 第二阶段：回缩 + 变灰 + 消失（0.5s）
		t.set_parallel(true)
		t.tween_property(ring, "scale", Vector2(0.3, 0.3), 0.5).set_ease(Tween.EASE_IN)
		t.tween_property(ring, "color", COLOR_WAVE_GRAY, 0.5).set_ease(Tween.EASE_IN)

		t.chain().tween_callback(ring.queue_free)


## 创建震地波（M2-E 圆环扩散）
## 3 道红色圆环从 Boss 中心向外扩散
static func create_ground_shockwave(origin_global_pos: Vector2, parent: Node) -> void:
	var ring_count: int = 3
	for i in range(ring_count):
		var ring := ColorRect.new()
		ring.name = "ShockwaveRing_%d" % i
		ring.color = Color(1.0, 0.3, 0.1, 0.5)
		ring.size = WAVE_INITIAL_SIZE
		ring.pivot_offset = WAVE_INITIAL_SIZE * 0.5
		ring.position = origin_global_pos - WAVE_INITIAL_SIZE * 0.5
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.z_index = 8
		parent.add_child(ring)

		var delay: float = float(i) * 0.12
		var target_scale: float = 1.5 + float(i) * 0.8

		var t: Tween = ring.create_tween()
		t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		t.set_parallel(true)
		t.tween_property(ring, "scale", Vector2(target_scale, target_scale), 0.5).set_delay(delay).set_ease(Tween.EASE_OUT)
		t.tween_property(ring, "color:a", 0.0, 0.5).set_delay(delay).set_ease(Tween.EASE_OUT)
		t.chain().tween_callback(ring.queue_free)


## 创建单一声波环（简化接口，用于自定义场景）
static func create_single_ring(origin_global_pos: Vector2, wave_color: Color, target_scale_val: float, duration: float, parent: Node) -> ColorRect:
	var ring := ColorRect.new()
	ring.name = "SonicRing"
	ring.color = wave_color
	ring.size = WAVE_INITIAL_SIZE
	ring.pivot_offset = WAVE_INITIAL_SIZE * 0.5
	ring.position = origin_global_pos - WAVE_INITIAL_SIZE * 0.5
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.z_index = 10
	parent.add_child(ring)

	var t: Tween = ring.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector2(target_scale_val, target_scale_val), duration).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "color:a", 0.0, duration).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(ring.queue_free)

	return ring
