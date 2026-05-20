class_name EnemyConfig
extends Resource

## 敌人配置资源 — 定义基础敌人类型和属性

## 敌人类型枚举
enum Type {
	MELEE,    # 近战变异体
	RANGED,   # 远程变异体
	ELITE,    # 精英
	BOSS,     # Boss
}

## 敌人类型 ID
@export var type_id: String = ""
## 显示名称
@export var display_name: String = ""
## 敌人类型
@export var enemy_type: Type = Type.MELEE
## 基础生命值
@export var base_health: int = 20
## 基础移速（px/s）
@export var base_speed: float = 100.0
## 基础接触伤害
@export var base_contact_damage: int = 5
## 基础远程伤害（0=无远程能力）
@export var base_ranged_damage: int = 0
## 远程攻击冷却
@export var ranged_cooldown: float = 2.5
## 基础经验值
@export var base_xp: int = 10
## 基础分数
@export var base_score: int = 1
## 每波次 HP 倍率增长
@export var hp_scale_per_wave: float = 0.2
## 每波次移速增长
@export var speed_scale_per_wave: float = 6.0
## 每波次伤害倍率增长
@export var damage_scale_per_wave: float = 0.2


## 创建近战默认配置
static func melee_default() -> EnemyConfig:
	var cfg := EnemyConfig.new()
	cfg.type_id = "melee_default"
	cfg.display_name = "近战变异体"
	cfg.enemy_type = Type.MELEE
	cfg.base_health = 20
	cfg.base_speed = 100.0
	cfg.base_contact_damage = 5
	cfg.base_xp = 10
	cfg.base_score = 1
	return cfg


## 创建远程默认配置
static func ranged_default() -> EnemyConfig:
	var cfg := EnemyConfig.new()
	cfg.type_id = "ranged_default"
	cfg.display_name = "远程变异体"
	cfg.enemy_type = Type.RANGED
	cfg.base_health = 25
	cfg.base_speed = 100.0
	cfg.base_contact_damage = 2
	cfg.base_ranged_damage = 10
	cfg.ranged_cooldown = 2.5
	cfg.base_xp = 20
	cfg.base_score = 2
	return cfg


## 创建精英默认配置
static func elite_default() -> EnemyConfig:
	var cfg := EnemyConfig.new()
	cfg.type_id = "elite_default"
	cfg.display_name = "精英变异体"
	cfg.enemy_type = Type.ELITE
	cfg.base_health = 90
	cfg.base_speed = 120.0
	cfg.base_contact_damage = 20
	cfg.base_xp = 40
	cfg.base_score = 5
	return cfg


## 创建 Boss 配置（体育老师·佐藤）
static func boss_sato() -> EnemyConfig:
	var cfg := EnemyConfig.new()
	cfg.type_id = "boss_sato"
	cfg.display_name = "体育老师 · 佐藤"
	cfg.enemy_type = Type.BOSS
	cfg.base_health = 1600
	cfg.base_speed = 60.0
	cfg.base_contact_damage = 25
	cfg.base_xp = 100
	cfg.base_score = 10
	return cfg
