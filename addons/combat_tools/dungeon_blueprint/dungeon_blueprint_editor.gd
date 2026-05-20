@tool
extends Control

## 副本蓝图编辑器 — GraphEdit 可视化副本逻辑编辑
##
## 五类节点：Trigger/Condition/Action/Logic/Variable
## 右键菜单按分类添加节点，拖拽连线，保存为 DungeonGraph .tres

const BlueprintNodes := preload("res://addons/combat_tools/dungeon_blueprint/blueprint_nodes.gd")

var _graph: GraphEdit
var _file_dialog: EditorFileDialog
var _current_path: String = ""
var _node_counter: int = 0


func _init() -> void:
	_build_ui()


func _build_ui() -> void:
	size = Vector2(750, 500)
	custom_minimum_size = Vector2(500, 350)

	var root := VBoxContainer.new()
	add_child(root)

	# 工具栏
	var toolbar := HBoxContainer.new()
	root.add_child(toolbar)

	var btn_new := Button.new(); btn_new.text = "新建"; btn_new.pressed.connect(_on_new)
	var btn_open := Button.new(); btn_open.text = "打开"; btn_open.pressed.connect(_on_open)
	var btn_save := Button.new(); btn_save.text = "保存"; btn_save.pressed.connect(_on_save)
	var btn_save_as := Button.new(); btn_save_as.text = "另存为"; btn_save_as.pressed.connect(_on_save_as)
	toolbar.add_child(btn_new)
	toolbar.add_child(btn_open)
	toolbar.add_child(btn_save)
	toolbar.add_child(btn_save_as)

	var cat_label := Label.new(); cat_label.text = "  右键画布添加节点:"
	toolbar.add_child(cat_label)
	for cat_idx in [BlueprintNodes.NodeCategory.TRIGGER, BlueprintNodes.NodeCategory.CONDITION, BlueprintNodes.NodeCategory.ACTION, BlueprintNodes.NodeCategory.LOGIC, BlueprintNodes.NodeCategory.VARIABLE]:
		var cat_name: String = BlueprintNodes.CAT_NAMES[cat_idx]
		var cat_color: Color = BlueprintNodes.CAT_COLORS[cat_idx]
		var chip := ColorRect.new()
		chip.color = cat_color; chip.custom_minimum_size = Vector2(12, 12)
		toolbar.add_child(chip)
		var lbl := Label.new(); lbl.text = cat_name
		toolbar.add_child(lbl)

	# GraphEdit 画布
	_graph = GraphEdit.new()
	_graph.size_flags_horizontal = SIZE_EXPAND_FILL
	_graph.size_flags_vertical = SIZE_EXPAND_FILL
	_graph.right_disconnects = 0
	_graph.connection_request.connect(_on_connection_request)
	_graph.disconnection_request.connect(_on_disconnection_request)
	_graph.node_selected.connect(_on_node_selected)
	_graph.node_deselected.connect(_on_node_deselected)
	_graph.gui_input.connect(_on_graph_input)
	root.add_child(_graph)

	# 底部属性面板
	var prop_panel := PanelContainer.new()
	root.add_child(prop_panel)
	var prop_label := Label.new()
	prop_label.name = "PropLabel"
	prop_label.text = "右键画布添加节点 | 拖拽端口连线 | 选中节点编辑属性"
	prop_panel.add_child(prop_label)

	# 文件对话框
	_file_dialog = EditorFileDialog.new()
	_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_file_dialog.add_filter("*.tres", "DungeonGraph Resource")
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)


# ==============================================================================
# 节点管理
# ==============================================================================

func _add_node_at(node_def: Dictionary, pos: Vector2) -> void:
	_node_counter += 1
	var node_id := "%s_%d" % [node_def.name, _node_counter]
	var gn := BlueprintNodes.create_node(node_def, node_id, pos.x, pos.y)
	_graph.add_child(gn)


func _show_context_menu(screen_pos: Vector2) -> void:
	var menu := PopupMenu.new()
	menu.name = "ContextMenu"

	for cat_idx in [BlueprintNodes.NodeCategory.TRIGGER, BlueprintNodes.NodeCategory.CONDITION, BlueprintNodes.NodeCategory.ACTION, BlueprintNodes.NodeCategory.LOGIC, BlueprintNodes.NodeCategory.VARIABLE]:
		var defs := BlueprintNodes.get_by_category(cat_idx)
		if defs.is_empty():
			continue
		menu.add_separator(BlueprintNodes.CAT_NAMES[cat_idx])
		for def in defs:
			menu.add_item(def.name)
			menu.set_item_metadata(menu.item_count - 1, {"def": def, "pos": screen_pos + _graph.scroll_offset})

	menu.id_pressed.connect(_on_menu_selected)
	menu.popup_hide.connect(menu.queue_free)
	_graph.add_child(menu)
	menu.position = screen_pos
	menu.popup()


func _on_menu_selected(id: int) -> void:
	var menu := _graph.get_node_or_null(NodePath("ContextMenu")) as PopupMenu
	if menu == null:
		return
	var meta: Dictionary = menu.get_item_metadata(id)
	var node_def: Dictionary = meta["def"]
	var pos: Vector2 = meta["pos"]
	_add_node_at(node_def, pos)


# ==============================================================================
# GraphEdit 信号
# ==============================================================================

func _on_graph_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_show_context_menu(event.position)


func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	_graph.connect_node(from_node, from_port, to_node, to_port)


func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	_graph.disconnect_node(from_node, from_port, to_node, to_port)


func _on_node_selected(node: Node) -> void:
	var label := get_node_or_null("VBoxContainer/PanelContainer/PropLabel") as Label
	if label == null:
		return
	var bp_type := node.get_meta("bp_type", "")
	var bp_cat := node.get_meta("bp_cat", -1)
	label.text = "[%s] %s — 选中后可编辑属性" % [BlueprintNodes.CAT_NAMES.get(bp_cat, "?"), bp_type]


func _on_node_deselected(_node: Node) -> void:
	var label := get_node_or_null("VBoxContainer/PanelContainer/PropLabel") as Label
	if label:
		label.text = "右键画布添加节点 | 拖拽端口连线 | 选中节点编辑属性"


# ==============================================================================
# 保存 / 加载
# ==============================================================================

func _on_new() -> void:
	for child in _graph.get_children():
		if child is GraphNode:
			_graph.remove_child(child)
			child.queue_free()
	_graph.clear_connections()
	_node_counter = 0
	_current_path = ""


func _on_save() -> void:
	if _current_path.is_empty():
		_on_save_as()
		return
	var dg := _serialize()
	if dg:
		var err := ResourceSaver.save(dg, _current_path)
		if err == OK:
			print("[BlueprintEditor] 已保存: %s" % _current_path)
		else:
			push_error("[BlueprintEditor] 保存失败: %d" % err)


func _on_save_as() -> void:
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.popup_centered_ratio(0.6)


func _on_open() -> void:
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.popup_centered_ratio(0.6)


func _on_file_selected(path: String) -> void:
	if _file_dialog.file_mode == EditorFileDialog.FILE_MODE_OPEN_FILE:
		var dg := load(path) as DungeonGraph
		if dg:
			_deserialize(dg, path)
		else:
			push_error("[BlueprintEditor] 无效文件: %s" % path)
	else:
		_current_path = path
		_on_save()


func _serialize() -> DungeonGraph:
	var dg := DungeonGraph.new()
	dg.graph_id = "dungeon_%d" % randi()

	for child in _graph.get_children():
		if not (child is GraphNode):
			continue
		var gn := child as GraphNode
		dg.nodes.append({
			"type": gn.get_meta("bp_type", ""),
			"id": gn.name,
			"x": gn.position_offset.x,
			"y": gn.position_offset.y,
			"data": gn.get_meta("bp_data", {})
		})

	for conn in _graph.get_connection_list():
		dg.connections.append({
			"from_node": conn.from_node,
			"from_port": conn.from_port,
			"to_node": conn.to_node,
			"to_port": conn.to_port,
		})

	return dg


func _deserialize(dg: DungeonGraph, path: String) -> void:
	_on_new()
	_current_path = path

	for node_data in dg.nodes:
		var def := BlueprintNodes.find_def(node_data.type)
		if def.is_empty():
			continue
		var gn := BlueprintNodes.create_node(def, node_data.id, node_data.x, node_data.y)
		gn.set_meta("bp_data", node_data.get("data", {}))
		_graph.add_child(gn)

	for conn in dg.connections:
		_graph.connect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
