class_name TilemapBuilder
extends Node2D

# 场景系统 — 运行时生成TileMap, 纯色图块, 不依赖外部图片

const T := 48; const MW := 3200; const MH := 2400
var tm: TileMap

func _ready() -> void:
	tm = TileMap.new(); tm.name = "TileMap"
	tm.z_index = -5; add_child(tm)
	_setup_tiles(); _draw_all()

func _setup_tiles() -> void:
	var ts := TileSet.new(); ts.tile_size = Vector2i(T, T)
	_add_color_tile(ts, 0, Color(0.12, 0.12, 0.16))  # 地板: 深灰
	_add_color_tile(ts, 1, Color(0.35, 0.30, 0.25))  # 墙壁: 棕色
	_add_color_tile(ts, 2, Color(0.2, 0.75, 0.2))   # 门: 绿色
	tm.tile_set = ts; tm.add_layer(1)

func _add_color_tile(ts: TileSet, source_id: int, color: Color) -> void:
	# 优先用AssetLoader加载真纹理, 失败则纯色
	var tex_name := ""
	match source_id:
		0: tex_name = "floor_tile"
		1: tex_name = "wall_tile"
		2: tex_name = "door_tile"
	var tex := AssetLoader.texture(tex_name, T, color)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(T, T)
	atlas.create_tile(Vector2i(0, 0))
	ts.add_source(atlas, source_id)

func _draw_all() -> void:
	var F := Vector2i(0, 0); var W := Vector2i(1, 0); var D := Vector2i(2, 0)
	var cols := int(MW / T) + 1; var rows := int(MH / T) + 1

	# 全局地板
	for x in cols: for y in rows: tm.set_cell(0, Vector2i(x, y), 0, F)

	# 边界围墙
	for x in range(0, cols): tm.set_cell(1, Vector2i(x, 0), 1, W)
	for x in range(0, cols): tm.set_cell(1, Vector2i(x, rows - 1), 1, W)
	for y in range(0, rows): tm.set_cell(1, Vector2i(0, y), 1, W)
	for y in range(0, rows): tm.set_cell(1, Vector2i(cols - 1, y), 1, W)

	# 校门(南侧中央, 6格宽)
	var gx := cols / 2
	for dx in range(-3, 4): tm.set_cell(1, Vector2i(gx + dx, rows - 1), 2, D)

	# 主干道(校门→北, 4格宽)
	for y in range(rows - 18, rows - 1):
		for dx in range(-2, 3): tm.set_cell(0, Vector2i(gx + dx, y), 0, F)

	# 教学楼左右两栋
	var bx := 8; var by := rows - 26; var bw := 14; var bh := 18
	var rx := gx + 4; var ry2 := by

	_building(bx, by, bw, bh, W, D)
	_building(rx, ry2, bw, bh, W, D)

	# 中央庭院(两楼之间)
	for x in range(bx + bw, rx):
		for y in range(by + 2, by + bh - 2):
			tm.set_cell(0, Vector2i(x, y), 0, F)
	_label(gx, by + bh / 2, "中央庭院")

	# 连廊(两楼之间通道)
	var conn_y := by + bh / 2
	for x in range(bx + bw - 2, rx + 4):
		tm.set_cell(0, Vector2i(x, conn_y), 2, D)

	# 北侧通道(通往体育馆)
	for y in range(by - 8, by):
		for dx in range(-2, 3): tm.set_cell(0, Vector2i(gx + dx, y), 0, F)

	# Boss间体育馆(北侧)
	var gym_y := by - 14; var gym_w := 14
	_building(gx - gym_w / 2, gym_y, gym_w, 8, W, D)
	for dx in range(-3, 4): tm.set_cell(1, Vector2i(gx + dx, gym_y + 8), 2, D)
	_label(gx, gym_y - 1, "Boss间")

	# 区域标签
	_label(gx, rows - 1, "校门"); _label(gx, rows - 12, "操场")
	_label(bx + bw / 2, by + bh / 2, "左楼"); _label(rx + bw / 2, ry2 + bh / 2, "右楼")
	_label(gx, gym_y + 9, "体育馆")

	# 强制刷新TileMap渲染
	tm.update_internals()

func _building(x: int, y: int, bw: int, bh: int, W: Vector2i, D: Vector2i) -> void:
	for xx in range(x, x + bw):
		tm.set_cell(1, Vector2i(xx, y), 1, W)
		tm.set_cell(1, Vector2i(xx, y + bh - 1), 1, W)
	for yy in range(y, y + bh):
		tm.set_cell(1, Vector2i(x, yy), 1, W)
		tm.set_cell(1, Vector2i(x + bw - 1, yy), 1, W)
	# 下墙门洞
	var mx := x + bw / 2
	for xx in range(x, mx - 2): tm.set_cell(0, Vector2i(xx, y + bh - 1), 0, Vector2i(0, 0))
	for xx in range(mx - 2, mx + 3): tm.set_cell(1, Vector2i(xx, y + bh - 1), 2, D)
	for xx in range(mx + 3, x + bw): tm.set_cell(0, Vector2i(xx, y + bh - 1), 0, Vector2i(0, 0))
	# 内部隔断(教室)
	for yy in range(y + 2, y + bh - 2, 4):
		for xx in range(x + 1, x + bw - 1):
			tm.set_cell(1, Vector2i(xx, yy), 1, W)
		for dx in range(-1, 2): tm.set_cell(1, Vector2i(mx + dx, yy), 2, D)

func _label(tx: int, ty: int, text: String) -> void:
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3))
	l.position = Vector2(tx * T - 30, ty * T - 6)
	l.size = Vector2(120, 18); add_child(l)
