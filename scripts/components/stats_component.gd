class_name StatsComponent
extends Node

## 属性组件 — 管理所有战斗数值的存取与修改器叠加
##
## 公式：final = (base + sum_FLAT) * (1 + sum_PERCENT_ADD) * product(1 + PERCENT_MUL)
##
## StatModifier 通过 add_modifier / remove_modifier 接口接入。
## BuffComponent 通过此接口间接修改属性，两侧解耦。

signal stat_changed(stat_name: String, new_value: float)

# === 标准属性名常量 ===
const MAX_HEALTH := "max_health"
const MOVE_SPEED := "move_speed"
const ATTACK_POWER := "attack_power"
const DEFENSE := "defense"
const ATTACK_RANGE := "attack_range"
const ATTACK_SPEED := "attack_speed"
const CRIT_CHANCE := "crit_chance"
const CRIT_DAMAGE := "crit_damage"
const PROJECTILE_SPEED := "projectile_speed"
const KNOCKBACK_RESIST := "knockback_resist"

# === 基础属性值字典 ===
var _base_stats: Dictionary = {}

# === 活跃的修改器列表 ===
var _modifiers: Array[StatModifier] = []

# --------------------------------------------------------------------------
# 基础属性存取
# --------------------------------------------------------------------------

## 设置基础值
func set_base(stat_name: String, value: float) -> void:
	_base_stats[stat_name] = value
	stat_changed.emit(stat_name, get_stat(stat_name))

## 批量设置基础值（从 StatsResource 或字典加载）
func set_bases(values: Dictionary) -> void:
	for key in values:
		_base_stats[key] = values[key]
	# 只发一次通用信号
	stat_changed.emit("", 0.0)

## 读取基础值
func get_base(stat_name: String, default: float = 0.0) -> float:
	return _base_stats.get(stat_name, default)

# --------------------------------------------------------------------------
# 最终值计算（带修改器叠加）
# --------------------------------------------------------------------------

## 获取最终属性值（基础值 + 所有修改器叠加）
func get_stat(stat_name: String, default: float = 0.0) -> float:
	var base: float = _base_stats.get(stat_name, default)
	var flat_sum := 0.0
	var percent_add_sum := 0.0
	var percent_mul_prod := 1.0

	for mod in _modifiers:
		if mod.stat_name != stat_name:
			continue
		match mod.mod_type:
			StatModifier.ModType.FLAT:
				flat_sum += mod.value
			StatModifier.ModType.PERCENT_ADD:
				percent_add_sum += mod.value
			StatModifier.ModType.PERCENT_MUL:
				percent_mul_prod *= (1.0 + mod.value)

	return (base + flat_sum) * (1.0 + percent_add_sum) * percent_mul_prod

## 便捷方法 — 一次性获取多个属性值
func get_stats(stat_names: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for name in stat_names:
		result[name] = get_stat(name)
	return result

# --------------------------------------------------------------------------
# 修改器管理
# --------------------------------------------------------------------------

## 添加修改器
func add_modifier(mod: StatModifier) -> void:
	_modifiers.append(mod)
	stat_changed.emit(mod.stat_name, get_stat(mod.stat_name))

## 移除单个修改器
func remove_modifier(mod: StatModifier) -> void:
	_modifiers.erase(mod)
	stat_changed.emit(mod.stat_name, get_stat(mod.stat_name))

## 移除指定来源的所有修改器
func remove_modifiers_by_source(source_id: String) -> void:
	var affected: Array[String] = []
	_modifiers = _modifiers.filter(func(m: StatModifier) -> bool:
		if m.source_id == source_id:
			if m.stat_name not in affected:
				affected.append(m.stat_name)
			return false
		return true
	)
	for stat_name in affected:
		stat_changed.emit(stat_name, get_stat(stat_name))

## 移除所有修改器
func clear_modifiers() -> void:
	_modifiers.clear()
	stat_changed.emit("", 0.0)

## 获取当前活跃的修改器列表（副本，不暴露内部数组引用）
func get_modifiers() -> Array[StatModifier]:
	return _modifiers.duplicate()
