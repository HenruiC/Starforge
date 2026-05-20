class_name DungeonConfig
extends Resource

## 副本配置资源 -- 定义三阶段敌人参数与波次间隔
##
## 在 game_manager 中引用，按当前 Stage 选择对应参数槽。
## 数值依据 GAP-02e 第七节 + Phase F 初调。

# =============================================================================
# Stage 1: 踏足校园 -- 教学阶段
# =============================================================================

## 近战杂兵基础 HP
@export var s1_melee_hp: int = 45
## 近战杂兵基础接触伤害
@export var s1_melee_damage: int = 15
## 近战杂兵基础移速
@export var s1_melee_speed: int = 100
## 远程射手基础 HP
@export var s1_ranged_hp: int = 22
## 远程射手基础远程伤害
@export var s1_ranged_damage: int = 10
## 远程射手基础移速
@export var s1_ranged_speed: int = 90
## 生成间隔（秒）
@export var s1_spawn_interval: float = 1.5
## 波次持续（秒）
@export var s1_wave_duration: float = 30.0

# =============================================================================
# Stage 2: 铃声下的教室 -- 压力测试阶段
# =============================================================================

## 近战杂兵基础 HP
@export var s2_melee_hp: int = 70
## 近战杂兵基础接触伤害
@export var s2_melee_damage: int = 18
## 近战杂兵基础移速
@export var s2_melee_speed: int = 110
## 精英基础 HP（普通 x3）
@export var s2_elite_hp: int = 210
## 精英基础接触伤害
@export var s2_elite_damage: int = 36
## 远程射手基础 HP
@export var s2_ranged_hp: int = 30
## 远程射手基础远程伤害
@export var s2_ranged_damage: int = 12
## 远程射手基础移速
@export var s2_ranged_speed: int = 95
## 生成间隔（秒）
@export var s2_spawn_interval: float = 1.2
## 波次持续（秒）
@export var s2_wave_duration: float = 30.0

# =============================================================================
# Stage 3: 体育馆的哨声 -- Boss 战 + 残余杂兵
# =============================================================================

## Boss 基础 HP（体育老师 · 佐藤）
@export var s3_boss_hp: int = 1600
## Boss 基础接触伤害
@export var s3_boss_damage: int = 25
## Boss 基础移速
@export var s3_boss_speed: int = 60
## 近战杂兵基础 HP（接近阶段的残余敌人）
@export var s3_melee_hp: int = 55
## 近战杂兵基础接触伤害
@export var s3_melee_damage: int = 18
## 近战杂兵基础移速
@export var s3_melee_speed: int = 120
## 远程射手基础 HP
@export var s3_ranged_hp: int = 35
## 远程射手基础远程伤害
@export var s3_ranged_damage: int = 14
## 远程射手基础移速
@export var s3_ranged_speed: int = 100
## 生成间隔（秒）
@export var s3_spawn_interval: float = 1.0
## 波次持续（秒）
@export var s3_wave_duration: float = 30.0


# =============================================================================
# 工厂方法
# =============================================================================

## 学校副本默认配置（Phase F 初调数值）
static func school_default() -> DungeonConfig:
	var cfg := DungeonConfig.new()

	# Stage 1
	cfg.s1_melee_hp = 45
	cfg.s1_melee_damage = 15
	cfg.s1_melee_speed = 100
	cfg.s1_ranged_hp = 22
	cfg.s1_ranged_damage = 10
	cfg.s1_ranged_speed = 90
	cfg.s1_spawn_interval = 1.5
	cfg.s1_wave_duration = 30.0

	# Stage 2
	cfg.s2_melee_hp = 70
	cfg.s2_melee_damage = 18
	cfg.s2_melee_speed = 110
	cfg.s2_elite_hp = 210
	cfg.s2_elite_damage = 36
	cfg.s2_ranged_hp = 30
	cfg.s2_ranged_damage = 12
	cfg.s2_ranged_speed = 95
	cfg.s2_spawn_interval = 1.2
	cfg.s2_wave_duration = 30.0

	# Stage 3
	cfg.s3_boss_hp = 1600
	cfg.s3_boss_damage = 25
	cfg.s3_boss_speed = 60
	cfg.s3_melee_hp = 55
	cfg.s3_melee_damage = 18
	cfg.s3_melee_speed = 120
	cfg.s3_ranged_hp = 35
	cfg.s3_ranged_damage = 14
	cfg.s3_ranged_speed = 100
	cfg.s3_spawn_interval = 1.0
	cfg.s3_wave_duration = 30.0

	return cfg


## 获取指定 Stage 的近战敌人 HP 基础值
func get_melee_hp(stage: int) -> int:
	match stage:
		2: return s2_melee_hp
		3: return s3_melee_hp
		_: return s1_melee_hp


## 获取指定 Stage 的近战敌人伤害基础值
func get_melee_damage(stage: int) -> int:
	match stage:
		2: return s2_melee_damage
		3: return s3_melee_damage
		_: return s1_melee_damage


## 获取指定 Stage 的近战敌人移速基础值
func get_melee_speed(stage: int) -> int:
	match stage:
		2: return s2_melee_speed
		3: return s3_melee_speed
		_: return s1_melee_speed


## 获取指定 Stage 的远程敌人 HP 基础值
func get_ranged_hp(stage: int) -> int:
	match stage:
		2: return s2_ranged_hp
		3: return s3_ranged_hp
		_: return s1_ranged_hp


## 获取指定 Stage 的远程敌人伤害基础值
func get_ranged_damage(stage: int) -> int:
	match stage:
		2: return s2_ranged_damage
		3: return s3_ranged_damage
		_: return s1_ranged_damage


## 获取指定 Stage 的远程敌人移速基础值
func get_ranged_speed(stage: int) -> int:
	match stage:
		2: return s2_ranged_speed
		3: return s3_ranged_speed
		_: return s1_ranged_speed


## 获取指定 Stage 的生成间隔
func get_spawn_interval(stage: int) -> float:
	match stage:
		2: return s2_spawn_interval
		3: return s3_spawn_interval
		_: return s1_spawn_interval


## 获取指定 Stage 的波次持续时间
func get_wave_duration(stage: int) -> float:
	match stage:
		2: return s2_wave_duration
		3: return s3_wave_duration
		_: return s1_wave_duration
