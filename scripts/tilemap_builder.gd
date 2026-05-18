class_name TilemapBuilder
extends Node2D

# 学校副本 — 宫崎英高·罗梅罗 联合重设计
# 叙事动线: 校门(安全)→操场(暴露)→前庭(过渡)→大厅(入口)
#           →走廊(脊骨)→教室(探索)→体育馆(高潮)
# 设计原则: 清晰地标 / 多路径选择 / 安全区 / 视野控制

const T:=48; const MW:=3200; const MH:=2400
var tilemap: TileMap

func _ready() -> void:
	tilemap = TileMap.new()
	tilemap.name = "TileMap"; tilemap.z_index = -1
	add_child(tilemap)
	_build_tileset()
	_design_map()

func _build_tileset() -> void:
	var ts := TileSet.new(); ts.tile_size = Vector2i(T, T)
	_add_atlas(ts, "floor_tile", 0)
	_add_atlas(ts, "wall_tile", 1)
	_add_atlas(ts, "door_tile", 2)
	tilemap.tile_set = ts
	tilemap.add_layer(1)

func _add_atlas(ts: TileSet, tex_name: String, source_id: int) -> void:
	var tex := AssetLoader.texture(tex_name, T, Color.GRAY) as Texture2D
	var atlas := TileSetAtlasSource.new()
	atlas.texture = tex; atlas.texture_region_size = Vector2i(T, T)
	atlas.create_tile(Vector2i(0, 0))
	ts.add_source(atlas, source_id)

func _design_map() -> void:
	var F:=Vector2i(0,0); var W:=Vector2i(1,0); var D:=Vector2i(2,0)
	var cols:=int(MW/T); var rows:=int(MH/T)

	# ===== 全域地板 =====
	for x in cols: for y in rows: tilemap.set_cell(0, Vector2i(x,y), 0, F)

	# ===== 1. 外围边界（不可通行） =====
	_rect(0,0, cols-1, rows-1, W)

	# ===== 2. 校门(南侧中央，宽6格) =====
	var gx:=cols/2
	for dx in range(-3,4): tilemap.set_cell(1, Vector2i(gx+dx, rows-1), 2, D)

	# ===== 3. 操场区(南半部, 开阔) =====
	# 操场是开放空间, 两侧有树, 中间一条主路通向教学楼
	var tree_tiles:Array[Vector2i]=[]
	for i in 10:
		var tx:=randi_range(3, cols-4)
		var ty:=randi_range(rows-20, rows-4)
		if abs(tx-gx)<6:continue
		tree_tiles.append(Vector2i(tx,ty))

	# ===== 4. 教学楼 =====
	var bx:=8; var by:=rows-24
	var bw:=cols-16; var bh:=16

	# 外墙(上+左+右, 下方留入口)
	for x in range(bx, bx+bw):tilemap.set_cell(1, Vector2i(x,by), 1, W)
	for y in range(by, by+bh):tilemap.set_cell(1, Vector2i(bx,y), 1, W)
	for y in range(by, by+bh):tilemap.set_cell(1, Vector2i(bx+bw-1,y), 1, W)
	# 下墙(左右两段+中间入口)
	for x in range(bx, gx-6):tilemap.set_cell(1, Vector2i(x, by+bh-1), 1, W)
	for x in range(gx+6, bx+bw):tilemap.set_cell(1, Vector2i(x, by+bh-1), 1, W)
	for dx in range(-6,7):tilemap.set_cell(1, Vector2i(gx+dx, by+bh-1), 2, D)

	# ===== 5. 入口大厅(玄关, bh=4格高) =====
	var hall_y:=by+bh-5
	# 大厅与走廊隔墙(左右各一段+中间通道)
	for x in range(bx+2, gx-3):tilemap.set_cell(1, Vector2i(x, hall_y), 1, W)
	for x in range(gx+3, bx+bw-2):tilemap.set_cell(1, Vector2i(x, hall_y), 1, W)
	for dx in range(-3,4):tilemap.set_cell(1, Vector2i(gx+dx, hall_y), 2, D)
	# 大厅两侧隔墙
	for y in range(hall_y, by+bh-1):tilemap.set_cell(1, Vector2i(bx+4, y), 1, W)
	for y in range(hall_y, by+bh-1):tilemap.set_cell(1, Vector2i(bx+bw-5, y), 1, W)

	# ===== 6. 走廊(脊骨, 水平, 3格宽) =====
	var corr_y:=by+6
	for x in range(bx+2, bx+bw-2):
		tilemap.set_cell(1, Vector2i(x, corr_y-2), 1, W)
		tilemap.set_cell(1, Vector2i(x, corr_y+1), 1, W)

	# 走廊中段开门(通向两侧教室)
	var left_door:=bx+bw/3
	var right_door:=bx+2*bw/3
	for dx in range(-2,3):
		tilemap.set_cell(1, Vector2i(left_door+dx, corr_y-2), 2, D)
		tilemap.set_cell(1, Vector2i(right_door+dx, corr_y-2), 2, D)

	# ===== 7. 上排教室A/B/C (走廊上方) =====
	_classroom(bx+2, by+1,      bx+bw/3-1, corr_y-3,  W, D)
	_classroom(bx+bw/3+1, by+1,  bx+2*bw/3-1, corr_y-3, W, D)
	_classroom(bx+2*bw/3+1, by+1, bx+bw-2,    corr_y-3, W, D)

	# ===== 8. 下排教室D/E/F (走廊下方, 大厅上方) =====
	_classroom(bx+2, corr_y+2,      bx+bw/3-1, hall_y-1,  W, D)
	_classroom(bx+bw/3+1, corr_y+2,  bx+2*bw/3-1, hall_y-1, W, D)
	_classroom(bx+2*bw/3+1, corr_y+2, bx+bw-2,    hall_y-1, W, D)

	# ===== 9. Boss间·体育馆(教学楼上方) =====
	var bby:=by-5; var bbx:=bx+6; var bbw:=bw-12; var bbh:=4
	for x in range(bbx, bbx+bbw):tilemap.set_cell(1, Vector2i(x, bby), 1, W)
	for y in range(bby, bby+bbh):tilemap.set_cell(1, Vector2i(bbx, y), 1, W)
	for y in range(bby, bby+bbh):tilemap.set_cell(1, Vector2i(bbx+bbw-1, y), 1, W)
	for x in range(bbx+3, bbx+bbw-3):tilemap.set_cell(1, Vector2i(x, bby+bbh-1), 1, W)
	for dx in range(-3, 4):tilemap.set_cell(1, Vector2i(bbx+bbw/2+dx, bby+bbh-1), 2, D)

	# ===== 10. 区域标签 =====
	_label(gx, rows-1, "▼ 校门", Color(0.9,0.8,0.2))
	_label(gx, rows-14, "操场", Color(0.3,0.8,0.3))
	_label(gx, by+bh-2, "教学楼入口", Color(0.3,0.5,1.0))
	_label(gx, corr_y, "走廊", Color(0.7,0.5,0.1))
	_label(bbx+bbw/2, bby+bbh-2, "Boss间", Color(1.0,0.15,0.05))

# ===== 工具函数 =====
func _rect(x1:int,y1:int,x2:int,y2:int,W:Vector2i)->void:
	for x in range(x1,x2+1):tilemap.set_cell(1, Vector2i(x,y1),1,W)
	for x in range(x1,x2+1):tilemap.set_cell(1, Vector2i(x,y2),1,W)
	for y in range(y1,y2+1):tilemap.set_cell(1, Vector2i(x1,y),1,W)
	for y in range(y1,y2+1):tilemap.set_cell(1, Vector2i(x2,y),1,W)

func _classroom(x1:int,y1:int,x2:int,y2:int,W:Vector2i,D:Vector2i)->void:
	for x in range(x1,x2):tilemap.set_cell(1, Vector2i(x,y1),1,W)
	for y in range(y1,y2):tilemap.set_cell(1, Vector2i(x1,y),1,W)
	for y in range(y1,y2):tilemap.set_cell(1, Vector2i(x2-1,y),1,W)
	var mx:=(x1+x2)/2;var gap:=3
	for x in range(x1,mx-gap):tilemap.set_cell(1, Vector2i(x,y2-1),1,W)
	for x in range(mx+gap,x2):tilemap.set_cell(1, Vector2i(x,y2-1),1,W)
	for dx in range(-gap+1,gap):tilemap.set_cell(1, Vector2i(mx+dx,y2-1),2,D)

func _label(tx:int,ty:int,text:String,color:Color)->void:
	var l:=Label.new();l.text=text
	l.add_theme_font_size_override("font_size",13)
	l.add_theme_color_override("font_color",color)
	l.position=Vector2(tx*T-40,ty*T+l.get_theme_font_size("font_size")/2)
	l.size=Vector2(160,18);add_child(l)
