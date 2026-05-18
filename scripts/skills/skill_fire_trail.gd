class_name SkillFireTrail
extends SkillBase

# 火焰路径 — 在地上留下火焰，持续灼烧敌人

@export var trail_lifetime: float = 3.0
@export var trail_interval: float = 0.3
@export var burn_damage: int = 5

var _trail_timer: float = 0.0

func can_execute() -> bool:
	return false  # 被动技能, 不通过execute触发

func _process(delta: float) -> void:
	super._process(delta)
	_trail_timer += delta
	if _trail_timer >= trail_interval:
		_trail_timer = 0.0
		_spawn_trail()

func _spawn_trail() -> void:
	var fire := _create_effect_rect(Color(1.0, 0.4, 0.05, 0.5), Vector2(16, 16), player.global_position, 8)
	var t := create_tween()
	t.tween_property(fire, "modulate:a", 0.0, trail_lifetime)
	t.tween_callback(fire.queue_free)

	# 灼烧附近敌人
	if attack_area == null: return
	for body in attack_area.get_overlapping_bodies():
		if body.is_in_group("enemy") and body.has_method("take_damage") and not body.is_dead:
			body.take_damage(burn_damage)

func apply_level_up(power: int = 1) -> void:
	burn_damage += power * 2
	trail_interval = maxf(trail_interval * 0.9, 0.1)
