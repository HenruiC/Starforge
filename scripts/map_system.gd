class_name MapSystem
extends Node

# 地图系统: 真实图片+迷雾探索+玩家标记

var _fog_grid: Array = []
var _fog_seen: int = 0
var _fog_total: int = 0
var _player: CharacterBody2D

func init(player_ref: CharacterBody2D, hud_layer: CanvasLayer) -> void:
	_player = player_ref
	var mp := hud_layer.get_node("MapPanel")
	var tr: TextureRect = mp.get_node("MapTexture")
	var path := "res://assets/generated/map_full.jpg"
	if ResourceLoader.exists(path):
		tr.texture = load(path) as Texture2D
	# 初始化迷雾
	var cw := 80.0; var cols := int(ceil(3200.0 / cw)); var rows := int(ceil(2400.0 / cw))
	_fog_total = cols * rows
	for x in cols:
		var row: Array = []
		for y in rows: row.append(false)
		_fog_grid.append(row)

func update() -> void:
	if _player == null: return
	var cx := int(_player.global_position.x / 80)
	var cy := int(_player.global_position.y / 80)
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			if dx*dx + dy*dy > 4: continue
			var nx := cx + dx; var ny := cy + dy
			if nx >= 0 and nx < _fog_grid.size() and ny >= 0 and ny < _fog_grid[0].size():
				if not _fog_grid[nx][ny]: _fog_grid[nx][ny] = true; _fog_seen += 1

	# 玩家标记
	var mp := get_parent().get_node("MapPanel") as Control
	var mk: Label = mp.get_node("PlayerMarker")
	var rx := 800.0 / 3200.0; var ry := 400.0 / 2400.0
	mk.offset_left = -400 + _player.global_position.x * rx - 10
	mk.offset_top = 80 + _player.global_position.y * ry - 12
	mk.offset_right = -400 + _player.global_position.x * rx + 10
	mk.offset_bottom = 80 + _player.global_position.y * ry + 15

	# 区域名 + 探索率
	mp.get_node("ZoneLabel").text = "当前位置: %s" % _zone_name(_player.global_position.y)
	var pct := 0.0
	if _fog_total > 0: pct = float(_fog_seen) / float(_fog_total) * 100.0
	mp.get_node("Hint").text = "[ M 打开 | ESC 关闭 ]  已探索: %.0f%%" % pct

func _zone_name(y: float) -> String:
	if y > 1800: return "操场"
	if y > 1500: return "玄关"
	if y > 1100: return "走廊"
	if y > 700: return "教室"
	return "体育馆"
