class_name GameManager
extends Node2D

# === 属性 ===
@export var spawn_margin: float = 80.0
@export var base_spawn_interval: float = 1.5
@export var enemies_per_spawn: int = 2
@export var wave_duration: float = 30.0
@export var difficulty_scale: float = 1.3

# === 场景引用 ===
var _enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")

# === 节点引用 ===
@onready var player: CharacterBody2D = $Player
@onready var spawn_timer: Timer = $SpawnTimer
@onready var wave_timer: Timer = $WaveTimer
@onready var enemies_container: Node2D = $Enemies

# UI (在Main场景根下)
@onready var kill_label: Label = $"../UI/KillCount"
@onready var wave_label: Label = $"../UI/WaveLabel"
@onready var game_over_panel: Control = $"../UI/GameOver"
@onready var final_score_label: Label = $"../UI/GameOver/FinalScore"
@onready var restart_label: Label = $"../UI/GameOver/RestartHint"

# === 变量 ===
var _kill_count: int = 0
var _current_wave: int = 1
var _wave_elapsed: float = 0.0
var _is_game_over: bool = false
var _screen_size: Vector2

func _ready() -> void:
	_screen_size = get_viewport().get_visible_rect().size

	# 初始化
	spawn_timer.wait_time = base_spawn_interval
	spawn_timer.start()
	wave_timer.wait_time = wave_duration
	wave_timer.start()

	game_over_panel.visible = false
	_update_ui()

	# 事件监听
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.player_died.connect(_on_player_died)

func _on_spawn_timer_timeout() -> void:
	if _is_game_over:
		return

	var count := enemies_per_spawn + int(_current_wave * 0.5)
	for i in count:
		_spawn_enemy()

func _spawn_enemy() -> void:
	var enemy: CharacterBody2D = _enemy_scene.instantiate()
	enemy.global_position = _random_spawn_position()

	# 难度缩放
	var wave_mult: float = 1.0 + (_current_wave - 1) * 0.2
	enemy.max_health = int(enemy.max_health * wave_mult)
	enemy.move_speed += _current_wave * 8
	enemy.contact_damage = int(enemy.contact_damage * wave_mult)

	enemies_container.add_child(enemy)

func _random_spawn_position() -> Vector2:
	var side := randi() % 4
	var pos := Vector2.ZERO
	match side:
		0: pos = Vector2(randf_range(0, _screen_size.x), -spawn_margin)  # 上
		1: pos = Vector2(randf_range(0, _screen_size.x), _screen_size.y + spawn_margin)  # 下
		2: pos = Vector2(-spawn_margin, randf_range(0, _screen_size.y))  # 左
		3: pos = Vector2(_screen_size.x + spawn_margin, randf_range(0, _screen_size.y))  # 右
	return pos

func _on_enemy_killed(_pos: Vector2, score: int) -> void:
	_kill_count += score
	_update_ui()

func _on_player_died() -> void:
	_is_game_over = true
	spawn_timer.stop()
	wave_timer.stop()

	game_over_panel.visible = true
	final_score_label.text = "击杀数: %d\n存活波次: %d" % [_kill_count, _current_wave]

func _on_wave_timer_timeout() -> void:
	_current_wave += 1
	_wave_elapsed = 0.0

	# 难度提升
	spawn_timer.wait_time = max(base_spawn_interval / pow(difficulty_scale, _current_wave - 1), 0.3)
	enemies_per_spawn += 1

	EventBus.wave_changed.emit(_current_wave)
	_update_ui()

func _update_ui() -> void:
	kill_label.text = "击杀: %d" % _kill_count
	wave_label.text = "波次 %d" % _current_wave

func _input(event: InputEvent) -> void:
	if _is_game_over and event.is_action_pressed("move_up"):
		_restart()

func _restart() -> void:
	get_tree().reload_current_scene()
