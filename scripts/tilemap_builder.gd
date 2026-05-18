class_name TilemapBuilder
extends Node2D

# 代码生成TileMap — 罗梅罗快速搭建风格
# 运行时创建TileSet+TileMap, 绘制学校布局

const T:=48; const MW:=3200; const MH:=2400

var tilemap: TileMap

func _ready() -> void:
	# 运行时创建TileMap
	tilemap = TileMap.new()
	tilemap.name = "TileMap"
	tilemap.z_index = -1
	add_child(tilemap)
	_build_tileset()
	_draw_map()

func _build_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)

	# 0: 地板 (无碰撞, 导航可行走)
	_add_atlas(ts, "floor_tile", 0, false, 0)
	# 1: 墙壁 (有碰撞, 不可行走)
	_add_atlas(ts, "wall_tile", 1, true, 0)
	# 2: 门标记 (无碰撞)
	_add_atlas(ts, "door_tile", 2, false, 0)

	tilemap.tile_set = ts
	tilemap.add_layer(1)  # 墙壁层

func _add_atlas(ts: TileSet, tex_name: String, source_id: int, _has_collision: bool, _nav_layer: int) -> void:
	var tex := AssetLoader.texture(tex_name, T, Color.GRAY) as Texture2D
	var atlas := TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(T, T)
	atlas.create_tile(Vector2i(0, 0))
	ts.add_source(atlas, source_id)

func _draw_map() -> void:
	tilemap.clear()
	# Layer 0: 地板(铺满)
	var floor_id := Vector2i(0, 0)
	var wall_id := Vector2i(1, 0)
	var door_id := Vector2i(2, 0)

	var cols := int(MW / T) + 1
	var rows := int(MH / T) + 1
	for x in cols:
		for y in rows:
			tilemap.set_cell(0, Vector2i(x, y), 0, floor_id)

	# Layer 1: 边界围墙(不可破坏, 红色标记)
	for x in cols:
		tilemap.set_cell(1, Vector2i(x, 0), 1, wall_id)
		tilemap.set_cell(1, Vector2i(x, rows - 1), 1, wall_id)
	for y in rows:
		tilemap.set_cell(1, Vector2i(0, y), 1, wall_id)
		tilemap.set_cell(1, Vector2i(cols - 1, y), 1, wall_id)

	# 校门(南墙中央留空)
	var gx := int(MW / 2 / T)
	for dx in range(-2, 3):
		tilemap.set_cell(1, Vector2i(gx + dx, rows - 1), 0, floor_id)  # 清空墙壁
		tilemap.set_cell(1, Vector2i(gx + dx, rows - 1), 2, door_id)  # 放门标记

	# 教学楼主体
	var bx:=6;var by:=int((MH-18*T)/T);var bw:=54;var bh:=13
	# 外墙
	for x in range(bx, bx+bw):
		tilemap.set_cell(1, Vector2i(x, by), 1, wall_id)
		if by+bh < rows: tilemap.set_cell(1, Vector2i(x, by+bh-1), 1, wall_id)
	for y in range(by, by+bh):
		tilemap.set_cell(1, Vector2i(bx, y), 1, wall_id)
		tilemap.set_cell(1, Vector2i(bx+bw-1, y), 1, wall_id)

	# 教学楼正门(南墙中央)
	var bx_center:=bx+bw/2
	for dx in range(-3, 4):
		if by+bh-1 < rows:
			tilemap.set_cell(1, Vector2i(bx_center+dx, by+bh-1), 0, floor_id)
			tilemap.set_cell(1, Vector2i(bx_center+dx, by+bh-1), 2, door_id)

	# 走廊(教学楼中间水平线)
	var cy:=by+bh/2
	for x in range(bx+4, bx+bw-4):
		tilemap.set_cell(1, Vector2i(x, cy-2), 1, wall_id)
		tilemap.set_cell(1, Vector2i(x, cy+2), 1, wall_id)

	# 6间教室
	_room(bx+4, by+1,    bx+19, cy-3, wall_id, door_id)
	_room(bx+20, by+1,   bx+35, cy-3, wall_id, door_id)
	_room(bx+36, by+1,   bx+bw-4, cy-3, wall_id, door_id)
	_room(bx+4, cy+3,    bx+19, by+bh-2, wall_id, door_id)
	_room(bx+20, cy+3,   bx+35, by+bh-2, wall_id, door_id)
	_room(bx+36, cy+3,   bx+bw-4, by+bh-2, wall_id, door_id)

	# Boss间
	var bby:=by-3
	tilemap.set_cell(1, Vector2i(bx+8, bby), 1, wall_id)
	tilemap.set_cell(1, Vector2i(bx+8, bby+4), 1, wall_id)
	tilemap.set_cell(1, Vector2i(bx+bw-8, bby), 1, wall_id)
	tilemap.set_cell(1, Vector2i(bx+bw-8, bby+4), 1, wall_id)
	for x in range(bx+8, bx+bw-7): tilemap.set_cell(1, Vector2i(x, bby), 1, wall_id)

func _room(x1:int, y1:int, x2:int, y2:int, wall_id:Vector2i, door_id:Vector2i) -> void:
	# 上+左+右
	for x in range(x1, x2): tilemap.set_cell(1, Vector2i(x, y1), 1, wall_id)
	for y in range(y1, y2): tilemap.set_cell(1, Vector2i(x1, y), 1, wall_id)
	for y in range(y1, y2): tilemap.set_cell(1, Vector2i(x2-1, y), 1, wall_id)
	# 下墙: 左边+缺口+右边
	var mx:=(x1+x2)/2;var gap:=4
	for x in range(x1, mx-gap): tilemap.set_cell(1, Vector2i(x, y2-1), 1, wall_id)
	for x in range(mx+gap, x2): tilemap.set_cell(1, Vector2i(x, y2-1), 1, wall_id)
	# 门标记
	for dx in range(-gap+1, gap):
		tilemap.set_cell(1, Vector2i(mx+dx, y2-1), 0, Vector2i(0,0))
	tilemap.set_cell(1, Vector2i(mx, y2-1), 2, door_id)

