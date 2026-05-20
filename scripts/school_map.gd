class_name SchoolMap
extends Node2D

# 学校地图 — 8色TileMap区域 + 罗梅罗关卡分区设计
#
# 罗梅罗信条：Suck it down and make it fun.
# 区域化 — 每个区域不同色，玩家一眼知道自己在哪里

const T := 48
const MW := 5760
const MH := 4320

# 区域配色（杨奇色彩体系映射）
const COLOR_PLAYGROUND_FLOOR := Color(0.91, 0.84, 0.72)       # #E8D5B7 浅沙
const COLOR_PLAYGROUND_WALL := Color(0.55, 0.49, 0.42)         # #8B7D6B 土棕
const COLOR_CLASSROOM_FLOOR := Color(0.16, 0.16, 0.20)         # #2A2A32 深灰
const COLOR_WALL_LEFT := Color(0.29, 0.25, 0.25)               # #4A4040 暗红棕
const COLOR_WALL_RIGHT := Color(0.24, 0.29, 0.24)              # #3D4A3D 暗绿棕
const COLOR_HALLWAY_FLOOR := Color(0.35, 0.35, 0.35)           # #5A5A5A 中灰
const COLOR_GYM_FLOOR := Color(0.42, 0.23, 0.16)               # #6B3A2A 红褐
const COLOR_GYM_WALL := Color(0.55, 0.27, 0.07)                # #8B4513 深棕
const COLOR_GATE := Color(0.48, 0.48, 0.35)                    # #7A7A5A 灰黄
const COLOR_CORRIDOR_FLOOR := Color(0.29, 0.35, 0.29)          # #4A5A4A 灰绿（连廊）
const COLOR_GATE_LIGHT := Color(1.0, 0.98, 0.88)                # 门外白光（暖白，非死白）
const COLOR_LOCKED_DOOR := Color(0.35, 0.15, 0.08)               # 锁住的门 暗红褐

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

# =============================================================================
# Tileset 构建 — 9 个 color source（0-8）
# =============================================================================

func _build_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)

	# Source 0-3: 各种地板（无碰撞）
	_add_color_source(ts, 0, COLOR_PLAYGROUND_FLOOR)    # 操场 浅沙
	_add_color_source(ts, 1, COLOR_CLASSROOM_FLOOR)     # 教室 深灰
	_add_color_source(ts, 2, COLOR_HALLWAY_FLOOR)       # 走廊 中灰
	_add_color_source(ts, 3, COLOR_GYM_FLOOR)           # 体育馆 红褐

	# Source 4-6: 各种墙壁（有碰撞）
	_add_color_source(ts, 4, COLOR_PLAYGROUND_WALL)     # 外壁 土棕
	_add_color_source(ts, 5, COLOR_WALL_LEFT)           # 左翼墙 暗红棕
	_add_color_source(ts, 6, COLOR_GYM_WALL)            # 体育馆壁 深棕

	# Source 7: 门/校门（无碰撞）
	_add_color_source(ts, 7, COLOR_GATE)

	# Source 8: 右翼墙 暗绿棕（有碰撞）
	_add_color_source(ts, 8, COLOR_WALL_RIGHT)

	# Source 9: 雾层 — 全黑（无碰撞）
	_add_color_source(ts, 9, Color(0, 0, 0, 1))

	# Source 10: 锁住的门 — 暗红褐（有碰撞）
	_add_color_source(ts, 10, COLOR_LOCKED_DOOR)

	# Source 12: 门外白光（非碰撞地板，用于校门打开后）
	_add_color_source(ts, 12, COLOR_GATE_LIGHT)

	# 物理层
	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, 8)

	# 为所有墙壁 source 添加碰撞（4, 5, 6, 8）
	for sid in [4, 5, 6, 8, 10]:
		_add_wall_collision(ts, sid)

	_tm.tile_set = ts
	_tm.add_layer(0)
	_tm.add_layer(1)
	_tm.add_layer(2)
	_tm.set_layer_z_index(2, 50)

func _add_color_source(ts: TileSet, sid: int, color: Color) -> void:
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var tex := ImageTexture.create_from_image(img)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(T, T)
	atlas.create_tile(Vector2i(0, 0))
	ts.add_source(atlas, sid)

func _add_wall_collision(ts: TileSet, sid: int) -> void:
	var source := ts.get_source(sid) as TileSetAtlasSource
	if source:
		var tile_data := source.get_tile_data(Vector2i(0, 0), 0)
		tile_data.add_collision_polygon(0)
		tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(0, 0),
			Vector2(T, 0),
			Vector2(T, T),
			Vector2(0, T)
		]))

func _deferred_update() -> void:
	if is_instance_valid(_tm):
		_tm.update_internals()


# =============================================================================
# 区域化 _draw() — 罗梅罗分区方案
# =============================================================================

func _draw() -> void:
	var cols := int(ceil(MW / float(T)))
	var rows := int(ceil(MH / float(T)))

	# 区域布局（tile 坐标）：
	# 体育馆  y=6..23   x=48..72
	# 前厅    y=24..29  x=52..68
	# 连廊    y=30..53  x=55..65
	# 左教学楼 y=54..75  x=14..40
	# 右教学楼 y=54..75  x=68..94
	# 操场    y=76..89  全宽
	# 校门    y=89      中心

	@warning_ignore("integer_division")
	var gx := cols / 2          # 60
	# 左教学楼
	var bx := 14
	var by := rows - 36         # 54
	var lw := 26
	var lh := 22
	# 右教学楼
	var rx := gx + 8            # 68
	# 连廊
	@warning_ignore("integer_division")
	var mid_y := by + lh / 2    # 65
	# 体育馆
	var gy := 6                 # 不变

	# ---- 阶段1：地板填充（按区域不同 source ID） ----
	_draw_floor_zones(cols, rows, bx, by, lw, lh, rx, gx, mid_y, gy)

	# ---- 阶段2：墙壁 + 建筑 ----
	_draw_boundary_walls(cols, rows)

	# 左教学楼（深灰地板 + 暗红棕墙）— 开北门+侧门
	_building(bx, by, lw, lh, 5, 7, "左楼", 1, 5, true, true)

	# 右教学楼（深灰地板 + 暗绿棕墙）— 开北门+侧门
	_building(rx, by, lw, lh, 8, 7, "右楼", 1, 8, true, true)

	# 体育馆（红褐地板 + 深棕墙）— 默认不开额外出口
	_building(gx - 12, gy, 24, 18, 6, 0, "", 3, 6)

	# 体育馆入口（南墙中央擦除9格，铺过渡地板）
	var gym_center_x := gx
	for dx in range(-4, 5):
		_tm.set_cell(0, Vector2i(gym_center_x + dx, gy + 17), 2, Vector2i(0, 0))

	# 体育馆入口锁住的门（source 10 — 暗红褐，有碰撞，layer 1）
	# 覆盖入口 9 格，击败精英守卫后由 LockedDoor 擦除并替换为地板
	for dx in range(-4, 5):
		_tm.set_cell(1, Vector2i(gym_center_x + dx, gy + 17), 10, Vector2i(0, 0))

	# ---- 阶段3：视觉增强 ----
	_draw_zone_boundaries(cols, rows, bx, by, lw, lh, rx, gx, mid_y, gy)
	_draw_zone_glows(cols, rows, bx, by, lw, lh, rx, gx, mid_y, gy)

	# ---- 阶段4：标签 ----
	_label(gx, rows - 1, "▼ 校门", Color.GOLD)
	_label(gx, rows - 18, "操场", Color(0.3, 0.8, 0.3))
	_label(gx, rows - 24, "前庭", Color(0.7, 0.7, 0.3))
	_label(gx, gy + 10, "Boss间", Color(1.0, 0.2, 0.1))
	_label(bx + 6, by + 3, "教学楼A", Color(0.6, 0.5, 0.3))
	_label(rx + 6, by + 3, "教学楼B", Color(0.5, 0.6, 0.3))

	_draw_fog_layer()

# =============================================================================
# 区域地板填充
# =============================================================================

func _draw_floor_zones(cols: int, rows: int, bx: int, by: int, lw: int, lh: int, rx: int, gx: int, mid_y: int, gy: int) -> void:
	# 默认全操场浅沙地板（source 0）
	for x in cols:
		for y in rows:
			_tm.set_cell(0, Vector2i(x, y), 0, Vector2i(0, 0))

	# 体育馆地板（source 3）— 覆盖 gym 区域
	for x in range(gx - 11, gx + 12):      # 49..71
		for y in range(gy + 1, gy + 17):    # 7..22
			_tm.set_cell(0, Vector2i(x, y), 3, Vector2i(0, 0))

	# 左教学楼地板（source 1）
	for x in range(bx + 1, bx + lw - 1):   # 15..39
		for y in range(by + 1, by + lh - 1):  # 55..75
			_tm.set_cell(0, Vector2i(x, y), 1, Vector2i(0, 0))

	# 右教学楼地板（source 1）
	for x in range(rx + 1, rx + lw - 1):   # 69..93
		for y in range(by + 1, by + lh - 1):  # 55..75
			_tm.set_cell(0, Vector2i(x, y), 1, Vector2i(0, 0))

	# 走廊地板（source 2）— 左教学楼到右教学楼（教室间的连廊）
	for x in range(bx + lw - 1, rx + 1):   # 39..69
		for y in range(mid_y - 2, mid_y + 3):  # 63..67
			_tm.set_cell(0, Vector2i(x, y), 2, Vector2i(0, 0))

	# 体育馆前厅过渡区（source 2）— 从体育馆入口到连廊
	for x in range(gx - 8, gx + 9):        # 52..69
		for y in range(gy + 18, gy + 24):   # 24..30
			_tm.set_cell(0, Vector2i(x, y), 2, Vector2i(0, 0))

	# 垂直通道（source 2）— 前厅到教学楼区域
	for x in range(gx - 5, gx + 6):        # 55..65
		for y in range(gy + 24, by + 1):    # 30..55
			_tm.set_cell(0, Vector2i(x, y), 2, Vector2i(0, 0))

	# 校门区域（source 7）— 入口地面泛黄
	for x in range(gx - 5, gx + 6):
		_tm.set_cell(0, Vector2i(x, rows - 1), 7, Vector2i(0, 0))

# =============================================================================
# 边界围墙
# =============================================================================

func _draw_boundary_walls(cols: int, rows: int) -> void:
	# 外圈用土棕墙壁（source 4）
	for x in cols:
		_tm.set_cell(1, Vector2i(x, 0), 4, Vector2i(0, 0))
		_tm.set_cell(1, Vector2i(x, rows - 1), 4, Vector2i(0, 0))
	for y in rows:
		_tm.set_cell(1, Vector2i(0, y), 4, Vector2i(0, 0))
		_tm.set_cell(1, Vector2i(cols - 1, y), 4, Vector2i(0, 0))

	# 校门（source 7）— 南墙中央11格（原来9格）
	@warning_ignore("integer_division")
	var gx := cols / 2
	for dx in range(-5, 6):
		_tm.set_cell(1, Vector2i(gx + dx, rows - 1), 7, Vector2i(0, 0))

# =============================================================================
# 建筑通用 — 支持区域化 floor/wall source
# =============================================================================

func _building(
	x: int, y: int, bw: int, bh: int,
	wall_sid: int, door_sid: int,
	label_name: String,
	floor_sid: int = 1,
	alt_wall_sid: int = -1,
	open_north: bool = false,
	open_side: bool = false
) -> void:
	# 围墙（内部墙壁使用指定 wall_sid）
	for xx in range(x, x + bw):
		_tm.set_cell(1, Vector2i(xx, y), wall_sid, Vector2i(0, 0))
		_tm.set_cell(1, Vector2i(xx, y + bh - 1), wall_sid, Vector2i(0, 0))
	for yy in range(y, y + bh):
		_tm.set_cell(1, Vector2i(x, yy), wall_sid, Vector2i(0, 0))
		_tm.set_cell(1, Vector2i(x + bw - 1, yy), wall_sid, Vector2i(0, 0))

	# 内部地板使用指定 floor_sid（已在 _draw_floor_zones 中填充）
	# 此处不再重复填充，避免覆盖区域地板

	# 门洞 — 南墙中央5格
	@warning_ignore("integer_division")
	var mx := x + bw / 2
	for dx in range(-2, 3):
		_tm.erase_cell(1, Vector2i(mx + dx, y + bh - 1))
		_tm.set_cell(1, Vector2i(mx + dx, y + bh - 1), door_sid, Vector2i(0, 0))
	# 北墙门洞 — 连通后方区域
	if open_north:
		for dx in range(-2, 3):
			_tm.erase_cell(1, Vector2i(mx + dx, y))
			_tm.set_cell(1, Vector2i(mx + dx, y), door_sid, Vector2i(0, 0))
		# 北门外铺走廊地板（4 tiles 深）
		for dy in range(1, 5):
			for dx in range(-3, 4):
				var tx := mx + dx
				var ty := y - dy
				if tx >= 0 and tx < 120 and ty >= 0:
					_tm.set_cell(0, Vector2i(tx, ty), 2, Vector2i(0, 0))

	# 右翼门洞墙壁也用对应墙色（如果提供了 alt_wall_sid）
	if alt_wall_sid > 0 and label_name == "右楼":
		for xx in range(x, x + bw):
			_tm.set_cell(1, Vector2i(xx, y), alt_wall_sid, Vector2i(0, 0))
			_tm.set_cell(1, Vector2i(xx, y + bh - 1), alt_wall_sid, Vector2i(0, 0))
		for yy in range(y, y + bh):
			_tm.set_cell(1, Vector2i(x, yy), alt_wall_sid, Vector2i(0, 0))
			_tm.set_cell(1, Vector2i(x + bw - 1, yy), alt_wall_sid, Vector2i(0, 0))

	# side door
	if open_side:
		var side_x: int
		var side_range
		if x < 60:
			side_x = x + bw - 1
			side_range = range(y + 9, y + 13)
		else:
			side_x = x
			side_range = range(y + 9, y + 13)
		for dy in side_range:
			_tm.erase_cell(1, Vector2i(side_x, dy))
			_tm.set_cell(1, Vector2i(side_x, dy), door_sid, Vector2i(0, 0))

	if label_name:
		@warning_ignore("integer_division")
		_label(mx, y + bh / 2, label_name, Color(0.8, 0.7, 0.2))
		# 教室内柱子 — 4个2x2掩体
		_pillar(x + 4, y + 4, wall_sid)
		_pillar(x + bw - 6, y + 4, wall_sid)
		_pillar(x + 4, y + bh - 6, wall_sid)
		_pillar(x + bw - 6, y + bh - 6, wall_sid)
		# 课桌排列 — 行间距3格，中间留过道
		@warning_ignore("integer_division")
		for row in range(2, bh - 2, 3):
			for col in range(2, bw - 2):
				if col == (bw - 2) / 2:
					continue
				_tm.set_cell(1, Vector2i(x + col, y + row), wall_sid, Vector2i(0, 0))

func _pillar(px: int, py: int, wall_sid: int = 5) -> void:
	for dx in range(2):
		for dy in range(2):
			_tm.set_cell(1, Vector2i(px + dx, py + dy), wall_sid, Vector2i(0, 0))

# =============================================================================
# 区域边界装饰（非碰撞 Tile）
# =============================================================================

func _draw_zone_boundaries(cols: int, rows: int, bx: int, by: int, lw: int, lh: int, rx: int, gx: int, mid_y: int, gy: int) -> void:
	# 操场到教学楼过渡线 (y=by+lh, 全宽外壁线不在内)
	# 使用装饰层 layer 1 但 source 4 不设碰撞需要额外处理
	# 这里用现有碰撞墙壁 source 4 来做边界（实际上已经有外壁了）

	# 体育馆到走廊过渡 — 红褐到中灰的视觉分界
	# 在体育馆南墙外一格铺一排 hallway floor（已做）

	# 教学楼之间的连廊地板（已做）

	# 校门两侧装饰性矮墙（在门两侧多放2格门 tile）
	@warning_ignore("integer_division")
	for dx in [-7, -6, 6, 7]:
		if gx + dx >= 0 and gx + dx < cols:
			_tm.set_cell(1, Vector2i(gx + dx, rows - 1), 7, Vector2i(0, 0))

# =============================================================================
# 区域 ColorRect 泛光
# =============================================================================

func _draw_zone_glows(cols: int, rows: int, bx: int, by: int, lw: int, lh: int, rx: int, gx: int, mid_y: int, gy: int) -> void:
	# 体育馆区域红褐泛光
	_add_zone_glow(gx * T - 12 * T, gy * T, 24 * T, 18 * T, Color(0.42, 0.23, 0.16, 0.06))

	# 左教学楼区域暗红泛光
	_add_zone_glow(bx * T, by * T, lw * T, lh * T, Color(0.29, 0.25, 0.25, 0.04))

	# 右教学楼区域暗绿泛光
	_add_zone_glow(rx * T, by * T, lw * T, lh * T, Color(0.24, 0.29, 0.24, 0.04))

	# 操场区域暖黄泛光
	_playground_glow(cols, rows, by, lh)

func _add_zone_glow(px: float, py: float, w: float, h: float, color: Color) -> void:
	var glow := ColorRect.new()
	glow.color = color
	glow.position = Vector2(px, py)
	glow.size = Vector2(w, h)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.z_index = -10
	add_child(glow)

func _playground_glow(cols: int, rows: int, by: int, lh: int) -> void:
	var glow := ColorRect.new()
	glow.color = Color(0.91, 0.84, 0.72, 0.04)
	glow.position = Vector2(0, (by + lh) * T)
	glow.size = Vector2(cols * T, (rows - (by + lh)) * T)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.z_index = -10
	add_child(glow)

# =============================================================================
# 地图纹理生成（更新颜色映射）
# =============================================================================

func generate_map_texture() -> ImageTexture:
	var cols := int(ceil(MW / float(T)))
	var rows := int(ceil(MH / float(T)))
	var img := Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	for x in cols:
		for y in rows:
			var sid := _tm.get_cell_source_id(1, Vector2i(x, y))
			if sid == 7:
				img.set_pixel(x, y, Color.GOLD)                          # 门
			elif sid in [4, 5, 6, 8, 10]:
				img.set_pixel(x, y, Color(0.4, 0.4, 0.5, 1.0))           # 墙壁
			else:
				var floor_sid := _tm.get_cell_source_id(0, Vector2i(x, y))
				match floor_sid:
					0: img.set_pixel(x, y, Color(0.25, 0.22, 0.18, 1.0))  # 操场
					1: img.set_pixel(x, y, Color(0.12, 0.12, 0.16, 1.0))  # 教室
					2: img.set_pixel(x, y, Color(0.18, 0.18, 0.18, 1.0))  # 走廊
					3: img.set_pixel(x, y, Color(0.28, 0.15, 0.10, 1.0))  # 体育馆
					_: img.set_pixel(x, y, Color(0.08, 0.08, 0.14, 1.0))  # 默认深空
	return ImageTexture.create_from_image(img)

# =============================================================================
# 标签
# =============================================================================

func _label(tx: int, ty: int, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", color)
	l.position = Vector2(tx * T - 30, ty * T - 6)
	l.size = Vector2(120, 18)
	l.z_index = 10
	add_child(l)

# =============================================================================
# 预置敌人 — 68个点位（杨奇方案）
# 集群分布，按区域分组
# =============================================================================

func get_preplaced_enemies() -> Array:
	var list: Array = []

	# ==== 操场 + 前庭（Stage 1 — 20个敌人） ====
	# 集群A（校门附近，x=40..50, y=80..87）: 5 melee
	list.append_array([
		{"pos": Vector2(2000, 4050), "type": "melee", "activation": 0},
		{"pos": Vector2(2150, 3950), "type": "melee", "activation": 0},
		{"pos": Vector2(2250, 4100), "type": "melee", "activation": 0},
		{"pos": Vector2(2300, 3900), "type": "melee", "activation": 0},
		{"pos": Vector2(2400, 4000), "type": "melee", "activation": 0},
	])
	# 集群B（操场中左，x=20..35, y=78..85）: 3 melee + 1 ranged
	list.append_array([
		{"pos": Vector2(1050, 3850), "type": "melee", "activation": 0},
		{"pos": Vector2(1250, 3950), "type": "melee", "activation": 0},
		{"pos": Vector2(1450, 3900), "type": "melee", "activation": 0},
		{"pos": Vector2(1600, 3950), "type": "ranged", "activation": 280},
	])
	# 集群C（操场中右，x=75..95, y=78..85）: 3 melee + 1 ranged
	list.append_array([
		{"pos": Vector2(3700, 3850), "type": "melee", "activation": 0},
		{"pos": Vector2(3900, 3980), "type": "melee", "activation": 0},
		{"pos": Vector2(4200, 3900), "type": "melee", "activation": 0},
		{"pos": Vector2(4400, 4000), "type": "ranged", "activation": 280},
	])
	# 集群D（前庭正中，x=55..65, y=78..82）: 3 melee + 1 dodger
	list.append_array([
		{"pos": Vector2(2720, 3800), "type": "melee", "activation": 0},
		{"pos": Vector2(2820, 3880), "type": "melee", "activation": 0},
		{"pos": Vector2(2920, 3850), "type": "melee", "activation": 0},
		{"pos": Vector2(3100, 3900), "type": "dodger", "activation": 300},
	])
	# 集群E（跑道远端，x=10..25, y=76..80）: 2 melee + 1 stationary
	list.append_array([
		{"pos": Vector2(600, 3700), "type": "melee", "activation": 0},
		{"pos": Vector2(850, 3750), "type": "melee", "activation": 0},
		{"pos": Vector2(1050, 3800), "type": "stationary", "activation": 200},
	])

	# ==== 左教学楼（Stage 2 — 16个敌人） ====
	# 教室前部（x=18..26, y=58..64）: 3 stationary + 2 melee
	list.append_array([
		{"pos": Vector2(912, 2856), "type": "stationary", "activation": 200},
		{"pos": Vector2(1008, 2904), "type": "stationary", "activation": 200},
		{"pos": Vector2(1128, 2856), "type": "stationary", "activation": 200},
		{"pos": Vector2(1056, 3024), "type": "melee", "activation": 0},
		{"pos": Vector2(1200, 2976), "type": "melee", "activation": 0},
	])
	# 教室中部（x=20..30, y=64..70）: 3 melee + 2 ranged
	list.append_array([
		{"pos": Vector2(1008, 3168), "type": "melee", "activation": 0},
		{"pos": Vector2(1200, 3240), "type": "melee", "activation": 0},
		{"pos": Vector2(1368, 3168), "type": "melee", "activation": 0},
		{"pos": Vector2(1296, 3312), "type": "ranged", "activation": 250},
		{"pos": Vector2(1224, 3408), "type": "ranged", "activation": 250},
	])
	# 教室后部（x=18..26, y=70..75）: 2 melee + 1 ranged
	list.append_array([
		{"pos": Vector2(960, 3456), "type": "melee", "activation": 0},
		{"pos": Vector2(1152, 3528), "type": "melee", "activation": 0},
		{"pos": Vector2(1080, 3600), "type": "ranged", "activation": 220},
	])
	# 走廊（x=26..34, y=62..66）: 2 melee + 1 dodger
	list.append_array([
		{"pos": Vector2(1320, 3072), "type": "melee", "activation": 0},
		{"pos": Vector2(1488, 3120), "type": "melee", "activation": 0},
		{"pos": Vector2(1584, 3048), "type": "dodger", "activation": 260},
	])

	# ==== 右教学楼（Stage 2 — 16个敌人，对称布局） ====
	# x坐标镜像到68+（左楼x+54 tiles）
	list.append_array([
		{"pos": Vector2(3504, 2856), "type": "melee", "activation": 0},
		{"pos": Vector2(3600, 2904), "type": "stationary", "activation": 200},
		{"pos": Vector2(3720, 2856), "type": "ranged", "activation": 250},
		{"pos": Vector2(3648, 3024), "type": "melee", "activation": 0},
		{"pos": Vector2(3792, 2976), "type": "melee", "activation": 0},
	])
	list.append_array([
		{"pos": Vector2(3600, 3168), "type": "melee", "activation": 0},
		{"pos": Vector2(3792, 3240), "type": "melee", "activation": 0},
		{"pos": Vector2(3960, 3168), "type": "melee", "activation": 0},
		{"pos": Vector2(3888, 3312), "type": "ranged", "activation": 250},
		{"pos": Vector2(3816, 3408), "type": "ranged", "activation": 220},
	])
	list.append_array([
		{"pos": Vector2(3552, 3456), "type": "melee", "activation": 0},
		{"pos": Vector2(3744, 3528), "type": "melee", "activation": 0},
		{"pos": Vector2(3672, 3600), "type": "ranged", "activation": 230},
	])
	list.append_array([
		{"pos": Vector2(3912, 3072), "type": "melee", "activation": 0},
		{"pos": Vector2(4080, 3120), "type": "melee", "activation": 0},
		{"pos": Vector2(4176, 3048), "type": "dodger", "activation": 260},
	])

	# ==== 连廊（Stage 2 — 9个敌人） ====
	list.append_array([
		# 左段（x=40..52）: 2 melee + 1 dodger
		{"pos": Vector2(2000, 3120), "type": "melee", "activation": 0},
		{"pos": Vector2(2150, 3080), "type": "melee", "activation": 0},
		{"pos": Vector2(2350, 3150), "type": "dodger", "activation": 260},
		# 中段（x=52..60）: 2 melee + 1 ranged
		{"pos": Vector2(2550, 3100), "type": "melee", "activation": 0},
		{"pos": Vector2(2700, 3060), "type": "melee", "activation": 0},
		{"pos": Vector2(2850, 3140), "type": "ranged", "activation": 260},
		# 右段（x=60..68）: 1 melee + 1 stationary + 1 ranged
		{"pos": Vector2(3000, 3100), "type": "melee", "activation": 0},
		{"pos": Vector2(3150, 3080), "type": "stationary", "activation": 180},
		{"pos": Vector2(3300, 3120), "type": "ranged", "activation": 260},
	])

	# ==== 体育馆前厅（Stage 3 — 5个敌人） ====
	list.append_array([
		{"pos": Vector2(2620, 1250), "type": "elite", "activation": 220},
		{"pos": Vector2(2820, 1220), "type": "elite", "activation": 220},
		{"pos": Vector2(3020, 1250), "type": "elite", "activation": 220},
		{"pos": Vector2(3220, 1280), "type": "elite", "activation": 220},
		{"pos": Vector2(2920, 1320), "type": "dodger", "activation": 300},
	])

	# ==== 体育馆入口精英守卫（Stage 4 — 击败后门开） ====
	list.append_array([
		{"pos": Vector2(2880, 1200), "type": "elite", "activation": 220},
	])

	# ==== Boss间伴随（Stage 4 — 2个 stationary） ====
	# Boss 本身由 game_manager.gd 生成
	list.append_array([
		{"pos": Vector2(2700, 600), "type": "stationary", "activation": 200},
		{"pos": Vector2(3100, 600), "type": "stationary", "activation": 200},
	])

	return list

# =============================================================================
# 碰撞查询
# =============================================================================

func is_wall_at(tx: int, ty: int) -> bool:
	if _tm == null:
		return false
	var sid := _tm.get_cell_source_id(1, Vector2i(tx, ty))
	return sid in [4, 5, 6, 8, 10]  # 所有有碰撞的墙壁 source（含锁门）

func get_tilemap() -> TileMap:
	return _tm

# 生成初始迷雾纹理（全黑=未探索）
func generate_fog_texture() -> ImageTexture:
	var cols := int(ceil(MW / float(T)))
	var rows := int(ceil(MH / float(T)))
	var img := Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0.85))  # 全黑半透明=未探索
	return ImageTexture.create_from_image(img)


# =============================================================================
# 雾层（TileMap Layer 2）— 全黑覆盖，玩家探索后擦除
# =============================================================================

func _draw_fog_layer() -> void:
	var cols := int(ceil(MW / float(T)))
	var rows := int(ceil(MH / float(T)))
	for x in cols:
		for y in rows:
			_tm.set_cell(2, Vector2i(x, y), 9, Vector2i(0, 0))

func reveal_fog_area(world_x: float, world_y: float, radius_tiles: int) -> void:
	var cx := int(world_x / T)
	var cy := int(world_y / T)
	var cols := int(ceil(MW / float(T)))
	var rows := int(ceil(MH / float(T)))
	for dx in range(-radius_tiles, radius_tiles + 1):
		for dy in range(-radius_tiles, radius_tiles + 1):
			if dx * dx + dy * dy > radius_tiles * radius_tiles:
				continue
			var tx := cx + dx
			var ty := cy + dy
			if tx >= 0 and tx < cols and ty >= 0 and ty < rows:
				_tm.erase_cell(2, Vector2i(tx, ty))
