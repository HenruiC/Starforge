class_name UIScarController
extends Node

## UI 伤疤系统 — Phase 4
##
## 根据玩家累计死亡次数在 HUD 上产生伤痕视觉效果。
## 伤疤等级越高，HUD 闪烁越频繁，错位越明显。
## Boss 被击败后伤疤等级降低（半治愈效果）。
##
## 用法：
##   var scar := UIScarController.new()
##   hud_layer.add_child(scar)
##   scar.start()
##   scar.register_hud_element(kill_label)
##
## 伤疤等级：
##   Lv.0  (0-2 次死亡)  — 无伤疤，HUD 正常
##   Lv.1  (3-5 次死亡)  — 轻微裂痕，偶尔闪烁
##   Lv.2  (6-10 次死亡) — 明显裂痕，闪烁+微错位
##   Lv.3  (11+ 次死亡)  — 严重裂痕，频繁闪烁+明显错位

signal scar_level_changed(level: int)

# 伤疤等级对应表
const SCAR_LEVEL_0: int = 0
const SCAR_LEVEL_1: int = 1
const SCAR_LEVEL_2: int = 2
const SCAR_LEVEL_3: int = 3

var _scar_level: int = 0
var _flicker_timer: float = 0.0
var _flicker_interval: float = -1.0
var _hud_elements: Array[Control] = []
var _is_active: bool = false
var _flicker_group: String = "hud_scar_flicker"


func _ready() -> void:
	name = "UIScarController"
	process_mode = Node.PROCESS_MODE_ALWAYS


## 启动伤疤系统（一般在 GameManager._ready 中调用）
func start() -> void:
	_scar_level = GamePersistence.get_scar_level()
	_flicker_interval = GamePersistence.get_scar_flicker_interval()
	_is_active = true
	scar_level_changed.emit(_scar_level)


## 注册需要闪烁效果的 HUD 元素
func register_hud_element(ctrl: Control) -> void:
	if ctrl and ctrl not in _hud_elements:
		_hud_elements.append(ctrl)


## 获取当前伤疤等级
func get_scar_level() -> int:
	return _scar_level


## 击败 Boss 后降低伤疤等级（半治愈）
func reduce_scar() -> void:
	GamePersistence.reduce_total_deaths()
	_scar_level = GamePersistence.get_scar_level()
	_flicker_interval = GamePersistence.get_scar_flicker_interval()
	scar_level_changed.emit(_scar_level)


## 重置累加死亡数（用于新游戏重新校准）
func reset_scar() -> void:
	# 不重置持久化数据，只重新读取
	start()


func _process(delta: float) -> void:
	if not _is_active:
		return
	if _flicker_interval <= 0.0:
		return

	_flicker_timer += delta
	if _flicker_timer >= _flicker_interval:
		_flicker_timer = 0.0
		_trigger_flicker()


## 触发一次 HUD 闪烁/错位
func _trigger_flicker() -> void:
	UIEffects.kill_group(_flicker_group)

	for ctrl in _hud_elements:
		if not is_instance_valid(ctrl):
			continue

		# 闪烁强度与错位幅度随等级递增
		var alpha_dip: float = 0.05 + _scar_level * 0.03
		var jitter_px: float = 1.0 + _scar_level * 0.5
		var orig_pos: Vector2 = ctrl.position

		var t: Tween = ctrl.create_tween()
		t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		t.set_parallel(true)

		# 微妙的 alpha 闪烁
		t.tween_property(ctrl, "modulate:a", 1.0 - alpha_dip, 0.03)

		# Lv.2+ 加位置错位
		if _scar_level >= SCAR_LEVEL_2:
			var jitter_x: float = randf_range(-jitter_px, jitter_px)
			var jitter_y: float = randf_range(-jitter_px, jitter_px)
			t.tween_property(ctrl, "position:x", orig_pos.x + jitter_x, 0.03)
			t.tween_property(ctrl, "position:y", orig_pos.y + jitter_y, 0.03)

		# 恢复
		t.tween_interval(0.04)
		t.set_parallel(true)
		t.tween_property(ctrl, "modulate:a", 1.0, 0.03)
		if _scar_level >= SCAR_LEVEL_2:
			t.tween_property(ctrl, "position", orig_pos, 0.03)

		UIEffects._register_tween(_flicker_group, t)


# =============================================================================
# 静态方法：在 CharSelect 面板上创建裂痕覆盖层
# =============================================================================

## 在指定面板上创建/更新裂痕纹理
## [param panel] CharSelect 面板节点
## [param scar_level] 当前伤疤等级
static func update_char_select_scars(panel: Control, scar_level: int) -> void:
	# 移除旧的裂痕容器
	var old_container: Node = panel.get_node_or_null("ScarCracks")
	if old_container:
		old_container.queue_free()

	if scar_level <= SCAR_LEVEL_0:
		return

	var container := Control.new()
	container.name = "ScarCracks"
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.anchors_preset = Control.PRESET_FULL_RECT

	var panel_size: Vector2 = panel.size
	if panel_size.x <= 0 or panel_size.y <= 0:
		# 面板尚未布局完成，使用父级尺寸
		var parent := panel.get_parent_control()
		if parent:
			panel_size = parent.size
		if panel_size.x <= 0 or panel_size.y <= 0:
			panel_size = Vector2(800, 600)

	var crack_count: int = scar_level * 2  # Lv.1=2条, Lv.2=4条, Lv.3=6条
	var base_alpha: float = 0.3 + scar_level * 0.1
	var base_width: float = 1.0 + scar_level * 0.5

	for i in range(crack_count):
		var crack := ColorRect.new()
		crack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crack.color = Color(0.15, 0.03, 0.03, base_alpha + randf_range(-0.05, 0.05))

		# 随机位置（避开中心区域因为按钮集中在那里）
		var center_x: float = panel_size.x * 0.5
		var center_y: float = panel_size.y * 0.5
		var x: float = center_x + randf_range(-panel_size.x * 0.35, panel_size.x * 0.35)
		var y: float = center_y + randf_range(-panel_size.y * 0.3, panel_size.y * 0.3)

		# 裂痕长度与宽度
		var length: float = 30.0 + scar_level * 15.0 + randf_range(0, 25.0)
		var width: float = base_width + randf_range(-0.3, 0.3)
		var angle: float = deg_to_rad(randf_range(-75, 75))

		crack.size = Vector2(length, width)
		crack.pivot_offset = Vector2(0, width * 0.5)
		crack.rotation = angle
		crack.position = Vector2(x - 0, y - width * 0.5)

		container.add_child(crack)

	# 如果等级 >= 2，增加一些"碎块"效果（小方块）
	if scar_level >= SCAR_LEVEL_2:
		var chip_count: int = scar_level * 2
		for i in range(chip_count):
			var chip := ColorRect.new()
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.color = Color(0.2, 0.05, 0.05, base_alpha + 0.1)
			chip.size = Vector2(randf_range(2.0, 5.0), randf_range(2.0, 5.0))
			chip.pivot_offset = chip.size * 0.5
			chip.rotation = deg_to_rad(randf_range(0, 360))
			chip.position = Vector2(
				randf_range(panel_size.x * 0.1, panel_size.x * 0.9),
				randf_range(panel_size.y * 0.1, panel_size.y * 0.9)
			)
			container.add_child(chip)

	panel.add_child(container)
