class_name GameManager
extends Node2D

# === 生成 ===
@export var spawn_margin: float = 80.0
@export var base_spawn_interval: float = 1.5
@export var enemies_per_spawn: int = 2
@export var wave_duration: float = 30.0
@export var elite_interval: int = 3

# === 场景 ===
var _enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")

# === 节点 ===
@onready var player: CharacterBody2D = $Player
@onready var spawn_timer: Timer = $SpawnTimer
@onready var wave_timer: Timer = $WaveTimer
@onready var enemies: Node2D = $Enemies

# HUD
@onready var kill_label: Label = $"../HUDLayer/HUD/KillCount"
@onready var wave_label: Label = $"../HUDLayer/HUD/WaveLabel"
@onready var timer_label: Label = $"../HUDLayer/HUD/TimerLabel"
@onready var game_over_panel: Control = $"../HUDLayer/HUD/GameOver"
@onready var final_score_label: Label = $"../HUDLayer/HUD/GameOver/FinalScore"
@onready var level_up_panel: Control = $"../HUDLayer/LevelUpPanel"
@onready var upgrade_buttons: HBoxContainer = $"../HUDLayer/LevelUpPanel/Buttons"
@onready var char_select_panel: Control = $"../HUDLayer/CharSelect"
@onready var char_select_buttons: HBoxContainer = $"../HUDLayer/CharSelect/Buttons"

# === 状态 ===
var _kill_count: int = 0
var _current_wave: int = 1
var _wave_elapsed: float = 0.0
var _is_game_over: bool = false
var _is_paused: bool = false
var _screen_size: Vector2
var _game_started: bool = false
var _difficulty_scale: float = 1.3

func _ready() -> void:
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
	$"../HUDLayer".process_mode = Node.PROCESS_MODE_ALWAYS

	for child in char_select_buttons.get_children():
		child.queue_free()

	var presets := SkillManager.PRESETS
	for key in presets:
		var data: Dictionary = presets[key]
		var btn := Button.new()
		btn.text = "%s\n%s" % [data["name"], data["desc"]]
		btn.custom_minimum_size = Vector2(170, 100)
		var c: Color = data["color"]
		btn.pressed.connect(func(): _on_preset_selected(key))

		var s := _make_button_style(c)
		btn.add_theme_stylebox_override("normal", s)
		var h := s.duplicate() as StyleBoxFlat
		h.bg_color = c.darkened(0.3)
		h.border_color = c.lightened(0.3)
		btn.add_theme_stylebox_override("hover", h)
		char_select_buttons.add_child(btn)

func _make_button_style(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.12, 0.2, 1.0)
	s.border_width_left = 2; s.border_width_right = 2
	s.border_width_top = 2; s.border_width_bottom = 2
	s.border_color = c
	s.corner_radius_top_left = 8; s.corner_radius_top_right = 8
	s.corner_radius_bottom_left = 8; s.corner_radius_bottom_right = 8
	return s

func _on_preset_selected(preset: String) -> void:
	char_select_panel.visible = false
	$"../HUDLayer".process_mode = Node.PROCESS_MODE_INHERIT
	_is_paused = false
	player.init_skills(preset)

func _on_game_start(_preset: String) -> void:
	_game_started = true
	spawn_timer.wait_time = base_spawn_interval
	spawn_timer.start()
	wave_timer.wait_time = wave_duration
	wave_timer.start()
	_update_ui()

func _process(delta: float) -> void:
	if _is_game_over or _is_paused or not _game_started:
		return
	_wave_elapsed += delta
	timer_label.text = "剩余: %.0fs" % maxf(wave_duration - _wave_elapsed, 0.0)

func _on_spawn_timer_timeout() -> void:
	if _is_game_over or not _game_started:
		return

	var count := enemies_per_spawn + int(_current_wave * 0.5)
	var is_elite_wave := (_current_wave % elite_interval == 0)

	for i in count:
		_spawn_enemy(i == 0 and is_elite_wave)

	if _current_wave >= 2:
		for i in max(int(_current_wave / 3), 1):
			_spawn_ranged_enemy()

func _spawn_enemy(as_elite: bool = false) -> void:
	var e: CharacterBody2D = _enemy_scene.instantiate()
	e.global_position = _random_spawn_position()
	var m: float = 1.0 + (_current_wave - 1) * 0.2

	if as_elite:
		e.is_elite = true
		e.max_health = int(30 * m * 3)
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
	e.is_ranged = true
	e.max_health = int(25 * m)
	e.move_speed = 100 + _current_wave * 4
	e.score_value = 2; e.xp_value = 20
	e.ranged_damage = int(10 * m)
	e.ranged_cooldown = maxf(2.5 - _current_wave * 0.1, 0.8)

	var sp: ColorRect = e.get_node("Sprite")
	if sp: sp.color = Color(0.2, 0.8, 0.3)
	enemies.add_child(e)

func _random_spawn_position() -> Vector2:
	var side := randi() % 4
	var x := _screen_size.x; var y := _screen_size.y
	match side:
		0: return Vector2(randf_range(0, x), -spawn_margin)
		1: return Vector2(randf_range(0, x), y + spawn_margin)
		2: return Vector2(-spawn_margin, randf_range(0, y))
		_: return Vector2(x + spawn_margin, randf_range(0, y))

func _on_enemy_killed(_pos: Vector2, score: int) -> void:
	if score > 0:
		_kill_count += score
		if player.has_method("gain_exp"):
			player.gain_exp(15 if score == 1 else (40 if score == 5 else score * 8))
	_update_ui()

func _on_player_died() -> void:
	_is_game_over = true
	spawn_timer.stop(); wave_timer.stop()
	game_over_panel.visible = true
	final_score_label.text = "击杀: %d\n波次: %d\nLv: %d" % [_kill_count, _current_wave, player.level]

func _on_wave_timer_timeout() -> void:
	_current_wave += 1; _wave_elapsed = 0.0
	spawn_timer.wait_time = maxf(base_spawn_interval / pow(_difficulty_scale, _current_wave - 1), 0.3)
	enemies_per_spawn += 1
	EventBus.wave_changed.emit(_current_wave)
	_update_ui()

# === 升级 ===
func _on_level_up_available(_count: int) -> void:
	_show_upgrade_panel()

func _show_upgrade_panel() -> void:
	_is_paused = true; get_tree().paused = true
	$"../HUDLayer".process_mode = Node.PROCESS_MODE_ALWAYS
	level_up_panel.visible = true

	for child in upgrade_buttons.get_children():
		child.queue_free()

	var pool: Array = player.skill_manager.get_upgrade_pool()
	pool.shuffle()
	var n: int = mini(pool.size(), 3)

	for i in n:
		var opt: Dictionary = pool[i]
		var btn := Button.new()
		btn.text = "%s %s\n%s" % [opt.icon, opt.name, opt.desc]
		btn.custom_minimum_size = Vector2(180, 80)
		btn.pressed.connect(func(): _on_upgrade_chosen(opt.id))

		var s := _make_button_style(Color(0.5, 0.4, 0.1))
		btn.add_theme_stylebox_override("normal", s)
		var h := s.duplicate() as StyleBoxFlat
		h.bg_color = Color(0.25, 0.25, 0.35); h.border_color = Color(0.8, 0.6, 0.1)
		btn.add_theme_stylebox_override("hover", h)
		upgrade_buttons.add_child(btn)

func _on_upgrade_chosen(id: String) -> void:
	player.apply_upgrade(id)
	level_up_panel.visible = false
	$"../HUDLayer".process_mode = Node.PROCESS_MODE_INHERIT
	_is_paused = false; get_tree().paused = false

	if player._pending_level_ups > 0:
		await get_tree().create_timer(0.2).timeout
		_show_upgrade_panel()

func _update_ui() -> void:
	kill_label.text = "击杀: %d" % _kill_count
	wave_label.text = "波次 %d" % _current_wave

func _input(event: InputEvent) -> void:
	if _is_game_over and event.is_action_pressed("move_up"):
		get_tree().paused = false
		get_tree().reload_current_scene()
