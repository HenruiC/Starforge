class_name MissionManager
extends Node

# 副本任务系统 — 天赋猎人·学校试炼

signal mission_completed(mission_id: String)
signal stage_cleared(stage: int)
signal boss_spawned(boss_name: String)

var _current_stage: int = 0
var _stage_missions: Array[Dictionary] = []
var _total_kills: int = 0
var _elite_kills: int = 0
var _classrooms_cleared: int = 0
var _game_manager: Node = null

func init(gm: Node) -> void:
	_game_manager = gm
	_define_stages()

func _define_stages() -> void:
	# 阶段1: 生存 — 在操场存活60秒
	_stage_missions.append({
		"stage": 1,
		"title": "第一试炼: 操场突围",
		"narrative": "末日降临，学校被怪物包围。先活下来。",
		"objectives": [
			{"id": "survive_60s", "text": "在操场存活60秒", "type": "timer", "target": 60.0, "progress": 0.0},
		],
		"reward": "+1武器选择"
	})

	# 阶段2: 清理教室
	_stage_missions.append({
		"stage": 2,
		"title": "第二试炼: 教室清剿",
		"narrative": "学生们被困在教室里。清理出一条生路。",
		"objectives": [
			{"id": "kill_30", "text": "击杀30个怪物", "type": "count", "target": 30, "progress": 0},
			{"id": "clear_2_rooms", "text": "清理2间教室(破坏所有课桌)", "type": "count", "target": 2, "progress": 0},
		],
		"reward": "+1技能升级"
	})

	# 阶段3: Boss战
	_stage_missions.append({
		"stage": 3,
		"title": "第三试炼: 操场Boss",
		"narrative": "一个强大的变异体出现在操场。击败它。",
		"objectives": [
			{"id": "kill_boss", "text": "击败操场Boss", "type": "count", "target": 1, "progress": 0},
		],
		"reward": "副本完成!"
	})

func get_current_stage() -> int:
	return _current_stage + 1

func get_stage_title() -> String:
	if _current_stage < _stage_missions.size():
		return _stage_missions[_current_stage]["title"]
	return ""

func get_stage_narrative() -> String:
	if _current_stage < _stage_missions.size():
		return _stage_missions[_current_stage]["narrative"]
	return ""

func get_objectives() -> Array:
	if _current_stage < _stage_missions.size():
		return _stage_missions[_current_stage]["objectives"]
	return []

func get_objective_progress() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for obj in get_objectives():
		result.append({
			"text": obj["text"],
			"progress": obj["progress"],
			"target": obj["target"],
			"done": obj["progress"] >= obj["target"]
		})
	return result

func notify_kill(is_elite: bool = false, is_boss: bool = false) -> void:
	_total_kills += 1
	if is_elite: _elite_kills += 1
	_update_progress("kill_30", 1)
	if is_boss: _update_progress("kill_boss", 1)

func notify_desk_destroyed() -> void:
	_classrooms_cleared += 1
	# 每5张课桌算1间教室
	_update_progress("clear_2_rooms", 1)

func notify_timer(delta: float) -> void:
	_update_progress("survive_60s", delta, true)

func _update_progress(id: String, amount: float, is_float: bool = false) -> void:
	if _current_stage >= _stage_missions.size(): return
	for obj in _stage_missions[_current_stage]["objectives"]:
		if obj["id"] == id and obj["progress"] < obj["target"]:
			if is_float:
				obj["progress"] += amount
			else:
				obj["progress"] += int(amount)
			_check_stage_complete()
			return

func _check_stage_complete() -> void:
	for obj in _stage_missions[_current_stage]["objectives"]:
		if obj["progress"] < obj["target"]: return
	_stage_cleared()

func _stage_cleared() -> void:
	stage_cleared.emit(_current_stage + 1)
	_current_stage += 1

	if _current_stage >= _stage_missions.size():
		mission_completed.emit("school_survival")
	elif _current_stage == 2:  # 阶段3: Spawn Boss
		boss_spawned.emit("操场变异体")
