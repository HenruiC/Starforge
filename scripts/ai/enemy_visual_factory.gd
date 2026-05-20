class_name EnemyVisualFactory
extends RefCounted

## 敌人视觉工厂 — 用 ColorRect 拼装敌人外形
##
## 设计原则（宫崎英高 2.3—2.4 节）：
## - 敌人类型通过**轮廓/形状**区分（而非仅颜色）
## - 竖长 = 近战（如人形）
## - 横宽 = 远程（如投掷姿态）
## - 大块 + 光环 = 精英
## - 复杂组合 = Boss
##
## 所有方法为静态工厂方法，返回节点树供 Enemy 挂载使用。

# --------------------------------------------------------------------------
# 颜色常量
# --------------------------------------------------------------------------

const COLOR_MELEE_BODY := Color(0.545, 0.451, 0.333, 1.0)   # #8B7355 灰褐
const COLOR_RANGED_BODY := Color(0.2, 0.545, 0.263, 1.0)    # 暗绿
const COLOR_ELITE_GLOW := Color(0.7, 0.2, 0.9, 0.25)         # 紫光环
const COLOR_BOSS_BODY := Color(0.4, 0.1, 0.05, 1.0)           # 暗红
const COLOR_BOSS_GLOW := Color(1.0, 0.5, 0.1, 0.35)           # 橙红光环

# --------------------------------------------------------------------------
# 工厂方法
# --------------------------------------------------------------------------

## 根据敌人类型创建 ColorRect 节点树
## 返回主 ColorRect（可作为 enemy.sprite 的替代或子节点）
static func create_visual(enemy: Node2D, is_ranged: bool, is_elite: bool, is_boss: bool) -> Node:
	if is_boss:
		return _build_boss(enemy)
	if is_elite:
		if is_ranged:
			return _build_elite_ranged(enemy)
		return _build_elite_melee(enemy)
	if is_ranged:
		return _build_ranged(enemy)
	return _build_melee(enemy)

# --------------------------------------------------------------------------
# 近战 — 竖长方形（宽 18，高 28）
# --------------------------------------------------------------------------

static func _build_melee(parent: Node2D) -> ColorRect:
	var body := ColorRect.new()
	body.name = "Sprite"
	body.color = COLOR_MELEE_BODY
	body.size = Vector2(18, 28)
	body.position = Vector2(-9, -14)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(body)
	return body

# --------------------------------------------------------------------------
# 远程 — 横宽 + 两侧小方块（投掷姿态）
# --------------------------------------------------------------------------

static func _build_ranged(parent: Node2D) -> ColorRect:
	var body := ColorRect.new()
	body.name = "Sprite"
	body.color = COLOR_RANGED_BODY
	body.size = Vector2(28, 16)
	body.position = Vector2(-14, -8)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(body)

	# 左侧"手臂"
	var arm_l := ColorRect.new()
	arm_l.name = "ArmLeft"
	arm_l.color = Color(0.3, 0.45, 0.35, 1.0)
	arm_l.size = Vector2(6, 4)
	arm_l.position = Vector2(-20, -2)
	arm_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(arm_l)

	# 右侧"手臂"
	var arm_r := ColorRect.new()
	arm_r.name = "ArmRight"
	arm_r.color = Color(0.3, 0.45, 0.35, 1.0)
	arm_r.size = Vector2(6, 4)
	arm_r.position = Vector2(14, -2)
	arm_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(arm_r)

	return body

# --------------------------------------------------------------------------
# 精英近战 — 大竖长方 + 紫光环 + 不规则突起
# --------------------------------------------------------------------------

static func _build_elite_melee(parent: Node2D) -> ColorRect:
	var body := ColorRect.new()
	body.name = "Sprite"
	body.color = Color(0.5, 0.3, 0.7, 1.0)  # 紫
	body.size = Vector2(28, 42)
	body.position = Vector2(-14, -21)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(body)

	# 紫光环
	var glow := ColorRect.new()
	glow.name = "Glow"
	glow.color = COLOR_ELITE_GLOW
	glow.size = Vector2(40, 54)
	glow.position = Vector2(-20, -27)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(glow)
	parent.move_child(glow, 0)

	# 不规则突起（左肩）
	var spike := ColorRect.new()
	spike.name = "Spike"
	spike.color = Color(0.6, 0.3, 0.8, 1.0)
	spike.size = Vector2(8, 8)
	spike.position = Vector2(-20, -10)
	spike.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spike)

	return body

# --------------------------------------------------------------------------
# 精英远程 — 大横宽 + 紫光环 + 大手臂
# --------------------------------------------------------------------------

static func _build_elite_ranged(parent: Node2D) -> ColorRect:
	var body := ColorRect.new()
	body.name = "Sprite"
	body.color = Color(0.3, 0.5, 0.4, 1.0)  # 暗绿偏紫
	body.size = Vector2(42, 24)
	body.position = Vector2(-21, -12)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(body)

	# 左臂
	var arm_l := ColorRect.new()
	arm_l.name = "ArmLeft"
	arm_l.color = Color(0.35, 0.5, 0.4, 1.0)
	arm_l.size = Vector2(10, 6)
	arm_l.position = Vector2(-31, 0)
	arm_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(arm_l)

	# 右臂
	var arm_r := ColorRect.new()
	arm_r.name = "ArmRight"
	arm_r.color = Color(0.35, 0.5, 0.4, 1.0)
	arm_r.size = Vector2(10, 6)
	arm_r.position = Vector2(21, 0)
	arm_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(arm_r)

	# 紫光环
	var glow := ColorRect.new()
	glow.name = "Glow"
	glow.color = COLOR_ELITE_GLOW
	glow.size = Vector2(54, 36)
	glow.position = Vector2(-27, -18)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(glow)
	parent.move_child(glow, 0)

	return body

# --------------------------------------------------------------------------
# Boss — 大主体 + 四肢体 + 光环
# --------------------------------------------------------------------------

static func _build_boss(parent: Node2D) -> ColorRect:
	# 主身体
	var body := ColorRect.new()
	body.name = "Sprite"
	body.color = COLOR_BOSS_BODY
	body.size = Vector2(48, 64)
	body.position = Vector2(-24, -32)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(body)

	# 左臂
	var arm_l := ColorRect.new()
	arm_l.name = "ArmLeft"
	arm_l.color = Color(0.35, 0.08, 0.04, 1.0)
	arm_l.size = Vector2(10, 24)
	arm_l.position = Vector2(-34, -12)
	arm_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(arm_l)

	# 右臂
	var arm_r := ColorRect.new()
	arm_r.name = "ArmRight"
	arm_r.color = Color(0.35, 0.08, 0.04, 1.0)
	arm_r.size = Vector2(10, 24)
	arm_r.position = Vector2(24, -12)
	arm_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(arm_r)

	# 双腿（用窄条表示）
	for i in 2:
		var leg := ColorRect.new()
		leg.name = "Leg" + str(i)
		leg.color = Color(0.3, 0.07, 0.03, 1.0)
		leg.size = Vector2(10, 14)
		leg.position = Vector2(-12 + i * 16, 20)
		leg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(leg)

	# Boss 光环
	var glow := ColorRect.new()
	glow.name = "Glow"
	glow.color = COLOR_BOSS_GLOW
	glow.size = Vector2(64, 80)
	glow.position = Vector2(-32, -40)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(glow)
	parent.move_child(glow, 0)

	return body
