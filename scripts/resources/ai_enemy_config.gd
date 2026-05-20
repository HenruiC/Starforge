class_name AIEnemyConfig
extends Resource

## 通用 AI 配置 — 数据驱动敌人行为
##
## 每种敌人类型对应一个 .tres 实例，或在代码中用静态工厂方法创建。
## 所有 AI 行为参数集中管理，不在 enemy.gd 中硬编码。

# =============================================================================
# 基础行为参数
# =============================================================================

## 初始行为模式 (CHASE / KITE / PATROL / GUARD / AMBUSH)
@export var initial_behavior: int = 0

## 索敌范围（px），超过此距离敌人完全无视玩家
@export var detection_range: float = 600.0

## 最大追击距离（px），超出后返回
@export var leash_range: float = 800.0

## 战斗移速倍率（相对于 Enemy.move_speed）
@export var chase_speed_mult: float = 1.0

# =============================================================================
# 近战参数
# =============================================================================

## 近战攻击距离（px）
@export var melee_range: float = 45.0

## 近战攻击基础冷却（秒）
@export var melee_cooldown: float = 1.2

# =============================================================================
# 远程参数
# =============================================================================

## 偏好距离（px），远程敌人试图维持在此距离
@export var preferred_distance: float = 180.0

## 远程攻击冷却（秒）
@export var ranged_cooldown: float = 2.0

# =============================================================================
# 巡逻参数
# =============================================================================

@export var patrol_points: Array[Vector2] = []
@export var patrol_wait_time: float = 1.0
@export var patrol_vision_angle: float = 120.0
@export var patrol_vision_range: float = 180.0

# =============================================================================
# 守卫参数
# =============================================================================

@export var guard_position: Vector2 = Vector2.ZERO
@export var guard_radius: float = 60.0
@export var guard_leash: float = 200.0

# =============================================================================
# 逃跑参数
# =============================================================================

@export var flee_health_ratio: float = 0.2
@export var flee_speed_mult: float = 1.3
@export var flee_timeout: float = 5.0

# =============================================================================
# 伏击参数
# =============================================================================

@export var ambush_trigger_distance: float = 60.0
@export var ambush_bonus_damage_mult: float = 1.5
@export var ambush_bonus_duration: float = 2.0

# =============================================================================
# 狂暴参数
# =============================================================================

## 是否启用狂暴系统
@export var berserk_enabled: bool = true

## 狂暴持续时间（秒）
@export var berserk_duration: float = 4.0

## 狂暴移速倍率
@export var berserk_speed_mult: float = 1.5

## 狂暴攻击冷却倍率（< 1.0 = 更快攻击）
@export var berserk_cooldown_mult: float = 0.5

## 狂暴触发伤害阈值（0 = 任意伤害触发）
@export var berserk_damage_threshold: int = 0

## 精英/Boss 狂暴时激怒周围小怪的半径（0 = 不激怒）
@export var enrage_radius: float = 500.0

# =============================================================================
# 导航参数
# =============================================================================

## 路径更新频率（秒）
@export var path_update_interval: float = 0.05

## 行为决策频率（秒）
@export var decision_interval: float = 0.15

## 是否使用 NavigationAgent2D 导航
@export var use_nav_agent: bool = true

# =============================================================================
# 预设工厂方法
# =============================================================================

static func melee_default() -> AIEnemyConfig:
	var cfg := AIEnemyConfig.new()
	cfg.initial_behavior = 1  # CHASE
	cfg.detection_range = 600.0
	cfg.leash_range = 800.0
	cfg.chase_speed_mult = 1.0
	cfg.melee_range = 45.0
	cfg.melee_cooldown = 1.2
	cfg.berserk_enabled = true
	cfg.berserk_duration = 4.0
	cfg.berserk_speed_mult = 1.5
	cfg.berserk_cooldown_mult = 0.5
	cfg.enrage_radius = 0.0
	cfg.use_nav_agent = true
	return cfg

static func ranged_default() -> AIEnemyConfig:
	var cfg := AIEnemyConfig.new()
	cfg.initial_behavior = 2  # KITE
	cfg.detection_range = 650.0
	cfg.leash_range = 900.0
	cfg.chase_speed_mult = 0.9
	cfg.preferred_distance = 180.0
	cfg.ranged_cooldown = 2.0
	cfg.berserk_enabled = true
	cfg.berserk_duration = 3.5
	cfg.berserk_speed_mult = 1.4
	cfg.berserk_cooldown_mult = 0.6
	cfg.enrage_radius = 0.0
	cfg.use_nav_agent = true
	return cfg

static func elite_default() -> AIEnemyConfig:
	var cfg := AIEnemyConfig.new()
	cfg.initial_behavior = 1  # CHASE
	cfg.detection_range = 700.0
	cfg.leash_range = 1000.0
	cfg.chase_speed_mult = 0.8
	cfg.melee_range = 55.0
	cfg.melee_cooldown = 1.2
	cfg.berserk_enabled = true
	cfg.berserk_duration = 5.0
	cfg.berserk_speed_mult = 1.3
	cfg.berserk_cooldown_mult = 0.5
	cfg.enrage_radius = 500.0
	cfg.use_nav_agent = true
	return cfg

static func boss_sato() -> AIEnemyConfig:
	var cfg := AIEnemyConfig.new()
	cfg.initial_behavior = 1  # CHASE
	cfg.detection_range = 900.0
	cfg.leash_range = 1200.0
	cfg.chase_speed_mult = 1.0
	cfg.melee_range = 60.0
	cfg.berserk_enabled = false  # Boss has own phase system
	cfg.enrage_radius = 500.0
	cfg.use_nav_agent = true
	return cfg

static func student_minion() -> AIEnemyConfig:
	var cfg := AIEnemyConfig.new()
	cfg.initial_behavior = 0  # IDLE
	cfg.detection_range = 400.0
	cfg.leash_range = 600.0
	cfg.chase_speed_mult = 0.9
	cfg.melee_range = 40.0
	cfg.melee_cooldown = 1.5
	cfg.berserk_enabled = true
	cfg.berserk_duration = 3.0
	cfg.berserk_speed_mult = 1.6
	cfg.berserk_cooldown_mult = 0.4
	cfg.enrage_radius = 0.0
	cfg.use_nav_agent = true
	return cfg
