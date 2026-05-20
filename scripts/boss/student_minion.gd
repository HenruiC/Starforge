class_name StudentMinion
extends Enemy

## 学生小怪 — 第三乐章召唤的白色方块
##
## 继承 Enemy，覆盖死亡行为：
## - 白色/灰白外观由 .tscn 提供，16x24 竖长方形，0.7x scale
## - HP 15，移速 140px/s，接触伤害 8
## - 死亡时静默消散（无粒子，仅 modulate.a→0 + scale→0.5 收缩）
## - Boss 死亡/第四乐章转换时自动消散

func _ready() -> void:
	# 使用 .tscn 提供的 Sprite、HitFlash、ContactArea 等子节点
	# Enemy._ready() 会创建 AI 控制器 + 视觉状态机
	super._ready()

	# 更新 HP 初始值（.tscn 中 export 的 max_health=15）
	_health = max_health

	# 连接 Boss 信号
	EventBus.boss_phase_changed.connect(_on_boss_phase_changed)
	EventBus.boss_defeated.connect(_on_boss_defeated)

	# 加入学生组
	add_to_group("student_minion")

## 覆盖 Enemy._build_visual() — 不替换 Sprite
## .tscn 已提供正确的白色外观（16x24, 0.7 scale），不需要 EnemyVisualFactory 重建
func _build_visual() -> void:
	sprite = get_node_or_null("Sprite") as ColorRect
	if sprite:
		sprite.color = Color(0.85, 0.85, 0.8, 1.0)
		sprite.size = Vector2(16, 24)
		sprite.scale = Vector2(0.7, 0.7)

# --------------------------------------------------------------------------
# 消散行为
# --------------------------------------------------------------------------

## 被哨声召回 — 静默消散（无粒子）
func dissipate() -> void:
	if is_dead:
		return
	is_dead = true

	# 停住
	velocity = Vector2.ZERO

	# 收缩 + 淡出
	var t: Tween = create_tween()
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, 0.5)
	if sprite:
		t.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.5)

	await t.finished
	queue_free()

# --------------------------------------------------------------------------
# Boss 信号响应
# --------------------------------------------------------------------------

## 第四乐章开始时所有学生消散
func _on_boss_phase_changed(phase: int, _phase_name: String) -> void:
	if phase == 4:  # 第四乐章
		_dissipate_safe()

## Boss 死亡时所有学生消散
func _on_boss_defeated() -> void:
	_dissipate_safe()

func _dissipate_safe() -> void:
	if is_inside_tree() and not is_dead:
		dissipate()

# --------------------------------------------------------------------------
# 死亡覆盖 — 无粒子消散
# --------------------------------------------------------------------------

func _die(killer: CombatUnit = null) -> void:
	if is_dead:
		return
	super._die(killer)

	# 学生不算击杀分数（emit 0 score）
	EventBus.enemy_killed.emit(global_position, 0)
	# 但仍发射 filtered 信号用于 MissionTriggerManager kill counting
	EventBus.enemy_killed_filtered.emit(global_position, 2, false, false, false)

	# 静默消散：无粒子，仅收缩
	if sprite:
		var t: Tween = create_tween()
		t.set_parallel(true)
		t.tween_property(sprite, "modulate:a", 0.0, 0.3)
		t.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.3)
		t.chain().tween_callback(queue_free)
	else:
		queue_free()
