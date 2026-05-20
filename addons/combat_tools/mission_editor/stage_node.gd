@tool
extends GraphNode

## 任务阶段节点 — MissionStage 可视化编辑 · 杨奇规范

var stage_index: int = 0:
	set(v):
		stage_index = v
		title = "Stage %d: %s" % [v + 1, _title_edit.text if _title_edit else ""]

var stage_title: String:
	get: return _title_edit.text if _title_edit else ""

var _title_edit: LineEdit
var _obj_container: VBoxContainer
var _act_dialogue_edit: LineEdit
var _comp_dialogue_edit: LineEdit
var _act_dialogue_group: LineEdit
var _comp_dialogue_group: LineEdit
var _act_prompt_edit: LineEdit
var _comp_prompt_edit: LineEdit
var _act_zone_edit: LineEdit
var _act_target_edit: LineEdit


func _init() -> void:
	_build_ui()


func _build_ui() -> void:
	title = "Stage"
	size = Vector2(360, 280)
	set_slot(0, true, 0, Color.WHITE, true, 0, Color(0.3, 0.8, 0.3))

	var vb := VBoxContainer.new(); vb.name = "StageFields"; add_child(vb)

	vb.add_child(_lbl("阶段标题"))
	_title_edit = LineEdit.new(); _title_edit.text = "新阶段"; _title_edit.name = "Title"
	vb.add_child(_title_edit)

	# 激活条件
	vb.add_child(_lbl("激活条件 (zone_id → 目标值)"))
	var ar := HBoxContainer.new()
	_act_zone_edit = LineEdit.new(); _act_zone_edit.placeholder_text = "Zone ID"; _act_zone_edit.size_flags_horizontal = SIZE_EXPAND_FILL; _act_zone_edit.name = "ActZone"
	_act_target_edit = LineEdit.new(); _act_target_edit.placeholder_text = "目标值"; _act_target_edit.name = "ActTarget"
	ar.add_child(_act_zone_edit); ar.add_child(_act_target_edit)
	vb.add_child(ar)

	# 提示
	vb.add_child(_lbl("激活提示"))
	_act_prompt_edit = LineEdit.new(); _act_prompt_edit.name = "OnActPrompt"; vb.add_child(_act_prompt_edit)
	vb.add_child(_lbl("完成提示"))
	_comp_prompt_edit = LineEdit.new(); _comp_prompt_edit.name = "OnCompPrompt"; vb.add_child(_comp_prompt_edit)

	# 对话引用
	vb.add_child(_lbl("激活对话 (DialogueBook路径)"))
	var d1 := HBoxContainer.new()
	_act_dialogue_edit = LineEdit.new(); _act_dialogue_edit.placeholder_text = "res://xxx_book.tres"; _act_dialogue_edit.size_flags_horizontal = SIZE_EXPAND_FILL; _act_dialogue_edit.name = "OnActDialogue"
	d1.add_child(_act_dialogue_edit)
	_act_dialogue_group = LineEdit.new(); _act_dialogue_group.placeholder_text = "组ID"; _act_dialogue_group.name = "OnActDialogueGroup"
	d1.add_child(_act_dialogue_group)
	vb.add_child(d1)

	vb.add_child(_lbl("完成对话 (DialogueBook路径)"))
	var d2 := HBoxContainer.new()
	_comp_dialogue_edit = LineEdit.new(); _comp_dialogue_edit.placeholder_text = "res://xxx_book.tres"; _comp_dialogue_edit.size_flags_horizontal = SIZE_EXPAND_FILL; _comp_dialogue_edit.name = "OnCompDialogue"
	d2.add_child(_comp_dialogue_edit)
	_comp_dialogue_group = LineEdit.new(); _comp_dialogue_group.placeholder_text = "组ID"; _comp_dialogue_group.name = "OnCompDialogueGroup"
	d2.add_child(_comp_dialogue_group)
	vb.add_child(d2)

	# Objective 列表
	vb.add_child(_lbl("目标"))
	_obj_container = VBoxContainer.new(); _obj_container.name = "Objectives"; vb.add_child(_obj_container)
	var btn_obj := Button.new(); btn_obj.text = "+目标"; btn_obj.pressed.connect(_on_add_objective)
	vb.add_child(btn_obj)

	_on_add_objective()
	_update_size()


func _lbl(t: String) -> Label:
	var l := Label.new(); l.text = t
	l.add_theme_color_override("font_color", Color(0.941, 0.902, 0.827))
	l.add_theme_font_size_override("font_size", 10)
	return l


func _on_add_objective() -> void:
	var row := _make_obj_row(); _obj_container.add_child(row); _update_size()

func _on_remove_objective(row: Control) -> void:
	_obj_container.remove_child(row); row.queue_free(); _update_size()

func _make_obj_row() -> Control:
	var p := PanelContainer.new(); var vb := VBoxContainer.new(); p.add_child(vb)

	var h := HBoxContainer.new(); vb.add_child(h)
	h.add_child(_lbl("目标 %d" % (_obj_container.get_child_count() + 1)))
	var bd := Button.new(); bd.text = "×"; bd.pressed.connect(func(): _on_remove_objective(p)); h.add_child(bd)

	var dr := HBoxContainer.new(); vb.add_child(dr)
	dr.add_child(_lbl("描述:"))
	var de := LineEdit.new(); de.name = "ObjDesc"; de.placeholder_text = "如：击杀8个敌人"; de.size_flags_horizontal = SIZE_EXPAND_FILL; dr.add_child(de)

	var pr := HBoxContainer.new(); vb.add_child(pr)
	pr.add_child(_lbl("Zone/ID:"))
	var pe := LineEdit.new(); pe.name = "ObjParam"; pe.placeholder_text = "zone_id 或 door_id"; pe.size_flags_horizontal = SIZE_EXPAND_FILL; pr.add_child(pe)

	var vr := HBoxContainer.new(); vb.add_child(vr)
	vr.add_child(_lbl("目标值:"))
	var ve := LineEdit.new(); ve.name = "ObjValue"; ve.placeholder_text = "如 8"; ve.size_flags_horizontal = SIZE_EXPAND_FILL; vr.add_child(ve)

	var ar := HBoxContainer.new(); vb.add_child(ar)
	ar.add_child(_lbl("完成动作:"))
	var ae := LineEdit.new(); ae.name = "ObjAction"; ae.placeholder_text = "door_id 或留空"; ae.size_flags_horizontal = SIZE_EXPAND_FILL; ar.add_child(ae)

	var dl := HBoxContainer.new(); vb.add_child(dl)
	dl.add_child(_lbl("完成对话路径:"))
	var de2 := LineEdit.new(); de2.name = "ObjDialogue"; de2.placeholder_text = "res://xxx.tres"; de2.size_flags_horizontal = SIZE_EXPAND_FILL; dl.add_child(de2)

	return p


func _update_size() -> void:
	size = Vector2(360, 280 + _obj_container.get_child_count() * 90)


# ==============================================================================
func build_stage() -> MissionStage:
	var s := MissionStage.new(); s.stage_id = stage_index; s.stage_title = _title_edit.text

	if not _act_zone_edit.text.is_empty():
		s.activation_condition = TriggerConfig.new()
		s.activation_condition.trigger_type = TriggerConfig.MissionTriggerType.LOCATION_REACH
		s.activation_condition.params["zone_id"] = _act_zone_edit.text
		if _act_target_edit.text.is_valid_float(): s.activation_condition.target_value = float(_act_target_edit.text)

	if not _act_prompt_edit.text.is_empty():
		s.on_activate_prompt = PromptConfig.new(); s.on_activate_prompt.text = _act_prompt_edit.text
	if not _comp_prompt_edit.text.is_empty():
		s.on_complete_prompt = PromptConfig.new(); s.on_complete_prompt.text = _comp_prompt_edit.text
	s.on_activate_dialogue = _load_book(_act_dialogue_edit.text)
	s.on_activate_dialogue_group = _act_dialogue_group.text
	s.on_complete_dialogue = _load_book(_comp_dialogue_edit.text)
	s.on_complete_dialogue_group = _comp_dialogue_group.text

	for c in _obj_container.get_children():
		var obj := _build_objective(c)
		if obj: s.objectives.append(obj)
	return s


func _build_objective(panel: Control) -> MissionObjective:
	var vb := panel.get_child(0) as VBoxContainer
	if vb == null: return null
	var obj := MissionObjective.new()
	obj.description = _text(vb, "ObjDesc"); obj.objective_id = obj.description.replace(" ", "_")
	var pid := _text(vb, "ObjParam")
	obj.trigger = TriggerConfig.new()
	obj.trigger.trigger_type = TriggerConfig.MissionTriggerType.KILL_COUNT
	obj.trigger.params["id"] = pid
	var vs := _text(vb, "ObjValue")
	if vs.is_valid_float(): obj.trigger.target_value = float(vs)
	var act := _text(vb, "ObjAction")
	if not act.is_empty(): obj.completion_action = {"type": "unlock_door", "door_id": act}
	obj.on_complete_dialogue = _load_book(_text(vb, "ObjDialogue"))
	return obj


func load_stage(stage: MissionStage) -> void:
	_title_edit.text = stage.stage_title; stage_index = stage.stage_id
	if stage.activation_condition:
		_act_zone_edit.text = stage.activation_condition.params.get("zone_id", "")
		_act_target_edit.text = str(stage.activation_condition.target_value)
	if stage.on_activate_prompt: _act_prompt_edit.text = stage.on_activate_prompt.text
	if stage.on_complete_prompt: _comp_prompt_edit.text = stage.on_complete_prompt.text
	_act_dialogue_edit.text = stage.on_activate_dialogue.resource_path if stage.on_activate_dialogue else ""
	_act_dialogue_group.text = stage.on_activate_dialogue_group
	_comp_dialogue_edit.text = stage.on_complete_dialogue.resource_path if stage.on_complete_dialogue else ""
	_comp_dialogue_group.text = stage.on_complete_dialogue_group
	_update_size()


func _load_book(path: String) -> DialogueBook:
	if path.is_empty() or not ResourceLoader.exists(path): return null
	return load(path) as DialogueBook


func _text(parent: Node, name: String) -> String:
	var n := _find(parent, name); return (n as LineEdit).text if n else ""

func _find(p: Node, name: String) -> Node:
	for c in p.get_children():
		if c.name == name: return c
		var f := _find(c, name); if f: return f
	return null
