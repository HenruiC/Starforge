class_name BuffComponent
extends Node

## Buff 组件 — 管理有时限的 StatModifier 叠加与生命周期
##
## 每个 Buff 是一组 StatModifier 的容器，挂载在 CombatUnit 下。
## Buff 过期时自动卸载其所有修改器。

signal buff_applied(buff_id: String, remaining: float)
signal buff_removed(buff_id: String)
signal buff_expired(buff_id: String)

## 拥有此组件的 CombatUnit（由 setup() 设置）
var owner_unit: Node = null

## 内部 Buff 条目
class BuffEntry:
	var buff_id: String
	var remaining: float
	var duration: float
	var modifiers: Array[StatModifier]
	var stacked_count: int  # 叠层计数（对 STACK 类型）
	var is_debuff: bool

	func is_expired() -> bool:
		return duration > 0.0 and remaining <= 0.0

## 活跃 Buff 列表
var _active_buffs: Array[BuffEntry] = []

## 用于 tick (每帧 delta 给时间)
func setup(unit: Node) -> void:
	owner_unit = unit

# --------------------------------------------------------------------------
# 公开 API
# --------------------------------------------------------------------------

## 应用一个 Buff（REFRESH 策略：同 ID 自动刷新）
##   buff_id:     Buff 唯一标识
##   modifiers:   该 Buff 包含的属性修改器数组
##   duration:    持续时间（0 = 永久）
##   source:      施加者（可选）
##   is_debuff:   是否为负面效果
func apply(buff_id: String, modifiers: Array[StatModifier], duration: float = 0.0, source: Node = null, is_debuff: bool = false) -> void:
	# 先移除同 ID 的旧 Buff（REFRESH 策略）
	var existing := _find_entry(buff_id)
	if existing:
		_remove_entry(existing)

	var entry := BuffEntry.new()
	entry.buff_id = buff_id
	entry.duration = duration
	entry.remaining = duration if duration > 0.0 else -1.0
	entry.modifiers = modifiers
	entry.stacked_count = 1
	entry.is_debuff = is_debuff

	# 将修改器加入 StatsComponent
	if owner_unit and owner_unit.has_method("get_stat"):
		var stats_node = owner_unit.get_node_or_null("StatsComponent") if owner_unit.has_node("StatsComponent") else null
		if stats_node and stats_node is StatsComponent:
			for mod in modifiers:
				stats_node.add_modifier(mod)

	_active_buffs.append(entry)
	buff_applied.emit(buff_id, entry.remaining)

## 移除指定 Buff
func remove(buff_id: String) -> void:
	var entry := _find_entry(buff_id)
	if entry:
		_remove_entry(entry)

## 清除所有 Buff
func clear_all() -> void:
	while _active_buffs.size() > 0:
		var entry := _active_buffs[0]
		_remove_entry(entry)

## 每帧调用（由 CombatUnit 或外部驱动）
func tick(delta: float) -> void:
	var i := _active_buffs.size() - 1
	while i >= 0:
		var entry := _active_buffs[i]
		if entry.duration > 0.0:
			entry.remaining -= delta
			if entry.remaining <= 0.0:
				_remove_entry(entry)
				buff_expired.emit(entry.buff_id)
		i -= 1

## 检查是否存在指定 Buff
func has_buff(buff_id: String) -> bool:
	return _find_entry(buff_id) != null

## 获取指定 Buff 的剩余时间
func get_remaining(buff_id: String) -> float:
	var entry := _find_entry(buff_id)
	return entry.remaining if entry else -1.0

## 获取当前活跃的 Buff ID 列表
func get_active_buff_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in _active_buffs:
		ids.append(entry.buff_id)
	return ids

# --------------------------------------------------------------------------
# 内部方法
# --------------------------------------------------------------------------

func _find_entry(buff_id: String) -> BuffEntry:
	for entry in _active_buffs:
		if entry.buff_id == buff_id:
			return entry
	return null

func _remove_entry(entry: BuffEntry) -> void:
	# 从 StatsComponent 移除修改器
	if owner_unit and owner_unit.has_method("get_stat"):
		var stats_node = owner_unit.get_node_or_null("StatsComponent") if owner_unit.has_node("StatsComponent") else null
		if stats_node and stats_node is StatsComponent:
			for mod in entry.modifiers:
				stats_node.remove_modifier(mod)

	_active_buffs.erase(entry)
	buff_removed.emit(entry.buff_id)
