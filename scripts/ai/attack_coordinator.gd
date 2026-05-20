class_name AttackCoordinator
extends Node

## 攻击协调器 — 全局单例（必须注册为 Autoload）
##
## 在 Project → Project Settings → Autoload 中注册此脚本，
## 节点名设为 "AttackCoordinator"。
##
## 协调所有敌人的攻击时序，确保：
## 1. 同帧近战攻击者 ≤ MAX_SIMULTANEOUS_MELEE
## 2. 超出限制的敌人在 60px 外排队等待
## 3. 远程敌人优先攻击未被近战纠缠的玩家位置
##
## 使用方式：在 Project Settings → Autoload 中注册。

# --------------------------------------------------------------------------
# 常量
# --------------------------------------------------------------------------

## 最大同时近战攻击者数
const MAX_SIMULTANEOUS_MELEE := 3
## 排队等待距离（px）
const QUEUE_DISTANCE := 60.0
## 判断"正在被近战攻击"的半径（px）
const MELEE_PRESSURE_RADIUS := 40.0

# --------------------------------------------------------------------------
# 运行时状态
# --------------------------------------------------------------------------

## 当前在前摇 / 伤害帧中的近战攻击者
var _active_attackers: Array[Node] = []
## 等待队列（按优先级排序）
var _attack_queue: Array[Node] = []
## 玩家位置（由 AI 控制器每帧更新）
var _player_pos: Vector2 = Vector2.ZERO

# --------------------------------------------------------------------------
# 公共接口
# --------------------------------------------------------------------------

## 敌人请求注册一次近战攻击。
## 返回 true = 允许攻击，false = 排队等待（敌人应停在 QUEUE_DISTANCE 外）。
func register_attack(unit: Node) -> bool:
	if _active_attackers.size() < MAX_SIMULTANEOUS_MELEE:
		_active_attackers.append(unit)
		return true

	# 达到上限 → 加入优先级队列
	_insert_into_queue(unit)
	return false

## 敌人攻击完成（进入硬直或恢复移动时调用）
func finish_attack(unit: Node) -> void:
	_active_attackers.erase(unit)
	_attack_queue.erase(unit)
	_dequeue_next()

## 敌人攻击被取消（受击死亡 / 眩晕 / 强制位移）
func cancel_attack(unit: Node) -> void:
	_active_attackers.erase(unit)
	_attack_queue.erase(unit)

## 获取当前活跃的近战攻击者数量
func get_active_melee_count() -> int:
	return _active_attackers.size()

## 玩家是否正在被近战攻击（用于远程敌人调整行为）
func is_player_under_melee_pressure() -> bool:
	return _active_attackers.size() >= 1

## 获取排队位置（0 = 下一个, -1 = 不在队列中）
func get_queue_position(unit: Node) -> int:
	return _attack_queue.find(unit)

## 更新玩家位置（由 GameManager 或 AI 控制器调用）
func update_player_position(pos: Vector2) -> void:
	_player_pos = pos

## 清除所有状态（波次切换 / Boss 战结束时调用）
func reset_all() -> void:
	_active_attackers.clear()
	_attack_queue.clear()

# --------------------------------------------------------------------------
# 内部
# --------------------------------------------------------------------------

func _dequeue_next() -> void:
	if _attack_queue.is_empty():
		return
	if _active_attackers.size() >= MAX_SIMULTANEOUS_MELEE:
		return

	var next_unit: Node = _attack_queue.pop_front()
	_active_attackers.append(next_unit)

	# 通知排队敌人可以攻击了（通过 EventBus 或直接调用）
	if next_unit.has_method("_on_attack_granted"):
		next_unit._on_attack_granted()
	elif next_unit.has_node("AIBehaviorController"):
		var ai: AIBehaviorController = next_unit.get_node("AIBehaviorController") as AIBehaviorController
		if ai:
			pass  # AI controller 会在下一帧尝试攻击

## 优先级排序插入（距离玩家越近 + 精英 > 普通）
func _insert_into_queue(unit: Node) -> void:
	var priority := _calculate_priority(unit)
	for i in _attack_queue.size():
		if _calculate_priority(_attack_queue[i]) < priority:
			_attack_queue.insert(i, unit)
			return
	_attack_queue.append(unit)

## 计算攻击优先级（高 = 更优先）
func _calculate_priority(unit: Node) -> float:
	var p := 0.0

	# 距离玩家近 → 高优先级
	if unit is Node2D:
		var dist: float = unit.global_position.distance_to(_player_pos)
		p += maxf(500.0 - dist, 0.0) * 1.0

	# 精英 → +100 优先级
	if unit.has_method("get_stat"):
		if unit.get_stat("is_elite", 0.0) > 0.5:
			p += 100.0

	# 相位偏移 → 微小随机扰动（避免同优先级竞争者频繁交换位置）
	if _attack_queue.size() > 0:
		p += randf_range(0.0, 10.0)

	return p
