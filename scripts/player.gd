class_name Player
extends CharacterBody2D

# === 基础属性 ===
@export var max_health: int = 100
@export var move_speed: float = 300.0
@export var attack_power: int = 15
@export var defense: int = 2
@export var attack_range: float = 120.0
@export var contact_damage_cooldown: float = 1.0

# 武器系统
@export var weapon_type: String = "sword"
@export var weapon_multiplier: float = 1.0

# 成长
@export var level: int = 1
@export var exp: int = 0
@export var exp_to_next: int = 50

# === 节点 ===
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var hitbox: Area2D = $Hitbox
@onready var hit_flash: ColorRect = $HitFlash
@onready var sprite: ColorRect = $Sprite

# HUD
@onready var hp_bar: ProgressBar = $HUD/HBox/HPBox/HPBar
@onready var hp_label: Label = $HUD/HBox/HPBox/HPLabel
@onready var exp_bar: ProgressBar = $HUD/EXPBar
@onready var level_label: Label = $HUD/LevelLabel
@onready var stats_label: Label = $HUD/StatsLabel
@onready var skill_icons: HBoxContainer = $HUD/SkillIcons

# === 技能系统 ===
var skill_manager: SkillManager = null
var _pending_level_ups: int = 0

# === 私有 ===
var _health: int
var _contact_timer: float = 0.0
var _is_dead: bool = false
var _aim_direction: Vector2 = Vector2.RIGHT

signal level_up_available(count: int)
signal preset_chosen(preset: String)

func _ready() -> void:
	_health = max_health
	(attack_shape.shape as CircleShape2D).radius = attack_range
	_update_all_ui()

func init_skills(skill_ids: Array, weapon_id: String) -> void:
	skill_manager = SkillManager.new()
	skill_manager.init(self, get_parent() if get_parent() else self, attack_area, skill_ids)
	add_child(skill_manager)

	var wp: Dictionary = SkillManager.WEAPON_POOL.get(weapon_id, SkillManager.WEAPON_POOL["sword"])
	weapon_type = weapon_id
	weapon_multiplier = wp["mult"]
	move_speed = wp["spd"]
	attack_range = wp["range"]
	(attack_shape.shape as CircleShape2D).radius = attack_range

	_update_skill_icons()
	preset_chosen.emit(weapon_id)

func _physics_process(delta: float) -> void:
	if _is_dead: return
	if GameState.current_state != GameState.State.PLAYING and GameState.current_state != GameState.State.CHAR_SELECT: return

	# 移动(WASD)
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * move_speed
	move_and_slide()

	# 更新攻击方向(鼠标)
	_aim_direction = (get_global_mouse_position() - global_position).normalized()

	# 接触伤害
	_contact_timer += delta
	if _contact_timer >= contact_damage_cooldown:
		_contact_timer = 0.0
		for body in hitbox.get_overlapping_bodies():
			if body.is_in_group("enemy") and body.has_method("get_contact_damage"):
				take_damage(body.get_contact_damage())

	# 技能系统
	if skill_manager:
		skill_manager.process_all(delta)

func take_damage(raw_amount: int) -> void:
	if _is_dead:
		return
	var actual: int = max(raw_amount - defense, 1)
	_health = max(_health - actual, 0)
	_update_all_ui()
	EventBus.player_hit.emit(actual, _health)

	var t := create_tween()
	t.tween_property(hit_flash, "color:a", 0.35, 0.04)
	t.tween_property(hit_flash, "color:a", 0.0, 0.12)

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
		level_up()
	_update_all_ui()

func level_up() -> void:
	level += 1
	_pending_level_ups += 1
	exp_to_next = int(exp_to_next * 1.35)
	_health = min(_health + 15, max_health)
	level_up_available.emit(_pending_level_ups)

	# 每5级技能质变检查
	if level % 5 == 0 and skill_manager:
		skill_manager.check_skill_evolution()

func has_pending_level_ups() -> bool:
	return _pending_level_ups > 0


func apply_upgrade(upgrade_id: String) -> void:
	_pending_level_ups -= 1

	match upgrade_id:
		"atk":
			attack_power += 5
			if skill_manager:
				for s in skill_manager.skills:
					s.damage += 3
		"spd":
			move_speed += 20
			if skill_manager:
				for s in skill_manager.skills:
					s.cooldown = maxf(s.cooldown * 0.92, 0.1)
		"def":
			defense += 2; max_health += 25
			_health = min(_health + 25, max_health)
		"skill1", "skill2", "skill3":
			var idx := 0 if upgrade_id == "skill1" else (1 if upgrade_id == "skill2" else 2)
			if skill_manager and idx < skill_manager.skills.size():
				skill_manager.skills[idx].apply_level_up()
		"heal":
			_health = max_health
			CombatFeedback.damage_number(global_position, max_health, false, true)

	_update_all_ui()
	_update_skill_icons()

func _update_all_ui() -> void:
	hp_bar.value = clamp(float(_health) / float(max_health) * 100.0, 0, 100)
	hp_label.text = "%d / %d" % [_health, max_health]
	exp_bar.value = clamp(float(exp) / float(exp_to_next) * 100.0, 0, 100)
	level_label.text = "Lv.%d" % level
	stats_label.text = "ATK:%d  DEF:%d  SPD:%.0f" % [attack_power, defense, move_speed]

func _update_skill_icons() -> void:
	for child in skill_icons.get_children():
		child.queue_free()
	if not skill_manager:
		return
	for s in skill_manager.skills:
		var icon := Label.new()
		icon.text = s.icon
		icon.custom_minimum_size = Vector2(28, 28)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		skill_icons.add_child(icon)
