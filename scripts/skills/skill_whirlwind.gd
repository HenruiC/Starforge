class_name SkillWhirlwind
extends SkillBase

@export var duration: float = 1.5
@export var ticks_per_second: float = 5.0
@export var spin_radius: float = 80.0

var _active: bool = false
var _elapsed: float = 0.0
var _tick_timer: float = 0.0
var _tick_interval: float = 0.2
var _original_speed: float = 300.0

func can_execute() -> bool:
	return not _active  # 旋转中不能再次触发

func execute() -> void:
	_active = true; _elapsed = 0.0; _tick_timer = 0.0
	_tick_interval = 1.0 / ticks_per_second
	if "move_speed" in player: _original_speed = player.move_speed
	_spin_visual()

func _process(delta: float) -> void:
	super._process(delta)
	if not _active: return
	_elapsed += delta; _tick_timer += delta
	if _tick_timer >= _tick_interval:
		_tick_timer -= _tick_interval
		_tick_damage()
		_spin_particles()
	if _elapsed >= duration:
		_end_spin()

func _end_spin() -> void:
	_active = false
	is_ready = true; cooldown_remaining = 0.0
	if "move_speed" in player: player.set("move_speed", _original_speed)

func _tick_damage() -> void:
	if attack_area == null: return
	var bodies := attack_area.get_overlapping_bodies()
	for body in bodies:
		if not body.is_in_group("enemy"): continue
		if not body.has_method("take_damage"): continue
		var dead: bool = body.get("is_dead") if body.get("is_dead") != null else false
		if dead: continue
		body.take_damage(int(float(damage) * 0.35))
		# 每次命中触发微顿帧
		CombatFeedback.hit_stop(1)

	# 也打击可破坏物
	for body in bodies:
		if body.is_in_group("destructible") and body.has_method("take_damage"):
			body.take_damage(int(float(damage) * 0.25))

func _spin_visual() -> void:
	for i in 4:
		var angle := float(i) * TAU / 4.0
		var blade := _create_effect_rect(Color(0.7, 0.85, 1.0, 0.5), Vector2(spin_radius * 1.5, 3), player.global_position, 14)
		blade.rotation = angle
		var t := create_tween()
		t.set_loops(int(duration * 4))
		t.tween_property(blade, "rotation", angle + TAU, 0.25)
		var cleanup := create_tween()
		cleanup.tween_interval(duration)
		cleanup.tween_callback(blade.queue_free)

func _spin_particles() -> void:
	var angle := randf_range(0, TAU); var dist := randf_range(spin_radius * 0.3, spin_radius)
	var pos := player.global_position + Vector2.RIGHT.rotated(angle) * dist
	var dot := _create_effect_rect(Color(0.6, 0.8, 1.0, 0.7), Vector2(4, 4), pos, 13)
	var t := create_tween().set_parallel(true)
	t.tween_property(dot, "scale", Vector2(0.1, 0.1), 0.3)
	t.tween_property(dot, "position", pos + Vector2(randf_range(-20, 20), randf_range(-20, 20)), 0.3)
	t.tween_property(dot, "modulate:a", 0.0, 0.3)
	t.chain().tween_callback(dot.queue_free)
