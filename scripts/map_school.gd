class_name MapSchool
extends Node2D

# 学校副本 — 宫崎英高重设计 v2
# 动线: 校门→操场→教学楼→走廊→教室群→Boss间
# 间距: TILE=48px 基准网格

const T := 48
const MW := 3200; const MH := 2400

var _w: PackedScene = preload("res://scenes/wall.tscn")
var _b: PackedScene = preload("res://scenes/boundary.tscn")
var _d: PackedScene = preload("res://scenes/door.tscn")
var _dk: PackedScene = preload("res://scenes/desk.tscn")
var _tr: PackedScene = preload("res://scenes/destructible.tscn")

func _ready() -> void: _build()

func _build() -> void:
	# ===== 边界 =====
	_rect(_b, 0, 0, MW, MH)

	# ===== 校门 (底部中央) =====
	var gx := MW/2
	_h(_w, gx-5*T, MH-T, gx-3*T, MH-T)
	_h(_w, gx+3*T, MH-T, gx+5*T, MH-T)
	_door(gx, MH-T, Color(0.9,0.7,0.2,0.9))
	_label(gx-40, MH-T-20, "校门 ▼", Color(0.7,0.7,0.3))

	# ===== 操场 (底部1/3) =====
	for i in 10:
		var tx := randf_range(3*T, MW-3*T)
		var ty := randf_range(MH-10*T, MH-2*T)
		if abs(tx-gx) < 4*T: continue  # 不挡主干道
		_tree(tx, ty)
	_label(gx-60, MH-7*T, "操场", Color(0.3,0.8,0.3))

	# ===== 教学楼 (中部) =====
	var bx := 8*T; var by := MH-16*T
	var bw := 50*T; var bh := 11*T  # 2400x528

	_h(_w, bx, by, bx+bw, by)
	_h(_w, bx, by, bx, by+bh)
	_h(_w, bx+bw, by, bx+bw, by+bh)

	# 教学楼正门 (下墙中央)
	_door(bx+bw/2, by+bh, Color(0.3,0.5,1.0,0.9))
	_label(bx+bw/2-60, by+bh+12, "教学楼 ▲", Color(0.8,0.7,0.3))

	# 玄关隔断
	var ox := bx+16*T; var ow := 18*T
	_h(_w, ox, by, ox, by+bh-4*T)
	_h(_w, ox+ow, by, ox+ow, by+bh-4*T)
	_door(ox, by+bh-4*T, Color(0.3,0.5,1.0,0.9))
	_door(ox+ow, by+bh-4*T, Color(0.3,0.5,1.0,0.9))
	_label(bx+bw/2-30, by+bh/2, "玄关", Color(0.6,0.5,0.2))

	# ===== 走廊 (教学楼上方) =====
	var cy := by + 6*T  # 走廊中心Y
	_h(_w, bx+4*T, cy-2*T, bx+bw-4*T, cy-2*T)
	_h(_w, bx+4*T, cy+2*T, bx+bw-4*T, cy+2*T)

	# 走廊入口(下方玄关→走廊)
	_h(_w, ox+T, cy-2*T, ox+T, cy+2*T)  # 小隔
	_h(_w, ox+ow-T, cy-2*T, ox+ow-T, cy+2*T)
	_door(bx+10*T, cy, Color(0.2,0.8,0.2,0.9))
	_door(bx+bw-10*T, cy, Color(0.2,0.8,0.2,0.9))
	_label(bx+bw/2-40, cy-16, "走廊", Color(0.7,0.5,0.1))

	# ===== 教室群 (走廊两侧) =====
	# 上排3间
	_room(bx+4*T, by+T, bx+18*T, cy-3*T, "A", 4, 2)
	_room(bx+19*T, by+T, bx+31*T, cy-3*T, "B", 4, 2)
	_room(bx+32*T, by+T, bx+bw-4*T, cy-3*T, "C", 3, 2)
	# 下排3间(走廊下方到玄关隔墙)
	_room(bx+4*T, cy+3*T, bx+18*T, by+bh-T, "D", 4, 2)
	_room(bx+19*T, cy+3*T, bx+31*T, by+bh-T, "E", 4, 2)
	_room(bx+32*T, cy+3*T, bx+bw-4*T, by+bh-T, "F", 3, 2)

	# ===== Boss间 (最上方) =====
	var bbx := bx+8*T; var bby := by-3*T; var bbw := 34*T; var bbh := 4*T
	_h(_w, bbx, bby, bbx+bbw, bby)
	_h(_w, bbx, bby, bbx, bby+bbh)
	_h(_w, bbx+bbw, bby, bbx+bbw, bby+bbh)
	_h(_w, bbx+4*T, bby+bbh, bbx+bbw-4*T, bby+bbh)
	_door(bbx+bbw/2, bby+bbh, Color(1.0,0.2,0.1,0.9))
	_label(bbx+bbw/2-80, bby-24, "⚠ Boss间", Color(1.0,0.2,0.1))

	# 操场边缘树
	for i in 5:
		_tree(randf_range(bx+2*T,bx+bw-2*T), randf_range(by+bh+T, MH-2*T))
		_tree(randf_range(bx-T,bx), randf_range(by, by+bh))
		_tree(randf_range(bx+bw, bx+bw+T), randf_range(by, by+bh))


# ===== 工具 =====
func _rect(p: PackedScene, x1: float, y1: float, x2: float, y2: float) -> void:
	_h(p, x1, y1, x2, y1); _h(p, x1, y1, x1, y2)
	_h(p, x1, y2, x2, y2); _h(p, x2, y1, x2, y2)

func _h(p: PackedScene, x1: float, y1: float, x2: float, y2: float) -> void:
	var dist := Vector2(x2-x1, y2-y1).length()
	var dir := Vector2(x2-x1, y2-y1).normalized()
	var pos := Vector2(x1, y1); var done := 0.0
	while done < dist - 1:
		var o := p.instantiate(); o.global_position = pos
		add_child(o); pos += dir * T; done += T

func _door(x: float, y: float, c: Color) -> void:
	var d := _d.instantiate(); d.global_position = Vector2(x, y); add_child(d)
	var sp := d.get_node_or_null("Sprite") as ColorRect
	if sp: sp.color = c; sp.scale = Vector2(1.8, 1.0)

func _tree(x: float, y: float) -> void:
	var t := _tr.instantiate()
	t.object_name = "树"; t.max_health = 20; t.drop_xp = 15
	t.object_color = Color(0.15,0.55,0.15,1.0)
	t.global_position = Vector2(x, y); add_child(t)

func _room(x1: float, y1: float, x2: float, y2: float, nm: String, cs: int, rs: int) -> void:
	_h(_w, x1, y1, x2, y1)
	_h(_w, x1, y1, x1, y2)
	_h(_w, x2, y1, x2, y2)
	# 下墙留4格门洞
	var mx := (x1+x2)/2
	_h(_w, x1, y2, mx-2*T, y2)
	_h(_w, mx+2*T, y2, x2, y2)
	_door(mx, y2, Color(0.8,0.8,0.1,0.9))
	_label(mx-40, y2+16, nm, Color(0.9,0.7,0.2))
	# 课桌
	for c in cs:
		for r in rs:
			var dk := _dk.instantiate()
			dk.global_position = Vector2(x1+(x2-x1)/float(cs+1)*float(c+1), y1+(y2-y1)/float(rs+1)*float(r+1))
			add_child(dk)

func _label(x: float, y: float, t: String, c: Color) -> void:
	var l := Label.new(); l.text = t
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", c)
	l.position = Vector2(x, y); l.size = Vector2(160, 18)
	add_child(l)
