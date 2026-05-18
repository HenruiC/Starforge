class_name SchoolMap
extends Node2D

# 学校地图 — 使用Godot原生导入的PNG纹理 + TileMap
# 卡马克: "PNG是Godot一等公民。load()直接可用。"

const T := 48
const MW := 3200
const MH := 2400

var _tm: TileMap

func _ready() -> void:
	_tm = TileMap.new()
	_tm.name = "TileMap"
	_tm.z_index = -5
	add_child(_tm)

	_build_tileset()
	_draw()
	_tm.update_internals()

func _build_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)

	# 地板: 深灰
	var floor_tex := load("res://assets/tiles/floor.png") as Texture2D
	_add_source(ts, 0, floor_tex)

	# 墙壁: 棕色
	var wall_tex := load("res://assets/tiles/wall.png") as Texture2D
	_add_source(ts, 1, wall_tex)

	# 门: 绿色
	var door_tex := load("res://assets/tiles/door.png") as Texture2D
	_add_source(ts, 2, door_tex)

	_tm.tile_set = ts
	_tm.add_layer(1)

func _add_source(ts: TileSet, sid: int, tex: Texture2D) -> void:
	var atlas := TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(T, T)
	atlas.create_tile(Vector2i(0, 0))
	ts.add_source(atlas, sid)

func _draw() -> void:
	var F := Vector2i(0, 0)
	var W := Vector2i(1, 0)
	var D := Vector2i(2, 0)
	var cols := int(ceil(MW / float(T)))
	var rows := int(ceil(MH / float(T)))

	# 全域地板
	for x in cols:
		for y in rows:
			_tm.set_cell(0, Vector2i(x, y), 0, F)

	# 边界
	for x in cols:
		_tm.set_cell(1, Vector2i(x, 0), 1, W)
		_tm.set_cell(1, Vector2i(x, rows - 1), 1, W)
	for y in rows:
		_tm.set_cell(1, Vector2i(0, y), 1, W)
		_tm.set_cell(1, Vector2i(cols - 1, y), 1, W)

	# 校门(南侧, 8格宽)
	var gx := cols / 2
	for dx in range(-4, 5):
		_tm.set_cell(1, Vector2i(gx + dx, rows - 1), 2, D)

	# 教学楼左(A翼)
	var bx := 8
	var by := rows - 26
	var lw := 18
	var lh := 18
	_building(bx, by, lw, lh, W, D, "左楼")
	# 教学楼右(B翼)
	var rx := gx + 6
	_building(rx, by, lw, lh, W, D, "右楼")

	# 连廊
	var mid_y := by + lh / 2
	for x in range(bx + lw - 2, rx + 4):
		_tm.set_cell(0, Vector2i(x, mid_y), 2, D)

	# Boss间
	var gy := by - 14
	_building(gx - 9, gy, 18, 8, W, D, null)
	for dx in range(-4, 5):
		_tm.set_cell(1, Vector2i(gx + dx, gy + 8), 2, D)

	# 标签
	_label(gx, rows - 1, "▼ 校门", Color.GOLD)
	_label(gx, rows - 14, "操场", Color(0.3, 0.8, 0.3))
	_label(gx, gy + 9, "Boss间", Color(1.0, 0.2, 0.1))

func _building(x: int, y: int, bw: int, bh: int, W: Vector2i, D: Vector2i, name: String) -> void:
	for xx in range(x, x + bw):
		_tm.set_cell(1, Vector2i(xx, y), 1, W)
		_tm.set_cell(1, Vector2i(xx, y + bh - 1), 1, W)
	for yy in range(y, y + bh):
		_tm.set_cell(1, Vector2i(x, yy), 1, W)
		_tm.set_cell(1, Vector2i(x + bw - 1, yy), 1, W)
	# 门洞
	var mx := x + bw / 2
	for xx in range(x, mx - 2):
		_tm.set_cell(0, Vector2i(xx, y + bh - 1), 0, Vector2i(0, 0))
	for dx in range(-2, 3):
		_tm.set_cell(1, Vector2i(mx + dx, y + bh - 1), 2, D)
	for xx in range(mx + 3, x + bw):
		_tm.set_cell(0, Vector2i(xx, y + bh - 1), 0, Vector2i(0, 0))
	if name:
		_label(mx, y + bh / 2, name, Color(0.8, 0.7, 0.2))

func _label(tx: int, ty: int, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", color)
	l.position = Vector2(tx * T - 30, ty * T - 6)
	l.size = Vector2(120, 18)
	l.z_index = 10
	add_child(l)
