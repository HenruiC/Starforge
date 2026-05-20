class_name DungeonGraph
extends Resource

## 副本蓝图数据容器 — 存储节点 + 连线，支持 .tres 序列化

## 蓝图唯一标识
@export var graph_id: String = ""
## 蓝图名称
@export var graph_name: String = ""

## 节点数据: [{type, id, x, y, data: {}}, ...]
@export var nodes: Array[Dictionary] = []
## 连线数据: [{from_node, from_port, to_node, to_port}, ...]
@export var connections: Array[Dictionary] = []


## 添加节点
func add_node(node_type: String, x: float, y: float, data: Dictionary = {}) -> String:
	var id := "%s_%d" % [node_type, nodes.size()]
	nodes.append({
		"type": node_type,
		"id": id,
		"x": x,
		"y": y,
		"data": data
	})
	return id


## 添加连线
func connect_nodes(from_id: String, from_port: int, to_id: String, to_port: int) -> void:
	connections.append({
		"from_node": from_id,
		"from_port": from_port,
		"to_node": to_id,
		"to_port": to_port
	})


## 获取节点数据
func get_node(id: String) -> Dictionary:
	for n in nodes:
		if n.id == id:
			return n
	return {}


## 获取某个节点的所有下游连接
func get_outgoing_connections(node_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for c in connections:
		if c.from_node == node_id:
			result.append(c)
	return result
