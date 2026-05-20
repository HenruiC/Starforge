class_name TriggerConfig
extends Resource

# Trigger 类型枚举
# V1.0 实现 LOCATION_REACH / KILL_COUNT / TIME_SURVIVE
# 后三类预留接口但不实现 Evaluator 逻辑
enum MissionTriggerType {
	LOCATION_REACH = 0,
	KILL_COUNT = 1,
	TIME_SURVIVE = 2,
	INTERACT = 3,
	COLLECT = 4,
	BOSS_HP_THRESHOLD = 5,
	# 6 is intentionally skipped — reserved for future use
	DEFEND_ZONE = 7,       # 新增：驻守指定区域 X 秒，离开暂停/重置
	PROTECT_OBJECT = 8,    # 新增：保护场景目标物体 HP>阈值 维持 X 秒
}

@export var trigger_type: int = MissionTriggerType.LOCATION_REACH
@export var params: Dictionary = {}

# 目标值（count / seconds / threshold）
@export var target_value: float = 1.0

# 运行时当前值 — 不导出，由 Evaluator 推进
var current_value: float = 0.0
