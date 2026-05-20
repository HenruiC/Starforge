class_name SkillBase
extends Node

# === 技能元数据 ===
@export var skill_id: String = ""
@export var skill_name: String = ""
@export var icon: String = ""
@export_multiline var description: String = ""

# === 数值 ===
@export var cooldown: float = 1.0
@export var damage: int = 10
@export var attack_range: float = 120.0

# === 状态 ===
var cooldown_remaining: float = 0.0
var is_ready: bool = true
var parent_node: Node2D = null
var attack_area: Area2D = null  # 由 SkillManager 注入

# === 统一战斗框架 ===
## 技能拥有者（CombatUnit 或 CharacterBody2D，由 setup 设置）
var owner_unit = null
## 瞄准目标（可由外部设置，用于 AI 或辅助瞄准）
var target_node: Node2D = null

# === 兼容层（阶段三完成后删除）===
## 旧接口：player → 代理到 owner_unit
var player: CharacterBody2D:
	get: return owner_unit as CharacterBody2D
	set(v): owner_unit = v

# === 视觉效果节点（子类可覆盖） ===
var effect_parent: Node2D = null

# --------------------------------------------------------------------------
# 攻击前摇 / 硬直系统（宫崎英高标准）
# --------------------------------------------------------------------------

## 前摇开始（参数=前摇总时长）
signal windup_started(duration: float)
## 前摇结束，即将进入伤害帧
signal windup_ended()
## 硬直开始
signal recovery_started(duration: float)
## 硬直结束，攻击流程完成
signal recovery_ended()

## 前摇时长（秒），遵照宫崎标准 ≥0.35s
var _windup_duration: float = 0.35
## 硬直时长（秒）
var _recovery_duration: float = 0.2
## 是否在前摇中
var _is_windup: bool = false
## 是否在硬直中
var _is_recovery: bool = false
## 是否在伤害帧中
var _is_active_frame: bool = false

## 攻击分类（对应 RECOVERY_STANDARDS / WINDUP_STANDARDS 的 key）
@export var attack_category: String = "melee_light"

## 硬直期间能否移动
var _can_move_during_recovery: bool = false
## 硬直期间能否攻击
var _can_attack_during_recovery: bool = false

# --------------------------------------------------------------------------
# 前摇 / 硬直标准表（宫崎英高 5.1 / 5.2 节）
# --------------------------------------------------------------------------

const RECOVERY_STANDARDS := {
	"melee_light":      {"min": 0.2, "recommended": 0.3, "can_move": false, "can_attack": false},
	"melee_heavy":      {"min": 0.4, "recommended": 0.6, "can_move": false, "can_attack": false},
	"ranged_single":    {"min": 0.15, "recommended": 0.2, "can_move": true,  "can_attack": false},
	"ranged_barrage":   {"min": 0.3, "recommended": 0.5, "can_move": false, "can_attack": false},
	"aoe_ground":       {"min": 0.5, "recommended": 0.8, "can_move": false, "can_attack": false},
	"dash_into_wall":   {"min": 0.5, "recommended": 0.8, "can_move": false, "can_attack": false},
	"ultimate":         {"min": 1.5, "recommended": 2.0, "can_move": false, "can_attack": false},
}

const WINDUP_STANDARDS := {
	"melee_light":      {"min": 0.35, "recommended": 0.4},
	"melee_heavy":      {"min": 0.6,  "recommended": 0.8},
	"ranged_single":    {"min": 0.35, "recommended": 0.4},
	"ranged_barrage":   {"min": 0.5,  "recommended": 0.7},
	"aoe_ground":       {"min": 0.8,  "recommended": 1.2},
	"dash":             {"min": 0.6,  "recommended": 0.7},
	"summon":           {"min": 1.0,  "recommended": 1.3},
	"ultimate":         {"min": 1.5,  "recommended": 2.0},
}

# --------------------------------------------------------------------------
# 初始化
# --------------------------------------------------------------------------

func setup(unit, ep: Node2D) -> void:
	owner_unit = unit
	effect_parent = ep
	_apply_windup_standard()
	_apply_recovery_standard()

func _apply_windup_standard() -> void:
	var std: Dictionary = WINDUP_STANDARDS.get(attack_category, WINDUP_STANDARDS["melee_light"])
	_windup_duration = maxf(_windup_duration, std["min"])

func _apply_recovery_standard() -> void:
	var std: Dictionary = RECOVERY_STANDARDS.get(attack_category, RECOVERY_STANDARDS["melee_light"])
	_recovery_duration = maxf(_recovery_duration, std["min"])
	_can_move_during_recovery = std["can_move"]
	_can_attack_during_recovery = std["can_attack"]

# --------------------------------------------------------------------------
# 每帧 — 冷却递减
# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_ready:
		cooldown_remaining -= delta
		if cooldown_remaining <= 0.0:
			cooldown_remaining = 0.0
			is_ready = true

# --------------------------------------------------------------------------
# 攻击执行 — 协程：前摇 → 伤害帧 → 硬直
# --------------------------------------------------------------------------

## 尝试执行攻击。
## 返回 false 表示技能不可用（冷却/条件不满足/正在前摇或硬直中）。
## 返回 true 表示攻击已启动，后续流程（前摇→伤害帧→硬直）在后台协程中自动推进。
	if get_tree().paused: return
func try_execute() -> bool:
	if not is_ready:
		return false
	if not can_execute():
		return false
	if _is_windup or _is_recovery or _is_active_frame:
		return false

	is_ready = false
	cooldown_remaining = cooldown

	# 前摇阶段
	_is_windup = true
	windup_started.emit(_windup_duration)
	await get_tree().create_timer(_windup_duration).timeout
	_is_windup = false
	windup_ended.emit()

	# 伤害帧
	_is_active_frame = true
	execute()
	_is_active_frame = false

	# 硬直阶段
	_is_recovery = true
	recovery_started.emit(_recovery_duration)
	await get_tree().create_timer(_recovery_duration).timeout
	_is_recovery = false
	recovery_ended.emit()

	_trigger_feedback()
	return true

func _trigger_feedback() -> void:
	if damage >= 30:
		CombatFeedback.big_hit_stop()
		CombatFeedback.screen_shake(4.0)
	elif damage >= 15:
		CombatFeedback.hit_stop()
		CombatFeedback.screen_shake(2.0)
	else:
		CombatFeedback.screen_shake(1.0)

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
