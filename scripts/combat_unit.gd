class_name CombatUnit
extends CharacterBody2D

## 统一战斗角色基类
##
## 继承 CharacterBody2D，是 Player / Enemy / Boss 的公共基类。
## 提供通用的战斗能力（生命值、受伤、死亡、击退），
## 但不包含任何输入或 AI 逻辑（由各 Controller 处理）。
##
## 属性值通过 get_stat() 读取，优先级：StatsComponent → @export 基础值。
## 当 StatsComponent 挂载后，所有属性受 Buff 和 StatModifier 影响。

# 阵营枚举
enum Team { FRIENDLY, ENEMY, NEUTRAL }

# === 生命周期信号 ===

## 受到伤害时发出（实际伤害值，当前 HP，攻击者）
signal damage_taken(amount: int, current_hp: int, source: CombatUnit)
## 受到治疗时发出
signal healed(amount: int, current_hp: int)
## 死亡时发出（击杀者）
signal died(killer: CombatUnit)
## HP 变化时发出
signal health_changed(current_hp: int, max_hp: int)
## 属性值变化时发出
signal stat_changed(stat_name: String, new_value: float)

# === 核心导出属性 ===

## 单位唯一标识（如 "player", "enemy_basic", "boss_sato"）
@export var unit_id: String = ""

## 阵营
@export var team: Team = Team.ENEMY

## 最大生命值（StatsComponent 未挂载时使用此值）
@export var max_health: int = 100

## 移动速度（StatsComponent 未挂载时使用此值）
@export var move_speed: float = 200.0

# === 组件引用（可选挂载） ===

## 属性组件（挂载后属性受 Buff/StatModifier 影响）
var stats: StatsComponent = null
## Buff 组件（挂载后支持 Buff/Debuff 系统）
var buffs: BuffComponent = null

# === 运行状态 ===

## 是否已死亡
var is_dead: bool = false

## 瞄准方向（玩家 = 鼠标方向，AI = 面向目标方向）
var aim_direction: Vector2 = Vector2.RIGHT

## 兼容属性：允许技能文件通过 player.get("_aim_direction") 继续访问
# （所有技能子类迁移完成后删除）
var _aim_direction:
	get: return aim_direction
	set(v): aim_direction = v

# === 内部 ===

## 当前生命值（通过 take_damage/heal 修改，不要直接写）
## 使用 _health_backing 避免 setter 自递归
var _health_backing: int = 0

var _health: int:
	get: return _health_backing
	set(v):
		var old := _health_backing
		_health_backing = clampi(v, 0, max_health)
		if old != _health_backing:
			health_changed.emit(_health_backing, max_health)

# --------------------------------------------------------------------------
# 初始化
# --------------------------------------------------------------------------

func _ready() -> void:
	_health = max_health

# --------------------------------------------------------------------------
# 公共 HP 存取
# --------------------------------------------------------------------------

## 当前生命值（只读）
func get_current_health() -> int:
	return _health

## 当前生命值比例 [0.0, 1.0]
func get_health_ratio() -> float:
	if max_health <= 0:
		return 0.0
	return float(_health) / float(max_health)

# --------------------------------------------------------------------------
# 通用战斗方法
# --------------------------------------------------------------------------

## 受到伤害
##   amount: 原始伤害值
##   source: 攻击者（可选）
func take_damage(amount: int, source: CombatUnit = null) -> void:
	if is_dead:
		return

	var defense_val: int = int(get_stat("defense", 0.0))
	var actual := maxi(amount - defense_val, 1)
	_health = maxi(_health - actual, 0)

	damage_taken.emit(actual, _health, source)

	if _health <= 0:
		_die(source)

## 治疗
func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	var old_hp := _health
	_health = mini(_health + amount, max_health)
	var actual := _health - old_hp
	if actual > 0:
		healed.emit(actual, _health)

## 死亡（虚方法，子类可覆盖添加自定义效果）
func _die(killer: CombatUnit = null) -> void:
	if is_dead:
		return
	is_dead = true
	died.emit(killer)

## 击退
func knockback(force: Vector2) -> void:
	velocity += force
	move_and_slide()

# --------------------------------------------------------------------------
# 属性读取（委托链）
# --------------------------------------------------------------------------

## 获取最终属性值
##   优先级：StatsComponent.get_stat() → _get_base_stat() → default
func get_stat(stat_name: String, default: float = 0.0) -> float:
	if stats:
		return stats.get_stat(stat_name, default)
	return _get_base_stat(stat_name, default)

## 获取基础属性值（由子类覆盖以提供自定义 @export 属性）
##   CombatUnit 提供 max_health / move_speed
func _get_base_stat(stat_name: String, default: float = 0.0) -> float:
	match stat_name:
		"max_health":
			return float(max_health)
		"move_speed":
			return float(move_speed)
	return default
