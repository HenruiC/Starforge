class_name MapSchool
extends Node2D

# 学校副本地图 — 关卡策划+陶德监修
# 区域: 教室/走廊/操场/校门
# 可破坏物类型: 墙壁(阻挡)/门(可通行)/窗(弹幕穿透)/课桌(可穿过)

const TILE := 48
const MAP_W := 3200
const MAP_H := 2400

var _wall_prefab: PackedScene = preload("res://scenes/wall.tscn")
var _door_prefab: PackedScene = preload("res://scenes/door.tscn")
var _desk_prefab: PackedScene = preload("res://scenes/desk.tscn")
var _tree_prefab: PackedScene = preload("res://scenes/destructible.tscn")

func _ready() -> void:
	_build_school()

func _build_school() -> void:
	# === 外围围墙 ===
	_draw_rect_walls(0, 0, MAP_W, MAP_H)

	# === 教学楼 (中央偏上) ===
	var bx := 600; var by := 400
	var bw := 2000; var bh := 1200

	# 教学楼外墙 (每隔一段留门口)
	_draw_wall_line(bx, by, bx + bw, by)       # 上
	_draw_wall_line(bx, by, bx, by + bh)       # 左
	_draw_wall_line(bx, by + bh, bx + bw, by + bh)  # 下
	_draw_wall_line(bx + bw, by, bx + bw, by + bh)  # 右

	# 正门 (下墙中间)
	_place_door(bx + bw / 2, by + bh)

	# === 内部走廊 (十字形) ===
	var mid_x := bx + bw / 2
	var mid_y := by + bh / 2

	# 水平走廊墙
	_draw_wall_line(bx + 100, mid_y - 80, bx + 400, mid_y - 80)
	_draw_wall_line(bx + 600, mid_y - 80, bx + 900, mid_y - 80)
	_draw_wall_line(bx + 1100, mid_y - 80, bx + 1400, mid_y - 80)
	_draw_wall_line(bx + 1600, mid_y - 80, bx + bw - 100, mid_y - 80)
	_draw_wall_line(bx + 100, mid_y + 80, bx + 400, mid_y + 80)
	_draw_wall_line(bx + 600, mid_y + 80, bx + 900, mid_y + 80)
	_draw_wall_line(bx + 1100, mid_y + 80, bx + 1400, mid_y + 80)
	_draw_wall_line(bx + 1600, mid_y + 80, bx + bw - 100, mid_y + 80)

	# 垂直走廊墙
	_draw_wall_line(mid_x - 80, by + 100, mid_x - 80, mid_y - 100)
	_draw_wall_line(mid_x + 80, by + 100, mid_x + 80, mid_y - 100)
	_draw_wall_line(mid_x - 80, mid_y + 100, mid_x - 80, by + bh - 100)
	_draw_wall_line(mid_x + 80, mid_y + 100, mid_x + 80, by + bh - 100)

	# 教室门 (走廊→教室)
	_place_door(bx + 250, mid_y - 80)   # 左上教室
	_place_door(bx + 750, mid_y - 80)   # 中上教室
	_place_door(bx + 1250, mid_y - 80)  # 右上教室
	_place_door(bx + 250, mid_y + 80)   # 左下教室
	_place_door(bx + 750, mid_y + 80)   # 中下教室
	_place_door(bx + 1250, mid_y + 80)  # 右下教室

	# === 教室内课桌 ===
	_place_desks_in_room(bx + 50, by + 50, bx + 380, mid_y - 120, 4, 3)
	_place_desks_in_room(bx + 500, by + 50, bx + 880, mid_y - 120, 5, 3)
	_place_desks_in_room(bx + 1000, by + 50, bx + 1380, mid_y - 120, 5, 3)
	_place_desks_in_room(bx + 50, mid_y + 120, bx + 380, by + bh - 50, 4, 3)
	_place_desks_in_room(bx + 500, mid_y + 120, bx + 880, by + bh - 50, 5, 3)
	_place_desks_in_room(bx + 1000, mid_y + 120, bx + 1380, by + bh - 50, 5, 3)

	# === 操场 (建筑物外部) ===
	_place_trees_around(bx - 200, by + bh + 100, bw + 400, MAP_H - (by + bh) - 200, 8)
	_place_trees_around(bx + bw + 100, by, MAP_W - (bx + bw) - 200, bh, 5)
	_place_trees_around(100, by, bx - 200, bh, 5)

	# 校门(下围墙中间)
	_place_door(MAP_W / 2, MAP_H)

func _draw_rect_walls(x1: float, y1: float, x2: float, y2: float) -> void:
	# 四周有间隙的围墙(四角留空做入口感)
	var gap := 120
	# 上
	_draw_wall_line(x1 + gap, y1, x2 - gap, y1)
	# 下 (中间留大门)
	_draw_wall_line(x1, y2, MAP_W / 2 - 80, y2)
	_draw_wall_line(MAP_W / 2 + 80, y2, x2, y2)
	# 左
	_draw_wall_line(x1, y1 + gap, x1, y2 - gap)
	# 右
	_draw_wall_line(x2, y1 + gap, x2, y2 - gap)

func _draw_wall_line(x1: float, y1: float, x2: float, y2: float) -> void:
	var dist := Vector2(x2 - x1, y2 - y1).length()
	var dir := Vector2(x2 - x1, y2 - y1).normalized()
	var step := TILE
	var pos := Vector2(x1, y1)
	var traveled := 0.0

	while traveled < dist:
		var w := _wall_prefab.instantiate()
		w.global_position = pos
		add_child(w)
		pos += dir * step
		traveled += step

func _place_door(x: float, y: float) -> void:
	var d := _door_prefab.instantiate()
	d.global_position = Vector2(x, y)
	add_child(d)

func _place_desks_in_room(x1: float, y1: float, x2: float, y2: float, cols: int, rows: int) -> void:
	var rw := x2 - x1; var rh := y2 - y1
	var spacing_x := rw / float(cols + 1)
	var spacing_y := rh / float(rows + 1)
	for c in cols:
		for r in rows:
			var d := _desk_prefab.instantiate()
			d.global_position = Vector2(x1 + spacing_x * float(c + 1), y1 + spacing_y * float(r + 1))
			add_child(d)

func _place_trees_around(x: float, y: float, w: float, h: float, count: int) -> void:
	for i in count:
		var t := _tree_prefab.instantiate()
		t.object_name = "树"; t.max_health = 20; t.drop_xp = 15
		t.object_color = Color(0.15, 0.55, 0.15, 1.0)
		t.global_position = Vector2(randf_range(x, x + w), randf_range(y, y + h))
		add_child(t)
