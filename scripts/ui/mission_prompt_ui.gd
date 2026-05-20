class_name MissionPromptUI
extends Control

# =============================================================================
# MissionPromptUI — 任务提示表现层
# 设计文档：output/docs/任务触发系统设计-V1.0.md §3.3
#
# 职责：
#   1. Stage 激活提示（顶部居中大标题，滑入→停留→淡出）
#   2. 方向箭头（屏幕边缘指向目标位置的"▼"，浮动动画）
#   3. Objective 进度弹窗（右侧堆叠，进度弹跳，完成打勾→淡出）
#
# 集成方式：
#   - 通过 GameManager.add_child() 挂到 HUDLayer 下
#   - GameManager / MissionTriggerManager 调用 public API 驱动显示
#   - 所有动效通过 Tween 实现，遵循六人共识（战斗中 ≤0.3s）
# =============================================================================

# ===== 可配置参数（可通过 setter 在运行时调整） =====

## Stage 激活提示配置
var stage_color: Color = Color(0.85, 0.65, 0.1)        # 暗金色
var stage_font_size: int = 28
var stage_slide_duration: float = 0.3                    # 滑入时长
var stage_hold_duration: float = 2.0                     # 停留时长
var stage_fade_duration: float = 0.25                    # 淡出时长

## 方向箭头配置
var arrow_color: Color = Color(0.85, 0.65, 0.1)
var arrow_font_size: int = 24
var arrow_float_period: float = 1.5                      # 浮动周期（秒）
var arrow_float_amplitude: float = 6.0                   # 浮动幅度（像素）
var arrow_close_distance: float = 200.0                  # 接近目标时淡出的距离
var arrow_edge_margin: float = 45.0                      # 箭头距屏幕边缘的间距

## Objective 进度弹窗配置
var objective_font_size: int = 16
var objective_check_color: Color = Color(0.85, 0.65, 0.1)  # 待完成复选框颜色
var objective_done_color: Color = Color(0.3, 0.85, 0.3)    # 完成文字颜色
var objective_flash_color: Color = Color(1.0, 0.9, 0.2)    # 完成时 flash 颜色
var objective_pop_duration: float = 0.2                    # 弹入动画时长
var objective_fade_duration: float = 0.3                   # 淡出动画时长
var objective_spacing: int = 6                             # 条目间距

# ===== 内部节点引用 =====

var _stage_label: Label
var _arrow_label: Label
var _objective_container: VBoxContainer

# ===== 运行时状态 =====

var _arrow_target: Vector2 = Vector2.ZERO         # 箭头指向的世界坐标
var _arrow_is_active: bool = false                # 箭头是否激活
var _arrow_float_time: float = 0.0                # 浮动动画累计时间
var _arrow_base_pos: Vector2 = Vector2.ZERO       # 箭头基准屏幕位置（不含浮动偏移）
var _arrow_is_nearby: bool = false                # 玩家是否接近目标

var _player_ref: Node2D = null                    # 玩家节点引用（用于箭头追踪）
var _stage_tween: Tween = null                    # stage 标签的动画实例
var _objectives: Dictionary = {}                  # obj_id -> ObjectiveEntry
var _scheduled_removals: Array[String] = []       # 待移除的 objective id

# =============================================================================
# Public API
# =============================================================================

## 设置玩家节点引用，用于箭头实时追踪玩家位置
func set_player(player: Node2D) -> void:
	_player_ref = player


## 显示 Stage 激活提示
## [param text] 显示文字，如 "第一阶段：踏入校园"
## [param duration] 停留秒数，默认 2.0；传 0 表示持续到手动调用 dismiss_stage_activate()
func show_stage_activate(text: String, duration: float = -1.0) -> void:
	if duration < 0.0:
		duration = stage_hold_duration

	# 杀死之前的 stage 动画
	_kill_stage_tween()

	_stage_label.text = text
	_stage_label.modulate = Color(1, 1, 1, 0)
	_stage_label.visible = true

	var t: Tween = create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.set_trans(Tween.TRANS_CUBIC)
	t.set_ease(Tween.EASE_OUT)

	# 滑入：从上方 -20px 到目标位置，透明度 0→1
	_stage_label.position = Vector2(_stage_label.position.x, stage_slide_offset_y())
	t.parallel().tween_property(_stage_label, "modulate:a", 1.0, stage_slide_duration)
	t.parallel().tween_property(_stage_label, "position:y", stage_target_y(), stage_slide_duration)

	if duration > 0.0:
		# 停留 → 淡出
		t.tween_interval(duration)
		t.tween_property(_stage_label, "modulate:a", 0.0, stage_fade_duration)
		t.tween_callback(func():
			_stage_label.visible = false
		)

	_stage_tween = t


## 手动关闭 Stage 激活提示（当 display_duration=0 时使用）
func dismiss_stage_activate() -> void:
	_kill_stage_tween()
	var t: Tween = create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.tween_property(_stage_label, "modulate:a", 0.0, stage_fade_duration)
	t.tween_callback(func():
		_stage_label.visible = false
	)


## 显示/更新方向箭头，指向目标世界坐标
func show_direction_arrow(target_world_pos: Vector2) -> void:
	_arrow_target = target_world_pos
	_arrow_is_active = true
	_arrow_float_time = 0.0
	_arrow_is_nearby = false
	_arrow_label.visible = true
	_arrow_label.modulate = Color(1, 1, 1, 1)
	# 立即计算一次位置
	_update_arrow_position()


## 强制更新一次箭头位置（GameManager 的 _process 每帧调用）
## 如果已通过 set_player() 设置了玩家引用，UI 会在自身 _process 中自动更新
func update_arrow(player_pos: Vector2) -> void:
	if _arrow_is_active:
		_arrow_target = player_pos  # GameManager 传递玩家位置来更新箭头状态
		# 注释：此方法目前用于外部驱动箭头位置更新，
		# 箭头真正使用的是 _arrow_target（目标位置）+ _player_ref（玩家位置）

## 显示/更新 Objective 进度
## 首次调用会在右侧创建新条目，后续更新会复用已有条目
func show_objective_progress(objective_id: String, description: String, current: float, target: float) -> void:
	if _objectives.has(objective_id):
		var entry: ObjectiveEntry = _objectives[objective_id]
		entry.update_progress(description, current, target)
	else:
		var entry: ObjectiveEntry = ObjectiveEntry.create(self, _objective_container, objective_id, description, current, target, objective_font_size, objective_check_color)
		_objectives[objective_id] = entry


## 标记 Objective 为已完成
## 触发打勾动画 + 金色 flash → 0.3s 淡出后自动移除
func complete_objective(objective_id: String, description: String = "") -> void:
	if not _objectives.has(objective_id):
		return
	var entry: ObjectiveEntry = _objectives[objective_id]
	entry.complete(objective_done_color, objective_flash_color, objective_fade_duration)


## 立即移除指定 Objective 条目
func remove_objective(objective_id: String) -> void:
	if not _objectives.has(objective_id):
		return
	var entry: ObjectiveEntry = _objectives[objective_id]
	_objectives.erase(objective_id)
	if is_instance_valid(entry.node):
		entry.node.queue_free()


## 清除所有 Objective 条目
func clear_objectives() -> void:
	for obj_id in _objectives.keys():
		var entry: ObjectiveEntry = _objectives[obj_id]
		if is_instance_valid(entry.node):
			entry.node.queue_free()
	_objectives.clear()


## 清除所有 UI（stage 提示 + 箭头 + objectives）
func clear_all() -> void:
	dismiss_stage_activate()
	hide_direction_arrow()
	clear_objectives()


# =============================================================================
# Internal: Lifecycle
# =============================================================================

func _ready() -> void:
	name = "MissionPromptUI"
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不拦截鼠标事件
	_build_ui()
	# 初始隐藏
	_stage_label.visible = false
	_arrow_label.visible = false


func _process(delta: float) -> void:
	# 箭头自动追踪：如果有玩家引用且箭头激活
	if _arrow_is_active and _player_ref and _arrow_target.length() > 0:
		var d := _player_ref.global_position.distance_to(_arrow_target)
		if d < 120: hide_direction_arrow(); return
		_update_arrow_position(delta)


# =============================================================================
# Internal: UI 构建
# =============================================================================

func _build_ui() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	# ---- Stage 激活标签 ----
	_stage_label = Label.new()
	_stage_label.name = "StageActivateLabel"
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stage_label.add_theme_color_override("font_color", stage_color)
	_stage_label.add_theme_font_size_override("font_size", stage_font_size)
	_stage_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	_stage_label.add_theme_constant_override("outline_size", 2)
	_stage_label.visible = false
	_stage_label.modulate = Color(1, 1, 1, 0)
	_stage_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_stage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 定位到屏幕顶部居中
	_stage_label.custom_minimum_size = Vector2(viewport_size.x, 0)
	_stage_label.size = Vector2(viewport_size.x, 0)
	_stage_label.position = Vector2(0, stage_target_y())
	add_child(_stage_label)

	# ---- 方向箭头 ----
	_arrow_label = Label.new()
	_arrow_label.name = "DirectionArrow"
	_arrow_label.text = "▼"
	_arrow_label.add_theme_color_override("font_color", arrow_color)
	_arrow_label.add_theme_font_size_override("font_size", arrow_font_size)
	_arrow_label.visible = false
	_arrow_label.modulate = Color(1, 1, 1, 0)
	_arrow_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 设置 Label 的 pivot 为中心，方便旋转
	_arrow_label.size = Vector2(30, 30)
	_arrow_label.pivot_offset = Vector2(15, 15)
	add_child(_arrow_label)

	# ---- Objective 容器（屏幕右侧） ----
	_objective_container = VBoxContainer.new()
	_objective_container.name = "ObjectiveContainer"
	_objective_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_container.add_theme_constant_override("separation", objective_spacing)
	_objective_container.size_flags_horizontal = Control.SIZE_SHRINK_END
	# 定位到屏幕右侧，距右边 20px，从 y=200 开始
	_objective_container.position = Vector2(viewport_size.x - 260, 200)
	_objective_container.custom_minimum_size = Vector2(240, 0)
	add_child(_objective_container)


func stage_target_y() -> float:
	return 80.0


func stage_slide_offset_y() -> float:
	return 80.0 - 20.0  # 从上方 20px 处滑入


# =============================================================================
# Internal: 箭头位置与动画
# =============================================================================

func _update_arrow_position(delta: float = 0.0) -> void:
	if not _arrow_is_active or not _player_ref:
		return

	# 1. 计算玩家到目标的距离
	var player_pos: Vector2 = _player_ref.global_position
	var dir_world: Vector2 = _arrow_target - player_pos
	var dist: float = dir_world.length()

	# 2. 判断是否接近目标 → 淡出箭头
	var was_nearby: bool = _arrow_is_nearby
	_arrow_is_nearby = dist < arrow_close_distance

	if _arrow_is_nearby and not was_nearby:
		_kill_arrow_tween()
		var t: Tween = create_tween()
		t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		t.tween_property(_arrow_label, "modulate:a", 0.0, 0.3)
	elif not _arrow_is_nearby and was_nearby:
		_kill_arrow_tween()
		var t: Tween = create_tween()
		t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		t.tween_property(_arrow_label, "modulate:a", 1.0, 0.3)

	if _arrow_is_nearby:
		return

	# 3. 获取相机信息，转换到屏幕坐标
	var camera: Camera2D = get_viewport().get_camera_2d()
	if not camera:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var screen_center: Vector2 = viewport_size * 0.5

	# 世界坐标 → 屏幕坐标（相对于 CanvasLayer）
	var target_screen: Vector2 = (_arrow_target - camera.global_position) * camera.zoom + screen_center

	# 4. 计算箭头基准位置
	_arrow_base_pos = _compute_arrow_edge_position(target_screen, viewport_size)

	# 5. 计算箭头旋转角度，使"▼"指向目标
	var arrow_dir: Vector2
	if _arrow_base_pos == target_screen:
		# 目标在屏幕内 → 从箭头位置指向目标
		arrow_dir = (target_screen - _arrow_base_pos).normalized()
	else:
		# 目标在屏幕外 → 从屏幕中心指向目标
		arrow_dir = (target_screen - screen_center).normalized()

	# 安全处理零向量
	if arrow_dir.length_squared() < 0.001:
		arrow_dir = Vector2(0, -1)  # fallback: 向上

	# "▼" 默认指向下方（Vector2(0,1) 方向，即角度 PI/2）
	_arrow_label.rotation = atan2(arrow_dir.y, arrow_dir.x) - PI / 2

	# 6. 浮动偏移（每帧叠加）
	_arrow_float_time += delta
	var float_offset: float = sin(_arrow_float_time * TAU / arrow_float_period) * arrow_float_amplitude
	_arrow_label.position = _arrow_base_pos + Vector2(0, float_offset)


func _compute_arrow_edge_position(target_screen: Vector2, viewport_size: Vector2) -> Vector2:
	# 如果目标在屏幕内（带边距），直接放在目标上方
	var margin: float = arrow_edge_margin
	if target_screen.x >= margin and target_screen.x <= viewport_size.x - margin \
		and target_screen.y >= margin and target_screen.y <= viewport_size.y - margin:
		return Vector2(target_screen.x, target_screen.y - 40)

	# 目标在屏幕外 → 计算从屏幕中心到目标的射线与屏幕边缘的交点
	var center: Vector2 = viewport_size * 0.5
	var dir: Vector2 = (target_screen - center).normalized()

	# 用参数 t 表示射线： center + t * dir, t > 0
	# 与四条边的交点中，取最小的正 t 值
	var t_min: float = INF
	var candidates: Array[float] = []

	# 右边缘
	if dir.x > 0.0:
		candidates.append((viewport_size.x - margin - center.x) / dir.x)
	# 左边缘
	if dir.x < 0.0:
		candidates.append((margin - center.x) / dir.x)
	# 下边缘
	if dir.y > 0.0:
		candidates.append((viewport_size.y - margin - center.y) / dir.y)
	# 上边缘
	if dir.y < 0.0:
		candidates.append((margin - center.y) / dir.y)

	for t in candidates:
		if t > 0.0 and t < t_min:
			t_min = t

	return center + dir * t_min


# =============================================================================
# Internal: Tween 管理
# =============================================================================

func _kill_stage_tween() -> void:
	if _stage_tween and is_instance_valid(_stage_tween):
		_stage_tween.kill()
	_stage_tween = null

## 所有以"arrow_"开头的 tween 组
var _arrow_tween: Tween = null

func _kill_arrow_tween() -> void:
	if _arrow_tween and is_instance_valid(_arrow_tween):
		_arrow_tween.kill()
	_arrow_tween = null


# =============================================================================
# ObjectiveEntry — 内部数据类，管理单条 Objective 的显示
# =============================================================================

## Objective 条目，管理单个目标的显示/更新/完成动画
class ObjectiveEntry:
	var node: HBoxContainer         # 根节点
	var check_label: Label          # "□" / "✓"
	var desc_label: Label           # 描述文字
	var progress_label: Label       # "(3/15)"
	var objective_id: String        # 唯一标识
	var current_value: float = 0.0
	var target_value: float = 1.0
	var is_completed: bool = false
	var _parent_ui: Control = null  # 持有 MissionPromptUI 引用，用于动画回调

	## 工厂方法：创建 Objective 条目并加入容器
	static func create(
		parent_ui: Control,
		container: VBoxContainer,
		obj_id: String,
		description: String,
		current: float,
		target: float,
		font_size: int,
		check_color: Color
	) -> ObjectiveEntry:
		var entry := ObjectiveEntry.new()
		entry._parent_ui = parent_ui
		entry.objective_id = obj_id
		entry.current_value = current
		entry.target_value = target

		# 根节点：HBoxContainer
		entry.node = HBoxContainer.new()
		entry.node.name = "Obj_" + obj_id
		entry.node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.node.add_theme_constant_override("separation", 6)
		entry.node.size_flags_horizontal = Control.SIZE_SHRINK_END

		# 勾选框标签
		entry.check_label = Label.new()
		entry.check_label.text = "□"
		entry.check_label.add_theme_color_override("font_color", check_color)
		entry.check_label.add_theme_font_size_override("font_size", font_size)
		entry.check_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.node.add_child(entry.check_label)

		# 描述标签（含进度信息）
		entry.desc_label = Label.new()
		entry.desc_label.text = description
		entry.desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		entry.desc_label.add_theme_font_size_override("font_size", font_size)
		entry.desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.node.add_child(entry.desc_label)

		# 进度数字标签
		var progress_text: String = entry._format_progress(current, target)
		entry.progress_label = Label.new()
		entry.progress_label.text = progress_text
		entry.progress_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		entry.progress_label.add_theme_font_size_override("font_size", font_size)
		entry.progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.node.add_child(entry.progress_label)

		# 弹入动画：scale 0.8 → 1.15 → 1.0
		entry.node.scale = Vector2(0.8, 0.8)
		entry.node.modulate = Color(1, 1, 1, 0)
		container.add_child(entry.node)

		var t: Tween = parent_ui.create_tween()
		t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		t.set_ease(Tween.EASE_OUT)
		t.set_trans(Tween.TRANS_BACK)
		t.parallel().tween_property(entry.node, "scale", Vector2(1.15, 1.15), 0.1)
		t.parallel().tween_property(entry.node, "modulate", Color.WHITE, 0.1)
		t.tween_property(entry.node, "scale", Vector2.ONE, 0.1)

		return entry


	## 更新进度（进度变化时数字弹跳）
	func update_progress(description: String, current: float, target: float) -> void:
		if is_completed:
			return

		var prev_current: float = current_value
		current_value = current
		target_value = target
		desc_label.text = description

		var new_text: String = _format_progress(current, target)
		if progress_label.text != new_text:
			progress_label.text = new_text
			# 数字弹跳动画
			if _parent_ui and is_instance_valid(_parent_ui):
				var t: Tween = _parent_ui.create_tween()
				t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
				t.set_ease(Tween.EASE_OUT)
				t.set_trans(Tween.TRANS_BACK)
				t.tween_property(progress_label, "scale", Vector2(1.3, 1.3), 0.08)
				t.tween_property(progress_label, "scale", Vector2.ONE, 0.1)

			# 非计数型（到达/完成型）到目标值时触发颜色变化
			if current >= target and not is_completed:
				# 由外部调用 complete() 处理
				pass


	## 标记完成：□→✓ + 金色 flash + 淡出
	func complete(done_color: Color, flash_color: Color, fade_duration: float) -> void:
		if is_completed:
			return
		is_completed = true

		# □ → ✓ 文字变化
		check_label.text = "✓"
		check_label.add_theme_color_override("font_color", done_color)
		desc_label.add_theme_color_override("font_color", done_color)

		if _parent_ui and is_instance_valid(_parent_ui):
			var t: Tween = _parent_ui.create_tween()
			t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)

			# 打勾动画：scale 0 → 1.2 → 1.0
			t.tween_property(check_label, "scale", Vector2(1.2, 1.2), 0.15).set_ease(Tween.EASE_OUT)
			t.tween_property(check_label, "scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_OUT)

			# 金色 flash 整行 → 恢复最终颜色
			t.tween_property(desc_label, "modulate", flash_color, 0.1)
			t.tween_property(desc_label, "modulate", Color.WHITE, 0.15)
			t.tween_property(progress_label, "modulate", flash_color, 0.05)
			t.tween_property(progress_label, "modulate", Color(done_color.r, done_color.g, done_color.b, 0.6), 0.15)

			# 延迟后淡出移除
			t.tween_interval(0.5)
			t.tween_property(node, "modulate:a", 0.0, fade_duration)
			t.tween_property(node, "scale", Vector2(0.8, 0.8), fade_duration)
			t.tween_callback(func():
				if is_instance_valid(node):
					node.queue_free()
			)


	## 移除条目（直接销毁，无动画）
	func remove_immediate() -> void:
		if is_instance_valid(node):
			node.queue_free()


	func _format_progress(current: float, target: float) -> String:
		if target <= 1.0:
			return ""  # 到达型不显示数字
		return "(%d/%d)" % [int(current), int(target)]


# =============================================================================
# _arrow_tween 兼容性引用（保持类型一致）
# =============================================================================

func hide_direction_arrow() -> void:
	_arrow_is_active = false
	_arrow_label.visible = false
