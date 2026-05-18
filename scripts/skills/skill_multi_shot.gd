class_name SkillMultiShot
extends SkillBase

@export var projectile_count: int = 3
@export var projectile_speed: float = 400.0
@export var spread_angle: float = 25.0

var _projectile_scene: PackedScene = preload("res://scenes/player_projectile.tscn")

func execute() -> void:
	var aim_dir: Vector2 = player.get("_aim_direction") if "_aim_direction" in player else Vector2.RIGHT
	var base_angle := aim_dir.angle()
	var spread := deg_to_rad(spread_angle)
	for i in projectile_count:
		var offset: float = 0.0
		if projectile_count > 1:
			offset = lerpf(-spread, spread, float(i) / float(projectile_count - 1))
		_fire(Vector2.RIGHT.rotated(base_angle + offset))

func _fire(dir: Vector2) -> void:
	var p := _projectile_scene.instantiate()
	p.setup(dir, projectile_speed, damage)
	p.global_position = player.global_position
	effect_parent.add_child(p)

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
	damage += power * 3; projectile_count += 1
	cooldown = maxf(cooldown * 0.94, 0.2)
