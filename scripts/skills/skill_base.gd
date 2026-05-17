class_name SkillBase
extends Node

# === 技能元数据 ===
@export var skill_id: String = ""
@export var skill_name: String = ""
@export var icon: String = "⚔"
@export_multiline var description: String = ""

# === 数值 ===
@export var cooldown: float = 1.0
@export var damage: int = 10
@export var attack_range: float = 120.0

# === 状态 ===
var cooldown_remaining: float = 0.0
var is_ready: bool = true
var player: CharacterBody2D = null
var parent_node: Node2D = null
var attack_area: Area2D = null  # 由 SkillManager 注入

# === 视觉效果节点（子类可覆盖） ===
var effect_parent: Node2D = null

func setup(p: CharacterBody2D, ep: Node2D) -> void:
	player = p
	effect_parent = ep

func _process(delta: float) -> void:
	if not is_ready:
		cooldown_remaining -= delta
		if cooldown_remaining <= 0.0:
			cooldown_remaining = 0.0
			is_ready = true

func try_execute() -> bool:
	if not is_ready:
		return false
	if not can_execute():
		return false
	is_ready = false
	cooldown_remaining = cooldown
	execute()
	return true

func can_execute() -> bool:
	return true

func execute() -> void:
	pass

func get_cooldown_ratio() -> float:
	if is_ready:
		return 1.0
	return 1.0 - (cooldown_remaining / cooldown)

func apply_level_up(power: int = 1) -> void:
	damage += power * 3
	cooldown = maxf(cooldown * 0.92, 0.1)

func _create_effect_rect(color: Color, size: Vector2, pos: Vector2, z: int = 10) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.size = size
	r.position = pos - size / 2.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.z_index = z
	effect_parent.add_child(r)
	return r
