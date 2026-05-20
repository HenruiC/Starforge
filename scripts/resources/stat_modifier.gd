class_name StatModifier
extends Resource

## 属性修改器 — 描述对某个属性的单一修改操作
##
## 三种修改类型：
##   FLAT:       直接加/减（base + sum_FLAT）
##   PERCENT_ADD: 百分比加/减（(1 + sum_PERCENT_ADD)）
##   PERCENT_MUL: 百分比乘（product(1 + PERCENT_MUL)）
##
## 最终公式：final = (base + sum_FLAT) * (1 + sum_PERCENT_ADD) * product(1 + PERCENT_MUL)

enum ModType { FLAT, PERCENT_ADD, PERCENT_MUL }

## 目标属性名称（如 "max_health", "move_speed", "attack_power"）
@export var stat_name: String = ""

## 修改类型
@export var mod_type: ModType = ModType.FLAT

## 修改值（FLAT：绝对值；PERCENT_ADD/PERCENT_MUL：小数，如 0.2 = +20%）
@export var value: float = 0.0

## 持续时间（0 = 永久生效，直到被主动移除）
@export var duration: float = 0.0

## 来源标识（如 buff_id "power_up"），用于去重/批量移除
@export var source_id: String = ""
