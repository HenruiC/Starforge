class_name SchoolMap
extends Node2D

# 学校地图 — 使用Godot原生导入的PNG纹理 + TileMap

const T := 48
const MW := 3200
const MH := 2400

var _tm: TileMap

func _ready() -> void:
	_tm = TileMap.new()
	_tm.name = "TileMap"
	_tm.z_index = 0
	add_child(_tm)

	_build_tileset()
	_draw()
	_tm.set_physics_process(false)
	call_deferred("_deferred_update")

func _build_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)

	# 地板
	var floor_tex := load("res://assets/tiles/floor.png") as Texture2D
	_add_source(ts, 0, floor_tex)

	# 墙壁
	var wall_tex := load("res://assets/tiles/wall.png") as Texture2D
	_add_source(ts, 1, wall_tex)

	# 门
	var door_tex := load("res://assets/tiles/door.png") as Texture2D
	_add_source(ts, 2, door_tex)

	_tm.tile_set = ts
	_tm.add_layer(0)
	_tm.add_layer(1)

func _deferred_update() -> void:
	if is_instance_valid(_tm):
		_tm.update_internals()

func _add_source(ts: TileSet, sid: int, tex: Texture2D) -> void:
	var atlas := TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(T, T)
	atlas.create_tile(Vector2i(0, 0))
	ts.add_source(atlas, sid)

func _draw() -> void:
	var F := Vector2i(0, 0)
	var W := Vector2i(0, 0)
	var D := Vector2i(0, 0)
	var cols := int(ceil(MW / float(T)))
	var rows := int(ceil(MH / float(T)))

	# 全域地板
	for x in cols:
		for y in rows:
			_tm.set_cell(0, Vector2i(x, y), 0, F)

	# 边界围墙
	for x in cols:
		_tm.set_cell(1, Vector2i(x, 0), 1, W)
		_tm.set_cell(1, Vector2i(x, rows - 1), 1, W)
	for y in rows:
		_tm.set_cell(1, Vector2i(0, y), 1, W)
		_tm.set_cell(1, Vector2i(cols - 1, y), 1, W)

	# 校门(南侧, 9格宽)
	@warning_ignore("integer_division")
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

	# 连廊 — 6格宽地板走廊，打通两侧墙壁
	@warning_ignore("integer_division")
	var mid_y := by + lh / 2
	_tm.erase_cell(1, Vector2i(bx + lw - 1, mid_y))
	_tm.erase_cell(1, Vector2i(rx, mid_y))
	for x in range(gx - 3, gx + 3):
		_tm.set_cell(0, Vector2i(x, mid_y), 0, F)

	# Boss间 (12格深)
	var gy := by - 18
	_building(gx - 9, gy, 18, 12, W, D, "")

	# 标签
	_label(gx, rows - 1, "▼ 校门", Color.GOLD)
	_label(gx, rows - 14, "操场", Color(0.3, 0.8, 0.3))
	_label(gx, gy + 11, "Boss间", Color(1.0, 0.2, 0.1))

func _building(x: int, y: int, bw: int, bh: int, W: Vector2i, D: Vector2i, label_name: String) -> void:
	# 围墙 (layer 1)
	for xx in range(x, x + bw):
		_tm.set_cell(1, Vector2i(xx, y), 1, W)
		_tm.set_cell(1, Vector2i(xx, y + bh - 1), 1, W)
	for yy in range(y, y + bh):
		_tm.set_cell(1, Vector2i(x, yy), 1, W)
		_tm.set_cell(1, Vector2i(x + bw - 1, yy), 1, W)

	# 内部地板填充 (layer 0)
	for xx in range(x + 1, x + bw - 1):
		for yy in range(y + 1, y + bh - 1):
			_tm.set_cell(0, Vector2i(xx, yy), 0, Vector2i(0, 0))

	# 门洞 — 擦除南墙中央5格墙壁，放置门 tile
	@warning_ignore("integer_division")
	var mx := x + bw / 2
	for dx in range(-2, 3):
		_tm.erase_cell(1, Vector2i(mx + dx, y + bh - 1))
		_tm.set_cell(1, Vector2i(mx + dx, y + bh - 1), 2, D)

	if label_name:
		@warning_ignore("integer_division")
		_label(mx, y + bh / 2, label_name, Color(0.8, 0.7, 0.2))
		# 教室内柱子 — 4个2x2掩体
		_pillar(x + 4, y + 4)
		_pillar(x + bw - 6, y + 4)
		_pillar(x + 4, y + bh - 6)
		_pillar(x + bw - 6, y + bh - 6)

func _pillar(px: int, py: int) -> void:
	for dx in range(2):
		for dy in range(2):
			_tm.set_cell(1, Vector2i(px + dx, py + dy), 1, Vector2i(0, 0))

func _label(tx: int, ty: int, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", color)
	l.position = Vector2(tx * T - 30, ty * T - 6)
	l.size = Vector2(120, 18)
	l.z_index = 10
	add_child(l)
