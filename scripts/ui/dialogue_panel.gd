class_name DialoguePanel
extends Control

# 对话系统 — 陶德/小岛联合设计: 叙事+玩法融合
# Phase 3: 面板滑入/滑出动画 + 翻页淡出过渡 + 说话人颜色区分

signal dialogue_finished

# --- 说话人颜色表 ---
const SPEAKER_COLORS := {
	"主角": Color(0.85, 0.65, 0.1),		# 暗金
	"系统": Color(0.4, 0.7, 0.9),			# 冷蓝
	"???": Color(0.7, 0.3, 0.3),			# 暗红
}
const SPEAKER_FALLBACK_COLOR := Color(0.7, 0.7, 0.7)  # 灰色

# --- 动画参数 ---
const PANEL_SLIDE_DURATION := 0.25
const PANEL_SLIDE_OFFSET := 40.0
const FADE_TRANSITION_DURATION := 0.1

@onready var text_label: Label = $TextLabel
@onready var speaker_label: Label = $SpeakerLabel
@onready var hint_label: Label = $HintLabel

var _queue: Array[Dictionary] = []
var _current: int = 0
var _is_active: bool = false
var _is_typing: bool = false
var _is_transitioning: bool = false
var _typewriter_tween: Tween = null
var _fade_tween: Tween = null
var _panel_base_y: float = 0.0
var _current_speed: float = 0.02


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel_base_y = position.y
	if not EventBus.dialogue_triggered.is_connected(_on_dialogue_triggered):
		EventBus.dialogue_triggered.connect(_on_dialogue_triggered)


# =====================================================================
# 公开接口
# =====================================================================

func show_dialogue(messages: Array[Dictionary]) -> void:
	# 终止上一次残留的动画
	if is_instance_valid(_typewriter_tween):
		_typewriter_tween.kill()
		_typewriter_tween = null
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
		_fade_tween = null

	_queue = messages
	_current = 0
	_is_active = true
	_is_typing = false
	_is_transitioning = false
	_open()
	_display_current()


## 显示 DialogueBook 中指定组的对话
func show_dialogue_book(book: DialogueBook, group_id: String = "") -> void:
	if book == null:
		return
	var gid: String = group_id if not group_id.is_empty() else book.start_group_id
	var group := book.find_group(gid)
	if group == null or group.entries.is_empty():
		return
	var messages: Array[Dictionary] = []
	for entry: DialogueEntry in group.entries:
		messages.append({
			"speaker": entry.speaker,
			"text": entry.text,
			"text_speed": entry.text_speed,
			"duration": entry.duration,
			"text_color": entry.text_color,
		})
	# TODO: 分支选项 UI
	show_dialogue(messages)


func _on_dialogue_triggered(book: DialogueBook, group_id: String) -> void:
	show_dialogue_book(book, group_id)


# =====================================================================
# 面板动画 — 滑入 / 滑出
# =====================================================================

func _open() -> void:
	"""底部面板从下方滑入 (0.25s EASE_IN_OUT)"""
	visible = true
	modulate.a = 0.0
	position.y = _panel_base_y + PANEL_SLIDE_OFFSET

	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 1.0, PANEL_SLIDE_DURATION).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "position:y", _panel_base_y, PANEL_SLIDE_DURATION).set_ease(Tween.EASE_IN_OUT)


func _close() -> void:
	"""面板向下滑出 (0.25s EASE_IN)，动画完成后隐藏"""
	_is_active = false
	_is_typing = false
	_is_transitioning = false

	# 终止所有进行中的动画
	if is_instance_valid(_typewriter_tween):
		_typewriter_tween.kill()
		_typewriter_tween = null
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
		_fade_tween = null

	hint_label.text = ""

	# 滑出动画
	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, PANEL_SLIDE_DURATION).set_ease(Tween.EASE_IN)
	t.tween_property(self, "position:y", _panel_base_y + PANEL_SLIDE_OFFSET, PANEL_SLIDE_DURATION).set_ease(Tween.EASE_IN)
	t.finished.connect(func():
		if is_instance_valid(self):
			visible = false
			dialogue_finished.emit()
	, CONNECT_ONE_SHOT)


# =====================================================================
# 页面展示 — 翻页过渡
# =====================================================================

func _display_current() -> void:
	if _current >= _queue.size():
		_close()
		return

	var msg := _queue[_current]
	_current_speed = msg.get("text_speed", 0.02)
	if _current > 0:
		# 翻页：旧说话人 + 文字淡出 (0.1s) → 新内容打字机
		_fade_transition(msg)
	else:
		# 第一页：直接展示（和面板滑入同时进行）
		_apply_content(msg)
		_start_typewriter()


func _fade_transition(msg: Dictionary) -> void:
	"""旧内容淡出 0.1s，然后展示新内容并启动打字机"""
	_is_transitioning = true
	hint_label.text = ""

	_fade_tween = create_tween()
	_fade_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	_fade_tween.tween_property(text_label, "modulate:a", 0.0, FADE_TRANSITION_DURATION)
	_fade_tween.parallel().tween_property(speaker_label, "modulate:a", 0.0, FADE_TRANSITION_DURATION)
	_fade_tween.tween_callback(func():
		_is_transitioning = false
		_fade_tween = null
		_apply_content(msg)
		_start_typewriter()
	)


# =====================================================================
# 内容填充 & 说话人颜色
# =====================================================================

func _apply_content(msg: Dictionary) -> void:
	var speaker: String = msg.get("speaker", "???")
	if msg.has("text_color"):
		speaker_label.add_theme_color_override("font_color", msg["text_color"])
	else:
		_apply_speaker_color(speaker)
	speaker_label.text = speaker
	text_label.text = msg.get("text", "")
	# 重置透明度（面板 modulate 控制整体淡入淡出）
	speaker_label.modulate.a = 1.0
	text_label.modulate.a = 1.0


func _apply_speaker_color(speaker: String) -> void:
	var color: Color = SPEAKER_COLORS.get(speaker, SPEAKER_FALLBACK_COLOR)
	speaker_label.add_theme_color_override("font_color", color)


# =====================================================================
# 打字机效果
# =====================================================================

func _start_typewriter() -> void:
	# 终止上一个打字机动画
	if is_instance_valid(_typewriter_tween):
		_typewriter_tween.kill()
		_typewriter_tween = null

	# 初始状态：文字不可见
	text_label.visible_characters = 0
	_is_typing = true
	hint_label.text = ""

	# 空文本跳过动画
	if text_label.text.length() == 0:
		_is_typing = false
		hint_label.text = "[空格] 继续"
		return

	# 从 0 → 全文长度，逐字显示
	var dur := text_label.text.length() * _current_speed
	var t: Tween = create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.tween_property(text_label, "visible_characters", text_label.text.length(), dur)
	t.finished.connect(_on_typewriter_finished, CONNECT_ONE_SHOT)
	_typewriter_tween = t


func _on_typewriter_finished() -> void:
	_is_typing = false
	_typewriter_tween = null
	hint_label.text = "[空格] 继续"


# =====================================================================
# 输入处理 — 键盘(空格/回车) + 鼠标左键
# =====================================================================

func _advance() -> void:
	"""统一推进逻辑：打字中则跳过，否则下一页"""
	if _is_transitioning:
		return

	if _is_typing:
		# 跳过：立刻显示全文
		if is_instance_valid(_typewriter_tween):
			_typewriter_tween.kill()
			_typewriter_tween = null
		text_label.visible_characters = text_label.text.length()
		_is_typing = false
		hint_label.text = "[空格] 继续"
	else:
		_current += 1
		_display_current()


func _input(event: InputEvent) -> void:
	if not _is_active or not visible:
		return

	# 键盘：空格 / 回车
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_advance()
			get_viewport().set_input_as_handled()

	# 鼠标：左键点击
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_advance()
		get_viewport().set_input_as_handled()
