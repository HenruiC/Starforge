class_name WaveConfig
extends Resource

## 波次配置资源 — 定义每波次的敌人组合和难度参数

## 波次编号（1-indexed）
@export var wave_number: int = 1
## 当前波次是否属于 Boss 战
@export var is_boss_wave: bool = false
## Boss ID（如果是 Boss 波次）
@export var boss_id: String = ""
## 基础敌人数
@export var base_enemy_count: int = 2
## 每波递增敌人数
@export var extra_enemies_per_wave: int = 1
## 精英波次间隔（每 N 波一次精英）
@export var elite_interval: int = 3
## 是否包含远程敌人
@export var has_ranged: bool = false
## 远程敌人数（如果 has_ranged）
@export var ranged_count_base: int = 0
## 远程敌人每 N 波增加
@export var ranged_extra_interval: int = 3
## Boss 波次前的准备波次数
@export var boss_prerequisite_waves: int = 5
## 波次持续时间（秒）
@export var wave_duration: float = 30.0
## 生成间隔（秒）
@export var spawn_interval: float = 1.5
## 难度倍率增长
@export var difficulty_scale: float = 1.3


## 计算指定波次的敌人数量
func get_enemy_count(wave: int) -> int:
	return base_enemy_count + (wave - 1) * extra_enemies_per_wave


## 是否为精英波次
func is_elite_wave(wave: int) -> bool:
	return elite_interval > 0 and wave % elite_interval == 0


## 计算指定波次的远程敌人数
func get_ranged_count(wave: int) -> int:
	if not has_ranged:
		return 0
	return ranged_count_base + max(0, (wave - 2) / ranged_extra_interval)


## 是否为 Boss 出场波次
func is_boss_spawn_wave(wave: int) -> bool:
	return wave == boss_prerequisite_waves + 1


## 获取 HP 倍率
func get_hp_multiplier(wave: int, scale_per_wave: float = 0.2) -> float:
	return 1.0 + (wave - 1) * scale_per_wave


## 获取速度增量
func get_speed_bonus(wave: int, speed_per_wave: float = 6.0) -> float:
	return (wave - 1) * speed_per_wave


## 学校副本默认波次配置
static func school_default() -> WaveConfig:
	var cfg := WaveConfig.new()
	cfg.wave_number = 1
	cfg.base_enemy_count = 2
	cfg.extra_enemies_per_wave = 1
	cfg.elite_interval = 3
	cfg.has_ranged = true
	cfg.ranged_count_base = 0
	cfg.ranged_extra_interval = 3
	cfg.boss_prerequisite_waves = 5
	cfg.wave_duration = 30.0
	cfg.spawn_interval = 1.5
	cfg.difficulty_scale = 1.3
	return cfg


## Boss 战波次配置
static func boss_wave_default() -> WaveConfig:
	var cfg := WaveConfig.new()
	cfg.wave_number = 6
	cfg.is_boss_wave = true
	cfg.boss_id = "boss_sato"
	cfg.wave_duration = 30.0
	cfg.spawn_interval = 1.5
	return cfg
