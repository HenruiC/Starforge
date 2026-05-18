class_name TilemapBuilder
extends Node2D

# 学校副本 v4 — 宫崎+罗梅罗: 多建筑群+开放路径+动线引导
# "不做大方块。学校是建筑群，空间之间的流动才是关卡。"
const T:=48; const MW:=3200; const MH:=2400
var tm:TileMap

func _ready() -> void:
	tm = TileMap.new(); tm.name = "TileMap"; tm.z_index = -1
	add_child(tm); _tileset(); _build()

func _tileset() -> void:
	var ts := TileSet.new(); ts.tile_size = Vector2i(T, T)
	var tiles := [["floor_tile", 0], ["wall_tile", 1], ["door_tile", 2]]
	for ti in tiles:
		var tex := AssetLoader.texture(ti[0], T, Color.GRAY) as Texture2D
		var a := TileSetAtlasSource.new(); a.texture = tex
		a.texture_region_size = Vector2i(T, T); a.create_tile(Vector2i(0, 0))
		ts.add_source(a, ti[1])
	tm.tile_set = ts; tm.add_layer(1)

func _build() -> void:
	var F:=Vector2i(0,0); var W:=Vector2i(1,0); var D:=Vector2i(2,0)
	var cx:=int(MW/T); var ry:=int(MH/T)
	for x in cx: for y in ry: tm.set_cell(0, Vector2i(x,y), 0, F)
	_boundary(cx, ry, W)

	# ===== 校门广场(南侧中央, 弧形开放) =====
	var gx:=cx/2
	_arch(gx, ry-1, 5, D, W)

	# ===== 主干道(校门→中央庭院, 笔直, 4格宽) =====
	var road_x:=gx
	for y in range(ry-12, ry):
		for dx in range(-2,3): tm.set_cell(1, Vector2i(road_x+dx, y), 0, F)

	# ===== 左区: 操场(开放) =====
	_label(gx-10, ry-14, "操场", Color(0.3,0.8,0.3))
	for i in 6:
		var tx:=randi_range(3, gx-6); var ty:=randi_range(ry-20, ry-6)
		tm.set_cell(1, Vector2i(tx, ty), 0, F)  # 操场标记

	# ===== 右区: 体育器材区 =====
	_label(gx+8, ry-14, "器材区", Color(0.5,0.5,0.5))

	# ===== 中央庭院(教学楼群中间, 开放, 4棵树) =====
	var cy:=ry-26
	_label(gx, cy-2, "中央庭院", Color(0.3,0.7,0.3))

	# ===== 左教学楼(A翼, 3层×5间) =====
	var lx:=gx-16; var ly:=cy-12
	_building(lx, ly, 14, 17, W, D)

	# 左楼内部分隔(走廊+教室)
	var lm:=lx+14
	for y in range(ly+2, ly+15, 4):
		for x in range(lx, lm-1): tm.set_cell(1, Vector2i(x, y), 1, W)
		var dxs:=randi_range(lx+2, lm-5)
		for dx in range(-1, 3): tm.set_cell(1, Vector2i(dxs+dx, y), 2, D)
		_label(dxs+1, y, "教室", Color(0.8,0.8,0.1))

	# ===== 右教学楼(B翼, 3层×5间) =====
	var rx:=gx+4; var ry2:=cy-12
	_building(rx, ry2, 14, 17, W, D)

	var rm:=rx+14
	for y in range(ry2+2, ry2+15, 4):
		for x in range(rx+1, rm): tm.set_cell(1, Vector2i(x, y), 1, W)
		var dxs:=randi_range(rx+3, rm-4)
		for dx in range(-1, 3): tm.set_cell(1, Vector2i(dxs+dx, y), 2, D)
		_label(dxs+1, y, "教室", Color(0.8,0.8,0.1))

	# ===== 连接走廊(两栋楼之间, 露天顶棚) =====
	var conn_y:=cy-8
	for x in range(lm-2, rx+4): tm.set_cell(1, Vector2i(x, conn_y-1), 0, F)
	_label(gx, conn_y-2, "连廊 ▼", Color(0.6,0.6,0.4))

	# ===== 北侧通道(通往体育馆) =====
	var path_north:=cy-18
	for y in range(path_north, cy-8):
		for dx in range(-2, 3): tm.set_cell(1, Vector2i(gx+dx, y), 0, F)

	# ===== 体育馆 Boss间(独立建筑, 北端) =====
	var gy:=path_north-10
	_building(gx-8, gy, 16, 10, W, D)
	for dx in range(-4, 5): tm.set_cell(1, Vector2i(gx+dx, gy+10), 2, D)
	_label(gx, gy-1, "⚠ 体育馆 · Boss间", Color(1.0,0.15,0.05))

	# ===== 动线引导标识 =====
	_label(gx, ry-1, "▼ 校门 · 起点", Color(0.9,0.8,0.2))
	_label(gx, cy, "◎ 中央庭院", Color(0.3,0.7,0.3))
	_label(gx, path_north+2, "▲ 体育馆方向", Color(1.0,0.3,0.1))

# ===== 工具 =====
func _boundary(cx:int, ry:int, W:Vector2i) -> void:
	for x in range(0, cx+1):
		tm.set_cell(1, Vector2i(x, 0), 1, W)
		tm.set_cell(1, Vector2i(x, ry-1), 1, W)
	for y in range(0, ry):
		tm.set_cell(1, Vector2i(0, y), 1, W)
		tm.set_cell(1, Vector2i(cx-1, y), 1, W)

func _arch(x:int, y:int, w:int, D:Vector2i, W:Vector2i) -> void:
	for dx in range(-w, w+1): tm.set_cell(1, Vector2i(x+dx, y), 2, D)
	for dx2 in range(-w-2, -w): tm.set_cell(1, Vector2i(x+dx2, y), 1, W)
	for dx2 in range(w+1, w+3): tm.set_cell(1, Vector2i(x+dx2, y), 1, W)

func _building(x:int, y:int, bw:int, bh:int, W:Vector2i, D:Vector2i) -> void:
	for xx in range(x, x+bw): tm.set_cell(1, Vector2i(xx, y), 1, W)
	for yy in range(y, y+bh): tm.set_cell(1, Vector2i(x, yy), 1, W)
	for yy in range(y, y+bh): tm.set_cell(1, Vector2i(x+bw-1, yy), 1, W)
	for xx in range(x, x+bw): tm.set_cell(1, Vector2i(xx, y+bh-1), 1, W)

func _label(tx:int, ty:int, text:String, color:Color) -> void:
	var l:=Label.new(); l.text=text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", color)
	l.position=Vector2(tx*T-60, ty*T-6); l.size=Vector2(200, 18)
	add_child(l)
