class_name StudentMinionVisual
extends RefCounted

## 学生小怪外观工厂 — TASK-V06
##
## 灰白色调 ColorRect（24×24），比普通敌人更小更淡。
## 死亡动画：静默消散（不是爆炸）——"下课了，不需要留下痕迹"。
##
## 使用方式：
##   # 创建学生小怪身体
##   var body := StudentMinionVisual.create_body(student_node)
##   # 死亡时播放消散
##   StudentMinionVisual.play_dissipate(body)

# === 颜色/尺寸常量 ===
# 灰白 — "不是红色的敌人"
const COLOR_BODY := Color(0.85, 0.85, 0.80, 1.0)
const COLOR_FLASH := Color(1.0, 1.0, 1.0, 0.0)

const BODY_SIZE := Vector2(24, 24)
const FLASH_SIZE := Vector2(28, 28)

# 与普通敌人的视觉对比：
# | 特征   | 普通敌人   | 学生小怪      |
# | 颜色   | 灰褐       | 灰白 #D9D9CC  |
# | 尺寸   | 18×28      | 24×24         |
# | scale  | 1.0x       | 0.7x          |
# | 死亡   | 闪白+粒子  | 静默消散      |


## 创建学生小怪视觉部件并附加到父节点
## 返回 Dictionary { "body": ColorRect, "hit_flash": ColorRect }
static func create_and_attach(parent: Node) -> Dictionary:
	var body := _create_body()
	var hit_flash := _create_hit_flash()

	parent.add_child(hit_flash)
	parent.add_child(body)

	return {"body": body, "hit_flash": hit_flash}


## 仅创建身体 ColorRect（用于简单场景）
static func create_body(parent: Node) -> ColorRect:
	var body := _create_body()
	parent.add_child(body)
	return body


## 播放静默消散动画（替代死亡粒子）
##  modulate.a→0 + scale→0.5, 0.3s → queue_free
static func play_dissipate(body: ColorRect) -> void:
	if not is_instance_valid(body):
		return

	var t: Tween = body.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.set_parallel(true)
	t.tween_property(body, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	t.tween_property(body, "scale", Vector2(0.5, 0.5), 0.3).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(body.queue_free)

	# 学生不是"被杀死"——他们是"被解散"。
	# 下课了，他们不需要留下任何痕迹。


## 播放受击闪白（短暂）
static func play_hit_flash(flash_rect: ColorRect) -> void:
	if not is_instance_valid(flash_rect):
		return

	var t: Tween = flash_rect.create_tween()
	t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	t.tween_property(flash_rect, "color:a", 0.5, 0.03)
	t.tween_property(flash_rect, "color:a", 0.0, 0.06)


# =============================================================================
# Internal Factory Methods
# =============================================================================

static func _create_body() -> ColorRect:
	var cr := ColorRect.new()
	cr.name = "StudentBody"
	cr.color = COLOR_BODY
	cr.size = BODY_SIZE
	cr.position = -BODY_SIZE * 0.5
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.z_index = 2
	return cr


static func _create_hit_flash() -> ColorRect:
	var cr := ColorRect.new()
	cr.name = "StudentHitFlash"
	cr.color = COLOR_FLASH
	cr.size = FLASH_SIZE
	cr.position = -FLASH_SIZE * 0.5
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.z_index = 3
	return cr
