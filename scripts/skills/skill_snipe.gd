class_name SkillSnipe
extends SkillBase

@export var projectile_speed: float = 700.0
@export var aoe_on_hit: float = 60.0

var _projectile_scene: PackedScene = preload("res://scenes/player_projectile.tscn")

func can_execute() -> bool:
	return _find_nearest_enemy() != null

func execute() -> void:
	var target := _find_nearest_enemy()
	if target == null: return
	var dir := player.global_position.direction_to(target.global_position)
	var p := _projectile_scene.instantiate()
	p.setup(dir, projectile_speed, damage)
	p.global_position = player.global_position
	effect_parent.add_child(p)

	var line := _create_effect_rect(Color(1.0, 0.3, 0.1, 0.5), Vector2(1, 2), player.global_position, 13)
	line.rotation = dir.angle(); line.scale = Vector2(0.1, 0.5)
	var lt := create_tween().set_parallel(true)
	lt.tween_property(line, "scale", Vector2(2.0, 0.3), 0.1)
	lt.tween_property(line, "modulate:a", 0.0, 0.15)
	lt.chain().tween_callback(line.queue_free)

func _find_nearest_enemy() -> Node2D:
	if attack_area == null: return null
	var bodies := attack_area.get_overlapping_bodies()
	var nearest: Node2D = null; var min_d: float = INF
	for b in bodies:
		if b.is_in_group("enemy") and not b.is_dead:
			var d := player.global_position.distance_squared_to(b.global_position)
			if d < min_d: min_d = d; nearest = b
	return nearest

func apply_level_up(power: int = 1) -> void:
	damage += power * 8; projectile_speed += 50; aoe_on_hit += 10
