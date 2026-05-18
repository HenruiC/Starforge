class_name MissionManager
extends Node

# 学校副本任务系统 — 陶德·自由探索 + 小岛·叙事驱动
# 动线: 校门→主干道→庭院→教学楼→连廊→体育馆Boss

signal stage_cleared(stage: int)
signal boss_spawned(boss_name: String)

var _stage: int = 0
var _missions: Array[Dictionary] = []

func init() -> void:
	# ===== 阶段1: 校门→主干道(强制引导) =====
	_missions.append({
		"stage": 1,
		"title": "第一试炼 · 踏入废校",
		"narrator": "主角",
		"narrative": "校门上的锁已经锈蚀。推开门，那条通往教学楼的路还在——只是路上多了不该有的东西。",
		"objectives": [
			{"id": "reach_courtyard", "text": "沿主干道抵达中央庭院", "hint": "向北走，别停", "target": 1, "progress": 0},
			{"id": "survive_wave1", "text": "在庭院击退第一波怪物", "hint": "开阔地适合风筝", "target": 8, "progress": 0},
		]
	})

	# ===== 阶段2: 教学楼自由探索(陶德: 左右任选) =====
	_missions.append({
		"stage": 2,
		"title": "第二试炼 · 沉默的教室",
		"narrator": "系统",
		"narrative": "左右两栋教学楼。哪边先开始？课桌下有学生留下的物资，但教室里不只有课桌。",
		"objectives": [
			{"id": "kill_20", "text": "击杀20个怪物", "hint": "走廊窄，注意走位", "target": 20, "progress": 0},
			{"id": "clear_desks", "text": "清理8张课桌(收集物资)", "hint": "教室里的黄色方块", "target": 8, "progress": 0},
			{"id": "visit_both_wings", "text": "探索左右两栋教学楼", "hint": "连廊连接两侧", "target": 1, "progress": 0},
		]
	})

	# ===== 阶段3: 连廊(必经+精英) =====
	_missions.append({
		"stage": 3,
		"title": "第三试炼 · 连廊的守护者",
		"narrator": "主角",
		"narrative": "连廊——两栋楼之间唯一的通道。一个精英怪守在连廊中央。它比别的怪物更大、更快、更愤怒。它曾经是这里的体育老师。",
		"objectives": [
			{"id": "kill_elite", "text": "击败连廊精英怪", "hint": "红色+巨大=精英", "target": 1, "progress": 0},
			{"id": "reach_gym_path", "text": "穿过连廊到达体育馆方向", "hint": "连廊尽头向北", "target": 1, "progress": 0},
		]
	})

	# ===== 阶段4: 体育馆Boss(高潮) =====
	_missions.append({
		"stage": 4,
		"title": "最终试炼 · 体育馆的变异体",
		"narrator": "???",
		"narrative": "体育馆的门从里面被撞开了。它太大了，不像任何一种你见过的生物。\n\n它曾经是这里的校长。现在它只是——一团需要被击败的东西。",
		"objectives": [
			{"id": "kill_boss", "text": "击败体育馆Boss", "hint": "保持距离，利用技能", "target": 1, "progress": 0},
		]
	})

func notify_kill(is_elite: bool = false) -> void:
	_progress("kill_20", 1)
	_progress("survive_wave1", 1)
	if is_elite: _progress("kill_elite", 1)

func notify_desk() -> void:
	_progress("clear_desks", 1)

func notify_reach_zone(zone: String) -> void:
	match zone:
		"courtyard": _progress("reach_courtyard", 1)
		"connector": _progress("visit_both_wings", 1)
		"gym_path": _progress("reach_gym_path", 1)

func notify_boss_kill() -> void:
	_progress("kill_boss", 1)

func _progress(id: String, amount: int) -> void:
	if _stage >= _missions.size(): return
	for obj in _missions[_stage]["objectives"]:
		if obj["id"] == id and int(obj["progress"]) < int(obj["target"]):
			obj["progress"] = int(obj["progress"]) + amount
			_check_done()

func _check_done() -> void:
	for obj in _missions[_stage]["objectives"]:
		if int(obj["progress"]) < int(obj["target"]): return
	_stage += 1
	stage_cleared.emit(_stage)
	if _stage == 4:
		boss_spawned.emit("体育馆变异体")

func get_title() -> String:
	return _missions[_stage]["title"] if _stage < _missions.size() else ""

func get_narrative() -> String:
	var m := _missions[_stage]
	return m["narrator"] + ": \"" + m["narrative"] + "\"" if _stage < _missions.size() else ""

func get_objectives() -> Array:
	return _missions[_stage]["objectives"] if _stage < _missions.size() else []

func get_current_stage() -> int:
	return _stage + 1
