@tool
extends Control

## 任务编辑器 — 杨奇规范 v1.0 · GraphEdit 可视化编辑 MissionChain

const COLOR_GOLD := Color(0.722, 0.525, 0.043)
const COLOR_TEXT := Color(0.941, 0.902, 0.827)
const COLOR_DIM := Color(0.333, 0.333, 0.333)

const StageNodeClass := preload("res://addons/combat_tools/mission_editor/stage_node.gd")

var _graph: GraphEdit
var _stage_nodes: Array[GraphNode] = []
var _current_path: String = ""
var _status_label: Label


func _init() -> void:
	name = "任务编辑器"
	_build_ui()


func _build_ui() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(500, 350)

	var root := VBoxContainer.new()
	root.set_anchors_preset(PRESET_FULL_RECT)
	add_child(root)

	# ==== 工具栏 ====
	var tb := HBoxContainer.new(); tb.add_theme_constant_override("separation", 4); root.add_child(tb)
	var btn_new := _btn("新建链"); btn_new.pressed.connect(_on_new); tb.add_child(btn_new)
	var btn_open := _btn("打开"); btn_open.pressed.connect(_on_open); tb.add_child(btn_open)
	var btn_save := _btn("保存"); btn_save.pressed.connect(_on_save); tb.add_child(btn_save)
	var btn_as := _btn("另存为"); btn_as.pressed.connect(_on_save_as); tb.add_child(btn_as)
	var btn_stage := _btn("+Stage"); btn_stage.pressed.connect(_on_add_stage); tb.add_child(btn_stage)
	_status_label = Label.new(); _status_label.add_theme_color_override("font_color", COLOR_DIM)
	tb.add_child(_status_label)

	# ==== GraphEdit 画布 ====
	_graph = GraphEdit.new()
	_graph.size_flags_horizontal = SIZE_EXPAND_FILL
	_graph.size_flags_vertical = SIZE_EXPAND_FILL
	_graph.right_disconnects = 0
	_graph.scroll_offset = Vector2(20, 20)
	_graph.connection_request.connect(_on_connection_request)
	_graph.disconnection_request.connect(_on_disconnection_request)
	_graph.node_selected.connect(_on_node_selected)
	root.add_child(_graph)

	# ==== 底部属性栏 ====
	var pp := PanelContainer.new(); root.add_child(pp)
	var pl := Label.new(); pl.name = "PropLabel"
	pl.add_theme_color_override("font_color", COLOR_DIM)
	pp.add_child(pl)

	_on_new()


# ==============================================================================
func _btn(text: String) -> Button:
	var b := Button.new(); b.text = text
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_font_size_override("font_size", 11)
	return b


# ==============================================================================
func _on_new() -> void:
	_graph.clear_connections()
	for n in _stage_nodes:
		_graph.remove_child(n); n.queue_free()
	_stage_nodes.clear()
	_current_path = ""

	# ChainRoot 节点
	var root_node := GraphNode.new()
	root_node.name = "ChainRoot"; root_node.title = "任务链"
	root_node.set_slot(0, false, 0, COLOR_GOLD, true, 0, COLOR_GOLD)
	root_node.position_offset = Vector2(40, 40); root_node.size = Vector2(160, 40)
	var vb := VBoxContainer.new(); vb.name = "ChainFields"; root_node.add_child(vb)
	var nr := HBoxContainer.new(); vb.add_child(nr)
	nr.add_child(_lbl("名称:"))
	var ne := LineEdit.new(); ne.name = "chain_name"; ne.size_flags_horizontal = SIZE_EXPAND_FILL; nr.add_child(ne)
	_graph.add_child(root_node)

	_show_empty_hint()
	_update_status()
	print("[任务编辑器] 新建链")


func _show_empty_hint() -> void:
	var lbl := _graph.get_node_or_null("EmptyHint")
	if lbl == null:
		lbl = Label.new(); lbl.name = "EmptyHint"
		lbl.add_theme_color_override("font_color", COLOR_DIM)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.position_offset = Vector2(260, 80)
		_graph.add_child(lbl)
	lbl.text = "点击「+Stage」创建第一个任务阶段"
	lbl.visible = _stage_nodes.is_empty()


func _on_add_stage() -> void:
	var node := StageNodeClass.new()
	node.stage_index = _stage_nodes.size()
	node.position_offset = Vector2(40, 140 + _stage_nodes.size() * 220)
	_graph.add_child(node)
	_stage_nodes.append(node)

	if _stage_nodes.size() == 1:
		_graph.connect_node("ChainRoot", 0, node.name, 0)
	else:
		var prev := _stage_nodes[_stage_nodes.size() - 2]
		_graph.connect_node(prev.name, 0, node.name, 0)

	_show_empty_hint()
	_update_status()
	print("[任务编辑器] +Stage %d" % node.stage_index)


# ==============================================================================
func _on_connection_request(f: StringName, fp: int, t: StringName, tp: int) -> void:
	_graph.connect_node(f, fp, t, tp)

func _on_disconnection_request(f: StringName, fp: int, t: StringName, tp: int) -> void:
	_graph.disconnect_node(f, fp, t, tp)

func _on_node_selected(node: Node) -> void:
	var lbl := get_node_or_null("VBoxContainer/PanelContainer/PropLabel") as Label
	if lbl == null: return
	if node is StageNodeClass:
		lbl.text = "Stage %d: %s" % [node.stage_index, node.stage_title]
	else:
		lbl.text = ""

func _update_status() -> void:
	var n := _stage_nodes.size()
	var p := _current_path
	var fn := "未保存" if p.is_empty() else p.get_file()
	_status_label.text = " %s · %d阶段" % [fn, n]


# ==============================================================================
func _on_save() -> void:
	if _current_path.is_empty(): _on_save_as(); return
	var chain := _build_chain()
	if chain:
		var err: int = ResourceSaver.save(chain, _current_path)
		if err == OK: print("[任务编辑器] 已保存: %s" % _current_path)
		else: push_error("[任务编辑器] 保存失败: %d" % err)

func _on_save_as() -> void:
	var fd := EditorFileDialog.new()
	fd.access = EditorFileDialog.ACCESS_RESOURCES
	fd.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	fd.add_filter("*.tres", "MissionChain")
	fd.file_selected.connect(func(path: String):
		_current_path = path; _update_status(); _on_save(); fd.queue_free()
	)
	add_child(fd); fd.popup_centered_ratio(0.6)

func _on_open() -> void:
	var fd := EditorFileDialog.new()
	fd.access = EditorFileDialog.ACCESS_RESOURCES
	fd.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	fd.add_filter("*.tres", "MissionChain")
	fd.file_selected.connect(func(path: String):
		var r := load(path)
		if r is MissionChain: _load_chain(r, path); print("[任务编辑器] 已加载: %s" % path)
		fd.queue_free()
	)
	add_child(fd); fd.popup_centered_ratio(0.6)


# ==============================================================================
func _load_chain(chain: MissionChain, path: String) -> void:
	_on_new(); _current_path = path
	# 填 ChainRoot 字段
	var root_node := _graph.get_node_or_null(NodePath("ChainRoot")) as GraphNode
	if root_node:
		var fields := root_node.get_node_or_null("ChainFields")
		if fields:
			var e := fields.get_node_or_null("chain_name") as LineEdit
			if e: e.text = chain.chain_name
	for stage: MissionStage in chain.stages:
		var node := StageNodeClass.new()
		node.position_offset = Vector2(40, 140 + _stage_nodes.size() * 220)
		_graph.add_child(node)
		node.load_stage(stage)
		_stage_nodes.append(node)
	if _stage_nodes.size() > 0:
		_graph.connect_node("ChainRoot", 0, _stage_nodes[0].name, 0)
		for i: int in _stage_nodes.size() - 1:
			var ok := false
			for conn: Dictionary in _graph.get_connection_list():
				if conn.from_node == _stage_nodes[i].name and conn.to_node == _stage_nodes[i + 1].name:
					ok = true; break
			if not ok:
				_graph.connect_node(_stage_nodes[i].name, 0, _stage_nodes[i + 1].name, 0)
	_show_empty_hint(); _update_status()


func _build_chain() -> MissionChain:
	var chain := MissionChain.new()
	# 读 ChainRoot 字段
	var root_node := _graph.get_node_or_null(NodePath("ChainRoot")) as GraphNode
	if root_node:
		var fields := root_node.get_node_or_null("ChainFields")
		if fields:
			chain.chain_name = _text_val(fields, "chain_name")
	var ordered := _get_ordered_stages()
	for gn: GraphNode in ordered:
		if gn is StageNodeClass: chain.stages.append(gn.build_stage())
	return chain


func _get_ordered_stages() -> Array:
	var result: Array = []
	var visited: Dictionary = {}
	var cur: String = "ChainRoot"
	while true:
		var found := false
		for conn: Dictionary in _graph.get_connection_list():
			if conn.from_node == cur and not visited.get(conn.to_node, false):
				var gn := _graph.get_node(NodePath(conn.to_node)) as GraphNode
				if gn: result.append(gn); visited[conn.to_node] = true; cur = conn.to_node; found = true; break
		if not found: break
	return result


func _text_val(parent: Node, name: String) -> String:
	var e := parent.get_node_or_null(name) as LineEdit
	return e.text if e else ""


func _lbl(t: String) -> Label:
	var l := Label.new(); l.text = t
	l.add_theme_color_override("font_color", COLOR_TEXT)
	l.add_theme_font_size_override("font_size", 10)
	return l
