class_name Enemy
extends CombatUnit

# 属性
@export var contact_damage: int = 10
@export var score_value: int = 1
@export var xp_value: int = 15
@export var is_elite: bool = false
@export var is_ranged: bool = false
@export var is_boss: bool = false
@export var is_dodger: bool = false
@export var activation_range: float = 0.0
@export var detection_range: float = 600.0
@export var ranged_damage: int = 10
@export var ranged_speed: float = 220.0
@export var ranged_cooldown: float = 2.0
@export var preferred_distance: float = 180.0
@export var ai_config: AIEnemyConfig = null

# 节点
@onready var sprite: ColorRect = $Sprite
@onready var hp_bar: ProgressBar = $HealthBar
@onready var contact_area: Area2D = $ContactArea
@onready var hit_flash: ColorRect = $HitFlash
@onready var shoot_timer: Timer = $ShootTimer

# 内部
var _enemy_projectile_scene: PackedScene = preload("res://scenes/enemy_projectile.tscn")
var _player_ref: Node2D = null
var _ranged_timer: float = 0.0
var _shoot_tween: Tween = null
var _nav_agent: NavigationAgent2D = null
var _boss_glow_tween: Tween = null
var _boss_attack_timer: float = 0.0
var _path_update_counter: int = 0

# 冲刺攻击状态机
var _lunge_state: String = "idle"
var _lunge_target: Vector2 = Vector2.ZERO
var _lunge_origin: Vector2 = Vector2.ZERO
var _lunge_timer: float = 0.0
var _lunge_cooldown: float = 0.0
var _lunge_speed: float = 400.0

# 狂暴
var _is_berserk: bool = false
var _berserk_timer: float = 0.0
var _berserk_speed_mult: float = 1.5

func _ready() -> void:
	super._ready()
	_update_hp()

	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player_ref = players[0]

	# 导航Agent
	_nav_agent = NavigationAgent2D.new()
	_nav_agent.path_desired_distance = 10.0
	_nav_agent.target_desired_distance = 20.0
	add_child(_nav_agent)
	await get_tree().process_frame
	_nav_agent.target_position = global_position
	_path_update_counter = randi() % 30

	# 外观区分
	if is_ranged: sprite.color = Color(0.2, 0.7, 0.3)
	elif is_elite: sprite.color = Color(0.7, 0.25, 0.85)
	else: sprite.color = Color(0.65, 0.25, 0.2)
	if is_elite: _setup_elite()
	if is_boss: _setup_boss()

	# AI配置兜底
	if ai_config == null: ai_config = AIEnemyConfig.melee_default()
	detection_range = ai_config.detection_range
	_collision_resize()

func _setup_elite() -> void:
	sprite.scale = Vector2(1.6, 1.6)
	sprite.color = Color(0.7, 0.2, 0.9)
	var glow := ColorRect.new()
	glow.name = "EliteGlow"; glow.color = Color(0.7, 0.2, 0.9, 0.25)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow); move_child(glow, 0)

func _setup_boss() -> void:
	sprite.color = Color(0.9, 0.1, 0.05)
	sprite.scale = Vector2(3.0, 3.0)
	var glow := ColorRect.new()
	glow.name = "BossGlow"; glow.color = Color(1.0, 0.5, 0.1, 0.35)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow); move_child(glow, 0)
	_boss_glow_tween = create_tween().set_loops(0)

func _collision_resize() -> void:
	var body := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not body: return
	var shape: Shape2D = body.shape
	if shape is CircleShape2D:
		var r: float = 14.0
		if is_boss: r = 32.0
		elif is_elite: r = 20.0
		(shape as CircleShape2D).radius = r

func _physics_process(delta: float) -> void:
	if is_dead or _player_ref == null: return
	if GameState.current_state != GameState.State.PLAYING: return
	var dist := global_position.distance_to(_player_ref.global_position)
	if dist > detection_range: return
	if activation_range > 0.0 and dist > activation_range: return

	if _is_berserk:
		_berserk_timer -= delta
		if _berserk_timer <= 0: _is_berserk = false

	if is_boss: _boss_behavior(delta); return
	if is_dodger: _dodger_behavior(delta); return
	if is_ranged: _ranged_behavior(delta); return
	_melee_behavior(delta)

# ====== 近战冲刺攻击 ======
func _melee_behavior(delta: float) -> void:
	if not _nav_agent or not is_instance_valid(_nav_agent): return
	if not _player_ref: return

	# 驻守任务优先
	var dz_target := _get_defend_zone_target()
	if dz_target != Vector2.ZERO and not is_elite and not is_boss:
		_nav_agent.target_position = dz_target
		var dz_next := _nav_agent.get_next_path_position()
		velocity = global_position.direction_to(dz_next) * move_speed * 1.3
		move_and_slide()
		return

	var speed := move_speed
	if _is_berserk: speed *= _berserk_speed_mult

	match _lunge_state:
		"idle", "chase":
			_path_update_counter += 1
			if _path_update_counter % 10 == 0:
				_nav_agent.target_position = _player_ref.global_position
			if not _nav_agent.is_navigation_finished():
				var np := _nav_agent.get_next_path_position()
				var d2p := global_position.distance_to(_player_ref.global_position)
				if d2p < 40:
					velocity = -global_position.direction_to(_player_ref.global_position) * speed * 0.4
				else:
					velocity = global_position.direction_to(np) * speed
			if global_position.distance_to(_player_ref.global_position) < 60:
				_lunge_cooldown -= delta
				if _lunge_cooldown <= 0:
					_lunge_state = "windup"; _lunge_timer = 0.2; _lunge_origin = global_position
					sprite.scale = Vector2(1.3, 0.65); sprite.modulate = Color(1.4, 1.4, 1.4)
		"windup":
			_lunge_timer -= delta; velocity = Vector2.ZERO
			if _lunge_timer <= 0:
				_lunge_state = "lunge"; _lunge_timer = 0.12
				_lunge_target = _player_ref.global_position
				_lunge_speed = global_position.distance_to(_lunge_target) / maxf(_lunge_timer, 0.05)
		"lunge":
			_lunge_timer -= delta
			velocity = global_position.direction_to(_lunge_target) * _lunge_speed
			if _player_ref and global_position.distance_to(_player_ref.global_position) < 20:
				_player_ref.take_damage(contact_damage, self)
				CombatFeedback.screen_shake(3.0); CombatFeedback.damage_number(global_position, contact_damage, true)
				_lunge_state = "retreat"; _lunge_timer = 0.1
			elif _lunge_timer <= 0:
				_lunge_state = "retreat"; _lunge_timer = 0.1
		"retreat":
			_lunge_timer -= delta
			velocity = global_position.direction_to(_lunge_origin) * speed * 1.5
			sprite.scale = sprite.scale.lerp(Vector2.ONE, delta * 8)
			sprite.modulate = sprite.modulate.lerp(sprite.color, delta * 8)
			if _lunge_timer <= 0 or global_position.distance_to(_lunge_origin) < 15:
				sprite.scale = Vector2.ONE; sprite.modulate = sprite.color
				_lunge_state = "idle"; _lunge_cooldown = randf_range(1.5, 2.5)
	move_and_slide()

# ====== 远程 ======
func _ranged_behavior(delta: float) -> void:
	var dist := global_position.distance_to(_player_ref.global_position)
	var dir := global_position.direction_to(_player_ref.global_position)
	var speed := move_speed
	if _is_berserk: speed *= _berserk_speed_mult
	if dist > preferred_distance * 1.5:
		velocity = dir * speed
	elif dist < 80:
		velocity = -dir * speed * 0.3
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	_ranged_timer += delta
	if _ranged_timer >= ranged_cooldown:
		_ranged_timer = 0.0; _shoot()

func _shoot() -> void:
	var proj := _enemy_projectile_scene.instantiate()
	proj.global_position = global_position
	proj.setup(global_position.direction_to(_player_ref.global_position), ranged_speed, ranged_damage)
	get_parent().add_child(proj)
	if _shoot_tween: _shoot_tween.kill()
	sprite.modulate = Color.YELLOW
	_shoot_tween = create_tween()
	_shoot_tween.tween_property(sprite, "modulate", sprite.color, 0.1)

# ====== Boss ======
func _boss_behavior(delta: float) -> void:
	var bai := get_node_or_null("BossAI") as BossAI
	if bai and is_instance_valid(bai):
		bai.tick(delta)
	move_and_slide()

func _build_boss_systems(cfg: BossConfig) -> void:
	max_health = cfg.total_hp; _health = max_health
	var bp := BossPhaseController.new(); bp.name = "PhaseController"; add_child(bp)
	bp.init_phases(cfg.phases)
	var bai := BossAI.new(); bai.name = "BossAI"; add_child(bai)
	bai.setup(self, _player_ref, bp, [])

# ====== 闪避 ======
func _dodger_behavior(delta: float) -> void:
	if not _player_ref: return
	var dir := global_position.direction_to(_player_ref.global_position)
	velocity = dir.rotated(PI / 2) * move_speed
	move_and_slide()

# ====== 受伤 ======
func take_damage(amount: int, source: CombatUnit = null) -> void:
	if is_dead: return
	var defense: int = 0
	if is_boss: defense = 4
	var actual: int = maxi(amount - defense, 1)
	_health = max(_health - actual, 0)
	_update_hp()
	CombatFeedback.damage_number(global_position, actual, amount >= 30)
	_show_hit_effect()
	if not _is_berserk and ai_config and ai_config.berserk_enabled:
		_is_berserk = true; _berserk_timer = ai_config.berserk_duration
	if _health <= 0: _die(source)

func _show_hit_effect() -> void:
	sprite.modulate = Color.WHITE
	create_tween().tween_property(sprite, "modulate", sprite.color, 0.1)

# ====== 死亡 ======
func _die(killer: CombatUnit = null) -> void:
	if is_dead: return
	if _boss_glow_tween: _boss_glow_tween.kill()
	is_dead = true
	EventBus.enemy_killed.emit(global_position, score_value)
	EventBus.enemy_killed_filtered.emit(global_position, score_value, is_elite, is_boss, is_ranged)
	if is_elite: CombatFeedback.kill_explosion(global_position)
	else: CombatFeedback.hit_particles(global_position, 4, Color(1.0, 0.5, 0.1))
	var t := create_tween().set_parallel(true)
	t.tween_property(sprite, "modulate:a", 0.0, 0.3)
	t.tween_property(sprite, "scale", sprite.scale * 1.3, 0.3)
	t.chain().tween_callback(queue_free)

# ====== 辅助 ======
func get_contact_damage() -> int: return contact_damage

func _update_hp() -> void:
	var ratio := (_health as float / max_health) * 100.0
	hp_bar.value = ratio; hp_bar.visible = ratio < 100.0

func _get_defend_zone_target() -> Vector2:
	var mtm := get_tree().get_first_node_in_group("mission_trigger")
	if mtm and mtm.has_method("get_defend_zone_center"): return mtm.get_defend_zone_center()
	return Vector2.ZERO

func _get_part(nm: String) -> ColorRect:
	var n := get_node_or_null(nm)
	return n as ColorRect if n else null
