class_name GameManager
extends Node2D

const _MissionManagerScript = preload("res://scripts/mission_manager.gd")

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
var sel_wp: String = "sword"
var sel_talents: Array = []
var wp_btns: Dictionary = {}
var talent_btns: Dictionary = {}
var preview_vbox: VBoxContainer
var confirm_btn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停时仍能接收M键/ESC
	add_to_group("game_manager")
	_screen_size = get_viewport().get_visible_rect().size
	game_over_panel.visible = false
	level_up_panel.visible = false
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.player_died.connect(_on_player_died)
	if player.has_signal("level_up_available"):
		player.level_up_available.connect(_on_level_up_available)
	if player.has_signal("preset_chosen"):
		player.preset_chosen.connect(_on_game_start)
	_show_char_select()

func _show_char_select() -> void:
	char_select_panel.visible = true
	_is_paused = true
	GameState.set_state(GameState.State.CHAR_SELECT)
	$"../HUDLayer".process_mode = Node.PROCESS_MODE_ALWAYS

	# 移除旧的叙事文本避免重叠
	var old_n := $"../HUDLayer/CharSelect".get_node_or_null("Narrative")
	if old_n: old_n.queue_free()

	var narrative := Label.new()
	narrative.name = "Narrative"
	narrative.text = "\"那一天，所有人都觉醒了天赋。\n而我，只有D级的——天赋适应。\""
	narrative.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	narrative.add_theme_font_size_override("font_size", 14)
	narrative.add_theme_color_override("font_color", Color(0.65, 0.6, 0.45, 1.0))
	narrative.anchor_left = 0.5; narrative.anchor_right = 0.5
	narrative.offset_left = -350; narrative.offset_top = 130
	narrative.offset_right = 350; narrative.offset_bottom = 170
	$"../HUDLayer/CharSelect".add_child(narrative)

	for child in char_select_buttons.get_children():
		child.queue_free()

	sel_wp = "sword"
	sel_talents.clear()
	wp_btns.clear()
	talent_btns.clear()

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	char_select_buttons.add_child(root)

	# 左: 武器
	var wp_vbox := _mk_zone("武器", Color(0.3, 0.5, 0.8, 1.0))
	root.add_child(wp_vbox)
	for key in SkillManager.WEAPON_POOL:
		var d: Dictionary = SkillManager.WEAPON_POOL[key]
		var wk: String = key
		var b := _mk_btn("weapon_" + wk, d["name"], d["desc"], Color(0.3, 0.5, 0.8, 1.0))
		b.pressed.connect(func(): sel_wp = wk; _refresh_preview())
		wp_vbox.add_child(b)
		wp_btns[wk] = b

	# 中: 天赋池 (9个技能用ScrollContainer)
	var tp_vbox := _mk_zone("天赋 (选3)", Color(0.8, 0.6, 0.2, 1.0))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(190, 280)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var tp_grid := GridContainer.new()
	tp_grid.columns = 1
	tp_grid.add_theme_constant_override("v_separation", 3)
	scroll.add_child(tp_grid)
	tp_vbox.add_child(scroll)
	root.add_child(tp_vbox)
	for key in SkillManager.TALENT_POOL:
		var d: Dictionary = SkillManager.TALENT_POOL[key]
		var tk: String = key
		var b := _mk_btn("icon_" + tk, d["name"], d["desc"], d["color"])
		b.custom_minimum_size = Vector2(175, 42)
		b.pressed.connect(func(): _toggle_talent(tk, b))
		talent_btns[tk] = b
		tp_grid.add_child(b)

	# 右: 预览
	preview_vbox = _mk_zone("已选", Color(0.3, 0.8, 0.3, 1.0))
	root.add_child(preview_vbox)

	confirm_btn = Button.new()
	confirm_btn.text = "踏入试炼"
	confirm_btn.custom_minimum_size = Vector2(280, 48)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.15, 0.1, 0.02, 1.0)
	cs.border_width_left = 2; cs.border_width_right = 2
	cs.border_width_top = 2; cs.border_width_bottom = 2
	cs.border_color = Color(0.8, 0.6, 0.1, 0.6)
	cs.corner_radius_top_left = 4; cs.corner_radius_top_right = 4
	cs.corner_radius_bottom_left = 4; cs.corner_radius_bottom_right = 4
	cs.content_margin_left = 12; cs.content_margin_right = 12
	confirm_btn.add_theme_stylebox_override("normal", cs)
	confirm_btn.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2, 1.0))
	confirm_btn.add_theme_font_size_override("font_size", 16)
	confirm_btn.pressed.connect(_try_start)
	char_select_buttons.add_child(confirm_btn)
	_refresh_preview()

func _mk_zone(title: String, color: Color) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.custom_minimum_size = Vector2(175, 0)
	var l := Label.new(); l.text = title
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l)
	return vb

func _mk_btn(icon_key: String, title: String, desc: String, color: Color) -> Button:
	var b := Button.new()
	b.icon = AssetLoader.texture(icon_key, 48, color)
	b.text = title + "\n" + desc
	b.custom_minimum_size = Vector2(170, 55)
	b.expand_icon = true
	var s := _mk_style(color); b.add_theme_stylebox_override("normal", s)
	return b

func _mk_style(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.08, 0.16, 1.0)
	s.border_width_left = 1; s.border_width_right = 1
	s.border_width_top = 1; s.border_width_bottom = 1
	s.border_color = Color(c.r, c.g, c.b, 0.3)
	s.corner_radius_top_left = 4; s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4; s.corner_radius_bottom_right = 4
	s.content_margin_left = 6; s.content_margin_right = 6
	s.content_margin_top = 4; s.content_margin_bottom = 4
	return s

func _toggle_talent(key: String, btn: Button) -> void:
	if key in sel_talents:
		sel_talents.erase(key)
		btn.modulate = Color.WHITE
		var s := _mk_style(SkillManager.TALENT_POOL[key]["color"])
		btn.add_theme_stylebox_override("normal", s)
	else:
		if sel_talents.size() >= 3: return
		sel_talents.append(key)
		btn.modulate = Color(0.5, 1.0, 0.5, 1.0)
		# 选中高亮边框
		var h := _mk_style(SkillManager.TALENT_POOL[key]["color"])
		h.border_color = Color.GREEN
		h.border_width_left = 2; h.border_width_right = 2
		h.border_width_top = 2; h.border_width_bottom = 2
		btn.add_theme_stylebox_override("normal", h)
	_refresh_preview()

func _refresh_preview() -> void:
	if preview_vbox == null: return
	for child in preview_vbox.get_children():
		if child is Label and child.text != "": child.queue_free()

	# 更新武器按钮高亮
	_update_weapon_highlight()

	var wp: Dictionary = SkillManager.WEAPON_POOL[sel_wp]
	var wl := Label.new(); wl.text = "武器: %s %s" % [wp["icon"], wp["name"]]
	wl.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0, 1.0))
	preview_vbox.add_child(wl)

func _update_weapon_highlight() -> void:
	for wk in wp_btns:
		wp_btns[wk].modulate = Color.GREEN if wk == sel_wp else Color.WHITE
	var tl := Label.new(); tl.text = "天赋: %d/3" % sel_talents.size()
	preview_vbox.add_child(tl)
	for tid in sel_talents:
		var td: Dictionary = SkillManager.TALENT_POOL[tid]
		var l := Label.new(); l.text = "  %s %s" % [td["icon"], td["name"]]
		l.add_theme_color_override("font_color", td["color"])
		preview_vbox.add_child(l)
	if confirm_btn:
		var ready := sel_talents.size() == 3
		confirm_btn.text = "踏入试炼" if ready else "选择天赋 (%d/3)" % sel_talents.size()
		confirm_btn.disabled = not ready
		if ready:
			var cs2 := confirm_btn.get_theme_stylebox("normal", "").duplicate() as StyleBoxFlat
			cs2.border_color = Color.GREEN
			confirm_btn.add_theme_stylebox_override("normal", cs2)

func _try_start() -> void:
	if sel_talents.size() != 3: return
	char_select_panel.visible = false
	$"../HUDLayer".process_mode = Node.PROCESS_MODE_INHERIT
	_is_paused = false
	player.init_skills(sel_talents.duplicate(), sel_wp)

func _on_game_start(_preset: String) -> void:
	var ms: Node = $"../HUDLayer/MapSystem"; if ms and ms.has_method("init"): ms.init(player, $"../HUDLayer")
	_game_started = true
	_mission_manager = _MissionManagerScript.new()
	_mission_manager.init()
	_mission_manager.stage_cleared.connect(_on_stage_cleared)
	_mission_manager.boss_spawned.connect(_on_boss_spawn)
	add_child(_mission_manager)
	_update_mission_hud()
	

	spawn_timer.wait_time = base_spawn_interval; spawn_timer.start()
	wave_timer.wait_time = wave_duration; wave_timer.start()
	_update_ui()

func _process(delta: float) -> void:
	if _is_game_over or _is_paused or not _game_started: return
	_wave_elapsed += delta
	timer_label.text = "剩余: %.0fs" % maxf(wave_duration - _wave_elapsed, 0.0)
	if _mission_manager:
		_update_mission_hud()


func _on_spawn_timer_timeout() -> void:
	if _is_game_over or not _game_started: return
	var count := enemies_per_spawn + int(_current_wave * 0.5)
	var is_elite_wave := (_current_wave % elite_interval == 0)
	for i in count: _spawn_enemy(i == 0 and is_elite_wave)
	if _current_wave >= 2:
		for i in max(int(float(_current_wave) / 3.0), 1): _spawn_ranged_enemy()

func _spawn_enemy(as_elite: bool = false) -> void:
	var e: CharacterBody2D = _enemy_scene.instantiate()
	e.global_position = _random_spawn_position()
	var m: float = 1.0 + (_current_wave - 1) * 0.2
	if as_elite:
		e.is_elite = true; e.max_health = int(30 * m * 3)
		e.move_speed = 120 + _current_wave * 8
		e.contact_damage = int(10 * m * 2)
		e.score_value = 5; e.xp_value = 40
	else:
		e.max_health = int(e.max_health * m)
		e.move_speed += _current_wave * 6
		e.contact_damage = int(e.contact_damage * m)
	enemies.add_child(e)

func _spawn_ranged_enemy() -> void:
	var e: CharacterBody2D = _enemy_scene.instantiate()
	e.global_position = _random_spawn_position()
	var m: float = 1.0 + (_current_wave - 1) * 0.2
	e.is_ranged = true; e.max_health = int(25 * m)
	e.move_speed = 100 + _current_wave * 4
	e.score_value = 2; e.xp_value = 20
	e.ranged_damage = int(10 * m)
	e.ranged_cooldown = maxf(2.5 - _current_wave * 0.1, 0.8)
	var sp: ColorRect = e.get_node("Sprite")
	if sp: sp.color = Color(0.2, 0.8, 0.3, 1.0)
	enemies.add_child(e)

func _random_spawn_position() -> Vector2:
	# 根据任务阶段决定生成区域
	var stage: int = _mission_manager.get_current_stage() if _mission_manager else 1
	var center := player.global_position if player else Vector2(1600, 2200)
	var nav: Node = get_node_or_null("../NavManager")

	# 阶段1: 校门→主干道(南部)
	if stage == 1:
		var y_range := Vector2(1800, 2200)  # 下半区
		center = Vector2(randf_range(800, 2400), randf_range(y_range.x, y_range.y))
	# 阶段2: 教学楼区域(中部)
	elif stage == 2:
		var side := randi() % 2
		if side == 0: center = Vector2(randf_range(400, 1400), randf_range(800, 1600))  # 左楼
		else: center = Vector2(randf_range(1800, 2800), randf_range(800, 1600))  # 右楼
	# 阶段3: 连廊→体育馆方向(北部)
	elif stage >= 3:
		center = Vector2(randf_range(1200, 2000), randf_range(300, 1000))

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


func _on_player_died() -> void:
	_is_game_over = true; spawn_timer.stop(); wave_timer.stop()
	game_over_panel.visible = true
	final_score_label.text = "击杀: %d\n波次: %d\nLv: %d" % [_kill_count, _current_wave, player.level]

func _on_wave_timer_timeout() -> void:
	_current_wave += 1; _wave_elapsed = 0.0
	spawn_timer.wait_time = maxf(base_spawn_interval / pow(_difficulty_scale, _current_wave - 1), 0.3)
	enemies_per_spawn += 1
	EventBus.wave_changed.emit(_current_wave); _update_ui()

func _on_level_up_available(_count: int) -> void:
	_show_upgrade_panel()

func _show_upgrade_panel() -> void:
	_is_paused = true; get_tree().paused = true
	GameState.set_state(GameState.State.PAUSED)
	$"../HUDLayer".process_mode = Node.PROCESS_MODE_ALWAYS
	level_up_panel.visible = true
	for child in upgrade_buttons.get_children(): child.queue_free()
	var pool: Array = player.skill_manager.get_upgrade_pool()
	pool.shuffle(); var n: int = mini(pool.size(), 3)
	for i in n:
		var opt: Dictionary = pool[i]
		var btn := Button.new()
		btn.text = "%s %s\n%s" % [opt.icon, opt.name, opt.desc]
		btn.custom_minimum_size = Vector2(180, 80)
		var oid: String = opt.id; btn.pressed.connect(func(): _on_upgrade_chosen(oid))
		var s := _mk_style(Color(0.5, 0.4, 0.1, 1.0))
		btn.add_theme_stylebox_override("normal", s)
		var h := s.duplicate() as StyleBoxFlat
		h.bg_color = Color(0.25, 0.25, 0.35, 1.0); h.border_color = Color(0.8, 0.6, 0.1, 1.0)
		btn.add_theme_stylebox_override("hover", h)
		upgrade_buttons.add_child(btn)

func _on_upgrade_chosen(id: String) -> void:
	player.apply_upgrade(id)
	level_up_panel.visible = false
	$"../HUDLayer".process_mode = Node.PROCESS_MODE_INHERIT
	_is_paused = false; get_tree().paused = false
	GameState.set_state(GameState.State.PLAYING)
	if player._pending_level_ups > 0:
		await get_tree().create_timer(0.2).timeout
		_show_upgrade_panel()

func _on_stage_cleared(_stage: int) -> void:
	CombatFeedback.screen_shake(8.0); CombatFeedback.big_hit_stop()
	_trigger_stage_dialogue(_stage)

func _trigger_stage_dialogue(stage: int) -> void:
	var dlg: Control = $"../HUDLayer/DialoguePanel"
	var msgs: Array[Dictionary] = []
	match stage:
		1:
			msgs = [
				{"speaker": "主角", "text": "30秒...我活下来了。这些怪物从哪来的？"},
				{"speaker": "系统", "text": "【天赋适应】已激活。检测到可用天赋槽位。"},
			]
		2:
			msgs = [
				{"speaker": "主角", "text": "教室里还有课桌...学生们去哪了？"},
				{"speaker": "系统", "text": "任务更新: 清理教室。每张课桌都是一段记忆。"},
			]
		_:
			return
	if dlg and dlg.has_method("show_dialogue"):
		get_tree().paused = true
		dlg.show_dialogue(msgs)
		await dlg.dialogue_finished
		get_tree().paused = false

func _on_boss_spawn(_boss_name: String) -> void:
	# 陶德: Boss出场叙事
	var dlg: Control = $"../HUDLayer/DialoguePanel"
	var msgs: Array[Dictionary] = [
		{"speaker": "主角", "text": "地面在震动...那是什么东西？！"},
		{"speaker": "???", "text": "一个巨大的变异体堵在操场中央。它曾经是这里的体育老师。"},
	]
	if dlg and dlg.has_method("show_dialogue"):
		get_tree().paused = true
		dlg.show_dialogue(msgs)
		await dlg.dialogue_finished
		get_tree().paused = false

	var e: CharacterBody2D = _enemy_scene.instantiate()
	e.global_position = Vector2(1600, 1800)
	e.is_boss = true; e.max_health = 500; e.move_speed = 60
	e.contact_damage = 25; e.score_value = 10; e.xp_value = 100
	e.ranged_damage = 20; e.ranged_cooldown = 3.0; e.is_ranged = true
	enemies.add_child(e)

func notify_desk() -> void:
	if _mission_manager: _mission_manager.notify_desk()

func _update_ui() -> void:
	kill_label.text = "击杀: %d" % _kill_count
	wave_label.text = "波次 %d" % _current_wave

func _update_mission_hud() -> void:

	if _mission_manager == null: return
	mission_title_label.text = _mission_manager.get_title()
	var lines: String = ""
	for obj in _mission_manager.get_objectives():
		var done: bool = float(obj["progress"]) >= float(obj["target"])
		var mark := "✓" if done else "□"
		var pv = obj["progress"]; var tv = obj["target"]
		var pct: String = ""
		if typeof(pv) == TYPE_FLOAT:
			pct = " (%.0f/%.0fs)" % [float(pv), float(tv)] if not done else ""
		else:
			pct = " (%d/%d)" % [int(pv), int(tv)] if not done else ""
		lines += "%s %s%s\n" % [mark, obj["text"], pct]
	mission_objectives_label.text = lines

func _input(event: InputEvent) -> void:
	if _is_game_over and event.is_action_pressed("move_up"):
		get_tree().paused = false; get_tree().reload_current_scene()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M and _game_started:
			GameState.toggle_map()
			var mp: Control = $"../HUDLayer/MapPanel"
			if mp:
				mp.visible = (GameState.current_state == GameState.State.MAP)
				if mp.visible: _update_map_from_system()
		elif event.keycode == KEY_ESCAPE:
			if GameState.current_state == GameState.State.MAP:
				GameState.set_state(GameState.State.PLAYING)
				$"../HUDLayer/MapPanel".visible = false

func _toggle_map() -> void:
	var mp: Control = $"../HUDLayer/MapPanel"
	if mp:
		mp.visible = not mp.visible
		if mp.visible:
			_update_map_from_system()

func _get_zone_narrative(y_pos: float) -> String:
	if y_pos > 1800: return "\"这里是起点。也是终点。\""
	if y_pos > 1500: return "\"鞋柜里还贴着去年的运动会照片。\""
	if y_pos > 1100: return "\"走廊的灯光忽明忽暗。有什么在尽头。\""
	if y_pos > 700: return "\"课桌上的涂鸦是最后的留言。\""
	return "\"体温从这里开始下降。\""

func _init_map_tex() -> void:
	var ms: Node = $"../HUDLayer/MapSystem"
	if ms and ms.has_method("init"): ms.init(player, $"../HUDLayer")

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
