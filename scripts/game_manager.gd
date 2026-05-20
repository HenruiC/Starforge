class_name GameManager
extends Node2D

const _MissionManagerScript = preload("res://scripts/mission_manager.gd")
const _DungeonConfigClass = preload("res://scripts/resources/dungeon_config.gd")

@export var spawn_margin: float = 80.0
@export var base_spawn_interval: float = 1.5
@export var enemies_per_spawn: int = 2
@export var wave_duration: float = 30.0
@export var elite_interval: int = 3

var _enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")

@onready var player: CharacterBody2D = $Player
@onready var spawn_timer: Timer = $SpawnTimer
@onready var wave_timer: Timer = $WaveTimer
@onready var enemies: Node2D = $Enemies

@onready var kill_label: Label = $"../HUDLayer/HUD/KillCount"
@onready var wave_label: Label = $"../HUDLayer/HUD/WaveLabel"
@onready var timer_label: Label = $"../HUDLayer/HUD/TimerLabel"
@onready var game_over_panel: Control = $"../HUDLayer/HUD/GameOver"
@onready var final_score_label: Label = $"../HUDLayer/HUD/GameOver/FinalScore"
@onready var level_up_panel: Control = $"../HUDLayer/LevelUpPanel"
@onready var upgrade_buttons: HBoxContainer = $"../HUDLayer/LevelUpPanel/Buttons"
@onready var char_select_panel: Control = $"../HUDLayer/CharSelect"
@onready var char_select_buttons: HBoxContainer = $"../HUDLayer/CharSelect/Buttons"
@onready var mission_title_label: Label = $"../HUDLayer/HUD/MissionTitle"
@onready var mission_objectives_label: Label = $"../HUDLayer/HUD/MissionObjectives"

var _kill_count: int = 0
var _current_wave: int = 1
var _wave_elapsed: float = 0.0
var _is_game_over: bool = false
var _is_paused: bool = false
var _screen_size: Vector2
var _game_started: bool = false
var _difficulty_scale: float = 1.3
var _mission_manager: Node = null
var _dungeon_config: DungeonConfig = null
var _char_select_ui: CharSelectUI
var _mission_prompt_ui: MissionPromptUI = null
var _prev_objective_states: Dictionary = {}
var _selected_dungeon_id: String = "school"
var _dungeon_select_ui: Control = null

# Phase 2 — 击杀弹跳仪式感递减
var _kill_bounce_count: int = 0
var _prev_kill_count: int = 0

# Phase 3 — 品质闭环
var _death_count: int = 0
var _hint_breathing_tween: Tween = null
var _low_hp_overlay: TextureRect = null
var _operator_protocol_active: bool = false
var _upgrade_btn_map: Dictionary = {}
var _last_hp_pct: float = 1.0

# 迷雾揭示计时（每 0.25s 刷新一次）
var _fog_reveal_accum: float = 0.0

# Phase D — Boss UI 控制器
var _silence_controller: SilenceController = null
var _boss_hp_bar: BossHpBar = null
var _vignette_controller: VignetteController = null

# Boss 战后状态
var _boss_defeated: bool = false
var _boss_defeat_pos: Vector2 = Vector2.ZERO      # Boss 倒下时的世界坐标
var _boss_fight_active: bool = false
var _pending_boss_upgrades: int = 0            # Boss 战中累积的升级次数
var _is_post_boss_upgrade: bool = false            # 下一个升级面板是否走 Boss 特殊逻辑
var _original_upgrade_title: String = ""            # 升级面板原标题（用于恢复）
var _boss_approach_triggered: bool = false           # 防止重复触发登场序列
var _boss_enemy: CharacterBody2D = null               # Boss 实体引用，用于坍塌动画
var _scar_controller: UIScarController = null         # Phase 4 — UI 伤疤系统

# 副本结算相关（校门）
var _game_start_time: int = 0             # Time.get_ticks_msec() at game start
var _gate_reach_time: int = 0             # Time.get_ticks_msec() at gate reach
var _gate_opened: bool = false            # 防止重复触发校门动画
var _dungeon_result_shown: bool = false
var _defend_spawn_timer: Timer = null
var _defend_wave_active: bool = false
var panel_manager: PanelManager = null
   # 防止重复弹出结算

# Phase 4 — 四乐章叙事标题
const MOVEMENT_TITLES: Dictionary = {
	1: {"title": "整队", "sub": "他吹了一声哨子。和从前一样。", "color": Color(1.0, 0.5, 0.1)},
	2: {"title": "分组对抗", "sub": "球从黑暗里飞出来。那不是篮球。", "color": Color(1.0, 0.7, 0.1)},
	3: {"title": "长跑", "sub": "跑道在延伸。体育馆没有这么大。", "color": Color(0.9, 0.85, 0.7)},
	4: {"title": "下课铃", "sub": "你记得怎么敬礼吗。", "color": Color(0.5, 0.05, 0.02)}
}

# 方案A: 统一面板优先级队列 — 记录每轮升级入口动画是否已播放
var _levelup_entrance_played: bool = false

func _ready() -> void:
	z_index = 1
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game_manager")
	_screen_size = get_viewport().get_visible_rect().size
	game_over_panel.visible = false
	level_up_panel.visible = false

	level_up_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	$"../HUDLayer/MapPanel".process_mode = Node.PROCESS_MODE_ALWAYS
	game_over_panel.process_mode = Node.PROCESS_MODE_ALWAYS

	_build_low_hp_overlay()
	_build_mission_prompt_ui()


	panel_manager = PanelManager.new()
	panel_manager.name = "PanelManager"
	add_child(panel_manager)
	panel_manager.register("dialogue", $"../HUDLayer/DialoguePanel")
	panel_manager.register("levelup", level_up_panel)
	panel_manager.register("map", $"../HUDLayer/MapPanel")

	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.enemy_killed_filtered.connect(_on_enemy_killed_filtered)
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_hit.connect(_on_player_hit)
	EventBus.boss_defeated.connect(_on_boss_defeated)

	_defend_spawn_timer = Timer.new()
	_defend_spawn_timer.name = "DefendSpawnTimer"
	_defend_spawn_timer.wait_time = 8.0
	_defend_spawn_timer.timeout.connect(_on_defend_spawn_timer_timeout)
	add_child(_defend_spawn_timer)
	EventBus.boss_killed.connect(_on_boss_killed)
	EventBus.boss_phase_changed.connect(_on_boss_phase_changed)
	if player.has_signal("level_up_available"):
		player.level_up_available.connect(_on_level_up_available)
	if player.has_signal("preset_chosen"):
		player.preset_chosen.connect(_on_game_start)
	_show_dungeon_select()

	# 记录升级面板原标题
	var _tl_label: Label = level_up_panel.get_node("Title") as Label
	if _tl_label:
		_original_upgrade_title = _tl_label.text

	# 创建 Phase D Boss UI 控制器
	_create_boss_ui_controllers()

	# 方案A: 监听面板显示信号（用于延迟播放入场动画等）



# =============================================================================
# Phase D — Boss UI 控制器创建
# =============================================================================

func _create_boss_ui_controllers() -> void:
	var hud_layer: CanvasLayer = $"../HUDLayer"
	if not hud_layer:
		return

	# Silence controller: 注册 HUD 元素到消退/恢复层
	_silence_controller = SilenceController.new()
	hud_layer.add_child(_silence_controller)
	_silence_controller.register_element(kill_label, 3, 1)
	_silence_controller.register_element(wave_label, 1, 3)
	_silence_controller.register_element(timer_label, 2, 2)
	_silence_controller.register_element(mission_title_label, 0, 4)
	_silence_controller.register_element(mission_objectives_label, 0, 4)

	# Boss HP bar: 屏幕顶部血条，默认隐藏
	_boss_hp_bar = BossHpBar.new()
	hud_layer.add_child(_boss_hp_bar)

	# Vignette controller: 暗角效果
	_vignette_controller = VignetteController.new()
	hud_layer.add_child(_vignette_controller)

	# Phase 4 — UI 伤疤系统
	_scar_controller = UIScarController.new()
	hud_layer.add_child(_scar_controller)
	_scar_controller.register_hud_element(kill_label)
	_scar_controller.register_hud_element(wave_label)
	_scar_controller.register_hud_element(timer_label)
	_scar_controller.register_hud_element(mission_title_label)
	_scar_controller.register_hud_element(mission_objectives_label)
	_scar_controller.start()


# =============================================================================
# Phase D — Boss 战事件处理
# =============================================================================

## Boss 击杀信号处理
## 视觉死亡演出（Hit Stop/坍塌/粒子/大字）已在 enemy.gd 的 BossDeathSequence 中完成。
## game_manager 只处理战后逻辑：独白、清理、升级面板。
func _on_boss_killed(_boss_id: String, position: Vector2, _boss_name: String) -> void:
	_boss_defeated = true
	_boss_defeat_pos = position
	_boss_defeated_sequence()

## 旧 enemy_killed_filtered 不再处理 is_boss
func _on_enemy_killed_filtered(_pos: Vector2, _score: int, _is_elite: bool, _is_boss: bool, _is_ranged: bool) -> void:
	pass

## Boss 阶段变化时更新血条颜色
func _on_boss_phase_changed(phase: int, _phase_name: String) -> void:
	if _boss_hp_bar and is_instance_valid(_boss_hp_bar):
		match phase:
			2, 3, 4:
				_boss_hp_bar.set_phase_color(phase)
	# Phase 4 — 乐章标题浮动显示
	_show_movement_title(phase)

## Boss 击败序列 — 战后逻辑（视觉演出已由 enemy.gd 处理）
##
## t=0.0: 开始（VictoryTextUI 已在 boss 死亡序列中浮现）
## t=0.5: 概率独白
## t=2.0+: 清理 + 升级面板
func _boss_defeated_sequence() -> void:
	_boss_defeated = true

	# 隐藏 Boss 血条
	if _boss_hp_bar and is_instance_valid(_boss_hp_bar):
		_boss_hp_bar.exit()

	# 学生小怪消散
	_dissipate_student_minions()

	# 等待胜利文字展示（enemy 死亡序列已经触发，等一段时间后显示独白）
	await get_tree().create_timer(0.5, false, true).timeout

	# ---- 概率独白（战后叙事） ----
	var roll := randf()
	var monologue_text: String
	if roll < 0.1:
		monologue_text = "校门开了。"
	elif roll < 0.3:
		monologue_text = "你低头看了看自己的手。手在抖。"
	else:
		monologue_text = "他倒下的时候，体育馆的灯闪了一下。"

	var monologue_label := Label.new()
	monologue_label.name = "VictoryMonologue"
	monologue_label.text = monologue_text
	monologue_label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.1))
	monologue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	monologue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	monologue_label.modulate = Color(1, 1, 1, 0)
	monologue_label.size = get_viewport().get_visible_rect().size
	$"../HUDLayer".add_child(monologue_label)
	monologue_label.z_index = 21
	var mono_tween: Tween = create_tween()
	mono_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	mono_tween.tween_property(monologue_label, "modulate:a", 1.0, 0.5)
	mono_tween.tween_interval(1.5)
	mono_tween.tween_property(monologue_label, "modulate:a", 0.0, 0.5)
	mono_tween.tween_callback(func():
		if is_instance_valid(monologue_label):
			monologue_label.queue_free()
	)
	await get_tree().create_timer(0.3).timeout

	# ---- Cleanup + Post-boss state ----
	if _vignette_controller and is_instance_valid(_vignette_controller):
		_vignette_controller.set_state(VignetteController.State.BOSS_DEFEAT)
	if _boss_enemy and is_instance_valid(_boss_enemy):
		_boss_enemy.queue_free()
		_boss_enemy = null

	_is_post_boss_upgrade = true
	EventBus.boss_defeated.emit()

	# ---- Handle pending upgrades ----
	await get_tree().create_timer(0.5).timeout
	while _pending_boss_upgrades > 0:
		_pending_boss_upgrades -= 1
		_show_upgrade_panel()
		break  # 只弹第一个，后续由 _finish_upgrade_chosen 链式处理


## 学生小怪消散 —— 不是被杀了，是下课了
func _dissipate_student_minions() -> void:
	for c in enemies.get_children():
		if c is CharacterBody2D and not c.is_boss and not c.is_elite:
			var sp: ColorRect = c.get_node("Sprite") if c.has_node("Sprite") else null
			if sp and sp.color == Color(1.0, 1.0, 1.0):
				c.set_process(false)
				c.set_physics_process(false)
				var d_tween: Tween = create_tween()
				d_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
				d_tween.tween_property(c, "modulate:a", 0.0, 0.5)
				d_tween.tween_callback(func():
					if is_instance_valid(c):
						c.queue_free()
				)


## 金色粒子爆发（在 Boss 坍塌位置）
func _spawn_golden_particles(world_pos: Vector2) -> void:
	var screen_pos: Vector2 = _world_to_screen(world_pos)
	var particle_count: int = 40
	var gold_color := Color(1.0, 0.85, 0.2)
	for i in particle_count:
		var p := ColorRect.new()
		p.color = gold_color
		p.size = Vector2(6, 6)
		p.position = screen_pos
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$"../HUDLayer".add_child(p)

		var angle: float = randf() * TAU
		var dist: float = randf_range(80, 200)
		var target_pos: Vector2 = screen_pos + Vector2(cos(angle), sin(angle)) * dist

		var pt: Tween = create_tween()
		pt.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		pt.set_parallel(true)
		pt.tween_property(p, "position", target_pos, randf_range(0.4, 0.8)).set_ease(Tween.EASE_OUT)
		pt.tween_property(p, "modulate:a", 0.0, randf_range(0.5, 0.9)).set_ease(Tween.EASE_IN)
		pt.tween_callback(func():
			if is_instance_valid(p):
				p.queue_free()
		)

## EventBus.boss_defeated 回调
func _on_boss_defeated() -> void:
	_boss_fight_active = false
	# Phase 4 — Boss 击败：降低伤疤等级（半治愈）
	if _scar_controller and is_instance_valid(_scar_controller):
		_scar_controller.reduce_scar()
	# 在此处可以触发累积升级面板（按设计文档 TASK-P10）
	if _silence_controller and is_instance_valid(_silence_controller):
		_silence_controller.force_restore()



# =============================================================================
# 校门到达检测 & 门打开动画
# =============================================================================

## 检测玩家到达 zone_gate_escape
## 仅在 Boss 已被击败时触发校门动画
func _on_player_entered_zone_for_gate(zone_id: String) -> void:
	if zone_id != "zone_gate_escape":
		return
	if not _boss_defeated:
		return  # Boss 还没死，不能逃离
	if _gate_opened:
		return  # 已经开始动画

	_gate_reach_time = Time.get_ticks_msec()
	_play_gate_open_sequence()


## 校门打开主序列（~3.0 秒总时长）
## 参考设计文档：output/docs/副本结算与校门-杨奇.md
func _play_gate_open_sequence() -> void:
	_gate_opened = true

	# 获取 TileMap 引用
	var sm := get_node_or_null("../SchoolMap")
	if sm == null or not sm.has_method("get_tilemap"):
		return
	var tm: TileMap = sm.get_tilemap()
	var T := 48
	var cols := int(ceil(5760.0 / float(T)))
	var rows := int(ceil(4320.0 / float(T)))
	@warning_ignore("integer_division")
	var gx := cols / 2  # gate center x in tile coords

	# ---- Step 1: 暗角+HUD消退 ----

	# ---- Step 2: 白暗角从四边涌入 ----
	_show_gate_light_vignette()

	# ---- Step 3: 门 tile 逐帧移动（约 8 帧 x 0.15s = 1.2s）----
	const GATE_HALF := 6
	const MOVE_STEPS := 8
	const MAX_SHIFT := 3

	for step in range(MOVE_STEPS + 1):
		var shift := int(round(float(step) / MOVE_STEPS * MAX_SHIFT))

		for dx in range(-GATE_HALF, GATE_HALF + 1):
			tm.erase_cell(1, Vector2i(gx + dx, rows - 1))

		for dx in range(-GATE_HALF, 0):
			tm.set_cell(1, Vector2i(gx + dx - shift, rows - 1), 7, Vector2i(0, 0))
		for dx in range(1, GATE_HALF + 1):
			tm.set_cell(1, Vector2i(gx + dx + shift, rows - 1), 7, Vector2i(0, 0))

		for dx in range(-shift, shift + 1):
			tm.set_cell(0, Vector2i(gx + dx, rows - 1), 12, Vector2i(0, 0))

		await get_tree().create_timer(0.15, false, true).timeout

	# ---- Step 4: 门完全消失，白光完全填充 ----
	for dx in range(-MAX_SHIFT, MAX_SHIFT + 1):
		tm.erase_cell(1, Vector2i(gx + dx, rows - 1))
		tm.set_cell(0, Vector2i(gx + dx, rows - 1), 12, Vector2i(0, 0))

	# ---- Step 5: 白色全屏 flash ----
	await _white_screen_flash(0.08)

	# ---- Step 6: 金色粒子涌入 ----
	_spawn_gate_light_particles(gx, rows - 1)

	# ---- Step 7: 恢复时间，弹出结算面板 ----
	Engine.time_scale = 1.0
	await get_tree().create_timer(0.3, false, true).timeout
	_show_dungeon_result()


## 白色闪屏 — 暖白全屏覆盖 0.08s
func _white_screen_flash(duration: float) -> void:
	var flash := ColorRect.new()
	flash.name = "GateFlash"
	flash.color = Color(1.0, 1.0, 0.95, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.anchors_preset = Control.PRESET_FULL_RECT
	flash.z_index = 30
	$"../HUDLayer".add_child(flash)

	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.tween_property(flash, "color:a", 0.92, duration * 0.5)
	t.tween_property(flash, "color:a", 0.0, duration * 0.5)
	t.tween_callback(func():
		if is_instance_valid(flash):
			flash.queue_free()
	)
	await get_tree().create_timer(duration, false, true).timeout


## 金色粒子从门外涌入
func _spawn_gate_light_particles(gx: int, gy: int) -> void:
	var origin: Vector2 = get_viewport().get_visible_rect().size * Vector2(0.5, 1.0)

	var particle_count: int = 30
	var gold_color := Color(1.0, 0.85, 0.2)
	for i in particle_count:
		var p := ColorRect.new()
		p.color = gold_color
		p.size = Vector2(5, 5)
		p.position = origin + Vector2(randf_range(-100, 100), 0)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.z_index = 25
		$"../HUDLayer".add_child(p)

		var target_pos: Vector2 = p.position + Vector2(
			randf_range(-120, 120),
			-randf_range(80, 250)
		)

		var pt: Tween = create_tween()
		pt.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		pt.set_parallel(true)
		pt.tween_property(p, "position", target_pos, randf_range(0.6, 1.2)).set_ease(Tween.EASE_OUT)
		pt.tween_property(p, "modulate:a", 0.0, randf_range(0.5, 1.0)).set_ease(Tween.EASE_IN)
		pt.tween_callback(func():
			if is_instance_valid(p):
				p.queue_free()
		)


## 白色暗角从屏幕边缘涌入
func _show_gate_light_vignette() -> void:
	var vignette := ColorRect.new()
	vignette.name = "GateLightVignette"
	vignette.color = Color(1.0, 0.98, 0.88, 0.0)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.anchors_preset = Control.PRESET_FULL_RECT
	vignette.z_index = 20
	$"../HUDLayer".add_child(vignette)

	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.tween_property(vignette, "color:a", 0.4, 0.5)
	t.tween_interval(0.8)
	t.tween_property(vignette, "color:a", 0.0, 0.3)
	t.tween_callback(func():
		if is_instance_valid(vignette):
			vignette.queue_free()
	)


# =============================================================================
# 评分系统
# =============================================================================

func _get_clear_time_seconds() -> float:
	if _game_start_time == 0 or _gate_reach_time == 0:
		return 0.0
	return float(_gate_reach_time - _game_start_time) / 1000.0

func _format_clear_time() -> String:
	var secs := int(_get_clear_time_seconds())
	var minutes := secs / 60
	var remaining := secs % 60
	return "%d:%02d" % [minutes, remaining]

func _calculate_rating() -> Dictionary:
	var clear_secs := _get_clear_time_seconds()

	var time_score := clampf(100.0 - (clear_secs - 90.0) * 0.3, 0.0, 100.0)
	var death_score := clampf(100.0 - _death_count * 25.0, 0.0, 100.0)
	var kill_score := clampf(_kill_count * 2.5, 0.0, 100.0)
	var total := time_score * 0.4 + death_score * 0.3 + kill_score * 0.3

	var grade: String
	var grade_color: Color
	var grade_flavor: String
	if total >= 85:
		grade = "S"
		grade_color = Color(0.788, 0.659, 0.298)
		grade_flavor = "你听见了下课铃。你自由了。"
	elif total >= 70:
		grade = "A"
		grade_color = Color(0.91, 0.84, 0.72)
		grade_flavor = "校门在你身后关上了。你没有回头。"
	elif total >= 50:
		grade = "B"
		grade_color = Color(0.55, 0.49, 0.42)
		grade_flavor = "你跑出来了。但有些东西跟在你后面——在你的影子里。"
	else:
		grade = "C"
		grade_color = Color(0.42, 0.23, 0.16)
		grade_flavor = "校门开了。但你不确定自己是不是也变了。"

	return {
		"clear_time_secs": clear_secs,
		"clear_time_str": _format_clear_time(),
		"player_level": player.level if player else 1,
		"kill_count": _kill_count,
		"death_count": _death_count,
		"grade": grade,
		"grade_color": grade_color,
		"grade_flavor": grade_flavor,
		"total_score": total,
		"time_score": time_score,
		"death_score": death_score,
		"kill_score": kill_score,
		"reward_slots": 3 if grade == "S" else (2 if grade == "A" else 1),
	}


func _show_dungeon_result() -> void:
	if _dungeon_result_shown:
		return
	_dungeon_result_shown = true

	_is_paused = true
	get_tree().paused = true
	$"../HUDLayer".process_mode = Node.PROCESS_MODE_ALWAYS

	var panel := DungeonResultPanel.new()
	panel.name = "DungeonResultPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.anchors_preset = Control.PRESET_FULL_RECT
	panel.z_index = 50
	$"../HUDLayer".add_child(panel)

	# 注册到 PanelManager（优先级3，最低）
	panel_manager.register("dungeon_result", panel)
	# 结算面板强制显示，不排队
	panel_manager.force_close_all()
	panel_manager.request_show("dungeon_result")

	var rating: Dictionary = _calculate_rating()
	panel.set_data(rating)
	panel.play_enter_animation()



func _show_movement_title(phase: int) -> void:
	var data: Dictionary = MOVEMENT_TITLES.get(phase, {})
	if data.is_empty():
		return
	var title: String = data.get("title", "")
	var sub: String = data.get("sub", "")
	var color: Color = data.get("color", Color.WHITE)
	if title.is_empty():
		return

	var title_label := Label.new()
	title_label.name = "MovementTitle_%d" % phase
	title_label.text = title
	title_label.add_theme_color_override("font_color", color)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.modulate = Color(1, 1, 1, 0)
	title_label.size = get_viewport().get_visible_rect().size
	$"../HUDLayer".add_child(title_label)
	title_label.z_index = 22

	var sub_label := Label.new()
	sub_label.name = "MovementSub_%d" % phase
	sub_label.text = sub
	sub_label.add_theme_color_override("font_color", color)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub_label.modulate = Color(1, 1, 1, 0)
	sub_label.position = Vector2(0, 30)
	$"../HUDLayer".add_child(sub_label)
	sub_label.z_index = 22

	var t: Tween = create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.set_parallel(true)
	t.tween_property(title_label, "modulate:a", 1.0, 0.3)
	t.tween_property(sub_label, "modulate:a", 1.0, 0.4).set_delay(0.1)
	t.tween_interval(1.8)
	t.set_parallel(true)
	t.tween_property(title_label, "modulate:a", 0.0, 0.4)
	t.tween_property(sub_label, "modulate:a", 0.0, 0.4)
	t.tween_callback(func():
		if is_instance_valid(title_label):
			title_label.queue_free()
		if is_instance_valid(sub_label):
			sub_label.queue_free()
	)


## 世界坐标 → 屏幕坐标（用于 Boss 升级面板定位）
func _world_to_screen(world_pos: Vector2) -> Vector2:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if not camera:
		return get_viewport().get_visible_rect().size * 0.5
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	return (world_pos - camera.global_position) * camera.zoom + viewport_size * 0.5


func _build_low_hp_overlay() -> void:
	_low_hp_overlay = TextureRect.new()
	_low_hp_overlay.name = "LowHealthOverlay"
	_low_hp_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_low_hp_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_low_hp_overlay.modulate = Color(1, 1, 1, 0)
	_low_hp_overlay.z_index = 15
	var grad := Gradient.new()
	grad.colors = [Color(1, 0, 0, 0), Color(0.8, 0.0, 0.0, 0.55)]
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_to = Vector2(0.5, 0.5)
	_low_hp_overlay.texture = gt
	_low_hp_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	$"../HUDLayer".add_child(_low_hp_overlay)
	_build_mission_prompt_ui()

func _build_mission_prompt_ui() -> void:
	_mission_prompt_ui = MissionPromptUI.new()
	_mission_prompt_ui.set_player(player)
	$"../HUDLayer".add_child(_mission_prompt_ui)

func _show_dungeon_select() -> void:
	_is_paused = true
	GameState.set_state(GameState.State.CHAR_SELECT)
	$"../HUDLayer".process_mode = Node.PROCESS_MODE_ALWAYS

	_dungeon_select_ui = DungeonSelectUI.new()
	_dungeon_select_ui.dungeon_selected.connect(_on_dungeon_selected)
	$"../HUDLayer".add_child(_dungeon_select_ui)


func _on_dungeon_selected(dungeon_id: String) -> void:
	_selected_dungeon_id = dungeon_id
	if _dungeon_select_ui:
		_dungeon_select_ui.queue_free()
		_dungeon_select_ui = null
	_show_char_select()


func _show_char_select() -> void:
	_is_paused = true
	GameState.set_state(GameState.State.CHAR_SELECT)
	$"../HUDLayer".process_mode = Node.PROCESS_MODE_ALWAYS

	char_select_panel.scale = Vector2(0.85, 0.85)
	char_select_panel.pivot_offset = char_select_panel.size * 0.5

	_char_select_ui = CharSelectUI.create(char_select_panel, char_select_buttons, _on_char_select_started)

	# Phase 2 — CharSelect 入场两层节奏
	_enter_char_select()


func _enter_char_select() -> void:
	var t_main: Tween = create_tween()
	t_main.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t_main.tween_property(char_select_panel, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_IN_OUT)

	for child in char_select_buttons.get_children():
		if child is HBoxContainer:
			var zones: Array = child.get_children()
			for z in zones:
				if z is VBoxContainer:
					z.modulate = Color(1, 1, 1, 0)
			var t_zones: Tween = create_tween()
			t_zones.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
			t_zones.set_parallel(true)
			for i in zones.size():
				if zones[i] is VBoxContainer:
					t_zones.tween_property(zones[i], "modulate", Color.WHITE, 0.2).set_delay(i * 0.08)
			break



func _on_char_select_started(weapon: String, talents: Array) -> void:
	var confirm_btn := _char_select_ui.confirm_btn
	confirm_btn.disabled = true

	var ct: Tween = create_tween()
	ct.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	ct.tween_property(confirm_btn, "scale", Vector2(0.95, 0.95), 0.06)

	ct.tween_property(char_select_panel, "modulate", Color(1, 1, 1, 0), 0.3)
	ct.parallel().tween_property(char_select_panel, "scale", Vector2(0.85, 0.85), 0.3)

	var _w: String = weapon
	var _t: Array = talents
	ct.tween_callback(func():
		_finish_char_select_start(_w, _t)
	)


func _finish_char_select_start(weapon: String, talents: Array) -> void:
	char_select_panel.visible = false
	char_select_panel.modulate = Color.WHITE
	char_select_panel.scale = Vector2.ONE
	$"../HUDLayer".process_mode = Node.PROCESS_MODE_INHERIT
	_is_paused = false
	var _ps: int = GameState.State.PLAYING; GameState.set_state(_ps)
	player.init_skills(talents, weapon)
	# Phase 4 — 武器类型影响 HUD 色调
	UIHelpers.weapon_type = weapon

func _on_game_start(_preset: String) -> void:
	var ms: Node = $"../HUDLayer/MapSystem"
	var map_tex: Texture2D = null
	var sm := get_node_or_null("../SchoolMap")
	if sm and sm.has_method("generate_map_texture"):
		map_tex = sm.generate_map_texture()
	if ms and ms.has_method("init"): ms.init(player, $"../HUDLayer", map_tex)
	_game_started = true
	_game_start_time = Time.get_ticks_msec()
	match _selected_dungeon_id:
		"rooftop": _dungeon_config = _DungeonConfigClass.school_default()
		_: _dungeon_config = _DungeonConfigClass.school_default()
	_mission_manager = _MissionManagerScript.new()
	_mission_manager.init()
	_mission_manager.stage_cleared.connect(_on_stage_cleared)
	_mission_manager.stage_activated.connect(_on_mission_stage_activated)
	EventBus.boss_approach_started.connect(_on_boss_approach_started)
	EventBus.player_entered_zone.connect(_on_player_entered_zone_for_boss)
	EventBus.player_entered_zone.connect(_on_player_entered_zone_for_gate)
	add_child(_mission_manager)
	# 学校副本专属：体育馆锁门
	if _selected_dungeon_id == "school":
		var ld := LockedDoor.new()
		ld.name = "GymLockedDoor"
		ld.door_id = "gym_lock_door"
		ld.unlock_floor_sid = 2
		var gym_door_tiles: Array[Vector2i] = []
		for dx in range(-4, 5):
			gym_door_tiles.append(Vector2i(60 + dx, 63))
		ld.tilemap_path = "../../SchoolMap/TileMap"
		ld.door_tile_positions = gym_door_tiles
		ld.play_unlock_fx = true
		add_child(ld)
	_update_mission_hud()

	# MissionPromptUI: show stage 1 activation + objectives
	_refresh_prompt_ui_from_stage()

	# 波次生成已禁用，使用预置敌人
	# spawn_timer.wait_time = base_spawn_interval; spawn_timer.start()  # 波次生成已禁用

	# 预置敌人（68个固定点位，杨奇集群方案）
	_spawn_preplaced_enemies()
	# wave_timer.wait_time = wave_duration; wave_timer.start()  # 波次生成已禁用
	_update_ui()

func _process(delta: float) -> void:
	if _is_game_over or not _game_started: return
	if _operator_protocol_active:
		_wave_elapsed += delta
		return
	if _is_paused: return
	_wave_elapsed += delta
	timer_label.text = "剩余: %.0fs" % maxf(wave_duration - _wave_elapsed, 0.0)
	if _mission_manager:
		_update_mission_hud()
	# Boss HP 条实时更新
	if _boss_hp_bar and _boss_fight_active:
		for c in enemies.get_children():
			if c is CharacterBody2D and c.is_boss:
				_boss_hp_bar.set_hp(c._health, c.max_health)
				break
	_update_low_hp_overlay()

	# 迷雾揭示（每 0.25s 基于玩家位置擦除 fog tile）
	_fog_reveal_accum += delta
	if _fog_reveal_accum >= 0.25:
		_fog_reveal_accum = 0.0
		var sm := get_node_or_null("../SchoolMap")
		if sm and sm.has_method("reveal_fog_area"):
			sm.reveal_fog_area(player.global_position.x, player.global_position.y, 8)


# 从 SchoolMap 读取预置敌人配置并生成
func _spawn_preplaced_enemies() -> void:
	var sm := get_node_or_null("../SchoolMap")
	if sm == null or not sm.has_method("get_preplaced_enemies"):
		return
	for cfg: Dictionary in sm.get_preplaced_enemies():
		var e: Enemy = _enemy_scene.instantiate() as Enemy
		e.global_position = cfg["pos"]
		var etype: String = cfg.get("type", "melee")
		match etype:
			"elite":
				e.is_elite = true
				e.max_health = 210
				e.move_speed = 110
				e.contact_damage = 22
			"ranged":
				e.is_ranged = true
				e.max_health = 30
				e.move_speed = 100
			"stationary":
				pass  # 普通近战，但 activation_range > 0
			_:
				pass  # 普通近战
		e.activation_range = cfg.get("activation", 0.0)
		enemies.add_child(e)

func _on_spawn_timer_timeout() -> void:
	if _is_game_over or not _game_started: return
	var count := enemies_per_spawn + int(_current_wave * 0.5)
	var is_elite_wave := (_current_wave % elite_interval == 0)
	for i in count: _spawn_enemy(i == 0 and is_elite_wave)
	if _current_wave >= 2:
		for i in max(int(float(_current_wave) / 3.0), 1): _spawn_ranged_enemy()

func _spawn_enemy(as_elite: bool = false) -> void:
	var e: Enemy = _enemy_scene.instantiate() as Enemy
	e.global_position = _random_spawn_position()
	var stage: int = _mission_manager.get_current_stage() if _mission_manager else 1
	var m: float = 1.0 + (_current_wave - 1) * 0.2
	if as_elite:
		e.is_elite = true
		if _dungeon_config:
			e.max_health = int(_dungeon_config.s2_elite_hp * m)
			e.contact_damage = int(_dungeon_config.s2_elite_damage * m)
			e.move_speed = _dungeon_config.s2_melee_speed + _current_wave * 8
		else:
			e.max_health = int(30 * m * 3)
			e.move_speed = 120 + _current_wave * 8
			e.contact_damage = int(10 * m * 2)
		e.score_value = 5; e.xp_value = 40
	else:
		if _dungeon_config:
			e.max_health = int(_dungeon_config.get_melee_hp(stage) * m)
			e.move_speed = _dungeon_config.get_melee_speed(stage) + _current_wave * 6
			e.contact_damage = int(_dungeon_config.get_melee_damage(stage) * m)
		else:
			e.max_health = int(e.max_health * m)
			e.move_speed += _current_wave * 6
			e.contact_damage = int(e.contact_damage * m)
	enemies.add_child(e)

func _spawn_ranged_enemy() -> void:
	var e: Enemy = _enemy_scene.instantiate() as Enemy
	e.global_position = _random_spawn_position()
	var stage: int = _mission_manager.get_current_stage() if _mission_manager else 1
	var m: float = 1.0 + (_current_wave - 1) * 0.2
	e.is_ranged = true
	if _dungeon_config:
		e.max_health = int(_dungeon_config.get_ranged_hp(stage) * m)
		e.move_speed = _dungeon_config.get_ranged_speed(stage) + _current_wave * 4
		e.ranged_damage = int(_dungeon_config.get_ranged_damage(stage) * m)
	else:
		e.max_health = int(25 * m)
		e.move_speed = 100 + _current_wave * 4
		e.ranged_damage = int(10 * m)
	e.score_value = 2; e.xp_value = 20
	e.ranged_cooldown = maxf(2.5 - _current_wave * 0.1, 0.8)
	var sp: ColorRect = e.get_node("Sprite")
	if sp: sp.color = Color(0.2, 0.8, 0.3, 1.0)
	enemies.add_child(e)

func _random_spawn_position() -> Vector2:
	var stage: int = _mission_manager.get_current_stage() if _mission_manager else 1
	var center := player.global_position if player else Vector2(2880, 3600)
	var nav: Node = get_node_or_null("../NavManager")

	if stage == 1:
		var y_range := Vector2(3600, 4200)
		center = Vector2(randf_range(500, 5000), randf_range(y_range.x, y_range.y))
	elif stage == 2:
		var side := randi() % 2
		if side == 0: center = Vector2(randf_range(800, 2000), randf_range(2600, 3600))
		else: center = Vector2(randf_range(3200, 4400), randf_range(2600, 3600))
	elif stage == 3:
		center = Vector2(randf_range(2200, 3200), randf_range(2700, 3300))
	elif stage == 4:
		center = Vector2(randf_range(2400, 3200), randf_range(300, 1300))
	elif stage >= 5:
		center = Vector2(randf_range(2400, 3200), randf_range(300, 4200))

	if nav and nav.has_method("get_random_nav_point"):
		return nav.get_random_nav_point(center)
	return center + Vector2(randf_range(-400,400), randf_range(-400,400))

func _on_enemy_killed(_pos: Vector2, score: int) -> void:
	if score > 0:
		_kill_count += score
		if player.has_method("gain_exp"):
			player.gain_exp(15 if score == 1 else (40 if score == 5 else score * 8))
		if _mission_manager: _mission_manager.notify_kill()
	_update_ui(); _update_mission_hud()


func _on_player_died(_kc: int = 0) -> void:
	_is_game_over = true
	spawn_timer.stop()
	wave_timer.stop()

	UIEffects.kill_group("hud_killcount")
	UIEffects.kill_group("hud_wave")
	UIEffects.kill_group("hud_timer")
	UIEffects.kill_group("hud_mission")
	UIEffects.kill_group("hud_cooldown")
	UIEffects.kill_group("hud_exp")

	# 方案A: 统一强制关闭所有面板（跳过动画，清除队列）
	panel_manager.force_close_all()

	Engine.time_scale = 1.0
	GameState.set_state(GameState.State.DEAD)

	_death_count += 1
	# Phase 4 — 持久化死亡计数
	GamePersistence.increment_total_deaths()

	# Phase 4 — Boss 战中死亡特殊文本
	if _boss_fight_active:
		var boss_death_title: Label = game_over_panel.get_node("Title") as Label
		boss_death_title.text = "再来一圈。"
		boss_death_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	final_score_label.text = "击杀: %d\n波次: %d\nLv: %d" % [_kill_count, _current_wave, player.level]

	var panel_bg: ColorRect = game_over_panel.get_node("Panel")
	var title_label: Label = game_over_panel.get_node("Title")
	var stats_label: Label = game_over_panel.get_node("FinalScore")
	var hint_label: Label = game_over_panel.get_node("RestartHint")

	panel_bg.color.a = 0.0
	title_label.modulate = Color(1, 1, 1, 0)
	title_label.scale = Vector2(0.5, 0.5)
	stats_label.modulate = Color(1, 1, 1, 0)
	hint_label.modulate = Color(1, 1, 1, 0)
	game_over_panel.visible = true

	var fast_mode: bool = _death_count >= 5
	var mask_dur: float = 0.1 if fast_mode else 0.3
	var title_dur: float = 0.2 if fast_mode else 0.4
	var title_delay: float = 0.15 if fast_mode else 0.5
	var stats_dur: float = 0.15 if fast_mode else 0.3

	var t: Tween = create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)

	t.tween_property(panel_bg, "color:a", 0.92, mask_dur)
	t.tween_interval(title_delay)
	t.set_parallel(true)
	t.tween_property(title_label, "scale", Vector2.ONE, title_dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(title_label, "modulate:a", 1.0, title_dur * 0.7)

	t.tween_interval(0.2 if not fast_mode else 0.05)
	t.tween_property(stats_label, "modulate:a", 1.0, stats_dur)

	t.tween_callback(func():
		_start_hint_breathing(hint_label)
	)

func _start_hint_breathing(hint: Label) -> void:
	_stop_hint_breathing()
	hint.modulate = Color(1, 1, 1, 0.4)
	_hint_breathing_tween = create_tween().set_loops()
	_hint_breathing_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	_hint_breathing_tween.tween_property(hint, "modulate:a", 1.0, 1.0).set_ease(Tween.EASE_IN_OUT)
	_hint_breathing_tween.tween_property(hint, "modulate:a", 0.4, 1.0).set_ease(Tween.EASE_IN_OUT)

func _stop_hint_breathing() -> void:
	if _hint_breathing_tween and is_instance_valid(_hint_breathing_tween):
		_hint_breathing_tween.kill()
	_hint_breathing_tween = null

func _on_wave_timer_timeout() -> void:
	_current_wave += 1; _wave_elapsed = 0.0
	spawn_timer.wait_time = maxf(base_spawn_interval / pow(_difficulty_scale, _current_wave - 1), 0.3)
	enemies_per_spawn += 1
	EventBus.wave_changed.emit(_current_wave); _update_ui()

	var peak_scale := maxf(
		UIEffects.WAVE_INITIAL_PEAK - (_current_wave - 2) * UIEffects.WAVE_DECAY_PER_STEP,
		UIEffects.WAVE_MIN_PEAK
	)
	UIEffects.wave_flash(wave_label, peak_scale)

func _on_level_up_available(_count: int) -> void:
	# Boss 战中延迟升级：只计数，不弹出面板
	if _boss_fight_active:
		_pending_boss_upgrades += 1
		return
	await get_tree().create_timer(0.15).timeout
	_show_upgrade_panel()


# 方案A: 面板显示时回调 — 用于延迟播放入场动画
func _on_panel_shown(panel_id: String) -> void:
	match panel_id:
		"levelup":
			if not _levelup_entrance_played:
				_enter_upgrade_panel()
				_levelup_entrance_played = true


func _show_upgrade_panel() -> void:
	print("UPGRADE: _show_upgrade_panel called, paused=", get_tree().paused, " _is_paused=", _is_paused)
	_is_paused = true; get_tree().paused = true
	GameState.set_state(GameState.State.PAUSED)
	$"../HUDLayer".process_mode = Node.PROCESS_MODE_ALWAYS

	# 重置面板到默认位置（确保后续 normal upgrade 不偏移）

	var pool: Array = player.skill_manager.get_upgrade_pool()
	pool.shuffle()

	# Phase D — 击败 Boss 后的升级：15% Operator Protocol 概率
	var is_operator: bool = not _operator_protocol_active
	if _is_post_boss_upgrade:
		is_operator = is_operator and randf() < 0.15
	else:
		is_operator = is_operator and randf() < 0.05

	_upgrade_btn_map = UpgradeUI.create(upgrade_buttons, pool, _on_upgrade_chosen)
	if is_operator:
		_operator_protocol_active = true
		# Phase D — 击败 Boss 后的 Operator Protocol 使用特殊文本
		if _is_post_boss_upgrade:
			_add_operator_option(pool, "???\n你听见了哨声。你应该听不见的。")
		else:
			_add_operator_option(pool)

	# 通过 PanelManager 统一管理显示（自动优先级排队/预占保留）
	_levelup_entrance_played = false
	panel_manager.request_show("levelup")


func _enter_upgrade_panel() -> void:
	print("UPGRADE: _enter_upgrade called, panel.visible=", level_up_panel.visible, " modulate.a=", level_up_panel.modulate.a)
	UIEffects.kill_group("panel_levelup")

	var bg := level_up_panel.get_node("Bg") as ColorRect
	var title := level_up_panel.get_node("Title") as Label

	if _is_post_boss_upgrade:
		# === TASK-I05: 升级序列微型电影 — 佐藤的馈赠 ===
		_is_post_boss_upgrade = false
		title.text = "他留给你的"
		title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))  # 金色
	else:
		# 标准标题
		title.text = _original_upgrade_title
		title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))  # 默认金色

	bg.modulate = Color(0, 0, 0, 0.0)
	title.scale = Vector2(0.6, 0.6)
	title.modulate = Color(1, 1, 1, 0)

	var btns: Array[Button] = []
	for child in upgrade_buttons.get_children():
		if child is Button:
			child.scale = Vector2(0.5, 0.5)
			btns.append(child)

	var t: Tween = create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)

	# 背景淡入 0.2s
	t.tween_property(bg, "modulate", Color(0, 0, 0, 0.5), 0.2)
	# 标题平行动画：缩放 + 淡入
	t.set_parallel(true)
	t.tween_property(title, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(title, "modulate:a", 1.0, 0.2)

	# 按钮 stagger 入场
	t.set_parallel(false)
	t.tween_interval(0.0)
	t.set_parallel(true)
	for i in btns.size():
		t.tween_property(btns[i], "scale", Vector2.ONE, 0.15).set_delay(i * 0.06).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _add_operator_option(pool: Array, override_text: String = "") -> void:
	var idx: int = mini(3, pool.size() - 1)
	var opt: Dictionary = pool[idx]
	var btn := Button.new()

	# Phase D — 击败 Boss 后的 Operator Protocol："哨声"选项
	if not override_text.is_empty():
		btn.text = override_text
	else:
		btn.text = "???\n%s" % opt.desc

	btn.custom_minimum_size = Vector2(180, 80)
	btn.modulate = Color(0.8, 0.15, 0.15, 0.7)
	var s := UIHelpers.make_style(Color(0.5, 0.0, 0.0, 1.0))
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", s.duplicate())
	btn.add_theme_stylebox_override("pressed", s.duplicate())
	var oid: String = opt.id
	btn.pressed.connect(func():
		_on_operator_upgrade_chosen(oid)
	)
	upgrade_buttons.add_child(btn)

func _on_operator_upgrade_chosen(id: String) -> void:
	player.apply_upgrade(id)
	UIEffects.kill_group("panel_levelup")
	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.tween_callback(func(): if is_instance_valid(level_up_panel): level_up_panel.visible = false)
	t.tween_interval(0.04)
	t.tween_callback(func(): if is_instance_valid(level_up_panel): level_up_panel.visible = true)
	t.tween_interval(0.04)
	t.tween_callback(func(): if is_instance_valid(level_up_panel): level_up_panel.visible = false)
	t.tween_interval(0.04)
	t.tween_callback(func(): if is_instance_valid(level_up_panel): level_up_panel.visible = true)
	t.tween_interval(0.04)
	t.tween_callback(func(): if is_instance_valid(level_up_panel): level_up_panel.visible = false)
	t.tween_interval(0.06)
	t.tween_callback(func():
		level_up_panel.visible = false
		level_up_panel.modulate = Color.WHITE
		level_up_panel.scale = Vector2.ONE
		_finish_upgrade_chosen()
		# 佐藤的 Operator Protocol：Boss 战后乱码持续 5s
		var garbled_iters: int = 50 if _operator_protocol_active else 20
		_apply_garbled_text(garbled_iters)
	)

func _on_upgrade_chosen(id: String) -> void:
	player.apply_upgrade(id)
	_play_upgrade_selection_feedback(id)
	await get_tree().create_timer(0.35).timeout
	_finish_upgrade_chosen()

func _play_upgrade_selection_feedback(id: String) -> void:
	UIEffects.kill_group("panel_levelup")
	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)

	t.set_parallel(true)
	for btn_id in _upgrade_btn_map:
		var btn: Button = _upgrade_btn_map[btn_id]
		if not is_instance_valid(btn):
			continue
		if btn_id == id:
			t.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.1).set_ease(Tween.EASE_OUT)
			t.tween_property(btn, "modulate", Color(1.2, 1.2, 0.5, 1.0), 0.1)
		else:
			t.tween_property(btn, "modulate", Color(0.4, 0.4, 0.4, 0.5), 0.15)

	t.set_parallel(false)
	t.tween_interval(0.0)
	t.tween_property(level_up_panel, "modulate", Color(1, 1, 1, 0), 0.2).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(level_up_panel, "scale", Vector2(0.8, 0.8), 0.2).set_ease(Tween.EASE_IN)

func _finish_upgrade_chosen() -> void:
	print("UPGRADE: _finish_upgrade_chosen called, paused=", get_tree().paused)
	$"../HUDLayer".process_mode = Node.PROCESS_MODE_INHERIT
	_is_paused = false; Engine.time_scale = 1.0
	if panel_manager.has_method("force_state"):
		panel_manager.force_state("levelup", 3)  # HIDDEN

	if player.has_pending_level_ups():
		# 通知队列系统: levelup 已关闭, 然后立即重新请求（链式处理）
		panel_manager.notify_closed("levelup")
		await get_tree().create_timer(0.2, false, true).timeout
		_show_upgrade_panel()
	else:
		var _ps: int = GameState.State.PLAYING; GameState.set_state(_ps)
		panel_manager.notify_closed("levelup")

func _apply_garbled_text(iterations: int = 20) -> void:
	var labels: Array[Label] = [
		kill_label, wave_label, timer_label,
		mission_title_label, mission_objectives_label
	]
	var player_labels: Array[Label] = [
		player.hp_label, player.stats_label, player.level_label
	]
	for pl in player_labels:
		if pl and is_instance_valid(pl):
			labels.append(pl)

	var saved: Dictionary = {}
	for l in labels:
		if l and is_instance_valid(l):
			saved[l] = l.text

	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	for i in range(iterations):
		t.tween_callback(func():
			for l in labels:
				if l and is_instance_valid(l):
					var txt: String = saved.get(l, l.text)
					l.text = _garbled_string(txt.length())
		)
		t.tween_interval(0.1)

	t.tween_callback(func():
		_recover_text(saved, labels)
	)

func _recover_text(saved: Dictionary, labels: Array) -> void:
	_operator_protocol_active = false
	for l in labels:
		if l and is_instance_valid(l) and saved.has(l):
			l.text = saved[l]
	_update_ui()
	_update_mission_hud()
	player._update_all_ui()

func _garbled_string(length: int) -> String:
	if length <= 0:
		return ""
	var chars := "0123456789@#$%&*ABCDEF"
	var result := ""
	for i in length:
		result += chars[randi() % chars.length()]
	return result

func _on_stage_cleared(cleared_stage_id: int) -> void:
	# 防御波次（DEFEND_ZONE）完成时关闭
	if cleared_stage_id == 3:
		_stop_defend_waves()

	# Stage 5 completion is handled by gate animation — skip screen effects
	if cleared_stage_id < 4:
		CombatFeedback.screen_shake(8.0)
		CombatFeedback.big_hit_stop()

	# Hide direction arrow when stage is cleared
	if _mission_prompt_ui and is_instance_valid(_mission_prompt_ui):
		_mission_prompt_ui.hide_direction_arrow()

	# Stage 1-3: play transition dialogue; Stage 4+: victory sequence or gate
	if cleared_stage_id < 4:
		await _trigger_stage_dialogue(cleared_stage_id)

	# Refresh prompt UI; skip Stage 5 (gate animation replaces it)
	if cleared_stage_id < 5 and _mission_prompt_ui and is_instance_valid(_mission_prompt_ui):
		_refresh_prompt_ui_from_stage()


func _refresh_prompt_ui_from_stage() -> void:
	if _mission_prompt_ui == null or not is_instance_valid(_mission_prompt_ui):
		return
	if _mission_manager == null:
		return
	_mission_prompt_ui.clear_objectives()
	_prev_objective_states.clear()
	var title: String = _mission_manager.get_title()
	if not title.is_empty():
		_mission_prompt_ui.show_stage_activate(title)
	for obj in _mission_manager.get_objectives():
		var obj_id: String = obj.get("id", "")
		if obj_id.is_empty():
			continue
		var desc: String = obj.get("text", "")
		var current: float = float(obj.get("progress", 0))
		var target: float = float(obj.get("target", 1))
		_mission_prompt_ui.show_objective_progress(obj_id, desc, current, target)
		_prev_objective_states[obj_id] = {"current": current, "target": target}

## 弹出 Stage 完成时的过渡对话
## 数据驱动：从 MissionStage.dialogue_messages 读取，不再硬编码
func _trigger_stage_dialogue(cleared_stage_id: int) -> void:
	var dlg: Control = $"../HUDLayer/DialoguePanel"
	if dlg == null or not dlg.has_method("show_dialogue"):
		return

	var msgs: Array[Dictionary] = _get_stage_dialogue_messages(cleared_stage_id)
	if msgs.is_empty():
		return

	# 通过 PanelManager 请求显示对话面板（自动预占低优先级面板）
	panel_manager.request_show("dialogue")
	GameState.set_state(GameState.State.DIALOGUE)
	dlg.show_dialogue(msgs)
	await dlg.dialogue_finished
	panel_manager.notify_closed("dialogue")
	# 对话面板的 _close() 已隐藏面板并发出 dialogue_finished
	panel_manager.notify_closed("dialogue")

	# 检查队列中是否有面板被恢复; 如果没有, 恢复 PLAYING
	if panel_manager.get_active_panel() == "":
		GameState.set_state(GameState.State.PLAYING)
	# 如果有面板被恢复（如 levelup), 其自身生命周期管理 GameState


## 从 MissionManager 的链数据中按 stage_id 读取对话消息
func _get_stage_dialogue_messages(stage_id: int) -> Array[Dictionary]:
	if _mission_manager == null:
		return []
	if not _mission_manager.has_method("get_stage_dialogue"):
		return []
	return _mission_manager.get_stage_dialogue(stage_id)

func _spawn_boss_deferred() -> void:
	# 检查 Boss 是否已生成
	for c in enemies.get_children():
		if c is CharacterBody2D and c.is_boss:
			return
	var e: Enemy = _enemy_scene.instantiate() as Enemy
	e.global_position = Vector2(2900, 700)
	e.is_boss = true
	e.max_health = int(_dungeon_config.s3_boss_hp) if _dungeon_config else 1600
	e.move_speed = 60
	e.contact_damage = 25
	e.score_value = 10
	e.xp_value = 100
	enemies.add_child(e)
	if _boss_hp_bar:
		_boss_hp_bar.set_hp(e._health, e.max_health)
		_boss_hp_bar.enter()
	_boss_fight_active = true
	EventBus.boss_phase_changed.emit(1, "热身")

func _on_boss_approach_started(_boss_id: String) -> void:
	## 第一阶段：登场逼近 — 沉默 + 暗角
	## 实际 Boss 生成由玩家进入 zone_gym_boss 触发
	if _boss_approach_triggered:
		return
	_boss_approach_triggered = true

	# Phase D — 沉默时刻：HUD 阶梯消退
	if _silence_controller and is_instance_valid(_silence_controller):
		_silence_controller.trigger_silence()

	# Phase D — 暗角加剧（沉默时刻）
	if _vignette_controller and is_instance_valid(_vignette_controller):
		_vignette_controller.set_state(VignetteController.State.BOSS_BATTLE)


func _on_player_entered_zone_for_boss(zone_id: String) -> void:
	if zone_id != "zone_gym_boss" or not _boss_approach_triggered or _boss_fight_active or _boss_defeated:
		return
	call_deferred("_spawn_boss_now")

func _spawn_boss_now() -> void:
	# ============================================================
	# 第一步：创建 Boss 实体，暂不可见
	# ============================================================
	var e: Enemy = _enemy_scene.instantiate() as Enemy
	e.global_position = Vector2(2900, 700)
	e.is_boss = true
	e.max_health = _dungeon_config.s3_boss_hp if _dungeon_config else 1600
	e.score_value = 10
	e.xp_value = 100
	e.modulate = Color(1, 1, 1, 0)  # 完全透明 — 从阴影中现身
	e.set_process(false)              # 冻结 AI，出场期间不行动
	e.set_physics_process(false)
	_boss_enemy = e
	enemies.add_child(e)

	# ============================================================
	# 第二步：2s 沉默时刻 — 画面定格 + HUD 消退 + 暗角最深
	# ============================================================
	# 暗角+HUD消退替代时停

	# 暗角拉到最深 (0.9 alpha) — 比战斗时 (0.6) 更深
	if _vignette_controller and is_instance_valid(_vignette_controller):
		UIEffects.kill_group("hud_vignette")
		var vignette_overlay: TextureRect = _vignette_controller.get_node_or_null("VignetteOverlay") as TextureRect
		if vignette_overlay:
			var v_tween: Tween = vignette_overlay.create_tween()
			v_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
			v_tween.tween_property(vignette_overlay, "modulate:a", 0.9, 0.5)

	# HUD 完全消退
	if _silence_controller and is_instance_valid(_silence_controller):
		_silence_controller.trigger_silence()

	# SFX: boss_entrance_rumble (占位)

	# 等待 2s — 沉默时刻的核心 (ignore_time_scale=true)
	await get_tree().create_timer(0.5, false, true).timeout

	# ============================================================
	# 第三步：Boss 从阴影中现身 (modulate.a 0→1, 1.5s)
	# ============================================================
	var appear_tween: Tween = create_tween()
	appear_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	appear_tween.tween_property(e, "modulate", Color.WHITE, 0.8)

	# 暗角从 0.9 回退到战斗水平 0.6
	if _vignette_controller and is_instance_valid(_vignette_controller):
		var vg_delay_tween: Tween = create_tween()
		vg_delay_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
		vg_delay_tween.tween_interval(0.7)
		vg_delay_tween.tween_callback(func():
			if _vignette_controller and is_instance_valid(_vignette_controller):
				_vignette_controller.set_state(VignetteController.State.BOSS_BATTLE, 0.8)
		)

	# ============================================================
	# 第四步：连续震动 — 在 Boss 半现身时触发
	# ============================================================
	await get_tree().create_timer(0.3, false, true).timeout
	CombatFeedback.screen_shake(6.0)

	await get_tree().create_timer(0.3, false, true).timeout
	CombatFeedback.screen_shake(9.0)

	await get_tree().create_timer(0.3, false, true).timeout
	CombatFeedback.screen_shake(12.0)

	# ============================================================
	# 第五步：大字标题 — Boss 名称揭示
	# ============================================================
	var reveal_label := Label.new()
	reveal_label.name = "BossNameReveal"
	reveal_label.text = "三年二班 体育教师 · 佐藤 幸雄"
	reveal_label.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))
	reveal_label.add_theme_font_size_override("font_size", 32)
	reveal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reveal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reveal_label.modulate = Color(1, 1, 1, 0)
	reveal_label.size = get_viewport().get_visible_rect().size
	$"../HUDLayer".add_child(reveal_label)
	reveal_label.z_index = 20

	var reveal_tween: Tween = create_tween()
	reveal_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	reveal_tween.tween_property(reveal_label, "modulate", Color.WHITE, 0.4)
	reveal_tween.tween_interval(1.2)
	reveal_tween.tween_property(reveal_label, "modulate:a", 0.0, 0.5)
	reveal_tween.tween_callback(func():
		if is_instance_valid(reveal_label):
			reveal_label.queue_free()
	)

	# ============================================================
	# 第六步：恢复游戏 — Boss AI 激活，战斗开始
	# ============================================================
	# 确保 Boss 完全可见
	e.modulate = Color.WHITE
	Engine.time_scale = 1.0
	e.set_process(true)
	e.set_physics_process(true)

	# Boss 血条显示
	if _boss_hp_bar and is_instance_valid(_boss_hp_bar):
		_boss_hp_bar.enter()
		_boss_hp_bar.set_hp(e.max_health, e.max_health)

	# 标记 Boss 战激活
	_boss_fight_active = true

	# 沉默结束：HUD 恢复
	if _silence_controller and is_instance_valid(_silence_controller):
		_silence_controller.trigger_restore()

	# 广播 Boss 激活
	EventBus.boss_activated.emit("boss_sato")
	EventBus.boss_phase_changed.emit(1, "热身")

	# Phase 4 — 递增 Boss 遭遇次数（仪式感递减）
	GamePersistence.increment_boss_encounter_count()

func notify_desk() -> void:
	if _mission_manager: _mission_manager.notify_desk()

func _update_ui() -> void:
	if _kill_count != _prev_kill_count:
		_kill_bounce_count += 1
		var peak_scale: float
		if _kill_bounce_count <= UIEffects.BOUNCE_DECAY_THRESHOLD_1:
			peak_scale = UIEffects.BOUNCE_SCALE_PEAK_1
		elif _kill_bounce_count <= UIEffects.BOUNCE_DECAY_THRESHOLD_2:
			peak_scale = UIEffects.BOUNCE_SCALE_PEAK_2
		else:
			peak_scale = UIEffects.BOUNCE_SCALE_PEAK_3
		UIEffects.bounce_with_peak(kill_label, peak_scale)
		_prev_kill_count = _kill_count

	kill_label.text = "击杀: %d" % _kill_count
	wave_label.text = "波次 %d" % _current_wave

func _update_mission_hud() -> void:
	if _mission_manager == null: return
	mission_title_label.text = _mission_manager.get_title()
	var lines: String = ""
	var stage_objectives: Array = _mission_manager.get_objectives()
	for obj in stage_objectives:
		var done: bool = float(obj["progress"]) >= float(obj["target"])
		var mark := "✓" if done else "□"
		var pv = obj["progress"]; var tv = obj["target"]
		var pct: String = ""
		if typeof(pv) == TYPE_FLOAT:
			pct = " (%.0f/%.0fs)" % [float(pv), float(tv)] if not done else ""
		else:
			pct = " (%d/%d)" % [int(pv), int(tv)] if not done else ""
		lines += "%s %s%s\n" % [mark, obj["text"], pct]

		# Push to MissionPromptUI: update or complete objective
		if _mission_prompt_ui and is_instance_valid(_mission_prompt_ui):
			var obj_id: String = obj.get("id", "")
			if obj_id.is_empty():
				continue
			var progress_val: float = float(pv)
			var target_val: float = float(tv)
			if done:
				_mission_prompt_ui.complete_objective(obj_id, obj.get("text", ""))
			else:
				_mission_prompt_ui.show_objective_progress(obj_id, obj.get("text", ""), progress_val, target_val)
			_prev_objective_states[obj_id] = progress_val

	mission_objectives_label.text = lines


## 刷新 Prompt UI：清空后重新加载当前 stage 的所有 objective
	if _mission_prompt_ui == null or not is_instance_valid(_mission_prompt_ui):
		return
	if _mission_manager == null:
		return
	_mission_prompt_ui.clear_objectives()
	_prev_objective_states.clear()

	# 显示当前 stage 的激活提示
	var title: String = _mission_manager.get_title()
	if not title.is_empty():
		_mission_prompt_ui.show_stage_activate(title)

	# 预填所有未完成 objective
	for obj in _mission_manager.get_objectives():
		var obj_id: String = obj.get("id", "")
		if obj_id.is_empty():
			continue
		var pv = obj["progress"]
		var tv = obj["target"]
		var progress_val: float = float(pv)
		var target_val: float = float(tv)
		if float(pv) < float(tv):
			_mission_prompt_ui.show_objective_progress(obj_id, obj.get("text", ""), progress_val, target_val)
		_prev_objective_states[obj_id] = progress_val

	# Stage 1: 显示方向箭头指向庭院
	var stage: int = _mission_manager.get_current_stage()
	match stage:
		1:
			if _mission_prompt_ui.has_method("show_direction_arrow"):
				_mission_prompt_ui.show_direction_arrow(Vector2(2880, 4272))  # 校门
		2:
			if _mission_prompt_ui.has_method("show_direction_arrow"):
				_mission_prompt_ui.show_direction_arrow(Vector2(2880, 3120))  # 教学楼连廊区域
		3:
			if _mission_prompt_ui.has_method("show_direction_arrow"):
				_mission_prompt_ui.show_direction_arrow(Vector2(2640, 3000))  # 走廊驻守区
		4:
			if _mission_prompt_ui.has_method("show_direction_arrow"):
				_mission_prompt_ui.show_direction_arrow(Vector2(2880, 580))   # Boss间
		5:
			if _mission_prompt_ui.has_method("show_direction_arrow"):
				_mission_prompt_ui.show_direction_arrow(Vector2(2880, 4272))  # 校门


func _input(event: InputEvent) -> void:
	if _is_game_over and event.is_action_pressed("move_up"):
		UIEffects.kill_group("panel_gameover")
		_stop_hint_breathing()
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M and _game_started:
			_toggle_map()
		elif event.keycode == KEY_ESCAPE:
			if GameState.current_state == GameState.State.MAP:
				_toggle_map()


func _toggle_map() -> void:
	var mp: Control = $"../HUDLayer/MapPanel"
	if not mp:
		return
	if GameState.current_state != GameState.State.MAP:
		# 生成地图纹理 — ImageTexture方案，120x90像素
		var sm := get_node_or_null("../SchoolMap")
		if sm and sm.has_method("generate_map_texture"):
			var tex: Texture2D = sm.generate_map_texture()
			var tr := mp.get_node("MapTexture") as TextureRect
			if tr and tex:
				tr.texture = tex
				var fog := mp.get_node("FogOverlay") as TextureRect
				if fog:
					fog.texture = sm.generate_fog_texture()  # 初始全迷雾
		_update_map_from_system()
		# SubViewport 方案：用俯视相机渲染关卡到地图面板
		_build_map_viewport(mp)
		var sm2 := get_node_or_null("../SchoolMap")
		if sm2 and sm2.has_method("generate_map_texture"):
			var tex: Texture2D = sm2.generate_map_texture()
			var tr: TextureRect = mp.get_node("MapTexture")
			if tr and tex:
				tr.texture = tex
		var fog: TextureRect = mp.get_node("FogOverlay")
		if fog: fog.visible = false  # 临时禁用迷雾
		_update_map_from_system()
		# 通过 PanelManager 统一管理显示
		_build_map_viewport(mp); _update_map_from_system(); panel_manager.request_show("map")
		GameState.set_state(GameState.State.MAP)
	else:
		GameState.set_state(GameState.State.PLAYING)
		panel_manager.hide("map")
		panel_manager.notify_closed("map")

func _on_player_hit(_damage: int, _current_hp: int) -> void:
	_update_low_hp_overlay()

func _update_low_hp_overlay() -> void:
	if not _low_hp_overlay or not is_instance_valid(_low_hp_overlay):
		return
	if not player or not is_instance_valid(player):
		return
	var pct: float = float(player._health) / float(player.max_health)
	if abs(pct - _last_hp_pct) < 0.01:
		return
	_last_hp_pct = pct

	var target_alpha: float = 0.0
	if pct < 0.3:
		target_alpha = (0.3 - pct) / 0.3 * 0.65

	UIEffects.kill_group("hud_lowhp")
	var t := create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.tween_property(_low_hp_overlay, "modulate:a", target_alpha, 0.3)

func _get_zone_narrative(y_pos: float) -> String:
	if y_pos > 1800: return "\"星期一早上的升旗台。你们班站在第二排。\""
	if y_pos > 1500: return "\"自己的室外鞋还在里面。没人来取过。\""
	if y_pos > 1100: return "\"三年级的公告栏。社团招新海报是去年的日期。\""
	if y_pos > 700: return "\"黑板上的值日生名字，写到一半。\""
	return "\"再往下走，温度越来越低。\""

func _init_map_tex() -> void:
	var ms: Node = $"../HUDLayer/MapSystem"
	var map_tex: Texture2D = null
	var sm := get_node_or_null("../SchoolMap")
	if sm and sm.has_method("generate_map_texture"):
		map_tex = sm.generate_map_texture()
	if ms and ms.has_method("init"): ms.init(player, $"../HUDLayer", map_tex)

func _update_map_from_system() -> void:
	var ms: Node = $"../HUDLayer/MapSystem"
	if ms and ms.has_method("update"): ms.update()

func _get_zone_name(pos: Vector2) -> String:
	var y := pos.y
	if y > 1800: return "操场·校门广场 — 阳光刺眼，曾经升旗的地方"
	if y > 1500: return "教学楼·玄关 — 鞋柜东倒西歪，室内鞋散落一地"
	if y > 1100: return "教学楼·走廊 — 墙上还贴着上学期的手抄报"
	if y > 700: return "教室区域 — 黑板上的粉笔字写到一半..."
	return "Boss间·最深处的体育馆 — 这里曾是全校的骄傲"
func _build_map_viewport(mp: Control) -> void:
	pass  # ImageTexture方案不需要预建ColorRect网格



# =============================================================================
# 防御波次系统（DEFEND_ZONE 激活时）
# =============================================================================

## Stage 激活时回调 — 检测 DEFEND_ZONE 并启动防御波次
func _on_mission_stage_activated(stage_id: int) -> void:
	if stage_id == 3:
		_start_defend_waves()


## 防御波次定时器触发 — 从两侧教室门洞 + 连廊方向生成敌人
func _on_defend_spawn_timer_timeout() -> void:
	if not _defend_wave_active:
		return

	# 左侧教室：2-3 melee
	for i in range(2 + randi() % 2):
		var e: Enemy = _enemy_scene.instantiate() as Enemy
		e.global_position = Vector2(1400 + randf_range(-150, 150), 3100 + randf_range(-150, 150))
		e.max_health = 50
		e.move_speed = 130
		e.contact_damage = 12
		e.score_value = 1
		e.xp_value = 15
		enemies.add_child(e)

	# 右侧教室：2-3 melee
	for i in range(2 + randi() % 2):
		var e: Enemy = _enemy_scene.instantiate() as Enemy
		e.global_position = Vector2(4300 + randf_range(-150, 150), 3100 + randf_range(-150, 150))
		e.max_health = 50
		e.move_speed = 130
		e.contact_damage = 12
		e.score_value = 1
		e.xp_value = 15
		enemies.add_child(e)

	# 连廊方向：1-2 ranged
	for i in range(1 + randi() % 2):
		var e: Enemy = _enemy_scene.instantiate() as Enemy
		e.global_position = Vector2(2800 + randf_range(-100, 100), 2600 + randf_range(-100, 100))
		e.is_ranged = true
		e.max_health = 30
		e.move_speed = 100
		e.ranged_damage = 10
		e.score_value = 2
		e.xp_value = 20
		enemies.add_child(e)


## 启动防御波次生成
func _start_defend_waves() -> void:
	if _defend_wave_active:
		return
	_defend_wave_active = true
	_defend_spawn_timer.start()
	# 立即生成第一波
	_on_defend_spawn_timer_timeout()


## 停止防御波次生成
func _stop_defend_waves() -> void:
	_defend_wave_active = false
	if _defend_spawn_timer and is_instance_valid(_defend_spawn_timer):
		_defend_spawn_timer.stop()


# =============================================================================
# 地图标记
# =============================================================================

func _add_mission_markers_to_map(mp: Control) -> void:
	# 清除旧标记
	for c in mp.get_children():
		if c.name.begins_with("Marker_"):
			c.queue_free()
	if not _mission_manager or not _mission_manager.has_method("get_objectives"):
		return
	var objs: Array = _mission_manager.get_objectives()
	for obj in objs:
		var zone_id: String = obj.get("zone_id", "")
		if zone_id.is_empty():
			continue
		# 查找zone位置
		var zone_pos := _get_zone_position(zone_id)
		if zone_pos == Vector2.ZERO:
			continue
		var rx: float = 800.0 / 5760.0
		var ry: float = 400.0 / 4320.0
		var marker := Label.new()
		marker.name = "Marker_" + zone_id
		marker.text = "▼"
		marker.add_theme_color_override("font_color", Color.GOLD)
		marker.add_theme_font_size_override("font_size", 14)
		marker.position = Vector2(-400 + int(zone_pos.x * rx) - 10, 30 + int(zone_pos.y * ry))
		mp.add_child(marker)

func _get_zone_position(zone_id: String) -> Vector2:
	match zone_id:
		"zone_gate": return Vector2(2880, 4272)
		"zone_gym_entrance": return Vector2(2880, 1200)
		"zone_hallway_defend": return Vector2(2640, 3000)
		"zone_gym_boss": return Vector2(2880, 580)
		"zone_gate_escape": return Vector2(2880, 4176)
	return Vector2.ZERO
