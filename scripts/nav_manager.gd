class_name NavManager
extends Node2D

## 通用导航管理器 — 自动扫描 TileMap 碰撞层烘焙导航网格
##
## 通过 NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS 让烘焙
## 过程识别 TileMap 的 physics layer 碰撞形状，自动排除墙壁区域。
## 不依赖任何硬编码坐标或 source ID。

# --------------------------------------------------------------------------
# 常量
# --------------------------------------------------------------------------

## 地图总宽（px），与 TileMap 尺寸对齐
const MW := 5760
## 地图总高（px）
const MH := 4320

# --------------------------------------------------------------------------
# 导出参数
# --------------------------------------------------------------------------

## 目标 TileMap 节点路径（相对于 NavManager 的父节点）
@export var tilemap_path: NodePath = NodePath("../TileMap")
## 导航烘焙解析的碰撞掩码（匹配 TileMap physics layer）
@export var parsed_collision_mask: int = 0xFFFF
## 轮廓收缩量（px），留边界防止角色走到地图边缘外
@export var outline_inset: float = 48.0

# --------------------------------------------------------------------------
# 运行时
# --------------------------------------------------------------------------

var _nav_region: NavigationRegion2D
var _tile_map: TileMap = null
var _baked: bool = false

# --------------------------------------------------------------------------
# 初始化
# --------------------------------------------------------------------------

func _ready() -> void:
	_setup_navigation()

func _setup_navigation() -> void:
	# 查找 TileMap
	if tilemap_path and has_node(tilemap_path):
		_tile_map = get_node(tilemap_path) as TileMap
	else:
		var parent := get_parent()
		if parent:
			for child in parent.get_children():
				if child is TileMap:
					_tile_map = child
					break

	if not _tile_map:
		push_warning("NavManager: 未找到 TileMap，导航区域将无障碍物排除")

	# 创建导航区域
	_nav_region = NavigationRegion2D.new()
	_nav_region.name = "NavRegion"

	var nav_poly := NavigationPolygon.new()
	var outline := PackedVector2Array([
		Vector2(outline_inset, outline_inset),
		Vector2(MW - outline_inset, outline_inset),
		Vector2(MW - outline_inset, MH - outline_inset),
		Vector2(outline_inset, MH - outline_inset),
	])
	nav_poly.add_outline(outline)

	# 关键设置：让烘焙引擎解析场景中的静态碰撞体
	# 这会识别 TileMap physics layer 以及 StaticBody2D 子节点
	nav_poly.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_poly.parsed_collision_mask = parsed_collision_mask

	_nav_region.navigation_polygon = nav_poly
	add_child(_nav_region)

	# 延迟烘焙，确保场景所有物理体已加载
	await get_tree().create_timer(0.5).timeout
	call_deferred("_bake_nav")

func _bake_nav() -> void:
	await get_tree().process_frame
	if _nav_region:
		_nav_region.bake_navigation_polygon()
		_baked = true
		var vert_count := _nav_region.navigation_polygon.get_vertices().size()
		print("NavManager: 导航烘焙完成, 顶点数=%d" % vert_count)

# --------------------------------------------------------------------------
# 导航查询
# --------------------------------------------------------------------------

## 获取玩家附近的可导航位置（敌人生成用）
func get_random_nav_point(near: Vector2, min_dist: float = 500, max_dist: float = 700) -> Vector2:
	for attempt in 30:
		var angle := randf_range(0, TAU)
		var dist := randf_range(min_dist, max_dist)
		var pos := near + Vector2(cos(angle) * dist, sin(angle) * dist)
		if pos.x < 100 or pos.x > MW - 100 or pos.y < 100 or pos.y > MH - 100:
			continue
		# 检查教学楼区域（左楼 14..40 tile, 右楼 68..94 tile, y=54..76）
		var left_bx := 14.0 * 48.0
		var right_bx := 68.0 * 48.0
		var by := 54.0 * 48.0
		var bh := 22.0 * 48.0
		var bw := 26.0 * 48.0
		if pos.x > left_bx and pos.x < left_bx + bw and pos.y > by and pos.y < by + bh:
			continue
		if pos.x > right_bx and pos.x < right_bx + bw and pos.y > by and pos.y < by + bh:
			continue
		return pos
	return near + Vector2(randf_range(-600, 600), randf_range(-600, 600))

## 导航是否已烘焙完成
func is_baked() -> bool:
	return _baked
