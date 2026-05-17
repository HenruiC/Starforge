class_name SkillChainLightning
extends SkillBase

# 链式闪电 — 命中主目标后弹跳到附近敌人

@export var chain_count: int = 3
@export var chain_range: float = 150.0
@export var damage_decay: float = 0.7

func execute() -> void:
	if attack_area == null: return
	var primary := _find_nearest_enemy()
	if primary == null: return

	var hit_list: Array = [primary]
	var current: Node2D = primary
	var dmg: int = damage

	for i in chain_count:
		if current == null or not is_instance_valid(current): break
		if current.has_method("take_damage") and not current.is_dead:
			current.take_damage(dmg)
			var from_pos: Vector2 = player.global_position if i == 0 else hit_list[i].global_position
			_spawn_lightning_vfx(from_pos, current.global_position)
		dmg = int(float(dmg) * damage_decay)
		var next := _find_nearest_to(current.global_position, hit_list)
		if next == null: break
		hit_list.append(next); current = next

func _find_nearest_enemy() -> Node2D:
	var bodies := attack_area.get_overlapping_bodies()
	var nearest: Node2D = null; var min_d: float = INF
	for b in bodies:
		if b.is_in_group("enemy") and not b.is_dead:
			var d := player.global_position.distance_squared_to(b.global_position)
			if d < min_d: min_d = d; nearest = b
	return nearest

func _find_nearest_to(pos: Vector2, exclude: Array) -> Node2D:
	var nearest: Node2D = null; var min_d: float = chain_range * chain_range
	for b in attack_area.get_overlapping_bodies():
		if b.is_in_group("enemy") and not b.is_dead:
			var excluded: bool = false
			for ex in exclude: if b == ex: excluded = true; break
			if not excluded:
				var d := pos.distance_squared_to(b.global_position)
				if d < min_d: min_d = d; nearest = b
	return nearest

func _spawn_lightning_vfx(from: Vector2, to: Vector2) -> void:
	var seg_count: int = randi() % 3 + 3
	var prev: Vector2 = from
	for i in seg_count:
		var t: float = float(i + 1) / float(seg_count + 1)
		var target: Vector2 = from.lerp(to, t)
		target += Vector2(randf_range(-12, 12), randf_range(-12, 12))
		var seg := _create_effect_rect(Color(0.5, 0.7, 1.0, 0.9), Vector2(prev.distance_to(target), 3), (prev + target) * 0.5, 15)
		seg.rotation = prev.direction_to(target).angle(); seg.scale = Vector2(1.0, 1.2)
		var tw := create_tween()
		tw.tween_property(seg, "modulate:a", 0.0, 0.25); tw.tween_callback(seg.queue_free)
		prev = target

	var hit := _create_effect_rect(Color(0.6, 0.8, 1.0, 0.9), Vector2(20, 20), to, 16)
	var ht := create_tween().set_parallel(true)
	ht.tween_property(hit, "scale", Vector2(2.0, 2.0), 0.12)
	ht.tween_property(hit, "modulate:a", 0.0, 0.15)
	ht.chain().tween_callback(hit.queue_free)

func apply_level_up(power: int = 1) -> void:
	damage += power * 4; chain_count += 1
	cooldown = maxf(cooldown * 0.93, 0.3)
