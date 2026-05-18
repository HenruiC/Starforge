class_name DialoguePanel
extends Control

# 对话系统 — 陶德/小岛联合设计: 叙事+玩法融合

signal dialogue_finished

@onready var text_label: Label = $TextLabel
@onready var speaker_label: Label = $SpeakerLabel
@onready var hint_label: Label = $HintLabel

var _queue: Array[Dictionary] = []
var _current: int = 0
var _is_active: bool = false

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_dialogue(messages: Array[Dictionary]) -> void:
	_queue = messages
	_current = 0
	_is_active = true
	visible = true
	_display_current()

func _display_current() -> void:
	if _current >= _queue.size():
		_close()
		return
	var msg := _queue[_current]
	speaker_label.text = msg.get("speaker", "???")
	text_label.text = msg.get("text", "")

func _input(event: InputEvent) -> void:
	if not _is_active or not visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_current += 1
			_display_current()

func _close() -> void:
	_is_active = false
	visible = false
	dialogue_finished.emit()
