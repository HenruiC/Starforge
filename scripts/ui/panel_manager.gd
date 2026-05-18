class_name PanelManager
extends Node

# Panel模块化管理 — 杨奇/小岛/马斯克联合设计
# 所有UI面板统一注册, 统一生命周期: show→interact→hide
#
# 增强 v2: 加入淡入淡出过渡 + 面板状态追踪 + 中断处理

enum PanelState { HIDDEN, ENTERING, ACTIVE, EXITING }

static var instance: PanelManager

var panels: Dictionary = {}
var _panel_states: Dictionary = {}  # panel_id: PanelState
var _hud_layer: CanvasLayer


func _ready() -> void:
	instance = self
	_hud_layer = get_node("../HUDLayer") as CanvasLayer


func register(panel_id: String, panel: Control) -> void:
	panels[panel_id] = panel
	_panel_states[panel_id] = PanelState.HIDDEN


func show(panel_id: String) -> void:
	if not panels.has(panel_id):
		return
	var p: Control = panels[panel_id]
	var state: PanelState = _panel_states.get(panel_id, PanelState.HIDDEN)

	match state:
		PanelState.HIDDEN, PanelState.EXITING:
			if state == PanelState.EXITING:
				# 反向: 正在淡出 → 改为淡入 (从当前alpha值开始)
				UIEffects.kill_group(_group_for(panel_id))
				_panel_states[panel_id] = PanelState.ENTERING
				var from_a: float = p.modulate.a
				var t2: Tween = UIEffects.panel_in(p, _group_for(panel_id), from_a)
				t2.finished.connect(_on_show_tween_finished.bind(panel_id), CONNECT_ONE_SHOT)
			else:
				_panel_states[panel_id] = PanelState.ENTERING
				var t: Tween = UIEffects.panel_in(p, _group_for(panel_id))
				t.finished.connect(_on_show_tween_finished.bind(panel_id), CONNECT_ONE_SHOT)

		PanelState.ENTERING, PanelState.ACTIVE:
			# 已在进入或已激活, 不做任何事
			pass


func hide(panel_id: String) -> void:
	if not panels.has(panel_id):
		return
	var p: Control = panels[panel_id]
	var state: PanelState = _panel_states.get(panel_id, PanelState.HIDDEN)

	match state:
		PanelState.ACTIVE, PanelState.ENTERING:
			if state == PanelState.ENTERING:
				# 正在淡入 → 反向为淡出
				UIEffects.kill_group(_group_for(panel_id))

			_panel_states[panel_id] = PanelState.EXITING
			var t: Tween = UIEffects.panel_out(p, _group_for(panel_id))
			t.finished.connect(_on_hide_tween_finished.bind(panel_id), CONNECT_ONE_SHOT)

		PanelState.HIDDEN, PanelState.EXITING:
			# 已隐藏或正在淡出, 不做任何事
			pass


func toggle(panel_id: String) -> void:
	if not panels.has(panel_id):
		return
	var state: PanelState = _panel_states.get(panel_id, PanelState.HIDDEN)
	match state:
		PanelState.HIDDEN, PanelState.EXITING:
			show(panel_id)
		PanelState.ACTIVE, PanelState.ENTERING:
			hide(panel_id)


func is_visible(panel_id: String) -> bool:
	return panels.has(panel_id) and panels[panel_id].visible


func get_state(panel_id: String) -> PanelState:
	return _panel_states.get(panel_id, PanelState.HIDDEN)


func hide_all() -> void:
	for panel_id in panels.keys():
		hide(panel_id)


func get_hud() -> CanvasLayer:
	return _hud_layer


# ---- 内部 ----

func _group_for(panel_id: String) -> String:
	return "panel_%s" % panel_id


func _on_show_tween_finished(panel_id: String) -> void:
	if _panel_states.get(panel_id) == PanelState.ENTERING:
		_panel_states[panel_id] = PanelState.ACTIVE


func _on_hide_tween_finished(panel_id: String) -> void:
	if _panel_states.get(panel_id) == PanelState.EXITING:
		_panel_states[panel_id] = PanelState.HIDDEN
