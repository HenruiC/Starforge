class_name GameStateManager
extends Node

# 统一游戏状态管理 — 马斯克架构
# Playing / Paused / MapOpen / Inventory / Settings / Dialogue / Dead

enum State { PLAYING, PAUSED, MAP, INVENTORY, SETTINGS, DIALOGUE, DEAD, CHAR_SELECT }

var current_state: State = State.CHAR_SELECT
var previous_state: State = State.CHAR_SELECT

signal state_changed(new_state: State, old_state: State)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func set_state(new_state: State) -> void:
	if new_state == current_state: return
	previous_state = current_state
	current_state = new_state
	state_changed.emit(new_state, previous_state)

	# 自动暂停/恢复
	match new_state:
		State.MAP, State.INVENTORY, State.SETTINGS, State.DIALOGUE:
			get_tree().paused = true
		State.PLAYING:
			get_tree().paused = false
		State.DEAD, State.CHAR_SELECT:
			pass  # 各自管理暂停

func is_playing() -> bool:
	return current_state == State.PLAYING

func is_paused_for_ui() -> bool:
	return current_state in [State.MAP, State.INVENTORY, State.SETTINGS]

func toggle_map() -> void:
	if current_state == State.MAP:
		set_state(State.PLAYING)
	else:
		set_state(State.MAP)

func go_playing() -> void:
	set_state(State.PLAYING)
