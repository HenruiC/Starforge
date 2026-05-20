@tool
extends RefCounted

## 副本蓝图五类节点工厂 + 基类
##
## 五类节点：
##   Trigger  — 等事件 → 1输出
##   Condition — 判断 → True(0)/False(1) 双输出
##   Action    — 执行逻辑 → 1输入 1输出
##   Logic     — 运算 → 2输入 1输出
##   Variable  — 读/写 → 1输入 1输出

enum NodeCategory { TRIGGER, CONDITION, ACTION, LOGIC, VARIABLE }

## 节点定义: {name, category, slots_in, slots_out, default_data}
static var registry: Array[Dictionary] = []


static func _init_registry() -> void:
	if not registry.is_empty():
		return

	# === TRIGGER (无输入, 1输出) ===
	registry.append_array([
		{name="OnZoneEnter", cat=NodeCategory.TRIGGER, in_p=0, out_p=1, data={zone_id=""}},
		{name="OnEnemyKilled", cat=NodeCategory.TRIGGER, in_p=0, out_p=1, data={enemy_type="", count=1}},
		{name="OnObjectiveDone", cat=NodeCategory.TRIGGER, in_p=0, out_p=1, data={objective_id=""}},
		{name="OnPlayerEnter", cat=NodeCategory.TRIGGER, in_p=0, out_p=1, data={}},
	])

	# === CONDITION (1输入, 2输出: True/False) ===
	registry.append_array([
		{name="CompareVar", cat=NodeCategory.CONDITION, in_p=1, out_p=2, data={var_name="", op=">=", value="0"}},
		{name="CheckStage", cat=NodeCategory.CONDITION, in_p=1, out_p=2, data={stage_id=0}},
		{name="CheckDoor", cat=NodeCategory.CONDITION, in_p=1, out_p=2, data={door_id="", state="locked"}},
		{name="HasItem", cat=NodeCategory.CONDITION, in_p=1, out_p=2, data={item_id=""}},
	])

	# === ACTION (1输入, 1输出) ===
	registry.append_array([
		{name="PlayDialogue", cat=NodeCategory.ACTION, in_p=1, out_p=1, data={dialogue_path=""}},
		{name="UnlockDoor", cat=NodeCategory.ACTION, in_p=1, out_p=1, data={door_id=""}},
		{name="CompleteObjective", cat=NodeCategory.ACTION, in_p=1, out_p=1, data={objective_id=""}},
		{name="AdvanceStage", cat=NodeCategory.ACTION, in_p=1, out_p=1, data={}},
		{name="SpawnEnemy", cat=NodeCategory.ACTION, in_p=1, out_p=1, data={enemy_config="melee", pos_x=0.0, pos_y=0.0}},
		{name="TeleportPlayer", cat=NodeCategory.ACTION, in_p=1, out_p=1, data={pos_x=0.0, pos_y=0.0}},
		{name="SetVariable", cat=NodeCategory.ACTION, in_p=1, out_p=1, data={var_name="", value=""}},
		{name="Wait", cat=NodeCategory.ACTION, in_p=1, out_p=1, data={seconds=1.0}},
	])

	# === LOGIC (2输入, 1输出) ===
	registry.append_array([
		{name="AND", cat=NodeCategory.LOGIC, in_p=2, out_p=1, data={}},
		{name="OR", cat=NodeCategory.LOGIC, in_p=2, out_p=1, data={}},
		{name="NOT", cat=NodeCategory.LOGIC, in_p=1, out_p=1, data={}},
		{name="Compare", cat=NodeCategory.LOGIC, in_p=2, out_p=1, data={op="=="}},
	])

	# === VARIABLE (1输入, 1输出) ===
	registry.append_array([
		{name="GetVar", cat=NodeCategory.VARIABLE, in_p=0, out_p=1, data={var_name=""}},
		{name="SetVar", cat=NodeCategory.VARIABLE, in_p=1, out_p=1, data={var_name="", value=""}},
	])


static func get_by_category(cat: int) -> Array[Dictionary]:
	_init_registry()
	var result: Array[Dictionary] = []
	for def in registry:
		if def.cat == cat:
			result.append(def)
	return result


static func find_def(node_name: String) -> Dictionary:
	_init_registry()
	for def in registry:
		if def.name == node_name:
			return def
	return {}


# int keys: TRIGGER=0, CONDITION=1, ACTION=2, LOGIC=3, VARIABLE=4
const CAT_COLORS: Dictionary = {
	0: Color(0.2, 0.6, 0.2),
	1: Color(0.8, 0.6, 0.1),
	2: Color(0.2, 0.4, 0.8),
	3: Color(0.6, 0.2, 0.8),
	4: Color(0.3, 0.7, 0.7),
}

const CAT_NAMES: Dictionary = {
	0: "Trigger",
	1: "Condition",
	2: "Action",
	3: "Logic",
	4: "Variable",
}


## 创建 GraphNode 实例
static func create_node(node_def: Dictionary, node_id: String, x: float, y: float) -> GraphNode:
	var gn := GraphNode.new()
	gn.name = node_id
	gn.title = node_def.name
	gn.position_offset = Vector2(x, y)
	gn.size = Vector2(160, 60)
	gn.set_meta("bp_type", node_def.name)
	gn.set_meta("bp_cat", node_def.cat)

	# 颜色标记
	var cat: int = node_def.cat
	if cat in CAT_COLORS:
		var overlay := ColorRect.new()
		overlay.color = CAT_COLORS[cat]
		overlay.color.a = 0.15
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		gn.add_child(overlay)

	# 端口
	for i: int in node_def.in_p:
		gn.set_slot(i, true, 0, CAT_COLORS.get(cat, Color.WHITE), false, 0, Color.WHITE)
	for i: int in node_def.out_p:
		var slot_idx: int = node_def.in_p + i
		var out_label: int = 0 if node_def.out_p == 1 else i
		gn.set_slot(slot_idx, false, 0, Color.WHITE, true, out_label, CAT_COLORS.get(cat, Color.WHITE))

	# 数据预览
	var vb := VBoxContainer.new()
	vb.name = "Data"
	for key: String in node_def.data:
		var val = node_def.data[key]
		var lbl := Label.new()
		lbl.text = "%s: %s" % [key, str(val)]
		lbl.add_theme_font_size_override("font_size", 9)
		vb.add_child(lbl)
	gn.add_child(vb)

	return gn
