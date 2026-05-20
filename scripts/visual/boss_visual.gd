class_name BossVisual
extends RefCounted

## Boss 五部件 ColorRect 拼装工厂 — TASK-V01
##
## 静态工厂方法创建本体+口哨+光环+双臂的完整视觉组合。
## 所有部件均为 ColorRect，不需要外部资源。
##
## 使用方式：
##   var visual_root := BossVisual.create()
##   boss.add_child(visual_root)
##   然后通过 visual_root.get_node("Body") 等访问部件

# === 部件名称常量（与 get_node() 配合使用） ===
const NAME_AURA := "Aura"
const NAME_BODY := "Body"
const NAME_WHISTLE := "Whistle"
const NAME_ARM_L := "ArmL"
const NAME_ARM_R := "ArmR"
const NAME_CORE := "CoreHighlight"
const NAME_HIT_FLASH := "HitFlash"

# === 颜色常量 ===
# 主体：深紫灰（Phase E 指定）
const COLOR_BODY := Color(0.28, 0.20, 0.30, 1.0)
# 口哨：银色（最标志性的视觉锚点）
const COLOR_WHISTLE := Color(0.6, 0.6, 0.65, 1.0)
# 光环默认：橙色（第一乐章热身）
const COLOR_AURA_DEFAULT := Color(1.0, 0.5, 0.1, 0.15)
# 核心弱点：高亮红（第四乐章暴露）
const COLOR_CORE := Color(1.0, 0.2, 0.05, 0.0)

# === 尺寸常量 ===
# Body：纵向 72×96 — 宽肩站姿
const BODY_SIZE := Vector2(72, 96)
# Whistle：8×8 — 小方块挂在颈部
const WHISTLE_SIZE := Vector2(8, 8)
# Aura：104×104 — 比主体大一圈
const AURA_SIZE := Vector2(104, 104)
# ArmL/ArmR：横向 48×16 — 短而宽的手臂
const ARM_SIZE := Vector2(48, 16)
# CoreHighlight：16×16 — 胸口弱点标记
const CORE_SIZE := Vector2(16, 16)
# HitFlash：覆盖整体
const FLASH_SIZE := Vector2(104, 104)


## 创建 Boss 视觉根节点（包含全部七个子部件）
## 返回 Node2D — 可直接 add_child 到 Boss 的 CharacterBody2D
static func create() -> Node2D:
	var root := Node2D.new()
	root.name = "BossVisual"

	# 按 z_index 顺序添加：低 z_index 先加（在底层）
	var aura := _create_aura()
	var arm_l := _create_arm(true)
	var body := _create_body()
	var arm_r := _create_arm(false)
	var whistle := _create_whistle()
	var hit_flash := _create_hit_flash()
	var core := _create_core_highlight()

	root.add_child(aura)
	root.add_child(arm_l)
	root.add_child(body)
	root.add_child(arm_r)
	root.add_child(whistle)
	root.add_child(hit_flash)
	root.add_child(core)

	return root


## 以潜伏姿态初始化所有部件（登场前/蹲伏阴影）
static func apply_lurking_pose(visual_root: Node2D) -> void:
	var body := visual_root.get_node(NAME_BODY) as ColorRect
	var arm_l := visual_root.get_node(NAME_ARM_L) as ColorRect
	var arm_r := visual_root.get_node(NAME_ARM_R) as ColorRect

	if body:
		body.scale.y = 0.5
		body.modulate.a = 0.3
	if arm_l:
		arm_l.scale.y = 0.5
		arm_l.modulate.a = 0.3
	if arm_r:
		arm_r.scale.y = 0.5
		arm_r.modulate.a = 0.3


## 切换到战斗姿态（激活后正常站立）
static func apply_combat_pose(visual_root: Node2D) -> void:
	var body := visual_root.get_node(NAME_BODY) as ColorRect
	var arm_l := visual_root.get_node(NAME_ARM_L) as ColorRect
	var arm_r := visual_root.get_node(NAME_ARM_R) as ColorRect
	var whistle := visual_root.get_node(NAME_WHISTLE) as ColorRect

	if body:
		body.scale = Vector2.ONE
		body.modulate.a = 1.0
	if arm_l:
		arm_l.scale = Vector2.ONE
		arm_l.modulate.a = 1.0
	if arm_r:
		arm_r.scale = Vector2.ONE
		arm_r.modulate.a = 1.0
	if whistle:
		whistle.modulate.a = 1.0


# =============================================================================
# 部件工厂方法
# =============================================================================

static func _create_aura() -> ColorRect:
	var cr := ColorRect.new()
	cr.name = NAME_AURA
	cr.color = COLOR_AURA_DEFAULT
	cr.size = AURA_SIZE
	cr.position = -AURA_SIZE * 0.5
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.z_index = 0
	return cr


static func _create_body() -> ColorRect:
	var cr := ColorRect.new()
	cr.name = NAME_BODY
	cr.color = COLOR_BODY
	cr.size = BODY_SIZE
	cr.position = -BODY_SIZE * 0.5
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.z_index = 2
	return cr


static func _create_whistle() -> ColorRect:
	var cr := ColorRect.new()
	cr.name = NAME_WHISTLE
	cr.color = COLOR_WHISTLE
	cr.size = WHISTLE_SIZE
	# 位于 Body 顶部上方 4px，水平居中
	var body_half_h: float = BODY_SIZE.x * 0.5
	var body_top: float = -BODY_SIZE.y * 0.5
	cr.position = Vector2(-WHISTLE_SIZE.x * 0.5, body_top - WHISTLE_SIZE.y - 2.0)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.z_index = 3
	return cr


static func _create_arm(is_left: bool) -> ColorRect:
	var cr := ColorRect.new()
	cr.name = NAME_ARM_L if is_left else NAME_ARM_R
	cr.color = COLOR_BODY
	cr.size = ARM_SIZE
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var body_half_w: float = BODY_SIZE.x * 0.5
	var arm_half_h: float = ARM_SIZE.y * 0.5

	if is_left:
		# 左臂：Body 左侧
		cr.position = Vector2(-body_half_w - ARM_SIZE.x, -arm_half_h)
		cr.z_index = 1
		# 旋转轴在右边缘（肩膀连接处）
		cr.pivot_offset = Vector2(ARM_SIZE.x, arm_half_h)
	else:
		# 右臂：Body 右侧
		cr.position = Vector2(body_half_w, -arm_half_h)
		cr.z_index = 3
		# 旋转轴在左边缘（肩膀连接处）
		cr.pivot_offset = Vector2(0.0, arm_half_h)

	return cr


static func _create_core_highlight() -> ColorRect:
	var cr := ColorRect.new()
	cr.name = NAME_CORE
	cr.color = COLOR_CORE
	cr.size = CORE_SIZE
	cr.position = -CORE_SIZE * 0.5
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.z_index = 5
	cr.visible = false
	return cr


static func _create_hit_flash() -> ColorRect:
	var cr := ColorRect.new()
	cr.name = NAME_HIT_FLASH
	cr.color = Color(1.0, 1.0, 1.0, 0.0)
	cr.size = FLASH_SIZE
	cr.position = -FLASH_SIZE * 0.5
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.z_index = 4
	return cr
