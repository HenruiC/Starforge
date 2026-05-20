class_name LockedDoor
extends StaticBody2D

# ==============================
# 锁住的门 — 由 EventBus.door_unlock_requested(door_id) 事件解锁
# 完全可配置：不绑定任何副本、任何坐标、任何 tile 位置
#
# 用法：在任意场景中实例化一个 LockedDoor 节点，填 export 参数即可。
# 门锁 tile 由关卡 map 脚本（如 school_map.gd）在 _draw() 中铺设，
# LockedDoor 只负责"解锁后的 tile 替换"。
# ==============================

## 门的唯一 ID — 与 Objective 的 completion_action.door_id 匹配
@export var door_id: String = ""

## TileMap 引用（通过 NodePath 获取，如 "TileMap" 或 "../SchoolMap/TileMap"）
@export var tilemap_path: NodePath

## 锁门 tile 在 TileSet 中的 source_id（用于擦除时的查找）
@export var lock_source_id: int = 10

## 开门后替换为的地板 tile source_id（设为 -1 表示直接擦除不替换）
@export var unlock_floor_sid: int = 0

## 门占据的 tile 坐标列表（Layer 1, Vector2i 数组）
## 示例：[Vector2i(56, 23), Vector2i(57, 23), ...]
@export var door_tile_positions: Array[Vector2i] = []

## 门是否在场景加载时就阻挡玩家（有碰撞）
@export var blocks_movement: bool = true

## 解锁后是否播放粒子/震动
@export var play_unlock_fx: bool = true

var _is_unlocked: bool = false
var _tm: TileMap


func _ready() -> void:
	print("LOCKED_DOOR: _ready, door_id=", door_id, " tilemap_path=", tilemap_path)
	add_to_group("locked_door")
	if tilemap_path:
		var node := get_node(tilemap_path)
		if node is TileMap:
			_tm = node
	EventBus.door_unlock_requested.connect(_on_unlock_requested)


func _on_unlock_requested(req_door_id: String) -> void:
	print("LOCKED_DOOR: received req=", req_door_id, " my_id=", door_id)
	if req_door_id != door_id or _is_unlocked:
		return
	_is_unlocked = true
	_play_unlock_sequence()


func _play_unlock_sequence() -> void:
	# 1. 震动（可选）
	if play_unlock_fx:
		CombatFeedback.screen_shake(3.0)

	# 2. 擦除 TileMap 中的锁门 tile，替换为地板
	print("LOCKED_DOOR: _tm=", _tm, " door_tile_positions=", door_tile_positions)
	if _tm:
		for pos in door_tile_positions:
			_tm.erase_cell(1, pos)  # 移除锁门（layer 1）
			if unlock_floor_sid >= 0:
				_tm.set_cell(0, pos, unlock_floor_sid, Vector2i(0, 0))  # 铺地板（layer 0）

	# 3. 禁用自身碰撞
	if blocks_movement and has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)

	# 4. 淡出视觉（如果绑定了 sprite）
	if has_node("Sprite"):
		var t := create_tween()
		t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		t.tween_property($Sprite, "modulate:a", 0.0, 0.5)
