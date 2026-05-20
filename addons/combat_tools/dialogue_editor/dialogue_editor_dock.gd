@tool
extends Control

## 对话编辑器 v2 — 杨奇规范 · 对话书/组/条目/分支 四级结构

const COLOR_GOLD := Color(0.722, 0.525, 0.043)
const COLOR_TEXT := Color(0.941, 0.902, 0.827)
const COLOR_DIM := Color(0.333, 0.333, 0.333)

var _book: DialogueBook
var _current_group_idx: int = -1
var _current_entry_idx: int = -1
var _preview_running: bool = false

# UI — group level
var _group_list: ItemList
var _group_name_edit: LineEdit
var _group_id_edit: LineEdit
var _next_group_edit: LineEdit
# UI — entry level
var _entry_list: ItemList
var _speaker_edit: LineEdit
var _text_edit: TextEdit
var _speed_spin: SpinBox
var _duration_spin: SpinBox
var _color_picker: ColorPickerButton
var _next_entry_spin: SpinBox
# UI — choice level
var _choice_list: ItemList
var _choice_text_edit: LineEdit
var _choice_target_edit: LineEdit
# status
var _status_label: Label


# ==============================================================================
func _init() -> void:
	name = "对话编辑器"
	_book = DialogueBook.new()
	_book.book_id = "new_book"
	_book.book_name = "新对话书"
	_build_ui()


func _build_ui() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(580, 400)

	var root := VBoxContainer.new()
	root.set_anchors_preset(PRESET_FULL_RECT)
	add_child(root)

	# ==== 工具栏 ====
	var tb := HBoxContainer.new(); tb.add_theme_constant_override("separation", 4); root.add_child(tb)
	var btn_new := _btn("新建"); btn_new.pressed.connect(_on_new); tb.add_child(btn_new)
	var btn_open := _btn("打开"); btn_open.pressed.connect(_on_open); tb.add_child(btn_open)
	var btn_save := _btn("保存"); btn_save.pressed.connect(_on_save); tb.add_child(btn_save)
	var btn_as := _btn("另存为"); btn_as.pressed.connect(_on_save_as); tb.add_child(btn_as)
	var btn_grp := _btn("+组"); btn_grp.pressed.connect(_on_add_group); tb.add_child(btn_grp)
	_status_label = Label.new(); _status_label.add_theme_color_override("font_color", COLOR_DIM)
	tb.add_child(_status_label)

	# ==== 主内容区 ====
	var split := HSplitContainer.new()
	split.size_flags_horizontal = SIZE_EXPAND_FILL
	split.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(split)

	# ---- 左侧：组列表 ----
	var left := VBoxContainer.new(); split.add_child(left)
	left.add_child(_lbl("对话组")); left.add_child(_lbl(" "))
	_group_list = ItemList.new()
	_group_list.size_flags_vertical = SIZE_EXPAND_FILL
	_group_list.custom_minimum_size = Vector2(120, 0)
	_group_list.item_selected.connect(_on_group_selected)
	left.add_child(_group_list)
	var gbtns := HBoxContainer.new(); left.add_child(gbtns)
	gbtns.add_child(_btn("+")); gbtns.get_child(-1).pressed.connect(_on_add_group)
	gbtns.add_child(_btn("-")); gbtns.get_child(-1).pressed.connect(_on_del_group)

	# ---- 中间：条目 + 分支 ----
	var mid := VBoxContainer.new(); split.add_child(mid)

	# 组信息行
	var gi_row := HBoxContainer.new(); mid.add_child(gi_row)
	gi_row.add_child(_lbl("组名:")); _group_name_edit = LineEdit.new()
	_group_name_edit.placeholder_text = "如：开场"; _group_name_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	_group_name_edit.text_changed.connect(_on_group_field); gi_row.add_child(_group_name_edit)
	gi_row.add_child(_lbl(" ID:")); _group_id_edit = LineEdit.new()
	_group_id_edit.placeholder_text = "如：intro"; _group_id_edit.custom_minimum_size = Vector2(80, 0)
	_group_id_edit.text_changed.connect(_on_group_field); gi_row.add_child(_group_id_edit)
	gi_row.add_child(_lbl(" →下一组:")); _next_group_edit = LineEdit.new()
	_next_group_edit.placeholder_text = "无分支时自动跳转"; _next_group_edit.custom_minimum_size = Vector2(80, 0)
	_next_group_edit.text_changed.connect(_on_group_field); gi_row.add_child(_next_group_edit)

	# 条目区
	mid.add_child(_lbl("对话条目"))
	var ebtns := HBoxContainer.new(); mid.add_child(ebtns)
	var btn_ent := _btn("+条目"); btn_ent.pressed.connect(_on_add_entry); ebtns.add_child(btn_ent)
	ebtns.add_child(_btn("-")); ebtns.get_child(-1).pressed.connect(_on_del_entry)
	ebtns.add_child(_btn("▲")); ebtns.get_child(-1).pressed.connect(_on_entry_up)
	ebtns.add_child(_btn("▼")); ebtns.get_child(-1).pressed.connect(_on_entry_down)

	_entry_list = ItemList.new()
	_entry_list.size_flags_vertical = SIZE_EXPAND_FILL
	_entry_list.custom_minimum_size = Vector2(0, 80)
	_entry_list.item_selected.connect(_on_entry_selected)
	mid.add_child(_entry_list)

	# 条目编辑行
	var sp_row := HBoxContainer.new(); mid.add_child(sp_row)
	sp_row.add_child(_lbl("说话人:")); _speaker_edit = LineEdit.new()
	_speaker_edit.placeholder_text = "说话人"; _speaker_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	_speaker_edit.text_changed.connect(_on_entry_field); sp_row.add_child(_speaker_edit)
	sp_row.add_child(_lbl(" 下一条:")); _next_entry_spin = SpinBox.new()
	_next_entry_spin.min_value = -1; _next_entry_spin.max_value = 99; _next_entry_spin.value = -1
	_next_entry_spin.value_changed.connect(_on_entry_field); sp_row.add_child(_next_entry_spin)

	var sp_row2 := HBoxContainer.new(); mid.add_child(sp_row2)
	sp_row2.add_child(_lbl("速度:")); _speed_spin = SpinBox.new()
	_speed_spin.min_value = 0.005; _speed_spin.max_value = 0.5; _speed_spin.step = 0.005; _speed_spin.value = 0.02
	_speed_spin.value_changed.connect(_on_entry_field); sp_row2.add_child(_speed_spin)
	sp_row2.add_child(_lbl(" 时长:")); _duration_spin = SpinBox.new()
	_duration_spin.min_value = 0.0; _duration_spin.max_value = 30.0; _duration_spin.step = 0.5
	_duration_spin.value_changed.connect(_on_entry_field); sp_row2.add_child(_duration_spin)
	sp_row2.add_child(_lbl(" 颜色:")); _color_picker = ColorPickerButton.new()
	_color_picker.color = Color.WHITE; _color_picker.color_changed.connect(_on_entry_field); sp_row2.add_child(_color_picker)

	mid.add_child(_lbl("文本:")); _text_edit = TextEdit.new()
	_text_edit.placeholder_text = "对话内容..."; _text_edit.size_flags_vertical = SIZE_EXPAND_FILL
	_text_edit.text_changed.connect(_on_entry_field); mid.add_child(_text_edit)

	# ---- 右侧：分支选项 ----
	var right := VBoxContainer.new(); split.add_child(right)
	right.add_child(_lbl("分支选项(末条触发)")); right.add_child(_lbl(" "))
	var cbtns := HBoxContainer.new(); right.add_child(cbtns)
	var btn_ch := _btn("+选项"); btn_ch.pressed.connect(_on_add_choice); cbtns.add_child(btn_ch)
	cbtns.add_child(_btn("-")); cbtns.get_child(-1).pressed.connect(_on_del_choice)

	_choice_list = ItemList.new()
	_choice_list.size_flags_vertical = SIZE_EXPAND_FILL
	_choice_list.custom_minimum_size = Vector2(140, 0)
	_choice_list.item_selected.connect(_on_choice_selected)
	right.add_child(_choice_list)

	right.add_child(_lbl("选项文字:")); _choice_text_edit = LineEdit.new()
	_choice_text_edit.placeholder_text = "如：你是谁？"; _choice_text_edit.text_changed.connect(_on_choice_field)
	right.add_child(_choice_text_edit)
	right.add_child(_lbl("目标组ID:")); _choice_target_edit = LineEdit.new()
	_choice_target_edit.placeholder_text = "如：answer_identity"; _choice_target_edit.text_changed.connect(_on_choice_field)
	right.add_child(_choice_target_edit)

	# ==== 底部预览 ====
	var pv := HBoxContainer.new(); root.add_child(pv)
	var btn_pv := _btn("预览当前组"); btn_pv.pressed.connect(_on_preview); pv.add_child(btn_pv)
	var btn_sp := _btn("停止"); btn_sp.pressed.connect(_on_stop_preview); pv.add_child(btn_sp)

	_refresh_all()


# ==============================================================================
func _btn(text: String) -> Button:
	var b := Button.new(); b.text = text
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_font_size_override("font_size", 11)
	return b

func _lbl(text: String) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_color_override("font_color", COLOR_TEXT)
	l.add_theme_font_size_override("font_size", 11)
	return l


# ==============================================================================
# 数据刷新
# ==============================================================================

func _refresh_all() -> void:
	_group_list.clear()
	if _book == null:
		return
	for i: int in _book.groups.size():
		var g := _book.groups[i]
		var label := "%d. %s (%d条)" % [i + 1, g.group_name, g.entries.size()]
		if g.choices.size() > 0:
			label += " ◈"
		if g.group_id == _book.start_group_id:
			label += " ★"
		_group_list.add_item(label)

	_entry_list.clear()
	_choice_list.clear()

	if _current_group_idx >= 0 and _current_group_idx < _book.groups.size():
		var g := _book.groups[_current_group_idx]
		for j: int in g.entries.size():
			var e := g.entries[j]
			var txt := e.text.substr(0, 30) if e.text else "(空)"
			_entry_list.add_item("%d. [%s] %s" % [j + 1, e.speaker, txt])
		for c: DialogueChoice in g.choices:
			_choice_list.add_item("%s → %s" % [c.choice_text, c.target_group_id])

	# 更新组详情
	if _current_group_idx >= 0 and _current_group_idx < _book.groups.size():
		var g := _book.groups[_current_group_idx]
		_group_name_edit.text = g.group_name
		_group_id_edit.text = g.group_id
		_next_group_edit.text = g.next_group_id
	else:
		_group_name_edit.text = ""
		_group_id_edit.text = ""
		_next_group_edit.text = ""

	_update_status()


func _update_status() -> void:
	var n := _book.groups.size() if _book else 0
	var p := _book.resource_path if _book else ""
	var fn := "未保存" if p.is_empty() else p.get_file()
	_status_label.text = " %s · %d组" % [fn, n]


# ==============================================================================
# 按钮行为
# ==============================================================================

func _on_new() -> void:
	print("[对话编辑器] 新建对话书")
	_book = DialogueBook.new(); _book.book_id = "new_book"; _book.book_name = "新对话书"
	_current_group_idx = -1; _current_entry_idx = -1
	_refresh_all()


func _on_open() -> void:
	var fd := EditorFileDialog.new()
	fd.access = EditorFileDialog.ACCESS_RESOURCES
	fd.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	fd.add_filter("*.tres", "DialogueBook")
	fd.file_selected.connect(func(path: String):
		var r := load(path)
		if r is DialogueBook:
			_book = r; _current_group_idx = -1; _current_entry_idx = -1
			_refresh_all(); print("[对话编辑器] 已加载: %s" % path)
		fd.queue_free()
	)
	add_child(fd); fd.popup_centered_ratio(0.6)


func _on_save() -> void:
	if _book.resource_path.is_empty(): _on_save_as(); return
	ResourceSaver.save(_book, _book.resource_path)
	print("[对话编辑器] 已保存: %s" % _book.resource_path)


func _on_save_as() -> void:
	var fd := EditorFileDialog.new()
	fd.access = EditorFileDialog.ACCESS_RESOURCES
	fd.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	fd.add_filter("*.tres", "DialogueBook")
	fd.file_selected.connect(func(path: String):
		_book.resource_path = path; ResourceSaver.save(_book, path)
		print("[对话编辑器] 已保存: %s" % path); fd.queue_free()
	)
	add_child(fd); fd.popup_centered_ratio(0.6)

# ---- Group ops ----

func _on_add_group() -> void:
	sync_entry_to_data()
	var g := DialogueGroup.new()
	g.group_id = "group_%d" % _book.groups.size()
	g.group_name = "新对话组"
	_book.groups.append(g)
	if _book.start_group_id.is_empty():
		_book.start_group_id = g.group_id
	_current_group_idx = _book.groups.size() - 1; _current_entry_idx = -1
	_refresh_all()
	print("[对话编辑器] +组: %s" % g.group_id)


func _on_del_group() -> void:
	if _current_group_idx < 0 or _current_group_idx >= _book.groups.size(): return
	var gid := _book.groups[_current_group_idx].group_id
	_book.groups.remove_at(_current_group_idx)
	if _book.start_group_id == gid:
		_book.start_group_id = _book.groups[0].group_id if _book.groups.size() > 0 else ""
	_current_group_idx = min(_current_group_idx, _book.groups.size() - 1)
	_current_entry_idx = -1; _refresh_all()
	print("[对话编辑器] -组: %s" % gid)


func _on_group_selected(idx: int) -> void:
	sync_entry_to_data()
	_current_group_idx = idx; _current_entry_idx = -1
	_refresh_all()


func _on_group_field(_v = null) -> void:
	if _current_group_idx < 0 or _current_group_idx >= _book.groups.size(): return
	var g := _book.groups[_current_group_idx]
	g.group_name = _group_name_edit.text
	g.group_id = _group_id_edit.text
	g.next_group_id = _next_group_edit.text
	_refresh_all()

# ---- Entry ops ----

func _on_add_entry() -> void:
	if _current_group_idx < 0: return
	var e := DialogueEntry.new(); e.speaker = "说话人"; e.text = "输入文本..."
	_book.groups[_current_group_idx].entries.append(e)
	_current_entry_idx = _book.groups[_current_group_idx].entries.size() - 1
	_refresh_all()
	print("[对话编辑器] +条目 %d" % _current_entry_idx)


func _on_del_entry() -> void:
	var g := _current_group()
	if g == null or _current_entry_idx < 0 or _current_entry_idx >= g.entries.size(): return
	g.entries.remove_at(_current_entry_idx)
	_current_entry_idx = min(_current_entry_idx, g.entries.size() - 1)
	_refresh_all()


func _on_entry_up() -> void:
	var g := _current_group()
	if g == null or _current_entry_idx <= 0: return
	var t := g.entries[_current_entry_idx]; g.entries[_current_entry_idx] = g.entries[_current_entry_idx - 1]; g.entries[_current_entry_idx - 1] = t
	_current_entry_idx -= 1; _refresh_all()


func _on_entry_down() -> void:
	var g := _current_group()
	if g == null or _current_entry_idx < 0 or _current_entry_idx >= g.entries.size() - 1: return
	var t := g.entries[_current_entry_idx]; g.entries[_current_entry_idx] = g.entries[_current_entry_idx + 1]; g.entries[_current_entry_idx + 1] = t
	_current_entry_idx += 1; _refresh_all()


func _on_entry_selected(idx: int) -> void:
	sync_entry_to_data(); _current_entry_idx = idx
	if idx < 0 or idx >= _entry_list.item_count: return
	var g := _current_group()
	if g == null or idx >= g.entries.size(): return
	var e := g.entries[idx]
	_speaker_edit.text = e.speaker; _text_edit.text = e.text
	_speed_spin.value = e.text_speed; _duration_spin.value = e.duration
	_color_picker.color = e.text_color; _next_entry_spin.value = e.next_entry


func _on_entry_field(_v = null) -> void:
	var g := _current_group()
	if g == null or _current_entry_idx < 0 or _current_entry_idx >= g.entries.size(): return
	var e := g.entries[_current_entry_idx]
	e.speaker = _speaker_edit.text; e.text = _text_edit.text
	e.text_speed = _speed_spin.value; e.duration = _duration_spin.value
	e.text_color = _color_picker.color; e.next_entry = int(_next_entry_spin.value)
	_refresh_all()

func sync_entry_to_data() -> void:
	_on_entry_field()

# ---- Choice ops ----

func _on_add_choice() -> void:
	var g := _current_group()
	if g == null: return
	var c := DialogueChoice.new(); c.choice_text = "选项"; c.target_group_id = ""
	g.choices.append(c); _refresh_all()


func _on_del_choice() -> void:
	var g := _current_group()
	if g == null: return
	var sel := _choice_list.get_selected_items()
	if sel.is_empty(): return
	g.choices.remove_at(sel[0]); _refresh_all()


func _on_choice_selected(idx: int) -> void:
	var g := _current_group()
	if g == null or idx >= g.choices.size(): return
	var c := g.choices[idx]
	_choice_text_edit.text = c.choice_text
	_choice_target_edit.text = c.target_group_id


func _on_choice_field(_v = null) -> void:
	var g := _current_group()
	if g == null: return
	var sel := _choice_list.get_selected_items()
	if sel.is_empty(): return
	var c := g.choices[sel[0]]
	c.choice_text = _choice_text_edit.text
	c.target_group_id = _choice_target_edit.text
	_refresh_all()

func _current_group() -> DialogueGroup:
	if _book == null or _current_group_idx < 0 or _current_group_idx >= _book.groups.size():
		return null
	return _book.groups[_current_group_idx]


# ==============================================================================
# 预览
# ==============================================================================

func _on_preview() -> void:
	if _preview_running: return
	var g := _current_group()
	if g == null or g.entries.is_empty(): print("[预览] 无内容"); return
	_preview_running = true
	for i: int in g.entries.size():
		if not _preview_running: break
		var e := g.entries[i]
		_entry_list.select(i); _entry_list.ensure_current_is_visible()
		print("[预览 %d/%d] %s: %s" % [i + 1, g.entries.size(), e.speaker, e.text])
		var wt: float = e.duration if e.duration > 0 else 2.0
		var t := get_tree(); if t: await t.create_timer(wt).timeout
	if _preview_running and g.choices.size() > 0:
		print("[预览] 分支选项:")
		for c: DialogueChoice in g.choices:
			print("  → %s (%s)" % [c.choice_text, c.target_group_id])
	_preview_running = false

func _on_stop_preview() -> void:
	_preview_running = false; print("[预览] 已停止")
