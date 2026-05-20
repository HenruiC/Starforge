@tool
extends EditorPlugin

const DialogueEditorDock := preload("res://addons/combat_tools/dialogue_editor/dialogue_editor_dock.gd")
const SkillInspectorPlugin := preload("res://addons/combat_tools/skill_editor/skill_inspector_plugin.gd")
const MissionGraphEditor := preload("res://addons/combat_tools/mission_editor/mission_graph_editor.gd")
const DungeonBlueprintEditor := preload("res://addons/combat_tools/dungeon_blueprint/dungeon_blueprint_editor.gd")

var _dialogue_dock: Control
var _skill_inspector: EditorInspectorPlugin
var _mission_editor: Control
var _blueprint_editor: Control


func _enter_tree() -> void:
	_dialogue_dock = DialogueEditorDock.new()
	_dialogue_dock.name = "对话编辑器"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dialogue_dock)

	_skill_inspector = SkillInspectorPlugin.new()
	add_inspector_plugin(_skill_inspector)

	_mission_editor = MissionGraphEditor.new()
	_mission_editor.name = "任务编辑器"
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _mission_editor)

	_blueprint_editor = DungeonBlueprintEditor.new()
	_blueprint_editor.name = "蓝图编辑器"
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _blueprint_editor)

	print("[CombatTools] 已加载 — 对话 + 技能 + 任务 + 蓝图编辑器")


func _exit_tree() -> void:
	if _dialogue_dock:
		remove_control_from_docks(_dialogue_dock)
		_dialogue_dock.free()
	if _mission_editor:
		remove_control_from_docks(_mission_editor)
		_mission_editor.free()
	if _blueprint_editor:
		remove_control_from_docks(_blueprint_editor)
		_blueprint_editor.free()
	if _skill_inspector:
		remove_inspector_plugin(_skill_inspector)

	print("[CombatTools] 已卸载")
