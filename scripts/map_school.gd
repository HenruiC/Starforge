class_name MapSchool
extends Node2D

# 学校副本 — 线性流程: 校门→操场→玄关→走廊→教室→Boss间
# 设计: 宫崎英高 / 监修: 陶德

const TILE := 48
const MW := 3200; const MH := 2400

var _wall: PackedScene = preload("res://scenes/wall.tscn")
var _boundary: PackedScene = preload("res://scenes/boundary.tscn")
var _door: PackedScene = preload("res://scenes/door.tscn")
var _desk: PackedScene = preload("res://scenes/desk.tscn")
var _tree: PackedScene = preload("res://scenes/destructible.tscn")

func _ready() -> void:
	_build()

func _build() -> void:
	# ===== 不可破坏边界 =====
	_rect(_boundary, 0, 0, MW, MH)

	# ===== 区域1: 校门前空地 + 操场 (底部) =====
	# 校门两侧围墙
	_h_line(_wall, 0, MH-120, MW/2-120, MH-120)
	_h_line(_wall, MW/2+120, MH-120, MW, MH-120)
	_place_door(MW/2, MH-120, "校门")
	_add_label(MW/2-80, MH-100, "▼ 校门", Color(0.5,0.5,0.5))

	# 操场区域(开阔地+树, 避开主干道)
	# 主干道: 校门→教学楼入口 (MW/2, MH-120 → bx+bw/2, by+bh)
	for i in 8:
		var tx: float; var ty: float
		while true:
			tx = randf_range(400, MW-400)
			ty = randf_range(MH-400, MH-160)
			# 不挡在主干道(校门到教学楼入口)
			if abs(tx - MW/2) < 120 and ty > MH-300: continue
			break
		_place_tree(tx, ty)
	_add_label(MW/2-60, MH-300, "操场 · 第一试炼", Color(0.3,0.8,0.3))

	# ===== 区域2: 教学楼玄关 (中下部) =====
	var bx := 800; var by := MH-600; var bw := 1600; var bh := 400

	# 教学楼外墙
	_h_line(_wall, bx, by, bx+bw, by)
	_h_line(_wall, bx, by, bx, by+bh)
	_h_line(_wall, bx+bw, by, bx+bw, by+bh)

	# 正门(下墙中间)
	_place_door(bx+bw/2, by+bh, "教学楼入口")
	_add_label(bx+bw/2-80, by+bh+16, "教学楼入口 ▲", Color(0.8,0.7,0.3))

	# 玄关区域(下墙留出口通向上方走廊)
	# 左右墙延伸形成玄关
	_h_line(_wall, bx+400, by, bx+400, by+bh-120)  # 左隔墙
	_h_line(_wall, bx+bw-400, by, bx+bw-400, by+bh-120)  # 右隔墙
	_place_door(bx+400, by+bh-120, "")
	_place_door(bx+bw-400, by+bh-120, "")

	_add_label(bx+bw/2-60, by+bh/2-12, "玄关", Color(0.7,0.6,0.3))

	# ===== 区域3: 走廊 (中间) =====
	var cy := by - 300  # 走廊Y坐标

	# 走廊两侧墙壁
	_h_line(_wall, bx, cy-80, bx+bw, cy-80)
	_h_line(_wall, bx, cy+80, bx+bw, cy+80)

	# 走廊两端门
	_place_door(bx+60, cy, "")
	_place_door(bx+bw-60, cy, "")

	_add_label(bx+bw/2-40, cy-12, "走廊 · 第二试炼", Color(0.8,0.6,0.2))

	# ===== 区域4: 教室区 (中上部, 走廊两侧) =====
	# 上排教室
	_room(bx+20, cy-280, bx+500, cy-100, "教室A", 3, 2)
	_room(bx+540, cy-280, bx+1060, cy-100, "教室B", 4, 2)
	_room(bx+1100, cy-280, bx+bw-20, cy-100, "教室C", 3, 2)
	# 下排教室
	_room(bx+20, cy+100, bx+500, cy+280, "教室D", 3, 2)
	_room(bx+540, cy+100, bx+1060, cy+280, "教室E", 4, 2)
	_room(bx+1100, cy+100, bx+bw-20, cy+280, "教室F", 3, 2)

	# ===== 区域5: Boss房间 (最上部) =====
	var bbx := bx+300; var bby := cy-500; var bbw := bw-600; var bbh := 200
	_h_line(_wall, bbx, bby, bbx+bbw, bby)
	_h_line(_wall, bbx, bby, bbx, bby+bbh)
	_h_line(_wall, bbx+bbw, bby, bbx+bbw, bby+bbh)

	# Boss间门(下方)
	_place_door(bbx+bbw/2, bby+bbh, "Boss间")

	_add_label(bbx+bbw/2-60, bby-20, "⚠ Boss间 · 第三试炼", Color(1.0,0.2,0.1))

	# ===== 树散布在建筑外区域 =====
	for i in 4:
		_place_tree(randf_range(100,bx-100), randf_range(by,by+bh))
		_place_tree(randf_range(bx+bw+100,MW-100), randf_range(by,by+bh))
		_place_tree(randf_range(bx,bx+bw), randf_range(by+bh+50,MH-200))


# === 工具函数 ===
func _rect(prefab: PackedScene, x1: float, y1: float, x2: float, y2: float) -> void:
	_h_line(prefab, x1, y1, x2, y1)
	_h_line(prefab, x1, y1, x1, y2)
	_h_line(prefab, x1, y2, x2, y2)
	_h_line(prefab, x2, y1, x2, y2)

func _h_line(prefab: PackedScene, x1: float, y1: float, x2: float, y2: float) -> void:
	var dist := Vector2(x2-x1, y2-y1).length()
	var dir := Vector2(x2-x1, y2-y1).normalized()
	var pos := Vector2(x1, y1); var traveled := 0.0
	while traveled < dist:
		var w := prefab.instantiate(); w.global_position = pos
		add_child(w); pos += dir * TILE; traveled += TILE

func _place_door(x: float, y: float, label: String = "") -> void:
	var d := _door.instantiate(); d.global_position = Vector2(x, y)
	add_child(d)

func _place_tree(x: float, y: float) -> void:
	var t := _tree.instantiate()
	t.object_name = "树"; t.max_health = 20; t.drop_xp = 15
	t.object_color = Color(0.15,0.55,0.15,1.0)
	t.global_position = Vector2(x, y); add_child(t)

func _room(x1: float, y1: float, x2: float, y2: float, name: String, cols: int, rows: int) -> void:
	_h_line(_wall, x1, y1, x2, y1)
	_h_line(_wall, x1, y1, x1, y2)
	_h_line(_wall, x2, y1, x2, y2)
	_h_line(_wall, x1, y2, x2, y2)
	# 教室门(下墙)
	_place_door((x1+x2)/2, y2, name)
	# 课桌
	var rw := x2-x1; var rh := y2-y1
	for c in cols:
		for r in rows:
			var d := _desk.instantiate()
			d.global_position = Vector2(x1+rw/float(cols+1)*float(c+1), y1+rh/float(rows+1)*float(r+1))
			add_child(d)

func _add_label(x: float, y: float, text: String, color: Color) -> void:
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", color)
	l.position = Vector2(x, y); l.size = Vector2(200, 20)
	add_child(l)
