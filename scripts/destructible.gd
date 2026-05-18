class_name Destructible
extends StaticBody2D

@export var max_health: int = 20
@export var drop_xp: int = 25
@export var object_name: String = "树"
@export var object_color: Color = Color(0.15, 0.55, 0.15)
@export var indestructible: bool = false

var _health: int = 20

@onready var sprite: ColorRect = $Sprite
@onready var hp_bar: ProgressBar = $HealthBar if has_node("HealthBar") else null

func _ready() -> void:
	_health = max_health
	sprite.color = object_color
	add_to_group("destructible")

func take_damage(amount: int) -> void:
	if indestructible:
		# 不可破坏物只播放弹回火花，不掉血
		CombatFeedback.hit_particles(global_position, 3, Color(0.7, 0.7, 0.7))
		return
	_health = max(_health - amount, 0)
	_update_hp()

	# 受击闪烁
	sprite.modulate = Color.WHITE
	var t := create_tween()
	t.tween_property(sprite, "modulate", object_color, 0.1)
	t.tween_callback(func():
		if _health <= 0: _destroy()
	)

	if _health <= 0:
		_destroy()

func _destroy() -> void:
	# 破坏粒子
	CombatFeedback.hit_particles(global_position, 6, Color(0.5, 0.4, 0.3))

	# 通知任务系统 (课桌破坏算教室清理进度)
	if object_name == "课桌":
		var gm := get_tree().get_first_node_in_group("game_manager")
		if gm and gm.has_method("notify_desk"):
			gm.notify_desk()

	# 只有树木类给经验 (drop_xp > 0 且不是建筑)
	if drop_xp > 0 and object_name not in ["墙壁", "课桌"]:
		CombatFeedback.damage_number(global_position, drop_xp, false, true)
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0 and players[0].has_method("gain_exp"):
			players[0].gain_exp(drop_xp)

	# 动画
	var t := create_tween().set_parallel(true)
	t.tween_property(sprite, "scale", Vector2(0.1, 0.1), 0.3)
	t.tween_property(sprite, "modulate:a", 0.0, 0.25)
	t.chain().tween_callback(queue_free)

func _update_hp() -> void:
	if hp_bar == null: return
	var ratio: float = float(_health) / float(max_health) * 100.0
	hp_bar.value = ratio
	hp_bar.visible = ratio < 100.0
