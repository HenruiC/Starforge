class_name PanelManager
extends Node

# Panel模块化管理 — 方案A: 统一面板优先级队列
# 所有UI面板统一走优先级队列, 对话不再特殊处理
#
# 核心规则:
# - 高优先级（数字小）请求 → 预占低优先级面板, 将低优先级推入队列前端（保留、不丢失）
# - 低优先级请求 → 排队等待直到高优先级面板关闭
# - 面板关闭时 → 自动从队列弹出下一个面板
#
# 增强 v2: 加入淡入淡出过渡 + 面板状态追踪 + 中断处理

enum PanelState { HIDDEN, ENTERING, ACTIVE, EXITING }

signal panel_shown(panel_id: String)     # 面板show()时发出
signal panel_closed(panel_id: String)    # 面板notify_closed时发出

static var instance: PanelManager

var panels: Dictionary = {}
var _panel_states: Dictionary = {}  # panel_id: PanelState
var _hud_layer: CanvasLayer


func _ready() -> void:
	instance = self
	_hud_layer = get_node("../../HUDLayer") as CanvasLayer


func register(panel_id: String, panel: Control) -> void:
	panels[panel_id] = panel
	_panel_states[panel_id] = PanelState.HIDDEN



# 面板优先级（数字越小越优先）
var _panel_priority := {
	"dialogue": 0,
	"levelup": 1,
	"map": 2,
	"dungeon_result": 3,
}
var _active_panel: String = ""
var _panel_queue: Array[String] = []


# 返回当前活跃面板ID, 对外只读
func get_active_panel() -> String:
	return _active_panel


# 请求打开面板（自动排队 + 预占保留）
# 高优先级面板预占时, 将低优先级面板推入队列前端, 不丢失
func request_show(panel_id: String) -> void:
	print("PANEL: request_show(", panel_id, ") active=", _active_panel, " queue=", _panel_queue)
	if _active_panel == panel_id:
		# 同一面板再次请求: 如果当前不可见则重新显示
		var p: Control = panels.get(panel_id)
		if p and not p.visible:
			_panel_states[panel_id] = PanelState.HIDDEN
			_active_panel = ""
			_show_panel(panel_id)
		return

	# 有活跃面板时, 按优先级决策
	if _active_panel != "":
		var current_priority: int = _panel_priority.get(panel_id, 99)
		var active_priority: int = _panel_priority.get(_active_panel, 99)

		if current_priority >= active_priority:
			# 请求面板优先级更低或相等 → 排队
			if not _panel_queue.has(panel_id):
				_panel_queue.append(panel_id)
			return
		else:
			# 请求面板优先级更高 → 预占: 保留当前面板到队列前端
			var preempted: String = _active_panel
			_hide_panel(preempted)
			# 推入队列前端（去重）
			_panel_queue.erase(preempted)
			_panel_queue.push_front(preempted)

	# 显示请求面板
	_active_panel = panel_id
	_show_panel(panel_id)


# 面板关闭时调用 — 清理状态 + 弹出队列中下一个面板
func notify_closed(panel_id: String) -> void:
	print("PANEL: notify_closed(", panel_id, ") active=", _active_panel, " queue=", _panel_queue)
	# 只处理当前活跃面板的关闭
	if _active_panel != panel_id:
		return

	_active_panel = ""

	# 处理队列中下一个
	if not _panel_queue.is_empty():
		var next_id: String = _panel_queue.pop_front()
		_active_panel = next_id
		_show_panel(next_id)

	panel_closed.emit(panel_id)


# 强制关闭所有面板（用于死亡等场景）, 不清除已注册的面板引用
func force_close_all() -> void:
	for panel_id in panels.keys():
		UIEffects.kill_group(_group_for(panel_id))
		panels[panel_id].visible = false
		_panel_states[panel_id] = PanelState.HIDDEN
	_active_panel = ""
	_panel_queue.clear()

func _show_panel(panel_id: String) -> void:
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

	panel_shown.emit(panel_id)


func _hide_panel(panel_id: String) -> void:
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
			_show_panel(panel_id)
		PanelState.ACTIVE, PanelState.ENTERING:
			_hide_panel(panel_id)


func is_visible(panel_id: String) -> bool:
	return panels.has(panel_id) and panels[panel_id].visible


func get_state(panel_id: String) -> PanelState:
	return _panel_states.get(panel_id, PanelState.HIDDEN)


func hide(panel_id: String) -> void:
	_hide_panel(panel_id)


func hide_all() -> void:
	for panel_id in panels.keys():
		_hide_panel(panel_id)


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

# 强制重置面板状态（供外部在手动hide面板后调用）
func force_state(panel_id: String, state: int) -> void:
	_panel_states[panel_id] = state as PanelState
