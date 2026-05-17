class_name MapManager
extends Node2D

@export var tree_count: int = 15
@export var rock_count: int = 8
@export var border_margin: float = 100.0

var _destructible_scene: PackedScene = preload("res://scenes/destructible.tscn")

func _ready() -> void:
	var screen := get_viewport().get_visible_rect().size
	_spawn_objects(screen)

func _spawn_objects(screen: Vector2) -> void:
	for i in tree_count:
		var tree := _destructible_scene.instantiate()
		tree.object_name = "树"
		tree.object_color = Color(0.15, 0.55, 0.15)
		tree.max_health = 20; tree.drop_xp = 15
		tree.global_position = _random_pos(screen, border_margin)
		add_child(tree)

	for i in rock_count:
		var rock := _destructible_scene.instantiate()
		rock.object_name = "岩石"
		rock.object_color = Color(0.45, 0.4, 0.35)
		rock.max_health = 40; rock.drop_xp = 30
		rock.global_position = _random_pos(screen, border_margin)
		add_child(rock)

func _random_pos(screen: Vector2, margin: float) -> Vector2:
	return Vector2(
		randf_range(margin, screen.x - margin),
		randf_range(margin, screen.y - margin)
	)
