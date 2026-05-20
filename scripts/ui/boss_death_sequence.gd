class_name BossDeathSequence
extends Node

## Boss 死亡演出通用管线 — 小岛秀夫
##
## 所有 Boss 的死亡演出走同一管道。差异仅在于 BossConfig 参数。
## 用法：
##   var seq := BossDeathSequence.new(boss_config)
##   add_child(seq)
##   await seq.play(enemy_ref, hud_layer)
##   seq.queue_free()
##
## 管线流程：
##   1. Big Hit Stop — Engine.time_scale = 0.05, 持续 0.15s
##   2. 时缓展开 — time_scale 0.05→0.3→0.6→1.0, 持续 0.8s (缓出)
##   3. Boss 坍塌 — 纵向压缩 + 横向拉宽 + 灰度化
##   4. 金色粒子爆发
##   5. 大字文字 — BossDeathTextUI (通用组件)
##   6. → sequence_completed 信号

signal sequence_completed

var cfg: BossConfig

func _init(config: BossConfig) -> void:
	cfg = config

func play(enemy: Node2D, hud_layer: CanvasLayer) -> void:
	if not enemy or not hud_layer:
		sequence_completed.emit()
		queue_free()
		return

	# ---------------------------------------------------------------
	# Step 1: Big Hit Stop
	# ---------------------------------------------------------------
	Engine.time_scale = 0.05
	await get_tree().create_timer(cfg.death_hit_stop_duration, true, true).timeout

	# ---------------------------------------------------------------
	# Step 2: 时缓展开 — 缓出曲线
	# ---------------------------------------------------------------
	var slowmo_duration: float = cfg.death_slowmo_duration
	var slowmo_elapsed: float = 0.0
	while slowmo_elapsed < slowmo_duration:
		slowmo_elapsed += get_process_delta_time()
		var t: float = slowmo_elapsed / slowmo_duration
		t = 1.0 - pow(1.0 - t, 3.0)  # ease-out cubic
		Engine.time_scale = 0.05 + t * 0.95
		await get_tree().process_frame
	Engine.time_scale = 1.0

	# ---------------------------------------------------------------
	# Step 3: Boss 坍塌动画
	# ---------------------------------------------------------------
	var sprite := enemy.get_node_or_null("Sprite") as ColorRect
	if sprite:
		var collapse_tween: Tween = enemy.create_tween()
		collapse_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		collapse_tween.set_parallel(true)
		collapse_tween.tween_property(sprite, "scale:y", 0.3, cfg.collapse_duration).set_ease(Tween.EASE_IN)
		collapse_tween.tween_property(sprite, "scale:x", 1.5, cfg.collapse_duration * 0.8).set_ease(Tween.EASE_IN)
		collapse_tween.tween_property(sprite, "modulate", Color(0.4, 0.4, 0.4, 1.0), cfg.collapse_duration * 0.4)
		collapse_tween.tween_property(sprite, "modulate:a", 0.0, cfg.collapse_duration)

	# 口哨掉落视觉效果
	var whistle_part := enemy.get_node_or_null("BossVisual/Whistle") as ColorRect
	if whistle_part:
		var whistle_start := whistle_part.global_position
		var whistle_tween: Tween = whistle_part.create_tween()
		whistle_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		whistle_tween.set_parallel(true)
		whistle_tween.tween_property(whistle_part, "global_position", whistle_start + Vector2(0, 60), 0.5).set_ease(Tween.EASE_IN)
		whistle_tween.tween_property(whistle_part, "rotation", deg_to_rad(180), 0.5)
		whistle_tween.tween_property(whistle_part, "modulate:a", 0.0, 0.5)
		whistle_tween.tween_callback(whistle_part.queue_free)

	# 等待坍塌完成
	await get_tree().create_timer(cfg.collapse_duration * 0.9, false, true).timeout

	# ---------------------------------------------------------------
	# Step 4: 金色粒子爆发 — 从坍塌位置 40 个粒子
	# ---------------------------------------------------------------
	_spawn_particles(enemy.global_position, hud_layer)

	await get_tree().create_timer(0.2, false, true).timeout

	# ---------------------------------------------------------------
	# Step 5: 大字文字 — 调用 VictoryTextUI
	# ---------------------------------------------------------------
	_show_defeat_text(hud_layer, cfg)

	# ---------------------------------------------------------------
	# Step 6: 等待文本展示完毕
	# ---------------------------------------------------------------
	await get_tree().create_timer(cfg.victory_text_duration, false, true).timeout

	# ---------------------------------------------------------------
	# 完成
	# ---------------------------------------------------------------
	sequence_completed.emit()
	queue_free()

# --------------------------------------------------------------------------
# 粒子爆发
# --------------------------------------------------------------------------

func _spawn_particles(world_pos: Vector2, hud: CanvasLayer) -> void:
	var screen_pos: Vector2 = _world_to_screen(world_pos)
	var particle_count: int = cfg.particle_count
	var gold_color: Color = cfg.particle_color

	for i in particle_count:
		var p := ColorRect.new()
		p.color = gold_color
		p.size = Vector2(6, 6)
		p.position = screen_pos
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.z_index = 25
		hud.add_child(p)

		var angle: float = randf() * TAU
		var dist: float = randf_range(80, 200)
		var target_pos: Vector2 = screen_pos + Vector2(cos(angle), sin(angle)) * dist

		var pt: Tween = create_tween()
		pt.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		pt.set_parallel(true)
		pt.tween_property(p, "position", target_pos, randf_range(0.4, 0.8)).set_ease(Tween.EASE_OUT)
		pt.tween_property(p, "modulate:a", 0.0, randf_range(0.5, 0.9)).set_ease(Tween.EASE_IN)
		pt.tween_callback(func():
			if is_instance_valid(p):
				p.queue_free()
		)

# --------------------------------------------------------------------------
# 大字文字
# --------------------------------------------------------------------------

func _show_defeat_text(hud: CanvasLayer, config: BossConfig) -> void:
	var text_ui := VictoryTextUI.new()
	text_ui.boss_display_name = config.boss_display_name
	text_ui.defeat_text = config.boss_defeat_text
	text_ui.text_color = config.boss_defeat_color
	text_ui.hold_duration = config.victory_text_duration
	hud.add_child(text_ui)

# --------------------------------------------------------------------------
# 辅助：世界坐标 → 屏幕坐标
# --------------------------------------------------------------------------

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if not camera:
		return get_viewport().get_visible_rect().size * 0.5
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	return (world_pos - camera.global_position) * camera.zoom + viewport_size * 0.5
