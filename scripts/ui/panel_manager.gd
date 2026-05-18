class_name PanelManager
extends Node

# Panel模块化管理 — 杨奇/小岛/马斯克联合设计
# 所有UI面板统一注册, 统一生命周期: show→interact→hide

static var instance: PanelManager

var panels: Dictionary = {}
var _hud_layer: CanvasLayer

func _ready() -> void:
	instance = self
	_hud_layer = get_node("../HUDLayer") as CanvasLayer

func register(panel_id: String, panel: Control) -> void:
	panels[panel_id] = panel

func show(panel_id: String) -> void:
	if panels.has(panel_id):
		panels[panel_id].visible = true

func hide(panel_id: String) -> void:
	if panels.has(panel_id):
		panels[panel_id].visible = false

func toggle(panel_id: String) -> void:
	if panels.has(panel_id):
		panels[panel_id].visible = not panels[panel_id].visible

func is_visible(panel_id: String) -> bool:
	return panels.has(panel_id) and panels[panel_id].visible

func hide_all() -> void:
	for p in panels.values():
		p.visible = false

func get_hud() -> CanvasLayer:
	return _hud_layer
