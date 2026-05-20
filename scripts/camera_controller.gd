class_name CameraController
extends Camera2D

@export var follow_speed: float = 5.0
@export var max_offset: float = 100.0

var _target: Node2D = null

func _ready() -> void:
	CombatFeedback.register_camera(self)
	limit_left = 0; limit_right = 5760
	limit_top = 0; limit_bottom = 4320
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_target = players[0] as Node2D
		global_position = _target.global_position  # 直接跳到玩家位置

func _physics_process(delta: float) -> void:
	if _target == null:
		return

	global_position = global_position.lerp(_target.global_position, follow_speed * delta)
