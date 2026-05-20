class_name SkillM3_SummonWhistle
extends SkillBase

## M3-A: 吹哨集合 — 召唤学生小怪
## 前摇 1.2s → 3 个白色方块从屏幕边缘出现并跑向玩家
## 最大同时存在 9 个，超过时不召唤

var _student_scene = null  # 代码创建，不使用 .tscn（Busy bug workaround）

func _init() -> void:
	skill_id = "m3_summon_whistle"
	skill_name = "吹哨集合"
	attack_category = "summon"
	_windup_duration = 1.2
	_recovery_duration = 0.5
	damage = 0
	cooldown = 12.0

func execute() -> void:
	if not owner_unit or not effect_parent:
		return

	# 检查场上学生数量
	if _get_student_count() >= 9:
		return

	var player := _find_player()
	if not player:
		return

	# 白色声波从 Boss 扩散
	CombatFeedback.hit_particles(owner_unit.global_position, 8, Color(0.9, 0.9, 0.8))

	# 从屏幕边缘生成 3 个学生
	var spawn_count: int = mini(3, 9 - _get_student_count())
	for i in range(spawn_count):
		var spawn_pos: Vector2 = _get_edge_spawn_position(player.global_position)
		_spawn_student(spawn_pos)
		await get_tree().create_timer(0.2).timeout

func _get_edge_spawn_position(player_pos: Vector2) -> Vector2:
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return player_pos + Vector2(randf_range(-200, 200), randf_range(-200, 200))

	var viewport_size := get_viewport().get_visible_rect().size
	var cam_pos: Vector2 = cam.global_position
	var side: int = randi() % 4
	match side:
		0: return Vector2(cam_pos.x - viewport_size.x * 0.6, cam_pos.y + randf_range(-viewport_size.y * 0.4, viewport_size.y * 0.4))
		1: return Vector2(cam_pos.x + viewport_size.x * 0.6, cam_pos.y + randf_range(-viewport_size.y * 0.4, viewport_size.y * 0.4))
		2: return Vector2(cam_pos.x + randf_range(-viewport_size.x * 0.4, viewport_size.x * 0.4), cam_pos.y - viewport_size.y * 0.6)
		3: return Vector2(cam_pos.x + randf_range(-viewport_size.x * 0.4, viewport_size.x * 0.4), cam_pos.y + viewport_size.y * 0.6)
	return player_pos + Vector2(randf_range(-150, 150), randf_range(-150, 150))

func _spawn_student(pos: Vector2) -> void:
	var tree := get_tree()
	if not tree:
		return

	var student: CharacterBody2D
	if _student_scene:
		student = _student_scene.instantiate()
	else:
		# 代码创建学生小怪（绕过 .tscn Busy bug）
		student = CharacterBody2D.new()
		student.collision_layer = 2
		student.collision_mask = 8
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 8
		shape.shape = circle
		student.add_child(shape)
		var sprite := ColorRect.new()
		sprite.name = "Sprite"
		sprite.color = Color(0.85, 0.85, 0.8, 1.0)
		sprite.size = Vector2(16, 24)
		sprite.scale = Vector2(0.7, 0.7)
		student.add_child(sprite)
	student.global_position = pos
	student.add_to_group("student_minion")

	# 添加到场景
	var root := tree.current_scene
	if root:
		var enemies_node: Node2D = root.get_node_or_null("Enemies")
		if enemies_node:
			enemies_node.add_child(student)
		else:
			root.add_child(student)

## 获取场上学生数量
func _get_student_count() -> int:
	var tree := get_tree()
	if not tree:
		return 0
	var students := tree.get_nodes_in_group("student_minion")
	return students.size()

func _find_player() -> Node2D:
	var tree := get_tree()
	if not tree:
		return null
	var players := tree.get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null
