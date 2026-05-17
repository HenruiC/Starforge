class_name Enemy
extends CharacterBody2D

# === 属性 ===
@export var max_health: int = 30
@export var move_speed: float = 120.0
@export var contact_damage: int = 10
@export var score_value: int = 1
@export var xp_value: int = 15
@export var is_elite: bool = false
@export var is_ranged: bool = false

# 远程攻击
@export var ranged_damage: int = 10
@export var ranged_speed: float = 220.0
@export var ranged_cooldown: float = 2.0
@export var preferred_distance: float = 180.0

# === 节点引用 ===
@onready var sprite: ColorRect = $Sprite
@onready var hp_bar: ProgressBar = $HealthBar
@onready var contact_area: Area2D = $ContactArea
@onready var hit_flash: ColorRect = $HitFlash
@onready var shoot_timer: Timer = $ShootTimer

# 预加载
var _enemy_projectile_scene: PackedScene = preload("res://scenes/enemy_projectile.tscn")

# === 变量 ===
var _health: int
var _player_ref: Node2D = null
var is_dead: bool = false
var _ranged_timer: float = 0.0

func _ready() -> void:
	_health = max_health
	_update_hp()

	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player_ref = players[0]

	# 精英外观
	if is_elite:
		_setup_elite()

func _setup_elite() -> void:
	sprite.color = Color(0.7, 0.2, 0.9, 1.0)
	sprite.scale = Vector2(1.6, 1.6)
	hp_bar.custom_minimum_size = Vector2(48, 5)
	sprite.offset_left = -18
	sprite.offset_top = -18
	sprite.offset_right = 18
	sprite.offset_bottom = 18
	# 精英光环
	var glow := ColorRect.new()
	glow.name = "EliteGlow"
	glow.color = Color(0.7, 0.2, 0.9, 0.25)
	glow.offset_left = -22
	glow.offset_top = -22
	glow.offset_right = 22
	glow.offset_bottom = 22
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)
	move_child(glow, 0)

func _physics_process(delta: float) -> void:
	if is_dead or _player_ref == null:
		return

	if is_ranged:
		_ranged_behavior(delta)
	else:
		_melee_behavior()

func _melee_behavior() -> void:
	var direction := global_position.direction_to(_player_ref.global_position)
	velocity = direction * move_speed
	move_and_slide()

func _ranged_behavior(delta: float) -> void:
	var dist := global_position.distance_to(_player_ref.global_position)
	var dir := global_position.direction_to(_player_ref.global_position)

	if dist > preferred_distance + 30:
		velocity = dir * move_speed
	elif dist < preferred_distance - 30:
		velocity = -dir * move_speed * 0.6
	else:
		velocity = Vector2.ZERO
		# 在射程内横向移动
		var strafe := dir.rotated(PI / 2) * move_speed * 0.3
		velocity += strafe

	move_and_slide()

	_ranged_timer += delta
	if _ranged_timer >= ranged_cooldown:
		_ranged_timer = 0.0
		_shoot()

func _shoot() -> void:
	var proj := _enemy_projectile_scene.instantiate()
	proj.global_position = global_position
	var dir := global_position.direction_to(_player_ref.global_position)
	proj.setup(dir, ranged_speed, ranged_damage)
	get_parent().add_child(proj)

	# 射击闪光
	sprite.modulate = Color.GREEN
	create_tween().tween_property(sprite, "modulate", sprite.color, 0.1)

func take_damage(amount: int) -> void:
	if is_dead:
		return

	var actual: int = max(amount, 1)
	_health = max(_health - actual, 0)
	_update_hp()

	# 伤害数字
	CombatFeedback.damage_number(global_position, actual, amount >= 30)
	# 受击特效
	_show_hit_effect()

	if _health <= 0:
		_die()

func _show_hit_effect() -> void:
	# 闪白
	sprite.material = null
	sprite.modulate = Color.WHITE

	# 受击震动
	var orig_pos := position
	var tween := create_tween()
	tween.tween_property(self, "position", orig_pos + Vector2(3, 0), 0.02)
	tween.tween_property(self, "position", orig_pos + Vector2(-3, 0), 0.02)
	tween.tween_property(self, "position", orig_pos, 0.02)
	tween.parallel().tween_property(sprite, "modulate", sprite.color if not is_elite else Color(0.7, 0.2, 0.9), 0.06)

	# 受击粒子模拟（多个小方块飞出）
	for i in 3:
		var p := ColorRect.new()
		p.color = Color(1.0, 0.8, 0.2, 0.7)
		p.size = Vector2(3, 3)
		p.position = Vector2(-1.5, -1.5)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(p)
		var angle := randf_range(0, TAU)
		var dist := randf_range(15, 30)
		var pt := create_tween()
		pt.set_parallel(true)
		pt.tween_property(p, "position", Vector2(cos(angle) * dist, sin(angle) * dist), 0.3)
		pt.tween_property(p, "color:a", 0.0, 0.3)
		pt.tween_callback(p.queue_free)

func knockback(force: Vector2) -> void:
	velocity += force
	move_and_slide()

func _die() -> void:
	is_dead = true
	EventBus.enemy_killed.emit(global_position, score_value)

	# 击杀粒子爆发
	if is_elite:
		CombatFeedback.kill_explosion(global_position)
	else:
		CombatFeedback.hit_particles(global_position, 4, Color(1.0, 0.5, 0.1))

	# 死亡扩散特效
	var tween := create_tween().set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_property(sprite, "scale", sprite.scale * 1.3, 0.3)
	tween.chain().tween_callback(queue_free)

func get_contact_damage() -> int:
	return contact_damage

func _update_hp() -> void:
	var ratio := (_health as float / max_health) * 100.0
	hp_bar.value = ratio
	hp_bar.visible = ratio < 100.0
