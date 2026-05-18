class_name MissionManager
extends Node

signal stage_cleared(stage: int)
signal boss_spawned(boss_name: String)

var _current_stage: int = 0
var _stage_missions: Array[Dictionary] = []

func init() -> void:
	_define_stages()

func _define_stages() -> void:
	_stage_missions.append({
		"stage": 1, "title": "第一试炼: 操场突围",
		"narrative": "学校被怪物包围。先活下来。",
		"objectives": [
			{"id": "timer_30s", "text": "存活30秒", "type": "timer", "target": 30.0, "progress": 0.0},
		]
	})
	_stage_missions.append({
		"stage": 2, "title": "第二试炼: 教室清剿",
		"narrative": "学生们被困在教室里。清理出一条生路。",
		"objectives": [
			{"id": "kills", "text": "击杀15个怪物", "type": "count", "target": 15, "progress": 0},
			{"id": "desks", "text": "清理5张课桌", "type": "count", "target": 5, "progress": 0},
		]
	})
	_stage_missions.append({
		"stage": 3, "title": "第三试炼: Boss讨伐",
		"narrative": "变异体出现在操场中央。击败它！",
		"objectives": [
			{"id": "boss", "text": "击败操场变异体", "type": "count", "target": 1, "progress": 0},
		]
	})

func get_title() -> String:
	if _current_stage < _stage_missions.size():
		return _stage_missions[_current_stage]["title"]
	return ""

func get_objectives() -> Array:
	if _current_stage < _stage_missions.size():
		return _stage_missions[_current_stage]["objectives"]
	return []

func notify_kill() -> void:
	_progress("kills", 1)

func notify_desk() -> void:
	_progress("desks", 1)

func notify_timer(delta: float) -> void:
	_progress_float("timer_30s", delta)

func notify_boss_kill() -> void:
	_progress("boss", 1)

func _progress(id: String, amount: int) -> void:
	if _current_stage >= _stage_missions.size(): return
	for obj in _stage_missions[_current_stage]["objectives"]:
		if obj["id"] == id and int(obj["progress"]) < int(obj["target"]):
			obj["progress"] = int(obj["progress"]) + amount
			_check_done()

func _progress_float(id: String, amount: float) -> void:
	if _current_stage >= _stage_missions.size(): return
	for obj in _stage_missions[_current_stage]["objectives"]:
		if obj["id"] == id and float(obj["progress"]) < float(obj["target"]):
			obj["progress"] = float(obj["progress"]) + amount
			_check_done()

func _check_done() -> void:
	for obj in _stage_missions[_current_stage]["objectives"]:
		var p = obj["progress"]; var t = obj["target"]
		if typeof(p) == TYPE_FLOAT:
			if float(p) < float(t): return
		else:
			if int(p) < int(t): return
	_current_stage += 1
	stage_cleared.emit(_current_stage)
	if _current_stage == 3:
		boss_spawned.emit("操场变异体")
