class_name Player
extends CharacterBody2D

# === 基础属性 ===
@export var max_health: int = 100
@export var move_speed: float = 300.0
@export var attack_range: float = 120.0
@export var attack_power: int = 15
@export var defense: int = 2
@export var attack_cooldown: float = 0.5
@export var contact_damage_cooldown: float = 1.0

# === AOE 范围攻击 ===
@export var aoe_cooldown: float = 4.0
@export var aoe_damage: int = 25
@export var aoe_range: float = 100.0
@export var aoe_knockback: float = 200.0

# === 投射物攻击（可选升级获得） ===
@export var has_projectile: bool = false
@export var projectile_count: int = 3
@export var projectile_damage: int = 12
@export var projectile_speed: float = 400.0
@export var projectile_cooldown: float = 1.5

# 成长
@export var level: int = 1
@export var exp: int = 0
@export var exp_to_next: int = 50

# === 节点引用 ===
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var hitbox: Area2D = $Hitbox
@onready var hit_flash: ColorRect = $HitFlash
@onready var sprite: ColorRect = $Sprite
@onready var aoe_sprite: ColorRect = $AOESprite/AOEVisual
@onready var aoe_scaler: Node2D = $AOESprite
@onready var projectile_spawner: Node2D = $ProjectileSpawner

# HUD
@onready var hp_bar: ProgressBar = $HUD/HBox/HPBox/HPBar
@onready var hp_label: Label = $HUD/HBox/HPBox/HPLabel
@onready var exp_bar: ProgressBar = $HUD/EXPBar
@onready var level_label: Label = $HUD/LevelLabel
@onready var stats_label: Label = $HUD/StatsLabel

# 预加载
var _player_projectile_scene: PackedScene = preload("res://scenes/player_projectile.tscn")

# === 私有变量 ===
var _health: int
var _attack_timer: float = 0.0
var _current_target: Node2D = null
var _contact_timer: float = 0.0
var _aoe_timer: float = 0.0
var _projectile_timer: float = 0.0
var _is_dead: bool = false
var _pending_level_ups: int = 0

signal level_up_available(count: int)

func _ready() -> void:
	_health = max_health
	(attack_shape.shape as CircleShape2D).radius = attack_range

	attack_area.body_entered.connect(_on_enemy_in_range)
	attack_area.body_exited.connect(_on_enemy_out_of_range)

	aoe_sprite.visible = false
	_update_all_ui()

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * move_speed
	move_and_slide()

	# 接触伤害
	_contact_timer += delta
	if _contact_timer >= contact_damage_cooldown:
		_contact_timer = 0.0
		_check_contact_damage()

	# 普通攻击
	_attack_timer += delta
	if _attack_timer >= attack_cooldown and _current_target != null:
		_attack_timer = 0.0
		_attack_current_target()

	# AOE 范围攻击
	_aoe_timer += delta
	if _aoe_timer >= aoe_cooldown:
		_aoe_timer = 0.0
		_do_aoe_attack()

	# 投射物攻击
	if has_projectile:
		_projectile_timer += delta
		if _projectile_timer >= projectile_cooldown:
			_projectile_timer = 0.0
			_spread_shot()

func _check_contact_damage() -> void:
	for body in hitbox.get_overlapping_bodies():
		if body.is_in_group("enemy") and body.has_method("get_contact_damage"):
			take_damage(body.get_contact_damage())

func _attack_current_target() -> void:
	if not is_instance_valid(_current_target) or not _current_target.has_method("take_damage") or _current_target.is_dead:
		_current_target = null
		return
	_current_target.take_damage(attack_power)

	# 攻击闪光
	sprite.modulate = Color(1.5, 1.5, 1.5, 1.0)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.06)

	# 挥剑特效
	_show_slash_effect()

func _show_slash_effect() -> void:
	var slash: ColorRect = $SlashEffect
	if _current_target:
		var dir := global_position.direction_to(_current_target.global_position)
		slash.rotation = dir.angle()
	slash.visible = true
	slash.modulate = Color(1.0, 0.9, 0.6, 0.7)
	slash.scale = Vector2(0.3, 1.0)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(slash, "scale", Vector2(1.5, 0.3), 0.12)
	tween.tween_property(slash, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(func(): slash.visible = false)

func _do_aoe_attack() -> void:
	aoe_sprite.visible = true
	aoe_sprite.modulate = Color(1.0, 0.6, 0.1, 0.45)
	aoe_scaler.scale = Vector2(0.3, 0.3)

	var tween := create_tween().set_parallel(true)
	var target_scale := aoe_range / 50.0
	tween.tween_property(aoe_scaler, "scale", Vector2(target_scale, target_scale), 0.2)
	tween.tween_property(aoe_sprite, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(func(): aoe_sprite.visible = false)

	for body in attack_area.get_overlapping_bodies():
		if body.is_in_group("enemy") and body.has_method("take_damage") and not body.is_dead:
			body.take_damage(aoe_damage)
			if body.has_method("knockback"):
				var dir := body.global_position.direction_to(global_position)
				body.knockback(dir * aoe_knockback)

func _spread_shot() -> void:
	var nearest := _find_nearest_enemy()
	if nearest == null:
		return

	var base_angle := global_position.direction_to(nearest.global_position).angle()
	var spread := deg_to_rad(25.0)

	for i in projectile_count:
		var offset_angle: float = 0.0
		if projectile_count > 1:
			offset_angle = lerp(-spread, spread, i as float / (projectile_count - 1))
		var dir := Vector2.RIGHT.rotated(base_angle + offset_angle)
		_fire_projectile(dir)

func _fire_projectile(dir: Vector2) -> void:
	var p := _player_projectile_scene.instantiate()
	p.setup(dir, projectile_speed, projectile_damage)
	p.global_position = global_position
	get_parent().add_child(p)

func _find_nearest_enemy() -> Node2D:
	var bodies := attack_area.get_overlapping_bodies()
	var nearest: Node2D = null
	var min_dist: float = INF
	for b in bodies:
		if b.is_in_group("enemy") and not b.is_dead:
			var d := global_position.distance_squared_to(b.global_position)
			if d < min_dist:
				min_dist = d
				nearest = b
	return nearest

func take_damage(raw_amount: int) -> void:
	if _is_dead:
		return
	var actual: int = max(raw_amount - defense, 1)
	_health = max(_health - actual, 0)
	_update_all_ui()
	EventBus.player_hit.emit(actual, _health)

	var tween := create_tween()
	tween.tween_property(hit_flash, "color:a", 0.35, 0.04)
	tween.tween_property(hit_flash, "color:a", 0.0, 0.12)

	if _health <= 0:
		_die()

func _die() -> void:
	_is_dead = true
	EventBus.player_died.emit()
	sprite.modulate = Color(0.4, 0.4, 0.4, 0.6)
	set_physics_process(false)

func gain_exp(amount: int) -> void:
	exp += amount
	while exp >= exp_to_next:
		exp -= exp_to_next
		_level_up()
	_update_all_ui()

func _level_up() -> void:
	level += 1
	_pending_level_ups += 1
	exp_to_next = int(exp_to_next * 1.35)
	_health = min(_health + 15, max_health)
	level_up_available.emit(_pending_level_ups)

func apply_upgrade(upgrade_id: String) -> void:
	_pending_level_ups -= 1
	match upgrade_id:
		"atk":
			attack_power += 5
			aoe_damage += 3
		"spd":
			move_speed += 20
			attack_cooldown = max(attack_cooldown * 0.92, 0.15)
		"def":
			defense += 2
			max_health += 25
			_health = min(_health + 25, max_health)
		"aoe":
			aoe_range += 15
			aoe_damage += 10
			aoe_cooldown = max(aoe_cooldown * 0.88, 1.5)
		"range":
			attack_range += 18
			(attack_shape.shape as CircleShape2D).radius = attack_range
			aoe_range += 10
		"multi":
			if not has_projectile:
				has_projectile = true
			else:
				projectile_count += 1
				projectile_damage += 4
		"heal":
			_health = max_health

	_update_all_ui()

func get_upgrade_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = [
		{"id": "atk", "name": "攻击强化", "desc": "ATK +5 / AOE伤害 +3", "icon": "⚔"},
		{"id": "spd", "name": "敏捷强化", "desc": "SPD +20 / 攻速 +8%", "icon": "👟"},
		{"id": "def", "name": "防御强化", "desc": "DEF +2 / MaxHP +25", "icon": "🛡"},
		{"id": "aoe", "name": "范围爆发", "desc": "AOE范围+15 / 伤害+10 / CD-12%", "icon": "💥"},
		{"id": "range", "name": "射程扩展", "desc": "攻击范围+18 / AOE+10", "icon": "🎯"},
		{"id": "multi", "name": "多重投射", "desc": "+1弹幕 / 弹幕伤害+4", "icon": "✨"},
		{"id": "heal", "name": "生命恢复", "desc": "HP完全恢复", "icon": "❤"},
	]
	return pool

func _update_all_ui() -> void:
	hp_bar.value = clamp((_health as float / max_health) * 100.0, 0.0, 100.0)
	hp_label.text = "%d / %d" % [_health, max_health]
	exp_bar.value = clamp((exp as float / exp_to_next) * 100.0, 0.0, 100.0)
	level_label.text = "Lv.%d" % level
	var proj_str := "MULTI:%d" % projectile_count if has_projectile else "AOE"
	stats_label.text = "ATK:%d  DEF:%d  SPD:%.0f  %s" % [attack_power, defense, move_speed, proj_str]

func _on_enemy_in_range(body: Node2D) -> void:
	if body.is_in_group("enemy") and _current_target == null:
		_current_target = body

func _on_enemy_out_of_range(body: Node2D) -> void:
	if body == _current_target:
		_current_target = null
		for b in attack_area.get_overlapping_bodies():
			if b.is_in_group("enemy") and not b.is_dead:
				_current_target = b
				break
