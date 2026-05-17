extends Node

# 战斗反馈管线 — 小岛秀夫监修
# 统一接口: 顿帧 / 屏幕震动 / 伤害数字 / 粒子爆发

const HIT_STOP_FRAMES: int = 3
const BIG_HIT_STOP_FRAMES: int = 6
const SHAKE_DECAY: float = 0.85
const SHAKE_THRESHOLD: float = 0.3

var _damage_number_scene: PackedScene = preload("res://scenes/damage_number.tscn")
var _camera: Camera2D = null
var _shake_intensity: float = 0.0
var _hit_stop_remaining: int = 0
var _original_time_scale: float = 1.0
var _effect_parent: Node = null

func _ready() -> void:
	_original_time_scale = Engine.time_scale
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	# 顿帧处理
	if _hit_stop_remaining > 0:
		_hit_stop_remaining -= 1
		if _hit_stop_remaining <= 0:
			Engine.time_scale = _original_time_scale
		return

	# 屏幕震动衰减
	if _shake_intensity > SHAKE_THRESHOLD and _camera:
		var ox := randf_range(-_shake_intensity, _shake_intensity)
		var oy := randf_range(-_shake_intensity, _shake_intensity)
		_camera.offset = Vector2(ox, oy)
		_shake_intensity *= SHAKE_DECAY
	elif _camera and _shake_intensity > 0:
		_camera.offset = Vector2.ZERO
		_shake_intensity = 0.0

# === 顿帧 ===
func hit_stop(frames: int = HIT_STOP_FRAMES) -> void:
	_hit_stop_remaining = frames
	Engine.time_scale = 0.0

func big_hit_stop() -> void:
	hit_stop(BIG_HIT_STOP_FRAMES)

# === 屏幕震动 ===
func screen_shake(intensity: float) -> void:
	_shake_intensity = max(_shake_intensity, intensity)

# === 伤害数字 ===
func damage_number(pos: Vector2, value: int, is_crit: bool = false, is_heal: bool = false) -> void:
	if _effect_parent == null:
		_effect_parent = _find_effect_parent()

	var dn := _damage_number_scene.instantiate()
	dn.global_position = pos + Vector2(randf_range(-20, 20), randf_range(-15, -5))
	_effect_parent.add_child(dn)

	if is_heal:
		dn.setup(str(value), Color.GREEN)
	elif is_crit:
		dn.setup(str(value), Color.ORANGE, 1.5)
		dn.global_position = pos + Vector2(randf_range(-15, 15), -30)
	else:
		dn.setup(str(value), Color.WHITE)

func _find_effect_parent() -> Node:
	var tree := get_tree()
	if tree:
		var root := tree.current_scene
		if root:
			return root
	return self

# === 粒子爆发 ===
func hit_particles(pos: Vector2, count: int = 6, color: Color = Color(1.0, 0.8, 0.2)) -> void:
	if _effect_parent == null:
		_effect_parent = _find_effect_parent()
	if _effect_parent == null:
		return

	for i in count:
		var p := ColorRect.new()
		p.color = color; p.size = Vector2(4, 4)
		p.position = pos - Vector2(2, 2)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.z_index = 20
		_effect_parent.add_child(p)

		var angle := randf_range(0, TAU); var dist := randf_range(25, 60)
		var t := create_tween().set_parallel(true)
		t.tween_property(p, "position", pos + Vector2(cos(angle) * dist, sin(angle) * dist), randf_range(0.2, 0.4))
		t.tween_property(p, "color:a", 0.0, randf_range(0.2, 0.4))
		t.tween_callback(p.queue_free)

# === 击杀爆发 ===
func kill_explosion(pos: Vector2) -> void:
	hit_particles(pos, 12, Color(1.0, 0.7, 0.1))
	hit_particles(pos, 8, Color(1.0, 0.3, 0.05))
	screen_shake(3.0)

# === 设置相机引用 ===
func register_camera(cam: Camera2D) -> void:
	_camera = cam
