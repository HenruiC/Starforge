class_name NavManager
extends Node2D

# 导航系统 — 马斯克/罗梅罗联合实现
# 基于NavigationRegion2D烘焙可行走区域，敌人用NavigationAgent2D寻路

var _nav_region: NavigationRegion2D
var _baked: bool = false

func _ready() -> void:
	_setup_navigation()

func _setup_navigation() -> void:
	_nav_region = NavigationRegion2D.new()
	_nav_region.name = "NavRegion"

	# 导航多边形覆盖整个地图(3200x2400)
	var nav_poly := NavigationPolygon.new()
	var outline := PackedVector2Array([
		Vector2(48, 48), Vector2(3152, 48),
		Vector2(3152, 2352), Vector2(48, 2352)
	])
	nav_poly.add_outline(outline)
	nav_poly.make_polygons_from_outlines()
	_nav_region.navigation_polygon = nav_poly
	add_child(_nav_region)

	# 等物理体加载完成后烘焙
	call_deferred("_bake_nav")

func _bake_nav() -> void:
	# 等一帧确保所有wall/door的StaticBody2D已加载
	await get_tree().process_frame
	if _nav_region:
		_nav_region.bake_navigation_polygon()
		_baked = true

# 获取玩家附近的可导航位置(敌人生成用)
func get_random_nav_point(near: Vector2, min_dist: float = 500, max_dist: float = 700) -> Vector2:
	for attempt in 30:
		var angle := randf_range(0, TAU)
		var dist := randf_range(min_dist, max_dist)
		var pos := near + Vector2(cos(angle) * dist, sin(angle) * dist)
		if pos.x < 100 or pos.x > 3100 or pos.y < 100 or pos.y > 2300: continue
		# 检查教学楼区域
		var bx := 6.0 * 48.0; var by := 2400.0 - 18.0 * 48.0
		var bw := 54.0 * 48.0; var bh := 13.0 * 48.0
		if pos.x > bx and pos.x < bx + bw and pos.y > by and pos.y < by + bh: continue
		return pos
	return near + Vector2(randf_range(-600, 600), randf_range(-600, 600))
