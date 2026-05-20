extends Node

## 副本蓝图运行时引擎
##
## 加载 DungeonGraph → 注册 Trigger → 沿连线执行 Action/Condition/Logic/Variable
## 集成 EventBus 现有信号，与 dialogue_panel / mission_trigger 协作

## 全局变量表（蓝图间共享）
static var variables: Dictionary = {}


## 加载并开始执行蓝图
func load_graph(graph: DungeonGraph) -> void:
	_connect_triggers(graph)


## 重置变量表
static func reset_variables() -> void:
	variables.clear()


# ==============================================================================
# Trigger 注册
# ==============================================================================

func _connect_triggers(graph: DungeonGraph) -> void:
	for node_data in graph.nodes:
		match node_data.type:
			"OnPlayerEnter":
				_execute_chain(graph, node_data.id)
			"OnZoneEnter":
				var zone_id: String = node_data.data.get("zone_id", "")
				if not zone_id.is_empty():
					EventBus.player_entered_zone.connect(func(zid: String):
						if zid == zone_id: _execute_chain(graph, node_data.id)
					)
			"OnEnemyKilled":
				var enemy_type: String = node_data.data.get("enemy_type", "")
				var count: int = node_data.data.get("count", 1)
				var killed := 0
				EventBus.enemy_killed_filtered.connect(func(_pos, _score, _elite, _boss, _ranged):
					if enemy_type.is_empty() or (enemy_type == "elite" and _elite) or (enemy_type == "boss" and _boss):
						killed += 1
						if killed >= count:
							killed = 0
							_execute_chain(graph, node_data.id)
				)
			"OnObjectiveDone":
				var obj_id: String = node_data.data.get("objective_id", "")
				if not obj_id.is_empty():
					EventBus.door_unlock_requested.connect(func(door: String):
						if door == obj_id: _execute_chain(graph, node_data.id)
					)


# ==============================================================================
# 链式执行引擎
# ==============================================================================

func _execute_chain(graph: DungeonGraph, from_node_id: String) -> void:
	var current_id := from_node_id

	while not current_id.is_empty():
		var node_data := graph.get_node(current_id)
		if node_data.is_empty():
			break

		match node_data.type:
			# --- Action ---
			"PlayDialogue":
				var path: String = node_data.data.get("dialogue_path", "")
				if not path.is_empty() and ResourceLoader.exists(path):
					var book := load(path) as DialogueBook
					if book:
						EventBus.dialogue_triggered.emit(book, "")
						await get_tree().create_timer(1.0).timeout  # 给对话面板时间显示

			"UnlockDoor":
				var door_id: String = node_data.data.get("door_id", "")
				if not door_id.is_empty():
					EventBus.door_unlock_requested.emit(door_id)

			"CompleteObjective":
				var obj_id: String = node_data.data.get("objective_id", "")
				print("[BlueprintRuntime] CompleteObjective: %s" % obj_id)

			"AdvanceStage":
				print("[BlueprintRuntime] AdvanceStage")

			"SpawnEnemy":
				print("[BlueprintRuntime] SpawnEnemy: %s at (%f, %f)" % [
					node_data.data.get("enemy_config", ""),
					node_data.data.get("pos_x", 0.0),
					node_data.data.get("pos_y", 0.0)
				])

			"TeleportPlayer":
				var px: float = node_data.data.get("pos_x", 0.0)
				var py: float = node_data.data.get("pos_y", 0.0)
				var player := _find_player()
				if player:
					player.global_position = Vector2(px, py)

			"SetVariable":
				var vn: String = node_data.data.get("var_name", "")
				var vv = node_data.data.get("value", "")
				if not vn.is_empty():
					variables[vn] = vv

			"Wait":
				var sec: float = node_data.data.get("seconds", 1.0)
				await get_tree().create_timer(sec).timeout

			# --- Condition ---
			"CompareVar":
				var var_name: String = node_data.data.get("var_name", "")
				var op: String = node_data.data.get("op", ">=")
				var val: String = node_data.data.get("value", "0")
				var result := _eval_compare(variables.get(var_name, 0), val, op)
				current_id = _next_node(graph, current_id, 0 if result else 1)
				continue

			"CheckStage":
				var stage: int = node_data.data.get("stage_id", 0)
				var current_stage := _get_current_stage()
				current_id = _next_node(graph, current_id, 0 if current_stage == stage else 1)
				continue

			"CheckDoor":
				# 简化：检查门的状态（默认假设锁着）
				current_id = _next_node(graph, current_id, 0)  # 默认走 True
				continue

			"HasItem":
				var item_id: String = node_data.data.get("item_id", "")
				current_id = _next_node(graph, current_id, 0 if variables.has(item_id) else 1)
				continue

			# --- Logic ---
			"AND", "OR", "Compare":
				pass  # 简化处理：沿输出继续

			"NOT":
				pass

		# 推进到下一节点
		current_id = _next_node(graph, current_id, 0)


func _next_node(graph: DungeonGraph, node_id: String, port: int) -> String:
	for conn in graph.connections:
		if conn.from_node == node_id and conn.from_port == port:
			return conn.to_node
	return ""


func _eval_compare(a, b_str: String, op: String) -> bool:
	var b: float = float(b_str) if b_str.is_valid_float() else 0.0
	var av: float = float(a) if str(a).is_valid_float() else 0.0
	match op:
		">":  return av > b
		">=": return av >= b
		"<":  return av < b
		"<=": return av <= b
		"==": return str(a) == b_str
		"!=": return str(a) != b_str
	return false


func _find_player() -> Node2D:
	var tree := get_tree()
	if tree == null:
		return null
	for node in tree.get_nodes_in_group("player"):
		return node
	return null


func _get_current_stage() -> int:
	var tree := get_tree()
	if tree == null:
		return -1
	for node in tree.get_nodes_in_group("mission_trigger"):
		if node.has_method("get_current_stage_index"):
			return node.get_current_stage_index()
	return -1
