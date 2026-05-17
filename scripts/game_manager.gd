class_name GameManager
extends Node2D

# === 生成属性 ===
@export var spawn_margin: float = 80.0
@export var base_spawn_interval: float = 1.5
@export var enemies_per_spawn: int = 2
@export var wave_duration: float = 30.0
@export var difficulty_scale: float = 1.3
@export var elite_interval: int = 3

# === 场景 ===
var _enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")

# === 节点 ===
@onready var player: CharacterBody2D = $Player
@onready var spawn_timer: Timer = $SpawnTimer
@onready var wave_timer: Timer = $WaveTimer
@onready var enemies_container: Node2D = $Enemies
@onready var projectiles_container: Node2D = $Projectiles

# HUD (CanvasLayer)
@onready var kill_label: Label = $"../HUDLayer/HUD/KillCount"
@onready var wave_label: Label = $"../HUDLayer/HUD/WaveLabel"
@onready var timer_label: Label = $"../HUDLayer/HUD/TimerLabel"
@onready var game_over_panel: Control = $"../HUDLayer/HUD/GameOver"
@onready var final_score_label: Label = $"../HUDLayer/HUD/GameOver/FinalScore"
@onready var level_up_panel: Control = $"../HUDLayer/LevelUpPanel"
@onready var upgrade_buttons: HBoxContainer = $"../HUDLayer/LevelUpPanel/Buttons"

# === 变量 ===
var _kill_count: int = 0
var _current_wave: int = 1
var _wave_elapsed: float = 0.0
var _is_game_over: bool = false
var _is_paused: bool = false
var _screen_size: Vector2

func _ready() -> void:
	_screen_size = get_viewport().get_visible_rect().size
	spawn_timer.wait_time = base_spawn_interval
	spawn_timer.start()
	wave_timer.wait_time = wave_duration
	wave_timer.start()

	game_over_panel.visible = false
	level_up_panel.visible = false

	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.player_died.connect(_on_player_died)

	if player.has_signal("level_up_available"):
		player.level_up_available.connect(_on_level_up_available)

	_update_ui()

func _process(delta: float) -> void:
	if _is_game_over or _is_paused:
		return
	_wave_elapsed += delta
	var remaining: float = maxf(wave_duration - _wave_elapsed, 0.0)
	timer_label.text = "剩余: %.0fs" % remaining

func _on_spawn_timer_timeout() -> void:
	if _is_game_over:
		return

	var count := enemies_per_spawn + int(_current_wave * 0.5)
	var is_elite_wave := (_current_wave % elite_interval == 0)

	for i in count:
		_spawn_enemy(i == 0 and is_elite_wave)

	if _current_wave >= 2:
		var ranged_count: int = max(int(_current_wave / 3), 1)
		for i in ranged_count:
			_spawn_ranged_enemy()

func _spawn_enemy(as_elite: bool = false) -> void:
	var enemy: CharacterBody2D = _enemy_scene.instantiate()
	enemy.global_position = _random_spawn_position()

	var wave_mult: float = 1.0 + (_current_wave - 1) * 0.2

	if as_elite:
		enemy.is_elite = true
		enemy.max_health = int(30 * wave_mult * 3)
		enemy.move_speed = 120 + _current_wave * 8
		enemy.contact_damage = int(10 * wave_mult * 2)
		enemy.score_value = 5
		enemy.xp_value = 40
	else:
		enemy.max_health = int(enemy.max_health * wave_mult)
		enemy.move_speed += _current_wave * 6
		enemy.contact_damage = int(enemy.contact_damage * wave_mult)

	enemies_container.add_child(enemy)

func _spawn_ranged_enemy() -> void:
	var enemy: CharacterBody2D = _enemy_scene.instantiate()
	enemy.global_position = _random_spawn_position()

	var wave_mult: float = 1.0 + (_current_wave - 1) * 0.2
	enemy.is_ranged = true
	enemy.max_health = int(20 * wave_mult)
	enemy.move_speed = 100 + _current_wave * 4
	enemy.score_value = 2
	enemy.xp_value = 20
	enemy.ranged_damage = int(10 * wave_mult)
	enemy.ranged_cooldown = maxf(2.5 - _current_wave * 0.1, 0.8)

	# 绿色外观
	var sprite: ColorRect = enemy.get_node("Sprite")
	if sprite:
		sprite.color = Color(0.2, 0.8, 0.3, 1.0)

	enemies_container.add_child(enemy)

func _random_spawn_position() -> Vector2:
	var side := randi() % 4
	match side:
		0: return Vector2(randf_range(0, _screen_size.x), -spawn_margin)
		1: return Vector2(randf_range(0, _screen_size.x), _screen_size.y + spawn_margin)
		2: return Vector2(-spawn_margin, randf_range(0, _screen_size.y))
		_: return Vector2(_screen_size.x + spawn_margin, randf_range(0, _screen_size.y))

func _on_enemy_killed(_pos: Vector2, score: int) -> void:
	if score > 0:
		_kill_count += score
		if player.has_method("gain_exp"):
			var exp_gain: int = 15 if score == 1 else (40 if score == 5 else score * 8)
			player.gain_exp(exp_gain)
	_update_ui()

func _on_player_died() -> void:
	_is_game_over = true
	spawn_timer.stop()
	wave_timer.stop()

	game_over_panel.visible = true
	final_score_label.text = "击杀数: %d\n存活波次: %d\n等级: %d" % [_kill_count, _current_wave, player.level]

func _on_wave_timer_timeout() -> void:
	_current_wave += 1
	_wave_elapsed = 0.0
	spawn_timer.wait_time = maxf(base_spawn_interval / pow(difficulty_scale, _current_wave - 1), 0.3)
	enemies_per_spawn += 1
	EventBus.wave_changed.emit(_current_wave)
	_update_ui()

# === 升级选择 ===
func _on_level_up_available(_count: int) -> void:
	_show_level_up_choices()

func _show_level_up_choices() -> void:
	_is_paused = true
	get_tree().paused = true
	# 让升级面板不受暂停影响，按钮可点击
	$"../HUDLayer".process_mode = Node.PROCESS_MODE_ALWAYS

	level_up_panel.visible = true

	# 清除旧按钮
	for child in upgrade_buttons.get_children():
		child.queue_free()

	var pool: Array = player.get_upgrade_pool()
	pool.shuffle()

	var count: int = mini(pool.size(), 3)
	for i in count:
		var opt: Dictionary = pool[i]
		var btn := Button.new()
		btn.text = "%s %s\n%s" % [opt.icon, opt.name, opt.desc]
		btn.custom_minimum_size = Vector2(180, 80)
		btn.pressed.connect(func(): _on_upgrade_chosen(opt.id))

		# 按钮样式
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.15, 0.25, 1.0)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.5, 0.4, 0.1, 1.0)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override("normal", style)

		var hover := style.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.25, 0.25, 0.35, 1.0)
		hover.border_color = Color(0.8, 0.6, 0.1, 1.0)
		btn.add_theme_stylebox_override("hover", hover)

		upgrade_buttons.add_child(btn)

func _on_upgrade_chosen(upgrade_id: String) -> void:
	player.apply_upgrade(upgrade_id)

	level_up_panel.visible = false
	_is_paused = false
	$"../HUDLayer".process_mode = Node.PROCESS_MODE_INHERIT
	get_tree().paused = false

	if player._pending_level_ups > 0:
		await get_tree().create_timer(0.2).timeout
		_show_level_up_choices()

func _update_ui() -> void:
	kill_label.text = "击杀: %d" % _kill_count
	wave_label.text = "波次 %d" % _current_wave

func _input(event: InputEvent) -> void:
	if _is_game_over and event.is_action_pressed("move_up"):
		get_tree().paused = false
		_restart()

func _restart() -> void:
	get_tree().reload_current_scene()
