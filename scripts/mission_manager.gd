class_name MissionManager
extends Node

# ==============================
# 任务系统 V2 — 向后兼容接口层
# 内部委托给 MissionTriggerManager
# ==============================

signal stage_cleared(stage: int)
signal stage_activated(stage: int)
signal boss_spawned(boss_name: String)

var _trigger_manager: MissionTriggerManager = null
var _chain: MissionChain = null
var _boss_stage_ids: Array[int] = [4]

# ==============================
# 初始化
# ==============================

func init() -> void:
	_chain = _create_school_chapter()

	_trigger_manager = MissionTriggerManager.new()
	_trigger_manager.name = "MissionTriggerManager"
	add_child(_trigger_manager)

func _ready() -> void:
	# 信号转发
	_trigger_manager.stage_completed.connect(_on_internal_stage_completed)
	_trigger_manager.stage_activated.connect(_on_internal_stage_activated)

	# 加载任务链
	if _chain != null:
		_trigger_manager.load_chain(_chain)


# ==============================
# 向后兼容公共接口
# ==============================

func get_title() -> String:
	var stage: MissionStage = _trigger_manager.get_current_stage()
	if stage != null:
		return stage.stage_title
	return ""

func get_narrative() -> String:
	var stage: MissionStage = _trigger_manager.get_current_stage()
	if stage != null and not stage.dialogue_messages.is_empty():
		var first: Dictionary = stage.dialogue_messages[0]
		var narrator: String = first.get("speaker", "系统")
		var text: String = first.get("text", "")
		return narrator + ": \"" + text + "\""
	return ""

func get_objectives() -> Array:
	var stage: MissionStage = _trigger_manager.get_current_stage()
	if stage == null:
		return []
	var result: Array[Dictionary] = []
	for obj in stage.objectives:
		var progress_val: float = obj.trigger.current_value if obj.trigger != null else 0.0
		var target_val: float = obj.trigger.target_value if obj.trigger != null else 1.0
		result.append({
			"id": obj.objective_id,
			"text": obj.description,
			"hint": obj.hint,
			"target": target_val,
			"progress": progress_val,
		})
	return result

func get_current_stage() -> int:
	var idx: int = _trigger_manager.get_current_stage_index()
	return idx + 1  # 1-indexed 对外接口

func get_stage_dialogue(stage_id: int) -> Array[Dictionary]:
	if _chain == null:
		return []
	for stage in _chain.stages:
		if stage.stage_id == stage_id:
			return stage.dialogue_messages
	return []

# 已废弃 — 以下方法保留方法体但不执行实际逻辑
func notify_kill(_is_elite: bool = false) -> void:
	pass  # 已废弃：MissionTriggerManager 通过 EventBus 自动追踪

func notify_desk() -> void:
	pass  # 已废弃

func notify_reach_zone(_zone: String) -> void:
	pass  # 已废弃

func notify_boss_kill() -> void:
	pass  # 已废弃


# ==============================
# 内部：信号转发
# ==============================

func _on_internal_stage_completed(stage_id: int) -> void:
	# 向后兼容：stage_cleared 发射已完成 Stage 的编号
	stage_cleared.emit(stage_id)

func _on_internal_stage_activated(stage_id: int) -> void:
	stage_activated.emit(stage_id)
	if stage_id in _boss_stage_ids:
		EventBus.boss_approach_started.emit("boss_sato")  # GAP-01: 两阶段登场序列


# ==============================
# 学校副本任务链
# ==============================

func _create_school_chapter() -> MissionChain:
	var chain := MissionChain.new()
	chain.chain_id = "school_chapter1"
	chain.chain_name = "放課後"

	# ---- Zone 坐标（基于 map_school.gd 的地图尺寸 5760x4320） ----
	chain.zone_definitions = [
		{
			"zone_id": "zone_gate",
			"position": Vector2(2880, 4272),       # gx*T=2880, (rows-1)*T=4272
			"size": Vector2(768, 480),             # 16x10 tile
		},
		{
			"zone_id": "zone_gym_entrance",
			"position": Vector2(2880, 1200),       # gx*T, gy+24 -> 前厅区域
			"size": Vector2(672, 288),             # 14x6 tile
		},
		{
			"zone_id": "zone_gym_boss",
			"position": Vector2(2880, 580),        # gx*T, 体育馆中心偏上
			"size": Vector2(864, 576),             # 18x12 tile
		},
		{
			"zone_id": "zone_gate_escape",
			"position": Vector2(2880, 4176),       # 比 zone_gate 更靠南（触发逃离）
			"size": Vector2(960, 288),             # 20x6 tile
		},
		{
			"zone_id": "zone_hallway_defend",
			"position": Vector2(2640, 3000),       # 连廊中段
			"size": Vector2(960, 576),             # 20x12 tile
		},
	]

	# ======== Stage 1: 前往教学楼 ========
	var stage1 := MissionStage.new()
	stage1.stage_id = 1
	stage1.stage_title = "第一关 · 校门"

	var prompt1_on := PromptConfig.new()
	prompt1_on.text = "穿过操场"
	prompt1_on.show_arrow = true
	prompt1_on.arrow_target_zone = "zone_gate"
	prompt1_on.animation = "slide_down"
	prompt1_on.display_duration = 0.0  # 持续到 Stage 完成
	stage1.on_activate_prompt = prompt1_on

	var prompt1_done := PromptConfig.new()
	prompt1_done.text = "✓ 校门就在身后"
	prompt1_done.animation = "fade_in"
	prompt1_done.display_duration = 2.0
	stage1.on_complete_prompt = prompt1_done

	# Objective: 到达校门
	var obj1a := MissionObjective.new()
	obj1a.objective_id = "reach_gate"
	obj1a.description = "冲到校门口"
	obj1a.hint = "往南跑，校门就在前面"
	obj1a.is_optional = false
	obj1a.show_progress_bar = false

	var trig1a := TriggerConfig.new()
	trig1a.trigger_type = TriggerConfig.MissionTriggerType.LOCATION_REACH
	trig1a.params = {"zone_id": "zone_gate", "trigger_mode": "enter"}
	trig1a.target_value = 1.0
	obj1a.trigger = trig1a
	stage1.objectives.append(obj1a)

	# Objective: 击杀 8 个第一批怪物
	var obj1b := MissionObjective.new()
	obj1b.objective_id = "survive_wave1"
	obj1b.description = "来一个杀一个"
	obj1b.hint = "别站着。动起来！"
	obj1b.is_optional = false
	obj1b.show_progress_bar = true

	var trig1b := TriggerConfig.new()
	trig1b.trigger_type = TriggerConfig.MissionTriggerType.KILL_COUNT
	trig1b.params = {"enemy_filter": "any"}
	trig1b.target_value = 8.0
	obj1b.trigger = trig1b
	stage1.objectives.append(obj1b)

	# 对话（Stage 1 完成时的过渡对话）
	stage1.dialogue_messages = [
		{"speaker": "主角", "text": "操场上那些东西……穿着我们学校的校服。三年二班的。上周还坐我前面。"},
		{"speaker": "？？", "text": "你的心跳加快了。但你没有跑——很好。这座学校已经被污染了。你是我见过唯一还清醒的人。校门就在前面，冲过去。别回头。"},
	]

	chain.stages.append(stage1)

	# ======== Stage 2: 铃声下的教室（击杀15个） ========
	var stage2 := MissionStage.new()
	stage2.stage_id = 2
	stage2.stage_title = "第二关 · 铃声下的教室"

	var prompt2_on := PromptConfig.new()
	prompt2_on.text = "进教学楼"
	prompt2_on.show_arrow = true
	prompt2_on.arrow_target_zone = "zone_gate"
	prompt2_on.animation = "slide_down"
	prompt2_on.display_duration = 0.0
	stage2.on_activate_prompt = prompt2_on

	var prompt2_done := PromptConfig.new()
	prompt2_done.text = "✓ 教室里安静了"
	prompt2_done.animation = "fade_in"
	prompt2_done.display_duration = 2.0
	stage2.on_complete_prompt = prompt2_done

	# Objective: 击杀 15 个怪物
	var obj2a := MissionObjective.new()
	obj2a.objective_id = "kill_15"
	obj2a.description = "走廊上全是——别省技能"
	obj2a.hint = "靠墙打！别被包饺子"
	obj2a.is_optional = false
	obj2a.show_progress_bar = true

	var trig2a := TriggerConfig.new()
	trig2a.trigger_type = TriggerConfig.MissionTriggerType.KILL_COUNT
	trig2a.params = {"enemy_filter": "any"}
	trig2a.target_value = 15.0
	obj2a.trigger = trig2a
	stage2.objectives.append(obj2a)

	stage2.dialogue_messages = [
		{"speaker": "主角", "text": "课桌上笔记还在，铅笔搁在没算完的方程式旁边。他们走得比我快——连书包都没拿。这间教室在上课铃响的时候还是活的。"},
		{"speaker": "？？", "text": "脚步声停了。但走廊尽头传来别的声音——像是有什么东西在拖拽着什么。你在教室门口站了三秒，然后走出去。"},
	]

	chain.stages.append(stage2)

	# ======== Stage 3: 守住走廊（DEFEND_ZONE 30s + 前往体育馆入口） ========
	var stage3 := MissionStage.new()
	stage3.stage_id = 3
	stage3.stage_title = "第三关 · 守住走廊"

	var prompt3_on := PromptConfig.new()
	prompt3_on.text = "守住连廊"
	prompt3_on.text_color = Color(1.0, 0.5, 0.1)
	prompt3_on.show_arrow = true
	prompt3_on.arrow_target_zone = "zone_hallway_defend"
	prompt3_on.animation = "slide_down"
	prompt3_on.display_duration = 0.0
	stage3.on_activate_prompt = prompt3_on

	var prompt3_done := PromptConfig.new()
	prompt3_done.text = "✓ 走廊安静了"
	prompt3_done.animation = "fade_in"
	prompt3_done.display_duration = 2.0
	stage3.on_complete_prompt = prompt3_done

	# Objective A: DEFEND_ZONE 驻守走廊 30 秒
	var obj3a := MissionObjective.new()
	obj3a.objective_id = "defend_hallway"
	obj3a.description = "在连廊坚持住——别后退"
	obj3a.hint = "守住走廊中间段，离开区域计时会暂停"
	obj3a.is_optional = false
	obj3a.show_progress_bar = true

	var trig3a := TriggerConfig.new()
	trig3a.trigger_type = TriggerConfig.MissionTriggerType.DEFEND_ZONE
	trig3a.params = {"zone_id": "zone_hallway_defend", "pause_on_exit": true}
	trig3a.target_value = 30.0
	obj3a.trigger = trig3a
	stage3.objectives.append(obj3a)

	# Objective B: 前往体育馆入口
	var obj3b := MissionObjective.new()
	obj3b.objective_id = "reach_gym"
	obj3b.description = "前往体育馆"
	obj3b.hint = "穿过连廊向北，体育馆在深处"
	obj3b.is_optional = false
	obj3b.show_progress_bar = false
	var trig3b := TriggerConfig.new()
	trig3b.trigger_type = TriggerConfig.MissionTriggerType.LOCATION_REACH
	trig3b.params = {"zone_id": "zone_gym_entrance", "trigger_mode": "enter"}
	trig3b.target_value = 1.0
	obj3b.trigger = trig3b
	stage3.objectives.append(obj3b)

	stage3.dialogue_messages = [
		{"speaker": "主角", "text": "走廊里的灯在闪。我的脚步声在空荡荡的楼道里回响。上面——那是什么样的声音？"},
		{"speaker": "？？", "text": "两边的教室门开着。你刚才从里面杀出来。但背后——又有脚步声了。"},
	]

	chain.stages.append(stage3)

	# ======== Stage 4: 体育馆的哨声（进门→杀精英守卫→门开→杀Boss） ========
	var stage4 := MissionStage.new()
	stage4.stage_id = 4
	stage4.stage_title = "第四关 · 体育馆的哨声"

	# 激活条件：到达体育馆入口
	var act_cond4 := TriggerConfig.new()
	act_cond4.trigger_type = TriggerConfig.MissionTriggerType.LOCATION_REACH
	act_cond4.params = {"zone_id": "zone_gym_entrance", "trigger_mode": "enter"}
	act_cond4.target_value = 1.0
	stage4.activation_condition = act_cond4

	var prompt4_on := PromptConfig.new()
	prompt4_on.text = "哨声还在响"
	prompt4_on.text_color = Color(1.0, 0.15, 0.05)  # 红色警告
	prompt4_on.show_arrow = true
	prompt4_on.arrow_target_zone = "zone_gym_boss"
	prompt4_on.animation = "pulse"
	prompt4_on.display_duration = 0.0
	stage4.on_activate_prompt = prompt4_on

	var prompt4_done := PromptConfig.new()
	prompt4_done.text = "✓ 哨声停了"
	prompt4_done.animation = "fade_in"
	prompt4_done.display_duration = 2.0
	stage4.on_complete_prompt = prompt4_done

	# Objective A: 击杀精英守卫 → 开门
	var obj4a := MissionObjective.new()
	obj4a.objective_id = "kill_guard"
	obj4a.description = "击败守卫·开门"
	obj4a.hint = "杀了他，门才会开"
	obj4a.is_optional = false
	obj4a.show_progress_bar = true

	var trig4a := TriggerConfig.new()
	trig4a.trigger_type = TriggerConfig.MissionTriggerType.KILL_COUNT
	trig4a.params = {"enemy_filter": "elite"}
	trig4a.target_value = 1.0
	obj4a.trigger = trig4a
	obj4a.completion_action = {"type": "unlock_door", "door_id": "gym_lock_door"}
	stage4.objectives.append(obj4a)

	# Objective B: 到达 Boss 间深处
	var obj4b := MissionObjective.new()
	obj4b.objective_id = "reach_boss_room"
	obj4b.description = "进体育馆——Boss在里面"
	obj4b.hint = "哨声都听见了吧——Boss就在里面"
	obj4b.is_optional = false
	obj4b.show_progress_bar = false

	var trig4b := TriggerConfig.new()
	trig4b.trigger_type = TriggerConfig.MissionTriggerType.LOCATION_REACH
	trig4b.params = {"zone_id": "zone_gym_boss", "trigger_mode": "enter"}
	trig4b.target_value = 1.0
	obj4b.trigger = trig4b
	stage4.objectives.append(obj4b)

	# Objective C: 击败 Boss
	var obj4c := MissionObjective.new()
	obj4c.objective_id = "kill_boss"
	obj4c.description = "杀了他——别留手"
	obj4c.hint = "别废话。进去杀。"
	obj4c.is_optional = false
	obj4c.show_progress_bar = true

	var trig4c := TriggerConfig.new()
	trig4c.trigger_type = TriggerConfig.MissionTriggerType.KILL_COUNT
	trig4c.params = {"enemy_filter": "boss"}
	trig4c.target_value = 1.0
	obj4c.trigger = trig4c
	stage4.objectives.append(obj4c)

	stage4.dialogue_messages = [
		{"speaker": "？？", "text": "体育馆的门在你面前。推开它。佐藤就在里面——他不是怪物。他是这所学校最后的老师。让他下课。"},
	]

	chain.stages.append(stage4)

	# ======== Stage 5: 下课铃（逃离学校） ========
	var stage5 := MissionStage.new()
	stage5.stage_id = 5
	stage5.stage_title = "终章 · 下课铃"

	# 激活条件：Boss 已被击败（玩家已在 zone_gym_boss）
	var act_cond5 := TriggerConfig.new()
	act_cond5.trigger_type = TriggerConfig.MissionTriggerType.LOCATION_REACH
	act_cond5.params = {"zone_id": "zone_gym_boss", "trigger_mode": "enter"}
	act_cond5.target_value = 1.0
	stage5.activation_condition = act_cond5

	var prompt5_on := PromptConfig.new()
	prompt5_on.text = "校门在前面。跑。"
	prompt5_on.text_color = Color(1.0, 0.85, 0.2)  # 金色——希望的颜色
	prompt5_on.show_arrow = true
	prompt5_on.arrow_target_zone = "zone_gate_escape"
	prompt5_on.animation = "pulse"
	prompt5_on.display_duration = 0.0  # 持续到 Stage 完成
	stage5.on_activate_prompt = prompt5_on

	# Objective: 到达校门（逃离）
	var obj5a := MissionObjective.new()
	obj5a.objective_id = "escape_gate"
	obj5a.description = "冲出校门"
	obj5a.hint = "往南！校门就在前面！别回头——"
	obj5a.is_optional = false
	obj5a.show_progress_bar = false

	var trig5a := TriggerConfig.new()
	trig5a.trigger_type = TriggerConfig.MissionTriggerType.LOCATION_REACH
	trig5a.params = {"zone_id": "zone_gate_escape", "trigger_mode": "enter"}
	trig5a.target_value = 1.0
	obj5a.trigger = trig5a
	stage5.objectives.append(obj5a)

	# 对话（Stage 5 激活时播放）
	stage5.dialogue_messages = [
		{"speaker": "？？", "text": "你听见了上课铃——不，是下课铃。佐藤倒下了，但这座学校还在。在你身后，走廊里的东西正在聚拢。往前看。校门。"},
	]

	chain.stages.append(stage5)

	return chain